all: test

test: unittest

unittest:
	pytest

next:
	python3 -m riscvm.emulator --address 0x80000000 tests/kernel.bin uart_out.txt
