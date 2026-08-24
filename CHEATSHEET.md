# riscvm cheatsheet

Common commands for working on this project. Run everything from the repo root.

## Setup

```sh
uv sync                   # creates .venv, editable install + pytest, per pyproject.toml
uv run pytest             # or just: make test
```

## Run the emulator

### Real xv6, fast (recommended for interactive use)

`tests/xv6-kernel-fs-small.bin` is a real xv6-riscv kernel rebuilt with
`PHYSTOP` reduced from 128MB to 2MB, so `kinit()` has far less to zero-fill
at boot. Reaches the `$ ` shell prompt in a few minutes instead of hours.

```sh
uv run python3 -m riscvm.emulator --address 0x80000000 --fs-image tests/fs.img tests/xv6-kernel-fs-small.bin
```

Run it in a real terminal (not piped through another command) so your
keyboard input is wired to the emulated UART -- once you see `$ ` you can
type `ls`, `cat README`, etc. Not suitable for memory-heavy programs like
`usertests` (2MB is a tight fit).

### Real xv6, full-size (matches real hardware's 128MB)

```sh
uv run python3 -m riscvm.emulator --address 0x80000000 --fs-image tests/fs.img tests/xv6-kernel-fs.bin
```

Boots identically, but `kinit()`'s byte-by-byte zero-fill of 128MB of RAM
takes on the order of *hours* in this pure-Python interpreter. Use the
small kernel above unless you specifically need the 128MB layout.

### Multicore (`--smp`)

```sh
uv run python3 -m riscvm.emulator --smp 3 --address 0x80000000 --fs-image tests/fs.img tests/xv6-kernel-fs-small.bin
```

Boots N harts (like qemu's `-smp N`; xv6-riscv's own `make qemu` defaults
to 3) round-robin, one instruction per hart per round. Reproduces the same
`hart 1 starting` / `hart 2 starting` banner real qemu prints, but takes
roughly N times as long as single-core since the harts split the
interpreter's instruction throughput.

### Piped / scripted input instead of your keyboard

```sh
uv run python3 -m riscvm.emulator --address 0x80000000 --fs-image tests/fs.img --uart-input commands.txt tests/xv6-kernel-fs-small.bin
```

### Development kernels (no filesystem, used to drive ISA implementation)

```sh
uv run python3 -m riscvm.emulator --address 0x80000000 tests/kernel64gc_nopageflush.bin uart_out.txt   # == make next
uv run python3 -m riscvm.emulator tests/fib.bin                                                        # quick sanity check
```

Ctrl-C during any run dumps all registers and the current instruction
before exiting -- useful for seeing exactly where execution stalled.

## Tests

```sh
uv run pytest                              # full suite
uv run pytest tests/test_isa.py -v         # one file, verbose
uv run pytest -k mulh                      # by name substring
uv run pytest tests/test_isa.py::test_R    # one parametrized test function
```

## Find the next instruction to implement

The classic dev loop for extending the ISA: run a kernel until it hits an
instruction with no execute case, which raises `InternalException` with a
full decode dump (mnemonic, opcode, all immediate encodings).

```sh
make next
# or directly:
uv run python3 -m riscvm.emulator --address 0x80000000 tests/kernel64gc_nopageflush.bin uart_out.txt
```

Then implement it in `riscvm/rv64i.py` (or `rv64c.py` for compressed
forms), add a regression test in `tests/test_isa.py` / `tests/test_rvc.py`
using the exact instruction word from the crash dump, and re-run.

## Disassemble / assemble a single instruction

```sh
uv run python3 tools/as.py                 # assemble: paste asm, get bytes
uv run python3 tools/as.py --dis           # disassemble: paste hex, get asm
```

## Performance: benchmark and profile

Both scripts run the real xv6 boot (`tests/xv6-kernel-fs-small.bin` +
`tests/fs.img`) so numbers reflect a realistic workload, not a synthetic
loop.

```sh
uv run python3 tools/bench_xv6_boot.py [seconds]              # sustained instructions/sec (default 30s)
uv run python3 tools/profile_xv6_boot.py [instruction_count]  # cProfile, sorted by cumulative then self time (default 2M)
```

To compare against PyPy: this codebase uses `match`/`case` (3.10+), so it
needs a PyPy build with 3.10+ language support (`pypy3 --version`).
Older `pypy3` builds pinned to the 3.9 language level will fail to import
with a `SyntaxError` on `match`.

## Debugging a stuck/crashed boot

- `InternalException` (raised for an unimplemented/invalid instruction)
  prints a full decode table -- mnemonic, every immediate encoding
  (I/S/B/U/J), opcode/funct3/funct7 bit breakdown.
- Ctrl-C prints all 31 general registers + `pc` + the current instruction.
- For a live, byte-flushed console while debugging interactively, write
  your own small driver around `riscvm.emulator.XV6` instead of the CLI --
  see `tools/bench_xv6_boot.py` for the minimal pattern (open the kernel +
  `fs.img`, construct `XV6(...)`, loop `cpu.fetch()`/`cpu.execute()`).
  This is also the easiest way to inject synthetic UART input
  (`emu.cpu.uart.inject(b'ls\n')`) or trace specific state (traps taken,
  UART bytes written, instruction counts) without re-running the CLI.

## Build kernel/filesystem fixtures from real xv6-riscv source

See `README.md` -> "Create binary kernel" for toolchain setup. To rebuild
the small (2MB `PHYSTOP`) kernel specifically: edit `PHYSTOP` in
`kernel/memlayout.h` in a real xv6-riscv checkout, `make kernel/kernel`,
then `riscv64-linux-gnu-objcopy -O binary kernel/kernel <out>.bin`.
