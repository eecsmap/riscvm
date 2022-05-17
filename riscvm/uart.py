from riscvm import error

'''
refer:
    https://www.scs.stanford.edu/10wi-cs140/pintos/specs/pc16550d.pdf
'''
import logging
logger = logging.getLogger(__name__)

# registers
#define RHR 0                 // receive holding register (for input bytes)
#define THR 0                 // transmit holding register (for output bytes)

# DLAB = 1 to write divisor latches of Baud Generator
DLL = 0                 # divisor latch least significant
DLM = 1                 # divisor latch most significant

IER = 1                 # interrupt enable register
IER_RX_ENABLE = 1<<0
IER_TX_ENABLE = 1<<1
FCR = 2                 # FIFO control register
FCR_FIFO_ENABLE = 1<<0
FCR_FIFO_CLEAR = 3<<1   # clear the content of the two FIFOs
#define ISR 2                 // interrupt status register
LCR = 3                 # line control register
LCR_EIGHT_BITS = 3<<0
LCR_BAUD_LATCH = 1<<7   # special mode to set baud rate
#define LSR 5                 // line status register
#define LSR_RX_READY (1<<0)   // input is waiting to be read from RHR
#define LSR_TX_IDLE (1<<5)    // THR can accept another character to send
LSR = 5 # Line Status Register
LSR_TX_IDLE = 1 << 5

class UART:

    def __init__(self, size, uart_output_file):
        # handle hold the lifetime of mmap object
        self.size = size
        #self.handle = gen('mem.dat', size)
        #self.data = next(self.handle)
        self.data = bytearray(size)
        self.data[LSR] = 1
        self.allow_send = True
        self.received_interrupt_enabled = False
        self.transmit_interrupt_enabled = False
        self.dlab = False # Divisor Latch Access Bit
        self.dll = 0
        self.dlm = 0
        # lets default to 8bit no parity
        self.filo_enabled = False
        self.output = uart_output_file

    def __len__(self):
        return len(self.data)

    def read(self, address, size):
        assert size == 1
        value = self.data[address] & 0xff
        match address:
            case 5:
                # LSR
                if self.allow_send:
                    value = LSR_TX_IDLE
        #logger.debug(f'*** uart read {size} bytes from address {address}: {value}')
        return value

    def write(self, address, size, value):
        assert size == 1, f'invalid address size {address}'
        value &= 0xff
        #logger.debug(f'*** uart write {size} bytes to address {address}: 0x{value:02X}')

        self.data[address] = value
        match address:
            case 0:
                if self.dlab:
                    self.dll = value
                else:
                    # THR
                    if self.output:
                        self.output.write(chr(value).encode())
            case 1:
                if self.dlab:
                    self.dlm = value
                else:
                    # IER: interrupt enable register
                    self.received_interrupt_enabled = bool(value | IER_RX_ENABLE)
                    self.transmit_interrupt_enabled = bool(value | IER_TX_ENABLE)
            case 2:
                # FCR: FILO control register
                self.filo_enabled = bool(value | FCR_FIFO_ENABLE)
                self.filo_reset = bool(value | FCR_FIFO_CLEAR)

            case 3:
                self.dlab = bool(value & LCR_BAUD_LATCH)
            

