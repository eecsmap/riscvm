import argparse
import sys

from riscvm import CPU
from riscvm.bus import Bus
from riscvm.instruction import get_asm, info
from riscvm.ram import RAM
from riscvm.uart import UART

class Emulator:

    def __init__(self, program, uart_output_file, address=0):
        ram = RAM()
        ram.data = bytearray(program)
        stack = RAM(0x200000) # 20MB for bss, stack, etc.
        bus = Bus()
        # hack: xv6 kernel bin assume to have this place as stack
        stack_begin = 0xb000
        bus = Bus().add_device(ram, (address, len(ram))).add_device(stack, (stack_begin, len(stack)))
        self.cpu = CPU(bus)
        self.cpu.pc.value = address
        #self.cpu.sp.value = (stack_end - 1) & -16
        # core local interrupt
        clint_base = 0x200_0000
        clint_size = 0x1_0000
        bus.add_device(RAM(clint_size), (clint_base, clint_size))
        UART_BASE = 0x1000_0000
        UART_SIZE = 0x100
        bus.add_device(UART(UART_SIZE, uart_output_file), (UART_BASE, UART_SIZE))

    def run(self, limit=0):
        count = 0
        while self.cpu.fetch():
            print(f'[{count:-5}] {self.cpu.pc.value:016X}: ({self.cpu.instruction.value:08X}) {get_asm(self.cpu.instruction, use_symbol=True, pc=self.cpu.pc.value)}')
            #print(info(self.cpu.instruction))
            self.cpu.execute()
            for reg in self.cpu.registers:
                pass
                #print(reg)
            count += 1
            #if count == 90: break # before calling consoleinit()
            #if count == 440: break # checking .con
            if (limit and count == limit):
                break

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('file', nargs='?', type=argparse.FileType('rb'), default=sys.stdin.buffer)
    parser.add_argument('uart_output', nargs='?', type=argparse.FileType('wb'), default=sys.stdout.buffer)
    args = parser.parse_args()
    data = args.file.read()
    Emulator(data, args.uart_output).run()
