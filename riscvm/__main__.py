from riscvm.rv64c import Instruction as RV64C_Instruction
from riscvm.rv64i import Instruction as RV64I_Instruction

if __name__ == '__main__':
    import argparse
    import sys
    parser = argparse.ArgumentParser()
    parser.add_argument('file', nargs='?', type=argparse.FileType('r'), default=sys.stdin)
    args = parser.parse_args()
    for line in args.file:
        if line:
            data = int(line.strip(), 16)
            Instruction = RV64I_Instruction if data & 0b11 == 0b11 else RV64C_Instruction
            print(Instruction(data))
