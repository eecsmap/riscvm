import struct
from binascii import unhexlify
from riscvm import CPU
from riscvm.csr import CSR
from riscvm.emulator import Emulator, XV6
from riscvm.exception import InternalException
from pytest import raises

# code are put as hex string for two reasons:
# 1. easy to write the tests.
# 2. tests run faster without reading test programs from files.
# Refer to project README to get instructions on how to build test programs.

def test_fib():
    code = unhexlify('9307f5ff6354a00213071000930600001306f0ff130507009387f7ff3307d70093060500e398c7fe678000001305000067800000')
    load_address = 0x1000 # load code to first page; this is just a demo with arbitrary value
    emulator = Emulator(code, address=load_address)
    emulator.cpu.registers[10].value = 80 # set a0 to 80 to get fib(80)
    with raises(InternalException):
        emulator.run()
    assert emulator.cpu.registers[10].value == 23416728348467685

def test_xv6_zero_pads_up_to_page_boundary_past_the_loaded_image():
    # a raw `objcopy -O binary` image doesn't always include .bss: reading
    # or writing just past the loaded bytes (but still within the same
    # page) must hit real, zeroed RAM rather than an unmapped gap between
    # the kernel image device and the stack device that starts on the next
    # page boundary.
    program = bytes(100)  # not page-aligned
    xv6 = XV6(program, address=0x80000000)
    gap_address = 0x80000000 + len(program) + 16
    assert xv6.cpu.bus.read(gap_address, 4) == 0
    xv6.cpu.bus.write(gap_address, 4, 0xdeadbeef)
    assert xv6.cpu.bus.read(gap_address, 4) == 0xdeadbeef

def test_xv6_disk_image_reaches_the_virtio_device():
    image = bytes([0x11, 0x22, 0x33, 0x44]) + bytes(4092)
    xv6 = XV6(bytes(64), address=0x80000000, disk_image=image)
    virtio_disk_base = 0x10001000
    device, rng = xv6.cpu.bus.get_device(virtio_disk_base, 1)
    assert device.disk[:4] == bytes([0x11, 0x22, 0x33, 0x44])

def test_xv6_uart_console_input_reaches_the_shell():
    # end-to-end: injecting bytes into the UART the same way live keyboard
    # input would (cpu.uart.inject) makes them readable through the RBR
    # register at the real UART address, and the UART is wired into the
    # PLIC on the interrupt line xv6's driver expects (UART0_IRQ = 10).
    xv6 = XV6(bytes(64), address=0x80000000)
    assert xv6.cpu.uart is not None
    UART0_IRQ = 10
    assert xv6.cpu.plic.devices_by_irq[UART0_IRQ] is xv6.cpu.uart

    xv6.cpu.uart.inject(b'ls\n')
    UART_BASE = 0x1000_0000
    RBR, LSR = 0, 5
    assert xv6.cpu.bus.read(UART_BASE + LSR, 1) & 0x1 == 1
    assert xv6.cpu.bus.read(UART_BASE + RBR, 1) == ord('l')

def test_xv6_smp_boots_one_cpu_object_per_hart():
    # --smp N (real qemu's own flag name) should give us N independent CPU
    # objects -- like N harts resetting at the same vector on real
    # hardware -- each with its own mhartid CSR but sharing the single
    # CLINT/PLIC/UART/bus every hart on the same board would share.
    xv6 = XV6(bytes(64), address=0x80000000, ncpu=3)
    assert len(xv6.cpus) == 3
    assert xv6.cpu is xv6.cpus[0]  # back-compat: XV6.cpu is still hart 0

    for expected_hartid, cpu in enumerate(xv6.cpus):
        assert cpu.hartid == expected_hartid
        assert cpu.csrs[CSR.MHARTID.value] == expected_hartid
        assert cpu.pc.value == 0x1000  # every hart resets at the same vector
        assert cpu.bus is xv6.cpu.bus
        assert cpu.clint is xv6.cpu.clint
        assert cpu.plic is xv6.cpu.plic
        assert cpu.uart is xv6.cpu.uart

    assert xv6.cpu.clint.nhart == 3

def test_xv6_default_ncpu_is_a_single_hart():
    xv6 = XV6(bytes(64), address=0x80000000)
    assert len(xv6.cpus) == 1
    assert xv6.cpu.clint.nhart == 1

def test_xv6_rejects_ncpu_zero():
    # ncpu=0 used to silently build an empty cpus list, so self.cpu =
    # self.cpus[0] raised an opaque IndexError instead of a clear error.
    with raises(AssertionError):
        XV6(bytes(64), address=0x80000000, ncpu=0)

def test_run_round_robins_harts_so_a_spin_wait_actually_unblocks():
    # this is the same shape as xv6's real boot handshake: hart 0 does some
    # work then sets a shared flag (kernel/main.c's `started`), and hart 1
    # busy-waits on it (`while(started == 0);`) before proceeding. If run()
    # let one hart run to completion before ever scheduling another, hart
    # 1's spin loop here (and xv6's) would never see hart 0's write.
    code = bytearray(0x1114)
    struct.pack_into('<I', code, 0x1000, 0x00100293)  # addi t0, x0, 1
    struct.pack_into('<I', code, 0x1004, 0x00502023)  # sw   t0, 0(x0)      -- flag <- 1
    struct.pack_into('<I', code, 0x1008, 0x0000006f)  # jal  x0, 0          -- spin forever
    struct.pack_into('<I', code, 0x1100, 0x00002303)  # lw   t1, 0(x0)      -- read flag
    struct.pack_into('<I', code, 0x1104, 0xfe030ee3)  # beq  t1, x0, -4     -- spin while flag == 0
    struct.pack_into('<I', code, 0x1108, 0x00200393)  # addi t2, x0, 2
    struct.pack_into('<I', code, 0x110c, 0x00702223)  # sw   t2, 4(x0)      -- marker <- 2
    struct.pack_into('<I', code, 0x1110, 0x0000006f)  # jal  x0, 0          -- spin forever

    emu = Emulator(code, address=0)
    emu.cpu.pc.value = 0x1000
    hart1 = CPU(emu.cpu.bus)
    hart1.pc.value = 0x1100
    emu.cpus.append(hart1)

    emu.run(limit=8)

    assert emu.cpu.bus.read(0, 4) == 1  # hart 0's flag write went through
    assert emu.cpu.bus.read(4, 4) == 2  # hart 1 saw it and left its spin loop
