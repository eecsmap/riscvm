import argparse
import sys

from riscvm import CPU
from riscvm.bus import Bus
from riscvm.ram import RAM

class Emulator:

    def __init__(self, program):
        ram = RAM(len(program))
        ram.load(program)
        bus = Bus()
        bus.add_device(ram, (0, len(ram)))
        self.cpu = CPU(bus)

    def run(self):
        while self.cpu.fetch():
            self.cpu.execute()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('file', nargs='?', type=argparse.FileType('rb'), default=sys.stdin.buffer)
    args = parser.parse_args()
    data = args.file.read()
    Emulator(data).run()
