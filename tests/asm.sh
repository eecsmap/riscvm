/opt/riscv-toolchain/bin/riscv64-unknown-linux-gnu-gcc -Wl,-Ttext=0x0 -nostdlib add.s -o add
riscv64-linux-gnu-objcopy -O binary add add.bin
python3 ~/github/riscv/disasm.py add.bin
