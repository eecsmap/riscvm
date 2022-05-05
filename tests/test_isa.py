from riscvm import Bus, RAM, CPU, Instruction
import pytest

def data_loaded(hexdata=None):
    ram = RAM()
    if hexdata:
        ram.data = bytearray.fromhex(hexdata)
        bus = Bus().add_device(ram, (0, len(ram)))
    else:
        bus = Bus()
    cpu = CPU(bus)
    return cpu

td_1 = (
    ('ff', 0x00000083, 0xffff_ffff_ffff_ffff), # lb x1, 0(x0)
    ('42ff', 0x00001083, 0xffff_ffff_ffff_ff42), # lh x1, 0(x0)
    ('ff', 0x00004083, 0xff), # lbu x1, 0(x0)
    ('42ff', 0x00005083, 0xff42), # lhu x1, 0(x0)
    ('', 0x02a00093, 42), # addi x1, x0, 42
)

@pytest.mark.parametrize('data,instruction,expected', td_1)
def test_x1(data, instruction, expected):
    cpu = data_loaded(data)
    cpu.execute(Instruction(instruction)) 
    assert cpu.registers[1].value == expected

td_2 = (
    (0, 0xffff_ffff_ffff_ff00, 0xfff14093, 0xff), # not x1, x2
)

@pytest.mark.parametrize('rs1,rs2,instruction,expected', td_2)
def test_xori(rs1, rs2, instruction, expected):
    cpu = data_loaded()
    cpu.registers[1].value = rs1
    cpu.registers[2].value = rs2
    cpu.execute(Instruction(instruction))
    assert cpu.registers[1].value == expected
