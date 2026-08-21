//! Corresponds to riscvm/cpu.py: owns the register file, pc, and bus, and
//! drives fetch/execute.
//!
//! Stage 3 added RVC dispatch on fetch()'s low 2 bits. Stage 4 added CSR/
//! privilege-level state. Stage 5 (this stage) wires fetch() up the same
//! way cpu.py's real fetch() works: tick the CLINT, periodically poll the
//! UART for input, check for a deliverable interrupt, *then* fetch --
//! matching real hardware's "interrupts are sampled between instructions".
//!
//! cpu.clint/uart/plic are Rc<RefCell<_>> (see bus::SharedDevice) because
//! the same instance also needs to live on the Bus for guest-code MMIO
//! access -- the Rust equivalent of riscvm's XV6.__init__ putting the same
//! Python object on both the bus and cpu.uart/clint/plic.
//!
//! MMU translation (mmu.py's `translate()` wrapping every bus access) is
//! still a later-stage addition (stage 6).

use crate::bus::Bus;
use crate::clint::Clint;
use crate::csr;
use crate::decode::Instruction;
use crate::error::{error, EmuError};
use crate::execute;
use crate::plic::Plic;
use crate::register::Registers;
use crate::rvc::{self, CInstruction};
use crate::trap;
use crate::uart::Uart;
use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;

pub enum DecodedInstruction {
    Full(Instruction),
    Compressed(CInstruction),
}

/// Instructions between uart.poll_input() calls (it's a real read() on the
/// input source; a human typing is plenty responsive checked this often).
/// Same constant/reasoning as cpu.py's UART_POLL_INTERVAL.
const UART_POLL_INTERVAL: i64 = 4096;

pub struct Cpu {
    pub regs: Registers,
    pub pc: u64,
    pub bus: Bus,
    pub csrs: HashMap<u32, u64>,
    pub mode: u8,
    pub clint: Option<Rc<RefCell<Clint>>>,
    pub uart: Option<Rc<RefCell<Uart>>>,
    pub plic: Option<Rc<RefCell<Plic>>>,
    uart_poll_countdown: i64,
}

impl Cpu {
    pub fn new(bus: Bus) -> Self {
        // Matches cpu.py's CPU.__init__: mstatus starts with some bits set
        // (notably MPP=11, i.e. M-mode, per the "hopefully we don't use
        // csrs too frequently" comment there), mie has MSIE|MTIE preset.
        let mut csrs = HashMap::new();
        csrs.insert(csr::MSTATUS, 0x000a_0000_0000);
        csrs.insert(csr::MIE, 0x222);
        Cpu {
            regs: Registers::new(),
            pc: 0,
            bus,
            csrs,
            mode: csr::PRIV_M,
            clint: None,
            uart: None,
            plic: None,
            uart_poll_countdown: 0,
        }
    }

    /// Mirrors CPU.fetch(): tick the CLINT, periodically poll UART input,
    /// check for a deliverable interrupt, then read one instruction word
    /// at pc and dispatch on the low 2 bits between full RV64I (0b11) and
    /// compressed (anything else).
    pub fn fetch(&mut self) -> Result<DecodedInstruction, EmuError> {
        if let Some(clint) = &self.clint {
            clint.borrow_mut().tick();
        }
        if let Some(uart) = &self.uart {
            self.uart_poll_countdown -= 1;
            if self.uart_poll_countdown <= 0 {
                uart.borrow_mut().poll_input();
                self.uart_poll_countdown = UART_POLL_INTERVAL;
            }
        }
        trap::check_interrupt(self);

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
