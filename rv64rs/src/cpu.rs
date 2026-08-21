//! Corresponds to riscvm/cpu.py: owns the register file, pc, and bus, and
//! drives fetch/execute. Interrupt/CLINT/UART polling, RVC dispatch, and
//! MMU translation are later-stage additions (see cpu.py's fetch() for the
//! full version this will grow into); this stage's fetch is deliberately
//! the plain 4-byte-word case only.

use crate::bus::Bus;
use crate::decode::Instruction;
use crate::error::{error, EmuError};
use crate::execute;
use crate::register::Registers;

pub struct Cpu {
    pub regs: Registers,
    pub pc: u64,
    pub bus: Bus,
}

impl Cpu {
    pub fn new(bus: Bus) -> Self {
        Cpu { regs: Registers::new(), pc: 0, bus }
    }

    /// Mirrors CPU.fetch(): read one 32-bit word at pc. (RVC/compressed
    /// dispatch on the low 2 bits is stage 3; unconditionally treating
    /// every word as a full RV64I instruction is correct for this stage's
    /// scope.)
    pub fn fetch(&self) -> Result<Instruction, EmuError> {
        let word = self.bus.read(self.pc, 4)? as u32;
        Ok(Instruction::new(word))
    }

    /// Mirrors CPU.execute(instruction): dispatch and run exactly one
    /// decoded instruction, returning the next pc value (the caller commits
    /// it -- kept explicit here rather than mutating self.pc inside execute,
    /// which makes it trivial to unit-test "does this instruction jump to X"
    /// the same way tests/test_isa.py does).
    pub fn execute(&mut self, instruction: &Instruction) -> Result<(), EmuError> {
        let next_pc = execute::execute(instruction, self)?;
        self.pc = next_pc;
        Ok(())
    }

    /// One fetch+execute step at the current pc.
    pub fn step(&mut self) -> Result<(), EmuError> {
        let instr = self.fetch()?;
        self.execute(&instr)
    }

    pub fn illegal_instruction<T>(&self, instr: &Instruction) -> Result<T, EmuError> {
        error(format!(
            "not implemented at this stage: opcode=0x{:02x} word=0x{:08x} @0x{:x}",
            instr.opcode, instr.value, self.pc
        ))
    }
}
