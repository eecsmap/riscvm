'''
riscv-privileged: Volume 2, Privileged Spec v. 20211203

https://github.com/riscv/riscv-isa-manual/releases/download/Priv-v1.12/riscv-privileged-20211203.pdf

'''

# Note that although CSRs and instructions are associated with one privilege level,
# they are also accessible at all higher privilege levels.

# csr[11:0] 12-bit encoding space for up to 4096 CSRs.

# Attempts to access a non-existent CSR raise an illegal instruction exception.

# Attempts to access a CSR without appropriate privilege level
# or to write a read-only register also raise illegal instruction exceptions.

# A read/write register might also contain some bits that are read-only,
# in which case writes to the read-only bits are ignored.

# The CSR addresses designated for custom uses
# will not be redefined by future standard extensions.
from enum import Enum, auto

class PrivilegeLevel(Enum):
    U = 0
    USER = 0
    APPLICATION = 0
    UNPRIVILEGED = 0
    S = 1
    SUPERVISOR = 1
    HYPERVISOR = 2
    M = 3
    MACHINE = 3

# The machine level has the highest privileges
# and is the only mandatory privilege level for a RISC-V hardware platform.

class CSR(Enum):
    SSTATUS = 0x100
    SIE = 0x104
    STVEC = 0x105
    SSCRATCH = 0x140
    SEPC = 0x141
    SCAUSE = 0x142
    STVAL = 0x143
    SIP = 0x144
    # Sstc. With it a supervisor timer interrupt comes from `time >= stimecmp`
    # directly, so S-mode reprograms its own timer with a single CSR write.
    # Without it the only timer is the CLINT's memory-mapped mtimecmp, which
    # S-mode cannot reach -- forcing the M-mode timervec trampoline that
    # rearms the CLINT and reflects the tick down as a software interrupt.
    # xv6 has used stimecmp since commit 92e60dd.
    STIMECMP = 0x14d
    SATP = 0x180
    MSTATUS = 0x300
    MEDELEG = 0x302
    MIDELEG = 0x303
    MIE = 0x304
    MTVEC = 0x305
    # Which counters S/U mode may read. xv6's timerinit() sets bit 1 (TM) so
    # supervisor code can read `time`; without it that read is illegal.
    MCOUNTEREN = 0x306
    # Bit 63 (STCE) is what enables Sstc.
    MENVCFG = 0x30a
    MSCRATCH = 0x340
    MEPC = 0x341
    MCAUSE = 0x342
    MTVAL = 0x343
    MIP = 0x344
    # Read-only shadow of the CLINT's mtime. Architecturally `time` is not an
    # independent counter -- it is the same real-time counter mtime exposes.
    TIME = 0xc01
    MHARTID = 0xf14

    def __str__(self):
        return f'{self.name}'
