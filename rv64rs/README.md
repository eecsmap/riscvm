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
cargo run --release -- xv6-boot <kernel.bin> [address_hex] [fs_image] [instr_limit]
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

[reached shell prompt after 19476480 instructions in 0.771s (25269984 instr/s); 8968772 (46.0%) ran with paging off -- a TLB can't help those]
```

Defaults to `../tests/xv6-kernel-fs-small.bin` (2MB `PHYSTOP`) +
`../tests/fs.img`. To try the full-size kernel (real hardware's 128MB
`PHYSTOP` — matches `riscvm`'s own `xv6-kernel-fs.bin`):

```sh
cargo run --release -- xv6-time-to-shell ../tests/xv6-kernel-fs.bin 0x80000000 ../tests/fs.img
```

```
[reached shell prompt after 426917888 instructions in 14.828s (28790739 instr/s); 416408798 (97.5%) ran with paging off -- a TLB can't help those]
```

The "ran with paging off" figure exists because it answered a real question
during development: xv6's `kinit()` zero-fills physical memory *before*
`kvminithart()` turns paging on, so for the 128MB kernel 97.5% of the boot
never touches the MMU at all. It's a useful sanity check when profiling --
see "Performance optimization" below.

## Measured performance

Same milestone (boot to `$ `), same machine, `cargo run --release`:

| Kernel | Instructions | Wall time | Rate |
|---|---|---|---|
| `xv6-kernel-fs-small.bin` (2MB `PHYSTOP`) | 19,476,480 | 0.77s | 25.3M instr/s |
| `xv6-kernel-fs.bin` (128MB `PHYSTOP`) | 426,917,888 | 14.8s | 28.8M instr/s |

For comparison, the same 2MB-`PHYSTOP` milestone measured on the Python
implementation earlier in this project's development: **~161.6s on CPython**
(~210x slower than this crate) and an estimated **~33s on PyPy** (using
PyPy's own measured sustained throughput on this exact boot workload) — still
roughly 43x slower. The 128MB kernel is documented in `riscvm`'s own
`CHEATSHEET.md` as taking "on the order of *hours*" under pure Python; this
crate does it in under 15 seconds.

## Performance optimization

The numbers above are the result of five profile-driven optimization
passes (each its own commit, with real before/after measurements and a
before/after profile — see the `perf P1`..`perf P5` commits in the git
log for the full detail). Every step below was found by actually profiling
the boot-to-shell benchmark with Xcode's Time Profiler (`xctrace`,
symbolicated via the `profiling` Cargo build profile — see
`[profile.profiling]` in `Cargo.toml`), not by guessing:

| Step | Fix | Boot-to-shell (2MB kernel) |
|---|---|---|
| baseline | — | ~2.96-3.09s (~6.3-6.6M instr/s) |
| P1 | CSR storage: `HashMap<u32,u64>` → flat `[u64; 4096]` array (CSR address space is a fixed 12 bits) | ~1.96-2.06s |
| P2 | `Bus` device lookup: binary search → direct index (no more linear re-scan comparing `Range` structs) | (profile-confirmed; wall-clock noisy under system load this round) |
| P3 | `Ram::read`/`write`: match `size` to a literal-length slice per arm so the compiler emits a scalar load/store instead of calling `memmove` | ~1.97-2.04s |
| P4 | Added a 256-entry software TLB to `mmu.rs` (see below) | ~1.06-1.08s |
| P5 | `Plic`'s `enable`/`threshold`: `HashMap<u64,u32>` → `[u32; 64]` (same HashMap-on-every-instruction pattern P1 fixed, this time via `check_interrupt()` calling `Plic::claimable()` unconditionally) | ~0.76-0.78s |

**On the TLB (P4) specifically**: this project already investigated a TLB
once and concluded it wasn't worth building, because 46-97.5% of a typical
boot runs with paging off entirely (`kinit()`'s zero-fill happens *before*
`kvminithart()` turns paging on) -- true, and still true. But after P1-P3
removed the cheaper HashMap/linear-scan/memmove overhead, profiling the
*paged* portion specifically showed `mmu::translate` + `Bus::read`
(the page-table walk) as the clear dominant remaining cost there. So the
earlier conclusion wasn't wrong, it was scoped to the wrong workload: a TLB
doesn't help `kinit()`'s bare-mode zero-fill (confirmed again after adding
one -- the 128MB kernel's 97.5%-bare-mode run barely moved from the TLB
itself), but it substantially helps everything that actually uses paging
(most of the 2MB kernel's remaining time, and any real interactive use
after boot, which is all paged user-mode execution). See the `perf P4`
commit message for the correctness argument (whole-TLB flush on
`SFENCE.VMA` and on any `satp` write, so the guest can never observe a
stale mapping that wouldn't have been observable before the TLB existed).

Where this stands relative to dedicated RISC-V simulators (QEMU's TCG is a
JIT and not a comparable architecture at all; Spike is a hand-optimized C++
interpreter, structurally the same kind of thing this crate is): Spike-class
interpreters are commonly cited in the tens-to-low-hundreds of MIPS range.
This crate's ~25-29M instr/s on real boot workloads is now within that same
order of magnitude, up from ~6.5M before this optimization pass -- there's
very likely more available (decode caching for repeated PC values in hot
loops is the next obvious candidate; the current profile's remaining top
entries are mostly unresolved/inlined addresses rather than one clear
hotspot, suggesting diminishing returns from this style of fix specifically).

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

Stage 8's TLB half got built after all (see "Performance optimization"
above) -- not as the originally-planned educational stretch goal, but
because profiling the real boot-to-shell benchmark showed it was worth real
instructions/sec on the paged portion of execution. An instruction/data
*cache* model (the other half of stage 8) is still not implemented: unlike
the TLB, this project doesn't model memory latency at all (`Ram` is a flat
`Vec<u8>`, real O(1) access), so a cache model wouldn't speed anything up
here -- it would only be useful as an observability/teaching tool (hit-rate
statistics), and would cost bookkeeping overhead rather than save any.

Also not implemented, matching riscvm's own current scope: floating-point
(F/D extensions), most AMO variants beyond AMOSWAP.W, EBREAK, and real
interactive UART input (the emulator can print output over UART, but
`--uart-input` isn't wired up to this crate's CLI the way it is in riscvm's
Python `emulator.py`).
