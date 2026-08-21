//! Ports tests/test_virtio.py's cases verbatim -- same register offsets,
//! same descriptor-chain layout, same expected results.

use rv64rs::bus::{Bus, DeviceImpl, SharedDevice};
use rv64rs::ram::Ram;
use rv64rs::virtio::VirtIOBlk;
use std::cell::RefCell;
use std::rc::Rc;

const VIRTIO_BASE: u64 = 0x1000_1000;

// register offsets (from virtio.rs / virtio.py)
const MAGIC_VALUE: u64 = 0x000;
const VERSION: u64 = 0x004;
const DEVICE_ID: u64 = 0x008;
const VENDOR_ID: u64 = 0x00c;
const QUEUE_SEL: u64 = 0x030;
const QUEUE_NUM_MAX: u64 = 0x034;
const QUEUE_NUM: u64 = 0x038;
const QUEUE_READY: u64 = 0x044;
const QUEUE_NOTIFY: u64 = 0x050;
const INTERRUPT_ACK: u64 = 0x064;
const STATUS: u64 = 0x070;
const QUEUE_DESC_LOW: u64 = 0x080;
const QUEUE_DESC_HIGH: u64 = 0x084;
const DRIVER_DESC_LOW: u64 = 0x090;
const DRIVER_DESC_HIGH: u64 = 0x094;
const DEVICE_DESC_LOW: u64 = 0x0a0;
const DEVICE_DESC_HIGH: u64 = 0x0a4;

const MAGIC: u64 = 0x74726976;
const VENDOR: u64 = 0x554d_4551;
const VIRTQ_DESC_F_NEXT: u64 = 1;
const VIRTQ_DESC_F_WRITE: u64 = 2;
const VIRTIO_BLK_T_IN: u64 = 0;
const VIRTIO_BLK_T_OUT: u64 = 1;

fn make_device() -> (Rc<RefCell<Bus>>, Rc<RefCell<VirtIOBlk>>) {
    let mut bus = Bus::new();
    bus.add_device(DeviceImpl::Ram(Ram::new(0x10000)), 0).unwrap();
    let bus = Rc::new(RefCell::new(bus));
    let dev = Rc::new(RefCell::new(VirtIOBlk::new(bus.clone(), 8 * 1024 * 1024, None)));
    bus.borrow_mut().add_device(DeviceImpl::VirtIOBlk(SharedDevice(dev.clone())), VIRTIO_BASE).unwrap();
    (bus, dev)
}

#[test]
fn disk_image_backs_the_synthetic_disk() {
    let mut bus = Bus::new();
    bus.add_device(DeviceImpl::Ram(Ram::new(0x10000)), 0).unwrap();
    let bus = Rc::new(RefCell::new(bus));
    let mut image = vec![0xABu8; 512];
    image.extend(vec![0u8; 512]); // sector 0 = 0xAB..., sector 1 = zero
    let dev = VirtIOBlk::new(bus, 8 * 1024 * 1024, Some(image));
    assert_eq!(&dev.disk[..512], &vec![0xABu8; 512][..]);
    assert_eq!(&dev.disk[512..1024], &vec![0u8; 512][..]);
}

#[test]
fn disk_image_smaller_than_disk_size_is_zero_padded() {
    let mut bus = Bus::new();
    bus.add_device(DeviceImpl::Ram(Ram::new(0x10000)), 0).unwrap();
    let bus = Rc::new(RefCell::new(bus));
    let dev = VirtIOBlk::new(bus, 4096, Some(vec![1, 2, 3]));
    assert_eq!(dev.disk.len(), 4096);
    assert_eq!(&dev.disk[..3], &[1, 2, 3]);
    assert_eq!(dev.disk[3], 0);
}

#[test]
fn identification() {
    let (bus, _dev) = make_device();
    assert_eq!(bus.borrow().read(VIRTIO_BASE + MAGIC_VALUE, 4).unwrap(), MAGIC);
    assert_eq!(bus.borrow().read(VIRTIO_BASE + VERSION, 4).unwrap(), 2);
    assert_eq!(bus.borrow().read(VIRTIO_BASE + DEVICE_ID, 4).unwrap(), 2);
    assert_eq!(bus.borrow().read(VIRTIO_BASE + VENDOR_ID, 4).unwrap(), VENDOR);
}

#[test]
fn queue_num_max_is_never_the_blocker() {
    let (bus, _dev) = make_device();
    assert!(bus.borrow().read(VIRTIO_BASE + QUEUE_NUM_MAX, 4).unwrap() >= 8);
}

#[test]
fn status_roundtrip() {
    let (bus, _dev) = make_device();
    bus.borrow().write(VIRTIO_BASE + STATUS, 4, 0xf).unwrap();
    assert_eq!(bus.borrow().read(VIRTIO_BASE + STATUS, 4).unwrap(), 0xf);
}

fn write_desc(bus: &Rc<RefCell<Bus>>, table_addr: u64, idx: u64, addr: u64, length: u64, flags: u64, next: u64) {
    let off = table_addr + idx * 16;
    bus.borrow().write(off, 8, addr).unwrap();
    bus.borrow().write(off + 8, 4, length).unwrap();
    bus.borrow().write(off + 12, 2, flags).unwrap();
    bus.borrow().write(off + 14, 2, next).unwrap();
}

fn setup_queue(bus: &Rc<RefCell<Bus>>) -> (u64, u64, u64) {
    let (desc_addr, avail_addr, used_addr, queue_num) = (0x2000u64, 0x3000u64, 0x4000u64, 8u64);
    let b = bus.borrow();
    b.write(VIRTIO_BASE + QUEUE_SEL, 4, 0).unwrap();
    b.write(VIRTIO_BASE + QUEUE_NUM, 4, queue_num).unwrap();
    b.write(VIRTIO_BASE + QUEUE_DESC_LOW, 4, desc_addr & 0xffffffff).unwrap();
    b.write(VIRTIO_BASE + QUEUE_DESC_HIGH, 4, desc_addr >> 32).unwrap();
    b.write(VIRTIO_BASE + DRIVER_DESC_LOW, 4, avail_addr & 0xffffffff).unwrap();
    b.write(VIRTIO_BASE + DRIVER_DESC_HIGH, 4, avail_addr >> 32).unwrap();
    b.write(VIRTIO_BASE + DEVICE_DESC_LOW, 4, used_addr & 0xffffffff).unwrap();
    b.write(VIRTIO_BASE + DEVICE_DESC_HIGH, 4, used_addr >> 32).unwrap();
    b.write(VIRTIO_BASE + QUEUE_READY, 4, 1).unwrap();
    (desc_addr, avail_addr, used_addr)
}

#[test]
fn queue_desc_addr_roundtrips_across_low_high_halves() {
    let (bus, dev) = make_device();
    bus.borrow().write(VIRTIO_BASE + QUEUE_DESC_LOW, 4, 0x12345678).unwrap();
    bus.borrow().write(VIRTIO_BASE + QUEUE_DESC_HIGH, 4, 0x9abcdef0).unwrap();
    assert_eq!(dev.borrow().desc_addr, 0x9abcdef012345678);
}

#[test]
fn queue_ready_roundtrip() {
    let (bus, _dev) = make_device();
    assert_eq!(bus.borrow().read(VIRTIO_BASE + QUEUE_READY, 4).unwrap(), 0);
    bus.borrow().write(VIRTIO_BASE + QUEUE_READY, 4, 1).unwrap();
    assert_eq!(bus.borrow().read(VIRTIO_BASE + QUEUE_READY, 4).unwrap(), 1);
}

#[test]
fn block_read_returns_disk_contents() {
    let (bus, dev) = make_device();
    let (desc_base, avail_base, used_base) = setup_queue(&bus);

    // seed the synthetic disk at sector 3 so we can tell a real read happened
    dev.borrow_mut().disk[3 * 512..3 * 512 + 4].copy_from_slice(&[0xde, 0xad, 0xbe, 0xef]);

    let (header_addr, data_addr, status_addr) = (0x8000u64, 0x9000u64, 0xa000u64);

    bus.borrow().write(header_addr, 4, VIRTIO_BLK_T_IN).unwrap();
    bus.borrow().write(header_addr + 8, 8, 3).unwrap(); // sector

    write_desc(&bus, desc_base, 0, header_addr, 16, VIRTQ_DESC_F_NEXT, 1);
    write_desc(&bus, desc_base, 1, data_addr, 512, VIRTQ_DESC_F_NEXT | VIRTQ_DESC_F_WRITE, 2);
    write_desc(&bus, desc_base, 2, status_addr, 1, VIRTQ_DESC_F_WRITE, 0);

    bus.borrow().write(avail_base + 4, 2, 0).unwrap(); // avail.ring[0] = descriptor head 0
    bus.borrow().write(avail_base + 2, 2, 1).unwrap(); // avail.idx = 1

    bus.borrow().write(VIRTIO_BASE + QUEUE_NOTIFY, 4, 0).unwrap();

    assert_eq!(bus.borrow().read(data_addr, 4).unwrap(), 0xefbeadde); // little-endian DE AD BE EF
    assert_eq!(bus.borrow().read(status_addr, 1).unwrap(), 0);
    assert_eq!(bus.borrow().read(used_base + 2, 2).unwrap(), 1); // used.idx advanced
    assert_eq!(bus.borrow().read(used_base + 4, 4).unwrap(), 0); // used.ring[0].id == descriptor head
    assert_ne!(dev.borrow().interrupt_status & 1, 0);
}

#[test]
fn block_write_persists_to_disk() {
    let (bus, dev) = make_device();
    let (desc_base, avail_base, _used_base) = setup_queue(&bus);

    let (header_addr, data_addr, status_addr) = (0x8000u64, 0x9000u64, 0xa000u64);

    bus.borrow().write(header_addr, 4, VIRTIO_BLK_T_OUT).unwrap();
    bus.borrow().write(header_addr + 8, 8, 5).unwrap(); // sector
    bus.borrow().write(data_addr, 4, 0x01020304).unwrap();

    write_desc(&bus, desc_base, 0, header_addr, 16, VIRTQ_DESC_F_NEXT, 1);
    write_desc(&bus, desc_base, 1, data_addr, 4, VIRTQ_DESC_F_NEXT, 2);
    write_desc(&bus, desc_base, 2, status_addr, 1, VIRTQ_DESC_F_WRITE, 0);

    bus.borrow().write(avail_base + 4, 2, 0).unwrap();
    bus.borrow().write(avail_base + 2, 2, 1).unwrap();

    bus.borrow().write(VIRTIO_BASE + QUEUE_NOTIFY, 4, 0).unwrap();

    assert_eq!(&dev.borrow().disk[5 * 512..5 * 512 + 4], &[0x04, 0x03, 0x02, 0x01]);
    assert_eq!(bus.borrow().read(status_addr, 1).unwrap(), 0);
}

#[test]
fn interrupt_ack_clears_status() {
    let (bus, dev) = make_device();
    dev.borrow_mut().interrupt_status = 1;
    bus.borrow().write(VIRTIO_BASE + INTERRUPT_ACK, 4, 1).unwrap();
    assert_eq!(dev.borrow().interrupt_status, 0);
}
