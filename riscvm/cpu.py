from riscvm import Register
from riscvm import Instruction
from riscvm import Bus
from riscvm import error
from riscvm.register import FixedRegister
from riscvm.utils import i8, i16, i32, i64, u8, u16, u32, u64, todo

class CPU:

    INSTRUCTION_SIZE = 4

    def __init__(self, bus):
        self.registers = [Register(0, f'x{i}') for i in range(32)]
        self.registers[0] = FixedRegister(0, 'x0')
        self.pc = Register(0x8000_0000)
        self.bus = bus
    
    def fetch(self):
        self.instruction = Instruction(self.bus.read(self.pc.value, self.INSTRUCTION_SIZE))
        self.pc.value += self.INSTRUCTION_SIZE
        return self.instruction

    def execute(self, instruction):
        if instruction:
            self.instruction = instruction

        if self.instruction.value == 0:
            error('stop at zero content instruction')

        print(self.instruction)
        match self.instruction.opcode:
            case 0b000_0011:
                match self.instruction.funct3:
                    case 0b000: # lb
                        self.registers[self.instruction.rd].value = i8(self.bus.read(self.registers[self.instruction.rs1].value + self.instruction.imm_i, 1))
                    case 0b001: # lh
                        self.registers[self.instruction.rd].value = i16(self.bus.read(self.registers[self.instruction.rs1].value + self.instruction.imm_i, 2))
                    case 0b010: # lw
                        self.registers[self.instruction.rd].value = i32(self.bus.read(self.registers[self.instruction.rs1].value + self.instruction.imm_i, 4))
                    case 0b011: # ld
                        self.registers[self.instruction.rd].value = i64(self.bus.read(self.registers[self.instruction.rs1].value + self.instruction.imm_i, 8))
                    case 0b100: # lbu
                        self.registers[self.instruction.rd].value = u8(self.bus.read(self.registers[self.instruction.rs1].value + self.instruction.imm_i, 1))
                    case 0b101: # lhu
                        self.registers[self.instruction.rd].value = u16(self.bus.read(self.registers[self.instruction.rs1].value + self.instruction.imm_i, 2))
                    case 0b110: # lwu
                        self.registers[self.instruction.rd].value = u32(self.bus.read(self.registers[self.instruction.rs1].value + self.instruction.imm_i, 4))
            case 0b001_0011:
                match self.instruction.funct3:
                    case 0b000: # addi
                        self.registers[self.instruction.rd].value = self.registers[self.instruction.rs1].value + self.instruction.imm_i
                    case 0b001:
                        match self.instruction.funct7:
                            case 0b0000000: # slli
                                self.registers[self.instruction.rd].value = self.registers[self.instruction.rs1].value << self.instruction.imm_i
                    case 0b010: # slti
                        self.registers[self.instruction.rd].value = i64(self.registers[self.instruction.rs1].value) < self.instruction.imm_i
                    case 0b011: # sltiu
                        self.registers[self.instruction.rd].value = u64(self.registers[self.instruction.rs1].value) < u64(self.instruction.imm_i)
                    case 0b100: # xori
                        self.registers[self.instruction.rd].value = u64(self.registers[self.instruction.rs1].value) ^ u64(self.instruction.imm_i)
                    case 0b101:
                        match self.instruction.funct7:
                            case 0b0000000: # srli
                                self.registers[self.instruction.rd].value = u64(self.registers[self.instruction.rs1].value) >> self.instruction.imm_i
                            case 0b0100000: # srai
                                self.registers[self.instruction.rd].value = i64(self.registers[self.instruction.rs1].value) >> self.instruction.imm_i

            case 0x33:
                self.registers[self.instruction.rd].value = i64(self.registers[self.instruction.rs1].value) + self.registers[self.instruction.rs2].value
        print(self.registers)
