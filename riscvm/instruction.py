from enum import Enum, auto
from textwrap import indent
from .mnemonics import Mnemonic, get_mnemonic

VERBOSE = True
USE_SYMBOL = True

from .utils import *

class OpCodeType(Enum):
    UNDEFINED = auto()
    LOAD = auto()
    STORE = auto()
    MADD = auto()
    BRANCH = auto()
    LOAD_FP = auto()
    STORE_FP = auto()
    MSUB = auto()
    JALR = auto()
    custom_0 = auto()
    custom_1 = auto()
    custom_2 = auto()
    custom_3 = auto()
    NMSUB = auto()
    reserved = auto()
    MISC_MEM = auto()
    AMO = auto()
    NMADD = auto()
    JAL = auto()
    OP_IMM = auto()
    OP = auto()
    OP_FP = auto()
    SYSTEM = auto()
    AUIPC = auto()
    LUI = auto()
    OP_IMM_32 = auto()
    OP_32 = auto()

    def __str__(self):
        return f'{self.name}'


def opcode_type(instruction):
    '''
    Table 19.1: RISC-V base opcode map, inst[1:0]=11
    '''
    opcode = instruction.opcode
    row = section(opcode, 5, 2)
    col = section(opcode, 2, 3)
    tail = section(opcode, 0, 2)

    if tail != 0b11: return OpCodeType.UNDEFINED
    
    match (row, col):
        case (0b00, 0b000):
            return OpCodeType.LOAD
        case (0b00, 0b001):
            return OpCodeType.LOAD_FP
        case (0b00, 0b010):
            return OpCodeType.custom_0
        case (0b00, 0b011):
            return OpCodeType.MISC_MEM
        case (0b00, 0b100):
            return OpCodeType.OP_IMM
        case (0b00, 0b101):
            return OpCodeType.AUIPC
        case (0b00, 0b110):
            return OpCodeType.OP_IMM_32
        case (0b01, 0b000):
            return OpCodeType.STORE
        case (0b01, 0b001):
            return OpCodeType.STORE_FP
        case (0b01, 0b010):
            return OpCodeType.custom_1
        case (0b01, 0b011):
            return OpCodeType.AMO
        case (0b01, 0b100):
            return OpCodeType.OP
        case (0b01, 0b101):
            return OpCodeType.LUI
        case (0b01, 0b110):
            return OpCodeType.OP_32
        case (0b10, 0b000):
            return OpCodeType.MADD
        case (0b10, 0b001):
            return OpCodeType.MSUB
        case (0b10, 0b010):
            return OpCodeType.NMSUB
        case (0b10, 0b011):
            return OpCodeType.NMADD
        case (0b10, 0b100):
            return OpCodeType.OP_FP
        case (0b10, 0b101):
            return OpCodeType.reserved
        case (0b10, 0b110):
            return OpCodeType.custom_2
        case (0b11, 0b000):
            return OpCodeType.BRANCH
        case (0b11, 0b001):
            return OpCodeType.JALR
        case (0b11, 0b010):
            return OpCodeType.reserved
        case (0b11, 0b011):
            return OpCodeType.JAL
        case (0b11, 0b100):
            return OpCodeType.SYSTEM
        case (0b11, 0b101):
            return OpCodeType.reserved
        case (0b11, 0b110):
            return OpCodeType.custom_3
         
    return OpCodeType.UNDEFINED

class InstructionType(Enum):
    UNDEFINED = auto()
    R = auto()
    I = auto()
    S = auto()
    B = auto()
    U = auto()
    J = auto()

    def __str__(self):
        return f'{self.name}'


def get_type(instruction):
    return {
        0b000_0011: InstructionType.I,
        0b001_0011: InstructionType.I,
        0b001_0111: InstructionType.U,
        0b010_0011: InstructionType.S,
        0b011_0011: InstructionType.R,
        0b011_0111: InstructionType.U,
        0b110_0011: InstructionType.B,
        0b110_0111: InstructionType.I,
        0b110_1111: InstructionType.J,
    }.get(instruction.opcode, InstructionType.UNDEFINED)

def h(content):
    '''hightlight content'''
    return '\x1b[31m' + content + '\x1b[0m'

def s(content, positions):
    for i, c in enumerate(content):
        if i in positions:
            yield ('_')
        yield c

def r(content):
    return list(content)[::-1]

def hs(content, highlights):
    for i, c in enumerate(content):
        yield h(c) if i in highlights else c


def h_opcode(instruction):
    return ''.join(r(s(hs(r(f'{instruction.value:032b}'), {0, 1, 2, 3, 4, 5, 6}), {7, 12, 15, 20, 25})))

def h_rd(instruction):
    return ''.join(r(s(hs(r(f'{instruction.value:032b}'), {7, 8, 9, 10, 11}), {7, 12, 15, 20, 25})))

def h_funct3(instruction):
    return ''.join(r(s(hs(r(f'{instruction.value:032b}'), {12, 13, 14}), {7, 12, 15, 20, 25})))

def h_rs1(instruction):
    return ''.join(r(s(hs(r(f'{instruction.value:032b}'), {15, 16, 17, 18, 19}), {7, 12, 15, 20, 25})))

def h_rs2(instruction):
    return ''.join(r(s(hs(r(f'{instruction.value:032b}'), {20, 21, 22, 23, 24}), {7, 12, 15, 20, 25})))

def h_funct7(instruction):
    return ''.join(r(s(hs(r(f'{instruction.value:032b}'), {25, 26, 27, 28, 29, 30, 31}), {7, 12, 15, 20, 25})))

def h_imm_i(instruction):
    return ''.join(r(s(hs(r(f'{instruction.value:032b}'), {20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31}), {7, 12, 15, 20, 25})))

def h_imm_s(instruction):
    return ''.join(r(s(hs(r(f'{instruction.value:032b}'), {7, 8, 9, 10, 11, 25, 26, 27, 28, 29, 30, 31}), {7, 12, 15, 20, 25})))

def h_imm_b(instruction):
    return ''.join(r(s(hs(r(f'{instruction.value:032b}'), {7, 8, 9, 10, 11, 25, 26, 27, 28, 29, 30, 31}), {7, 12, 15, 20, 25})))

def h_imm_u(instruction):
    return ''.join(r(s(hs(r(f'{instruction.value:032b}'), set(range(12, 32))), {7, 12, 15, 20, 25})))

def h_imm_j(instruction):
    return ''.join(r(s(hs(r(f'{instruction.value:032b}'), set(range(12, 32))), {7, 12, 20, 21, 31})))

def inst_gen(bytes):
    '''read instructions as four bytes from input'''
    # struct.iter_unpack('<I', bytes) requires len(bytes) % 4 == 0
    index = 0
    max_size = len(bytes)
    while index + 4 <= max_size:
        yield int.from_bytes(bytes[index:index+4], byteorder='little')
        index += 4
    
def get_instructions(byte_stream):
    bytes = byte_stream.buffer.read()
    yield from inst_gen(bytes)

def regx(reg_index):
    assert 0 <= reg_index and reg_index < 32
    return f'x{reg_index}'

def regc(reg_index):
    return (
        'zero', 'ra', 'sp', 'gp', 'tp', 't0', 't1', 't2',
        's0', 's1', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7',
        's2', 's3', 's4', 's5', 's6', 's7', 's8', 's9', 's10', 's11',
        't3', 't4', 't5', 't6'
    )[reg_index]

def csr_name(csr_index):
    match csr_index:
        case 0xf14: return 'mhartid'
    return f'0x{csr_index:03x}'

def get_asm(instruction, use_symbol=False, pc=0):
    reg = regc if use_symbol else regx
    sep = ','
    mnemonic = get_mnemonic(instruction)
    mnemonic_sec = f'{mnemonic:4}'
    if instruction.type is InstructionType.R:
        return mnemonic_sec + '\t' + sep.join([
            f'{reg(instruction.rd)}',
            f'{reg(instruction.rs1)}',
            f'{reg(instruction.rs2)}',
        ])
    if instruction.type is InstructionType.I:
        if instruction.opcode == 0b000_0011:
            return mnemonic_sec + '\t' + sep.join([
                f'{reg(instruction.rd)}',
                f'{instruction.imm_i}({reg(instruction.rs1)})',
            ])
        return mnemonic_sec + '\t' + sep.join([
            f'{reg(instruction.rd)}',
            f'{reg(instruction.rs1)}',
            f'0x{instruction.imm_i & 0b11111:x}' if get_mnemonic(instruction) in ['slli', 'srli', 'srai'] else f'{instruction.imm_i}',
        ])
    if instruction.type is InstructionType.S:
        return mnemonic_sec + '\t' + sep.join([
            f'{reg(instruction.rs2)}',
            f'{instruction.imm_s}({reg(instruction.rs1)})',
        ])
    if instruction.type is InstructionType.B:
        return mnemonic_sec + '\t' + sep.join([
            f'{reg(instruction.rs1)}',
            f'{reg(instruction.rs2)}',
            f'{instruction.imm_b + pc:x}',
        ])
    if instruction.type is InstructionType.U:
        return mnemonic_sec + '\t' + sep.join([
            f'{reg(instruction.rd)}',
            f'0x{section(instruction.imm_u, 12, 20):x}',
        ])
    if instruction.type is InstructionType.J:
        return mnemonic_sec + '\t' + sep.join([
            f'{reg(instruction.rd)}',
            f'{instruction.imm_j}',
        ])
    if mnemonic in {Mnemonic.CSRRS}:
        return mnemonic_sec + '\t' + sep.join([
            f'{reg(instruction.rd)}',
            f'{csr_name(instruction.csr)}',
            f'{reg(instruction.rs1)}'
        ])
    return mnemonic_sec

def info(instruction):
    return indent('\n'.join([
        f'0x{instruction.value:08x}',
        instruction.type.name,
        instruction.opcode_type.name,
        'opcode\t:' + h_opcode(instruction) + '\t' + f'0x{instruction.opcode:02x}',
        'rd\t:' + h_rd(instruction) + '\t' + regx(instruction.rd) + '\t' + regc(instruction.rd),
        'funct3\t:' + h_funct3(instruction) + '\t' + f'0x{instruction.funct3:1x}',
        'rs1\t:' + h_rs1(instruction) + '\t' + regx(instruction.rs1) + '\t' + regc(instruction.rs1),
        'rs2\t:' + h_rs2(instruction) + '\t' + regx(instruction.rs2) + '\t' + regc(instruction.rs2),
        'funct7\t:' + h_funct7(instruction) + '\t' + f'0x{instruction.funct7:02x}',
        'I imm\t:' + h_imm_i(instruction) + '\t' + f'{instruction.imm_i}',
        'S imm\t:' + h_imm_s(instruction) + '\t' + f'{instruction.imm_s}',
        'B imm\t:' + h_imm_b(instruction) + '\t' + f'{instruction.imm_b}',
        'U imm\t:' + h_imm_u(instruction) + '\t' + f'{instruction.imm_u}',
        'J imm\t:' + h_imm_j(instruction) + '\t' + f'{instruction.imm_j}',
    ]), '\t')

class Instruction:

    def __init__(self, value):
        self.value = u32(value)

    @property
    def type(self):
        return get_type(self)

    @property
    def opcode_type(self):
        return opcode_type(self)

    @property
    def opcode(self):
        return opcode(self.value)

    @property
    def rd(self):
        return rd(self.value)

    @property
    def funct3(self):
        return funct3(self.value)

    @property
    def rs1(self):
        return rs1(self.value)

    @property
    def rs2(self):
        return rs2(self.value)

    @property
    def funct7(self):
        return funct7(self.value)

    @property
    def imm_i(self):
        return imm_i(self.value)

    @property
    def imm_s(self):
        return imm_s(self.value)

    @property
    def imm_b(self):
        return imm_b(self.value)
    
    @property
    def imm_u(self):
        return imm_u(self.value)

    @property
    def imm_j(self):
        # 20, 10-1, 11, 19-12
        return imm_j(self.value)

    @property
    def mnemonic(self):
        return get_mnemonic(self)
    
    @property
    def shamt(self):
        return shamt(self.value)

    @property
    def csr(self):
        return csr(self.value)

    @property
    def asm(self):
        return get_asm(self, use_symbol=USE_SYMBOL)

    def __str__(self):
        if VERBOSE:
            return self.asm + '\n' + info(self)
        return self.asm
