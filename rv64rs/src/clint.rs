//! Corresponds to riscvm/clint.py's core state (mtime/mtimecmp + tick() +
//! pending()) -- pulled forward from stage 5 because trap.rs's
//! check_interrupt() genuinely needs a tickable CLINT to test the timer
//! interrupt path (see tests/test_trap.py's test_clint_* cases, which
//! construct a bare `CLINT(size)` and never put it on a Bus either).
//!
//! The Device/MMIO half (read/write of MTIME/MTIMECMP registers, wiring
//! onto the bus) is still stage 5's job, once there's a real boot loop
//! that needs to observe/program the timer from guest code.

const NHART: usize = 1;

pub struct Clint {
    pub mtime: u64,
    pub mtimecmp: [u64; NHART],
}

impl Clint {
    pub fn new() -> Self {
        Clint { mtime: 0, mtimecmp: [u64::MAX; NHART] } // start effectively "never"
    }

    pub fn tick(&mut self) {
        self.mtime = self.mtime.wrapping_add(1);
    }

    pub fn pending(&self) -> bool {
        self.mtime >= self.mtimecmp[0]
    }
}

impl Default for Clint {
    fn default() -> Self {
        Self::new()
    }
}
