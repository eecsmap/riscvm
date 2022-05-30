from enum import Enum, auto
from textwrap import indent

import logging
logger = logging.getLogger(__name__)

VERBOSE = True
USE_SYMBOL = True

from riscvm.csr import CSR
from riscvm.utils import lookup_mnemonic, i, i8, i16, i32, i64, u8, u16, u32, u64, regc, partial, section

# rv32/64
opcode = partial(section, pos=0, nbits=7)
rd = partial(section, pos=7, nbits=5)
funct3 = partial(section, pos=12, nbits=3)
rs1 = partial(section, pos=15, nbits=5)
rs2 = partial(section, pos=20, nbits=5)
funct7 = partial(section, pos=25, nbits=7)
imm_i = lambda x: i(12)(funct7(x) << 5 | rs2(x))
imm_s = lambda x: i(12)(funct7(x) << 5 | rd(x))
imm_b = lambda x: i(13)(
    section(x, 31, 1) << 12
    | section(x, 7, 1) << 11
    | section(x, 25, 6) << 5
    | section(x, 8, 4) << 1)
imm_u = lambda x: i32(section(x, 12, 20) << 12)
imm_j = lambda x: i(21)(
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

class Mnemonic(Enum):
    UNDEFINED = auto()
    # RV32I Base Instruction Set
    LUI = auto()
    AUIPC = auto()
    JAL = auto()
    JALR = auto()
    BEQ = auto()
    BNE = auto()
    BLT = auto()
    BGE = auto()
    BLTU = auto()
    BGEU = auto()
    LB = auto()
    LH = auto()
    LW = auto()
    LBU = auto()
    LHU = auto()
    SB = auto()
    SH = auto()
    SW = auto()
    ADDI = auto()
    SLTI = auto()
    SLTIU = auto()
    XORI = auto()
    ORI = auto()
    ANDI = auto()
    SLLI = auto()
    SRLI = auto()
    SRAI = auto()
    ADD = auto()
    SUB = auto()
    SLL = auto()
    SLT = auto()
    SLTU = auto()
    XOR = auto()
    SRL = auto()
    SRA = auto()
    OR = auto()
    AND = auto()
    FENCE = auto()
    ECALL = auto()
    EBREAK = auto()
    # RV64I Base Instruction Set
    LWU = auto()
    LD = auto()
    SD = auto()
    #SLLI = auto()
    #SRLI = auto()
    #SRAI = auto()
    ADDIW = auto()
    SLLIW = auto()
    SRLIW = auto()
    SRAIW = auto()
    ADDW = auto()
    SUBW = auto()
    SLLW = auto()
    SRLW = auto()
    SRAW = auto()
    # RV32/RV64 Zifencei
    FENCE_I = auto()
    # RV32/RV64 Zicsr
    CSRRW = auto()
    CSRRS = auto()
    CSRRC = auto()
    CSRRWI = auto()
    CSRRSI = auto()
    CSRRCI = auto()
    # RV32M
    MUL = auto()
    MULH = auto()
    MULHSU = auto()
    MULHU = auto()
    DIV = auto()
    DIVU = auto()
    REM = auto()
    REMU = auto()
    # RV64M
    MULW = auto()
    DIVW = auto()
    DIVUW = auto()
    REMW = auto()
    REMUW = auto()
    # RV32A
    LR_W = auto()
    SC_W = auto()
    AMOSWAP_W = auto()
    AMOADD_W = auto()
    AMOXOR_W = auto()
    AMOAND_W = auto()
    AMOOR_W = auto()
    AMOMIN_W = auto()
    AMOMAX_W = auto()
    AMOMINU_W = auto()
    AMOMAXU_W = auto()
    # RV64A
    LR_D = auto()
    SC_D = auto()
    AMOSWAP_D = auto()
    AMOADD_D = auto()
    AMOXOR_D = auto()
    AMOAND_D = auto()
    AMOOR_D = auto()
    AMOMIN_D = auto()
    AMOMAX_D = auto()
    AMOMINU_D = auto()
    AMOMAXU_D = auto()
    # Privileged
    MRET = auto()
    # Compressed
    C_LUI = auto()
    C_ADDI = auto()
    C_ADD = auto()
    C_SDSP = auto()
    C_ADDI4SPN = auto()

    def __str__(self):
        return f'{self.name}'.replace('_', '.')

MNEMONICS = {

    # rv32/64
    0b00_000_11: {
        0b000: Mnemonic.LB,
        0b001: Mnemonic.LH,
        0b010: Mnemonic.LW,
        0b011: Mnemonic.LD,
        0b100: Mnemonic.LBU,
        0b101: Mnemonic.LHU,
        0b110: Mnemonic.LWU,
    },
    0b00_011_11: {
        0b000: Mnemonic.FENCE,
        0b001: Mnemonic.FENCE_I,
    },
    0b00_100_11: {
        0b000: Mnemonic.ADDI,
        0b001: {
            0b0000000: Mnemonic.SLLI,
            0b0000001: Mnemonic.SLLI, # RV64I
        },
        0b010: Mnemonic.SLTI,
        0b011: Mnemonic.SLTIU,
        0b100: Mnemonic.XORI,
        0b101: {
            0b0000000: Mnemonic.SRLI,
            0b0000001: Mnemonic.SRLI,  # RV64I
            0b0100000: Mnemonic.SRAI,
            0b0100001: Mnemonic.SRAI,  # RV64I
        },
        0b110: Mnemonic.ORI,
        0b111: Mnemonic.ANDI,
    },
    0b00_101_11: Mnemonic.AUIPC,
    0b00_110_11: {
        0b000: Mnemonic.ADDIW,
        0b001: {
            0b0000000: Mnemonic.SLLIW,
        },
        0b101: {
            0b0000000: Mnemonic.SRLIW,
            0b0100000: Mnemonic.SRAIW,
        },
    },
    0b01_000_11: {
        0b000: Mnemonic.SB,
        0b001: Mnemonic.SH,
        0b010: Mnemonic.SW,
        0b011: Mnemonic.SD,
    },
    0b01_011_11: {
        0b010: {
            0b00000: Mnemonic.AMOADD_W,
            0b00001: Mnemonic.AMOSWAP_W,
            0b00010: Mnemonic.LR_W,
            0b00011: Mnemonic.SC_W,
            0b00100: Mnemonic.AMOXOR_W,
            0b01000: Mnemonic.AMOOR_W,
            0b01100: Mnemonic.AMOADD_W,
            0b10000: Mnemonic.AMOMIN_W,
            0b10100: Mnemonic.AMOMAX_W,
            0b11000: Mnemonic.AMOMINU_W,
            0b11100: Mnemonic.AMOMAXU_W,
        },
        0b011: {
            0b00000: Mnemonic.AMOADD_D,
            0b00001: Mnemonic.AMOSWAP_D,
            0b00010: Mnemonic.LR_D,
            0b00011: Mnemonic.SC_D,
            0b00100: Mnemonic.AMOXOR_D,
            0b01000: Mnemonic.AMOOR_D,
            0b01100: Mnemonic.AMOADD_D,
            0b10000: Mnemonic.AMOMIN_D,
            0b10100: Mnemonic.AMOMAX_D,
            0b11000: Mnemonic.AMOMINU_D,
            0b11100: Mnemonic.AMOMAXU_D,
        }
    },
    0b01_100_11: {
        0b000: {
            0b0000000: Mnemonic.ADD,
            0b0000001: Mnemonic.MUL,
            0b0100000: Mnemonic.SUB,
        },
        0b001: {
            0b0000000: Mnemonic.SLL,
            0b0000001: Mnemonic.MULH,
        },
        0b010: {
            0b0000000: Mnemonic.SLT,
            0b0000001: Mnemonic.MULHSU,
        },
        0b011: {
            0b0000000: Mnemonic.SLTU,
            0b0000001: Mnemonic.MULHU,
        },
        0b100: {
            0b0000000: Mnemonic.XOR,
            0b0000001: Mnemonic.DIV,
        },
        0b101: {
            0b0000000: Mnemonic.SRL,
            0b0000001: Mnemonic.DIVU,
            0b0100000: Mnemonic.SRA,
        },
        0b110: {
            0b0000000: Mnemonic.OR,
            0b0000001: Mnemonic.REM,
        },
        0b111: {
            0b0000000: Mnemonic.AND,
            0b0000001: Mnemonic.REMU,
        },
    },
    0b01_101_11: Mnemonic.LUI,
    0b01_110_11: {
        0b000: {
            0b0000000: Mnemonic.ADDW,
            0b0000001: Mnemonic.MULW,
            0b0100000: Mnemonic.SUBW,
        },
        0b001: {
            0b0000000: Mnemonic.SLLW,
        },
        0b100: {
            0b0000001: Mnemonic.DIVW,
        },
        0b101: {
            0b0000000: Mnemonic.SRLW,
            0b0000001: Mnemonic.DIVUW,
            0b0100000: Mnemonic.SRAW,
        },
        0b110: {
            0b0000001: Mnemonic.REMW,
        },
        0b111: {
            0b0000001: Mnemonic.REMUW,
        }
    },
    0b11_000_11: {
        0b000: Mnemonic.BEQ,
        0b001: Mnemonic.BNE,
        0b100: Mnemonic.BLT,
        0b101: Mnemonic.BGE,
        0b110: Mnemonic.BLTU,
        0b111: Mnemonic.BGEU,
    },
    0b11_001_11: {
        0b000: Mnemonic.JALR,
    },
    0b11_011_11: Mnemonic.JAL,
    0b11_100_11: {
        0b000: {
            0b0000000: {
                0b00000: Mnemonic.ECALL,
                0b00001: Mnemonic.EBREAK,
            },
            0b0011000: Mnemonic.MRET,
        },
        0b001: Mnemonic.CSRRW,
        0b010: Mnemonic.CSRRS,
        0b011: Mnemonic.CSRRC,
        0b101: Mnemonic.CSRRWI,
        0b110: Mnemonic.CSRRSI,
        0b111: Mnemonic.CSRRCI,
    },
}

def get_matchers(instruction):
    '''
    Every instruction has its own decoding pattern.
    '''
    assert instruction.opcode & 0b11 == 0b11
    if instruction.opcode == 0b0101111:
        return (opcode, funct3, atomic)
    return (opcode, funct3, funct7, rs2)

def get_mnemonic(instruction):
    return lookup_mnemonic(instruction, get_matchers(instruction), MNEMONICS, Mnemonic.UNDEFINED)

def actor(instruction, cpu):
    mnemonic = get_mnemonic(instruction)
    new_pc = cpu.pc.value + 4
    match get_mnemonic(instruction):
        case Mnemonic.LB:
            cpu.rd(i8(cpu.bus.read(cpu.registers[instruction.rs1].value + instruction.imm_i, 1)))
        case Mnemonic.LH:
            cpu.rd(i16(cpu.bus.read(cpu.registers[instruction.rs1].value + instruction.imm_i, 2)))
        case Mnemonic.LW:
            cpu.rd(i32(cpu.bus.read(cpu.registers[instruction.rs1].value + instruction.imm_i, 4)))
        case Mnemonic.LD:
            cpu.rd(i64(cpu.bus.read(cpu.registers[instruction.rs1].value + instruction.imm_i, 8)))
        case Mnemonic.LBU:
            cpu.rd(u8(cpu.bus.read(cpu.registers[instruction.rs1].value + instruction.imm_i, 1)))
        case Mnemonic.LHU:
            cpu.rd(u16(cpu.bus.read(cpu.registers[instruction.rs1].value + instruction.imm_i, 2)))
        case Mnemonic.LWU:
            cpu.rd(u32(cpu.bus.read(cpu.registers[instruction.rs1].value + instruction.imm_i, 4)))
        case Mnemonic.XORI:
            cpu.rd(u64(cpu.registers[instruction.rs1].value) ^ u64(instruction.imm_i))
        case Mnemonic.ADDI:
            cpu.rd(cpu.registers[instruction.rs1].value + instruction.imm_i)
        case Mnemonic.SLLI:
            cpu.rd(cpu.registers[instruction.rs1].value << instruction.shamt)
        case Mnemonic.SLTI:
            cpu.rd(i64(cpu.registers[instruction.rs1].value) < instruction.imm_i)
        case Mnemonic.SLTIU:
            cpu.rd(u64(cpu.registers[instruction.rs1].value) < u64(instruction.imm_i))
        case Mnemonic.SRLI:
            cpu.rd(u64(cpu.registers[instruction.rs1].value) >> instruction.imm_i)
        case Mnemonic.SRAI:
            cpu.rd(i64(cpu.registers[instruction.rs1].value) >> instruction.imm_i)
        case Mnemonic.BGE:
            if i64(cpu.registers[instruction.rs1].value) >= i64(cpu.registers[instruction.rs2].value):
                new_pc = cpu.pc.value + instruction.imm_b
        case Mnemonic.BEQ:
            if cpu.registers[instruction.rs1].value == cpu.registers[instruction.rs2].value:
                new_pc = cpu.pc.value + instruction.imm_b
        case Mnemonic.JALR:
            new_pc = ((cpu.registers[instruction.rs1].value + instruction.imm_i) >> 1) << 1
            cpu.rd(cpu.pc.value + instruction.size)
        case Mnemonic.ADD:
            cpu.rd(cpu.registers[instruction.rs1].value + cpu.registers[instruction.rs2].value)
        case Mnemonic.SUB:
            cpu.rd(cpu.registers[instruction.rs1].value - cpu.registers[instruction.rs2].value)
        case Mnemonic.BNE:
            if cpu.registers[instruction.rs1].value != cpu.registers[instruction.rs2].value:
                new_pc = cpu.pc.value + instruction.imm_b
        case Mnemonic.BLTU:
            if u64(cpu.registers[instruction.rs1].value) < u64(cpu.registers[instruction.rs2].value):
                new_pc = cpu.pc.value + instruction.imm_b
        case Mnemonic.BGEU:
            if u64(cpu.registers[instruction.rs1].value) >= u64(cpu.registers[instruction.rs2].value):
                new_pc = cpu.pc.value + instruction.imm_b
        case Mnemonic.AUIPC:
            cpu.rd(cpu.pc.value + instruction.imm_u)
        case Mnemonic.LUI:
            cpu.rd(instruction.imm_u)
        case Mnemonic.CSRRS:
            cpu.rd(cpu.csrs.setdefault(instruction.csr, 0))
            cpu.csrs[instruction.csr] |= cpu.registers[instruction.rs1].value
        case Mnemonic.CSRRW:
            cpu.rd(cpu.csrs.setdefault(instruction.csr, 0))
            cpu.csrs[instruction.csr] = cpu.registers[instruction.rs1].value
        case Mnemonic.MUL:
            cpu.rd(cpu.registers[instruction.rs1].value * cpu.registers[instruction.rs2].value)
        case Mnemonic.JAL:
            cpu.rd(cpu.pc.value + instruction.size)
            new_pc = cpu.pc.value + instruction.imm_j
        case Mnemonic.SD:
            cpu.bus.write(cpu.registers[instruction.rs1].value + instruction.imm_s, 8, cpu.registers[instruction.rs2].value)
        case Mnemonic.SW:
            cpu.bus.write(cpu.registers[instruction.rs1].value + instruction.imm_s, 4, cpu.registers[instruction.rs2].value)
        case Mnemonic.SB:
            cpu.bus.write(cpu.registers[instruction.rs1].value + instruction.imm_s, 1, cpu.registers[instruction.rs2].value)
        
        case Mnemonic.AND:
            cpu.rd(cpu.registers[instruction.rs1].value & cpu.registers[instruction.rs2].value)
        case Mnemonic.ANDI:
            cpu.rd(cpu.registers[instruction.rs1].value & instruction.imm_i)
        case Mnemonic.OR:
            cpu.rd(cpu.registers[instruction.rs1].value | cpu.registers[instruction.rs2].value)
        case Mnemonic.ORI:
            cpu.rd(cpu.registers[instruction.rs1].value | instruction.imm_i)
        case Mnemonic.SLLIW:
            cpu.rd(cpu.registers[instruction.rs1].value << (instruction.shamt & 0b11111))
        case Mnemonic.ADDIW:
            cpu.rd(i32(cpu.registers[instruction.rs1].value + instruction.imm_i))
        case Mnemonic.MRET:
            # return from a trap in M-mode
            # clear mstatus.MPRV when leaving M-mode
            # MPP holds value y
            # MIE set to MPIE
            # previous mode change to y
            # MPIE set to 1
            # MPP set to U if U else M
            # MPP != M then MRET set MPRV = 0
            # An MRET or SRET instruction that changes the privilege mode to a mode less privileged than M also sets MPRV=0.
            new_pc = cpu.csrs[CSR.MEPC.value]
        # Atomic Memory Operations
        case Mnemonic.AMOSWAP_W:
            old_value = i32(cpu.bus.read(cpu.registers[instruction.rs1].value, 4))
            cpu.bus.write(cpu.registers[instruction.rs1].value, 4, cpu.registers[instruction.rs2].value)
            cpu.rd(old_value)
        case Mnemonic.FENCE:
            pass
        case _:
            error(f'invalid instruction: {instruction}')
    cpu.pc.value = new_pc


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
    head = section(opcode, 0, 2)
    rvc_funct3 = section(instruction.value, 13, 3)

    if head != 0b11:
        
        # https://five-embeddev.com/riscv-isa-manual/latest/rvc-opcode-map.html#rvcopcodemap
        
        match(head, rvc_funct3):
            # https://five-embeddev.com/riscv-isa-manual/latest/c.html
            case (0b01, 0b011):
                return OpCodeType.LUI
            case (0b01, 0b000):
                return OpCodeType.ADDI

    if head == 0b11:
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
    if isinstance(instruction, Instruction):
        return {
            0b000_0011: InstructionType.I,
            0b001_0011: InstructionType.I,
            0b001_0111: InstructionType.U,
            0b001_1011: InstructionType.I,
            0b010_0011: InstructionType.S,
            0b011_0011: InstructionType.R,
            0b011_0111: InstructionType.U,
            0b110_0011: InstructionType.B,
            0b110_0111: InstructionType.I,
            0b110_1111: InstructionType.J,
        }.get(instruction.opcode, InstructionType.UNDEFINED)
    if isinstance(instruction, CompressedInstruction):
        return InstructionType.UNDEFINED

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
            f'{instruction.imm_j + pc:x}',
        ])
    if mnemonic in {Mnemonic.CSRRS, Mnemonic.CSRRW}:
        return mnemonic_sec + '\t' + sep.join([
            f'{reg(instruction.rd)}',
            f'{csr_name(instruction.csr)}',
            f'{reg(instruction.rs1)}'
        ])
    return mnemonic_sec

def info(instruction):
    match instruction.opcode & 0b11:
        case 0b11:
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
        case _:
            return 'unsupported instruction'
        

class Instruction:

    size = 4

    is_compressed = False

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

    #@property
    def asm(self, pc=0):
        return get_asm(self, use_symbol=USE_SYMBOL)

    def __str__(self):
        if VERBOSE:
            return self.asm() + '\n' + info(self)
        return self.asm()
