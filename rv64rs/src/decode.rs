//! Corresponds to the decode portion of riscvm/rv64i.py: pull opcode/rd/
//! rs1/rs2/funct3/funct7 and the five immediate encodings (I/S/B/U/J) out
//! of a raw 32-bit instruction word. Field layout and sign-extension match
//! rv64i.py's `imm_i`/`imm_s`/`imm_b`/`imm_u`/`imm_j` exactly (see that
//! file's `_test_sections()` doctests for the bit-layout reference this
//! was checked against).

#[derive(Debug, Clone, Copy)]
pub struct Instruction {
    pub value: u32,
    pub opcode: u32,
    pub rd: usize,
    pub rs1: usize,
    pub rs2: usize,
    pub funct3: u32,
    pub funct7: u32,
    pub imm_i: i64,
    pub imm_s: i64,
    pub imm_b: i64,
    pub imm_u: i64,
    pub imm_j: i64,
    pub shamt: u32, // RV64: 6-bit shift amount (bits [25:20])
    pub csr: u32,   // same bits as imm_i, unsigned: the 12-bit CSR address (SYSTEM opcode)
}

#[inline(always)]
fn sext(value: u32, bits: u32) -> i64 {
    let shift = 32 - bits;
    ((value << shift) as i32 >> shift) as i64
}

impl Instruction {
    pub fn new(w: u32) -> Self {
        let opcode = w & 0x7f;
        let rd = ((w >> 7) & 0x1f) as usize;
        let rs1 = ((w >> 15) & 0x1f) as usize;
        let rs2 = ((w >> 20) & 0x1f) as usize;
        let funct3 = (w >> 12) & 0x7;
        let funct7 = (w >> 25) & 0x7f;

        let imm_i = sext(w >> 20, 12);
        let imm_s = sext(((w >> 25) << 5) | ((w >> 7) & 0x1f), 12);
        let imm_b = sext(
            (((w >> 31) & 1) << 12)
                | (((w >> 7) & 1) << 11)
                | (((w >> 25) & 0x3f) << 5)
                | (((w >> 8) & 0xf) << 1),
            13,
        );
        let imm_u = ((w & 0xffff_f000) as i32) as i64;
        let imm_j = sext(
            (((w >> 31) & 1) << 20)
                | (((w >> 12) & 0xff) << 12)
                | (((w >> 20) & 1) << 11)
                | (((w >> 21) & 0x3ff) << 1),
            21,
        );
        let shamt = (w >> 20) & 0x3f;
        let csr = (w >> 20) & 0xfff;

        Instruction {
            value: w,
            opcode,
            rd,
            rs1,
            rs2,
            funct3,
            funct7,
            imm_i,
            imm_s,
            imm_b,
            imm_u,
            imm_j,
            shamt,
            csr,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Cross-checked against rv64i.py's _test_sections() doctests.
    #[test]
    fn imm_i_sign_extends() {
        let neg = Instruction::new(0b1000000_00001_00000_000_00000_0000000);
        assert_eq!(neg.imm_i, -2047);
    }

    #[test]
    fn field_extraction() {
        let w = Instruction::new(0b0000101_00010_00001_011_00100_0000110);
        assert_eq!(w.opcode, 6);
        assert_eq!(w.rd, 4);
        assert_eq!(w.funct3, 3);
        assert_eq!(w.rs1, 1);
        assert_eq!(w.rs2, 2);
        assert_eq!(w.funct7, 5);
    }
}
