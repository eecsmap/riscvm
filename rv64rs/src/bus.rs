//! Corresponds to riscvm/bus.py + riscvm/rangemanager.py.
//!
//! `Device` is the uniform interface every MMIO-mapped thing implements
//! (RAM today; UART/CLINT/PLIC/VirtIOBlk in later stages), matching how
//! bus.py treats every device identically via read(addr,size)/write(...).
//! `RangeManager` mirrors rangemanager.py's sorted-range lookup (bisect on
//! start addresses) so overlapping/unmapped-range errors match the Python
//! behavior exactly.

use crate::clint::Clint;
use crate::error::{error, EmuError};
use crate::plic::Plic;
use crate::ram::Ram;
use crate::uart::Uart;
use crate::virtio::VirtIOBlk;
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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Range {
    pub start: u64,
    pub size: u64,
}

impl Range {
    /// The sentinel every unpopulated slot starts as (size 0): since every
    /// real access has size >= 1, `contains()` below can never match it, so
    /// dispatch can unconditionally check e.g. `virtio_range.contains(...)`
    /// even when Bus has no VirtIOBlk at all (the generic Emulator/fib/
    /// stack-demo path) without needing an Option<Range> at every call site.
    const NONE: Range = Range { start: 0, size: 0 };

    fn contains(&self, address: u64, size: u64) -> bool {
        match address.checked_add(size) {
            Some(end) => address >= self.start && end <= self.start + self.size,
            None => false,
        }
    }
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

/// Concrete owned fields instead of a generic device list (P6 -- see git
/// history -- was `Vec<RefCell<DeviceImpl>>`, an enum-dispatched version of
/// the original `Vec<RefCell<Box<dyn Device>>>`). Modeled directly after
/// d0iasm/rvemu-for-book's `Bus`, which this crate was profiled against
/// (see rv64rs/README.md's "Performance optimization" section): that
/// project stores every device as a plain struct field and dispatches with
/// a sequential range if-chain, no trait object, no RefCell, no binary
/// search at all. P6 measured only a ~3-4% wall-clock gain from removing
/// just the vtable call (`Box<dyn Device>` -> enum) while keeping
/// per-device RefCells and RangeManager's binary search -- this step (P7)
/// tries the bigger swing: `ram`/`stack`/`bootloader` (the hot path -- hit
/// on literally every instruction fetch, most loads/stores, and every PTE
/// step of a page-table walk) become plain owned fields with no RefCell at
/// all, dispatched via a first-checked if-chain instead of a binary search.
///
/// This is a real architectural departure from riscvm's generic bus.py +
/// rangemanager.py (which this crate mirrored 1:1 through P6) -- Bus is no
/// longer generic over "any Device"; it hardcodes exactly the device set
/// Xv6Emulator/Emulator ever actually build. See the P7 commit message for
/// the measured result and the tradeoff this implies.
///
/// CLINT/UART/PLIC stay `Option<Rc<RefCell<_>>>`: Cpu also holds its own
/// clone of each (see cpu.rs's doc comment on cpu.clint/uart/plic) so the
/// same instance can tick()/poll_input()/claimable() from Cpu *and* answer
/// guest MMIO reads/writes from Bus -- that sharing still needs a RefCell.
/// They're also far off the hot path (touched only by explicit MMIO
/// instructions and once per UART_POLL_INTERVAL), so the RefCell check
/// there costs comparatively little.
///
/// VirtIOBlk no longer holds its own `Rc<RefCell<Bus>>` back-reference (see
/// virtio.rs's doc comment): its DMA access to guest RAM is now a `&mut
/// Bus` parameter threaded through from the QUEUE_NOTIFY dispatch below,
/// exactly like rvemu's `disk_access(cpu: &mut Cpu)` touching
/// `cpu.bus.dram`/`cpu.bus.virtio` as disjoint fields of the same struct --
/// not a reentrant call back through the shared Rc<RefCell<Bus>>, which
/// would now panic (`Bus::write` takes `&mut self`, so the outer dispatch
/// already holds an exclusive borrow of that RefCell<Bus> for the whole
/// call).
pub struct Bus {
    range_manager: RangeManager, // add-time overlap/bounds validation only; read()/write() no longer consult it
    ram: Ram,
    ram_range: Range,
    stack: Ram,
    stack_range: Range,
    bootloader: Ram,
    bootloader_range: Range,
    clint: Option<Rc<RefCell<Clint>>>,
    clint_range: Range,
    uart: Option<Rc<RefCell<Uart>>>,
    uart_range: Range,
    plic: Option<Rc<RefCell<Plic>>>,
    plic_range: Range,
    virtio: Option<Rc<RefCell<VirtIOBlk>>>,
    virtio_range: Range,
}

impl Bus {
    pub fn new() -> Self {
        Bus {
            range_manager: RangeManager::new(),
            ram: Ram::new(0),
            ram_range: Range::NONE,
            stack: Ram::new(0),
            stack_range: Range::NONE,
            bootloader: Ram::new(0),
            bootloader_range: Range::NONE,
            clint: None,
            clint_range: Range::NONE,
            uart: None,
            uart_range: Range::NONE,
            plic: None,
            plic_range: Range::NONE,
            virtio: None,
            virtio_range: Range::NONE,
        }
    }

    /// Validates (start, size) the same way RangeManager::add_range always
    /// has (overflow/zero-size/overlap-with-a-neighbor checks, same error
    /// messages) -- the return value's index isn't needed any more (each
    /// setter below already knows exactly which field it's populating), so
    /// this only exists for the validation side effect.
    fn reserve(&mut self, start: u64, size: u64) -> Result<Range, EmuError> {
        let range = Range { start, size };
        self.range_manager.add_range(range)?;
        Ok(range)
    }

    pub fn set_ram(&mut self, ram: Ram, start: u64) -> Result<(), EmuError> {
        self.ram_range = self.reserve(start, ram.len())?;
        self.ram = ram;
        Ok(())
    }

    pub fn set_stack(&mut self, stack: Ram, start: u64) -> Result<(), EmuError> {
        self.stack_range = self.reserve(start, stack.len())?;
        self.stack = stack;
        Ok(())
    }

    pub fn set_bootloader(&mut self, bootloader: Ram, start: u64) -> Result<(), EmuError> {
        self.bootloader_range = self.reserve(start, bootloader.len())?;
        self.bootloader = bootloader;
        Ok(())
    }

    pub fn set_clint(&mut self, clint: Rc<RefCell<Clint>>, start: u64) -> Result<(), EmuError> {
        let size = clint.borrow().len();
        self.clint_range = self.reserve(start, size)?;
        self.clint = Some(clint);
        Ok(())
    }

    pub fn set_uart(&mut self, uart: Rc<RefCell<Uart>>, start: u64) -> Result<(), EmuError> {
        let size = uart.borrow().len();
        self.uart_range = self.reserve(start, size)?;
        self.uart = Some(uart);
        Ok(())
    }

    pub fn set_plic(&mut self, plic: Rc<RefCell<Plic>>, start: u64) -> Result<(), EmuError> {
        let size = plic.borrow().len();
        self.plic_range = self.reserve(start, size)?;
        self.plic = Some(plic);
        Ok(())
    }

    pub fn set_virtio(&mut self, virtio: Rc<RefCell<VirtIOBlk>>, start: u64) -> Result<(), EmuError> {
        let size = virtio.borrow().len();
        self.virtio_range = self.reserve(start, size)?;
        self.virtio = Some(virtio);
        Ok(())
    }

    /// `ram` and `stack` are checked inline, before ever making a call:
    /// together they cover the overwhelming majority of Bus accesses
    /// (every instruction fetch targets `ram`, and most loads/stores during
    /// a typical boot target `stack` -- see P9's commit message for why
    /// `kinit()`'s 128MB zero-fill alone is 97.5% of a full boot). Profiling
    /// after P9 (which did this same inlined-fast-path/cold-slow-path split
    /// for mmu::translate) showed `Bus::read`/`write` themselves as the next
    /// largest non-inlined cost on the hot path for the same reason
    /// translate() was: fetch/read/write in cpu.rs are all inlined into
    /// Cpu::step, so every un-inlined function they call is a real call/
    /// return boundary paid on every single instruction. `read_mmio`/
    /// `write_mmio` hold the bootloader/CLINT/UART/PLIC/VirtIO cases,
    /// reached rarely enough that leaving them as real function calls costs
    /// nothing worth inlining for.
    #[inline(always)]
    pub fn read(&mut self, address: u64, size: u8) -> Result<u64, EmuError> {
        let sz = size as u64;
        if self.ram_range.contains(address, sz) {
            return self.ram.read(address - self.ram_range.start, size);
        }
        if self.stack_range.contains(address, sz) {
            return self.stack.read(address - self.stack_range.start, size);
        }
        self.read_mmio(address, size, sz)
    }

    fn read_mmio(&mut self, address: u64, size: u8, sz: u64) -> Result<u64, EmuError> {
        if self.bootloader_range.contains(address, sz) {
            return self.bootloader.read(address - self.bootloader_range.start, size);
        }
        if self.clint_range.contains(address, sz) {
            return self.clint.as_ref().unwrap().borrow_mut().read(address - self.clint_range.start, size);
        }
        if self.uart_range.contains(address, sz) {
            return self.uart.as_ref().unwrap().borrow_mut().read(address - self.uart_range.start, size);
        }
        if self.plic_range.contains(address, sz) {
            return self.plic.as_ref().unwrap().borrow_mut().read(address - self.plic_range.start, size);
        }
        if self.virtio_range.contains(address, sz) {
            return self.virtio.as_ref().unwrap().borrow_mut().read(address - self.virtio_range.start, size);
        }
        error("no device mapped to this address range")
    }

    #[inline(always)]
    pub fn write(&mut self, address: u64, size: u8, value: u64) -> Result<(), EmuError> {
        let sz = size as u64;
        if self.ram_range.contains(address, sz) {
            return self.ram.write(address - self.ram_range.start, size, value);
        }
        if self.stack_range.contains(address, sz) {
            return self.stack.write(address - self.stack_range.start, size, value);
        }
        self.write_mmio(address, size, value, sz)
    }

    fn write_mmio(&mut self, address: u64, size: u8, value: u64, sz: u64) -> Result<(), EmuError> {
        if self.bootloader_range.contains(address, sz) {
            return self.bootloader.write(address - self.bootloader_range.start, size, value);
        }
        if self.clint_range.contains(address, sz) {
            return self.clint.as_ref().unwrap().borrow_mut().write(address - self.clint_range.start, size, value);
        }
        if self.uart_range.contains(address, sz) {
            return self.uart.as_ref().unwrap().borrow_mut().write(address - self.uart_range.start, size, value);
        }
        if self.plic_range.contains(address, sz) {
            return self.plic.as_ref().unwrap().borrow_mut().write(address - self.plic_range.start, size, value);
        }
        if self.virtio_range.contains(address, sz) {
            // VirtIOBlk's write can trigger a QUEUE_NOTIFY -> process_queue
            // DMA into guest RAM. Clone the Rc (cheap, just a refcount
            // bump) *before* borrowing it, so the borrow_mut() below is on
            // an independent handle -- that leaves `self` free to be
            // reborrowed mutably and passed in as the `bus: &mut Bus`
            // DMA accessor, instead of re-entering through the shared
            // Rc<RefCell<Bus>> the way VirtIOBlk used to (see this
            // struct's doc comment).
            let virtio = self.virtio.clone().unwrap();
            let offset = address - self.virtio_range.start;
            return virtio.borrow_mut().write(offset, size, value, self);
        }
        error("no device mapped to this address range")
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
        let mut bus = Bus::new();
        assert!(bus.read(0, 4).is_err());
    }
}
