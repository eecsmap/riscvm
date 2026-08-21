//! Corresponds to riscvm/bus.py + riscvm/rangemanager.py.
//!
//! `Device` is the uniform interface every MMIO-mapped thing implements
//! (RAM today; UART/CLINT/PLIC/VirtIOBlk in later stages), matching how
//! bus.py treats every device identically via read(addr,size)/write(...).
//! `RangeManager` mirrors rangemanager.py's sorted-range lookup (bisect on
//! start addresses) so overlapping/unmapped-range errors match the Python
//! behavior exactly.

use crate::error::{error, EmuError};
use std::cell::RefCell;
use std::rc::Rc;

pub trait Device {
    fn len(&self) -> u64;
    fn is_empty(&self) -> bool {
        self.len() == 0
    }
    /// Takes &mut self (not &self, despite "read"): real device registers
    /// can have read side effects -- UART's RBR consumes a byte from the
    /// queue, PLIC's claim register consumes a pending interrupt. Matches
    /// the real hardware semantics riscvm's Python read() methods already
    /// rely on (Python doesn't distinguish const-ness at all).
    fn read(&mut self, address: u64, size: u8) -> Result<u64, EmuError>;
    fn write(&mut self, address: u64, size: u8, value: u64) -> Result<(), EmuError>;
}

/// Wraps a device that Cpu also needs direct access to (CLINT for tick(),
/// UART for poll_input()/interrupt_status(), PLIC for claimable()) so the
/// same instance can sit on the Bus *and* be held by Cpu -- matching how
/// riscvm's XV6.__init__ does `self.cpu.uart = uart` after also putting
/// `uart` on the bus (the same Python object, shared by reference; Rc<RefCell<_>>
/// is the Rust equivalent of that sharing).
pub struct SharedDevice<T: Device>(pub Rc<RefCell<T>>);

impl<T: Device> Device for SharedDevice<T> {
    fn len(&self) -> u64 {
        self.0.borrow().len()
    }
    fn read(&mut self, address: u64, size: u8) -> Result<u64, EmuError> {
        self.0.borrow_mut().read(address, size)
    }
    fn write(&mut self, address: u64, size: u8, value: u64) -> Result<(), EmuError> {
        self.0.borrow_mut().write(address, size, value)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Range {
    pub start: u64,
    pub size: u64,
}

pub struct RangeManager {
    starts: Vec<u64>,
    sizes: Vec<u64>,
}

impl RangeManager {
    pub fn new() -> Self {
        RangeManager { starts: Vec::new(), sizes: Vec::new() }
    }

    /// Mirrors RangeManger.add_range: insert keeping `starts` sorted, erroring
    /// on overflow or overlap with a neighboring range. Returns the index the
    /// range landed at, so Bus::add_device can insert its device at the same
    /// position in its own parallel Vec (see Bus's doc comment: this is what
    /// lets get_range() hand back a ready-to-use device index instead of a
    /// Range that then has to be linearly re-matched against every device).
    pub fn add_range(&mut self, range: Range) -> Result<usize, EmuError> {
        if range.size == 0 {
            return error(format!("invalid range ({}, {})", range.start, range.size));
        }
        if range.start.checked_add(range.size).is_none() {
            return error(format!("overflow range ({}, {})", range.start, range.size));
        }

        let position = self.starts.partition_point(|&s| s < range.start);

        if position == self.starts.len() {
            if position > 0 {
                let prev_end = self.starts[position - 1] + self.sizes[position - 1];
                if prev_end > range.start {
                    return error(format!("range ({}, {}) cannot fit in {}", range.start, range.size, self.describe()));
                }
            }
            self.starts.push(range.start);
            self.sizes.push(range.size);
            return Ok(position);
        }

        if self.starts[position] == range.start {
            return error(format!("range ({}, {}) cannot fit in {}", range.start, range.size, self.describe()));
        }
        if range.start + range.size > self.starts[position] {
            return error(format!("range ({}, {}) cannot fit in {}", range.start, range.size, self.describe()));
        }

        self.starts.insert(position, range.start);
        self.sizes.insert(position, range.size);
        Ok(position)
    }

    /// Mirrors RangeManger.get_range: find the range covering
    /// [address, address+size), returning its index (into the same
    /// position add_range returned) plus its (start,size) for computing
    /// the device-local offset.
    pub fn get_range(&self, address: u64, size: u64) -> Result<(usize, Range), EmuError> {
        if size == 0 {
            return error(format!("invalid range ({address}, {size})"));
        }
        if address.checked_add(size).is_none() {
            return error(format!("overflow range ({address}, {size})"));
        }

        let position = self.starts.partition_point(|&s| s <= address);
        if position == 0 {
            return error("no device mapped to this address range");
        }
        let idx = position - 1;
        let (target_start, target_size) = (self.starts[idx], self.sizes[idx]);
        if address + size <= target_start + target_size {
            Ok((idx, Range { start: target_start, size: target_size }))
        } else {
            error(format!(
                "no device mapped to cover (0x{:x}, 0x{:x})",
                address,
                address + size
            ))
        }
    }

    fn describe(&self) -> String {
        self.starts
            .iter()
            .zip(self.sizes.iter())
            .map(|(s, sz)| format!("[{:x} - {:x})", s, s + sz))
            .collect()
    }
}

impl Default for RangeManager {
    fn default() -> Self {
        Self::new()
    }
}

/// Each slot gets its own RefCell (rather than one RefCell around the whole
/// Bus) so that read()/write() only need `&self`: a device like VirtIOBlk
/// that re-enters the bus mid-dispatch (to read/write guest RAM while
/// processing a queue notification) borrows a *different* slot's RefCell
/// than the one currently held for its own dispatch, so it doesn't
/// conflict. One shared RefCell<Bus> would panic here (a device can't
/// re-borrow the very RefCell that's already exclusively borrowed to call
/// it) -- this bit us during stage 7's VirtIOBlk before add_device().
///
/// `devices` is a parallel Vec to `range_manager`'s internal sorted arrays
/// (same index space -- add_range()/get_range() hand back exactly that
/// index), so read()/write() go straight from "binary search" to "direct
/// indexed device access" with no linear re-scan comparing Range structs
/// afterward. Profiling showed that linear scan (via PartialEq on Range)
/// costing real time on every single guest memory access.
pub struct Bus {
    range_manager: RangeManager,
    devices: Vec<RefCell<Box<dyn Device>>>,
}

impl Bus {
    pub fn new() -> Self {
        Bus { range_manager: RangeManager::new(), devices: Vec::new() }
    }

    pub fn add_device(&mut self, device: Box<dyn Device>, start: u64) -> Result<(), EmuError> {
        let range = Range { start, size: device.len() };
        let idx = self.range_manager.add_range(range)?;
        self.devices.insert(idx, RefCell::new(device));
        Ok(())
    }

    pub fn read(&self, address: u64, size: u8) -> Result<u64, EmuError> {
        let (idx, range) = self.range_manager.get_range(address, size as u64)?;
        self.devices[idx].borrow_mut().read(address - range.start, size)
    }

    pub fn write(&self, address: u64, size: u8, value: u64) -> Result<(), EmuError> {
        let (idx, range) = self.range_manager.get_range(address, size as u64)?;
        self.devices[idx].borrow_mut().write(address - range.start, size, value)
    }
}

impl Default for Bus {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Mirrors tests/test_bus.py::test_invalid_address
    #[test]
    fn test_invalid_address() {
        let bus = Bus::new();
        assert!(bus.read(0, 4).is_err());
    }
}
