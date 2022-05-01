from functools import partial

def u(value, N):
    return value & N

u8 = partial(u, N=(1<<8) - 1)
u16 = partial(u, N=(1<<16) - 1)
u32 = partial(u, N=(1<<32) - 1)
u64 = partial(u, N=(1<<64) - 1)

def i(value, N):
    positive = value & N - 1
    if value & N:
        return positive - N
    return positive

i8 = partial(i, N=1<<7)
i16 = partial(i, N=1<<15)
i32 = partial(i, N=1<<31)
i64 = partial(i, N=1<<63)

# ===========================================================================
# tests
# ===========================================================================
import pytest

d_i8 = (
    (0, 0),
    (1, 1),
    (127, 127),
    (128, -128),
    (-128, -128),
    (-129, 127),
    (255, -1),
    (256, 0),
    (257, 1),
)

@pytest.mark.parametrize('input,expected', d_i8)
def test_i8(input, expected):
    assert i8(input) == expected

def todo():
    raise NotImplementedError()