from riscvm import RAM, Bus

def test_mem():
    RAM_BASE = 0x8000_0000
    RAM_SIZE = 1024 * 1024 * 128
    ram = RAM(RAM_SIZE)
    bus = Bus()
    bus.add_device(ram, (RAM_BASE, RAM_SIZE))

test_mem()