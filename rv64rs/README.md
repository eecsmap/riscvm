# rv64rs

A staged Rust reimplementation of [`riscvm`](../riscvm) — the Python RISC-V
emulator this repo also contains. Same module layout, same test fixtures,
same correctness oracle (riscvm's own `tests/test_*.py`), built up stage by
stage (ALU → MEM → ISA completion → privilege/trap → MMIO → MMU → disk).
See [PLAN.md](PLAN.md) for the staged plan and the reasoning behind each
stage's scope.

**Status: all 7 core stages done.** It boots a real xv6 kernel with a real
filesystem image all the way to an interactive shell prompt.

## Requirements

- Rust (any recent stable toolchain; developed against 1.97). Install via
  [rustup](https://rustup.rs/) or `brew install rust`.
- No other dependencies — the crate has zero external crates.

## Build

```sh
cd rv64rs
cargo build --release
```

Always use `--release` for anything that actually boots a kernel — debug
builds are roughly 10-15x slower (no optimizations, bounds checks
everywhere) and the difference is the gap between "3 seconds" and "40
seconds" for the boot-to-shell milestone below.

## Run the tests

```sh
cargo test --release
```

70 tests, all ported directly from riscvm's own `tests/test_*.py` (same
instruction words, same CSR values, same expected results — see PLAN.md's
"verification strategy" and each stage's git commit message for exactly
which Python test each Rust test corresponds to). `cargo test` (debug mode)
works too but the two full-kernel-boot integration tests
(`tests/xv6_boot.rs`, `tests/xv6_shell.rs`) take several seconds longer
without `--release`.

```sh
cargo clippy --release --all-targets   # should be clean, 0 warnings
```

## Try it

All paths below are relative to this directory (`rv64rs/`) and assume
you're running from here; the fixtures themselves live in `../tests/`.

### Quick sanity check — fib(80), no memory, no devices

```sh
cargo run --release -- fib
```

```
stopped: no device mapped to this address range
a0 = fib(80) = 23416728348467685 (expected 23416728348467685, match = true)
```

### A program that actually uses the stack (LOAD/STORE)

```sh
cargo run --release -- stack-demo
```

### Boot a bare kernel image and dump registers on exit/error

Useful for the "find the next unimplemented instruction" dev loop described
in PLAN.md's stage 3:

```sh
cargo run --release -- xv6-boot ../tests/kernel64gc_nopageflush.bin
```

Add an address (default `0x80000000`), an instruction limit (default:
unlimited — stops only on error), and a filesystem image path as further
positional args:

```sh
cargo run --release -- xv6-boot <kernel.bin> [address_hex] [instr_limit] [fs_image]
```

### Boot all the way to a shell prompt, with precise timing

This is the real milestone: boots straight through and exits the instant
`$ ` appears in the UART output, printing exactly how long that took
(measured from just before the first instruction executes, so kernel/fs
image loading and device setup aren't counted).

```sh
cargo run --release -- xv6-time-to-shell
```

```
xv6 kernel is booting

init: starting sh
$ 

[reached shell prompt after 19476480 instructions in 2.963s (6574149 instr/s); 8968772 (46.0%) ran with paging off -- a TLB can't help those]
```

Defaults to `../tests/xv6-kernel-fs-small.bin` (2MB `PHYSTOP`) +
`../tests/fs.img`. To try the full-size kernel (real hardware's 128MB
`PHYSTOP` — matches `riscvm`'s own `xv6-kernel-fs.bin`):

```sh
cargo run --release -- xv6-time-to-shell ../tests/xv6-kernel-fs.bin 0x80000000 ../tests/fs.img
```

```
[reached shell prompt after 426917888 instructions in 44.805s (9528443 instr/s); 416408798 (97.5%) ran with paging off -- a TLB can't help those]
```

The "ran with paging off" figure exists because it answered a real question
during development (would a TLB speed this up? — no, see PLAN.md/the git
log: the dominant cost, xv6's `kinit()` zero-filling physical memory, runs
*before* paging is even turned on).

## Measured performance

Same milestone (boot to `$ `), same machine, `cargo run --release`:

| Kernel | Instructions | Wall time | Rate |
|---|---|---|---|
| `xv6-kernel-fs-small.bin` (2MB `PHYSTOP`) | 19,476,480 | 2.96s | 6.57M instr/s |
| `xv6-kernel-fs.bin` (128MB `PHYSTOP`) | 426,917,888 | 44.8s | 9.53M instr/s |

For comparison, the same 2MB-`PHYSTOP` milestone measured on the Python
implementation earlier in this project's development: **~161.6s on CPython**
(~54x slower than this crate) and an estimated **~33s on PyPy** (using
PyPy's own measured sustained throughput on this exact boot workload) — still
roughly 11x slower. The 128MB kernel is documented in `riscvm`'s own
`CHEATSHEET.md` as taking "on the order of *hours*" under pure Python; this
crate does it in under a minute.

## Project structure

Each `src/*.rs` file corresponds to one `riscvm/*.py` file, same name where
possible:

| Rust | Python | What |
|---|---|---|
| `register.rs` | `register.py` | x0-hardwired-to-zero register file |
| `bus.rs` | `bus.py`, `rangemanager.py` | address-range dispatch to devices |
| `ram.rs` | `ram.py` | flat byte-array memory device |
| `decode.rs` | `rv64i.py` (decode) | 32-bit instruction field/immediate extraction |
| `execute.rs` | `rv64i.py` (execute) | RV64I/M + AMOSWAP.W semantics |
| `rvc.rs` | `rv64c.py` | 16-bit compressed instructions |
| `cpu.rs` | `cpu.py` | fetch/execute loop, interrupt sampling |
| `csr.rs`, `trap.rs` | `csr.py`, `trap.py` | privilege levels, CSR aliasing, trap delivery |
| `mmu.rs` | `mmu.py` | Sv39 page-table translation |
| `clint.rs` | `clint.py` | timer (mtime/mtimecmp) |
| `uart.rs` | `uart.py` | 16550 console |
| `plic.rs` | `plic.py` | interrupt controller |
| `virtio.rs` | `virtio.py` | VirtIO MMIO block device |
| `emulator.rs` | `emulator.py` | `Emulator`/`XV6` assembly (RAM+stack; +devices+bootloader) |
| `asm.rs` | `tools/as.py` | tiny hand-assembly helpers (no `riscv64-linux-gnu-gcc` on this machine) |

`Cpu.bus` is `Rc<RefCell<Bus>>` (not an owned `Bus`) because VirtIOBlk needs
to read/write arbitrary guest memory through the same bus it's registered
on — see `cpu.rs`'s doc comment and the stage 7 commit message for why, and
why `Bus` uses a `RefCell` per device slot rather than one around the whole
struct (the latter panics on VirtIOBlk's reentrant access).

## What's not here

Stage 8 (an optional TLB/cache stretch goal, purely for exploring memory-
hierarchy performance) was evaluated and deliberately not built: measurement
showed 46-97.5% of the boot-to-shell workload runs with paging off entirely
(dominated by `kinit()`'s physical-memory zero-fill, which happens before
`kvminithart()` turns paging on), so a TLB wouldn't move the needle on this
milestone. It would need a paging-dominated workload (e.g. running
commands after boot, not one-time memory init) to actually demonstrate a
difference. See the git log for the full measurement.

Also not implemented, matching riscvm's own current scope: floating-point
(F/D extensions), most AMO variants beyond AMOSWAP.W, EBREAK, and real
interactive UART input (the emulator can print output over UART, but
`--uart-input` isn't wired up to this crate's CLI the way it is in riscvm's
Python `emulator.py`).
