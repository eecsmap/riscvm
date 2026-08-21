//! Corresponds to riscvm/rv64c.py: the "C" (compressed, 16-bit)
//! instructions. Field layout, decode table, and execute semantics are a
//! direct port -- same bit positions, same mnemonic-selection table, same
//! special cases (e.g. LI/ADDIW/ANDI don't error on a zero immediate;
//! ADDI/LUI/ADDI4SPN/ADDI16SP/SLLI/SRLI/SRAI do, per the RVC spec's
//! reserved encodings).
//!
//! Only the RVC subset riscvm itself implements is ported here (no
//! compressed floating-point loads/stores, no C.SLLI64 etc.) -- this
//! project doesn't implement those either, so there's nothing to port.

use crate::cpu::Cpu;
use crate::error::{error, EmuError};

#[derive(Debug, Clone, Copy)]
pub struct CInstruction {
    pub value: u16,
}

#[inline(always)]
fn section(x: u16, pos: u32, nbits: u32) -> u32 {
    ((x as u32) >> pos) & ((1u32 << nbits) - 1)
}

#[inline(always)]
fn sext(value: u32, bits: u32) -> i64 {
    let shift = 32 - bits;
    ((value << shift) as i32 >> shift) as i64
}

impl CInstruction {
    pub fn new(value: u16) -> Self {
        CInstruction { value }
    }

    pub fn op(&self) -> u32 {
        section(self.value, 0, 2)
    }
    pub fn rd(&self) -> usize {
        section(self.value, 7, 5) as usize
    }
    pub fn rs1(&self) -> usize {
        self.rd()
    }
    pub fn rs2(&self) -> usize {
        section(self.value, 2, 5) as usize
    }
    pub fn rs1_prime(&self) -> usize {
        section(self.value, 7, 3) as usize + 8
    }
    pub fn rs2_prime(&self) -> usize {
        section(self.value, 2, 3) as usize + 8
    }
    pub fn funct3(&self) -> u32 {
        section(self.value, 13, 3)
    }
    pub fn funct6(&self) -> u32 {
        section(self.value, 10, 6)
    }
    pub fn funct2(&self) -> u32 {
        section(self.value, 5, 2)
    }
    pub fn bit12(&self) -> u32 {
        section(self.value, 12, 1)
    }

    fn uimm_5_0(&self) -> u32 {
        (section(self.value, 12, 1) << 5) | section(self.value, 2, 5)
    }
    /// LI, ADDIW, ANDI: sign-extended, zero is a valid value.
    pub fn imm_5_0(&self) -> i64 {
        sext(self.uimm_5_0(), 6)
    }
    /// ADDI, LUI: same bits as imm_5_0, but zero is a reserved encoding.
    pub fn nzimm_5_0(&self) -> Result<i64, EmuError> {
        nz(self.imm_5_0())
    }
    /// SLLI, SRLI, SRAI shift amount: zero is reserved.
    pub fn shamt(&self) -> Result<u32, EmuError> {
        let v = self.uimm_5_0();
        if v == 0 {
            nz_error()
        } else {
            Ok(v)
        }
    }
    pub fn nzuimm_9_2(&self) -> Result<u32, EmuError> {
        let v = (section(self.value, 11, 2) << 4)
            | (section(self.value, 7, 4) << 6)
            | (section(self.value, 6, 1) << 2)
            | (section(self.value, 5, 1) << 3);
        if v == 0 {
            nz_error()
        } else {
            Ok(v)
        }
    }
    pub fn nzimm_9_4(&self) -> Result<i64, EmuError> {
        let v = sext(
            (section(self.value, 12, 1) << 9)
                | (section(self.value, 6, 1) << 4)
                | (section(self.value, 5, 1) << 6)
                | (section(self.value, 3, 2) << 7)
                | (section(self.value, 2, 1) << 5),
            10,
        );
        nz(v)
    }
    pub fn offset_6_2(&self) -> u32 {
        (section(self.value, 10, 3) << 3) | (section(self.value, 6, 1) << 2) | (section(self.value, 5, 1) << 6)
    }
    pub fn offset_7_3(&self) -> u32 {
        (section(self.value, 10, 3) << 3) | (section(self.value, 5, 2) << 6)
    }
    pub fn offset_8_1(&self) -> i64 {
        sext(
            (section(self.value, 12, 1) << 8)
                | (section(self.value, 10, 2) << 3)
                | (section(self.value, 5, 2) << 6)
                | (section(self.value, 3, 2) << 1)
                | (section(self.value, 2, 1) << 5),
            9,
        )
    }
    pub fn offset_8_3_ldsp(&self) -> u32 {
        (section(self.value, 12, 1) << 5) | (section(self.value, 5, 2) << 3) | (section(self.value, 2, 3) << 6)
    }
    pub fn offset_8_3_sdsp(&self) -> u32 {
        (section(self.value, 10, 3) << 3) | (section(self.value, 7, 3) << 6)
    }
    pub fn offset_11_1(&self) -> i64 {
        sext(
            (section(self.value, 12, 1) << 11)
                | (section(self.value, 11, 1) << 4)
                | (section(self.value, 9, 2) << 8)
                | (section(self.value, 8, 1) << 10)
                | (section(self.value, 7, 1) << 6)
                | (section(self.value, 6, 1) << 7)
                | (section(self.value, 3, 3) << 1)
                | (section(self.value, 2, 1) << 5),
            12,
        )
    }
}

fn nz_error<T>() -> Result<T, EmuError> {
    error("unexpected zero immediate value")
}

fn nz(v: i64) -> Result<i64, EmuError> {
    if v == 0 {
        nz_error()
    } else {
        Ok(v)
    }
}

/// Executes one decoded 16-bit instruction, returning the next pc
/// (default: pc+2). Mirrors rv64c.py's actor(), including which mnemonics
/// share a funct3 slot and are disambiguated further (SUB/XOR/OR/AND vs
/// SUBW/ADDW by funct2+bit; MV/JR vs ADD/JALR/EBREAK by rs2/rs1 presence).
pub fn execute(instr: &CInstruction, cpu: &mut Cpu) -> Result<u64, EmuError> {
    let pc = cpu.pc;
    let default_next = pc.wrapping_add(2);

    match instr.op() {
        0b00 => match instr.funct3() {
            0b000 => {
                // C.ADDI4SPN: addi rd', x2, nzuimm[9:2]
                let imm = instr.nzuimm_9_2()?;
                let sp = cpu.regs.read(2);
                cpu.regs.write(instr.rs2_prime(), sp.wrapping_add(imm as u64));
                Ok(default_next)
            }
            0b010 => {
                // C.LW: lw rd', offset[6:2](rs1')
                let addr = cpu.regs.read(instr.rs1_prime()).wrapping_add(instr.offset_6_2() as u64);
                let v = cpu.read(addr, 4)?;
                cpu.regs.write(instr.rs2_prime(), sext(v as u32, 32) as u64);
                Ok(default_next)
            }
            0b011 => {
                // C.LD: ld rd', offset[7:3](rs1')
                let addr = cpu.regs.read(instr.rs1_prime()).wrapping_add(instr.offset_7_3() as u64);
                let v = cpu.read(addr, 8)?;
                cpu.regs.write(instr.rs2_prime(), v);
                Ok(default_next)
            }
            0b110 => {
                // C.SW: sw rs2', offset[6:2](rs1')
                let addr = cpu.regs.read(instr.rs1_prime()).wrapping_add(instr.offset_6_2() as u64);
                cpu.write(addr, 4, cpu.regs.read(instr.rs2_prime()))?;
                Ok(default_next)
            }
            0b111 => {
                // C.SD: sd rs2', offset[7:3](rs1')
                let addr = cpu.regs.read(instr.rs1_prime()).wrapping_add(instr.offset_7_3() as u64);
                cpu.write(addr, 8, cpu.regs.read(instr.rs2_prime()))?;
                Ok(default_next)
            }
            _ => cpu.illegal_c_instruction(instr),
        },
        0b01 => match instr.funct3() {
            0b000 => {
                // C.ADDI (rd==0 is C.NOP, handled the same way): addi rd,rd,nzimm[5:0]
                let imm = instr.imm_5_0(); // not the nz-checked variant: NOP is imm=0,rd=0
                let rd = instr.rd();
                cpu.regs.write(rd, cpu.regs.read(rd).wrapping_add(imm as u64));
                Ok(default_next)
            }
            0b001 => {
                // C.ADDIW: addiw rd,rd,imm[5:0]
                let rd = instr.rd();
                if rd == 0 {
                    return cpu.illegal_c_instruction(instr);
                }
                let a = cpu.regs.read(rd) as u32;
                let out = a.wrapping_add(instr.imm_5_0() as u32);
                cpu.regs.write(rd, (out as i32) as i64 as u64);
                Ok(default_next)
            }
            0b010 => {
                // C.LI: addi rd, x0, imm[5:0]
                let rd = instr.rd();
                if rd == 0 {
                    return cpu.illegal_c_instruction(instr);
                }
                cpu.regs.write(rd, instr.imm_5_0() as u64);
                Ok(default_next)
            }
            0b011 => {
                if instr.rd() == 2 {
                    // C.ADDI16SP: addi x2, x2, nzimm[9:4]
                    let imm = instr.nzimm_9_4()?;
                    let sp = cpu.regs.read(2);
                    cpu.regs.write(2, sp.wrapping_add(imm as u64));
                } else {
                    // C.LUI: lui rd, nzimm[17:12]  (same raw bits as nzimm_5_0, shifted)
                    let rd = instr.rd();
                    if rd == 0 || rd == 2 {
                        return cpu.illegal_c_instruction(instr);
                    }
                    let imm = instr.nzimm_5_0()?;
                    cpu.regs.write(rd, (imm << 12) as u64);
                }
                Ok(default_next)
            }
            0b100 => {
                let funct6 = instr.funct6();
                match funct6 & 0b11 {
                    0b00 => {
                        // C.SRLI
                        let shamt = instr.shamt()?;
                        let r = instr.rs1_prime();
                        cpu.regs.write(r, cpu.regs.read(r) >> shamt);
                        Ok(default_next)
                    }
                    0b01 => {
                        // C.SRAI
                        let shamt = instr.shamt()?;
                        let r = instr.rs1_prime();
                        cpu.regs.write(r, ((cpu.regs.read(r) as i64) >> shamt) as u64);
                        Ok(default_next)
                    }
                    0b10 => {
                        // C.ANDI (zero is a valid immediate here)
                        let r = instr.rs1_prime();
                        cpu.regs.write(r, cpu.regs.read(r) & (instr.imm_5_0() as u64));
                        Ok(default_next)
                    }
                    0b11 => {
                        let r1 = instr.rs1_prime();
                        let r2 = instr.rs2_prime();
                        let a = cpu.regs.read(r1);
                        let b = cpu.regs.read(r2);
                        if funct6 & 0b100 == 0 {
                            match instr.funct2() {
                                0b00 => cpu.regs.write(r1, a.wrapping_sub(b)), // C.SUB
                                0b01 => cpu.regs.write(r1, a ^ b),              // C.XOR
                                0b10 => cpu.regs.write(r1, a | b),               // C.OR
                                0b11 => cpu.regs.write(r1, a & b),               // C.AND
                                _ => unreachable!(),
                            }
                        } else {
                            let a32 = a as u32;
                            let b32 = b as u32;
                            match instr.funct2() {
                                0b00 => cpu.regs.write(r1, (a32.wrapping_sub(b32) as i32) as i64 as u64), // C.SUBW
                                0b01 => cpu.regs.write(r1, (a32.wrapping_add(b32) as i32) as i64 as u64), // C.ADDW
                                _ => return cpu.illegal_c_instruction(instr),
                            }
                        }
                        Ok(default_next)
                    }
                    _ => unreachable!(),
                }
            }
            0b101 => Ok(pc.wrapping_add(instr.offset_11_1() as u64)), // C.J
            0b110 => {
                // C.BEQZ
                let taken = cpu.regs.read(instr.rs1_prime()) == 0;
                Ok(if taken { pc.wrapping_add(instr.offset_8_1() as u64) } else { default_next })
            }
            0b111 => {
                // C.BNEZ
                let taken = cpu.regs.read(instr.rs1_prime()) != 0;
                Ok(if taken { pc.wrapping_add(instr.offset_8_1() as u64) } else { default_next })
            }
            _ => cpu.illegal_c_instruction(instr),
        },
        0b10 => match instr.funct3() {
            0b000 => {
                // C.SLLI
                let shamt = instr.shamt()?;
                let rd = instr.rd();
                cpu.regs.write(rd, cpu.regs.read(rd) << shamt);
                Ok(default_next)
            }
            0b011 => {
                // C.LDSP
                let rd = instr.rd();
                if rd == 0 {
                    return cpu.illegal_c_instruction(instr);
                }
                let addr = cpu.regs.read(2).wrapping_add(instr.offset_8_3_ldsp() as u64);
                let v = cpu.read(addr, 8)?;
                cpu.regs.write(rd, v);
                Ok(default_next)
            }
            0b100 => {
                if instr.bit12() == 0 {
                    if instr.rs2() != 0 {
                        // C.MV: add rd, x0, rs2
                        let rs1 = instr.rs1();
                        if rs1 == 0 {
                            return cpu.illegal_c_instruction(instr);
                        }
                        cpu.regs.write(rs1, cpu.regs.read(instr.rs2()));
                        Ok(default_next)
                    } else {
                        // C.JR: jalr x0, rs1, 0
                        let rs1 = instr.rs1();
                        if rs1 == 0 {
                            return cpu.illegal_c_instruction(instr);
                        }
                        Ok(cpu.regs.read(rs1))
                    }
                } else if instr.rs2() != 0 {
                    // C.ADD: add rd, rd, rs2
                    let rd = instr.rd();
                    if rd == 0 {
                        return cpu.illegal_c_instruction(instr);
                    }
                    cpu.regs.write(rd, cpu.regs.read(rd).wrapping_add(cpu.regs.read(instr.rs2())));
                    Ok(default_next)
                } else if instr.rs1() != 0 {
                    // C.JALR: jalr x1, rs1, 0
                    let target = cpu.regs.read(instr.rs1());
                    cpu.regs.write(1, pc.wrapping_add(2));
                    Ok(target)
                } else {
                    // C.EBREAK -- not implemented at this stage (SYSTEM/trap territory, stage 4)
                    cpu.illegal_c_instruction(instr)
                }
            }
            0b111 => {
                // C.SDSP: sd rs2, offset[8:3](x2)
                let addr = cpu.regs.read(2).wrapping_add(instr.offset_8_3_sdsp() as u64);
                cpu.write(addr, 8, cpu.regs.read(instr.rs2()))?;
                Ok(default_next)
            }
            _ => cpu.illegal_c_instruction(instr),
        },
        _ => cpu.illegal_c_instruction(instr),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bus::Bus;
    use crate::ram::Ram;

    fn cpu() -> Cpu {
        let mut bus = Bus::new();
        bus.add_device(Box::new(Ram::new(0x10000)), 0).unwrap();
        Cpu::new(bus)
    }

    // rd'/rs1' = a1 (x11, compressed raw 3), rs2' = a5 (x15, compressed raw 7)
    #[test]
    fn c_alu() {
        let cases: [(u16, u64, u64, u64); 5] = [
            (0x8d9d, 10, 3, 7),                                              // c.sub a1,a1,a5
            (0x8dbd, 0b1010, 0b0110, 0b1100),                                 // c.xor a1,a1,a5
            (0x9d9d, 10, 3, 7),                                                // c.subw a1,a1,a5
            (0x9dbd, 10, 3, 13),                                               // c.addw a1,a1,a5
            (0x9dbd, 0xffff_ffff_0000_0001, 0xffff_ffff_ffff_ffff, 0),          // c.addw wraps to 32 bits
        ];
        for (word, a1, a5, expected) in cases {
            let mut c = cpu();
            c.regs.write(11, a1);
            c.regs.write(15, a5);
            c.execute_compressed(&CInstruction::new(word)).unwrap();
            assert_eq!(c.regs.read(11), expected, "word=0x{word:x}");
        }
    }

    #[test]
    fn c_jalr_jumps_and_saves_return_address() {
        let mut c = cpu();
        c.pc = 0x1000;
        c.regs.write(10, 0x2000); // a0: jump target
        c.execute_compressed(&CInstruction::new(0x9502)).unwrap(); // c.jalr a0
        assert_eq!(c.pc, 0x2000);
        assert_eq!(c.regs.read(1), 0x1002); // ra <- return address (pc + 2)
    }

    #[test]
    fn nz_error_on_zero_immediate() {
        let instr = CInstruction::new(0);
        assert!(instr.nzimm_5_0().is_err());
    }
}
