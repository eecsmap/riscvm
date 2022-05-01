import argparse
import sys

from riscvm import CPU
from riscvm import Instruction

class Emulator:

    def __init__(self, program):
        self.cpu = CPU()
        self.cpu.bus.ram.load(program)
        

    def run(self):
        while self.cpu.fetch():
            self.cpu.execute()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('file', nargs='?', type=argparse.FileType('rb'), default=sys.stdin.buffer)
    args = parser.parse_args()
    data = args.file.read()
    Emulator(data).run()