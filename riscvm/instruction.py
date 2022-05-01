from enum import Enum, auto
from textwrap import indent

VERBOSE = True
USE_SYMBOL = True




# TODO: this should be loaded from some csv table instead

mnemonics = {
    0b000_0011: {
        0b000: 'lb', # rv32i
        0b001: 'lh', # rv32i
        0b010: 'lw', # rv32i
        0b011: 'ld', # RV64I
        0b100: 'lbu', # rv32i
        0b101: 'lhu', # rv32i
        0b110: 'lwu', # RV64I
    },
    0b0001111: {
        0b000: 'fence', # rv32i
        0b001: 'fence.i', # rv32i
    },
    0b00_100_11: {
        0b000: 'addi', # rv32i
        0b001: {
            # this to make sure we only shift from 0 to 31 bits
            0b0000000: 'slli', # RV32I
            0b0000001: 'slli', # RV64I
        },
        0b010: 'slti', # rv32i
        0b011: 'sltiu', # rv32i
        0b100: 'xori', # rv32i
        0b101: {
            # this to make sure we only shift from 0 to 31 bits
            0b0000000: 'srli',  # rv32i
            # this to make sure we only shift from 0 to 31 bits
            0b0100000: 'srai',  # rv32i
        },
        0b110: 'ori', # rv32i
        0b111: 'andi', # rv32i
    },
    0b0010111: 'auipc', # rv32i
    0b0011011: {
        # rv64i: addiw
        # rv64i: slliw
        # rv64i: srliw
        # rv64i: sraiw
    },
    0b0100011: {
        0b000: 'sb', # rv32i
        0b001: 'sh', # rv32i
        0b010: 'sw', # rv32i
        0b011: 'sd', # RV64I
    },
    0b0110011: {
        0b000: {
            0b0000000: 'add', # rv32i
            0b0000001: 'mul', # rv32m
            0b0100000: 'sub', # rv32i
        },
        0b001: {
            0b0000000: 'sll', # rv32i
            0b0000001: 'mulh', # rv32m
        },
        0b010: {
            0b0000000: 'slt',  # rv32i
            0b0000001: 'mulhsu', # rv32m
        },
        0b011: {
            0b0000000: 'sltu', # rv32i
            0b0000001: 'mulhu', # rv32m
        },
        0b100: {
            0b0000000: 'xor', # rv32i
            0b0000001: 'div', # rv32m
        },
        0b101: {
            0b0000000: 'srl', # rv32i
            0b0000001: 'divu', # rv32m
            0b0100000: 'sra', # rv32i
        },
        0b110: {
            0b0000000: 'or', # rv32i
            0b0000001: 'rem', # rv32m
        },
        0b111: {
            0b0000000: 'and', # rv32i
            0b0000001: 'remu', # rv32m
        },
    },
    0b0110111: 'lui', # rv32i
    0b0111011: {
        # rv64i: addw
        # rv64i: subw
        # rv64i: sllw
        # rv64i: srlw
        # rv64i: sraw
        # rv64m: mulw
        # rv64m: divw
        # rv64m: divuw
        # rv64m: remw
        # rv64m: remuw
    },
    0b1100011: {
        0b000: 'beq', # rv32i
        0b001: 'bne', # rv32i
        0b100: 'blt', # rv32i
        0b101: 'bge', # rv32i
        0b110: 'bltu', # rv32i
        0b111: 'bgeu', # rv32i
    },
    0b1100111: {
        0b000: 'jalr', # rv32i
    },
    0b1101111: 'jal', # rv32i
    0b1110011: {
        0b000: {
            0b0000000: {
                # rs2
                0b00000: 'ecall', # rv32i
                0b00001: 'ebreak', # rv32i
            }
        },
        0b001: 'csrrw', # rv32i
        0b010: 'csrrs', # rv32i
        0b011: 'csrrc', # rv32i
        0b101: 'csrrwi', # rv32i
        0b110: 'csrrsi', # rv32i
        0b111: 'csrrci', # rv32i
    }
}

mnemonics_a = {
    0b0101111: {
        0b010: {
            0b00000: 'amoadd.w', # rv32a
            0b00001: 'amoswap.w', # rv32a
            0b00010: 'lr.w', # rv32a
            0b00011: 'sc.w', # rv32a
            0b00100: 'amoxor.w', # rv32a
            0b01000: 'amoor.w', # rv32a
            0b01100: 'amoand.w', # rv32a
            0b10000: 'amomin.w', # rv32a
            0b10100: 'amomax.w', # rv32a
            0b11000: 'amominu.w', # rv32a
            0b11100: 'amomaxu.w', # rv32a
        },
        0b011: {
            0b00000: 'amoadd.d', # rv64a
            0b00001: 'amoswap.d', # rv64a
            0b00010: 'lr.d', # rv64a
            0b00011: 'sc.d', # rv64a
            0b00100: 'amoxor.d', # rv64a
            0b01000: 'amoor.d', # rv64a
            0b01100: 'amoand.d', # rv64a
            0b10000: 'amomin.d', # rv64a
            0b10100: 'amomax.d', # rv64a
            0b11000: 'amominu.d', # rv64a
            0b11100: 'amomaxu.d', # rv64a
        }
    }
}

def get_mnemonic(instruction):
    UNDEFINED = 'UD'
    value = mnemonics
    levels = (instruction.opcode, instruction.funct3, instruction.funct7, instruction.rs2)
    
    # for atomic extension
    if instruction.opcode == 0b0101111:
        value = mnemonics_a
        levels = (instruction.opcode, instruction.funct3, instruction.funct7 >> 2)

    for level in levels:
        value = value.get(level, UNDEFINED)
        if not isinstance(value, dict):
            return value
    raise InternalException('incorrect mnemonics definition')



class InternalException(Exception):
    pass

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

def int32(value, nbits):
    assert nbits > 0
    if value >> (nbits - 1) & 1:
        return (value & ((1 << nbits) - 1)) - (1 << nbits)
    return value & ((1 << nbits) - 1)

def section(value, pos, nbits):
    assert pos >= 0
    assert nbits > 0
    assert nbits + pos <= 32
    return value >> pos & ((1 << nbits) - 1)


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

def get_asm(instruction, use_symbol=False):
    reg = regc if use_symbol else regx
    sep = ','
    mnemonic = f'{get_mnemonic(instruction)}'
    if instruction.type is InstructionType.R:
        return mnemonic + '\t' + sep.join([
            f'{reg(instruction.rd)}',
            f'{reg(instruction.rs1)}',
            f'{reg(instruction.rs2)}',
        ])
    if instruction.type is InstructionType.I:
        if instruction.opcode == 0b000_0011:
            return mnemonic + '\t' + sep.join([
                f'{reg(instruction.rd)}',
                f'{instruction.imm_i}({reg(instruction.rs1)})',
            ])
        return mnemonic + '\t' + sep.join([
            f'{reg(instruction.rd)}',
            f'{reg(instruction.rs1)}',
            f'0x{instruction.imm_i & 0b11111:x}' if get_mnemonic(instruction) in ['slli', 'srli', 'srai'] else f'{instruction.imm_i}',
        ])
    if instruction.type is InstructionType.S:
        return mnemonic + '\t' + sep.join([
            f'{reg(instruction.rs2)}',
            f'{instruction.imm_s}({reg(instruction.rs1)})',
        ])
    if instruction.type is InstructionType.B:
        return mnemonic + '\t' + sep.join([
            f'{reg(instruction.rs1)}',
            f'{reg(instruction.rs2)}',
            f'{instruction.imm_b}',
        ])
    if instruction.type is InstructionType.U:
        return mnemonic + '\t' + sep.join([
            f'{reg(instruction.rd)}',
            f'0x{section(instruction.imm_u, 12, 20):x}',
        ])
    if instruction.type is InstructionType.J:
        return mnemonic + '\t' + sep.join([
            f'{reg(instruction.rd)}',
            f'{instruction.imm_j}',
        ])
    return mnemonic

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
        self.value = value

    @property
    def type(self):
        return get_type(self)

    @property
    def opcode_type(self):
        return get_opcode_type(self)

    @property
    def opcode(self):
        return section(self.value, 0, 7)

    @property
    def rd(self):
        return section(self.value, 7, 5)

    @property
    def funct3(self):
        return section(self.value, 12, 3)

    @property
    def rs1(self):
        return section(self.value, 15, 5)

    @property
    def rs2(self):
        return section(self.value, 20, 5)

    @property
    def funct7(self):
        return section(self.value, 25, 7)

    @property
    def imm_i(self):
        return int32(self.funct7 << 5 | self.rs2, 12)

    @property
    def imm_s(self):
        return int32(self.funct7 << 5 | self.rd, 12)

    @property
    def imm_b(self):
        return int32(
            section(self.value, 31, 1) << 12
            | section(self.value, 7, 1) << 11
            | section(self.value, 25, 6) << 5
            | section(self.value, 8, 4) << 1
        , 13)
    
    @property
    def imm_u(self):
        return int32(section(self.value, 12, 20) << 12, 32)

    @property
    def imm_j(self):
        # 20, 10-1, 11, 19-12
        return int32(
            section(self.value, 31, 1) << 20
            | section(self.value, 12, 8) << 12
            | section(self.value, 20, 1) << 11
            | section(self.value, 21, 10) << 1
        , 21)

    @property
    def mnemonic(self):
        get_mnemonic(self)

    @property
    def asm(self):
        return get_asm(self, use_symbol=USE_SYMBOL)

    def __str__(self):
        if VERBOSE:
            return self.asm + '\n' + info(self)
        return self.asm



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


def get_opcode_type(instruction):
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
         
    return InstructionType.UNDEFINED
