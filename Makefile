all: test

test: unittest

unittest:
	pytest

next:
	python3 -m riscvm.emulator tests/xv6-kernel.bin uart_out.txt