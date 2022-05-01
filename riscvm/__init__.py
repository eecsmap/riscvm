'''
refer to https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf

Chapter 19 RV32/64G Instruction Set Listings

G = IMAFD
'''
# Make sure organize modules in topological order
from .exception import RV64Exception, error
from .utils import *
from .mport import gen
from .instruction import Instruction, get_asm, inst_gen, int32
from .register import Register
from .ram import RAM, create_ram
from .bus import Bus
from .cpu import CPU
