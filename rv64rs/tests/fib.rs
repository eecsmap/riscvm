//! Stage 1 milestone: ports tests/test_emu.py::test_fib end-to-end.
//! Loads the fib program at 0x1000, sets a0=80, runs until the program's
//! final `jalr zero,ra,0` (ra still 0) hits an unmapped fetch -- same stop
//! condition Python hits as InternalException -- and checks the same
//! expected result.

use rv64rs::emulator::Emulator;

const EXPECTED_FIB_80: u64 = 23416728348467685;

// Same 52 bytes as tests/test_emu.py::test_fib's inline hex string, so this
// test doesn't depend on the fixture file's on-disk path.
const FIB_HEX: &str = "9307f5ff6354a00213071000930600001306f0ff130507009387f7ff3307d70093060500e398c7fe678000001305000067800000";

fn hex_decode(s: &str) -> Vec<u8> {
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
        .collect()
}

#[test]
fn fib_80_inline() {
    let code = hex_decode(FIB_HEX);
    let mut emu = Emulator::new(&code, 0x1000).unwrap();
    emu.cpu.regs.write(10, 80);
    let _stopped = emu.run(); // expected: unmapped fetch at pc=0 (ra was never set)
    assert_eq!(emu.cpu.regs.read(10), EXPECTED_FIB_80);
    assert_eq!(emu.cpu.pc, 0);
}

#[test]
fn fib_80_from_fixture_file() {
    // Reuses the actual repo fixture rather than duplicating it.
    let code = std::fs::read("../tests/fib.bin").expect("tests/fib.bin should exist at repo root");
    let mut emu = Emulator::new(&code, 0x1000).unwrap();
    emu.cpu.regs.write(10, 80);
    emu.run();
    assert_eq!(emu.cpu.regs.read(10), EXPECTED_FIB_80);
}
