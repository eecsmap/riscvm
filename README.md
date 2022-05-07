# RISC-V(irtual) Machine

## Requirement
- python3.10
- pytest

## Usage

Run tests.
```
pytest
```

A quick sanity check.
```
python3 -m riscvm.emulator tests/fib.bin
```

### Next Step Iteration
There is a xv6 kernel binary provided in tests.
Run `python3 -m riscvm.emulator tests/xv6-kernel.bin` to find next instruction to implement:)

## Develop

- Clone this project
- `cd riscvm`
- `bash pub.sh`
- Install this package in editable mode (i.e. setuptools "develop mode") `pip install -e .`
- Sanity check `echo 12345678 | python3 -m riscvm`

## (Optional) Build RISC-V tool-chain
Read https://github.com/riscv-collab/riscv-gnu-toolchain

### On Linux
```
sudo apt install autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev

git clone https://github.com/riscv/riscv-gnu-toolchain`

cd riscv-gnu-toolchain

./configure --prefix=/opt/rv64g --with-arch=rv64g --with-abi=lp64d

sudo make linux
```

## Build test binaries
Using tools from /opt/rv64g we just built.
```
gcc -S fib.c
gcc -Wl,-Ttext=0 -nostdlib -o fib.o fib.s
objcopy -O binary fib.o fib.bin
```
