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
