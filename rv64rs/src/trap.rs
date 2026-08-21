//! Corresponds to riscvm/trap.py: CSR aliasing (sstatus/sie/sip are a
//! bit-masked view of mstatus/mie/mip, not separate storage -- xv6 relies
//! on this, e.g. start() sets mstatus.MPP directly while push_off()/
//! pop_off() manipulate sstatus.SIE) and trap delivery (raise_trap,
//! check_interrupt).
//!
use crate::cpu::Cpu;
use crate::csr;

pub const SSTATUS_MASK: u64 = (1 << 1) | (1 << 5) | (1 << 8); // SIE, SPIE, SPP
pub const SIE_MASK: u64 = (1 << 1) | (1 << 5) | (1 << 9); // SSIE, STIE, SEIE
pub const SIP_MASK: u64 = (1 << 1) | (1 << 5) | (1 << 9); // SSIP, STIP, SEIP

pub const MSTATUS_SIE: u64 = 1 << 1;
pub const MSTATUS_MIE: u64 = 1 << 3;
pub const MSTATUS_SPIE: u64 = 1 << 5;
pub const MSTATUS_MPIE: u64 = 1 << 7;
pub const MSTATUS_SPP: u64 = 1 << 8;
pub const MSTATUS_MPP: u64 = 0b11 << 11;

pub const MIP_MTIP: u64 = 1 << 7;
pub const MIP_SEIP: u64 = 1 << 9;

// interrupt cause numbers (privileged spec table 3.6)
pub const SUPERVISOR_SOFTWARE_INTERRUPT: u64 = 1;
pub const MACHINE_SOFTWARE_INTERRUPT: u64 = 3;
pub const SUPERVISOR_TIMER_INTERRUPT: u64 = 5;
pub const MACHINE_TIMER_INTERRUPT: u64 = 7;
pub const SUPERVISOR_EXTERNAL_INTERRUPT: u64 = 9;
pub const MACHINE_EXTERNAL_INTERRUPT: u64 = 11;

const PRIORITY: [u64; 6] = [
    MACHINE_EXTERNAL_INTERRUPT,
    MACHINE_SOFTWARE_INTERRUPT,
    MACHINE_TIMER_INTERRUPT,
    SUPERVISOR_EXTERNAL_INTERRUPT,
    SUPERVISOR_SOFTWARE_INTERRUPT,
    SUPERVISOR_TIMER_INTERRUPT,
];

/// M-mode-only causes (MSI=3, MTI=7, MEI=11) are never delegatable, no
/// matter what's written to mideleg -- real hardware hardwires those bit
/// positions to zero. Without this, xv6's mideleg=0xffff (set once,
/// covering everything) would incorrectly hand a raw machine timer
/// interrupt straight to S-mode instead of the M-mode timervec relaying it
/// via sip.SSIP.
pub const MIDELEG_DELEGATABLE_MASK: u64 =
    !((1 << MACHINE_SOFTWARE_INTERRUPT) | (1 << MACHINE_TIMER_INTERRUPT) | (1 << MACHINE_EXTERNAL_INTERRUPT));

fn aliased_target(addr: u32) -> Option<(u32, u64)> {
    match addr {
        csr::SSTATUS => Some((csr::MSTATUS, SSTATUS_MASK)),
        csr::SIE => Some((csr::MIE, SIE_MASK)),
        csr::SIP => Some((csr::MIP, SIP_MASK)),
        _ => None,
    }
}

pub fn csr_read(cpu: &Cpu, addr: u32) -> u64 {
    if let Some((base_addr, mask)) = aliased_target(addr) {
        cpu.csrs.get(base_addr) & mask
    } else {
        cpu.csrs.get(addr)
    }
}

pub fn csr_write(cpu: &mut Cpu, addr: u32, value: u64) {
    if let Some((base_addr, mask)) = aliased_target(addr) {
        let base = cpu.csrs.get(base_addr);
        cpu.csrs.insert(base_addr, (base & !mask) | (value & mask));
    } else {
        cpu.csrs.insert(addr, value);
    }
    // A satp write can change the active address space (or turn paging on/
    // off); any cached TLB entries could now point at the wrong PPNs or a
    // torn-down mapping. Flushing here (rather than relying solely on the
    // guest issuing SFENCE.VMA afterward) keeps this new TLB from being
    // observable-behavior-changing: before it existed, every access was a
    // fresh walk, so nothing could ever have depended on stale mappings.
    if addr == csr::SATP {
        cpu.tlb.flush();
    }
}

/// Deliver a trap (exception or interrupt), choosing M-mode or S-mode per
/// medeleg/mideleg, and return the new pc (the chosen trap vector).
pub fn raise_trap(cpu: &mut Cpu, cause: u64, is_interrupt: bool, tval: u64) -> u64 {
    let deleg_csr = if is_interrupt { csr::MIDELEG } else { csr::MEDELEG };
    let mut deleg = cpu.csrs.get(deleg_csr);
    if is_interrupt {
        deleg &= MIDELEG_DELEGATABLE_MASK;
    }
    let delegate = cpu.mode != csr::PRIV_M && (deleg >> cause) & 1 != 0;

    let scause_value = if is_interrupt { cause | (1 << 63) } else { cause };

    if delegate {
        cpu.csrs.insert(csr::SEPC, cpu.pc);
        cpu.csrs.insert(csr::SCAUSE, scause_value);
        cpu.csrs.insert(csr::STVAL, tval);
        let mut mstatus = cpu.csrs.get(csr::MSTATUS);
        let sie = mstatus & MSTATUS_SIE != 0;
        mstatus = (mstatus & !MSTATUS_SPIE) | if sie { MSTATUS_SPIE } else { 0 };
        mstatus &= !MSTATUS_SIE;
        mstatus = (mstatus & !MSTATUS_SPP) | if cpu.mode == csr::PRIV_S { MSTATUS_SPP } else { 0 };
        cpu.csrs.insert(csr::MSTATUS, mstatus);
        cpu.mode = csr::PRIV_S;
        cpu.csrs.get(csr::STVEC) & !0b11
    } else {
        cpu.csrs.insert(csr::MEPC, cpu.pc);
        cpu.csrs.insert(csr::MCAUSE, scause_value);
        cpu.csrs.insert(csr::MTVAL, tval);
        let mut mstatus = cpu.csrs.get(csr::MSTATUS);
        let mie = mstatus & MSTATUS_MIE != 0;
        mstatus = (mstatus & !MSTATUS_MPIE) | if mie { MSTATUS_MPIE } else { 0 };
        mstatus &= !MSTATUS_MIE;
        mstatus = (mstatus & !MSTATUS_MPP) | ((cpu.mode as u64) << 11);
        cpu.csrs.insert(csr::MSTATUS, mstatus);
        cpu.mode = csr::PRIV_M;
        cpu.csrs.get(csr::MTVEC) & !0b11
    }
}

/// Update MIP's hardware-driven bits (MTIP from CLINT, SEIP from PLIC) and,
/// if an enabled interrupt is pending and would actually be taken at the
/// current privilege/mstatus.[M|S]IE, deliver it.
///
/// Returns true if a trap was taken (pc already updated), else false.
pub fn check_interrupt(cpu: &mut Cpu) -> bool {
    let mut mip = cpu.csrs.get(csr::MIP);
    if let Some(clint) = &cpu.clint {
        mip = if clint.borrow().pending() { mip | MIP_MTIP } else { mip & !MIP_MTIP };
    }
    if let Some(plic) = &cpu.plic {
        mip = if plic.borrow().claimable(1) { mip | MIP_SEIP } else { mip & !MIP_SEIP };
    }
    cpu.csrs.insert(csr::MIP, mip);

    let mie = cpu.csrs.get(csr::MIE);
    let pending_enabled = mip & mie;
    if pending_enabled == 0 {
        return false;
    }

    let mstatus = cpu.csrs.get(csr::MSTATUS);
    for &cause in PRIORITY.iter() {
        let bit = 1u64 << cause;
        if pending_enabled & bit == 0 {
            continue;
        }
        let deleg = cpu.csrs.get(csr::MIDELEG) & MIDELEG_DELEGATABLE_MASK;
        let delegated = cpu.mode != csr::PRIV_M && (deleg >> cause) & 1 != 0;
        if delegated {
            if cpu.mode == csr::PRIV_S && mstatus & MSTATUS_SIE == 0 {
                continue;
            }
        } else if cpu.mode == csr::PRIV_M && mstatus & MSTATUS_MIE == 0 {
            continue;
        }
        cpu.pc = raise_trap(cpu, cause, true, 0);
        return true;
    }
    false
}
