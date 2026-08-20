import io
from riscvm.uart import UART

RBR = 0
IER = 1
LSR = 5

def make_uart(uart_input_file=None):
    return UART(0x100, io.BytesIO(), uart_input_file)

def test_no_data_available_by_default():
    uart = make_uart()
    assert uart.read(LSR, 1) & 0x1 == 0
    assert uart.interrupt_status == 0

def test_inject_makes_data_available_and_readable():
    uart = make_uart()
    uart.inject(b'ls\n')
    assert uart.read(LSR, 1) & 0x1 == 1
    assert uart.read(RBR, 1) == ord('l')
    assert uart.read(RBR, 1) == ord('s')
    assert uart.read(RBR, 1) == ord('\n')
    # queue drained: LSR data-ready bit drops back to 0
    assert uart.read(LSR, 1) & 0x1 == 0

def test_rbr_read_without_data_returns_zero_not_garbage():
    uart = make_uart()
    assert uart.read(RBR, 1) == 0

def test_ier_bit_test_is_and_not_or():
    # the IER setter used to do `bool(value | IER_RX_ENABLE)`, which is
    # truthy for nearly any value regardless of whether the bit is actually
    # set -- disabling RX interrupts (writing 0) never worked.
    uart = make_uart()
    uart.write(IER, 1, 0x3)  # enable both RX and TX interrupt sources
    assert uart.interrupt_enabled_received_data_available is True
    uart.write(IER, 1, 0x0)  # disable everything
    assert uart.interrupt_enabled_received_data_available is False

def test_interrupt_status_requires_both_data_and_enable():
    uart = make_uart()
    uart.inject(b'x')
    assert uart.interrupt_status == 0  # RX interrupts not enabled yet
    uart.write(IER, 1, 0x1)  # enable RX interrupt
    assert uart.interrupt_status == 1
    uart.read(RBR, 1)  # drain the byte
    assert uart.interrupt_status == 0

def test_poll_input_from_a_plain_stream_without_fileno():
    source = io.BytesIO(b'ls\n')
    uart = make_uart(uart_input_file=source)
    uart.poll_input()
    assert bytes(uart.rx_queue) == b'ls\n'
