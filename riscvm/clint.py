'''
Minimal CLINT (Core-Local Interruptor): mtime + per-hart mtimecmp.

refer: qemu's sifive_clint / xv6-riscv kernel/memlayout.h CLINT_MTIME,
CLINT_MTIMECMP

xv6's timerinit() reads CLINT_MTIME once and sets CLINT_MTIMECMP(hart)
to mtime+interval; its M-mode timervec then reprograms mtimecmp on
every tick. mtime needs to actually advance for that comparison to ever
fire, so unlike the rest of this project's devices this one has to be
driven by the CPU: tick() is called once per instruction (see cpu.py).
'''

MTIME_OFFSET = 0xbff8
MTIMECMP_OFFSET = 0x4000
NHART = 1

class CLINT:

    def __init__(self, size):
        self.size = size
        self.mtime = 0
        self.mtimecmp = [(1 << 64) - 1] * NHART  # start effectively "never"

    def __len__(self):
        return self.size

    def tick(self, amount=1):
        self.mtime = (self.mtime + amount) & ((1 << 64) - 1)

    def pending(self, hart=0):
        return self.mtime >= self.mtimecmp[hart]

    def read(self, address, size):
        assert size == 8, f'clint reads are 8 bytes, got {size}'
        if address == MTIME_OFFSET:
            return self.mtime
        if MTIMECMP_OFFSET <= address < MTIMECMP_OFFSET + 8 * NHART:
            return self.mtimecmp[(address - MTIMECMP_OFFSET) // 8]
        return 0

    def write(self, address, size, value):
        assert size == 8, f'clint writes are 8 bytes, got {size}'
        if address == MTIME_OFFSET:
            self.mtime = value & ((1 << 64) - 1)
        elif MTIMECMP_OFFSET <= address < MTIMECMP_OFFSET + 8 * NHART:
            self.mtimecmp[(address - MTIMECMP_OFFSET) // 8] = value & ((1 << 64) - 1)
