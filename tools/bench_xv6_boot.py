'''
Throughput benchmark: how many instructions/sec does the interpreter
sustain while booting the real xv6 kernel (tests/xv6-kernel-fs-small.bin)?

Usage: python3 tools/bench_xv6_boot.py [seconds]  (run from the repo root)

Useful for comparing interpreter changes, or alternative Python engines
(e.g. PyPy) against CPython, on a fixed, realistic workload rather than a
synthetic loop.
'''
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from riscvm.emulator import XV6

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ROOT, 'tests', 'xv6-kernel-fs-small.bin'), 'rb') as f:
    kernel = bytearray(f.read())
with open(os.path.join(ROOT, 'tests', 'fs.img'), 'rb') as f:
    fs_image = f.read()


class Sink:
    def write(self, b):
        pass


emu = XV6(kernel, Sink(), address=0x80000000, disk_image=fs_image)

budget = float(sys.argv[1]) if len(sys.argv) > 1 else 30.0
start = time.time()
count = 0
while emu.cpu.fetch():
    emu.cpu.execute()
    count += 1
    if time.time() - start > budget:
        break
elapsed = time.time() - start
print(f'engine={sys.implementation.name} count={count} elapsed={elapsed:.2f}s rate={count/elapsed:.0f} instr/s')
