//! Corresponds to riscvm/clint.py: mtime/mtimecmp state (tick()/pending(),
//! added in stage 4 because trap.rs's check_interrupt() needs a tickable
//! CLINT to test the timer interrupt path) plus, as of this stage, the
//! Device/MMIO half -- reading/writing MTIME and MTIMECMP from guest code,
//! the same registers xv6's timerinit()/timervec touch.
//!
//! `mtimecmp` is sized by `nhart` (one slot per simulated hart -- see
//! emulator.rs's SMP support and cpu.rs's `hartid` field) rather than a
//! fixed-size array, matching riscvm's own clint.py's `nhart` constructor
//! parameter.

use crate::bus::Device;
use crate::error::{error, EmuError};

const MTIME_OFFSET: u64 = 0xbff8;
const MTIMECMP_OFFSET: u64 = 0x4000;

pub struct Clint {
    size: u64,
    pub mtime: u64,
    pub mtimecmp: Vec<u64>,
}

impl Clint {
    pub fn new(size: u64, nhart: usize) -> Self {
        Clint { size, mtime: 0, mtimecmp: vec![u64::MAX; nhart] } // start effectively "never"
    }

    pub fn tick(&mut self) {
        self.mtime = self.mtime.wrapping_add(1);
    }

    pub fn pending(&self, hart: usize) -> bool {
        self.mtime >= self.mtimecmp[hart]
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
        let mtimecmp_end = MTIMECMP_OFFSET + 8 * self.mtimecmp.len() as u64;
        if (MTIMECMP_OFFSET..mtimecmp_end).contains(&address) {
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
        } else {
            let mtimecmp_end = MTIMECMP_OFFSET + 8 * self.mtimecmp.len() as u64;
            if (MTIMECMP_OFFSET..mtimecmp_end).contains(&address) {
                self.mtimecmp[((address - MTIMECMP_OFFSET) / 8) as usize] = value;
            }
        }
        Ok(())
    }
}
