from riscvm.instruction import Instruction

if __name__ == '__main__':
    import argparse
    import sys
    parser = argparse.ArgumentParser()
    parser.add_argument('file', nargs='?', type=argparse.FileType('r'), default=sys.stdin)
    args = parser.parse_args()
    for line in args.file:
        if line:
            value = int(line.strip(), 16)
            print(Instruction(value))
