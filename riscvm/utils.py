from functools import partial

import logging
logger = logging.getLogger(__name__)

# ===========================================================================
# converters of an integer value
# ------------------------------
# Cache these convertors with the hope they are faster than signed(value, nbits)
# since no shifting on the fly.
# ===========================================================================

def regc(reg_index):
    return (
        'zero', 'ra', 'sp', 'gp', 'tp', 't0', 't1', 't2',
        's0', 's1', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7',
        's2', 's3', 's4', 's5', 's6', 's7', 's8', 's9', 's10', 's11',
        't3', 't4', 't5', 't6'
    )[reg_index]

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

def i(n):
    return partial(_i, npower=1<<n-1)

i6 = partial(_i, npower=1<<5)
i8 = partial(_i, npower=1<<7)
i9 = partial(_i, npower=1<<8)
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

def lookup_mnemonic(instruction, matcher, mnemonics, default):
    value = mnemonics
    levels = matcher
    for level in levels:
        value = value.get(level(instruction.value), default)
        if callable(value):
            return value(instruction)
        if not isinstance(value, dict):
            return value
    return default
    