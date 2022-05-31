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
from riscvm.utils import regc
import binascii
import logging
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

    def __init__(self, program, uart_output_file=None, address=0):
        ram = RAM()
        ram.data = bytearray(program)
        stack = RAM(0x8000000) # 128MB for bss, stack, etc.
        bus = Bus()
        # hack: xv6 kernel bin assume to have this place as stack
        stack_begin = ((len(ram) + 0x1000 - 1) >> 12 << 12) + address
        bus = Bus().add_device(ram, (address, len(ram))).add_device(stack, (stack_begin, len(stack)))
        self.cpu = CPU(bus)
        #self.cpu.pc.value = address
        #self.cpu.sp.value = (stack_end - 1) & -16
        # core local interrupt
        clint_base = 0x200_0000
        clint_size = 0x1_0000
        clint = RAM(clint_size)
        mtime = 0xbff8
        clint.write(mtime, 8, 0xfd03)
        bus.add_device(clint, (clint_base, clint_size))
        UART_BASE = 0x1000_0000
        UART_SIZE = 0x100
        bus.add_device(UART(UART_SIZE, uart_output_file), (UART_BASE, UART_SIZE))
        bootloader = RAM()
        bootloader.data = bytearray(binascii.unhexlify('9702000013868202732540f183b5020283b282016780020000000080000000000000008700000000'))
        bus.add_device(bootloader, (0x1000, len(bootloader)))
        self.cpu.pc.value = 0x1000


if __name__ == '__main__':
    import sys
    parser = argparse.ArgumentParser()
    parser.add_argument('--address', type=lambda x: int(x, 16), default=0)
    parser.add_argument('file', nargs='?', type=argparse.FileType('rb'), default=sys.stdin.buffer)
    parser.add_argument('uart_output', nargs='?', type=argparse.FileType('wb'), default=sys.stdout.buffer)
    args = parser.parse_args()
    #data = args.file.read()
    import mmap
    mm = mmap.mmap(args.file.fileno(), 0, flags=mmap.MAP_PRIVATE)
    data = bytearray(mm)
    XV6(data, args.uart_output, address=args.address).run()
