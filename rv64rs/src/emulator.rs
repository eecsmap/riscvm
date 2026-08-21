//! Corresponds to riscvm/emulator.py's `Emulator` and `XV6` classes.
//!
//! `Emulator` loads a raw program at `address` plus a 128MB scratch region
//! right after it for stack/bss -- no devices, matching emulator.py's
//! plain Emulator.__init__.
//!
//! `Xv6Emulator` additionally wires up CLINT, UART, PLIC, and (stage 7,
//! this stage) VirtIOBlk, and starts execution at a tiny bootloader at
//! 0x1000 that jumps into the kernel at `address`, matching XV6.__init__
//! exactly -- same bootloader bytes, same MMIO addresses.

use crate::bus::{Bus, Device};
use crate::clint::Clint;
use crate::cpu::Cpu;
use crate::error::EmuError;
use crate::plic::Plic;
use crate::ram::Ram;
use crate::uart::Uart;
use crate::virtio::VirtIOBlk;
use std::cell::RefCell;
use std::io::{Read, Write};
use std::rc::Rc;

const STACK_SIZE: u64 = 0x0800_0000; // 128MB, same constant as emulator.py

pub struct Emulator {
    pub cpu: Cpu,
}

impl Emulator {
    pub fn new(program: &[u8], address: u64) -> Result<Self, EmuError> {
        let ram = Ram::with_content(program.len() as u64, program);
        let ram_len = ram.len();
        let stack_begin = ((ram_len + 0xfff) & !0xfff) + address;
        let stack = Ram::new(STACK_SIZE);

        let mut bus = Bus::new();
        bus.set_ram(ram, address)?;
        bus.set_stack(stack, stack_begin)?;

        let mut cpu = Cpu::new(Rc::new(RefCell::new(bus)));
        cpu.pc = address;
        Ok(Emulator { cpu })
    }

    /// Runs fetch/execute until an error (unmapped fetch, unimplemented
    /// opcode, ...) -- mirrors Emulator.run()'s InternalException loop exit,
    /// except we return the error instead of printing+reraising.
    pub fn run(&mut self) -> EmuError {
        loop {
            if let Err(e) = self.cpu.step() {
                return e;
            }
        }
    }
}

const CLINT_BASE: u64 = 0x0200_0000;
const CLINT_SIZE: u64 = 0x1_0000;
const UART_BASE: u64 = 0x1000_0000;
const UART_SIZE: u64 = 0x100;
const UART0_IRQ: u32 = 10;
const VIRTIO_DISK_BASE: u64 = 0x1000_1000;
const VIRTIO_DISK_SIZE_DEFAULT: u64 = 8 * 1024 * 1024;
const VIRTIO0_IRQ: u32 = 1;
const PLIC_BASE: u64 = 0x0C00_0000;
const PLIC_SIZE: u64 = 0x0FFF_FFFF - PLIC_BASE + 1;
const BOOTLOADER_ADDR: u64 = 0x1000;
// Same bytes as emulator.py's XV6.__init__: a tiny stub that jumps into
// the kernel image at `address` (encoded into the bytes below).
const BOOTLOADER_HEX: &str = "9702000013868202732540f183b5020283b282016780020000000080000000000000008700000000";

pub struct Xv6Emulator {
    pub cpu: Cpu,
}

impl Xv6Emulator {
    pub fn new(
        program: &[u8],
        address: u64,
        uart_output: Option<Box<dyn Write>>,
        uart_input: Option<Box<dyn Read>>,
        disk_image: Option<Vec<u8>>,
    ) -> Result<Self, EmuError> {
        // pad up to the next page boundary: a raw `objcopy -O binary` image
        // doesn't always include .bss, so the kernel can genuinely read/
        // write just past the loaded bytes before reaching the stack --
        // that gap needs to be real, zeroed RAM.
        let stack_begin = ((program.len() as u64 + 0xfff) & !0xfff) + address;
        let ram = Ram::with_content(stack_begin - address, program);
        let stack = Ram::new(STACK_SIZE);

        let mut bus = Bus::new();
        bus.set_ram(ram, address)?;
        bus.set_stack(stack, stack_begin)?;

        let clint = Rc::new(RefCell::new(Clint::new(CLINT_SIZE)));
        bus.set_clint(clint.clone(), CLINT_BASE)?;

        let uart = Rc::new(RefCell::new(Uart::new(UART_SIZE, uart_output, uart_input)));
        bus.set_uart(uart.clone(), UART_BASE)?;

        // VirtIOBlk no longer needs a Bus handle at construction time (see
        // virtio.rs's doc comment: DMA access is threaded through as a
        // `&mut Bus` parameter at call time now, not held as a
        // reentrant Rc<RefCell<Bus>> back-reference).
        let virtio = Rc::new(RefCell::new(VirtIOBlk::new(VIRTIO_DISK_SIZE_DEFAULT, disk_image)));
        bus.set_virtio(virtio.clone(), VIRTIO_DISK_BASE)?;

        let mut plic = Plic::new(PLIC_SIZE);
        let uart_for_plic = uart.clone();
        plic.register_irq(UART0_IRQ, move || uart_for_plic.borrow().interrupt_status());
        let virtio_for_plic = virtio.clone();
        plic.register_irq(VIRTIO0_IRQ, move || virtio_for_plic.borrow().interrupt_status);
        let plic = Rc::new(RefCell::new(plic));
        bus.set_plic(plic.clone(), PLIC_BASE)?;

        let bootloader_bytes = hex_decode(BOOTLOADER_HEX);
        let bootloader = Ram::with_content(bootloader_bytes.len() as u64, &bootloader_bytes);
        bus.set_bootloader(bootloader, BOOTLOADER_ADDR)?;

        let mut cpu = Cpu::new(Rc::new(RefCell::new(bus)));
        cpu.clint = Some(clint);
        cpu.uart = Some(uart);
        cpu.plic = Some(plic);
        cpu.pc = BOOTLOADER_ADDR;

        Ok(Xv6Emulator { cpu })
    }

    pub fn run(&mut self) -> EmuError {
        loop {
            if let Err(e) = self.cpu.step() {
                return e;
            }
        }
    }
}

fn hex_decode(s: &str) -> Vec<u8> {
    (0..s.len()).step_by(2).map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap()).collect()
}
