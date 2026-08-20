'''
Sv39 page-table translation (RISC-V privileged spec).

refer: riscv-privileged-20211203.pdf, section 4.4 "Sv39: Page-Based 39-bit
Virtual-Memory System"

xv6 runs identity-mapped (VA == PA) for almost everything, but places
per-process kernel stacks and the trampoline at high virtual addresses
that only exist through the page table (see KSTACK/TRAMPOLINE in
kernel/memlayout.h), so once satp switches on paging those accesses need
real translation.

There is no privilege-mode tracking in this emulator (MRET is just a jump
to mepc), so unlike real hardware we don't exempt M-mode from translation;
translation is simply gated on satp's MODE field.
'''

from riscvm.exception import error
from riscvm.csr import CSR

SATP_CSR = CSR.SATP.value

MODE_BARE = 0
MODE_SV39 = 8

PAGESIZE = 0x1000
PTE_SIZE = 8
LEVELS = 3

PTE_V = 1 << 0
PTE_R = 1 << 1
PTE_W = 1 << 2
PTE_X = 1 << 3

PPN_MASK = (1 << 44) - 1

def translate(cpu, va, access):
    '''
    Translate a virtual address through Sv39 paging, if satp enables it.
    access is one of 'r', 'w', 'x'. Returns va unchanged when paging is off.
    '''
    satp = cpu.csrs.get(SATP_CSR, 0)
    mode = satp >> 60
    if mode == MODE_BARE:
        return va
    if mode != MODE_SV39:
        error(f'unsupported satp MODE {mode} (only Bare and Sv39 are implemented)')

    vpn = [(va >> 12) & 0x1ff, (va >> 21) & 0x1ff, (va >> 30) & 0x1ff]

    a = (satp & PPN_MASK) * PAGESIZE
    level = LEVELS - 1
    while level >= 0:
        pte_addr = a + vpn[level] * PTE_SIZE
        pte = cpu.bus.read(pte_addr, PTE_SIZE)  # page table entries live in physical memory: no translation here
        if not pte & PTE_V:
            error(f'page fault: invalid PTE translating VA 0x{va:x} (level {level}, pte 0x{pte:x} @0x{pte_addr:x})')
        if pte & (PTE_R | PTE_X):
            break  # leaf
        if pte & PTE_W:
            error(f'page fault: reserved PTE encoding (W without R/X) translating VA 0x{va:x}')
        a = ((pte >> 10) & PPN_MASK) * PAGESIZE
        level -= 1
    else:
        error(f'page fault: page table walk exhausted translating VA 0x{va:x}')

    required = {'r': PTE_R, 'w': PTE_W, 'x': PTE_X}[access]
    if not pte & required:
        error(f'page fault: permission denied ({access}) translating VA 0x{va:x} (pte 0x{pte:x})')

    ppn = (pte >> 10) & PPN_MASK
    if level > 0:
        # superpage: the low-order PPN fields must come from the VA, and the
        # PTE's corresponding bits must be zero (a misaligned superpage)
        low_mask = (1 << (9 * level)) - 1
        if ppn & low_mask:
            error(f'page fault: misaligned superpage translating VA 0x{va:x}')
        va_low = 0
        for l in range(level):
            va_low |= vpn[l] << (9 * l)
        ppn = (ppn & ~low_mask) | va_low

    return (ppn << 12) | (va & 0xfff)
