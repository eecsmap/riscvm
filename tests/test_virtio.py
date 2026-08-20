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

def test_disk_image_backs_the_synthetic_disk():
    bus = Bus()
    ram = RAM(0x10000)
    bus.add_device(ram, (0, len(ram)))
    image = bytes([0xAB]) * 512 + bytes(512)  # sector 0 = 0xAB..., sector 1 = zero
    dev = VirtIOBlk(bus, disk_image=image)
    assert dev.disk[:512] == bytes([0xAB]) * 512
    assert dev.disk[512:1024] == bytes(512)

def test_disk_image_smaller_than_disk_size_is_zero_padded():
    bus = Bus()
    ram = RAM(0x10000)
    bus.add_device(ram, (0, len(ram)))
    dev = VirtIOBlk(bus, disk_size=4096, disk_image=bytes([1, 2, 3]))
    assert len(dev.disk) == 4096
    assert dev.disk[:3] == bytes([1, 2, 3])
    assert dev.disk[3] == 0

def test_identification():
    bus, dev = make_device()
    assert bus.read(0x10001000 + VirtIOBlk.MAGIC_VALUE, 4) == VirtIOBlk.MAGIC
    assert bus.read(0x10001000 + VirtIOBlk.VERSION, 4) == 2
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

def setup_queue(bus, dev, desc_addr=0x2000, avail_addr=0x3000, used_addr=0x4000, queue_num=8):
    bus.write(0x10001000 + VirtIOBlk.QUEUE_SEL, 4, 0)
    bus.write(0x10001000 + VirtIOBlk.QUEUE_NUM, 4, queue_num)
    bus.write(0x10001000 + VirtIOBlk.QUEUE_DESC_LOW, 4, desc_addr & 0xffffffff)
    bus.write(0x10001000 + VirtIOBlk.QUEUE_DESC_HIGH, 4, desc_addr >> 32)
    bus.write(0x10001000 + VirtIOBlk.DRIVER_DESC_LOW, 4, avail_addr & 0xffffffff)
    bus.write(0x10001000 + VirtIOBlk.DRIVER_DESC_HIGH, 4, avail_addr >> 32)
    bus.write(0x10001000 + VirtIOBlk.DEVICE_DESC_LOW, 4, used_addr & 0xffffffff)
    bus.write(0x10001000 + VirtIOBlk.DEVICE_DESC_HIGH, 4, used_addr >> 32)
    bus.write(0x10001000 + VirtIOBlk.QUEUE_READY, 4, 1)
    return desc_addr, avail_addr, used_addr, queue_num

def test_queue_desc_addr_roundtrips_across_low_high_halves():
    bus, dev = make_device()
    bus.write(0x10001000 + VirtIOBlk.QUEUE_DESC_LOW, 4, 0x12345678)
    bus.write(0x10001000 + VirtIOBlk.QUEUE_DESC_HIGH, 4, 0x9abcdef0)
    assert dev.desc_addr == 0x9abcdef012345678

def test_queue_ready_roundtrip():
    bus, dev = make_device()
    assert bus.read(0x10001000 + VirtIOBlk.QUEUE_READY, 4) == 0
    bus.write(0x10001000 + VirtIOBlk.QUEUE_READY, 4, 1)
    assert bus.read(0x10001000 + VirtIOBlk.QUEUE_READY, 4) == 1

def test_block_read_returns_disk_contents():
    bus, dev = make_device()
    desc_base, avail_base, used_base, num = setup_queue(bus, dev)

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
    desc_base, avail_base, used_base, num = setup_queue(bus, dev)

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
