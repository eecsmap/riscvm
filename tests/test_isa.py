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

td_I = (
    ('ff', 0x00000083, 0xffff_ffff_ffff_ffff), # lb x1, 0(x0)
    ('42ff', 0x00001083, 0xffff_ffff_ffff_ff42), # lh x1, 0(x0)
    ('ff', 0x00004083, 0xff), # lbu x1, 0(x0)
    ('42ff', 0x00005083, 0xff42), # lhu x1, 0(x0)
    ('', 0x02a00093, 42), # addi x1, x0, 42
)

@pytest.mark.parametrize('data,instruction,expected', td_I)
def test_I(data, instruction, expected):
    cpu = data_loaded(data)
    cpu.execute(Instruction(instruction)) 
    assert cpu.registers[1].value == expected

td_R = (
    # rd, rs1, rs2, rs1_value, rs2_value, instruction, rd_expected
    (1, 1, 2, 0, 0xffff_ffff_ffff_ff00, 0xfff14093, 0xff), # not x1, x2
    (10, 10, 11, 2, 3, 0x02B50533, 6), # mul a0,a0,a1
    (10, 10, 11, 0x8000_0000_0000_0000, 1, 0x02B50533, 0x8000_0000_0000_0000), # mul a0,a0,a1
    (10, 10, 11, 0x8000_0000_0000_0001, 2, 0x02B50533, 2), # mul a0,a0,a1
    (10, 10, 11, 2, 3, 0x00b52533, 1), # slt a0,a0,a1; 2 < 3 -> 1
    (10, 10, 11, 3, 2, 0x00b52533, 0), # slt a0,a0,a1; 3 < 2 -> 0
    (10, 10, 11, 0xffff_ffff_ffff_ffff, 1, 0x00b52533, 1), # slt a0,a0,a1; -1 < 1 (signed) -> 1
    (10, 10, 11, 0xffff_ffff_ffff_ffff, 1, 0x00b53533, 0), # sltu a0,a0,a1; huge < 1 (unsigned) -> 0
    (10, 10, 11, 2, 3, 0x00b53533, 1), # sltu a0,a0,a1; 2 < 3 -> 1
    (10, 10, 11, 0b1010, 0b0110, 0x00b54533, 0b1100), # xor a0,a0,a1
    (10, 10, 11, 2, 3, 0x00b5053b, 5), # addw a0,a0,a1
    (10, 10, 11, 5, 3, 0x40b5053b, 2), # subw a0,a0,a1
    (10, 10, 11, 0xffff_ffff_0000_0001, 0xffff_ffff_ffff_ffff, 0x00b5053b, 0), # addw wraps to 32 bits: 1 + -1 -> 0
)

@pytest.mark.parametrize('rd, rs1, rs2, rs1_value, rs2_value, instruction, rd_expected', td_R)
def test_R(rd, rs1, rs2, rs1_value, rs2_value, instruction, rd_expected):
    cpu = data_loaded()
    cpu.registers[rs1].value = rs1_value
    cpu.registers[rs2].value = rs2_value
    cpu.execute(Instruction(instruction))
    assert cpu.registers[rd].value == rd_expected


def test_sh_stores_halfword():
    ram = RAM(0x100)
    bus = Bus().add_device(ram, (0, len(ram)))
    cpu = CPU(bus)
    cpu.registers[10].value = 0x20  # a0: base address
    cpu.registers[11].value = 0xbeef  # a1: value to store
    cpu.execute(Instruction(0xb51223))  # sh a1, 4(a0)
    assert bus.read(0x24, 2) == 0xbeef

td_shift_i = (
    # rs1_value, instruction, rd_expected
    (0xffff_ffff_ffff_fff0, 0x0040d093, 0x0fff_ffff_ffff_ffff), # srli x1, x1, 4
    (0xffff_ffff_ffff_fff0, 0x4040d093, 0xffff_ffff_ffff_ffff), # srai x1, x1, 4
)

@pytest.mark.parametrize('rs1_value, instruction, rd_expected', td_shift_i)
def test_shift_i(rs1_value, instruction, rd_expected):
    cpu = data_loaded()
    cpu.registers[1].value = rs1_value
    cpu.execute(Instruction(instruction))
    assert cpu.registers[1].value == rd_expected

td_B = (
    # rs1, rs2, rs1_value, rs2_value, instruction, pc_value, pc_expected
    (11, 12, 0xffff_ffff_ffff_ffff, 1, 0x02c5c063, 0x1000, 0x1020),  # blt a1,a2,+32; -1 < 1 -> taken
    (11, 12, 5, 3, 0x02c5c063, 0x1000, 0x1004),  # blt a1,a2,+32; 5 < 3 -> not taken
)

@pytest.mark.parametrize('rs1, rs2, rs1_value, rs2_value, instruction, pc_value, pc_expected', td_B)
def test_branch(rs1, rs2, rs1_value, rs2_value, instruction, pc_value, pc_expected):
    cpu = data_loaded()
    cpu.registers[rs1].value = rs1_value
    cpu.registers[rs2].value = rs2_value
    cpu.pc.value = pc_value
    cpu.execute(Instruction(instruction))
    assert cpu.pc.value == pc_expected

td_J = (
    # rd, pc_value, instruction, rd_expected, pc_expected
    (1, 0x1000, 0x08c000ef, 0x1004, 0x108c), # JAL    ra, 0x8c
)

@pytest.mark.parametrize('rd, pc_value, instruction, rd_expected, pc_expected', td_J)
def test_jump(rd, pc_value, instruction, rd_expected, pc_expected):
    cpu = data_loaded()
    cpu.pc.value = pc_value
    cpu.execute(Instruction(instruction))
    assert cpu.registers[rd].value == rd_expected
    assert cpu.pc.value == pc_expected
