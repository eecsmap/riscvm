from enum import Enum, auto
from riscvm import error, todo

'''
refer:
    https://www.scs.stanford.edu/10wi-cs140/pintos/specs/pc16550d.pdf
'''

import logging
logger = logging.getLogger(__name__)


class RegisterEnum(Enum):
    # DLAB = 0 READ
    RBR = 0 # receiver buffer
    IER = 1 # 
    IIR = 2 # interrupt identification
    LCR = 3 # 
    MCR = 4 # modem control
    LSR = 5 # line status
    MSR = 6 # modem status
    SCR = 7 # scratch

    # DLAB = 0 WRITE
    THR = 0 # transmitter holding
    FCR = 2 # 

    # DLAB = 1 READ
    DLL = 0 # divisor latch LSB
    DLM = 1 # divisor latch MSB

    
# The machine level has the highest privileges
# and is the only mandatory privilege level for a RISC-V hardware platform.

class CSR(Enum):
    MEPC = 0x341
    MSTATUS = 0x300
    MIE = 0x304

    def __str__(self):
        return f'{self.name}'

# registers
#define RHR 0                 // receive holding register (for input bytes)
#define THR 0                 // transmit holding register (for output bytes)

# DLAB = 1 to write divisor latches of Baud Generator
#DLL = 0                 # divisor latch least significant
#DLM = 1                 # divisor latch most significant

#IER = 1                 # interrupt enable register

#FCR = 2                 # FIFO control register

#define ISR 2                 // interrupt status register
#LCR = 3                 # line control register
#
#
#define LSR 5                 // line status register
#define LSR_RX_READY (1<<0)   // input is waiting to be read from RHR
#define LSR_TX_IDLE (1<<5)    // THR can accept another character to send
#LSR = 5 # Line Status Register


class Register:

    def __init__(self, uart, index, name):
        self._uart = uart
        self._index = index
        self._name = name
    @property
    def value(self):
        return 0

class RBR(Register):
    pass
class IER(Register):
    'interrupt enable register'
    IER_RX_ENABLE = 1<<0
    IER_TX_ENABLE = 1<<1

    @property
    def value(self):
        assert not self._uart.dlab, 'not accessible in current dlab mode'
        return 0
    @value.setter
    def value(self, value):
        assert not self._uart.dlab, 'not accessible in current dlab mode'
        self._uart.interrupt_enabled_received_data_available = bool(value | self.IER_RX_ENABLE)
        self._uart.interrupt_enabled_transmitter_holding_register_empty = bool(value | self.IER_TX_ENABLE)
        assert not value & ~(self.IER_RX_ENABLE | self.IER_TX_ENABLE), "TODO: more flags to handle"

class IIR(Register):
    pass

class LCR(Register):
    'line control register'
    LCR_NBITS = 3<<0
    LCR_BAUD_LATCH = 1<<7   # special mode to set baud rate

    @property
    def value(self):
        value = (
            self._uart.divisor_latch_accessible << 7
            | (self._uart.line_control_nbits)
        )
        return value

    @value.setter
    def value(self, value):
        self._uart.divisor_latch_accessible = bool(value & self.LCR_BAUD_LATCH)
        self._uart.line_control_nbits = value & self.LCR_NBITS
        if value & ~(self.LCR_BAUD_LATCH | self.LCR_NBITS):
            todo()

class MCR(Register):
    pass
class LSR(Register):
    'line status register'

    LSR_TX_IDLE = 1 << 5

    @property
    def value(self):
        return (
            self._uart.data_available << 0
            | self.LSR_TX_IDLE
            )

class MSR(Register):
    pass
class SCR(Register):
    pass
class THR(Register):
    pass
class FCR(Register):
    'FIFO control register'
    FCR_FIFO_ENABLE = 1<<0
    FCR_FIFO_CLEAR = 3<<1   # clear the content of the two FIFOs

    @property
    def value(self):
        error('uart register fcr is write only')

    @value.setter
    def value(self, value):
        self._uart.filo_enabled = bool(value | self.FCR_FIFO_ENABLE)
        self._uart.filo_reset = bool(value | self.FCR_FIFO_CLEAR)
        assert not value & ~(self.FCR_FIFO_ENABLE | self.FCR_FIFO_CLEAR), "TODO: more flags to handle"


class DLL(Register):
    'divisor latch LSB register'
    @property
    def value(self):
        assert self._uart.dlab, 'not accessible in current dlab mode'
        return self._uart.dll_value
    @value.setter
    def value(self, value):
        assert self._uart.dlab, 'not accessible in current dlab mode'
        self._uart.dll_value = value

class DLM(Register):
    'divisor latch MSB register'
    @property
    def value(self):
        assert self._uart.dlab, 'not accessible in current dlab mode'
        return self._uart.dlm_value
    @value.setter
    def value(self, value):
        assert self._uart.dlab, 'not accessible in current dlab mode'
        self._uart.dlm_value = value


# RBR = 0 # receiver buffer
# IER = 1 # interrupt enable
# IIR = 2 # interrupt identification
# LCR = 3 # line control
# MCR = 4 # modem control
# LSR = 5 # line status
# MSR = 6 # modem status
# SCR = 7 # scratch

# # DLAB = 0 WRITE
# THR = 0 # transmitter holding
# FCR = 2 # FIFO control

# # DLAB = 1 READ
# DLL = 0 # divisor latch LSB
# DLM = 1 # divisor latch MSB


class UART:

    def __init__(self, size, uart_output_file):
        # handle hold the lifetime of mmap object
        self.size = size
        #self.handle = gen('mem.dat', size)
        #self.data = next(self.handle)
        self._registers = dict(
            rbr = RBR(self, 0, 'rbr'),
            ier = IER(self, 1, 'ier'),
            iir = IIR(self, 2, 'iir'),
            lcr = LCR(self, 3, 'lcr'),
            mcr = MCR(self, 4, 'mcr'),
            lsr = LSR(self, 5, 'lsr'),
            msr = MSR(self, 6, 'msr'),
            scr = SCR(self, 7, 'scr'),
            thr = THR(self, 0, 'thr'),
            fcr = FCR(self, 2, 'fcr'),
            dll = DLL(self, 0, 'dll'),
            dlm = DLM(self, 1, 'dlm'),
        )
        self.divisor_latch_accessible = False
        self.interrupt_enabled_received_data_available = False
        self.interrupt_enabled_transmitter_holding_register_empty = False
        self.line_control_nbits = 0
        self.dll_value = 0
        self.dlm_value = 0
        self.data_available = True

        self.filo_enabled = False
        #self.data[LSR] = 1
        #self.lsr.value = 1
        self.allow_send = True
        #self.dll = 0
        #self.dlm = 0
        # lets default to 8bit no parity
        self.output = uart_output_file

    def __len__(self):
        return len(self.data)

    @property
    def rbr(self):
        return self._registers['rbr'].value
    @property
    def ier(self):
        return self._registers['ier'].value
    @property
    def iir(self):
        return self._registers['iir'].value
    @property
    def lcr(self):
        return self._registers['lcr'].value
    @property
    def mcr(self):
        return self._registers['mcr'].value
    @property
    def lsr(self):
        return self._registers['lsr'].value
    @property
    def msr(self):
        return self._registers['msr'].value
    @property
    def scr(self):
        return self._registers['scr'].value
    # DLAB = 0 write
    @property
    def thr(self):
        error('uart register thr is write only')
    @property
    def fcr(self):
        error('uart register fcr is write only')
    # DLAB = 1 read
    @property
    def dll(self):
        return self._registers['dll'].value
    @property
    def dlm(self):
        return self._registers['dlm'].value

    # @rbr.setter
    # def rbr(self):
    #     return self._registers['rbr']
    @ier.setter
    def ier(self, value):
        assert not self.dlab, 'not accessible in current dlab mode'
        self._registers['ier'].value = value
    # @property
    # def iir(self):
    #     return self._registers['iir']
    @lcr.setter
    def lcr(self, value):
        self._registers['lcr'].value = value
    # @property
    # def mcr(self):
    #     return self._registers['mcr']
    # @property
    # def lsr(self):
    #     return self._registers['lsr']
    # @property
    # def msr(self):
    #     return self._registers['msr']
    # @property
    # def scr(self):
    #     return self._registers['scr']
    # # DLAB = 0 write
    @thr.setter
    def thr(self, value):
        assert not self.dlab, 'not accessible in current dlab mode'
        self._registers['thr'].value = value
    @fcr.setter
    def fcr(self, value):
        self._registers['fcr'].value = value
    # DLAB = 1 read
    @dll.setter
    def dll(self, value):
        assert self.dlab, 'not accessible in current dlab mode'
        self._registers['dll'].value = value
    @dlm.setter
    def dlm(self, value):
        assert self.dlab, 'not accessible in current dlab mode'
        self._registers['dlm'].value = value
    

    @property
    def dlab(self):
        'Divisor Latch Access Bit'
        return self.lcr >> 7

    def read(self, address, size):
        assert size == 1
        match address:
            case 0:
                value = self.dll if self.dlab else self.rbr
            case 1:
                value = self.dlm if self.dlab else self.ier
            case 2:
                value = self.iir
            case 3:
                value = self.lcr
            case 4:
                value = self.mcr
            case 5:
                # ref https://www.lammertbies.nl/comm/info/serial-uart
                # Bit 5 and 6 both show the state of the transmitting cycle.
                # The difference is, that bit 5 turns high as soon as
                # the transmitter holding register is empty whereas
                # bit 6 indicates that also the shift register which outputs the bits on the line is empty.
                if self.allow_send: pass
                value = self.lsr
            case 6:
                value = self.msr
            case 7:
                value = self.scr

        regname = [
            [
                'rbr', 'ier', 'iir', 'lcr', 'mcr', 'lsr', 'msr', 'scr'
            ],
            [
                'dll', 'dlm', 'iir', 'lcr', 'mcr', 'lsr', 'msr', 'scr'
            ]
        ]
        #logger.info(f'*** uart read from\t{regname[self.dlab][address]}({address}): 0x{value:02X} \'{value:c}\'')
        return value

    def write(self, address, size, value):
        assert size == 1, f'invalid address size {address}'
        value &= 0xff
        regname = [
            [
                'thr', 'ier', 'fcr', 'lcr', 'mcr', 'factory_test', 'not_used', 'scr'
            ],
            [
                'dll', 'dlm', 'fcr', 'lcr', 'mcr', 'factory_test', 'not_used', 'scr'
            ]
        ]
        assert address not in {5, 6}, 'uart register illegal write'
        #logger.debug(f'*** uart write to\t{regname[self.dlab][address]}({address}): 0x{value:02x}')

        match address:
            case 0:
                if self.dlab:
                    self.dll = value
                else:
                    # THR
                    #logger.info(f'*** uart write to\t{regname[self.dlab][address]}({address}): 0x{value:02x} \'{value:c}\'')
                    if self.output:
                        self.output.write(chr(value).encode())
            case 1:
                if self.dlab:
                    self.dlm = value
                else:
                    self.ier = value
            case 2:
                self.fcr = value
            case 3:
                self.lcr = value
