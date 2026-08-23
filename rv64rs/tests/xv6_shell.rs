//! Stage 7 milestone: full boot to an interactive `$` shell prompt, using
//! the same real xv6 filesystem image (tests/fs.img) and fs-enabled kernel
//! (tests/xv6-kernel-fs-small.bin) manually verified against the Python
//! implementation earlier in this project's history. This is the actual
//! end state riscvm's own README describes for the small kernel.

use rv64rs::emulator::Xv6Emulator;
use std::cell::RefCell;
use std::io::Write;
use std::rc::Rc;
use std::time::Instant;

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

#[test]
fn boots_to_an_interactive_shell_prompt() {
    let kernel = std::fs::read("../tests/xv6-kernel-fs-small.bin").expect("kernel fixture should exist");
    let fs_image = std::fs::read("../tests/fs.img").expect("fs image fixture should exist");
    let output = Rc::new(RefCell::new(Vec::<u8>::new()));

    let mut emu =
        Xv6Emulator::new(&kernel, 0x8000_0000, Some(Box::new(Sink(output.clone()))), None, Some(fs_image)).unwrap();

    let start = Instant::now();
    let mut count: u64 = 0;
    const LIMIT: u64 = 40_000_000;
    loop {
        if emu.cpus[0].step(&mut emu.bus).is_err() {
            break;
        }
        count += 1;
        // Checking the whole buffer's tail every instruction is wasteful at
        // this scale; check periodically instead (same cadence idea as
        // cpu.py's own UART_POLL_INTERVAL).
        if count.is_multiple_of(4096) && output.borrow().ends_with(b"$ ") {
            break;
        }
        if count >= LIMIT {
            break;
        }
    }
    let elapsed = start.elapsed();

    let printed = String::from_utf8_lossy(&output.borrow()).to_string();
    println!("reached shell prompt after {count} instructions in {elapsed:?}");
    assert!(printed.contains("xv6 kernel is booting"), "missing boot banner, got: {printed:?}");
    assert!(printed.contains("init: starting sh"), "missing init/sh startup, got: {printed:?}");
    assert!(printed.ends_with("$ "), "did not reach the shell prompt within {LIMIT} instructions, got: {printed:?}");
}
