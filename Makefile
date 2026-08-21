all: test

test: unittest

unittest:
	uv run pytest

next:
	uv run python3 -m riscvm.emulator --address 0x80000000 tests/kernel64gc_nopageflush.bin uart_out.txt

ignore:
	uv run python3 -m riscvm.emulator --address 0x80000000 tests/kernel64g.bin uart_out.txt
	uv run python3 -m riscvm.emulator --address 0x80000000 tests/kernel64gc.bin uart_out.txt
	uv run python3 -m riscvm.emulator --address 0x80000000 tests/xv6-kernel.bin uart_out.txt
