//! Corresponds to riscvm/virtio.py: a minimal VirtIO MMIO (modern, version
//! 2) block device -- just enough of the protocol for xv6's
//! virtio_disk_init() to see a real disk and complete feature negotiation/
//! queue setup, plus a synchronous QUEUE_NOTIFY handler that resolves a
//! block request immediately against an in-memory disk image (no real
//! interrupt-driven completion; the PLIC interrupt line is still raised,
//! via interrupt_status, for xv6's driver to observe).

use crate::bus::Bus;
use crate::error::{error, EmuError};
use std::collections::HashMap;

const PAGE_SIZE: u64 = 0x1000;

const MAGIC_VALUE: u64 = 0x000;
const VERSION: u64 = 0x004;
const DEVICE_ID: u64 = 0x008;
const VENDOR_ID: u64 = 0x00c;
const DEVICE_FEATURES: u64 = 0x010;
const DRIVER_FEATURES: u64 = 0x020;
const QUEUE_SEL: u64 = 0x030;
const QUEUE_NUM_MAX: u64 = 0x034;
const QUEUE_NUM: u64 = 0x038;
const QUEUE_READY: u64 = 0x044;
const QUEUE_NOTIFY: u64 = 0x050;
const INTERRUPT_STATUS: u64 = 0x060;
const INTERRUPT_ACK: u64 = 0x064;
const STATUS: u64 = 0x070;
const QUEUE_DESC_LOW: u64 = 0x080;
const QUEUE_DESC_HIGH: u64 = 0x084;
const DRIVER_DESC_LOW: u64 = 0x090; // avail ring address
const DRIVER_DESC_HIGH: u64 = 0x094;
const DEVICE_DESC_LOW: u64 = 0x0a0; // used ring address
const DEVICE_DESC_HIGH: u64 = 0x0a4;

const MAGIC: u64 = 0x74726976; // 'virt'
const VENDOR: u64 = 0x554d_4551; // 'QEMU'
const DEVICE_ID_BLK: u64 = 2;
const MMIO_VERSION: u64 = 2;

// generous upper bound so we accept whatever queue depth the driver asks
// for; our queue processing isn't backed by a fixed-size ring buffer
const QUEUE_NUM_MAX_VALUE: u64 = 1 << 15;

const VIRTQ_DESC_F_NEXT: u16 = 1;
// VIRTQ_DESC_F_WRITE (bit 2) is part of the spec but, like virtio.py, this
// implementation never branches on it -- the request type in the header
// descriptor already says read vs. write, and both directions trust the
// chain's addr/len fields regardless of this flag.
#[allow(dead_code)]
const VIRTQ_DESC_F_WRITE: u16 = 2;

const VIRTIO_BLK_T_IN: u32 = 0; // read
const VIRTIO_BLK_T_OUT: u32 = 1; // write

const SECTOR_SIZE: u64 = 512;

pub struct VirtIOBlk {
    pub disk: Vec<u8>,
    device_features: u32,
    driver_features: u32,
    queue_sel: u32,
    queue_num: u32,
    queue_ready: u32,
    pub desc_addr: u64,
    avail_addr: u64,
    used_addr: u64,
    status: u32,
    pub interrupt_status: u32,
    last_avail_idx: HashMap<u32, u16>,
}

impl VirtIOBlk {
    pub fn new(disk_size: u64, disk_image: Option<Vec<u8>>) -> Self {
        let disk = match disk_image {
            Some(mut image) => {
                if (image.len() as u64) < disk_size {
                    image.resize(disk_size as usize, 0);
                }
                image
            }
            None => vec![0u8; disk_size as usize],
        };
        VirtIOBlk {
            disk,
            device_features: 0,
            driver_features: 0,
            queue_sel: 0,
            queue_num: 0,
            queue_ready: 0,
            desc_addr: 0,
            avail_addr: 0,
            used_addr: 0,
            status: 0,
            interrupt_status: 0,
            last_avail_idx: HashMap::new(),
        }
    }

    pub fn len(&self) -> u64 {
        PAGE_SIZE
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    pub fn read(&mut self, address: u64, size: u8) -> Result<u64, EmuError> {
        if size != 4 {
            return error(format!("virtio-mmio register reads must be 4 bytes, got {size} @0x{address:x}"));
        }
        let value = match address {
            MAGIC_VALUE => MAGIC,
            VERSION => MMIO_VERSION,
            DEVICE_ID => DEVICE_ID_BLK,
            VENDOR_ID => VENDOR,
            DEVICE_FEATURES => self.device_features as u64,
            QUEUE_NUM_MAX => QUEUE_NUM_MAX_VALUE,
            QUEUE_READY => self.queue_ready as u64,
            INTERRUPT_STATUS => self.interrupt_status as u64,
            STATUS => self.status as u64,
            _ => 0,
        };
        Ok(value)
    }

    /// Takes `bus: &mut Bus` for the QUEUE_NOTIFY case's DMA into guest RAM
    /// -- this device no longer holds its own `Rc<RefCell<Bus>>` handle
    /// back to the bus it's registered on (see bus.rs's doc comment on
    /// `Bus::write`'s VIRTIO arm for why: that reentrant-Rc pattern doesn't
    /// work any more now that Bus::read/write take `&mut self`, so the
    /// bus that dispatched this call passes itself in directly instead).
    pub fn write(&mut self, address: u64, size: u8, value: u64, bus: &mut Bus) -> Result<(), EmuError> {
        if size != 4 {
            return error(format!("virtio-mmio register writes must be 4 bytes, got {size} @0x{address:x}"));
        }
        let v32 = value as u32;
        match address {
            DRIVER_FEATURES => self.driver_features = v32,
            QUEUE_SEL => self.queue_sel = v32,
            QUEUE_NUM => self.queue_num = v32,
            QUEUE_READY => self.queue_ready = v32,
            QUEUE_DESC_LOW => self.desc_addr = (self.desc_addr & !0xffff_ffff) | value,
            QUEUE_DESC_HIGH => self.desc_addr = (self.desc_addr & 0xffff_ffff) | (value << 32),
            DRIVER_DESC_LOW => self.avail_addr = (self.avail_addr & !0xffff_ffff) | value,
            DRIVER_DESC_HIGH => self.avail_addr = (self.avail_addr & 0xffff_ffff) | (value << 32),
            DEVICE_DESC_LOW => self.used_addr = (self.used_addr & !0xffff_ffff) | value,
            DEVICE_DESC_HIGH => self.used_addr = (self.used_addr & 0xffff_ffff) | (value << 32),
            QUEUE_NOTIFY => self.process_queue(v32, bus)?,
            INTERRUPT_ACK => self.interrupt_status &= !v32,
            STATUS => {
                self.status = v32;
                if v32 == 0 {
                    // driver-initiated reset
                    self.queue_ready = 0;
                    self.queue_num = 0;
                    self.desc_addr = 0;
                    self.avail_addr = 0;
                    self.used_addr = 0;
                    self.last_avail_idx.clear();
                }
            }
            _ => {}
        }
        Ok(())
    }

    fn process_queue(&mut self, queue_idx: u32, bus: &mut Bus) -> Result<(), EmuError> {
        if self.queue_ready == 0 || self.queue_num == 0 {
            return Ok(());
        }

        let desc_base = self.desc_addr;
        let avail_base = self.avail_addr;
        let used_base = self.used_addr;

        let avail_idx = bus.read(avail_base + 2, 2)? as u16;
        let used_idx_initial = bus.read(used_base + 2, 2)? as u16;
        let mut last = self.last_avail_idx.get(&queue_idx).copied().unwrap_or(used_idx_initial);
        let mut used_idx = used_idx_initial;

        while last != avail_idx {
            let ring_off = avail_base + 4 + (last as u64 % self.queue_num as u64) * 2;
            let head = bus.read(ring_off, 2)? as u16;
            let length = self.process_descriptor_chain(desc_base, head, bus)?;

            let used_elem_off = used_base + 4 + (used_idx as u64 % self.queue_num as u64) * 8;
            bus.write(used_elem_off, 4, head as u64)?;
            bus.write(used_elem_off + 4, 4, length as u64)?;
            used_idx = used_idx.wrapping_add(1);
            bus.write(used_base + 2, 2, used_idx as u64)?;
            last = last.wrapping_add(1);
        }

        self.last_avail_idx.insert(queue_idx, last);
        self.interrupt_status |= 1;
        Ok(())
    }

    fn process_descriptor_chain(&mut self, desc_base: u64, head: u16, bus: &mut Bus) -> Result<u32, EmuError> {
        let mut descs: Vec<(u64, u32, u16)> = Vec::new();
        let mut idx = head;
        let mut seen = std::collections::HashSet::new();
        loop {
            if !seen.insert(idx) {
                break;
            }
            let off = desc_base + idx as u64 * 16;
            let addr = bus.read(off, 8)?;
            let length = bus.read(off + 8, 4)? as u32;
            let flags = bus.read(off + 12, 2)? as u16;
            let nxt = bus.read(off + 14, 2)? as u16;
            descs.push((addr, length, flags));
            if flags & VIRTQ_DESC_F_NEXT != 0 {
                idx = nxt;
            } else {
                break;
            }
        }

        if descs.len() < 3 {
            return Ok(0); // malformed descriptor chain (need header/data/status)
        }

        let (header_addr, _, _) = descs[0];
        let (data_addr, data_len, _) = descs[1];
        let (status_addr, _, _) = descs[descs.len() - 1];

        let req_type = bus.read(header_addr, 4)? as u32;
        let sector = bus.read(header_addr + 8, 8)?;
        let offset = sector * SECTOR_SIZE;

        if req_type == VIRTIO_BLK_T_IN {
            let end = (offset + data_len as u64) as usize;
            if end > self.disk.len() {
                self.disk.resize(end, 0);
            }
            let chunk = self.disk[offset as usize..end].to_vec();
            for (i, &b) in chunk.iter().enumerate() {
                bus.write(data_addr + i as u64, 1, b as u64)?;
            }
        } else if req_type == VIRTIO_BLK_T_OUT {
            let mut chunk = vec![0u8; data_len as usize];
            for (i, b) in chunk.iter_mut().enumerate() {
                *b = bus.read(data_addr + i as u64, 1)? as u8;
            }
            let end = (offset + data_len as u64) as usize;
            if end > self.disk.len() {
                self.disk.resize(end, 0);
            }
            self.disk[offset as usize..end].copy_from_slice(&chunk);
        } // unsupported request type: silently ignored, matching riscvm's logger.warning-only path

        bus.write(status_addr, 1, 0)?; // VIRTIO_BLK_S_OK
        Ok(0)
    }
}
