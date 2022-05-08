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

td_R = (
    # rd, rs1, rs2, rs1_value, rs2_value, instruction, rd_expected
    (1, 1, 2, 0, 0xffff_ffff_ffff_ff00, 0xfff14093, 0xff), # not x1, x2
    (10, 10, 11, 2, 3, 0x02B50533, 6), # mul a0,a0,a1
    (10, 10, 11, 0x8000_0000_0000_0000, 1, 0x02B50533, 0x8000_0000_0000_0000), # mul a0,a0,a1
    (10, 10, 11, 0x8000_0000_0000_0001, 2, 0x02B50533, 2), # mul a0,a0,a1
)

@pytest.mark.parametrize('rd, rs1, rs2, rs1_value, rs2_value, instruction, rd_expected', td_R)
def test_xori(rd, rs1, rs2, rs1_value, rs2_value, instruction, rd_expected):
    cpu = data_loaded()
    cpu.registers[rs1].value = rs1_value
    cpu.registers[rs2].value = rs2_value
    cpu.execute(Instruction(instruction))
    assert cpu.registers[rd].value == rd_expected
