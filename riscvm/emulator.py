import argparse
import sys

from riscvm import CPU
from riscvm.bus import Bus
from riscvm.instruction import get_asm, info
from riscvm.ram import RAM

class Emulator:

    def __init__(self, program, address=0):
        ram = RAM()
        ram.data = bytearray(program)
        bus = Bus()
        bus = Bus().add_device(ram, (address, address + len(ram)))
        self.cpu = CPU(bus)
        self.cpu.pc.value = address

    def run(self, limit=0):
        count = 0
        while self.cpu.fetch():
            print(f'{self.cpu.pc.value:016X}: ({self.cpu.instruction.value:08X}) {get_asm(self.cpu.instruction, use_symbol=True, pc=self.cpu.pc.value)}')
            print(info(self.cpu.instruction))
            for reg in self.cpu.registers:
                print(reg)
            self.cpu.execute()
            count += 1
            if (limit and count == limit):
                break

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('file', nargs='?', type=argparse.FileType('rb'), default=sys.stdin.buffer)
    args = parser.parse_args()
    data = args.file.read()
    Emulator(data).run()
