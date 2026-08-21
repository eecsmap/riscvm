//! Corresponds to riscvm/plic.py: a minimal SiFive-style PLIC (priority
//! registers, per-context enable bits, a per-context priority threshold,
//! claim/complete), matching the subset qemu's riscv-virt machine exposes
//! and xv6-riscv's kernel/plic.c drives.
//!
//! A device's interrupt line is modeled as "pending whenever its own
//! interrupt_status() has bit 0 set" (level-triggered) rather than
//! tracking a separate pending bit here -- so completing an interrupt is a
//! no-op: the line drops on its own once the driver acks the device
//! directly (e.g. UART reading RBR), exactly mirroring real hardware where
//! completion re-arms the PLIC rather than clearing the source.

use crate::bus::Device;
use crate::error::{error, EmuError};

const PRIORITY_BASE: u64 = 0x0;
const PRIORITY_END: u64 = 0x1000;
const ENABLE_BASE: u64 = 0x2000;
const ENABLE_END: u64 = 0x1f2000;
const ENABLE_STRIDE: u64 = 0x80;
const CONTEXT_BASE: u64 = 0x200000;
const CONTEXT_STRIDE: u64 = 0x1000;
const THRESHOLD_OFFSET: u64 = 0x0;
const CLAIM_OFFSET: u64 = 0x4;

const MAX_IRQ: usize = 32; // this emulator's device set only uses IRQ 1 and 10; one word is plenty

// Real contexts in play here are tiny (context = hart*2 + M/S, and this
// emulator only ever has 1 hart -- context 0 or 1), but the MMIO decode
// above technically allows a much larger range, so this stays generous
// rather than exactly 2. `enable`/`threshold` were HashMap<u64,u32> until
// profiling the boot-to-shell benchmark showed check_interrupt() calling
// Plic::claimable() on *every instruction* (same pattern P1 already fixed
// for CSRs) made SipHash/hashbrown machinery ~9% of sampled time again,
// even after the CSR HashMap was long gone.
const MAX_CONTEXTS: usize = 64;

pub struct Plic {
    size: u64,
    devices_by_irq: Vec<(u32, Box<dyn Fn() -> u32>)>, // irq -> closure reading interrupt_status()
    priority: [u32; MAX_IRQ],
    enable: [u32; MAX_CONTEXTS],
    threshold: [u32; MAX_CONTEXTS],
}

impl Plic {
    pub fn new(size: u64) -> Self {
        Plic {
            size,
            devices_by_irq: Vec::new(),
            priority: [0; MAX_IRQ],
            enable: [0; MAX_CONTEXTS],
            threshold: [0; MAX_CONTEXTS],
        }
    }

    /// Out-of-range contexts read as 0 (same default a HashMap.get().unwrap_or(0)
    /// gave) rather than panicking -- a guest write far out in the enable/
    /// context MMIO windows shouldn't crash the emulator even though no
    /// real guest here ever does that.
    #[inline(always)]
    fn enable_get(&self, context: u64) -> u32 {
        self.enable.get(context as usize).copied().unwrap_or(0)
    }
    #[inline(always)]
    fn enable_set(&mut self, context: u64, value: u32) {
        if let Some(slot) = self.enable.get_mut(context as usize) {
            *slot = value;
        }
    }
    #[inline(always)]
    fn threshold_get(&self, context: u64) -> u32 {
        self.threshold.get(context as usize).copied().unwrap_or(0)
    }
    #[inline(always)]
    fn threshold_set(&mut self, context: u64, value: u32) {
        if let Some(slot) = self.threshold.get_mut(context as usize) {
            *slot = value;
        }
    }

    /// Registers a device's live interrupt-status source for `irq`. Takes
    /// a closure (rather than a trait object tied to a specific device
    /// type) so callers can wire in an `Rc<RefCell<Uart>>` etc. without the
    /// Plic needing to know concrete device types.
    pub fn register_irq(&mut self, irq: u32, status: impl Fn() -> u32 + 'static) {
        self.devices_by_irq.push((irq, Box::new(status)));
    }

    fn pending_mask(&self) -> u32 {
        let mut mask = 0u32;
        for (irq, status) in &self.devices_by_irq {
            if status() & 1 != 0 {
                mask |= 1 << irq;
            }
        }
        mask
    }

    pub fn claimable(&self, context: u64) -> bool {
        self.claim_irq(context) != 0
    }

    fn claim_irq(&self, context: u64) -> u32 {
        let candidates = self.pending_mask() & self.enable_get(context);
        let threshold = self.threshold_get(context);
        let mut best_irq = 0u32;
        let mut best_priority = threshold;
        for irq in 1..MAX_IRQ as u32 {
            if candidates & (1 << irq) != 0 && self.priority[irq as usize] > best_priority {
                best_priority = self.priority[irq as usize];
                best_irq = irq;
            }
        }
        best_irq
    }
}

impl Device for Plic {
    fn len(&self) -> u64 {
        self.size
    }

    fn read(&mut self, address: u64, size: u8) -> Result<u64, EmuError> {
        if size != 4 {
            return error(format!("plic accesses are 4 bytes, got {size}"));
        }
        if (PRIORITY_BASE..PRIORITY_END).contains(&address) {
            let irq = (address / 4) as usize;
            return Ok(if irq < MAX_IRQ { self.priority[irq] as u64 } else { 0 });
        }
        if (ENABLE_BASE..ENABLE_END).contains(&address) {
            let context = (address - ENABLE_BASE) / ENABLE_STRIDE;
            return Ok(self.enable_get(context) as u64);
        }
        if address >= CONTEXT_BASE {
            let context = (address - CONTEXT_BASE) / CONTEXT_STRIDE;
            let offset = (address - CONTEXT_BASE) % CONTEXT_STRIDE;
            if offset == THRESHOLD_OFFSET {
                return Ok(self.threshold_get(context) as u64);
            }
            if offset == CLAIM_OFFSET {
                return Ok(self.claim_irq(context) as u64); // claiming is read-triggered
            }
        }
        Ok(0)
    }

    fn write(&mut self, address: u64, size: u8, value: u64) -> Result<(), EmuError> {
        if size != 4 {
            return error(format!("plic accesses are 4 bytes, got {size}"));
        }
        let value = value as u32;
        if (PRIORITY_BASE..PRIORITY_END).contains(&address) {
            let irq = (address / 4) as usize;
            if irq < MAX_IRQ {
                self.priority[irq] = value;
            }
            return Ok(());
        }
        if (ENABLE_BASE..ENABLE_END).contains(&address) {
            let context = (address - ENABLE_BASE) / ENABLE_STRIDE;
            self.enable_set(context, value);
            return Ok(());
        }
        if address >= CONTEXT_BASE {
            let context = (address - CONTEXT_BASE) / CONTEXT_STRIDE;
            let offset = (address - CONTEXT_BASE) % CONTEXT_STRIDE;
            if offset == THRESHOLD_OFFSET {
                self.threshold_set(context, value);
            }
            // CLAIM_OFFSET write is "complete" -- no-op, see module docstring
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::Cell;
    use std::rc::Rc;

    // Mirrors tests/test_trap.py's two PLIC-only cases.

    #[test]
    fn claim_respects_priority_enable_and_threshold() {
        let status = Rc::new(Cell::new(1u32));
        let mut plic = Plic::new(0x400000);
        let s = status.clone();
        plic.register_irq(1, move || s.get());

        // not enabled yet -> nothing claimable
        assert_eq!(plic.claim_irq(1), 0);

        plic.write(0x2080, 4, 1 << 1).unwrap(); // enable irq 1 for context 1 (S-mode, hart0)
        plic.write(4, 4, 1).unwrap(); // priority[1] = 1 (offset = irq * 4)
        plic.write(0x201000, 4, 0).unwrap(); // threshold[context 1] = 0

        assert!(plic.claimable(1));
        assert_eq!(plic.read(0x201004, 4).unwrap(), 1); // SCLAIM(hart0) returns irq 1

        status.set(0); // device acked -> line drops
        assert!(!plic.claimable(1));
    }

    #[test]
    fn threshold_masks_low_priority() {
        let status = Rc::new(Cell::new(1u32));
        let mut plic = Plic::new(0x400000);
        let s = status.clone();
        plic.register_irq(1, move || s.get());
        plic.write(0x2080, 4, 1 << 1).unwrap();
        plic.write(4, 4, 1).unwrap(); // priority[1] = 1
        plic.write(0x201000, 4, 2).unwrap(); // threshold above the irq's priority
        assert!(!plic.claimable(1));
    }
}
