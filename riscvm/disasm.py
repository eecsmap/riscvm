import argparse
import struct
import sys

from riscvm import get_asm, Instruction

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('file', nargs='?', type=argparse.FileType('rb'), default=sys.stdin.buffer)
    args = parser.parse_args()
    data = args.file.read(4)
    while data:
        print(get_asm(Instruction(struct.unpack('<i', data)[0]), use_symbol=True))
        data = args.file.read(4)
