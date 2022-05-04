from riscvm import Bus, RAM, CPU, Instruction, create_ram

def test_lb():
    bus = Bus()
    ram = create_ram(b'\xff')
    bus.add_device(ram, (0, len(ram)))
    cpu = CPU(bus=bus)
    cpu.execute(Instruction(0x00000083)) # 'lb x1, 0(x0)'
    assert cpu.registers[1].value == 0xffff_ffff_ffff_ffff

def test_lh():
    bus = Bus()
    ram = create_ram(b'\x42\xff')
    bus.add_device(ram, (0, len(ram)))
    cpu = CPU(bus=bus)
    cpu.execute(Instruction(0x00001083)) # 'lh x1, 0(x0)'
    assert cpu.registers[1].value == 0xffff_ffff_ffff_ff42

def test_lbu():
    bus = Bus()
    ram = create_ram(b'\xff')
    bus.add_device(ram, (0, len(ram)))
    cpu = CPU(bus=bus)
    cpu.execute(Instruction(0x00004083)) # 'lbu x1, 0(x0)'
    assert cpu.registers[1].value == 0xff

def test_lhu():
    bus = Bus()
    ram = create_ram(b'\x42\xff')
    bus.add_device(ram, (0, len(ram)))
    cpu = CPU(bus=bus)
    cpu.execute(Instruction(0x00005083)) # 'lhu x1, 0(x0)'
    assert cpu.registers[1].value == 0xff42

def test_addi():
    bus = Bus()
    ram = create_ram(b'\x00')
    bus.add_device(ram, (0, len(ram)))
    cpu = CPU(bus=bus)
    cpu.execute(Instruction(0x02a00093)) # addi x1, x0, 42
    assert cpu.registers[1].value == 42

def test_xori():
    bus = Bus()
    ram = create_ram(b'\x00')
    bus.add_device(ram, (0, len(ram)))
    cpu = CPU(bus=bus)
    cpu.registers[2].value = 0xffff_ffff_ffff_ff00
    cpu.execute(Instruction(0xfff14093)) # not x1, x2
    assert cpu.registers[1].value == 0xff

test_lb()