'''
cProfile a fixed number of real instructions of the xv6 boot
(tests/xv6-kernel-fs-small.bin), to find where the interpreter actually
spends its time.

Usage: python3 tools/profile_xv6_boot.py [instruction_count]  (from repo root)
'''
import os
import sys
import cProfile
import pstats

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

N = int(sys.argv[1]) if len(sys.argv) > 1 else 2_000_000


def run():
    count = 0
    while emu.cpu.fetch() and count < N:
        emu.cpu.execute()
        count += 1


pr = cProfile.Profile()
pr.enable()
run()
pr.disable()

stats = pstats.Stats(pr)
stats.sort_stats('cumulative')
stats.print_stats(25)
print('=== by tottime (self time, excludes callees) ===')
stats.sort_stats('tottime')
stats.print_stats(25)
