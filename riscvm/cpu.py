from enum import Enum
from riscvm.exception import error
from riscvm.register import Register, FixedRegister
from riscvm.rv64i import Instruction as RV64I_Instruction, actor as rv64i_actor
from riscvm.rv64c import Instruction as RV64C_Instruction, actor as rv64c_actor
from riscvm.csr import CSR

import logging
logger = logging.getLogger(__name__)

def get_actor(instruction_u32):
    match instruction_u32 & 0b11:
        case 0b11: return rv64i_actor
    return rv64c_actor

class CPU:

    RV64I_SIZE = 4
    RV64C_SIZE = 2

    def __init__(self, bus):
        self.instrustion = None
        self.registers = [Register(0, f'x{i}') for i in range(32)]
        self.registers[0] = FixedRegister(0, 'x0')
        self.pc = Register()
        self.sp = self.registers[2]
        self.bus = bus
        self.csrs = {
            CSR.MSTATUS.value : 0xa00000000,
        } # hopefully we are not going to use csrs too frequently, otherwise we need an array

    def fetch(self):
        data = self.bus.read(self.pc.value, self.RV64C_SIZE)

        match data & 0b11:
            case 0b11:
                self.instruction = RV64I_Instruction(self.bus.read(self.pc.value, self.RV64I_SIZE))
            case 0b00 | 0b01 | 0b10:
                self.instruction = RV64C_Instruction(data)
            case _:
                error(f'invalid instruction 0x{data:08x} @0x{self.pc.value:016x}')
        return self.instruction

    def rd(self, value):
        # assume instruction always have rd well defined
        self.registers[self.instruction.rd].value = value

    def execute(self, instruction=None):
        if instruction:
            self.instruction = instruction
        actor = get_actor(self.instruction.value)
        actor(self.instruction, self)
