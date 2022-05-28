# This module is to implement the "C" Standard Extension for Compressed Instructions, Version 2.0
# described here in chapter 16:
#
#   https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf
#

# RVC can be added to any of the base ISAs (RV32, RV64, RV128)

# Typically, 50%-60% of the RISC-V instructions in a program can be replaced with RVC instructions,
# resulting in a 25%-30% code-size reduction.

# used when:
# 1. the immeidate or address offset is small
# 2. one of the registers is the zero register (x0), the ABI link register (x1), or the ABI stack point (x2)
# 3. the destination register and the first source register are identical
# 4. the registers used are the 8 most popular ones

from enum import Enum, auto
from functools import partial
from .utils import section, u16, i6
from .instruction import regc
from .exception import error

# we are based on rv64
BASE_ISA = 'RV64'

INSTRUCTION_SIZE_IN_BITS = 16
INSTRUCTION_SIZE_IN_BYTES = 2

# every RVC instruction expands to a single 32-bit instruction in the base ISA (RV32I/RV32E/RV64I/RV128I)
# or the F and D standrad extensions.
# TODO: provide the translate might be useful.
# we might be able to do the translate in decode phase!

# There are nine compressed instruction format!

class RVC_Type(Enum):
    UNDEFINED = auto()
    CR  = auto()    # Register
    CI  = auto()    # Immediate
    CSS = auto()    # Stack-relative Store
    CIW = auto()    # Wide Immediate
    CL  = auto()    # Load
    CS  = auto()    # Store
    CA  = auto()    # Arithmetic
    CB  = auto()    # Branch
    CJ  = auto()    # Jump

    # def __str__(self):
    #     return f'{self.name}'.replace('_', '.')

# popular registers: x8 - x15
# Integer Register Number:      x8  x9  x10 x11 x12 x13 x14 x15
# Integer Reigster ABI Name:    s0  s1  a0  a1  a2  a3  a4  a5
# Floating-Point Register Name: f8  f9  f10 f11 f12 f13 f14 f15
# FP Register ABI Name:         fs0 fs1 fa0 fa1 fa2 fa3 fa4 fa5
# RV calling convention uses popular registers frequently.
# Meanwhile, RV32E has only 16 registers :)

# convert popular registers to normal registers
pop2regx = lambda x: x + 8

# SECTIONS
op = partial(section, pos=0, nbits=2)
rd = partial(section, pos=7, nbits=5)
rs1 = rd
rs2 = partial(section, pos=2, nbits=5)
funct3 = partial(section, pos=13, nbits=3)
funct4 = partial(section, pos=12, nbits=4)
funct6 = partial(section, pos=10, nbits=6)
funct2 = partial(section, pos=5, nbits=2)
rs1_prime = partial(section, pos=7, nbits=3)
rs2_prime = partial(section, pos=2, nbits=3)
rd_prime = rs2_prime
rd_prime_ca = rs1_prime
bit12 = partial(section, pos=12, nbits=1)

offset_8_3 = lambda x: (
    section(x, 10, 3) << 3
    | section(x, 7, 3) << 6
)

nzuimm_9_2 = lambda x: (
    section(x, 5, 1) << 3
    | section(x, 6, 1) << 2
    | section(x, 7, 4) << 6
    | section(x, 11, 2) << 4
)

nzimm_5_0 = lambda x: i6(
    section(x, 12, 1) << 5
    | section(x, 2, 5)
)

nzimm_17_12 = lambda x: i6(
    section(x, 12, 1) << 5
    | section(x, 2, 5)
)

offset_lwsp = lambda x: (
    section(x, 12, 1) << 5
    | section(x, 4, 2) << 2
    | section(x, 2, 2) << 6
) << 2


class Mnemonic(Enum):
    UNDEFINED = auto()
    LWSP = auto()
    LDSP = auto()
    LQSP = auto()
    FLWSP = auto()
    FLDSP = auto()
    LUI = auto()
    ADDI = auto()
    ADD = auto()
    SDSP = auto()
    ADDI4SPN = auto()
    AND = auto()
    OR = auto()

    def __str__(self):
        return f'C.{self.name}'.lower()

MNEMONICS = {
    0b00: {
        0b000: Mnemonic.ADDI4SPN,
    },
    0b01: {
        0b011: Mnemonic.LUI,
        0b000: Mnemonic.ADDI,
        0b100: {
            # funct6
            0b100_011: {
                # funct2
                0b10: Mnemonic.OR,
                0b11: Mnemonic.AND,
            },
        },
    },
    0b10: {
        0b001: Mnemonic.FLDSP,
        0b010: Mnemonic.LWSP,
        0b011: Mnemonic.LDSP,
        0b100: {
            0b1: lambda x: Mnemonic.ADD if rs2(x.value) else Mnemonic.JALR
        },
        0b111: Mnemonic.SDSP,
    },
}

class Instruction:
    size = 2
    is_compressed = True
    def __init__(self, value):
        self.value = u16(value)

    @property
    def type(self):
        return get_type(self)

    @property
    def op(self):
        return op(self.value)

    @property
    def rd(self):
        return rd(self.value)

    @property
    def rs1(self):
        return rs1(self.value)

    @property
    def rs2(self):
        return rs2(self.value)

    @property
    def rs1_prime(self):
        return rs1_prime(self.value) + 8

    @property
    def rs2_prime(self):
        return rs2_prime(self.value) + 8

    @property
    def rd_prime_ca(self):
        return rd_prime_ca(self.value) + 8

    @property
    def rd_prime(self):
        return rd_prime(self.value) + 8

    @property
    def nzimm_5_0(self):
        return nzimm_5_0(self.value)

    @property
    def nzimm_17_12(self):
        return nzimm_17_12(self.value)

    @property
    def offset_8_3(self):
        return offset_8_3(self.value)

    @property
    def nzuimm_9_2(self):
        return nzuimm_9_2(self.value)

    @property
    def asm(self):
        return get_asm(self)

    def __str__(self):
        return self.asm

def get_matchers(instruction):
    '''
    Every instruction has its own decoding pattern.
    '''
    if instruction.op in [0b00, 0b01]:
        return (op, funct3, funct6, funct2)
    if instruction.op == 0b10:
        return (op, funct3, bit12)

def get_mnemonic(instruction):
    value = MNEMONICS
    levels = get_matchers(instruction)
    for level in levels:
        value = value.get(level(instruction.value), Mnemonic.UNDEFINED)
        if callable(value):
            return value(instruction)
        if not isinstance(value, dict):
            return value
    return Mnemonic.UNDEFINED

def get_asm(instruction):
    mnemonic = get_mnemonic(instruction)
    match mnemonic:
        case Mnemonic.LUI:
            rest = ','.join([regc(instruction.rd), f'0x{instruction.nzimm_17_12 & 0xfffff:x}'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.ADDI:
            rest = ','.join([regc(instruction.rd), regc(instruction.rs1), f'{instruction.nzimm_5_0}'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.ADD:
            rest = ','.join([regc(instruction.rd), regc(instruction.rs1), regc(instruction.rs2)])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.SDSP:
            rest = ','.join([regc(instruction.rs2), f'{instruction.offset_8_3}(sp)'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.ADDI4SPN:
            rest = ','.join([regc(instruction.rd_prime), regc(2), f'{instruction.nzuimm_9_2}'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.AND | Mnemonic.OR:
            rest = ','.join([regc(instruction.rd_prime_ca), regc(instruction.rs1_prime), regc(instruction.rs2_prime)])
            return f'{mnemonic}\t{rest}'

def actor(instruction, cpu):
    mnemonic = get_mnemonic(instruction)
    match mnemonic:
        case Mnemonic.LUI:
            # lui rd, nzimm[17:12]
            assert instruction.rd not in {0, 2}
            assert instruction.nzimm_17_12 != 0
            cpu.registers[instruction.rd].value = instruction.nzimm_17_12 << 12
        case Mnemonic.ADDI:
            # addi rd, rd, nzimm[5:0]
            assert instruction.rd != 0
            assert instruction.nzimm_5_0 != 0
            cpu.registers[instruction.rd].value += instruction.nzimm_5_0
        case Mnemonic.ADD:
            assert instruction.rd != 0
            assert instruction.rs2 != 0
            cpu.registers[instruction.rd].value += cpu.registers[instruction.rs2].value
        case Mnemonic.SDSP:
            cpu.bus.write(cpu.registers[2].value + instruction.offset_8_3, 8, cpu.registers[instruction.rs2].value)
        case Mnemonic.ADDI4SPN:
            # addi rd_, x2, nzuimm[9:2]
            assert instruction.nzuimm_9_2 != 0
            cpu.registers[instruction.rd_prime].value = cpu.registers[2].value + instruction.nzuimm_9_2
        case Mnemonic.AND:
            # and rd_, rd_, rs2_
            cpu.registers[instruction.rd_prime_ca].value = cpu.registers[instruction.rs1_prime].value & cpu.registers[instruction.rs2_prime].value
        case Mnemonic.OR:
            # or rd_, rd_, rs2_
            cpu.registers[instruction.rd_prime_ca].value = cpu.registers[instruction.rs1_prime].value | cpu.registers[instruction.rs2_prime].value
        
        case Mnemonic.LWSP:
            # lw rd, offset[7:2](x2)
            assert instruction.rd != 0
            
            print(instruction)
        case _:
            error('invalid instruction')
    cpu.pc.value += 2
