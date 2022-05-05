import argparse
import sys

from riscvm import CPU
from riscvm.bus import Bus
from riscvm.exception import StopException
from riscvm.ram import RAM

class Emulator:

    def __init__(self, program):
        ram = RAM()
        ram.data = bytearray(program)
        bus = Bus()
        bus = Bus().add_device(ram, (0, len(ram)))
        self.cpu = CPU(bus)

    def run(self):
        try:
            while self.cpu.fetch():
                self.cpu.execute()
        except StopException:
            pass

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('file', nargs='?', type=argparse.FileType('rb'), default=sys.stdin.buffer)
    args = parser.parse_args()
    data = args.file.read()
    Emulator(data).run()
