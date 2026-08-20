import argparse

import logging.config


LOGGING_CONFIG = {
    'version': 1,
    'disable_existing_loggers': True,
    'formatters': {
        'standard': {
            'format': '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
        },
        'riscvm': {
            'format': '%(message)s'
        }
    },
    'handlers': {
        'default': {
            'level': 'DEBUG',
            'formatter': 'standard',
            'class': 'logging.StreamHandler',
            'stream': 'ext://sys.stdout',  # Default is stderr
        },
        'riscvm': {
            'level': 'DEBUG',
            'formatter': 'riscvm',
            'class': 'logging.StreamHandler',
            'stream': 'ext://sys.stdout',  # Default is stderr
        }
    },
    'loggers': {
        '': {  # root logger
            'handlers': ['default'],
            'level': 'WARNING',
            'propagate': False
        },
        'riscvm': {
            'handlers': ['riscvm'],
            'level': 'INFO',
            'propagate': True
        },
        # 'riscvm.bus': {
        #     'handlers': ['riscvm'],
        #     'level': 'INFO',
        #     'propagate': False
        # },
        'riscvm.uart': {
            'handlers': ['riscvm'],
            'level': 'DEBUG',
            'propagate': False
        },
        '__main__': {  # if __name__ == '__main__'
            'handlers': ['riscvm'],
            'level': 'DEBUG',
            'propagate': False
        },
    }
}

logging.config.dictConfig(LOGGING_CONFIG)

from riscvm import CPU
from riscvm.exception import InternalException, error
from riscvm.bus import Bus
from riscvm.rv64i import get_asm, info
from riscvm.ram import RAM
from riscvm.uart import UART
from riscvm.virtio import VirtIOBlk
from riscvm.clint import CLINT
from riscvm.plic import PLIC
from riscvm.utils import regc
import binascii
import logging
import os
logger = logging.getLogger(__name__)

class Emulator:

    def __init__(self, program, uart_output_file=None, address=0):
        ram = RAM()
        ram.data = bytearray(program)
        stack = RAM(0x8000000) # 128MB for bss, stack, etc.
        bus = Bus()
        # hack: xv6 kernel bin assume to have this place as stack
        stack_begin = ((len(ram) + 0x1000 - 1) >> 12 << 12) + address
        bus = Bus().add_device(ram, (address, len(ram))).add_device(stack, (stack_begin, len(stack)))
        self.cpu = CPU(bus)
        self.cpu.pc.value = address

    def dump_registers(self):
        for i, r in enumerate(self.cpu.registers[1:]):
            print(regc(i+1), f'0x{r.value:x}')
        print('pc', f'0x{self.cpu.pc.value:x}')

    def run(self, limit=0):
        count = 0
        try:
            while self.cpu.fetch():
                #if count % 100000 == 0:
                #
                if count % 10000 == 0:
                    print(count, end='\r')
                #print(f'[{count:-5}] {self.cpu.pc.value:016x}: ({self.cpu.instruction.value:0{2 * self.cpu.instruction.size}x})\t{self.cpu.instruction.asm(pc=self.cpu.pc.value)}')#, use_symbol=True, pc=self.cpu.pc.value)}')
                #print(f'=> {self.cpu.pc.value:016x}: ({self.cpu.instruction.value:0{2 * self.cpu.instruction.size}x})\t{self.cpu.instruction.asm(pc=self.cpu.pc.value)}')#, use_symbol=True, pc=self.cpu.pc.value)}')
                #logger.debug(info(self.cpu.instruction))
                self.cpu.execute()
                #self.dump_registers()
                count += 1
                #if count == 90: break # before calling consoleinit()
                #if count == 440: break # checking .con
                if (limit and count == limit):
                    break
        except InternalException as e:
            print(e)
            self.dump_registers()
            print(f'[{count:-5}] {self.cpu.pc.value:016x}: ({self.cpu.instruction.value:0{2 * self.cpu.instruction.size}x})\t{self.cpu.instruction.asm(pc=self.cpu.pc.value)}')
            raise e
        except KeyboardInterrupt:
            print('\n')
            self.dump_registers()
            print(f'[{count:-5}] {self.cpu.pc.value:016x}: ({self.cpu.instruction.value:0{2 * self.cpu.instruction.size}x})\t{self.cpu.instruction.asm(pc=self.cpu.pc.value)}')
            raise

class XV6(Emulator):

    def __init__(self, program, uart_output_file=None, address=0, disk_image=None, uart_input_file=None):
        ram = RAM()
        # pad up to the next page boundary: a raw `objcopy -O binary` image
        # doesn't always include .bss (depends on the toolchain/linker
        # script), so the kernel can genuinely read/write just past the
        # loaded bytes before reaching the (already-mapped, zero-filled)
        # stack region below -- that gap needs to be real, zeroed RAM, not
        # a hole no device covers.
        stack_begin = ((len(program) + 0x1000 - 1) >> 12 << 12) + address
        ram.data = bytearray(program) + bytearray(stack_begin - address - len(program))
        stack = RAM(0x8000000) # 128MB for bss, stack, etc.
        bus = Bus()
        # hack: xv6 kernel bin assume to have this place as stack
        bus = Bus().add_device(ram, (address, len(ram))).add_device(stack, (stack_begin, len(stack)))
        self.cpu = CPU(bus)
        #self.cpu.pc.value = address
        #self.cpu.sp.value = (stack_end - 1) & -16
        # core local interrupt
        clint_base = 0x200_0000
        clint_size = 0x1_0000
        clint = CLINT(clint_size)
        bus.add_device(clint, (clint_base, clint_size))
        self.cpu.clint = clint
        UART_BASE = 0x1000_0000
        UART_SIZE = 0x100
        uart = UART(UART_SIZE, uart_output_file, uart_input_file)
        bus.add_device(uart, (UART_BASE, UART_SIZE))
        self.cpu.uart = uart
        virtio_disk_base = 0x10001000
        virtio_disk_size = 0x1000
        virtio = VirtIOBlk(bus, disk_image=disk_image)
        bus.add_device(virtio, (virtio_disk_base, virtio_disk_size))
        VIRTIO0_IRQ = 1
        UART0_IRQ = 10
        plic_base = 0x0C00_0000
        plic_size = 0x0FFF_FFFF - plic_base + 1
        plic = PLIC(plic_size, devices_by_irq={VIRTIO0_IRQ: virtio, UART0_IRQ: uart})
        bus.add_device(plic, (plic_base, plic_size))
        self.cpu.plic = plic
        # virtio_net_base = 0x10002000
        # virtio_net_size = 0x1000
        # bus.add_device(RAM(virtio_net_size), (virtio_net_base, virtio_net_size))

        bootloader = RAM()
        bootloader.data = bytearray(binascii.unhexlify('9702000013868202732540f183b5020283b282016780020000000080000000000000008700000000'))
        bus.add_device(bootloader, (0x1000, len(bootloader)))
        self.cpu.pc.value = 0x1000


if __name__ == '__main__':
    import sys
    parser = argparse.ArgumentParser()
    parser.add_argument('--address', type=lambda x: int(x, 16), default=0)
    parser.add_argument('--fs-image', type=argparse.FileType('rb'), default=None,
                         help='xv6 filesystem image (built via mkfs) to back the virtio disk')
    parser.add_argument('--uart-input', type=argparse.FileType('rb'), default=None,
                         help='source of console input bytes; defaults to the terminal when stdin is a tty')
    parser.add_argument('file', nargs='?', type=argparse.FileType('rb'), default=sys.stdin.buffer)
    parser.add_argument('uart_output', nargs='?', type=argparse.FileType('wb'), default=sys.stdout.buffer)
    args = parser.parse_args()
    #data = args.file.read()
    import mmap
    mm = mmap.mmap(args.file.fileno(), 0, flags=mmap.MAP_PRIVATE)
    data = bytearray(mm)
    disk_image = args.fs_image.read() if args.fs_image else None
    uart_input = args.uart_input
    if uart_input is None and args.file is not sys.stdin.buffer and sys.stdin.isatty():
        # let the shell's `$ ` prompt actually be usable when run normally
        # (kernel image given as a real file, terminal attached); a fully
        # scripted/piped invocation opts in explicitly via --uart-input
        uart_input = sys.stdin.buffer
        os.set_blocking(uart_input.fileno(), False)
    XV6(data, args.uart_output, address=args.address, disk_image=disk_image, uart_input_file=uart_input).run()
