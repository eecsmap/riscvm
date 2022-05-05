from riscvm import Register
from riscvm import Instruction
from riscvm import error
from riscvm.exception import StopException
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
        print(f'debug: fetching from 0x{self.pc.value:016X}')
        self.instruction = Instruction(self.bus.read(self.pc.value, self.INSTRUCTION_SIZE))
        return self.instruction

    def rd(self, value):
        self.registers[self.instruction.rd].value = value

    def execute(self, instruction=None):
        if instruction:
            self.instruction = instruction
        
        if self.instruction.value == 0:
            raise StopException('stop at zero content instruction')

        instruction = self.instruction
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
            case Mnemonic.JALR:
                self.rd(self.pc.value + self.INSTRUCTION_SIZE)
                jumping = True
                pc_new = ((self.registers[instruction.rs1].value + instruction.imm_i) >> 1) << 1
            case Mnemonic.ADD:
                self.rd(self.registers[instruction.rs1].value + self.registers[instruction.rs2].value)
            case Mnemonic.BNE:
                if self.registers[instruction.rs1].value != self.registers[instruction.rs2].value:
                    branching = True
                    pc_offset = instruction.imm_b
            case _:
                raise Exception(f'invalid instruction: {instruction}')
        if branching:
            self.pc.value += pc_offset
        elif jumping:
            self.pc.value = pc_new
        else:
            self.pc.value += self.INSTRUCTION_SIZE
