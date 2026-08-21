//! Ports test cases from tests/test_isa.py verbatim -- same instruction
//! words, same expected values.
//!
//! Stage 1 (ALU + control flow, no memory):
//!   - td_I: only the ADDI row
//!   - td_R: NOT(XORI)/SLT/SLTU/XOR/ADDW/SUBW rows (MUL/DIV/REM rows are
//!     the RV64M extension -- stage 3)
//!   - td_shift_i, td_B, td_J: all ported
//!   - test_fence_i_is_a_noop: ported
//!
//! Stage 2 (this stage, MEM):
//!   - td_I's LB/LH/LBU/LHU rows
//!   - test_sh_stores_halfword

use rv64rs::bus::Bus;
use rv64rs::cpu::Cpu;
use rv64rs::decode::Instruction;
use rv64rs::ram::Ram;

fn cpu() -> Cpu {
    Cpu::new(Bus::new())
}

/// Mirrors test_isa.py's data_loaded(hexdata): a CPU with a RAM device
/// mapped at address 0 holding `data`.
fn cpu_with_ram(hex_data: &str) -> Cpu {
    let bytes: Vec<u8> = (0..hex_data.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex_data[i..i + 2], 16).unwrap())
        .collect();
    let ram = Ram::with_content(bytes.len() as u64, &bytes);
    let mut bus = Bus::new();
    bus.add_device(Box::new(ram), 0).unwrap();
    Cpu::new(bus)
}

// --- td_I: addi x1, x0, 42 ---
#[test]
fn addi() {
    let mut c = cpu();
    c.execute(&Instruction::new(0x02a00093)).unwrap();
    assert_eq!(c.regs.read(1), 42);
}

// --- td_R (filtered to non-M-extension rows) ---
#[test]
fn not_via_xori() {
    // not x1,x2 (XORI x1,x2,-1); tuple sets x1=0 (irrelevant, it's rd) and
    // x2=0xffff_ffff_ffff_ff00 (the real rs1)
    let mut c = cpu();
    c.regs.write(1, 0);
    c.regs.write(2, 0xffff_ffff_ffff_ff00);
    c.execute(&Instruction::new(0xfff14093)).unwrap();
    assert_eq!(c.regs.read(1), 0xff);
}

#[test]
fn slt_signed_comparisons() {
    let cases: [(u64, u64, u32, u64); 3] = [
        (2, 3, 0x00b52533, 1),                                   // 2 < 3 -> 1
        (3, 2, 0x00b52533, 0),                                   // 3 < 2 -> 0
        (0xffff_ffff_ffff_ffff, 1, 0x00b52533, 1),                // -1 < 1 (signed) -> 1
    ];
    for (rs1v, rs2v, word, expected) in cases {
        let mut c = cpu();
        c.regs.write(10, rs1v);
        c.regs.write(11, rs2v);
        c.execute(&Instruction::new(word)).unwrap();
        assert_eq!(c.regs.read(10), expected, "word=0x{word:x}");
    }
}

#[test]
fn sltu_unsigned_comparisons() {
    let cases: [(u64, u64, u32, u64); 2] = [
        (0xffff_ffff_ffff_ffff, 1, 0x00b53533, 0), // huge < 1 (unsigned) -> 0
        (2, 3, 0x00b53533, 1),
    ];
    for (rs1v, rs2v, word, expected) in cases {
        let mut c = cpu();
        c.regs.write(10, rs1v);
        c.regs.write(11, rs2v);
        c.execute(&Instruction::new(word)).unwrap();
        assert_eq!(c.regs.read(10), expected, "word=0x{word:x}");
    }
}

#[test]
fn xor_register() {
    let mut c = cpu();
    c.regs.write(10, 0b1010);
    c.regs.write(11, 0b0110);
    c.execute(&Instruction::new(0x00b54533)).unwrap();
    assert_eq!(c.regs.read(10), 0b1100);
}

#[test]
fn addw_subw() {
    let mut c = cpu();
    c.regs.write(10, 2);
    c.regs.write(11, 3);
    c.execute(&Instruction::new(0x00b5053b)).unwrap(); // addw a0,a0,a1
    assert_eq!(c.regs.read(10), 5);

    let mut c = cpu();
    c.regs.write(10, 5);
    c.regs.write(11, 3);
    c.execute(&Instruction::new(0x40b5053b)).unwrap(); // subw a0,a0,a1
    assert_eq!(c.regs.read(10), 2);

    let mut c = cpu();
    c.regs.write(10, 0xffff_ffff_0000_0001);
    c.regs.write(11, 0xffff_ffff_ffff_ffff);
    c.execute(&Instruction::new(0x00b5053b)).unwrap(); // addw wraps to 32 bits: 1 + -1 -> 0
    assert_eq!(c.regs.read(10), 0);
}

// --- td_shift_i ---
#[test]
fn shift_immediates() {
    let cases: [(u64, u32, u64); 5] = [
        (0xffff_ffff_ffff_fff0, 0x0040d093, 0x0fff_ffff_ffff_ffff), // srli x1,x1,4
        (0xffff_ffff_ffff_fff0, 0x4040d093, 0xffff_ffff_ffff_ffff), // srai x1,x1,4
        (0xffff_ffff_8000_0000, 0x40909b, 0x0),                     // slliw x1,x1,4
        (0xffff_ffff_ffff_fff0, 0x40d09b, 0x0fffffff),               // srliw x1,x1,4
        (0xffff_ffff_8000_0000, 0x4040d09b, 0xffff_ffff_f800_0000),  // sraiw x1,x1,4
    ];
    for (rs1v, word, expected) in cases {
        let mut c = cpu();
        c.regs.write(1, rs1v);
        c.execute(&Instruction::new(word)).unwrap();
        assert_eq!(c.regs.read(1), expected, "word=0x{word:x}");
    }
}

// --- td_B ---
#[test]
fn branch_blt() {
    let mut c = cpu();
    c.regs.write(11, 0xffff_ffff_ffff_ffff);
    c.regs.write(12, 1);
    c.pc = 0x1000;
    c.execute(&Instruction::new(0x02c5c063)).unwrap(); // blt a1,a2,+32; -1<1 -> taken
    assert_eq!(c.pc, 0x1020);

    let mut c = cpu();
    c.regs.write(11, 5);
    c.regs.write(12, 3);
    c.pc = 0x1000;
    c.execute(&Instruction::new(0x02c5c063)).unwrap(); // 5<3 -> not taken
    assert_eq!(c.pc, 0x1004);
}

// --- td_J ---
#[test]
fn jal() {
    let mut c = cpu();
    c.pc = 0x1000;
    c.execute(&Instruction::new(0x08c000ef)).unwrap(); // jal ra, 0x8c
    assert_eq!(c.regs.read(1), 0x1004);
    assert_eq!(c.pc, 0x108c);
}

#[test]
fn fence_i_is_a_noop() {
    let mut c = cpu();
    c.pc = 0x1000;
    c.execute(&Instruction::new(0x0000100f)).unwrap();
    assert_eq!(c.pc, 0x1004);
}

// --- stage 2: td_I's load rows ---
#[test]
fn loads() {
    let cases: [(&str, u32, u64); 4] = [
        ("ff", 0x00000083, 0xffff_ffff_ffff_ffff),   // lb x1, 0(x0)
        ("42ff", 0x00001083, 0xffff_ffff_ffff_ff42), // lh x1, 0(x0)
        ("ff", 0x00004083, 0xff),                     // lbu x1, 0(x0)
        ("42ff", 0x00005083, 0xff42),                 // lhu x1, 0(x0)
    ];
    for (data, word, expected) in cases {
        let mut c = cpu_with_ram(data);
        c.execute(&Instruction::new(word)).unwrap();
        assert_eq!(c.regs.read(1), expected, "word=0x{word:x}");
    }
}

// --- stage 3: td_R's RV64M rows (deferred from stage 1) ---
#[test]
fn rv64m_extension() {
    let cases: [(u64, u64, u32, u64); 18] = [
        (2, 3, 0x02B50533, 6),                                                      // mul a0,a0,a1
        (0x8000_0000_0000_0000, 1, 0x02B50533, 0x8000_0000_0000_0000),               // mul
        (0x8000_0000_0000_0001, 2, 0x02B50533, 2),                                    // mul
        (7, 2, 0x02b54533, 3),                                                         // div 7/2 -> 3
        (0xffff_ffff_ffff_fff9, 2, 0x02b54533, 0xffff_ffff_ffff_fffd),                 // div -7/2 -> -3
        (0x8000_0000_0000_0000, 0xffff_ffff_ffff_ffff, 0x02b54533, 0x8000_0000_0000_0000), // div overflow -> dividend
        (5, 0, 0x02b54533, 0xffff_ffff_ffff_ffff),                                     // div by zero -> -1
        (7, 2, 0x02b55533, 3),                                                          // divu
        (5, 0, 0x02b55533, 0xffff_ffff_ffff_ffff),                                     // divu by zero -> all ones
        (0xffff_ffff_ffff_fff9, 2, 0x02b56533, 0xffff_ffff_ffff_ffff),                  // rem -7%2 -> -1
        (0x8000_0000_0000_0000, 0xffff_ffff_ffff_ffff, 0x02b56533, 0),                  // rem overflow -> 0
        (5, 0, 0x02b56533, 5),                                                          // rem by zero -> dividend
        (7, 2, 0x02b57533, 1),                                                          // remu
        (5, 0, 0x02b57533, 5),                                                          // remu by zero -> dividend
        (0xffff_ffff_ffff_fffe, 0x4000_0000_0000_0000, 0x02b51533, 0xffff_ffff_ffff_ffff), // mulh
        (3, 4, 0x02b5053b, 12),                                                          // mulw
        (7, 2, 0x02b5453b, 3),                                                           // divw
        (7, 2, 0x02b5653b, 1),                                                           // remw
    ];
    for (rs1v, rs2v, word, expected) in cases.iter() {
        let mut c = cpu();
        c.regs.write(10, *rs1v);
        c.regs.write(11, *rs2v);
        c.execute(&Instruction::new(*word)).unwrap();
        assert_eq!(c.regs.read(10), *expected, "word=0x{word:x}");
    }

    // remu a4,a1,a2 -- the exact instruction that first exposed this gap in riscvm
    let mut c = cpu();
    c.regs.write(11, 7);
    c.regs.write(12, 2);
    c.execute(&Instruction::new(0x02c5f733)).unwrap();
    assert_eq!(c.regs.read(14), 1);
}

// --- stage 2: test_sh_stores_halfword ---
#[test]
fn sh_stores_halfword() {
    let ram = Ram::new(0x100);
    let mut bus = Bus::new();
    bus.add_device(Box::new(ram), 0).unwrap();
    let mut c = Cpu::new(bus);
    c.regs.write(10, 0x20);   // a0: base address
    c.regs.write(11, 0xbeef); // a1: value to store
    c.execute(&Instruction::new(0xb51223)).unwrap(); // sh a1, 4(a0)
    assert_eq!(c.bus.read(0x24, 2).unwrap(), 0xbeef);
}
