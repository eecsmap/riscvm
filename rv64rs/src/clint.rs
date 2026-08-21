//! Corresponds to riscvm/clint.py: mtime/mtimecmp state (tick()/pending(),
//! added in stage 4 because trap.rs's check_interrupt() needs a tickable
//! CLINT to test the timer interrupt path) plus, as of this stage, the
//! Device/MMIO half -- reading/writing MTIME and MTIMECMP from guest code,
//! the same registers xv6's timerinit()/timervec touch.

use crate::bus::Device;
use crate::error::{error, EmuError};

const NHART: usize = 1;
const MTIME_OFFSET: u64 = 0xbff8;
const MTIMECMP_OFFSET: u64 = 0x4000;

pub struct Clint {
    size: u64,
    pub mtime: u64,
    pub mtimecmp: [u64; NHART],
}

impl Clint {
    pub fn new(size: u64) -> Self {
        Clint { size, mtime: 0, mtimecmp: [u64::MAX; NHART] } // start effectively "never"
    }

    pub fn tick(&mut self) {
        self.mtime = self.mtime.wrapping_add(1);
    }

    pub fn pending(&self) -> bool {
        self.mtime >= self.mtimecmp[0]
    }
}

impl Device for Clint {
    fn len(&self) -> u64 {
        self.size
    }

    fn read(&mut self, address: u64, size: u8) -> Result<u64, EmuError> {
        if size != 8 {
            return error(format!("clint reads are 8 bytes, got {size}"));
        }
        if address == MTIME_OFFSET {
            return Ok(self.mtime);
        }
        if (MTIMECMP_OFFSET..MTIMECMP_OFFSET + 8 * NHART as u64).contains(&address) {
            return Ok(self.mtimecmp[((address - MTIMECMP_OFFSET) / 8) as usize]);
        }
        Ok(0)
    }

    fn write(&mut self, address: u64, size: u8, value: u64) -> Result<(), EmuError> {
        if size != 8 {
            return error(format!("clint writes are 8 bytes, got {size}"));
        }
        if address == MTIME_OFFSET {
            self.mtime = value;
        } else if (MTIMECMP_OFFSET..MTIMECMP_OFFSET + 8 * NHART as u64).contains(&address) {
            self.mtimecmp[((address - MTIMECMP_OFFSET) / 8) as usize] = value;
        }
        Ok(())
    }
}
