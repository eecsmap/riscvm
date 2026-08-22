import os
import select
from enum import Enum
from collections import deque
from riscvm import error, todo

'''
refer:
    https://www.scs.stanford.edu/10wi-cs140/pintos/specs/pc16550d.pdf

register offsets (DLAB = Divisor Latch Access Bit; see UART.dlab):
    DLAB=0 read:  RBR=0 IER=1 IIR=2 LCR=3 MCR=4 LSR=5 MSR=6 SCR=7
    DLAB=0 write: THR=0 IER=1 FCR=2 LCR=3 MCR=4
    DLAB=1:       DLL=0 DLM=1 (both directions)
'''

import logging
logger = logging.getLogger(__name__)


class Register:

    def __init__(self, uart, index, name):
        self._uart = uart
        self._index = index
        self._name = name
    @property
    def value(self):
        return 0

class RBR(Register):
    'receiver buffer register'
    @property
    def value(self):
        if self._uart.rx_queue:
            return self._uart.rx_queue.popleft()
        return 0
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
        # bitwise AND to test the bit, not OR (which is truthy for almost any
        # value regardless of whether the bit is actually set)
        self._uart.interrupt_enabled_received_data_available = bool(value & self.IER_RX_ENABLE)
        self._uart.interrupt_enabled_transmitter_holding_register_empty = bool(value & self.IER_TX_ENABLE)
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
        # bitwise AND to test the bit, not OR (which is truthy for almost any
        # value regardless of whether the bit is actually set)
        self._uart.fifo_enabled = bool(value & self.FCR_FIFO_ENABLE)
        self._uart.fifo_reset = bool(value & self.FCR_FIFO_CLEAR)
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

    def __init__(self, size, uart_output_file, uart_input_file=None):
        self.size = size
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
        self.rx_queue = deque()

        self.fifo_enabled = False
        self.fifo_reset = False
        self.output = uart_output_file
        # optional live input source (e.g. sys.stdin.buffer for an
        # interactive session); polled non-blockingly once per instruction
        # (see cpu.py) so typed/piped bytes show up in rx_queue without the
        # driver having to already know data is coming
        self.input = uart_input_file
        self._input_fd = None
        if self.input is not None and hasattr(self.input, 'fileno'):
            try:
                self._input_fd = self.input.fileno()
            except (OSError, ValueError):
                self._input_fd = None

    def __len__(self):
        return self.size

    @property
    def data_available(self):
        return bool(self.rx_queue)

    @property
    def interrupt_status(self):
        'level-triggered PLIC line: high whenever unread input is sitting in RBR and RX interrupts are enabled'
        return 1 if (self.data_available and self.interrupt_enabled_received_data_available) else 0

    def inject(self, data):
        "feed bytes into the receive queue, as if they'd arrived on the wire"
        self.rx_queue.extend(data)

    def poll_input(self):
        'best-effort, non-blocking top-up of rx_queue from the configured input source'
        if self.input is None:
            return
        try:
            if self._input_fd is not None:
                ready, _, _ = select.select([self._input_fd], [], [], 0)
                if not ready:
                    return
                chunk = os.read(self._input_fd, 256)
            else:
                chunk = self.input.read(256)
        except (BlockingIOError, InterruptedError, OSError):
            return
        if chunk:
            self.inject(chunk if isinstance(chunk, (bytes, bytearray)) else chunk.encode())

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

    @ier.setter
    def ier(self, value):
        assert not self.dlab, 'not accessible in current dlab mode'
        self._registers['ier'].value = value
    @lcr.setter
    def lcr(self, value):
        self._registers['lcr'].value = value
    # rbr/iir/mcr/lsr/msr/scr have no setter: they're read-only from the guest
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
                value = self.lsr
            case 6:
                value = self.msr
            case 7:
                value = self.scr

        return value

    def write(self, address, size, value):
        assert size == 1, f'invalid address size {address}'
        value &= 0xff
        assert address not in {5, 6}, 'uart register illegal write'

        match address:
            case 0:
                if self.dlab:
                    self.dll = value
                else:
                    # THR
                    if self.output:
                        self.output.write(chr(value).encode())
                        # flush every byte: this is a live console, not a
                        # batch log -- without this, output sits in the
                        # default buffered-file write buffer and the reader
                        # (a human at a terminal, or anything tailing the
                        # output file) sees nothing until it fills (~8KB)
                        # or the process exits, even though xv6 is printing
                        # normally the whole time
                        if hasattr(self.output, 'flush'):
                            self.output.flush()
            case 1:
                if self.dlab:
                    self.dlm = value
                else:
                    self.ier = value
            case 2:
                self.fcr = value
            case 3:
                self.lcr = value
