//! Staged Rust reimplementation of riscvm. Module layout mirrors the
//! Python package (riscvm/*.py) file-for-file where practical; see
//! PLAN.md for the staged implementation plan this follows.
//!
//! Stage 0: skeleton only (Register, Bus/RangeManager, RAM). decode/
//! execute/cpu/emulator arrive in stage 1.

pub mod bus;
pub mod error;
pub mod ram;
pub mod register;
