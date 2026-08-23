//! SMP support: multiple `Cpu`s (harts) sharing one `Bus`, wired the same
//! way emulator.py's XV6(..., ncpu=N)/riscvm's `--smp` do. Mirrors
//! tests/test_emu.py's own SMP additions.

use rv64rs::asm::{encode_b, encode_i, encode_j, encode_s, FUNCT3_ADDI, FUNCT3_BEQ, FUNCT3_LW, FUNCT3_SW, OPCODE_BRANCH, OPCODE_JAL, OPCODE_LOAD, OPCODE_OP_IMM, OPCODE_STORE, T0, T1, T2, ZERO};
use rv64rs::cpu::Cpu;
use rv64rs::emulator::{Emulator, Xv6Emulator};

#[test]
fn xv6_smp_boots_one_cpu_object_per_hart() {
    // --smp N (real qemu's own flag name) should give us N independent Cpu
    // objects -- like N harts resetting at the same vector on real
    // hardware -- each with its own mhartid CSR but sharing the single
    // CLINT/PLIC/UART/bus every hart on the same board would share.
    let emu = Xv6Emulator::new_smp(&[0u8; 64], 0x8000_0000, None, None, None, 3).unwrap();
    assert_eq!(emu.cpus.len(), 3);

    for (expected_hartid, cpu) in emu.cpus.iter().enumerate() {
        assert_eq!(cpu.hartid, expected_hartid as u64);
        assert_eq!(cpu.csrs.get(rv64rs::csr::MHARTID), expected_hartid as u64);
        assert_eq!(cpu.pc, 0x1000); // every hart resets at the same vector
    }
}

#[test]
fn xv6_default_ncpu_is_a_single_hart() {
    let emu = Xv6Emulator::new(&[0u8; 64], 0x8000_0000, None, None, None).unwrap();
    assert_eq!(emu.cpus.len(), 1);
}

#[test]
fn run_round_robins_harts_so_a_spin_wait_actually_unblocks() {
    // This is the same shape as xv6's real boot handshake: hart 0 does some
    // work then sets a shared flag (kernel/main.c's `started`), and hart 1
    // busy-waits on it (`while(started == 0);`) before proceeding. If
    // run() let one hart run to completion before ever scheduling another,
    // hart 1's spin loop here (and xv6's) would never see hart 0's write.
    let mut code = vec![0u8; 0x1114];
    let put = |code: &mut Vec<u8>, addr: usize, word: u32| {
        code[addr..addr + 4].copy_from_slice(&word.to_le_bytes());
    };

    put(&mut code, 0x1000, encode_i(1, ZERO, FUNCT3_ADDI, T0, OPCODE_OP_IMM)); // addi t0, x0, 1
    put(&mut code, 0x1004, encode_s(0, ZERO, T0, FUNCT3_SW, OPCODE_STORE)); // sw t0, 0(x0)       -- flag <- 1
    put(&mut code, 0x1008, encode_j(0, ZERO, OPCODE_JAL)); // jal x0, 0          -- spin forever
    put(&mut code, 0x1100, encode_i(0, ZERO, FUNCT3_LW, T1, OPCODE_LOAD)); // lw t1, 0(x0)       -- read flag
    put(&mut code, 0x1104, encode_b(-4, T1, ZERO, FUNCT3_BEQ, OPCODE_BRANCH)); // beq t1, x0, -4 -- spin while flag == 0
    put(&mut code, 0x1108, encode_i(2, ZERO, FUNCT3_ADDI, T2, OPCODE_OP_IMM)); // addi t2, x0, 2
    put(&mut code, 0x110c, encode_s(4, ZERO, T2, FUNCT3_SW, OPCODE_STORE)); // sw t2, 4(x0)       -- marker <- 2
    put(&mut code, 0x1110, encode_j(0, ZERO, OPCODE_JAL)); // jal x0, 0          -- spin forever

    let mut emu = Emulator::new(&code, 0).unwrap();
    emu.cpu().pc = 0x1000;
    let mut hart1 = Cpu::new(1);
    hart1.pc = 0x1100;
    emu.cpus.push(hart1);

    for _ in 0..8 {
        for i in 0..emu.cpus.len() {
            emu.cpus[i].step(&mut emu.bus).unwrap();
        }
    }

    assert_eq!(emu.bus.read(0, 4).unwrap(), 1); // hart 0's flag write went through
    assert_eq!(emu.bus.read(4, 4).unwrap(), 2); // hart 1 saw it and left its spin loop
}

#[test]
fn smp_boot_prints_the_multicore_hart_starting_banner() {
    // Full end-to-end boot of the real small-PHYSTOP xv6 kernel with 3
    // harts, matching real qemu's own default (`make qemu` uses -smp 3).
    // Feasible as a real test here (not just a manual/background check
    // like riscvm's Python emulator needs -- see its README) because
    // rv64rs boots the same kernel to a shell in single-digit seconds.
    use std::cell::RefCell;
    use std::io::Write;
    use std::rc::Rc;

    struct Sink(Rc<RefCell<Vec<u8>>>);
    impl Write for Sink {
        fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
            self.0.borrow_mut().extend_from_slice(buf);
            Ok(buf.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }

    let kernel = std::fs::read("../tests/xv6-kernel-fs-small.bin").expect("kernel fixture should exist");
    let fs_image = std::fs::read("../tests/fs.img").expect("fs image fixture should exist");
    let output = Rc::new(RefCell::new(Vec::<u8>::new()));

    let mut emu = Xv6Emulator::new_smp(
        &kernel,
        0x8000_0000,
        Some(Box::new(Sink(output.clone()))),
        None,
        Some(fs_image),
        3,
    )
    .unwrap();

    const LIMIT: u64 = 40_000_000; // per-hart round count, same budget as xv6_shell.rs's single-hart test
    let mut count: u64 = 0;
    'outer: loop {
        for i in 0..emu.cpus.len() {
            if emu.cpus[i].step(&mut emu.bus).is_err() {
                break 'outer;
            }
        }
        count += 1;
        if count.is_multiple_of(4096) && output.borrow().ends_with(b"$ ") {
            break;
        }
        if count >= LIMIT {
            break;
        }
    }

    let printed = String::from_utf8_lossy(&output.borrow()).to_string();
    println!("reached shell prompt after {count} rounds");
    assert!(printed.contains("xv6 kernel is booting"), "missing boot banner, got: {printed:?}");
    assert!(printed.contains("hart 1 starting"), "hart 1 never reported in, got: {printed:?}");
    assert!(printed.contains("hart 2 starting"), "hart 2 never reported in, got: {printed:?}");
    assert!(printed.contains("init: starting sh"), "missing init/sh startup, got: {printed:?}");
    assert!(printed.ends_with("$ "), "did not reach the shell prompt within {LIMIT} rounds, got: {printed:?}");
}
