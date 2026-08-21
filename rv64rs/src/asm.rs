//! Tiny hand-assembly helpers, standing in for riscvm's tools/as.py (which
//! shells out to a real riscv64-linux-gnu-gcc toolchain we don't have on
//! this machine). Just enough instruction encoders to build small demo/test
//! programs by hand for milestones that need more than a single
//! instruction word.

pub fn encode_i(imm: i32, rs1: u32, funct3: u32, rd: u32, opcode: u32) -> u32 {
    (((imm as u32) & 0xfff) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode
}

pub fn encode_s(imm: i32, rs1: u32, rs2: u32, funct3: u32, opcode: u32) -> u32 {
    let imm = imm as u32;
    (((imm >> 5) & 0x7f) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((imm & 0x1f) << 7) | opcode
}

/// `imm` is the already-shifted upper-20-bits value (e.g. 0x3000 for `lui sp, 0x3`).
pub fn encode_u(imm: u32, rd: u32, opcode: u32) -> u32 {
    (imm & 0xffff_f000) | (rd << 7) | opcode
}

pub fn encode_j(imm: i32, rd: u32, opcode: u32) -> u32 {
    let imm = imm as u32;
    let bit20 = (imm >> 20) & 1;
    let bits10_1 = (imm >> 1) & 0x3ff;
    let bit11 = (imm >> 11) & 1;
    let bits19_12 = (imm >> 12) & 0xff;
    (bit20 << 31) | (bits10_1 << 21) | (bit11 << 20) | (bits19_12 << 12) | (rd << 7) | opcode
}

// Standard RISC-V ABI register numbers used by demo programs.
pub const ZERO: u32 = 0;
pub const RA: u32 = 1;
pub const SP: u32 = 2;
pub const T0: u32 = 5;
pub const T1: u32 = 6;
pub const A0: u32 = 10;

pub const OPCODE_LOAD: u32 = 0x03;
pub const OPCODE_STORE: u32 = 0x23;
pub const OPCODE_OP_IMM: u32 = 0x13;
pub const OPCODE_LUI: u32 = 0x37;
pub const OPCODE_JALR: u32 = 0x67;

pub const FUNCT3_SW: u32 = 0x2;
pub const FUNCT3_LW: u32 = 0x2;
pub const FUNCT3_ADDI: u32 = 0x0;

/// Stage 2 milestone program: use the stack region for real -- write 42,
/// read it back, increment, write again, read the final value into a0.
/// Ends the same way tests/fib.bin does: `jalr zero, ra, 0` with ra=0 (never
/// set), so it jumps to the unmapped address 0 and stops cleanly.
pub fn stack_demo_program() -> Vec<u8> {
    let instrs = [
        encode_u(0x3000, SP, OPCODE_LUI),                             // lui sp, 0x3       (sp = 0x3000, inside the stack region)
        encode_i(42, ZERO, FUNCT3_ADDI, T0, OPCODE_OP_IMM),             // addi t0, zero, 42
        encode_s(0, SP, T0, FUNCT3_SW, OPCODE_STORE),                   // sw t0, 0(sp)
        encode_i(0, SP, FUNCT3_LW, T1, OPCODE_LOAD),                    // lw t1, 0(sp)
        encode_i(1, T1, FUNCT3_ADDI, T1, OPCODE_OP_IMM),                 // addi t1, t1, 1
        encode_s(4, SP, T1, FUNCT3_SW, OPCODE_STORE),                    // sw t1, 4(sp)
        encode_i(4, SP, FUNCT3_LW, A0, OPCODE_LOAD),                     // lw a0, 4(sp)
        encode_i(0, RA, 0x0, ZERO, OPCODE_JALR),                          // jalr zero, ra, 0
    ];
    instrs.iter().flat_map(|w| w.to_le_bytes()).collect()
}
