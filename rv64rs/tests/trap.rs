//! Ports tests/test_trap.py's CSR/trap/interrupt cases verbatim (same
//! instruction words / CSR values / expected results). The two PLIC-only
//! cases in that file now live in plic.rs's own unit tests instead
//! (test_plic_claim_respects_priority_enable_and_threshold,
//! test_plic_threshold_masks_low_priority) since they don't touch CPU at
//! all -- same reasoning as rvc.rs owning its own decode/execute tests.

use rv64rs::bus::Bus;
use rv64rs::clint::Clint;
use rv64rs::cpu::Cpu;
use rv64rs::csr;
use rv64rs::decode::Instruction;
use rv64rs::ram::Ram;
use rv64rs::trap::{check_interrupt, csr_read, csr_write, raise_trap, MSTATUS_MIE, MSTATUS_SIE};
use std::cell::RefCell;
use std::rc::Rc;

fn cpu() -> Cpu {
    let mut bus = Bus::new();
    bus.add_device(Box::new(Ram::new(0x10000)), 0).unwrap();
    Cpu::new(bus)
}

#[test]
fn sstatus_aliases_mstatus() {
    let mut c = cpu();
    csr_write(&mut c, csr::MSTATUS, MSTATUS_MIE); // set a machine-only bit
    csr_write(&mut c, csr::SSTATUS, MSTATUS_SIE); // set SIE via the S-mode view
    assert!(c.csrs[&csr::MSTATUS] & MSTATUS_SIE != 0);
    assert!(c.csrs[&csr::MSTATUS] & MSTATUS_MIE != 0);
    assert_eq!(csr_read(&c, csr::SSTATUS), MSTATUS_SIE);
}

#[test]
fn sie_aliases_mie() {
    let mut c = cpu();
    csr_write(&mut c, csr::SIE, 0x222); // SSIE|STIE|SEIE
    assert_eq!(c.csrs[&csr::MIE], 0x222);
    assert_eq!(csr_read(&c, csr::SIE), 0x222);
}

#[test]
fn csrrc_clears_bits() {
    let mut c = cpu();
    c.csrs.insert(csr::MSCRATCH, 0b1111);
    c.regs.write(10, 0b0101); // a0
    c.execute(&Instruction::new(0x34053773)).unwrap(); // csrrc a4, mscratch, a0
    assert_eq!(c.regs.read(14), 0b1111); // a4 <- old value
    assert_eq!(c.csrs[&csr::MSCRATCH], 0b1010); // cleared bits set in a0
}

#[test]
fn csrrwi_uses_immediate_not_register() {
    let mut c = cpu();
    c.csrs.insert(csr::MSCRATCH, 0xff);
    c.execute(&Instruction::new(0x3402d0f3)).unwrap(); // csrrwi x1, mscratch, 5
    assert_eq!(c.regs.read(1), 0xff);
    assert_eq!(c.csrs[&csr::MSCRATCH], 5);
}

#[test]
fn csrrsi_sets_bits_from_immediate() {
    let mut c = cpu();
    c.csrs.insert(csr::MSCRATCH, 0b1000);
    c.execute(&Instruction::new(0x3401e0f3)).unwrap(); // csrrsi x1, mscratch, 3
    assert_eq!(c.csrs[&csr::MSCRATCH], 0b1011);
}

#[test]
fn csrrci_clears_bits_from_immediate() {
    // `csrrci s1, sstatus, 2` -- clears SIE via a 5-bit immediate mask.
    let mut c = cpu();
    c.csrs.insert(csr::MSTATUS, 0b111);
    c.execute(&Instruction::new(0x100174f3)).unwrap(); // csrrci s1, sstatus, 2
    assert_eq!(c.regs.read(9), 0b010); // s1 <- old sstatus view (bits 1/5/8 only: SIE here)
    assert_eq!(c.csrs[&csr::MSTATUS], 0b101); // bit 1 (SIE) cleared; bits 0,2 survive
}

#[test]
fn ecall_from_u_mode_delegated_traps_to_s_mode() {
    let mut c = cpu();
    c.mode = csr::PRIV_U;
    csr_write(&mut c, csr::MEDELEG, 1 << 8); // delegate U-mode ecall to S
    c.csrs.insert(csr::STVEC, 0x2000);
    c.pc = 0x1000;
    let new_pc = raise_trap(&mut c, 8, false, 0);
    assert_eq!(new_pc, 0x2000);
    assert_eq!(c.mode, csr::PRIV_S);
    assert_eq!(c.csrs[&csr::SEPC], 0x1000);
    assert_eq!(c.csrs[&csr::SCAUSE], 8);
}

#[test]
fn ecall_not_delegated_traps_to_m_mode() {
    let mut c = cpu();
    c.mode = csr::PRIV_U;
    csr_write(&mut c, csr::MEDELEG, 0); // nothing delegated
    c.csrs.insert(csr::MTVEC, 0x3000);
    c.pc = 0x1000;
    let new_pc = raise_trap(&mut c, 8, false, 0);
    assert_eq!(new_pc, 0x3000);
    assert_eq!(c.mode, csr::PRIV_M);
    assert_eq!(c.csrs[&csr::MEPC], 0x1000);
}

#[test]
fn ecall_execute_and_sret_round_trip() {
    let mut c = cpu();
    c.mode = csr::PRIV_U;
    csr_write(&mut c, csr::MEDELEG, 1 << 8);
    csr_write(&mut c, csr::SSTATUS, MSTATUS_SIE); // interrupts enabled before the trap
    c.csrs.insert(csr::STVEC, 0x4000);
    c.pc = 0x1000;
    c.execute(&Instruction::new(0x00000073)).unwrap(); // ecall
    assert_eq!(c.pc, 0x4000);
    assert_eq!(c.mode, csr::PRIV_S);
    assert_eq!(csr_read(&c, csr::SSTATUS) & MSTATUS_SIE, 0); // SIE cleared on entry

    c.execute(&Instruction::new(0x10200073)).unwrap(); // sret
    assert_eq!(c.pc, 0x1000); // back to sepc
    assert_eq!(c.mode, csr::PRIV_U);
    assert!(csr_read(&c, csr::SSTATUS) & MSTATUS_SIE != 0); // SIE restored from SPIE
}

#[test]
fn csrrw_self_swap_preserves_original_value() {
    // xv6's timervec starts with `csrrw a0, mscratch, a0` -- rd and rs1 are
    // the same register; reading rs1 before writing rd matters.
    let mut c = cpu();
    c.csrs.insert(csr::MSCRATCH, 0x9000);
    c.regs.write(10, 0x1234); // a0
    c.execute(&Instruction::new(0x34051573)).unwrap(); // csrrw a0, mscratch, a0
    assert_eq!(c.regs.read(10), 0x9000);
    assert_eq!(c.csrs[&csr::MSCRATCH], 0x1234);
}

#[test]
fn csrrs_self_alias_still_ors_original_value() {
    let mut c = cpu();
    c.csrs.insert(csr::MSCRATCH, 0x0f0);
    c.regs.write(10, 0x00f);
    c.execute(&Instruction::new(0x34052573)).unwrap(); // csrrs a0, mscratch, a0
    assert_eq!(c.regs.read(10), 0x0f0);
    assert_eq!(c.csrs[&csr::MSCRATCH], 0x0ff);
}

#[test]
fn wfi_is_a_noop() {
    let mut c = cpu();
    c.pc = 0x1000;
    c.execute(&Instruction::new(0x10500073)).unwrap(); // wfi
    assert_eq!(c.pc, 0x1004);
}

#[test]
fn clint_mtip_always_taken_in_m_mode_target_when_below_m() {
    let mut c = cpu();
    let mut clint = Clint::new(0x10000);
    clint.mtimecmp[0] = 5;
    c.mode = csr::PRIV_S;
    csr_write(&mut c, csr::MIE, 1 << 7); // MTIE
    c.csrs.insert(csr::MTVEC, 0x5000);
    c.pc = 0x1000;

    for _ in 0..5 {
        clint.tick();
    }
    c.clint = Some(Rc::new(RefCell::new(clint)));

    assert!(check_interrupt(&mut c));
    assert_eq!(c.pc, 0x5000);
    assert_eq!(c.mode, csr::PRIV_M);
    assert_eq!(c.csrs[&csr::MCAUSE], 7 | (1 << 63));
}

#[test]
fn clint_mtip_not_delivered_when_mtie_disabled() {
    let mut c = cpu();
    let mut clint = Clint::new(0x10000);
    clint.mtimecmp[0] = 5;
    c.mode = csr::PRIV_S;
    csr_write(&mut c, csr::MIE, 0); // MTIE off
    c.pc = 0x1000;

    for _ in 0..10 {
        clint.tick();
    }
    c.clint = Some(Rc::new(RefCell::new(clint)));

    assert!(!check_interrupt(&mut c));
    assert_eq!(c.pc, 0x1000);
}

#[test]
fn clint_mtip_never_delegated_even_if_mideleg_says_so() {
    let mut c = cpu();
    let mut clint = Clint::new(0x10000);
    clint.mtimecmp[0] = 5;
    c.mode = csr::PRIV_S;
    csr_write(&mut c, csr::MIDELEG, 0xffff);
    csr_write(&mut c, csr::MIE, 1 << 7); // MTIE
    c.csrs.insert(csr::MTVEC, 0x5000);
    c.csrs.insert(csr::STVEC, 0x6000);
    c.pc = 0x1000;

    for _ in 0..5 {
        clint.tick();
    }
    c.clint = Some(Rc::new(RefCell::new(clint)));

    assert!(check_interrupt(&mut c));
    assert_eq!(c.mode, csr::PRIV_M);
    assert_eq!(c.pc, 0x5000); // mtvec, not stvec
    assert_eq!(c.csrs[&csr::MCAUSE], 7 | (1 << 63));
}

#[test]
fn supervisor_software_interrupt_delivered_via_sip() {
    let mut c = cpu();
    c.mode = csr::PRIV_S;
    csr_write(&mut c, csr::MIDELEG, 1 << 1); // delegate supervisor software interrupt
    csr_write(&mut c, csr::SIE, 1 << 1); // SSIE
    csr_write(&mut c, csr::SSTATUS, MSTATUS_SIE);
    c.csrs.insert(csr::STVEC, 0x6000);
    c.pc = 0x1000;

    csr_write(&mut c, csr::SIP, 1 << 1); // sip.SSIP = 1, as the M-mode timervec would

    assert!(check_interrupt(&mut c));
    assert_eq!(c.pc, 0x6000);
    assert_eq!(c.mode, csr::PRIV_S);
    assert_eq!(c.csrs[&csr::SCAUSE], 1 | (1 << 63));
}
