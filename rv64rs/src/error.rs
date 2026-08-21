//! Corresponds to riscvm/exception.py: a single error type raised for any
//! "the emulator cannot continue" condition (invalid address, unmapped
//! device, unimplemented instruction, ...). Python raises InternalException;
//! we return Result<_, EmuError> instead, since Rust has no exceptions.

use std::fmt;

#[derive(Debug, Clone)]
pub struct EmuError(pub String);

impl fmt::Display for EmuError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl std::error::Error for EmuError {}

pub fn error<T>(message: impl Into<String>) -> Result<T, EmuError> {
    Err(EmuError(message.into()))
}
