//! Corresponds to riscvm/cpu.py: owns the register file, pc, and bus, and
//! drives fetch/execute.
//!
//! Stage 3 adds RVC dispatch: fetch() reads 4 bytes (over-reading is fine
//! for a compressed instruction -- only the low 16 bits matter, same as
//! cpu.py's fetch() comment about RVC constructors masking down to their
//! own width) and picks full RV64I vs 16-bit RVC by the low 2 bits, exactly
//! like cpu.py's `match data & 0b11`.
//!
//! Stage 4 adds CSR/privilege-level state (cpu.csrs, cpu.mode) and a
//! cpu.clint slot for trap.rs's check_interrupt() -- see trap.rs and
//! clint.rs. UART polling and MMU translation are still later-stage
//! additions; fetch() doesn't yet call check_interrupt() itself the way
//! cpu.py's does (that per-instruction interrupt-checking loop is a
//! stage 5 concern, once there's a real device wired up to observe it).

use crate::bus::Bus;
use crate::clint::Clint;
use crate::csr;
use crate::decode::Instruction;
use crate::error::{error, EmuError};
use crate::execute;
use crate::register::Registers;
use crate::rvc::{self, CInstruction};
use std::collections::HashMap;

pub enum DecodedInstruction {
    Full(Instruction),
    Compressed(CInstruction),
}

pub struct Cpu {
    pub regs: Registers,
    pub pc: u64,
    pub bus: Bus,
    pub csrs: HashMap<u32, u64>,
    pub mode: u8,
    pub clint: Option<Clint>,
}

impl Cpu {
    pub fn new(bus: Bus) -> Self {
        // Matches cpu.py's CPU.__init__: mstatus starts with some bits set
        // (notably MPP=11, i.e. M-mode, per the "hopefully we don't use
        // csrs too frequently" comment there), mie has MSIE|MTIE preset.
        let mut csrs = HashMap::new();
        csrs.insert(csr::MSTATUS, 0x000a_0000_0000);
        csrs.insert(csr::MIE, 0x222);
        Cpu { regs: Registers::new(), pc: 0, bus, csrs, mode: csr::PRIV_M, clint: None }
    }

    /// Mirrors CPU.fetch()'s `match data & 0b11` dispatch between full
    /// RV64I (0b11) and compressed (anything else) instructions.
    pub fn fetch(&self) -> Result<DecodedInstruction, EmuError> {
        let word = self.bus.read(self.pc, 4)? as u32;
        if word & 0b11 == 0b11 {
            Ok(DecodedInstruction::Full(Instruction::new(word)))
        } else {
            Ok(DecodedInstruction::Compressed(CInstruction::new(word as u16)))
        }
    }

    /// Mirrors CPU.execute(instruction) for a full RV64I instruction.
    pub fn execute(&mut self, instruction: &Instruction) -> Result<(), EmuError> {
        let next_pc = execute::execute(instruction, self)?;
        self.pc = next_pc;
        Ok(())
    }

    /// Same as execute(), for a 16-bit RVC instruction.
    pub fn execute_compressed(&mut self, instruction: &CInstruction) -> Result<(), EmuError> {
        let next_pc = rvc::execute(instruction, self)?;
        self.pc = next_pc;
        Ok(())
    }

    /// One fetch+execute step at the current pc.
    pub fn step(&mut self) -> Result<(), EmuError> {
        match self.fetch()? {
            DecodedInstruction::Full(instr) => self.execute(&instr),
            DecodedInstruction::Compressed(instr) => self.execute_compressed(&instr),
        }
    }

    pub fn illegal_instruction<T>(&self, instr: &Instruction) -> Result<T, EmuError> {
        error(format!(
            "not implemented at this stage: opcode=0x{:02x} word=0x{:08x} @0x{:x}",
            instr.opcode, instr.value, self.pc
        ))
    }

    pub fn illegal_c_instruction<T>(&self, instr: &CInstruction) -> Result<T, EmuError> {
        error(format!(
            "not implemented at this stage: compressed word=0x{:04x} @0x{:x}",
            instr.value, self.pc
        ))
    }
}
