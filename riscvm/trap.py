'''
Trap delivery: exceptions (ECALL, ...) and interrupts (timer, external via
PLIC), plus the sstatus/sie/sip <-> mstatus/mie/mip aliasing those traps
depend on.

refer: riscv-privileged-20211203.pdf, sections 3.1 (mstatus etc.), 3.1.8
(mideleg/medeleg), 3.1.9 (mie/mip)

On real hardware sstatus/sie/sip are not separate storage: they are a
restricted, bit-masked *view* of mstatus/mie/mip. This emulator stores
CSRs in a plain dict (cpu.csrs), so without this module a write to
mstatus and a later read of sstatus would silently disagree. xv6 relies
on exactly this aliasing (e.g. start() sets mstatus.MPP directly, while
push_off()/pop_off() manipulate sstatus.SIE), so csr_read/csr_write here
are the only correct way to touch any of these six CSRs.

There is no privilege-mode tracking anywhere else in this emulator
(MRET used to just jump to mepc), so this module also owns cpu.mode
and the M/S trap-delegation decision (medeleg/mideleg), matching what
xv6's start() sets up (delegates everything to S-mode) before running
almost entirely in S-mode from then on.
'''

from riscvm.csr import CSR, PrivilegeLevel

SSTATUS_MASK = (1 << 1) | (1 << 5) | (1 << 8)   # SIE, SPIE, SPP
SIE_MASK = (1 << 1) | (1 << 5) | (1 << 9)       # SSIE, STIE, SEIE
SIP_MASK = (1 << 1) | (1 << 5) | (1 << 9)       # SSIP, STIP, SEIP

MSTATUS_SIE = 1 << 1
MSTATUS_MIE = 1 << 3
MSTATUS_SPIE = 1 << 5
MSTATUS_MPIE = 1 << 7
MSTATUS_SPP = 1 << 8
MSTATUS_MPP = 0b11 << 11

MIP_SSIP = 1 << 1
MIP_MSIP = 1 << 3
MIP_STIP = 1 << 5
MIP_MTIP = 1 << 7
MIP_SEIP = 1 << 9
MIP_MEIP = 1 << 11

_ALIASED = {
    CSR.SSTATUS.value: (CSR.MSTATUS.value, SSTATUS_MASK),
    CSR.SIE.value: (CSR.MIE.value, SIE_MASK),
    CSR.SIP.value: (CSR.MIP.value, SIP_MASK),
}

def csr_read(cpu, addr):
    alias = _ALIASED.get(addr)
    if alias:
        base_addr, mask = alias
        return cpu.csrs.get(base_addr, 0) & mask
    return cpu.csrs.get(addr, 0)

def csr_write(cpu, addr, value):
    alias = _ALIASED.get(addr)
    if alias:
        base_addr, mask = alias
        base = cpu.csrs.get(base_addr, 0)
        cpu.csrs[base_addr] = (base & ~mask) | (value & mask)
        return
    cpu.csrs[addr] = value

def raise_trap(cpu, cause, is_interrupt, tval=0):
    '''
    Deliver a trap (exception or interrupt), choosing M-mode or S-mode
    per medeleg/mideleg, and return the new pc (the chosen trap vector).
    '''
    deleg = cpu.csrs.get(CSR.MIDELEG.value if is_interrupt else CSR.MEDELEG.value, 0)
    delegate = cpu.mode != PrivilegeLevel.M.value and (deleg >> cause) & 1

    scause_value = cause | (1 << 63) if is_interrupt else cause

    if delegate:
        cpu.csrs[CSR.SEPC.value] = cpu.pc.value
        cpu.csrs[CSR.SCAUSE.value] = scause_value
        cpu.csrs[CSR.STVAL.value] = tval
        mstatus = cpu.csrs.get(CSR.MSTATUS.value, 0)
        sie = bool(mstatus & MSTATUS_SIE)
        mstatus = (mstatus & ~MSTATUS_SPIE) | (MSTATUS_SPIE if sie else 0)
        mstatus &= ~MSTATUS_SIE
        mstatus = (mstatus & ~MSTATUS_SPP) | (MSTATUS_SPP if cpu.mode == PrivilegeLevel.S.value else 0)
        cpu.csrs[CSR.MSTATUS.value] = mstatus
        cpu.mode = PrivilegeLevel.S.value
        return cpu.csrs.get(CSR.STVEC.value, 0) & ~0b11  # direct mode only
    else:
        cpu.csrs[CSR.MEPC.value] = cpu.pc.value
        cpu.csrs[CSR.MCAUSE.value] = scause_value
        cpu.csrs[CSR.MTVAL.value] = tval
        mstatus = cpu.csrs.get(CSR.MSTATUS.value, 0)
        mie = bool(mstatus & MSTATUS_MIE)
        mstatus = (mstatus & ~MSTATUS_MPIE) | (MSTATUS_MPIE if mie else 0)
        mstatus &= ~MSTATUS_MIE
        mstatus = (mstatus & ~MSTATUS_MPP) | (cpu.mode << 11)
        cpu.csrs[CSR.MSTATUS.value] = mstatus
        cpu.mode = PrivilegeLevel.M.value
        return cpu.csrs.get(CSR.MTVEC.value, 0) & ~0b11

# interrupt cause numbers (privileged spec table 3.6)
SUPERVISOR_SOFTWARE_INTERRUPT = 1
MACHINE_SOFTWARE_INTERRUPT = 3
SUPERVISOR_TIMER_INTERRUPT = 5
MACHINE_TIMER_INTERRUPT = 7
SUPERVISOR_EXTERNAL_INTERRUPT = 9
MACHINE_EXTERNAL_INTERRUPT = 11

_PRIORITY = (
    MACHINE_EXTERNAL_INTERRUPT, MACHINE_SOFTWARE_INTERRUPT, MACHINE_TIMER_INTERRUPT,
    SUPERVISOR_EXTERNAL_INTERRUPT, SUPERVISOR_SOFTWARE_INTERRUPT, SUPERVISOR_TIMER_INTERRUPT,
)

def check_interrupt(cpu):
    '''
    Update MIP's hardware-driven bits (MTIP from CLINT, [MS]EIP from PLIC)
    and, if an enabled interrupt is pending and would actually be taken at
    the current privilege/mstatus.[M|S]IE, deliver it.

    Returns True if a trap was taken (pc already updated), else False.
    '''
    mip = cpu.csrs.get(CSR.MIP.value, 0)
    if cpu.clint is not None:
        mip = (mip | MIP_MTIP) if cpu.clint.pending() else (mip & ~MIP_MTIP)
    if cpu.plic is not None:
        mip = (mip | MIP_SEIP) if cpu.plic.claimable(1) else (mip & ~MIP_SEIP)
    cpu.csrs[CSR.MIP.value] = mip

    mie = cpu.csrs.get(CSR.MIE.value, 0)
    pending_enabled = mip & mie
    if not pending_enabled:
        return False

    mstatus = cpu.csrs.get(CSR.MSTATUS.value, 0)
    for cause in _PRIORITY:
        bit = 1 << cause
        if not (pending_enabled & bit):
            continue
        deleg = cpu.csrs.get(CSR.MIDELEG.value, 0)
        delegated = cpu.mode != PrivilegeLevel.M.value and (deleg >> cause) & 1
        if delegated:
            if cpu.mode == PrivilegeLevel.S.value and not (mstatus & MSTATUS_SIE):
                continue
        else:
            if cpu.mode == PrivilegeLevel.M.value and not (mstatus & MSTATUS_MIE):
                continue
        cpu.pc.value = raise_trap(cpu, cause, is_interrupt=True)
        return True
    return False
