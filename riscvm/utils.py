from functools import partial

import logging
logger = logging.getLogger(__name__)

# ===========================================================================
# converters of an integer value
# ------------------------------
# Cache these convertors with the hope they are faster than signed(value, nbits)
# since no shifting on the fly.
# ===========================================================================

def _u(value, nbits_mask):
    return value & nbits_mask

u8 = partial(_u, nbits_mask = (1 << 8) - 1)
u16 = partial(_u, nbits_mask = (1 << 16) - 1)
u32 = partial(_u, nbits_mask = (1 << 32) - 1)
u64 = partial(_u, nbits_mask = (1 << 64) - 1)

def _i(value, npower):
    assert npower > 0
    positive = value & (npower - 1)
    if value & npower:
        return positive - npower
    return positive

i6 = partial(_i, npower=1<<5)
i8 = partial(_i, npower=1<<7)
i12 = partial(_i, npower=1<<11)
i13 = partial(_i, npower=1<<12)
i16 = partial(_i, npower=1<<15)
i21 = partial(_i, npower=1<<20)
i32 = partial(_i, npower=1<<31)
i64 = partial(_i, npower=1<<63)

def _test_integers():
    '''
    >>> i8(0)
    0
    >>> i8(1)
    1
    >>> i8(127)
    127
    >>> i8(128)
    -128
    >>> i8(-128)
    -128
    >>> i8(-129)
    127
    >>> i8(255)
    -1
    >>> i8(256)
    0
    >>> i8(257)
    1
    '''

def todo():
    raise NotImplementedError()

# ===========================================================================
# sections of an integer / instruction
# ===========================================================================

def section(value, pos, nbits):
    '''
    Get an n-bit section as unsigned value[pos : pos + nbits].

    >>> section(0b1011, 0, 1)
    1
    >>> section(0b1011, 0, 2)
    3
    >>> section(0b1011, 0, 3)
    3
    >>> section(0b1011, 0, 4)
    11
    >>> section(0b1011, 0, 5)
    11
    >>> section(0b1011, 1, 3)
    5
    >>> section(0b1011, 4, 1)
    0
    >>> section(-1, 2, 3)
    7
    '''
    assert pos >= 0
    assert nbits > 0
    return value >> pos & ((1 << nbits) - 1)

def signed(value, nbits):
    '''
    Parse value as nbits signed integer.
    >>> signed(0, 1)
    0
    >>> signed(1, 1)
    -1
    >>> signed(2, 1)
    0
    >>> signed(5, 1)
    -1
    >>> signed(5, 2)
    1
    >>> signed(5, 3)
    -3
    >>> signed(5, 4)
    5
    '''
    assert nbits > 0
    mask = (1 << nbits) - 1
    positive = value & mask
    if (value >> (nbits - 1)) & 1:
        return positive - mask - 1
    return positive

# rvc: compressed instruction helpers
c_op = partial(section, pos=0, nbits=2)
c_funct3 = partial(section, pos=13, nbits=3)
c_funct4 = partial(section, pos=12, nbits=4)
c_rd = partial(section, pos=7, nbits=5)
c_rs2 = partial(section, pos=2, nbits=5)
c_imm = lambda x: i6(
    section(x, 12, 1) << 5
    | section(x, 2, 5))
c_uimm = lambda x: (
    section(x, 10, 3) << 3
    | section(x, 7, 3) << 6
)
# rv32/64
opcode = partial(section, pos=0, nbits=7)
rd = partial(section, pos=7, nbits=5)
funct3 = partial(section, pos=12, nbits=3)
rs1 = partial(section, pos=15, nbits=5)
rs2 = partial(section, pos=20, nbits=5)
funct7 = partial(section, pos=25, nbits=7)
imm_i = lambda x: i12(funct7(x) << 5 | rs2(x))
imm_s = lambda x: i12(funct7(x) << 5 | rd(x))
imm_b = lambda x: i13(
    section(x, 31, 1) << 12
    | section(x, 7, 1) << 11
    | section(x, 25, 6) << 5
    | section(x, 8, 4) << 1)
imm_u = lambda x: i32(section(x, 12, 20) << 12)
imm_j = lambda x: i21(
    section(x, 31, 1) << 20
    | section(x, 12, 8) << 12
    | section(x, 20, 1) << 11
    | section(x, 21, 10) << 1)
shamt = partial(section, pos=20, nbits=6) # RV64
atomic = lambda x: funct7(x) >> 2
csr = partial(section, pos=20, nbits=12)

def _test_sections():
    '''
    >>> opcode(0b0000110)
    6
    >>> rd(0b00100_0000000)
    4
    >>> funct3(0b011_00000_0000000)
    3
    >>> rs1(0b00001_000_00000_0000000)
    1
    >>> rs2(0b00010_00001_000_00000_0000000)
    2
    >>> funct7(0b0000101_00010_00001_000_00000_0000000)
    5
    >>> imm_i(0b0000001_00001_00000_000_00000_0000000)
    33
    >>> imm_i(0b1000000_00001_00000_000_00000_0000000)
    -2047
    >>> imm_s(0b1000000_00000_00000_000_00011_0000000)
    -2045
    >>> imm_b(0b1000000_00000_00000_000_00010_0000000)
    -4094
    >>> imm_b(0b0000000_00001_00000_000_00011_0000000)
    2050
    >>> imm_u(0b1000000_00000_00000_001_00000_0000000)
    -2147479552
    >>> imm_j(0b1111111_11111_11111_111_00000_0000000)
    -2
    >>> imm_j(0b0000000_00011_00000_000_00000_0000000)
    2050
    '''
