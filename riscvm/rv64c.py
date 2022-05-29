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
from riscvm.exception import error
from riscvm.utils import section, u16, i6, i32, i, regc, lookup_mnemonic

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
rs1 = rd = partial(section, pos=7, nbits=5)
rs2 = partial(section, pos=2, nbits=5)
funct3 = partial(section, pos=13, nbits=3)
funct4 = partial(section, pos=12, nbits=4)
funct6 = partial(section, pos=10, nbits=6)
funct2 = partial(section, pos=5, nbits=2)
rs1_prime = partial(section, pos=7, nbits=3)
rs2_prime = partial(section, pos=2, nbits=3)
bit12 = partial(section, pos=12, nbits=1)

def nz_error():
    error('unexpected zero immediate value')

# SDSP
offset_8_3_sdsp = lambda x: (
    section(x, 10, 3) << 3
    | section(x, 7, 3) << 6
)

# LDSP
offset_8_3_ldsp = lambda x: (
    section(x, 12, 1) << 5
    | section(x, 5, 2) << 3
    | section(x, 2, 3) << 6
)

# SD, LD
offset_7_3 = lambda x: (
    section(x, 10, 3) << 3
    | section(x, 5, 2) << 6
)

# BEQZ, BNEZ
offset_8_1 = lambda x: i(9)(
    section(x, 12, 1) << 8
    | section(x, 10, 2) << 3
    | section(x, 5, 2) << 6
    | section(x, 3, 2) << 1
    | section(x, 2, 1) << 5
)

# J
offset_11_1 = lambda x: i(12)(
    section(x, 12, 1) << 11
    | section(x, 11, 1) << 4
    | section(x, 9, 2) << 8
    | section(x, 8, 1) << 10
    | section(x, 7, 1) << 6
    | section(x, 6, 1) << 7
    | section(x, 3, 3) << 1
    | section(x, 2, 1) << 5
)

# SW, LW
offset_6_2 = lambda x: (
    section(x, 10, 3) << 3
    | section(x, 6, 1) << 2
    | section(x, 5, 1) << 6
)

# ADDI4SPN
nzuimm_9_2 = lambda x: (
    section(x, 11, 2) << 4
    | section(x, 7, 4) << 6
    | section(x, 6, 1) << 2
    | section(x, 5, 1) << 3
) or nz_error()

uimm_5_0 = lambda x: (
    section(x, 12, 1) << 5
    | section(x, 2, 5)
)
# SLLI, SRLI
shamt = nzuimm_5_0 = lambda x: uimm_5_0(x) or nz_error()

# LI, ADDIW, ANDI
imm_5_0 = lambda x: i6(uimm_5_0(x))

# ADDI, LUI
nzimm_5_0 = lambda x: imm_5_0(x) or nz_error()

# ADDI16SP
nzimm_9_4 = lambda x: i(10)(
    section(x, 12, 1) << 9
    | section(x, 6, 1) << 4
    | section(x, 5, 1) << 6
    | section(x, 3, 2) << 7
    | section(x, 2, 1) << 5
) or nz_error()


class Mnemonic(Enum):
    UNDEFINED = auto()
    SDSP = auto()
    LDSP = auto()
    SD = auto()
    LD = auto()
    BEQZ = auto()
    BNEZ = auto()
    J = auto()
    SW = auto()
    LW = auto()
    ADDI4SPN = auto()
    ADDI = auto()
    LUI = auto()
    # C.ADDI16SP is used to adjust the stack pointer in procedure prologues and epilogues
    # in the range (-512, 496) in the granularity of 16 bytes
    ADDI16SP = auto()
    LI = auto()
    ADDIW = auto()
    ANDI = auto()
    SRLI = auto()
    SLLI = auto()
    ADD = auto()
    AND = auto()
    OR = auto()
    JR = auto()
    MV = auto()

    def __str__(self):
        return self.name.lower()

MNEMONICS = {
    0b00: {
        0b000: Mnemonic.ADDI4SPN,
        0b010: Mnemonic.LW,
        0b011: Mnemonic.LD,
        0b110: Mnemonic.SW,
        0b111: Mnemonic.SD,
    },
    0b01: {
        0b000: Mnemonic.ADDI, # NOP is 0x1, yet we don't need to handle it since rd = 0
        0b001: Mnemonic.ADDIW,
        0b010: Mnemonic.LI,
        0b011: lambda x: Mnemonic.ADDI16SP if rd(x.value) == 2 else Mnemonic.LUI,
        0b100: {
            # funct6
            0b100_0_00: Mnemonic.SRLI,
            0b100_1_00: Mnemonic.SRLI,
            0b100_0_10: Mnemonic.ANDI,
            0b100_1_10: Mnemonic.ANDI,
            0b100_0_11: {
                # funct2
                0b10: Mnemonic.OR,
                0b11: Mnemonic.AND,
            },
        },
        0b101: Mnemonic.J,
        0b110: Mnemonic.BEQZ,
        0b111: Mnemonic.BNEZ,
    },
    0b10: {
        0b000: Mnemonic.SLLI,
        0b011: Mnemonic.LDSP,
        0b100: {
            0b0: lambda x: Mnemonic.MV if rs2(x.value) else Mnemonic.JR,
            0b1: lambda x: Mnemonic.ADD if rs2(x.value) else Mnemonic.JALR if rs1(x.value) else Mnemonic.EBREAK,
        },
        0b111: Mnemonic.SDSP,
    },
}

class Instruction:

    size = INSTRUCTION_SIZE_IN_BYTES
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
    def imm_5_0(self):
        return imm_5_0(self.value)

    @property
    def nzimm_5_0(self):
        return nzimm_5_0(self.value)

    @property
    def nzuimm_9_2(self):
        return nzuimm_9_2(self.value)

    @property
    def nzimm_9_4(self):
        return nzimm_9_4(self.value)

    @property
    def offset_6_2(self):
        return offset_6_2(self.value)

    @property
    def offset_7_3(self):
        return offset_7_3(self.value)

    @property
    def offset_8_1(self):
        return offset_8_1(self.value)

    @property
    def offset_8_3_ldsp(self):
        return offset_8_3_ldsp(self.value)

    @property
    def offset_8_3_sdsp(self):
        return offset_8_3_sdsp(self.value)

    @property
    def offset_11_1(self):
        return offset_11_1(self.value)

    @property
    def shamt(self):
        return shamt(self.value)

    #@property
    def asm(self, pc=0):
        return get_asm(self, pc)

    def __str__(self):
        return self.asm()

def get_matchers(instruction):
    '''
    Every instruction has its own decoding pattern.
    '''
    if instruction.op in [0b00, 0b01]:
        return (op, funct3, funct6, funct2)
    if instruction.op == 0b10:
        return (op, funct3, bit12)

def get_mnemonic(instruction):
    return lookup_mnemonic(instruction, get_matchers(instruction), MNEMONICS, Mnemonic.UNDEFINED)

def get_asm(instruction, pc=0):
    mnemonic = get_mnemonic(instruction)
    match mnemonic:
        case Mnemonic.SDSP:
            rest = ','.join([regc(instruction.rs2), f'{instruction.offset_8_3_sdsp}(sp)'])
            return f'sd\t{rest}'
        case Mnemonic.LDSP:
            rest = ','.join([regc(instruction.rd), f'{instruction.offset_8_3_ldsp}(sp)'])
            return f'ld\t{rest}'
        case Mnemonic.SD | Mnemonic.LD:
            rest = ','.join([regc(instruction.rs2_prime), f'{instruction.offset_7_3}({regc(instruction.rs1_prime)})'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.BEQZ | Mnemonic.BNEZ:
            rest = ','.join([regc(instruction.rs1_prime), f'{instruction.offset_8_1 + pc:x}'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.J:
            rest = f'{instruction.offset_11_1 + pc:x}'
            return f'{mnemonic}\t{rest}'
        case Mnemonic.SW | Mnemonic.LW:
            rest = ','.join([regc(instruction.rs2_prime), f'{instruction.offset_6_2}({regc(instruction.rs1_prime)})'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.ADDI4SPN:
            rest = ','.join([regc(instruction.rs2_prime), regc(2), f'{instruction.nzuimm_9_2}'])
            return f'addi\t{rest}'
        case Mnemonic.ADDI:
            rest = ','.join([regc(instruction.rd), regc(instruction.rs1), f'{instruction.nzimm_5_0}'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.LUI:
            rest = ','.join([regc(instruction.rd), f'0x{instruction.nzimm_5_0 & 0xfffff:x}'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.ADDI16SP:
            rest = ','.join([regc(2), regc(2), f'{instruction.nzimm_9_4}'])
            return f'addi\t{rest}'
        case Mnemonic.LI:
            rest = ','.join([regc(instruction.rd), f'{instruction.imm_5_0}'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.ADDIW:
            if instruction.imm_5_0 == 0:
                # spec says sext.w rd yet gcc says sext.w rd,rd :)
                rest = ','.join([regc(instruction.rd), regc(instruction.rd)])
                return f'sext.w\t{rest}'
            rest = ','.join([regc(instruction.rd), regc(instruction.rd), f'{instruction.imm_5_0}'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.ANDI:
            rest = ','.join([regc(instruction.rs1_prime), regc(instruction.rs1_prime), f'{instruction.imm_5_0}'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.SRLI:
            rest = ','.join([regc(instruction.rs1_prime), regc(instruction.rs1_prime), f'0x{instruction.shamt:x}'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.SLLI:
            rest = ','.join([regc(instruction.rd), regc(instruction.rs1), f'0x{instruction.shamt:x}'])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.ADD:
            rest = ','.join([regc(instruction.rd), regc(instruction.rs1), regc(instruction.rs2)])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.AND | Mnemonic.OR:
            rest = ','.join([regc(instruction.rs1_prime), regc(instruction.rs1_prime), regc(instruction.rs2_prime)])
            return f'{mnemonic}\t{rest}'
        case Mnemonic.JR:
            if instruction.rs1 == 1:
                return 'ret'
            return f'{mnemonic}\t{regc(instruction.rs1)}'
        case Mnemonic.MV:
            rest = ','.join([regc(instruction.rs1), regc(instruction.rs2)])
            return f'{mnemonic}\t{rest}'

def actor(instruction, cpu):
    mnemonic = get_mnemonic(instruction)
    new_pc = cpu.pc.value + 2
    match mnemonic:
        case Mnemonic.SDSP:
            # sd rs2, offset[8:3](x2)
            cpu.bus.write(cpu.registers[2].value + instruction.offset_8_3_sdsp, 8, cpu.registers[instruction.rs2].value)
        case Mnemonic.LDSP:
            # ld rd, offset[8:3](x2)
            assert instruction.rd != 0
            cpu.registers[instruction.rd].value = cpu.bus.read(cpu.registers[2].value + instruction.offset_8_3_ldsp, 8)
        case Mnemonic.SD:
            # sd rs2_, offset[7:3](rs1_)
            cpu.bus.write(cpu.registers[instruction.rs1_prime].value + instruction.offset_7_3, 8, cpu.registers[instruction.rs2_prime].value)
        case Mnemonic.LD:
            # ld rs2_, offset[7:3](rs1_)
            cpu.registers[instruction.rs2_prime].value = cpu.bus.read(cpu.registers[instruction.rs1_prime].value + instruction.offset_7_3, 8)
        case Mnemonic.BEQZ:
            # beq rs1_, x0, offset[8:1]
            if cpu.registers[instruction.rs1_prime].value == 0:
                new_pc = cpu.pc.value + instruction.offset_8_1
        case Mnemonic.BNEZ:
            # bne rs1_, x0, offset[8:1]
            if cpu.registers[instruction.rs1_prime].value != 0:
                new_pc = cpu.pc.value + instruction.offset_8_1
        case Mnemonic.J:
            # jal x0, offset[11:1]
            new_pc = cpu.pc.value + instruction.offset_11_1
        case Mnemonic.SW:
            # sw rs2_, offset[6:2](rs1_)
            cpu.bus.write(cpu.registers[instruction.rs1_prime].value + instruction.offset_6_2, 4, cpu.registers[instruction.rs2_prime].value)
        case Mnemonic.LW:
            # lw rd_, offset[6:2](rs1_)
            cpu.registers[instruction.rs2_prime].value = i32(cpu.bus.read(cpu.registers[instruction.rs1_prime].value + instruction.offset_6_2, 4))
        case Mnemonic.ADDI4SPN:
            # addi rd_, x2, nzuimm[9:2]
            assert instruction.nzuimm_9_2 != 0
            cpu.registers[instruction.rs2_prime].value = cpu.registers[2].value + instruction.nzuimm_9_2
        case Mnemonic.ADDI:
            # addi rd, rd, nzimm[5:0]
            cpu.registers[instruction.rd].value += instruction.nzimm_5_0
        case Mnemonic.LUI:
            # lui rd, nzuimm[17:12]
            assert instruction.rd not in {0, 2}
            # well, according to what the spec describes, it is actually nzimm_5_0
            assert instruction.nzimm_5_0 != 0
            cpu.registers[instruction.rd].value = instruction.nzimm_5_0 << 12
        case Mnemonic.ADDI16SP:
            # addi x2, x2, nzimm[9:4]
            assert instruction.rd == 2
            assert instruction.nzimm_9_4 != 0
            cpu.registers[2].value += instruction.nzimm_9_4
        case Mnemonic.LI:
            # addi rd, x0, imm[5:0]
            assert instruction.rd != 0
            cpu.registers[instruction.rd].value = instruction.imm_5_0
        case Mnemonic.ADDIW:
            # addiw rd, rd, imm[5:0]
            # sext.w rd
            assert instruction.rd != 0
            cpu.registers[instruction.rd].value += i32(cpu.registers[instruction.rd].value) + instruction.imm_5_0
        case Mnemonic.ANDI:
            # andi rd_, rd_, imm[5:0]
            cpu.registers[instruction.rs1_prime].value &= instruction.imm_5_0
        case Mnemonic.SRLI:
            # srli rd_, rd_, shamt[5:0]
            assert instruction.shamt != 0
            # register values are unsigned so it is logic shift by default
            cpu.registers[instruction.rs1_prime].value >>= instruction.shamt
        case Mnemonic.SLLI:
            # slli rd, rd, shamt[5:0]
            assert instruction.shamt != 0
            cpu.registers[instruction.rd].value <<= instruction.shamt
        case Mnemonic.ADD:
            # add rd, rd, rs2
            assert instruction.rd != 0
            assert instruction.rs2 != 0
            cpu.registers[instruction.rd].value += cpu.registers[instruction.rs2].value
        case Mnemonic.AND:
            # and rd_, rd_, rs2_
            cpu.registers[instruction.rs1_prime].value &= cpu.registers[instruction.rs2_prime].value
        case Mnemonic.OR:
            # or rd_, rd_, rs2_
            cpu.registers[instruction.rs1_prime].value |= cpu.registers[instruction.rs2_prime].value
        case Mnemonic.JR:
            # jalr x0, rs1, 0
            assert instruction.rs1 != 0
            assert instruction.rs2 == 0
            new_pc = cpu.registers[instruction.rs1].value
        case Mnemonic.MV:
            # add rd, x0, rs2
            assert instruction.rs1 != 0
            assert instruction.rs2 != 0
            cpu.registers[instruction.rs1].value = cpu.registers[instruction.rs2].value
        
        case _:
            error('invalid instruction')
    cpu.pc.value = new_pc
