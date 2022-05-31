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
There is a xv6 kernel binary provided in tests. We use it to drive the development.
To find next instruction to implement, simply run:
`python3 -m riscvm.emulator tests/xv6-kernel.bin`
Make sure which ever instruction added is well tested too.

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

## Create binary kernel (Ubuntu 22.04 LTS)
1. `sudo apt-get install git build-essential gdb-multiarch qemu-system-misc gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu`
2. `git clone https://github.com/mit-pdos/xv6-riscv`
3. `cd xv6-riscv`
4. `make qemu`
5. `riscv64-linux-gnu-objcopy -O binary kernel/kernel kernel.bin`
6. `riscv64-linux-gnu-objdump -b binary -m riscv:rv64 -D kernel.bin --adjust-vma=0x80000000`

## Build test binaries
Using tools from /opt/rv64g we just built.
```
gcc -S fib.c
gcc -Wl,-Ttext=0 -nostdlib -o fib.o fib.s
objcopy -O binary fib.o fib.bin
```

## example dev workflow
1. run `make next` to find next instruction to implement.
2. add test accordingly into tests/test_isa.py, you might find output from step 1 useful in creating tests.
3. run `make test` to run tests.
4. add implementation to pass tests.

## examples of tools
```
python tools/as.py
mv a0, a1

python tools/as.py --dis
852e
```

## dev scenarios
if you run make next and see
```
riscvm.exception.InternalException: invalid instruction: UNDEFINED
        0x12000073
        UNDEFINED
        SYSTEM
        opcode  :0001001_00000_00000_000_00000_1110011  0x73
        rd      :0001001_00000_00000_000_00000_1110011  x0      zero
        funct3  :0001001_00000_00000_000_00000_1110011  0x0
        rs1     :0001001_00000_00000_000_00000_1110011  x0      zero
        rs2     :0001001_00000_00000_000_00000_1110011  x0      zero
        funct7  :0001001_00000_00000_000_00000_1110011  0x09
        I imm   :0001001_00000_00000_000_00000_1110011  288
        S imm   :0001001_00000_00000_000_00000_1110011  288
        B imm   :0001001_00000_00000_000_00000_1110011  288
        U imm   :0001001_00000_00000_000_00000_1110011  301989888
        J imm   :0_0010010000_0_00000000_00000_1110011  288
```
then just run
```
python tools/as.py --dis
12000073
['sfence.vma']
```
to figure out what needs to be implement next. For this example, it is `sfence.vma`
