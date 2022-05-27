from enum import Enum, auto

import logging
logger = logging.getLogger(__name__)

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

    def __str__(self):
        return f'{self.name}'.replace('_', '.')

MNEMONICS = {
    # rv32c/64c
    0b01: {
        0b011: Mnemonic.C_LUI,
        0b000: Mnemonic.C_ADDI,
    },
    0b10: {
        0b1001: Mnemonic.C_ADD,
        0b1110: Mnemonic.C_SDSP,
        0b1111: Mnemonic.C_SDSP,
    },
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


from .utils import opcode, funct3, funct7, atomic, rs2, c_op, c_funct3, c_funct4

def get_matchers(instruction):
    '''
    Every instruction has its own decoding pattern.
    '''
    if instruction.opcode & 0b11 == 0b11:
        if instruction.opcode == 0b0101111:
            return (opcode, funct3, atomic)
        return (opcode, funct3, funct7, rs2)
    if instruction.opcode & 0b11 == 0b01:
        return (c_op, c_funct3)
    if instruction.opcode & 0b11 == 0b10:
        return (c_op, c_funct4)

def get_mnemonic(instruction):
    value = MNEMONICS
    levels = get_matchers(instruction)
    for level in levels:
        value = value.get(level(instruction.value), Mnemonic.UNDEFINED)
        if not isinstance(value, dict):
            return value
    return Mnemonic.UNDEFINED
