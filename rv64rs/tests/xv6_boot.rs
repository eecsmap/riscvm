//! Stage 5 milestones, both exercised through the real fetch/execute loop
//! (Cpu::step(), same path Xv6Emulator::run() uses) rather than calling
//! trap::check_interrupt() directly like stage 4's unit tests do:
//!   1. A real xv6 kernel image prints "xv6 kernel is booting" over the
//!      emulated UART.
//!   2. A timer interrupt actually preempts a running instruction stream,
//!      observed as pc landing in the trap handler instead of continuing
//!      the loop it interrupted.

use rv64rs::asm::{encode_j, ZERO};
use rv64rs::bus::{Bus, SharedDevice};
use rv64rs::clint::Clint;
use rv64rs::cpu::Cpu;
use rv64rs::csr;
use rv64rs::emulator::Xv6Emulator;
use rv64rs::ram::Ram;
use rv64rs::trap::{MSTATUS_MIE, MSTATUS_MPIE};
use std::cell::RefCell;
use std::rc::Rc;

#[test]
fn boots_and_prints_xv6_kernel_is_booting() {
    let code = std::fs::read("../tests/kernel64gc_nopageflush.bin").expect("kernel fixture should exist");
    let output = Rc::new(RefCell::new(Vec::<u8>::new()));

    struct Sink(Rc<RefCell<Vec<u8>>>);
    impl std::io::Write for Sink {
        fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
            self.0.borrow_mut().extend_from_slice(buf);
            Ok(buf.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }

    let mut emu = Xv6Emulator::new(&code, 0x8000_0000, Some(Box::new(Sink(output.clone()))), None, None).unwrap();
    for _ in 0..5_000_000 {
        if emu.cpu.step().is_err() {
            break;
        }
    }

    let printed = String::from_utf8_lossy(&output.borrow()).to_string();
    assert!(
        printed.contains("xv6 kernel is booting"),
        "expected UART output to contain the boot banner, got: {printed:?}"
    );
}

#[test]
fn timer_interrupt_preempts_a_running_loop_via_real_fetch_path() {
    const MAIN_LOOP_ADDR: u64 = 0x1000;
    const TRAP_HANDLER_ADDR: u64 = 0x2000;

    // Both addresses hold `jal x0, 0`: an infinite self-loop, so whichever
    // one the CPU is executing, pc just sits there -- a clean way to tell
    // "did we ever leave the main loop" apart from "did something crash".
    let mut ram = Ram::new(0x2000);
    let self_jump = encode_j(0, ZERO, 0x6f);
    for base in [0u64, TRAP_HANDLER_ADDR - MAIN_LOOP_ADDR] {
        let b = base as usize;
        ram.data[b..b + 4].copy_from_slice(&self_jump.to_le_bytes());
    }
    let mut bus = Bus::new();
    bus.add_device(Box::new(ram), MAIN_LOOP_ADDR).unwrap();

    let clint = Rc::new(RefCell::new(Clint::new(0x10000)));
    clint.borrow_mut().mtimecmp[0] = 0; // pending as soon as it's ticked even once
    bus.add_device(Box::new(SharedDevice(clint.clone())), 0x0200_0000).unwrap();

    let mut cpu = Cpu::new(Rc::new(RefCell::new(bus)));
    cpu.clint = Some(clint);
    cpu.pc = MAIN_LOOP_ADDR;
    cpu.csrs.insert(csr::MTVEC, TRAP_HANDLER_ADDR);
    cpu.csrs.insert(csr::MIE, 1 << 7); // MTIE
    cpu.csrs.insert(csr::MSTATUS, MSTATUS_MIE);

    // First step: fetch() ticks the CLINT (mtime 0->1, already >= mtimecmp
    // 0), check_interrupt() takes the trap *before* decoding, so this step
    // actually executes the trap handler's first instruction, not the main
    // loop's.
    cpu.step().unwrap();
    assert_eq!(cpu.pc, TRAP_HANDLER_ADDR, "should have landed in the trap handler, not the main loop");
    assert_eq!(cpu.mode, csr::PRIV_M);
    assert_eq!(cpu.csrs[&csr::MCAUSE], 7 | (1 << 63)); // machine timer interrupt
    assert_eq!(cpu.csrs[&csr::MEPC], MAIN_LOOP_ADDR); // trap entry saved where we were interrupted
    // Entering the trap must have cleared MSTATUS.MIE (into MPIE) --
    // otherwise the same interrupt fires again on every single instruction
    // forever instead of being taken exactly once.
    assert_eq!(cpu.csrs[&csr::MSTATUS] & MSTATUS_MIE, 0);
    assert_ne!(cpu.csrs[&csr::MSTATUS] & MSTATUS_MPIE, 0);

    // Subsequent steps: MIE is now clear, so check_interrupt() must not
    // re-fire even though CLINT's pending() is still true -- the CPU just
    // keeps looping in the handler, exactly once preempted.
    for _ in 0..50 {
        cpu.step().unwrap();
        assert_eq!(cpu.pc, TRAP_HANDLER_ADDR);
    }
}
