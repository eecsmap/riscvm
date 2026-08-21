//! Corresponds to riscvm/mmu.py: Sv39 page-table translation (RISC-V
//! privileged spec section 4.4).
//!
//! xv6 runs identity-mapped (VA == PA) for almost everything, but places
//! per-process kernel stacks and the trampoline at high virtual addresses
//! that only exist through the page table, so once satp switches on
//! paging those accesses need real translation.
//!
//! There is no privilege-mode exemption from translation here (matching
//! riscvm: M-mode isn't special-cased either), so translation is simply
//! gated on satp's MODE field.

use crate::cpu::Cpu;
use crate::csr;
use crate::error::{error, EmuError};

const MODE_BARE: u64 = 0;
const MODE_SV39: u64 = 8;

const PAGESIZE: u64 = 0x1000;
const PTE_SIZE: u64 = 8;
const LEVELS: i32 = 3;

pub const PTE_V: u64 = 1 << 0;
pub const PTE_R: u64 = 1 << 1;
pub const PTE_W: u64 = 1 << 2;
pub const PTE_X: u64 = 1 << 3;

const PPN_MASK: u64 = (1 << 44) - 1;

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Access {
    R,
    W,
    X,
}

/// Translate a virtual address through Sv39 paging, if satp enables it.
/// Returns va unchanged when paging is off (satp.MODE == Bare).
pub fn translate(cpu: &mut Cpu, va: u64, access: Access) -> Result<u64, EmuError> {
    let satp = cpu.csrs.get(&csr::SATP).copied().unwrap_or(0);
    let mode = satp >> 60;
    if mode == MODE_BARE {
        return Ok(va);
    }
    if mode != MODE_SV39 {
        return error(format!("unsupported satp MODE {mode} (only Bare and Sv39 are implemented)"));
    }

    let vpn = [(va >> 12) & 0x1ff, (va >> 21) & 0x1ff, (va >> 30) & 0x1ff];

    let mut a = (satp & PPN_MASK) * PAGESIZE;
    let mut level = LEVELS - 1;
    let mut pte: u64;
    loop {
        if level < 0 {
            return error(format!("page fault: page table walk exhausted translating VA 0x{va:x}"));
        }
        let pte_addr = a + vpn[level as usize] * PTE_SIZE;
        pte = cpu.bus.borrow().read(pte_addr, PTE_SIZE as u8)?; // page table entries live in physical memory: no translation here
        if pte & PTE_V == 0 {
            return error(format!(
                "page fault: invalid PTE translating VA 0x{va:x} (level {level}, pte 0x{pte:x} @0x{pte_addr:x})"
            ));
        }
        if pte & (PTE_R | PTE_X) != 0 {
            break; // leaf
        }
        if pte & PTE_W != 0 {
            return error(format!("page fault: reserved PTE encoding (W without R/X) translating VA 0x{va:x}"));
        }
        a = ((pte >> 10) & PPN_MASK) * PAGESIZE;
        level -= 1;
    }

    let required = match access {
        Access::R => PTE_R,
        Access::W => PTE_W,
        Access::X => PTE_X,
    };
    if pte & required == 0 {
        return error(format!("page fault: permission denied translating VA 0x{va:x} (pte 0x{pte:x})"));
    }

    let mut ppn = (pte >> 10) & PPN_MASK;
    if level > 0 {
        // superpage: the low-order PPN fields must come from the VA, and
        // the PTE's corresponding bits must be zero (a misaligned superpage)
        let low_mask = (1u64 << (9 * level)) - 1;
        if ppn & low_mask != 0 {
            return error(format!("page fault: misaligned superpage translating VA 0x{va:x}"));
        }
        let mut va_low = 0u64;
        for l in 0..level {
            va_low |= vpn[l as usize] << (9 * l);
        }
        ppn = (ppn & !low_mask) | va_low;
    }

    Ok((ppn << 12) | (va & 0xfff))
}
