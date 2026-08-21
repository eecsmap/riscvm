//! Ports tests/test_mmu.py's cases verbatim -- same PTE layout, same
//! virtual addresses, same expected results.

use rv64rs::bus::Bus;
use rv64rs::cpu::Cpu;
use rv64rs::csr;
use rv64rs::mmu::{translate, Access, PTE_R, PTE_V, PTE_W};
use rv64rs::ram::Ram;
use std::cell::RefCell;
use std::rc::Rc;

const PAGESIZE: u64 = 0x1000;

fn make_cpu(ram_size: u64) -> Cpu {
    let mut bus = Bus::new();
    bus.add_device(Box::new(Ram::new(ram_size)), 0).unwrap();
    Cpu::new(Rc::new(RefCell::new(bus)))
}

fn write_pte(cpu: &mut Cpu, table_ppn: u64, index: u64, target_ppn: u64, flags: u64) {
    let addr = table_ppn * PAGESIZE + index * 8;
    let pte = (target_ppn << 10) | flags;
    cpu.bus.borrow().write(addr, 8, pte).unwrap();
}

#[test]
fn bare_mode_is_identity() {
    let mut c = make_cpu(0x10000);
    assert_eq!(translate(&mut c, 0x1234, Access::R).unwrap(), 0x1234);
    assert_eq!(translate(&mut c, 0x1234, Access::W).unwrap(), 0x1234);
    assert_eq!(translate(&mut c, 0x1234, Access::X).unwrap(), 0x1234);
}

#[test]
fn cpu_read_write_passthrough_when_bare() {
    let mut c = make_cpu(0x10000);
    c.write(0x100, 8, 0xdeadbeef).unwrap();
    assert_eq!(c.read(0x100, 8).unwrap(), 0xdeadbeef);
}

#[test]
fn sv39_three_level_translation() {
    let mut c = make_cpu(0x10000);
    let (root_ppn, l1_ppn, l0_ppn, data_ppn) = (1, 2, 3, 4);

    let (vpn2, vpn1, vpn0, offset) = (1u64, 2u64, 3u64, 0x123u64);
    let va = (vpn2 << 30) | (vpn1 << 21) | (vpn0 << 12) | offset;

    write_pte(&mut c, root_ppn, vpn2, l1_ppn, PTE_V); // pointer (no R/W/X)
    write_pte(&mut c, l1_ppn, vpn1, l0_ppn, PTE_V); // pointer
    write_pte(&mut c, l0_ppn, vpn0, data_ppn, PTE_V | PTE_R | PTE_W); // leaf

    c.csrs.insert(csr::SATP, (8 << 60) | root_ppn);

    let pa = translate(&mut c, va, Access::R).unwrap();
    assert_eq!(pa, (data_ppn << 12) | offset);
}

#[test]
fn sv39_cpu_read_write_end_to_end() {
    let mut c = make_cpu(0x10000);
    let (root_ppn, l1_ppn, l0_ppn, data_ppn) = (1, 2, 3, 4);
    let (vpn2, vpn1, vpn0, offset) = (0u64, 0u64, 0u64, 0x10u64);
    let va = (vpn2 << 30) | (vpn1 << 21) | (vpn0 << 12) | offset;

    write_pte(&mut c, root_ppn, vpn2, l1_ppn, PTE_V);
    write_pte(&mut c, l1_ppn, vpn1, l0_ppn, PTE_V);
    write_pte(&mut c, l0_ppn, vpn0, data_ppn, PTE_V | PTE_R | PTE_W);
    c.csrs.insert(csr::SATP, (8 << 60) | root_ppn);

    c.write(va, 8, 0x1122334455667788).unwrap();
    assert_eq!(c.read(va, 8).unwrap(), 0x1122334455667788);
    // confirm it actually landed at the translated physical address
    assert_eq!(c.bus.borrow().read(data_ppn * PAGESIZE + offset, 8).unwrap(), 0x1122334455667788);
}

#[test]
fn sv39_gigapage_superpage() {
    let mut c = make_cpu(0x10000);
    let root_ppn = 1;
    let (vpn2, vpn1, vpn0, offset) = (5u64, 7u64, 9u64, 0x42u64);
    let va = (vpn2 << 30) | (vpn1 << 21) | (vpn0 << 12) | offset;

    let superpage_ppn = 100u64 << 18; // low 18 bits zero: 1GB-aligned
    write_pte(&mut c, root_ppn, vpn2, superpage_ppn, PTE_V | PTE_R | PTE_W);
    c.csrs.insert(csr::SATP, (8 << 60) | root_ppn);

    let pa = translate(&mut c, va, Access::R).unwrap();
    let expected_ppn = superpage_ppn | (vpn1 << 9) | vpn0;
    assert_eq!(pa, (expected_ppn << 12) | offset);
}

#[test]
fn sv39_invalid_pte_faults() {
    let mut c = make_cpu(0x10000);
    c.csrs.insert(csr::SATP, (8 << 60) | 1); // root table page left all zero -> V=0
    assert!(translate(&mut c, 0x1000, Access::R).is_err());
}

#[test]
fn sv39_permission_denied_faults() {
    let mut c = make_cpu(0x10000);
    let (root_ppn, l1_ppn, l0_ppn, data_ppn) = (1, 2, 3, 4);
    let va = 0; // vpn2=vpn1=vpn0=0
    write_pte(&mut c, root_ppn, 0, l1_ppn, PTE_V);
    write_pte(&mut c, l1_ppn, 0, l0_ppn, PTE_V);
    write_pte(&mut c, l0_ppn, 0, data_ppn, PTE_V | PTE_R); // read-only leaf
    c.csrs.insert(csr::SATP, (8 << 60) | root_ppn);

    assert_eq!(translate(&mut c, va, Access::R).unwrap(), data_ppn * PAGESIZE);
    assert!(translate(&mut c, va, Access::W).is_err());
}

#[test]
fn sv39_unsupported_mode_faults() {
    let mut c = make_cpu(0x10000);
    c.csrs.insert(csr::SATP, 1 << 60); // mode 1 (Sv32) not implemented
    assert!(translate(&mut c, 0x1000, Access::R).is_err());
}
