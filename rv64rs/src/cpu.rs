//! Corresponds to riscvm/cpu.py: owns the register file, pc, and bus, and
//! drives fetch/execute.
//!
//! Stage 3 adds RVC dispatch: fetch() reads 4 bytes (over-reading is fine
//! for a compressed instruction -- only the low 16 bits matter, same as
//! cpu.py's fetch() comment about RVC constructors masking down to their
//! own width) and picks full RV64I vs 16-bit RVC by the low 2 bits, exactly
//! like cpu.py's `match data & 0b11`.
//!
//! Interrupt/CLINT/UART polling and MMU translation are still later-stage
//! additions.

use crate::bus::Bus;
use crate::decode::Instruction;
use crate::error::{error, EmuError};
use crate::execute;
use crate::register::Registers;
use crate::rvc::{self, CInstruction};

pub enum DecodedInstruction {
    Full(Instruction),
    Compressed(CInstruction),
}

pub struct Cpu {
    pub regs: Registers,
    pub pc: u64,
    pub bus: Bus,
}

impl Cpu {
    pub fn new(bus: Bus) -> Self {
        Cpu { regs: Registers::new(), pc: 0, bus }
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
