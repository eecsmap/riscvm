//! CLI entry point.
//! - `fib` (stage 1): reproduces tests/test_emu.py::test_fib end-to-end.
//! - `stack-demo` (stage 2): runs a hand-assembled program that actually
//!   uses the stack region via LOAD/STORE.
//! - `xv6-boot` (stage 5): boots a kernel image through Xv6Emulator (CLINT/
//!   UART/PLIC wired up) and prints whatever it writes to the UART.
//! - anything else: generic run mode for poking at other programs.

use rv64rs::asm::stack_demo_program;
use rv64rs::emulator::{Emulator, Xv6Emulator};
use std::env;

const REG_NAMES: [&str; 32] = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0", "a1", "a2", "a3", "a4",
    "a5", "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4",
    "t5", "t6",
];

fn dump_registers(cpu: &rv64rs::cpu::Cpu) {
    for (i, name) in REG_NAMES.iter().enumerate().skip(1) {
        println!("{} (x{}) = 0x{:x}", name, i, cpu.regs.read(i));
    }
    println!("pc = 0x{:x}", cpu.pc);
}

fn run_fib(path: &str) {
    let code = std::fs::read(path).expect("failed to read fib.bin");
    let mut emu = Emulator::new(&code, 0x1000).expect("failed to set up emulator");
    emu.cpu.regs.write(10, 80); // a0 = 80, same as tests/test_emu.py::test_fib

    let err = emu.run();

    const EXPECTED: u64 = 23416728348467685;
    let a0 = emu.cpu.regs.read(10);
    println!("stopped: {err}");
    println!("a0 = fib(80) = {a0} (expected {EXPECTED}, match = {})", a0 == EXPECTED);
}

fn run_stack_demo() {
    let code = stack_demo_program();
    let mut emu = Emulator::new(&code, 0x1000).expect("failed to set up emulator");
    let err = emu.run();

    let a0 = emu.cpu.regs.read(10);
    println!("stopped: {err}");
    println!("a0 = {a0} (expected 43, match = {})", a0 == 43);
    println!(
        "stack[0x3000..0x3008) = {}, {}",
        emu.cpu.bus.read(0x3000, 4).unwrap(),
        emu.cpu.bus.read(0x3004, 4).unwrap()
    );
}

fn run_xv6_boot(path: &str, address: u64, limit: u64) {
    let code = std::fs::read(path).expect("failed to read kernel image");
    let mut emu = Xv6Emulator::new(&code, address, Some(Box::new(std::io::stdout())), None)
        .expect("failed to set up XV6 emulator");

    let mut count: u64 = 0;
    let err = loop {
        if let Err(e) = emu.cpu.step() {
            break e;
        }
        count += 1;
        if limit != 0 && count >= limit {
            eprintln!("\n[reached instruction limit {limit}]");
            std::process::exit(0);
        }
    };
    eprintln!("\nstopped after {count} instructions: {err}");
    dump_registers(&emu.cpu);
}

fn run_generic(path: &str, address: u64) {
    let code = std::fs::read(path).expect("failed to read program");
    let mut emu = Emulator::new(&code, address).expect("failed to set up emulator");
    let err = emu.run();
    println!("stopped: {err}");
    dump_registers(&emu.cpu);
}

fn main() {
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("fib") => {
            let path = args.get(2).map(String::as_str).unwrap_or("../tests/fib.bin");
            run_fib(path);
        }
        Some("stack-demo") => run_stack_demo(),
        Some("xv6-boot") => {
            let path = args.get(2).map(String::as_str).unwrap_or("../tests/kernel64gc_nopageflush.bin");
            let address = args
                .get(3)
                .map(|s| u64::from_str_radix(s.trim_start_matches("0x"), 16).unwrap())
                .unwrap_or(0x8000_0000);
            let limit = args.get(4).and_then(|s| s.parse().ok()).unwrap_or(0);
            run_xv6_boot(path, address, limit);
        }
        Some(path) => {
            let address = args
                .get(2)
                .map(|s| u64::from_str_radix(s.trim_start_matches("0x"), 16).unwrap())
                .unwrap_or(0x1000);
            run_generic(path, address);
        }
        None => {
            eprintln!("usage: rv64rs fib [path]   |   rv64rs <path> [address_hex]");
            std::process::exit(1);
        }
    }
}
