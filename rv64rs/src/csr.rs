//! Corresponds to riscvm/csr.py: CSR addresses and privilege levels.
//! Plain u32/u8 constants rather than a Rust enum, matching how loosely
//! Python treats these (cpu.mode is just an int; cpu.csrs is a plain
//! dict keyed by these addresses).

pub const PRIV_U: u8 = 0;
pub const PRIV_S: u8 = 1;
pub const PRIV_M: u8 = 3;

pub const SSTATUS: u32 = 0x100;
pub const SIE: u32 = 0x104;
pub const STVEC: u32 = 0x105;
pub const SSCRATCH: u32 = 0x140;
pub const SEPC: u32 = 0x141;
pub const SCAUSE: u32 = 0x142;
pub const STVAL: u32 = 0x143;
pub const SIP: u32 = 0x144;
pub const SATP: u32 = 0x180;
pub const MSTATUS: u32 = 0x300;
pub const MEDELEG: u32 = 0x302;
pub const MIDELEG: u32 = 0x303;
pub const MIE: u32 = 0x304;
pub const MTVEC: u32 = 0x305;
pub const MSCRATCH: u32 = 0x340;
pub const MEPC: u32 = 0x341;
pub const MCAUSE: u32 = 0x342;
pub const MTVAL: u32 = 0x343;
pub const MIP: u32 = 0x344;

/// Corresponds to how riscvm's cpu.py stores cpu.csrs -- a plain dict keyed
/// by CSR address, defaulting missing entries to 0 (`.get(addr, 0)`). The
/// real hardware address space is a fixed 12 bits (csr[11:0], see csr.py's
/// own comment), so unlike Python's dict this is a flat, boxed 4096-entry
/// array: O(1) direct indexing, no hashing.
///
/// This replaced a `HashMap<u32, u64>` after profiling showed it dominating
/// the boot-to-shell benchmark: SipHash (Rust's default hasher, built for
/// DoS resistance against untrusted keys) plus hashbrown's table machinery
/// accounted for ~15-17% of total sampled time, entirely from CSR traffic
/// that check_interrupt() alone performs on *every single instruction*
/// (reading MIP, writing it back) regardless of whether anything changed.
pub struct Csrs(Box<[u64; 4096]>);

impl Csrs {
    pub fn new() -> Self {
        Csrs(Box::new([0; 4096]))
    }

    #[inline(always)]
    pub fn get(&self, addr: u32) -> u64 {
        self.0[(addr & 0xfff) as usize]
    }

    #[inline(always)]
    pub fn insert(&mut self, addr: u32, value: u64) {
        self.0[(addr & 0xfff) as usize] = value;
    }
}

impl Default for Csrs {
    fn default() -> Self {
        Self::new()
    }
}

impl std::ops::Index<u32> for Csrs {
    type Output = u64;
    fn index(&self, addr: u32) -> &u64 {
        &self.0[(addr & 0xfff) as usize]
    }
}
