//! Corresponds to riscvm/uart.py: a minimal 16550-style UART, just the
//! register subset riscvm itself models (RBR/IER/LCR/LSR/THR/DLL/DLM;
//! IIR/MCR/MSR/SCR always read 0, matching the Python base Register
//! class's default). MCR/SCR writes are silent no-ops and LSR/MSR writes
//! are illegal, exactly matching uart.py's write() match arms (only 0-3
//! are handled; 5/6 are asserted against).

use crate::bus::Device;
use crate::error::{error, EmuError};
use std::collections::VecDeque;
use std::io::{Read, Write};

const LSR_TX_IDLE: u8 = 1 << 5;
const IER_RX_ENABLE: u8 = 1 << 0;
const IER_TX_ENABLE: u8 = 1 << 1;
const LCR_NBITS: u8 = 3;
const LCR_BAUD_LATCH: u8 = 1 << 7;

pub struct Uart {
    size: u64,
    divisor_latch_accessible: bool,
    interrupt_enabled_rx: bool,
    interrupt_enabled_tx: bool,
    line_control_nbits: u8,
    dll_value: u8,
    dlm_value: u8,
    rx_queue: VecDeque<u8>,
    output: Option<Box<dyn Write>>,
    input: Option<Box<dyn Read>>,
}

impl Uart {
    pub fn new(size: u64, output: Option<Box<dyn Write>>, input: Option<Box<dyn Read>>) -> Self {
        Uart {
            size,
            divisor_latch_accessible: false,
            interrupt_enabled_rx: false,
            interrupt_enabled_tx: false,
            line_control_nbits: 0,
            dll_value: 0,
            dlm_value: 0,
            rx_queue: VecDeque::new(),
            output,
            input,
        }
    }

    fn dlab(&self) -> bool {
        self.divisor_latch_accessible
    }

    pub fn data_available(&self) -> bool {
        !self.rx_queue.is_empty()
    }

    /// Level-triggered PLIC line: high whenever unread input is sitting in
    /// RBR and RX interrupts are enabled.
    pub fn interrupt_status(&self) -> u32 {
        (self.data_available() && self.interrupt_enabled_rx) as u32
    }

    /// Feed bytes into the receive queue, as if they'd arrived on the wire.
    pub fn inject(&mut self, data: &[u8]) {
        self.rx_queue.extend(data.iter().copied());
    }

    /// Best-effort, non-blocking(-ish) top-up of rx_queue from the
    /// configured input source. A real interactive stdin needs platform
    /// non-blocking-mode support this stage doesn't add yet (stage 7,
    /// alongside real interactive boot); this works for any `Read` source
    /// that itself doesn't block (e.g. a pre-filled buffer, a pipe with
    /// data ready).
    pub fn poll_input(&mut self) {
        let Some(input) = self.input.as_mut() else { return };
        let mut buf = [0u8; 256];
        if let Ok(n) = input.read(&mut buf) {
            if n > 0 {
                self.rx_queue.extend(buf[..n].iter().copied());
            }
        }
    }

    fn rbr(&mut self) -> u8 {
        self.rx_queue.pop_front().unwrap_or(0)
    }

    fn ier(&self) -> u8 {
        ((self.interrupt_enabled_rx as u8) * IER_RX_ENABLE) | ((self.interrupt_enabled_tx as u8) * IER_TX_ENABLE)
    }

    fn lcr(&self) -> u8 {
        ((self.divisor_latch_accessible as u8) << 7) | self.line_control_nbits
    }

    fn lsr(&self) -> u8 {
        (self.data_available() as u8) | LSR_TX_IDLE
    }
}

impl Device for Uart {
    fn len(&self) -> u64 {
        self.size
    }

    fn read(&mut self, address: u64, size: u8) -> Result<u64, EmuError> {
        if size != 1 {
            return error(format!("uart reads are 1 byte, got {size}"));
        }
        let value = match address {
            // RBR: reading actually consumes the byte, same as real 16550
            // hardware (and riscvm's rbr property, which popleft()s).
            0 => if self.dlab() { self.dll_value } else { self.rbr() },
            1 => if self.dlab() { self.dlm_value } else { self.ier() },
            2 => 0, // IIR
            3 => self.lcr(),
            4 => 0, // MCR
            5 => self.lsr(),
            6 => 0, // MSR
            7 => 0, // SCR
            _ => 0,
        };
        Ok(value as u64)
    }

    fn write(&mut self, address: u64, size: u8, value: u64) -> Result<(), EmuError> {
        if size != 1 {
            return error(format!("uart writes are 1 byte, got {size}"));
        }
        let value = (value & 0xff) as u8;
        match address {
            5 | 6 => return error("uart register illegal write"),
            0 => {
                if self.dlab() {
                    self.dll_value = value;
                } else if let Some(out) = self.output.as_mut() {
                    let _ = out.write_all(&[value]);
                    let _ = out.flush();
                }
            }
            1 => {
                if self.dlab() {
                    self.dlm_value = value;
                } else {
                    if value & !(IER_RX_ENABLE | IER_TX_ENABLE) != 0 {
                        return error("uart IER: unhandled flag bits");
                    }
                    self.interrupt_enabled_rx = value & IER_RX_ENABLE != 0;
                    self.interrupt_enabled_tx = value & IER_TX_ENABLE != 0;
                }
            }
            2 => {} // FCR: accepted, not modeled
            3 => {
                self.divisor_latch_accessible = value & LCR_BAUD_LATCH != 0;
                self.line_control_nbits = value & LCR_NBITS;
            }
            _ => {} // MCR(4)/SCR(7): silent no-op, matching uart.py's write() (no case for them)
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn uart() -> Uart {
        Uart::new(0x100, Some(Box::new(Vec::<u8>::new())), None)
    }

    // Mirrors tests/test_uart.py

    #[test]
    fn no_data_available_by_default() {
        let mut u = uart();
        assert_eq!(u.read(5, 1).unwrap() & 0x1, 0);
        assert_eq!(u.interrupt_status(), 0);
    }

    #[test]
    fn inject_makes_data_available_and_readable() {
        let mut u = uart();
        u.inject(b"ls\n");
        assert_eq!(u.read(5, 1).unwrap() & 0x1, 1);
        assert_eq!(u.read(0, 1).unwrap(), b'l' as u64);
        assert_eq!(u.read(0, 1).unwrap(), b's' as u64);
        assert_eq!(u.read(0, 1).unwrap(), b'\n' as u64);
        // queue drained: LSR data-ready bit drops back to 0
        assert_eq!(u.read(5, 1).unwrap() & 0x1, 0);
    }

    #[test]
    fn rbr_read_without_data_returns_zero_not_garbage() {
        let mut u = uart();
        assert_eq!(u.read(0, 1).unwrap(), 0);
    }

    #[test]
    fn ier_bit_test_is_and_not_or() {
        let mut u = uart();
        u.write(1, 1, 0x3).unwrap(); // enable both RX and TX interrupt sources
        assert!(u.interrupt_enabled_rx);
        u.write(1, 1, 0x0).unwrap(); // disable everything
        assert!(!u.interrupt_enabled_rx);
    }

    #[test]
    fn interrupt_status_requires_both_data_and_enable() {
        let mut u = uart();
        u.inject(b"x");
        assert_eq!(u.interrupt_status(), 0); // RX interrupts not enabled yet
        u.write(1, 1, 0x1).unwrap(); // enable RX interrupt
        assert_eq!(u.interrupt_status(), 1);
        u.read(0, 1).unwrap(); // drain the byte
        assert_eq!(u.interrupt_status(), 0);
    }

    #[test]
    fn poll_input_from_a_plain_stream() {
        let source: Box<dyn Read> = Box::new(std::io::Cursor::new(b"ls\n".to_vec()));
        let mut u = Uart::new(0x100, None, Some(source));
        u.poll_input();
        assert_eq!(u.rx_queue, VecDeque::from(vec![b'l', b's', b'\n']));
    }
}
