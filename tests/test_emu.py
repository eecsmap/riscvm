from binascii import unhexlify
from riscvm.emulator import Emulator

def test_fib():
    data = unhexlify('9300000000000000')
    Emulator(data).run()