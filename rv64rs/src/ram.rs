//! Corresponds to riscvm/ram.py: a flat byte array Device, little-endian,
//! sizes restricted to {1,2,4,8} bytes same as the Python version.

use crate::bus::Device;
use crate::error::{error, EmuError};

pub struct Ram {
    pub data: Vec<u8>,
}

impl Ram {
    pub fn new(size: u64) -> Self {
        Ram { data: vec![0u8; size as usize] }
    }

    /// Mirrors create_ram(size, content): pad up to `size` (or the content
    /// length, whichever is larger), then load `content` at offset 0.
    pub fn with_content(size: u64, content: &[u8]) -> Self {
        let len = size.max(content.len() as u64) as usize;
        let mut data = vec![0u8; len];
        data[..content.len()].copy_from_slice(content);
        Ram { data }
    }
}

impl Device for Ram {
    fn len(&self) -> u64 {
        self.data.len() as u64
    }

    // Each arm below slices with a literal length (a..a+2, not a..a+size),
    // so the compiler knows the copy width at compile time and emits a
    // single scalar load/store -- the previous version sliced with the
    // runtime `size` value even inside the 1|2|4|8 match arm, which kept
    // the copy length dynamic as far as the optimizer could tell and
    // compiled to a real memmove() call. Profiling showed that call
    // costing ~5-6% of total sampled time on the boot-to-shell benchmark
    // (every single instruction fetch and most loads/stores go through
    // this function).
    fn read(&mut self, address: u64, size: u8) -> Result<u64, EmuError> {
        let a = address as usize;
        match size {
            1 => Ok(self.data[a] as u64),
            2 => Ok(u16::from_le_bytes(self.data[a..a + 2].try_into().unwrap()) as u64),
            4 => Ok(u32::from_le_bytes(self.data[a..a + 4].try_into().unwrap()) as u64),
            8 => Ok(u64::from_le_bytes(self.data[a..a + 8].try_into().unwrap())),
            _ => error(format!("invalid address size {address}")),
        }
    }

    fn write(&mut self, address: u64, size: u8, value: u64) -> Result<(), EmuError> {
        let a = address as usize;
        match size {
            1 => {
                self.data[a] = value as u8;
                Ok(())
            }
            2 => {
                self.data[a..a + 2].copy_from_slice(&(value as u16).to_le_bytes());
                Ok(())
            }
            4 => {
                self.data[a..a + 4].copy_from_slice(&(value as u32).to_le_bytes());
                Ok(())
            }
            8 => {
                self.data[a..a + 8].copy_from_slice(&value.to_le_bytes());
                Ok(())
            }
            _ => error(format!("invalid address size {address}")),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Mirrors tests/test_mem.py
    #[test]
    fn read_write_roundtrip() {
        let mut ram = Ram::new(0x100);
        ram.write(0x10, 4, 0xdead_beef).unwrap();
        assert_eq!(ram.read(0x10, 4).unwrap(), 0xdead_beef);
    }
}
