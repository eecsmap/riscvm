'''
Minimal VirtIO MMIO (legacy, version 1) block device.

refer:
    https://docs.oasis-open.org/virtio/virtio/v1.1/virtio-v1.1.html
    xv6-riscv kernel/virtio.h, kernel/virtio_disk.c

Just enough of the protocol for xv6's virtio_disk_init() to see a real
disk and complete feature negotiation / queue setup without panicking,
plus a synchronous QUEUE_NOTIFY handler so a block request (once one is
ever issued) resolves immediately against an in-memory synthetic disk,
rather than requiring real interrupt delivery (not modeled by this
emulator yet).
'''

import logging
logger = logging.getLogger(__name__)

PAGE_SIZE = 0x1000

class VirtIOBlk:

    MAGIC_VALUE = 0x000
    VERSION = 0x004
    DEVICE_ID = 0x008
    VENDOR_ID = 0x00c
    DEVICE_FEATURES = 0x010
    DRIVER_FEATURES = 0x020
    GUEST_PAGE_SIZE = 0x028
    QUEUE_SEL = 0x030
    QUEUE_NUM_MAX = 0x034
    QUEUE_NUM = 0x038
    QUEUE_ALIGN = 0x03c
    QUEUE_PFN = 0x040
    QUEUE_NOTIFY = 0x050
    INTERRUPT_STATUS = 0x060
    INTERRUPT_ACK = 0x064
    STATUS = 0x070

    MAGIC = 0x74726976  # 'virt'
    VENDOR = 0x554d4551  # 'QEMU'
    DEVICE_ID_BLK = 2
    LEGACY_VERSION = 1

    # generous upper bound so we accept whatever queue depth the driver
    # asks for; our queue processing isn't backed by a fixed-size ring buffer
    QUEUE_NUM_MAX_VALUE = 1 << 15

    VIRTQ_DESC_F_NEXT = 1
    VIRTQ_DESC_F_WRITE = 2

    VIRTIO_BLK_T_IN = 0   # read
    VIRTIO_BLK_T_OUT = 1  # write

    SECTOR_SIZE = 512

    def __init__(self, bus, disk_size=8 * 1024 * 1024, disk_image=None):
        # bus grants access to guest physical memory: the descriptor table,
        # avail/used rings, and the actual read/write buffers all live in RAM
        # the driver allocated, addressed by physical address.
        self.bus = bus
        if disk_image is not None:
            # real xv6 filesystem image (built via mkfs): back reads/writes
            # with its actual bytes instead of an all-zero synthetic disk
            self.disk = bytearray(disk_image)
            if len(self.disk) < disk_size:
                self.disk.extend(bytes(disk_size - len(self.disk)))
        else:
            self.disk = bytearray(disk_size)  # synthetic, zero-filled
        self.device_features = 0
        self.driver_features = 0
        self.queue_sel = 0
        self.queue_num = 0
        self.queue_pfn = 0
        self.status = 0
        self.interrupt_status = 0
        self._last_avail_idx = {}  # queue index -> last processed avail.idx

    def __len__(self):
        return PAGE_SIZE

    def read(self, address, size):
        assert size == 4, f'virtio-mmio register reads must be 4 bytes, got {size} @0x{address:x}'
        match address:
            case self.MAGIC_VALUE:
                return self.MAGIC
            case self.VERSION:
                return self.LEGACY_VERSION
            case self.DEVICE_ID:
                return self.DEVICE_ID_BLK
            case self.VENDOR_ID:
                return self.VENDOR
            case self.DEVICE_FEATURES:
                return self.device_features
            case self.QUEUE_NUM_MAX:
                return self.QUEUE_NUM_MAX_VALUE
            case self.QUEUE_PFN:
                return self.queue_pfn
            case self.INTERRUPT_STATUS:
                return self.interrupt_status
            case self.STATUS:
                return self.status
            case _:
                return 0

    def write(self, address, size, value):
        assert size == 4, f'virtio-mmio register writes must be 4 bytes, got {size} @0x{address:x}'
        match address:
            case self.DRIVER_FEATURES:
                self.driver_features = value
            case self.GUEST_PAGE_SIZE | self.QUEUE_ALIGN:
                pass  # legacy alignment hints; we use a fixed PAGE_SIZE layout
            case self.QUEUE_SEL:
                self.queue_sel = value
            case self.QUEUE_NUM:
                self.queue_num = value
            case self.QUEUE_PFN:
                self.queue_pfn = value
            case self.QUEUE_NOTIFY:
                self._process_queue(value)
            case self.INTERRUPT_ACK:
                self.interrupt_status &= ~value
            case self.STATUS:
                self.status = value
                if value == 0:
                    # driver-initiated reset
                    self.queue_pfn = 0
                    self.queue_num = 0
                    self._last_avail_idx.clear()
            case _:
                pass

    # -- guest memory helpers -------------------------------------------

    def _r16(self, addr):
        return self.bus.read(addr, 2)

    def _r32(self, addr):
        return self.bus.read(addr, 4)

    def _r64(self, addr):
        return self.bus.read(addr, 8)

    def _w16(self, addr, value):
        self.bus.write(addr, 2, value)

    def _w32(self, addr, value):
        self.bus.write(addr, 4, value)

    def _read_bytes(self, addr, n):
        return bytes(self.bus.read(addr + i, 1) for i in range(n))

    def _write_bytes(self, addr, data):
        for i, b in enumerate(data):
            self.bus.write(addr + i, 1, b)

    # -- virtqueue processing --------------------------------------------

    def _process_queue(self, queue_idx):
        if self.queue_pfn == 0 or self.queue_num == 0:
            return

        base = self.queue_pfn * PAGE_SIZE
        desc_base = base
        avail_base = base + self.queue_num * 16
        used_base = base + PAGE_SIZE  # legacy layout: used ring starts on the next page

        avail_idx = self._r16(avail_base + 2)
        used_idx = self._r16(used_base + 2)
        last = self._last_avail_idx.get(queue_idx, used_idx)

        while (last & 0xffff) != avail_idx:
            ring_off = avail_base + 4 + (last % self.queue_num) * 2
            head = self._r16(ring_off)
            length = self._process_descriptor_chain(desc_base, head)

            used_elem_off = used_base + 4 + (used_idx % self.queue_num) * 8
            self._w32(used_elem_off, head)
            self._w32(used_elem_off + 4, length)
            used_idx = (used_idx + 1) & 0xffff
            self._w16(used_base + 2, used_idx)
            last = (last + 1) & 0xffff

        self._last_avail_idx[queue_idx] = last
        self.interrupt_status |= 1

    def _process_descriptor_chain(self, desc_base, head):
        descs = []
        idx = head
        seen = set()
        while idx not in seen:
            seen.add(idx)
            off = desc_base + idx * 16
            addr = self._r64(off)
            length = self._r32(off + 8)
            flags = self._r16(off + 12)
            nxt = self._r16(off + 14)
            descs.append((addr, length, flags))
            if flags & self.VIRTQ_DESC_F_NEXT:
                idx = nxt
            else:
                break

        if len(descs) < 3:
            logger.warning('virtio: malformed descriptor chain (need header/data/status)')
            return 0

        header_addr, _, _ = descs[0]
        data_addr, data_len, _ = descs[1]
        status_addr, _, _ = descs[-1]

        req_type = self._r32(header_addr)
        sector = self._r64(header_addr + 8)
        offset = sector * self.SECTOR_SIZE

        if req_type == self.VIRTIO_BLK_T_IN:
            end = offset + data_len
            if end > len(self.disk):
                self.disk.extend(bytes(end - len(self.disk)))
            self._write_bytes(data_addr, bytes(self.disk[offset:end]))
        elif req_type == self.VIRTIO_BLK_T_OUT:
            chunk = self._read_bytes(data_addr, data_len)
            end = offset + data_len
            if end > len(self.disk):
                self.disk.extend(bytes(end - len(self.disk)))
            self.disk[offset:end] = chunk
        else:
            logger.warning(f'virtio: unsupported request type {req_type}')

        self._write_bytes(status_addr, bytes([0]))  # VIRTIO_BLK_S_OK
        return 0
