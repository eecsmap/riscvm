//! Corresponds to the plain `Emulator` class in riscvm/emulator.py (not the
//! `XV6` subclass -- CLINT/UART/PLIC/VirtIO wiring is later stages). Loads
//! a raw program at `address`, plus a 128MB scratch region right after it
//! for stack/bss, exactly like emulator.py's Emulator.__init__.

use crate::bus::{Bus, Device};
use crate::cpu::Cpu;
use crate::error::EmuError;
use crate::ram::Ram;

const STACK_SIZE: u64 = 0x0800_0000; // 128MB, same constant as emulator.py

pub struct Emulator {
    pub cpu: Cpu,
}

impl Emulator {
    pub fn new(program: &[u8], address: u64) -> Result<Self, EmuError> {
        let ram = Ram::with_content(program.len() as u64, program);
        let ram_len = ram.len();
        let stack_begin = ((ram_len + 0xfff) & !0xfff) + address;
        let stack = Ram::new(STACK_SIZE);

        let mut bus = Bus::new();
        bus.add_device(Box::new(ram), address)?;
        bus.add_device(Box::new(stack), stack_begin)?;

        let mut cpu = Cpu::new(bus);
        cpu.pc = address;
        Ok(Emulator { cpu })
    }

    /// Runs fetch/execute until an error (unmapped fetch, unimplemented
    /// opcode, ...) -- mirrors Emulator.run()'s InternalException loop exit,
    /// except we return the error instead of printing+reraising.
    pub fn run(&mut self) -> EmuError {
        loop {
            if let Err(e) = self.cpu.step() {
                return e;
            }
        }
    }
}
