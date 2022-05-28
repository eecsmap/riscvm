from enum import Enum
from riscvm import Register
from riscvm.instruction import Instruction #, CompressedInstruction
from riscvm import error
from riscvm.mnemonics import Mnemonic
from riscvm.register import FixedRegister
from riscvm.utils import i8, i16, i32, i64, u8, u16, u32, u64, todo
from .instruction import get_mnemonic
from .rvc64 import actor as rvc64_actor, Instruction as CompressedInstruction
import logging
logger = logging.getLogger(__name__)

class CSR(Enum):
    MEPC = 0x341

    def __str__(self):
        return f'{self.name}'


def get_handler(instruction_value):
    match instruction_value & 0b11:
        case 0b00 | 0b01 | 0b10:
            return rvc64_actor
    return None

class CPU:

    COMPRESSED_INSTRUCTION_SIZE = 2
    INSTRUCTION_SIZE = 4

    def __init__(self, bus):
        self.instrustion = None
        self.registers = [Register(0, f'x{i}') for i in range(32)]
        self.registers[0] = FixedRegister(0, 'x0')
        self.pc = Register() #0x8000_0000)
        self.bus = bus
        self.sp = self.registers[2]
        self.csrs = {} # hopefully we are not going to use csrs too frequently, otherwise we need an array
    
    def fetch(self):
        data = self.bus.read(self.pc.value, self.COMPRESSED_INSTRUCTION_SIZE)

        match data & 0b11:
            case 0b11:
                self.instruction = Instruction(self.bus.read(self.pc.value, self.INSTRUCTION_SIZE))
            case 0b00 | 0b01 | 0b10:
                self.instruction = CompressedInstruction(data)
            case _:
                error(f'invalid instruction 0x{data:08x} @0x{self.pc.value:016x}')
        return self.instruction

    def rd(self, value):
        self.registers[self.instruction.rd].value = value


    def execute(self, instruction=None):
        if instruction:
            self.instruction = instruction
        instruction = self.instruction

        actor = get_handler(instruction.value)
        if actor:
            actor(instruction, self)
        else:
            branching = False
            pc_offset = 0
            jumping = False
            pc_new = 0
            match get_mnemonic(instruction):
                case Mnemonic.LB:
                    self.rd(i8(self.bus.read(self.registers[instruction.rs1].value + instruction.imm_i, 1)))
                case Mnemonic.LH:
                    self.rd(i16(self.bus.read(self.registers[instruction.rs1].value + instruction.imm_i, 2)))
                case Mnemonic.LW:
                    self.rd(i32(self.bus.read(self.registers[instruction.rs1].value + instruction.imm_i, 4)))
                case Mnemonic.LD:
                    self.rd(i64(self.bus.read(self.registers[instruction.rs1].value + instruction.imm_i, 8)))
                case Mnemonic.LBU:
                    self.rd(u8(self.bus.read(self.registers[instruction.rs1].value + instruction.imm_i, 1)))
                case Mnemonic.LHU:
                    self.rd(u16(self.bus.read(self.registers[instruction.rs1].value + instruction.imm_i, 2)))
                case Mnemonic.LWU:
                    self.rd(u32(self.bus.read(self.registers[instruction.rs1].value + instruction.imm_i, 4)))
                case Mnemonic.XORI:
                    self.rd(u64(self.registers[instruction.rs1].value) ^ u64(instruction.imm_i))
                case Mnemonic.ADDI:
                    self.rd(self.registers[instruction.rs1].value + instruction.imm_i)
                case Mnemonic.SLLI:
                    self.rd(self.registers[instruction.rs1].value << instruction.shamt)
                case Mnemonic.SLTI:
                    self.rd(i64(self.registers[instruction.rs1].value) < instruction.imm_i)
                case Mnemonic.SLTIU:
                    self.rd(u64(self.registers[instruction.rs1].value) < u64(instruction.imm_i))
                case Mnemonic.SRLI:
                    self.rd(u64(self.registers[instruction.rs1].value) >> instruction.imm_i)
                case Mnemonic.SRAI:
                    self.rd(i64(self.registers[instruction.rs1].value) >> instruction.imm_i)
                case Mnemonic.BGE:
                    if i64(self.registers[instruction.rs1].value) >= i64(self.registers[instruction.rs2].value):
                        branching = True
                        pc_offset = instruction.imm_b
                case Mnemonic.BEQ:
                    if self.registers[instruction.rs1].value == self.registers[instruction.rs2].value:
                        branching = True
                        pc_offset = instruction.imm_b
                case Mnemonic.JALR:
                    jumping = True
                    pc_new = ((self.registers[instruction.rs1].value + instruction.imm_i) >> 1) << 1
                    self.rd(self.pc.value + self.INSTRUCTION_SIZE)
                case Mnemonic.ADD:
                    self.rd(self.registers[instruction.rs1].value + self.registers[instruction.rs2].value)
                case Mnemonic.SUB:
                    self.rd(self.registers[instruction.rs1].value - self.registers[instruction.rs2].value)
                case Mnemonic.BNE:
                    if self.registers[instruction.rs1].value != self.registers[instruction.rs2].value:
                        branching = True
                        pc_offset = instruction.imm_b
                case Mnemonic.BLTU:
                    if u64(self.registers[instruction.rs1].value) < u64(self.registers[instruction.rs2].value):
                        branching = True
                        pc_offset = instruction.imm_b
                case Mnemonic.BGEU:
                    if u64(self.registers[instruction.rs1].value) >= u64(self.registers[instruction.rs2].value):
                        branching = True
                        pc_offset = instruction.imm_b
                case Mnemonic.AUIPC:
                    self.rd(self.pc.value + instruction.imm_u)
                case Mnemonic.LUI:
                    self.rd(instruction.imm_u)
                case Mnemonic.CSRRS:
                    self.rd(self.csrs.setdefault(instruction.csr, 0))
                    self.csrs[instruction.csr] |= self.registers[instruction.rs1].value
                case Mnemonic.CSRRW:
                    self.rd(self.csrs.setdefault(instruction.csr, 0))
                    self.csrs[instruction.csr] = self.registers[instruction.rs1].value
                case Mnemonic.MUL:
                    self.rd(self.registers[instruction.rs1].value * self.registers[instruction.rs2].value)
                case Mnemonic.JAL:
                    self.rd(self.pc.value + self.INSTRUCTION_SIZE)
                    jumping = True
                    pc_new = self.pc.value + instruction.imm_j
                case Mnemonic.SD:
                    self.bus.write(self.registers[instruction.rs1].value + instruction.imm_s, 8, self.registers[instruction.rs2].value)
                case Mnemonic.SW:
                    self.bus.write(self.registers[instruction.rs1].value + instruction.imm_s, 4, self.registers[instruction.rs2].value)
                case Mnemonic.SB:
                    self.bus.write(self.registers[instruction.rs1].value + instruction.imm_s, 1, self.registers[instruction.rs2].value)
                
                case Mnemonic.AND:
                    self.rd(self.registers[instruction.rs1].value & self.registers[instruction.rs2].value)
                case Mnemonic.ANDI:
                    self.rd(self.registers[instruction.rs1].value & instruction.imm_i)
                case Mnemonic.OR:
                    self.rd(self.registers[instruction.rs1].value | self.registers[instruction.rs2].value)
                case Mnemonic.ORI:
                    self.rd(self.registers[instruction.rs1].value | instruction.imm_i)
                case Mnemonic.SLLIW:
                    self.rd(self.registers[instruction.rs1].value << (instruction.shamt & 0b11111))
                case Mnemonic.ADDIW:
                    self.rd(i32(self.registers[instruction.rs1].value + instruction.imm_i))
                case Mnemonic.MRET:
                    # return from a trap in M-mode
                    jumping = True
                    pc_new = self.csrs[CSR.MEPC.value]
                # Atomic Memory Operations
                case Mnemonic.AMOSWAP_W:
                    old_value = i32(self.bus.read(self.registers[instruction.rs1].value, 4))
                    self.bus.write(self.registers[instruction.rs1].value, 4, self.registers[instruction.rs2].value)
                    self.rd(old_value)
                case Mnemonic.FENCE:
                    pass



                case Mnemonic.C_LUI:
                    assert instruction.nzimm != 0
                    assert instruction.rd not in {0, 2}
                    self.rd(instruction.nzimm << 12)
                case Mnemonic.C_ADDI:
                    assert instruction.nzimm != 0
                    assert instruction.rd != 0
                    self.rd(self.registers[instruction.rd].value + instruction.nzimm)
                case Mnemonic.C_ADD:
                    assert instruction.rd != 0
                    assert instruction.rs2 != 0
                    self.rd(self.registers[instruction.rd].value + self.registers[instruction.rs2].value)
                case Mnemonic.C_SDSP:
                    self.bus.write(self.registers[2].value + instruction.uimm, 8, self.registers[instruction.rs2].value)


                case Mnemonic.C_ADDI4SPN:
                    assert instruction.nzuimm_w != 0
                    self.registers[instruction.rd_prime].value = self.registers[2].value + 4 * instruction.nzuimm_w
                case _:
                    error(f'invalid instruction: {instruction}')
            if branching:
                self.pc.value += pc_offset
            elif jumping:
                self.pc.value = pc_new
            else:
                self.pc.value += instruction.size
