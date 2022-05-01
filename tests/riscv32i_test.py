from riscvm import inst_gen, int32, Instruction
import pytest

testdata_run = (
    (b'', []),
    (b'\x01', []),
    (b'\x01\x02', []),
    (b'\x01\x02\x03', []),
    (b'\x01\x02\x03\x04', [0x04030201]),
    (b'\x01\x02\x03\x04\x05', [0x04030201]),
    (b'\x01\x02\x03\x04\x05\x06', [0x04030201]),
    (b'\x01\x02\x03\x04\x05\x06\x07', [0x04030201]),
    (b'\x01\x02\x03\x04\x05\x06\x07\x08', [0x04030201, 0x08070605]),
)

@pytest.mark.parametrize('input,expected', testdata_run)
def test_run(input, expected):
    data = b'\x01\x23\x45\x67\x89\xab\xcd\xef'
    instructions = inst_gen(input)
    assert(list(instructions) == expected)


testdata_int32 = (
    (0b0, 1, 0),
    (0b1, 1, -1),
    (0b10, 1, 0),
    (0b01, 1, -1),
)

@pytest.mark.parametrize('value,nbits,expected', testdata_int32)
def test_int32(value, nbits, expected):
    assert(int32(value, nbits) == expected)


testdata_instruction = (
    (Instruction(0b0100000_10000_01000_100_00010_0000001).opcode, 1),
    (Instruction(0b0100000_10000_01000_100_00010_0000001).rd, 2),
    (Instruction(0b0100000_10000_01000_100_00010_0000001).funct3, 4),
    (Instruction(0b0100000_10000_01000_100_00010_0000001).rs1, 8),
    (Instruction(0b0100000_10000_01000_100_00010_0000001).rs2, 16),
    (Instruction(0b0100000_10000_01000_100_00010_0000001).funct7, 32),
    (Instruction(0b1000000_00000_00000_000_00000_0000000).imm_i, -2048),
    (Instruction(0b1000000_00000_00000_000_00001_0000000).imm_s, -2047),
    (Instruction(0b1000000_00000_00000_000_00010_0000000).imm_b, -4094),
    (Instruction(0b1000000_00000_00000_000_00000_0000000).imm_u, -2147483648),
    (Instruction(0b1_0000000001_0_00000000_00000_0000000).imm_j, -1048574),
)

@pytest.mark.parametrize('value,expected', testdata_instruction)
def test_instruction(value, expected):
    assert(value == expected)

def candidate():
    print(Instruction(0x00000000))
    print(Instruction(0x40000003))
    print(Instruction(0x40000013))
    print(Instruction(0x40000017))
    print(Instruction(0x40000023))
    print(Instruction(0x00000033))
    print(Instruction(0x40000037))
    print(Instruction(0x40000063))
    print(Instruction(0x40000067))
    print(Instruction(0x4000006f))

    print(Instruction(0x80000003))
    print(Instruction(0x80000013))
    print(Instruction(0x80000017))
    print(Instruction(0x80000023))
    print(Instruction(0x00000033))
    print(Instruction(0x80000037))
    print(Instruction(0x80000063))
    print(Instruction(0x80000067))
    print(Instruction(0x8000006f))

    # make sure
    # 0x40155513 -> srai, x10, x10, 0x1
    # 0x02004737 -> lui, x14, 0x2004
    # 
