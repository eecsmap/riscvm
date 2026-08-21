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
//!
//! `Tlb`: not part of riscvm's Python mmu.py (which re-walks every access,
//! with no cache) -- added here after profiling the boot-to-shell
//! benchmark showed translate()+Bus::read together as the dominant
//! remaining cost once the earlier HashMap/linear-scan/memmove overhead
//! was gone (see the perf-P1..P3 commits). Direct-mapped, tagged by VPN,
//! caching the leaf PTE's R/W/X permission bits alongside the resolved
//! PPN so a cache hit can also resolve a permission *fault* without
//! re-walking (the cached bits are the real PTE's permissions, not just
//! "whatever access first missed here"). Flushed on SFENCE.VMA and on any
//! write to satp (see execute.rs's SFENCE.VMA case and trap.rs's
//! csr_write) -- coarse (whole-TLB, not per-address) but correctness-safe,
//! matching how riscvm's own SFENCE_VMA case already documents "no TLB to
//! flush, so a fresh translate() is correct" -- now there is one, so this
//! keeps that same guarantee.

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

const TLB_ENTRIES: usize = 256;

#[derive(Clone, Copy)]
struct TlbEntry {
    valid: bool,
    vpn: u64,
    ppn: u64,
    perm: u64, // the leaf PTE's PTE_R|PTE_W|PTE_X bits
}

pub struct Tlb {
    entries: Box<[TlbEntry; TLB_ENTRIES]>,
}

impl Tlb {
    pub fn new() -> Self {
        Tlb { entries: Box::new([TlbEntry { valid: false, vpn: 0, ppn: 0, perm: 0 }; TLB_ENTRIES]) }
    }

    #[inline(always)]
    fn slot(vpn: u64) -> usize {
        (vpn as usize) % TLB_ENTRIES
    }

    #[inline(always)]
    fn lookup(&self, vpn: u64) -> Option<(u64, u64)> {
        let e = &self.entries[Self::slot(vpn)];
        if e.valid && e.vpn == vpn {
            Some((e.ppn, e.perm))
        } else {
            None
        }
    }

    #[inline(always)]
    fn insert(&mut self, vpn: u64, ppn: u64, perm: u64) {
        self.entries[Self::slot(vpn)] = TlbEntry { valid: true, vpn, ppn, perm };
    }

    /// SFENCE.VMA / any satp write: whole-TLB invalidation. Coarse but
    /// simple and always correct -- xv6 (like any real OS) already issues
    /// SFENCE.VMA whenever it needs precise invalidation; nothing here
    /// relies on finer granularity.
    pub fn flush(&mut self) {
        for e in self.entries.iter_mut() {
            e.valid = false;
        }
    }
}

impl Default for Tlb {
    fn default() -> Self {
        Self::new()
    }
}

/// Translate a virtual address through Sv39 paging, if satp enables it.
/// Returns va unchanged when paging is off (satp.MODE == Bare) -- Bare
/// mode never consults the TLB at all, matching how it never did a walk
/// either (see the perf-P3 commit's measurement: ~46-97.5% of a typical
/// boot runs in Bare mode, so this early return is still the hottest path
/// overall).
///
/// `#[inline(always)]` + the Bare check split out from the TLB-lookup/walk
/// body below (`translate_paged`, left un-inlined -- it's a big function
/// with a loop, and forcing it inline as well would bloat every call site
/// for the ~2.5% of calls that ever reach it): profiling the boot-to-shell
/// benchmark after P6-P8 showed `translate` as a real, non-inlined cost by
/// itself (it's called from `fetch`/`read`/`write`, all of which *are*
/// inlined into `Cpu::step` -- see cpu.rs -- so `translate` was the one
/// remaining function-call boundary on the hottest path in the whole
/// crate). Splitting it this way lets the Bare-mode fast path -- taken by
/// the overwhelming majority of calls on a typical boot -- get inlined
/// directly into its callers with no call/return overhead at all, while
/// the rarely-taken walk still lives in one place instead of being
/// duplicated at every inlined call site.
#[inline(always)]
pub fn translate(cpu: &mut Cpu, va: u64, access: Access) -> Result<u64, EmuError> {
    let satp = cpu.csrs.get(csr::SATP);
    if satp >> 60 == MODE_BARE {
        return Ok(va);
    }
    translate_paged(cpu, va, access, satp)
}

fn translate_paged(cpu: &mut Cpu, va: u64, access: Access, satp: u64) -> Result<u64, EmuError> {
    let mode = satp >> 60;
    if mode != MODE_SV39 {
        return error(format!("unsupported satp MODE {mode} (only Bare and Sv39 are implemented)"));
    }

    let vpn_full = va >> 12;
    let required = match access {
        Access::R => PTE_R,
        Access::W => PTE_W,
        Access::X => PTE_X,
    };
    if let Some((ppn, perm)) = cpu.tlb.lookup(vpn_full) {
        if perm & required == 0 {
            return error(format!("page fault: permission denied translating VA 0x{va:x} (cached pte perm 0x{perm:x})"));
        }
        return Ok((ppn << 12) | (va & 0xfff));
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
        pte = cpu.bus.read(pte_addr, PTE_SIZE as u8)?; // page table entries live in physical memory: no translation here
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

    // Cache at 4KB granularity regardless of the leaf's actual page size
    // (a superpage's constituent 4KB VPNs each get their own entry on
    // first access) -- simple and always correct, and every leaf PTE's
    // permission bits, so a future access with *different* required
    // permissions on this same page is still a correct cache hit.
    cpu.tlb.insert(vpn_full, ppn, pte & (PTE_R | PTE_W | PTE_X));

    Ok((ppn << 12) | (va & 0xfff))
}
