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
    MEPC = 0x341
    MSTATUS = 0x300
    MIE = 0x304

    def __str__(self):
        return f'{self.name}'
