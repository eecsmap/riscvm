from binascii import unhexlify
from io import StringIO
from tempfile import NamedTemporaryFile
import logging
import re
import subprocess
import argparse
import sys

logger = logging.getLogger(__name__)

'''
$ python3 as.py 
addi s0, sp, 16
b'\x00\x08'
mv a0, a1
b'.\x85'
add a0, a1, a2
b'3\x85\xc5\x00'
$ python3 as.py --dis
800
['addi', 's0', 'sp', '16']
deadbeef
['jal', 't4', '0xfffffffffffdb5ea']
'''

# riscv64-linux-gnu-gcc -v
# --with-arch=rv64gc --with-abi=lp64d

def get_instruction_value(asm):

    cmd = [
        'riscv64-linux-gnu-gcc',
        '-c',
        '-x', 'assembler',
        '-o', 'temp.o',
        '/dev/stdin'
    ]
    subprocess.run(cmd, input=asm if asm.endswith('\n') else f'{asm}\n', text=True, check=True)

    cmd = [
        'riscv64-linux-gnu-objcopy',
        '-O', 'binary',
        'temp.o',
        '/dev/stdout'
    ]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)

    cmd = [
        'xxd',
        '-ps'
    ]
    return unhexlify(subprocess.run(cmd, stdin=p.stdout, capture_output=True, check=True).stdout.strip())

def dis(uint32_value):
    with NamedTemporaryFile(delete=True) as f:
        data = (uint32_value).to_bytes(4 if uint32_value & 0xFFFF0000 else 2, byteorder='little')
        f.write(data)
        f.flush()
        cmd = [
            'riscv64-linux-gnu-objdump',
            '-b', 'binary',
            '-m', 'riscv:rv64',
            '-D',
            f.name
        ]
        logger.debug(f'data: {data}')
        stdout = subprocess.run(cmd, capture_output=True, text=True).stdout
        logger.debug(f'stdout: {stdout}')
        last_line = stdout.splitlines()[-1].strip()
        parts = re.split(r'[ \t,]+', last_line)
    return parts[2:]

def loopback(asm):
    value = get_instruction_value(asm if asm.endswith('\n') else f'{asm}\n')
    expected = re.split(r'[ \t,]+', asm.strip())
    logger.debug(f'expected: {expected}')
    result = dis(int.from_bytes(value, byteorder='little'))
    logger.debug(f'result: {result}')
    assert expected == result, f'{expected} != {result}'

def main():
    argparser = argparse.ArgumentParser()
    argparser.add_argument('--dis', action='store_true')
    args = argparser.parse_args()
    if args.dis:
        for line in sys.stdin:
            print(dis(int(line.strip(), 16)))
    else:
        for line in sys.stdin:
            loopback(line)
            print(f'{int.from_bytes(get_instruction_value(line), byteorder="little"):x}')
 
if __name__ == '__main__':
    logging.basicConfig(format='%(asctime)s [%(levelname)s] %(name)s: %(message)s', level=logging.WARNING)
    exit(main())
