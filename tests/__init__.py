import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import pytest

from riscvm.utils import i8

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