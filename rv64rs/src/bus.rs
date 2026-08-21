//! Corresponds to riscvm/bus.py + riscvm/rangemanager.py.
//!
//! `Device` is the uniform interface every MMIO-mapped thing implements
//! (RAM today; UART/CLINT/PLIC/VirtIOBlk in later stages), matching how
//! bus.py treats every device identically via read(addr,size)/write(...).
//! `RangeManager` mirrors rangemanager.py's sorted-range lookup (bisect on
//! start addresses) so overlapping/unmapped-range errors match the Python
//! behavior exactly.

use crate::error::{error, EmuError};

pub trait Device {
    fn len(&self) -> u64;
    fn is_empty(&self) -> bool {
        self.len() == 0
    }
    fn read(&self, address: u64, size: u8) -> Result<u64, EmuError>;
    fn write(&mut self, address: u64, size: u8, value: u64) -> Result<(), EmuError>;
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
    /// on overflow or overlap with a neighboring range.
    pub fn add_range(&mut self, range: Range) -> Result<(), EmuError> {
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
            return Ok(());
        }

        if self.starts[position] == range.start {
            return error(format!("range ({}, {}) cannot fit in {}", range.start, range.size, self.describe()));
        }
        if range.start + range.size > self.starts[position] {
            return error(format!("range ({}, {}) cannot fit in {}", range.start, range.size, self.describe()));
        }

        self.starts.insert(position, range.start);
        self.sizes.insert(position, range.size);
        Ok(())
    }

    /// Mirrors RangeManger.get_range: find the (start,size) covering
    /// [address, address+size).
    pub fn get_range(&self, address: u64, size: u64) -> Result<Range, EmuError> {
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
            Ok(Range { start: target_start, size: target_size })
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

pub struct Bus {
    range_manager: RangeManager,
    devices: Vec<(Range, Box<dyn Device>)>,
}

impl Bus {
    pub fn new() -> Self {
        Bus { range_manager: RangeManager::new(), devices: Vec::new() }
    }

    pub fn add_device(&mut self, device: Box<dyn Device>, start: u64) -> Result<(), EmuError> {
        let range = Range { start, size: device.len() };
        self.range_manager.add_range(range)?;
        self.devices.push((range, device));
        Ok(())
    }

    fn find_device(&self, range: Range) -> &(Range, Box<dyn Device>) {
        self.devices
            .iter()
            .find(|(r, _)| *r == range)
            .expect("range_manager returned a range with no matching device")
    }

    fn find_device_mut(&mut self, range: Range) -> &mut (Range, Box<dyn Device>) {
        self.devices
            .iter_mut()
            .find(|(r, _)| *r == range)
            .expect("range_manager returned a range with no matching device")
    }

    pub fn read(&self, address: u64, size: u8) -> Result<u64, EmuError> {
        let range = self.range_manager.get_range(address, size as u64)?;
        let (r, device) = self.find_device(range);
        device.read(address - r.start, size)
    }

    pub fn write(&mut self, address: u64, size: u8, value: u64) -> Result<(), EmuError> {
        let range = self.range_manager.get_range(address, size as u64)?;
        let (r, device) = self.find_device_mut(range);
        let start = r.start;
        device.write(address - start, size, value)
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
