from binascii import unhexlify
from riscvm.emulator import Emulator, XV6
from riscvm.exception import InternalException
from pytest import raises

# code are put as hex string for two reasons:
# 1. easy to write the tests.
# 2. tests run faster without reading test programs from files.
# Refer to project README to get instructions on how to build test programs.

def test_fib():
    code = unhexlify('9307f5ff6354a00213071000930600001306f0ff130507009387f7ff3307d70093060500e398c7fe678000001305000067800000')
    load_address = 0x1000 # load code to first page; this is just a demo with arbitrary value
    emulator = Emulator(code, address=load_address)
    emulator.cpu.registers[10].value = 80 # set a0 to 80 to get fib(80)
    with raises(InternalException):
        emulator.run()
    assert emulator.cpu.registers[10].value == 23416728348467685

def test_xv6_disk_image_reaches_the_virtio_device():
    image = bytes([0x11, 0x22, 0x33, 0x44]) + bytes(4092)
    xv6 = XV6(bytes(64), address=0x80000000, disk_image=image)
    virtio_disk_base = 0x10001000
    device, rng = xv6.cpu.bus.get_device(virtio_disk_base, 1)
    assert device.disk[:4] == bytes([0x11, 0x22, 0x33, 0x44])
