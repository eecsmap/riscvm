//! Corresponds to the RV64I execute portion of riscvm/rv64i.py.
//!
//! Stage 1 added OP-IMM / OP (+ their -32 W-variants), LUI, AUIPC, BRANCH,
//! JAL, JALR, and MISC-MEM/FENCE as a no-op -- pure register compute and
//! control flow, no bus access.
//!
//! Stage 2 added LOAD/STORE. Stage 4 added SYSTEM (opcode 0x73): CSRRW/
//! CSRRS/CSRRC and their -immediate forms, ECALL, MRET, SRET, WFI (no-op).
//! EBREAK is decoded but not implemented, matching riscvm's own actor():
//! it's in the Mnemonic table but has no case in the match, so it falls
//! through to the same "unimplemented" error there too.
//!
//! Stage 6: LOAD/STORE (and AMOSWAP.W) go through cpu.read()/cpu.write()
//! instead of cpu.bus.read/write directly, so they pick up Sv39
//! translation (see mmu.rs) once satp switches paging on.
//!
//! perf-P4: SFENCE.VMA now actually does something -- flushes mmu::Tlb
//! (see mmu.rs for why one exists at all: profiling justified it after
//! P1-P3 removed the cheaper wins).

use crate::cpu::Cpu;
use crate::decode::Instruction;
use crate::error::EmuError;
use crate::trap;

const OPCODE_LOAD: u32 = 0x03;
const OPCODE_MISC_MEM: u32 = 0x0f;
const OPCODE_STORE: u32 = 0x23;
const OPCODE_AUIPC: u32 = 0x17;
const OPCODE_OP_IMM: u32 = 0x13;
const OPCODE_OP_IMM_32: u32 = 0x1b;
const OPCODE_LUI: u32 = 0x37;
const OPCODE_OP: u32 = 0x33;
const OPCODE_OP_32: u32 = 0x3b;
const OPCODE_BRANCH: u32 = 0x63;
const OPCODE_JALR: u32 = 0x67;
const OPCODE_JAL: u32 = 0x6f;
const OPCODE_SYSTEM: u32 = 0x73;
const OPCODE_AMO: u32 = 0x2f;

/// Sign-extend the low `bits` bits of a value already sitting in a u64
/// (used for LB/LH/LW, whose loaded width is narrower than the 64-bit
/// register they land in).
#[inline(always)]
fn sext64(value: u64, bits: u32) -> u64 {
    let shift = 64 - bits;
    (((value << shift) as i64) >> shift) as u64
}

/// Executes one decoded instruction against `cpu`, returning the next pc
/// (the caller, Cpu::execute, commits it). Errors on anything outside this
/// stage's scope.
pub fn execute(instr: &Instruction, cpu: &mut Cpu) -> Result<u64, EmuError> {
    let pc = cpu.pc;
    let default_next = pc.wrapping_add(4);

    match instr.opcode {
        OPCODE_LOAD => {
            let addr = cpu.regs.read(instr.rs1).wrapping_add(instr.imm_i as u64);
            let out = match instr.funct3 {
                0x0 => sext64(cpu.read(addr, 1)?, 8),   // LB
                0x1 => sext64(cpu.read(addr, 2)?, 16),  // LH
                0x2 => sext64(cpu.read(addr, 4)?, 32),  // LW
                0x3 => cpu.read(addr, 8)?,               // LD
                0x4 => cpu.read(addr, 1)?,                // LBU
                0x5 => cpu.read(addr, 2)?,                // LHU
                0x6 => cpu.read(addr, 4)?,                // LWU
                _ => return cpu.illegal_instruction(instr),
            };
            cpu.regs.write(instr.rd, out);
            Ok(default_next)
        }
        OPCODE_STORE => {
            let addr = cpu.regs.read(instr.rs1).wrapping_add(instr.imm_s as u64);
            let value = cpu.regs.read(instr.rs2);
            match instr.funct3 {
                0x0 => cpu.write(addr, 1, value)?, // SB
                0x1 => cpu.write(addr, 2, value)?, // SH
                0x2 => cpu.write(addr, 4, value)?, // SW
                0x3 => cpu.write(addr, 8, value)?, // SD
                _ => return cpu.illegal_instruction(instr),
            };
            Ok(default_next)
        }
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
                (0x1, 0x00) => a << (b & 0x3f),                   // SLL
                (0x2, 0x00) => ((a as i64) < (b as i64)) as u64,   // SLT
                (0x3, 0x00) => (a < b) as u64,                     // SLTU
                (0x4, 0x00) => a ^ b,                              // XOR
                (0x5, 0x00) => a >> (b & 0x3f),                   // SRL
                (0x5, 0x20) => ((a as i64) >> (b & 0x3f)) as u64, // SRA
                (0x6, 0x00) => a | b,                              // OR
                (0x7, 0x00) => a & b,                              // AND
                // RV64M
                (0x0, 0x01) => a.wrapping_mul(b), // MUL
                (0x1, 0x01) => (((a as i64 as i128) * (b as i64 as i128)) >> 64) as u64, // MULH
                (0x2, 0x01) => (((a as i64 as i128) * (b as i128)) >> 64) as u64, // MULHSU
                (0x3, 0x01) => (((a as u128) * (b as u128)) >> 64) as u64, // MULHU
                (0x4, 0x01) => match (a as i64, b as i64) {
                    (_, 0) => u64::MAX,                    // div by zero -> -1
                    (i64::MIN, -1) => a,                    // overflow -> wraps to dividend
                    (x, y) => (x / y) as u64,                // DIV (truncated toward zero)
                },
                (0x5, 0x01) => a.checked_div(b).unwrap_or(u64::MAX), // DIVU
                (0x6, 0x01) => match (a as i64, b as i64) {
                    (_, 0) => a,                            // rem by zero -> dividend
                    (i64::MIN, -1) => 0,                     // overflow -> 0
                    (x, y) => (x % y) as u64,                // REM
                },
                (0x7, 0x01) => if b == 0 { a } else { a % b }, // REMU
                _ => return cpu.illegal_instruction(instr),
            };
            cpu.regs.write(instr.rd, out);
            Ok(default_next)
        }
        OPCODE_OP_32 => {
            let a32 = cpu.regs.read(instr.rs1) as u32;
            let b32 = cpu.regs.read(instr.rs2) as u32;
            // All results here are 32-bit and get sign-extended to 64 below,
            // including the divide-by-zero case: per spec, DIVW/DIVUW on
            // division by zero yield -1 sign-extended to the full 64-bit
            // register, which 0xffff_ffffu32 -> sign-extend naturally gives.
            let out32 = match (instr.funct3, instr.funct7) {
                (0x0, 0x00) => a32.wrapping_add(b32),   // ADDW
                (0x0, 0x20) => a32.wrapping_sub(b32),    // SUBW
                (0x1, _) => a32 << (b32 & 0x1f),          // SLLW
                (0x5, 0x00) => a32 >> (b32 & 0x1f),       // SRLW
                (0x5, 0x20) => ((a32 as i32) >> (b32 & 0x1f)) as u32, // SRAW
                // RV64M word variants
                (0x0, 0x01) => a32.wrapping_mul(b32), // MULW
                (0x4, 0x01) => match (a32 as i32, b32 as i32) {
                    (_, 0) => 0xffff_ffff,          // div by zero -> -1
                    (i32::MIN, -1) => a32,            // overflow -> wraps to dividend
                    (x, y) => (x / y) as u32,
                }, // DIVW
                (0x5, 0x01) => a32.checked_div(b32).unwrap_or(0xffff_ffff), // DIVUW
                (0x6, 0x01) => match (a32 as i32, b32 as i32) {
                    (_, 0) => a32,                    // rem by zero -> dividend
                    (i32::MIN, -1) => 0,               // overflow -> 0
                    (x, y) => (x % y) as u32,
                }, // REMW
                (0x7, 0x01) => if b32 == 0 { a32 } else { a32 % b32 }, // REMUW
                _ => return cpu.illegal_instruction(instr),
            };
            cpu.regs.write(instr.rd, (out32 as i32) as i64 as u64);
            Ok(default_next)
        }
        OPCODE_MISC_MEM => Ok(default_next), // FENCE / FENCE.I: no-op at this stage
        OPCODE_SYSTEM => execute_system(instr, cpu, default_next),
        OPCODE_AMO => {
            // Only AMOSWAP.W is implemented, matching riscvm's own actor():
            // it's the only AMO variant that ever got a case there (xv6's
            // spinlocks -- initlock/acquire -- are the only thing needing
            // one). funct5 is funct7's top 5 bits (funct7 >> 2); the low 2
            // bits are aq/rl ordering flags this single-threaded emulator
            // has no reason to model.
            let funct5 = instr.funct7 >> 2;
            if instr.funct3 == 0x2 && funct5 == 0b00001 {
                let addr = cpu.regs.read(instr.rs1);
                let old = sext64(cpu.read(addr, 4)?, 32);
                cpu.write(addr, 4, cpu.regs.read(instr.rs2))?;
                cpu.regs.write(instr.rd, old);
                Ok(default_next)
            } else {
                cpu.illegal_instruction(instr)
            }
        }
        _ => cpu.illegal_instruction(instr),
    }
}

fn execute_system(instr: &Instruction, cpu: &mut Cpu, default_next: u64) -> Result<u64, EmuError> {
    match instr.funct3 {
        0x1 => {
            // CSRRW: read rs1 before writing rd, in case rd == rs1 (xv6's
            // timervec starts with `csrrw a0, mscratch, a0`).
            let rs1_value = cpu.regs.read(instr.rs1);
            cpu.regs.write(instr.rd, trap::csr_read(cpu, instr.csr));
            trap::csr_write(cpu, instr.csr, rs1_value);
            Ok(default_next)
        }
        0x2 => {
            // CSRRS
            let rs1_value = cpu.regs.read(instr.rs1);
            let old = trap::csr_read(cpu, instr.csr);
            cpu.regs.write(instr.rd, old);
            trap::csr_write(cpu, instr.csr, old | rs1_value);
            Ok(default_next)
        }
        0x3 => {
            // CSRRC
            let rs1_value = cpu.regs.read(instr.rs1);
            let old = trap::csr_read(cpu, instr.csr);
            cpu.regs.write(instr.rd, old);
            trap::csr_write(cpu, instr.csr, old & !rs1_value);
            Ok(default_next)
        }
        0x5 => {
            // CSRRWI: the rs1 field holds a 5-bit zero-extended immediate, not a register
            let imm = instr.rs1 as u64;
            cpu.regs.write(instr.rd, trap::csr_read(cpu, instr.csr));
            trap::csr_write(cpu, instr.csr, imm);
            Ok(default_next)
        }
        0x6 => {
            // CSRRSI
            let imm = instr.rs1 as u64;
            let old = trap::csr_read(cpu, instr.csr);
            cpu.regs.write(instr.rd, old);
            trap::csr_write(cpu, instr.csr, old | imm);
            Ok(default_next)
        }
        0x7 => {
            // CSRRCI
            let imm = instr.rs1 as u64;
            let old = trap::csr_read(cpu, instr.csr);
            cpu.regs.write(instr.rd, old);
            trap::csr_write(cpu, instr.csr, old & !imm);
            Ok(default_next)
        }
        0x0 => match (instr.funct7, instr.rs2) {
            (0b0000000, 0b00000) => {
                // ECALL: 8=U-mode, 9=S-mode, 11=M-mode
                let cause = 8 + cpu.mode as u64;
                Ok(trap::raise_trap(cpu, cause, false, 0))
            }
            (0b0001000, 0b00010) => {
                // SRET
                let mut sstatus = cpu.csrs.get(crate::csr::MSTATUS); // sstatus aliases mstatus
                let spie = sstatus & trap::MSTATUS_SPIE != 0;
                let spp = (sstatus & trap::MSTATUS_SPP) >> 8;
                sstatus = (sstatus & !trap::MSTATUS_SIE) | if spie { trap::MSTATUS_SIE } else { 0 };
                sstatus |= trap::MSTATUS_SPIE;
                sstatus &= !trap::MSTATUS_SPP;
                cpu.csrs.insert(crate::csr::MSTATUS, sstatus);
                cpu.mode = spp as u8;
                Ok(cpu.csrs.get(crate::csr::SEPC))
            }
            (0b0001000, 0b00101) => Ok(default_next), // WFI: interrupts are checked every instruction anyway
            (0b0001001, _) => {
                cpu.tlb.flush(); // SFENCE.VMA: whole-TLB invalidation (see mmu::Tlb::flush)
                Ok(default_next)
            }
            (0b0011000, _) => {
                // MRET
                let mut mstatus = cpu.csrs.get(crate::csr::MSTATUS);
                let mpie = mstatus & trap::MSTATUS_MPIE != 0;
                let mpp = (mstatus & trap::MSTATUS_MPP) >> 11;
                mstatus = (mstatus & !trap::MSTATUS_MIE) | if mpie { trap::MSTATUS_MIE } else { 0 };
                mstatus |= trap::MSTATUS_MPIE;
                mstatus &= !trap::MSTATUS_MPP;
                cpu.csrs.insert(crate::csr::MSTATUS, mstatus);
                cpu.mode = mpp as u8;
                Ok(cpu.csrs.get(crate::csr::MEPC))
            }
            _ => cpu.illegal_instruction(instr), // includes EBREAK -- unimplemented in riscvm too
        },
        _ => cpu.illegal_instruction(instr),
    }
}
