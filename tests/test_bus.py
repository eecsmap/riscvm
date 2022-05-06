from riscvm.bus import Bus
from riscvm.exception import InternalException
from pytest import raises

def test_invalid_address():
    bus = Bus()
    with raises(InternalException):
        # read 4 bytes from a gap (no device mapped)
        bus.read(0, 4)
