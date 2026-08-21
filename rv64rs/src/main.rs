//! CLI entry point. Stage 1 scope: a `fib` subcommand reproducing
//! tests/test_emu.py::test_fib end-to-end (load tests/fib.bin at 0x1000,
//! a0=80, run until the program's final JALR to ra=0 hits unmapped memory,
//! check a0). A generic run mode is also provided for poking at other
//! stage-1-only (ALU/branch/jump, no memory) programs.

use rv64rs::emulator::Emulator;
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
