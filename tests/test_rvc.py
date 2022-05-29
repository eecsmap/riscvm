from pytest import raises
from riscvm.rv64c import nzimm_5_0
from riscvm.exception import InternalException

def test_nz_error():
    with raises(InternalException):
        nzimm_5_0(0)
