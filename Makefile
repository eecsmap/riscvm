all: test

test: unittest

unittest:
	pytest

next:
	python3 -m riscvm.emulator --address 0x80000000 tests/kernel64gc_nopageflush.bin uart_out.txt

ignore:
	python3 -m riscvm.emulator --address 0x80000000 tests/kernel64g.bin uart_out.txt
	python3 -m riscvm.emulator --address 0x80000000 tests/kernel64gc.bin uart_out.txt
	python3 -m riscvm.emulator --address 0x80000000 tests/xv6-kernel.bin uart_out.txt
