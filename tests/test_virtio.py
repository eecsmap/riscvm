from riscvm import Bus, RAM
from riscvm.virtio import VirtIOBlk

DESC = 0
LEN = 8
FLAGS = 12
NEXT = 14

def make_device():
    bus = Bus()
    ram = RAM(0x10000)
    bus.add_device(ram, (0, len(ram)))
    dev = VirtIOBlk(bus)
    bus.add_device(dev, (0x10001000, len(dev)))
    return bus, dev

def test_identification():
    bus, dev = make_device()
    assert bus.read(0x10001000 + VirtIOBlk.MAGIC_VALUE, 4) == VirtIOBlk.MAGIC
    assert bus.read(0x10001000 + VirtIOBlk.VERSION, 4) == 1
    assert bus.read(0x10001000 + VirtIOBlk.DEVICE_ID, 4) == 2
    assert bus.read(0x10001000 + VirtIOBlk.VENDOR_ID, 4) == VirtIOBlk.VENDOR

def test_queue_num_max_is_never_the_blocker():
    bus, dev = make_device()
    assert bus.read(0x10001000 + VirtIOBlk.QUEUE_NUM_MAX, 4) >= 8

def test_status_roundtrip():
    bus, dev = make_device()
    bus.write(0x10001000 + VirtIOBlk.STATUS, 4, 0xf)
    assert bus.read(0x10001000 + VirtIOBlk.STATUS, 4) == 0xf

def write_desc(bus, table_addr, idx, addr, length, flags, nxt):
    off = table_addr + idx * 16
    bus.write(off, 8, addr)
    bus.write(off + 8, 4, length)
    bus.write(off + 12, 2, flags)
    bus.write(off + 14, 2, nxt)

def setup_queue(bus, dev, queue_pfn=1, queue_num=8):
    bus.write(0x10001000 + VirtIOBlk.QUEUE_SEL, 4, 0)
    bus.write(0x10001000 + VirtIOBlk.QUEUE_NUM, 4, queue_num)
    bus.write(0x10001000 + VirtIOBlk.QUEUE_PFN, 4, queue_pfn)
    return queue_pfn * 0x1000, queue_num

def test_block_read_returns_disk_contents():
    bus, dev = make_device()
    base, num = setup_queue(bus, dev)
    desc_base = base
    avail_base = base + num * 16
    used_base = base + 0x1000

    # seed the synthetic disk at sector 3 so we can tell a real read happened
    dev.disk[3 * 512:3 * 512 + 4] = b'\xde\xad\xbe\xef'

    header_addr = 0x8000
    data_addr = 0x9000
    status_addr = 0xa000

    bus.write(header_addr, 4, VirtIOBlk.VIRTIO_BLK_T_IN)
    bus.write(header_addr + 8, 8, 3)  # sector

    write_desc(bus, desc_base, 0, header_addr, 16, VirtIOBlk.VIRTQ_DESC_F_NEXT, 1)
    write_desc(bus, desc_base, 1, data_addr, 512, VirtIOBlk.VIRTQ_DESC_F_NEXT | VirtIOBlk.VIRTQ_DESC_F_WRITE, 2)
    write_desc(bus, desc_base, 2, status_addr, 1, VirtIOBlk.VIRTQ_DESC_F_WRITE, 0)

    bus.write(avail_base + 4, 2, 0)  # avail.ring[0] = descriptor head 0
    bus.write(avail_base + 2, 2, 1)  # avail.idx = 1

    bus.write(0x10001000 + VirtIOBlk.QUEUE_NOTIFY, 4, 0)

    assert bus.read(data_addr, 4) == 0xefbeadde  # little-endian read back of DE AD BE EF
    assert bus.read(status_addr, 1) == 0
    assert bus.read(used_base + 2, 2) == 1  # used.idx advanced
    assert bus.read(used_base + 4, 4) == 0  # used.ring[0].id == descriptor head
    assert dev.interrupt_status & 1

def test_block_write_persists_to_disk():
    bus, dev = make_device()
    base, num = setup_queue(bus, dev)
    desc_base = base
    avail_base = base + num * 16

    header_addr = 0x8000
    data_addr = 0x9000
    status_addr = 0xa000

    bus.write(header_addr, 4, VirtIOBlk.VIRTIO_BLK_T_OUT)
    bus.write(header_addr + 8, 8, 5)  # sector
    bus.write(data_addr, 4, 0x01020304)

    write_desc(bus, desc_base, 0, header_addr, 16, VirtIOBlk.VIRTQ_DESC_F_NEXT, 1)
    write_desc(bus, desc_base, 1, data_addr, 4, VirtIOBlk.VIRTQ_DESC_F_NEXT, 2)
    write_desc(bus, desc_base, 2, status_addr, 1, VirtIOBlk.VIRTQ_DESC_F_WRITE, 0)

    bus.write(avail_base + 4, 2, 0)
    bus.write(avail_base + 2, 2, 1)

    bus.write(0x10001000 + VirtIOBlk.QUEUE_NOTIFY, 4, 0)

    assert dev.disk[5 * 512:5 * 512 + 4] == b'\x04\x03\x02\x01'
    assert bus.read(status_addr, 1) == 0

def test_interrupt_ack_clears_status():
    bus, dev = make_device()
    dev.interrupt_status = 1
    bus.write(0x10001000 + VirtIOBlk.INTERRUPT_ACK, 4, 1)
    assert dev.interrupt_status == 0
