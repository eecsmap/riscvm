//! Corresponds to riscvm/register.py.
//!
//! Python models each register as its own `Register` object (with a
//! `FixedRegister` subclass for x0 that ignores writes). In Rust a plain
//! [u64; 32] array with a guarded write is the idiomatic equivalent -- same
//! semantics (x0 always reads 0), no per-register object needed.

#[derive(Debug, Clone)]
pub struct Registers {
    regs: [u64; 32],
}

impl Registers {
    pub fn new() -> Self {
        Registers { regs: [0; 32] }
    }

    #[inline(always)]
    pub fn read(&self, index: usize) -> u64 {
        self.regs[index]
    }

    /// Mirrors FixedRegister: writes to x0 are silently ignored.
    #[inline(always)]
    pub fn write(&mut self, index: usize, value: u64) {
        if index != 0 {
            self.regs[index] = value;
        }
    }
}

impl Default for Registers {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn x0_is_hardwired_to_zero() {
        let mut r = Registers::new();
        r.write(0, 42);
        assert_eq!(r.read(0), 0);
    }

    #[test]
    fn other_registers_are_read_write() {
        let mut r = Registers::new();
        r.write(5, 0xdead_beef);
        assert_eq!(r.read(5), 0xdead_beef);
    }
}
