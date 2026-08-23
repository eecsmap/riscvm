from enum import Enum
from riscvm.exception import error
from riscvm.register import Register, FixedRegister
from riscvm.rv64i import Instruction as RV64I_Instruction, actor as rv64i_actor
from riscvm.rv64c import Instruction as RV64C_Instruction, actor as rv64c_actor
from riscvm.csr import CSR, PrivilegeLevel
from riscvm.mmu import translate
from riscvm.trap import check_interrupt

import logging
logger = logging.getLogger(__name__)

def get_actor(instruction_u32):
    match instruction_u32 & 0b11:
        case 0b11: return rv64i_actor
    return rv64c_actor

class CPU:

    RV64I_SIZE = 4
    RV64C_SIZE = 2

    def __init__(self, bus, hartid=0):
        self.instrustion = None
        self.registers = [Register(0, f'x{i}') for i in range(32)]
        self.registers[0] = FixedRegister(0, 'x0')
        self.pc = Register()
        self.sp = self.registers[2]
        self.bus = bus
        self.hartid = hartid
        self.csrs = {
            CSR.MSTATUS.value : 0xa00000000,
            CSR.MIE.value : 0x222,
            CSR.MHARTID.value : hartid,
        } # hopefully we are not going to use csrs too frequently, otherwise we need an array
        self.mode = PrivilegeLevel.M.value
        # set by XV6 (or any caller wanting timer/external/console interrupts);
        # a plain Emulator has no such devices, so these stay no-ops
        self.clint = None
        self.plic = None
        self.uart = None
        self._uart_poll_countdown = 0

    UART_POLL_INTERVAL = 4096  # instructions between uart.poll_input() calls
                                # (it's a real select() syscall; a human typing
                                # is plenty responsive checked this often)

    def fetch(self):
        # interrupts are checked once per instruction, at the boundary between
        # instructions, matching real hardware; a taken interrupt updates pc
        # before we fetch, same as a taken branch would
        if self.clint is not None:
            self.clint.tick()
        if self.uart is not None:
            self._uart_poll_countdown -= 1
            if self._uart_poll_countdown <= 0:
                self.uart.poll_input()
                self._uart_poll_countdown = self.UART_POLL_INTERVAL
        check_interrupt(self)

        # single 4-byte read; RVC-format constructors mask down to their own width,
        # so we never need a second bus dispatch to disambiguate.
        # NOTE: this reads 4 bytes even for a 2-byte compressed instruction, which
        # can over-read past the end of a device's mapped range at the very top of
        # memory. Fine for a boot-time PC deep inside RAM; would need a bounds guard
        # (or fall back to the 2-byte read near a device boundary) for a fully general RVC decoder.
        data = self.bus.read(translate(self, self.pc.value, 'x'), self.RV64I_SIZE)

        match data & 0b11:
            case 0b11:
                self.instruction = RV64I_Instruction(data)
            case 0b00 | 0b01 | 0b10:
                self.instruction = RV64C_Instruction(data)
            case _:
                error(f'invalid instruction 0x{data:08x} @0x{self.pc.value:016x}')
        return self.instruction

    def rd(self, value):
        # assume instruction always have rd well defined
        self.registers[self.instruction.rd].value = value

    def read(self, address, size):
        return self.bus.read(translate(self, address, 'r'), size)

    def write(self, address, size, value):
        self.bus.write(translate(self, address, 'w'), size, value)

    def execute(self, instruction=None):
        if instruction:
            self.instruction = instruction
        actor = get_actor(self.instruction.value)
        actor(self.instruction, self)
