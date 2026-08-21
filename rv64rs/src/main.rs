//! CLI entry point.
//! - `fib` (stage 1): reproduces tests/test_emu.py::test_fib end-to-end.
//! - `stack-demo` (stage 2): runs a hand-assembled program that actually
//!   uses the stack region via LOAD/STORE.
//! - `xv6-boot` (stage 5): boots a kernel image through Xv6Emulator (CLINT/
//!   UART/PLIC wired up) and prints whatever it writes to the UART.
//! - anything else: generic run mode for poking at other programs.

use rv64rs::asm::stack_demo_program;
use rv64rs::emulator::{Emulator, Xv6Emulator};
use std::cell::RefCell;
use std::env;
use std::io::Write;
use std::rc::Rc;
use std::time::Instant;

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
        emu.cpu.bus.borrow().read(0x3000, 4).unwrap(),
        emu.cpu.bus.borrow().read(0x3004, 4).unwrap()
    );
}

fn run_xv6_boot(path: &str, address: u64, limit: u64, fs_image: Option<&str>) {
    let code = std::fs::read(path).expect("failed to read kernel image");
    let disk_image = fs_image.map(|p| std::fs::read(p).expect("failed to read fs image"));
    let mut emu = Xv6Emulator::new(&code, address, Some(Box::new(std::io::stdout())), None, disk_image)
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

struct Tee(Rc<RefCell<Vec<u8>>>);
impl Write for Tee {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        std::io::stdout().write_all(buf)?;
        self.0.borrow_mut().extend_from_slice(buf);
        Ok(buf.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        std::io::stdout().flush()
    }
}

/// Boots straight through to the `$ ` shell prompt and exits immediately,
/// printing a precise elapsed time from just before the first instruction
/// executes (kernel + fs image already loaded, devices already wired up)
/// to the instant the prompt appears in the UART stream. Avoids the
/// imprecision of eyeballing/killing a long-running `xv6-boot` process by
/// hand once it reaches the shell and just idles waiting for input.
fn run_xv6_time_to_shell(path: &str, address: u64, fs_image: Option<&str>, limit: u64) {
    let code = std::fs::read(path).expect("failed to read kernel image");
    let disk_image = fs_image.map(|p| std::fs::read(p).expect("failed to read fs image"));
    let output = Rc::new(RefCell::new(Vec::<u8>::new()));
    let mut emu = Xv6Emulator::new(&code, address, Some(Box::new(Tee(output.clone()))), None, disk_image)
        .expect("failed to set up XV6 emulator");

    let start = Instant::now();
    let mut count: u64 = 0;
    let mut bare_count: u64 = 0; // satp.MODE == Bare: translate() is a no-op, a TLB couldn't help these
    loop {
        let paging_on = emu.cpu.csrs.get(rv64rs::csr::SATP) >> 60 == 8;
        if !paging_on {
            bare_count += 1;
        }
        if let Err(e) = emu.cpu.step() {
            eprintln!("\nstopped early after {count} instructions: {e}");
            std::process::exit(1);
        }
        count += 1;
        if count.is_multiple_of(4096) && output.borrow().ends_with(b"$ ") {
            let elapsed = start.elapsed();
            eprintln!(
                "\n\n[reached shell prompt after {count} instructions in {:.3}s ({:.0} instr/s); {bare_count} ({:.1}%) ran with paging off -- a TLB can't help those]",
                elapsed.as_secs_f64(),
                count as f64 / elapsed.as_secs_f64(),
                100.0 * bare_count as f64 / count as f64,
            );
            std::process::exit(0);
        }
        if limit != 0 && count >= limit {
            eprintln!("\n[gave up after {limit} instructions without reaching the shell prompt]");
            std::process::exit(1);
        }
    }
}

/// Parses an optional instruction-limit argument, panicking with a clear
/// message on unparseable input rather than silently falling back to
/// `default` -- a silent fallback here is exactly what let a real fs.img
/// path get quietly dropped (unparseable as a number) instead of erroring.
fn parse_limit(arg: Option<&String>, default: u64) -> u64 {
    match arg {
        None => default,
        Some(s) => s.parse().unwrap_or_else(|_| panic!("invalid instruction limit {s:?}: expected a number")),
    }
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
        // Both xv6-* subcommands take positional args in the SAME order:
        // <kernel> [address_hex] [fs_image] [instr_limit]. (They didn't
        // used to -- xv6-boot had fs_image and instr_limit swapped relative
        // to xv6-time-to-shell, which silently ate a real fs.img path as an
        // unparseable "instruction limit" that defaulted to 0/unlimited,
        // producing a kernel boot against a blank synthetic disk instead of
        // a clear error. Fixed by both reordering these to match and by
        // parse_limit erroring loudly instead of defaulting on bad input.)
        Some("xv6-boot") => {
            let path = args.get(2).map(String::as_str).unwrap_or("../tests/kernel64gc_nopageflush.bin");
            let address = args
                .get(3)
                .map(|s| u64::from_str_radix(s.trim_start_matches("0x"), 16).unwrap())
                .unwrap_or(0x8000_0000);
            let fs_image = args.get(4).map(String::as_str);
            let limit = parse_limit(args.get(5), 0);
            run_xv6_boot(path, address, limit, fs_image);
        }
        Some("xv6-time-to-shell") => {
            let path = args.get(2).map(String::as_str).unwrap_or("../tests/xv6-kernel-fs-small.bin");
            let address = args
                .get(3)
                .map(|s| u64::from_str_radix(s.trim_start_matches("0x"), 16).unwrap())
                .unwrap_or(0x8000_0000);
            let fs_image = args.get(4).map(String::as_str).or(Some("../tests/fs.img"));
            let limit = parse_limit(args.get(5), 2_000_000_000);
            run_xv6_time_to_shell(path, address, fs_image, limit);
        }
        Some(path) => {
            let address = args
                .get(2)
                .map(|s| u64::from_str_radix(s.trim_start_matches("0x"), 16).unwrap())
                .unwrap_or(0x1000);
            run_generic(path, address);
        }
        None => {
            eprintln!("usage:");
            eprintln!("  rv64rs fib [path]");
            eprintln!("  rv64rs stack-demo");
            eprintln!("  rv64rs xv6-boot [kernel] [address_hex] [fs_image] [instr_limit]");
            eprintln!("  rv64rs xv6-time-to-shell [kernel] [address_hex] [fs_image] [instr_limit]");
            eprintln!("  rv64rs <path> [address_hex]");
            std::process::exit(1);
        }
    }
}
