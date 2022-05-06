import sys
import subprocess
import os.path

src = sys.argv[1]
temp = os.path.splitext(src)[0]
des = temp + '.bin'

cmd = ['/opt/riscv-toolchain/bin/riscv64-unknown-linux-gnu-gcc', '-Wl,-Ttext=0x0', '-nostdlib']
subprocess.run(cmd + [src, '-o', temp])

cmd = ['riscv64-linux-gnu-objcopy', '-O', 'binary']
subprocess.run(cmd + [temp, des])


# build tool-chain
# ttps://github.com/riscv-collab/riscv-gnu-toolchain
# sudo apt-get install autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev
# git clone https://github.com/riscv/riscv-gnu-toolchain
# cd riscv-gnu-toolchain
# ./configure --prefix=/opt/rv64g --with-arch=rv64g --with-abi=lp64d

# gcc -S fib.c
# gcc -Wl,-Ttext=0 -nostdlib -o fib.o fib.s
# objcopy -O binary fib.o fib.bin
