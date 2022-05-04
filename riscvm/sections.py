from functools import partial

def section(value, pos, nbits):
    '''
    Get n-bit section as value[pos:pos+nbits].
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
    # assert nbits + pos <= 32
    return value >> pos & ((1 << nbits) - 1)

def int32(value, nbits):
    '''
    Parse value as nbits signed integer.
    >>> int32(1, 1)
    -1
    >>> int32(5, 1)
    -1
    >>> int32(5, 2)
    1
    >>> int32(5, 3)
    -3
    >>> int32(5, 4)
    5
    '''
    assert nbits > 0
    mask = (1 << nbits) - 1
    positive = value & mask
    signed = (value >> (nbits - 1)) & 1
    if signed:
        return positive - mask - 1
    return positive

opcode = partial(section, pos=0, nbits=7)
rd = partial(section, pos=7, nbits=5)
funct3 = partial(section, pos=12, nbits=3)
rs1 = partial(section, pos=15, nbits=5)
rs2 = partial(section, pos=20, nbits=5)
funct7 = partial(section, pos=25, nbits=7)
imm_i = lambda x: int32(funct7(x) << 5 | rs2(x), 12)
imm_s = lambda x: int32(funct7(x) << 5 | rd(x), 12)
imm_b = lambda x: int32(
    section(x, 31, 1) << 12
    | section(x, 7, 1) << 11
    | section(x, 25, 6) << 5
    | section(x, 8, 4) << 1, 13)
imm_u = lambda x: int32(section(x, 12, 20) << 12, 32)
imm_j = lambda x: int32(
    section(x, 31, 1) << 20
    | section(x, 12, 8) << 12
    | section(x, 20, 1) << 11
    | section(x, 21, 10) << 1, 21)
shamt = partial(section, pos=20, nbits=6) # RV64
atomic = lambda x: funct7(x) >> 2

def test_sections():
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
