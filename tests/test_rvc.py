import pytest
from pytest import raises
from riscvm import Bus, RAM, CPU
from riscvm.rv64c import nzimm_5_0, Instruction as CInstruction
from riscvm.exception import InternalException

def test_nz_error():
    with raises(InternalException):
        nzimm_5_0(0)

def make_cpu():
    bus = Bus()
    ram = RAM(0x10000)
    bus.add_device(ram, (0, len(ram)))
    return CPU(bus)

# rd'/rs1' = a1 (x11, compressed raw 3), rs2' = a5 (x15, compressed raw 7)
td_c_alu = (
    # instruction, a1_value, a5_value, expected_a1
    (0x8d9d, 10, 3, 7),                    # c.sub a1,a1,a5
    (0x8dbd, 0b1010, 0b0110, 0b1100),      # c.xor a1,a1,a5
    (0x9d9d, 10, 3, 7),                    # c.subw a1,a1,a5
    (0x9dbd, 10, 3, 13),                   # c.addw a1,a1,a5
    (0x9dbd, 0xffff_ffff_0000_0001, 0xffff_ffff_ffff_ffff, 0), # c.addw wraps to 32 bits: (1)+(-1) -> 0
)

@pytest.mark.parametrize('instruction, a1_value, a5_value, expected_a1', td_c_alu)
def test_c_alu(instruction, a1_value, a5_value, expected_a1):
    cpu = make_cpu()
    cpu.registers[11].value = a1_value  # a1
    cpu.registers[15].value = a5_value  # a5
    cpu.execute(CInstruction(instruction))
    assert cpu.registers[11].value == expected_a1

def test_c_jalr_jumps_and_saves_return_address():
    # rv64c.py's own Mnemonic enum had no JALR member at all (referenced
    # in the decode table's lambda but never defined), so this crashed
    # with AttributeError rather than the usual "invalid instruction".
    cpu = make_cpu()
    cpu.pc.value = 0x1000
    cpu.registers[10].value = 0x2000  # a0: jump target
    cpu.execute(CInstruction(0x9502))  # c.jalr a0
    assert cpu.pc.value == 0x2000
    assert cpu.registers[1].value == 0x1002  # ra <- return address (pc + 2)
