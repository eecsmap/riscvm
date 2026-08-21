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

    fn read(&mut self, address: u64, size: u8) -> Result<u64, EmuError> {
        match size {
            1 | 2 | 4 | 8 => {
                let a = address as usize;
                let mut buf = [0u8; 8];
                buf[..size as usize].copy_from_slice(&self.data[a..a + size as usize]);
                Ok(u64::from_le_bytes(buf))
            }
            _ => error(format!("invalid address size {address}")),
        }
    }

    fn write(&mut self, address: u64, size: u8, value: u64) -> Result<(), EmuError> {
        match size {
            1 | 2 | 4 | 8 => {
                let a = address as usize;
                let bytes = value.to_le_bytes();
                self.data[a..a + size as usize].copy_from_slice(&bytes[..size as usize]);
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
