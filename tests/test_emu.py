from binascii import unhexlify
from riscvm.emulator import Emulator
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
