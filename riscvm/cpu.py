from riscvm import Register
from riscvm import Instruction
from riscvm import Bus
from riscvm import error
from riscvm.mnemonics import Mnemonic
from riscvm.register import FixedRegister
from riscvm.utils import i8, i16, i32, i64, u8, u16, u32, u64, todo
from .instruction import get_mnemonic

class CPU:

    INSTRUCTION_SIZE = 4

    def __init__(self, bus):
        self.registers = [Register(0, f'x{i}') for i in range(32)]
        self.registers[0] = FixedRegister(0, 'x0')
        self.pc = Register() #0x8000_0000)
        self.bus = bus
    
    def fetch(self):
        self.instruction = Instruction(self.bus.read(self.pc.value, self.INSTRUCTION_SIZE))
        self.pc.value += self.INSTRUCTION_SIZE
        return self.instruction

    def rd(self, value):
        self.registers[self.instruction.rd].value = value

    def execute(self, instruction=None):
        if instruction:
            self.instruction = instruction
        
        if self.instruction.value == 0:
            error('stop at zero content instruction')

        instruction = self.instruction
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
            case _:
                raise Exception(f'invalid instruction: {instruction}')
