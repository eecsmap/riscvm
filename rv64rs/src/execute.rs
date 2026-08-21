//! Corresponds to the RV64I execute portion of riscvm/rv64i.py.
//!
//! Stage 1 scope only: OP-IMM / OP (+ their -32 W-variants), LUI, AUIPC,
//! BRANCH, JAL, JALR, and MISC-MEM/FENCE as a no-op -- pure register
//! compute and control flow, no bus access. LOAD/STORE (stage 2) and
//! SYSTEM/ECALL (stage 4) deliberately return "not implemented at this
//! stage" rather than silently doing nothing, so the staging stays honest
//! (mirrors how riscvm itself grew: an unimplemented opcode is a loud
//! InternalException, not silent wrong behavior).

use crate::cpu::Cpu;
use crate::decode::Instruction;
use crate::error::EmuError;

const OPCODE_LUI: u32 = 0x37;
const OPCODE_AUIPC: u32 = 0x17;
const OPCODE_JAL: u32 = 0x6f;
const OPCODE_JALR: u32 = 0x67;
const OPCODE_BRANCH: u32 = 0x63;
const OPCODE_OP_IMM: u32 = 0x13;
const OPCODE_OP_IMM_32: u32 = 0x1b;
const OPCODE_OP: u32 = 0x33;
const OPCODE_OP_32: u32 = 0x3b;
const OPCODE_MISC_MEM: u32 = 0x0f;

/// Executes one decoded instruction against `cpu`, returning the next pc
/// (the caller, Cpu::execute, commits it). Errors on anything outside this
/// stage's scope.
pub fn execute(instr: &Instruction, cpu: &mut Cpu) -> Result<u64, EmuError> {
    let pc = cpu.pc;
    let default_next = pc.wrapping_add(4);

    match instr.opcode {
        OPCODE_LUI => {
            cpu.regs.write(instr.rd, instr.imm_u as u64);
            Ok(default_next)
        }
        OPCODE_AUIPC => {
            cpu.regs.write(instr.rd, pc.wrapping_add(instr.imm_u as u64));
            Ok(default_next)
        }
        OPCODE_JAL => {
            cpu.regs.write(instr.rd, default_next);
            Ok(pc.wrapping_add(instr.imm_j as u64))
        }
        OPCODE_JALR => {
            let base = cpu.regs.read(instr.rs1);
            let target = base.wrapping_add(instr.imm_i as u64) & !1u64;
            cpu.regs.write(instr.rd, default_next);
            Ok(target)
        }
        OPCODE_BRANCH => {
            let a = cpu.regs.read(instr.rs1);
            let b = cpu.regs.read(instr.rs2);
            let taken = match instr.funct3 {
                0x0 => a == b,                         // BEQ
                0x1 => a != b,                          // BNE
                0x4 => (a as i64) < (b as i64),          // BLT
                0x5 => (a as i64) >= (b as i64),         // BGE
                0x6 => a < b,                            // BLTU
                0x7 => a >= b,                            // BGEU
                _ => return cpu.illegal_instruction(instr),
            };
            Ok(if taken { pc.wrapping_add(instr.imm_b as u64) } else { default_next })
        }
        OPCODE_OP_IMM => {
            let a = cpu.regs.read(instr.rs1);
            let imm = instr.imm_i as u64;
            let out = match instr.funct3 {
                0x0 => a.wrapping_add(imm),                          // ADDI
                0x2 => ((a as i64) < (instr.imm_i)) as u64,           // SLTI
                0x3 => (a < imm) as u64,                              // SLTIU
                0x4 => a ^ imm,                                       // XORI
                0x6 => a | imm,                                       // ORI
                0x7 => a & imm,                                       // ANDI
                0x1 => a << instr.shamt,                              // SLLI
                0x5 => {
                    if instr.funct7 & 0x20 != 0 {
                        ((a as i64) >> instr.shamt) as u64            // SRAI
                    } else {
                        a >> instr.shamt                              // SRLI
                    }
                }
                _ => return cpu.illegal_instruction(instr),
            };
            cpu.regs.write(instr.rd, out);
            Ok(default_next)
        }
        OPCODE_OP_IMM_32 => {
            let a = cpu.regs.read(instr.rs1) as u32;
            let shamt32 = instr.shamt & 0x1f;
            let out32 = match instr.funct3 {
                0x0 => a.wrapping_add(instr.imm_i as u32), // ADDIW
                0x1 => a << shamt32,                        // SLLIW
                0x5 => {
                    if instr.funct7 & 0x20 != 0 {
                        ((a as i32) >> shamt32) as u32       // SRAIW
                    } else {
                        a >> shamt32                          // SRLIW
                    }
                }
                _ => return cpu.illegal_instruction(instr),
            };
            cpu.regs.write(instr.rd, (out32 as i32) as i64 as u64); // sign-extend to 64
            Ok(default_next)
        }
        OPCODE_OP => {
            let a = cpu.regs.read(instr.rs1);
            let b = cpu.regs.read(instr.rs2);
            let out = match (instr.funct3, instr.funct7) {
                (0x0, 0x00) => a.wrapping_add(b),               // ADD
                (0x0, 0x20) => a.wrapping_sub(b),                // SUB
                (0x1, _) => a << (b & 0x3f),                     // SLL
                (0x2, _) => ((a as i64) < (b as i64)) as u64,     // SLT
                (0x3, _) => (a < b) as u64,                       // SLTU
                (0x4, _) => a ^ b,                                // XOR
                (0x5, 0x00) => a >> (b & 0x3f),                   // SRL
                (0x5, 0x20) => ((a as i64) >> (b & 0x3f)) as u64, // SRA
                (0x6, _) => a | b,                                // OR
                (0x7, _) => a & b,                                // AND
                _ => return cpu.illegal_instruction(instr),
            };
            cpu.regs.write(instr.rd, out);
            Ok(default_next)
        }
        OPCODE_OP_32 => {
            let a = cpu.regs.read(instr.rs1) as u32;
            let b = cpu.regs.read(instr.rs2) as u32;
            let out32 = match (instr.funct3, instr.funct7) {
                (0x0, 0x00) => a.wrapping_add(b),   // ADDW
                (0x0, 0x20) => a.wrapping_sub(b),    // SUBW
                (0x1, _) => a << (b & 0x1f),          // SLLW
                (0x5, 0x00) => a >> (b & 0x1f),       // SRLW
                (0x5, 0x20) => ((a as i32) >> (b & 0x1f)) as u32, // SRAW
                _ => return cpu.illegal_instruction(instr),
            };
            cpu.regs.write(instr.rd, (out32 as i32) as i64 as u64);
            Ok(default_next)
        }
        OPCODE_MISC_MEM => Ok(default_next), // FENCE / FENCE.I: no-op at this stage
        _ => cpu.illegal_instruction(instr),
    }
}
