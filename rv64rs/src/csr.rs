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
