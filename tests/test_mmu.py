from riscvm import Bus, RAM, CPU
from riscvm.csr import CSR
from riscvm.mmu import translate, PTE_V, PTE_R, PTE_W
from riscvm.exception import InternalException
import pytest

PAGESIZE = 0x1000

def make_cpu(ram_size=0x10000):
    bus = Bus()
    ram = RAM(ram_size)
    bus.add_device(ram, (0, ram_size))
    return CPU(bus)

def write_pte(cpu, table_ppn, index, target_ppn, flags):
    addr = table_ppn * PAGESIZE + index * 8
    pte = (target_ppn << 10) | flags
    cpu.bus.write(addr, 8, pte)

def test_bare_mode_is_identity():
    cpu = make_cpu()
    assert translate(cpu, 0x1234, 'r') == 0x1234
    assert translate(cpu, 0x1234, 'w') == 0x1234
    assert translate(cpu, 0x1234, 'x') == 0x1234

def test_cpu_read_write_passthrough_when_bare():
    cpu = make_cpu()
    cpu.write(0x100, 8, 0xdeadbeef)
    assert cpu.read(0x100, 8) == 0xdeadbeef

def test_sv39_three_level_translation():
    cpu = make_cpu(ram_size=0x10000)
    root_ppn, l1_ppn, l0_ppn, data_ppn = 1, 2, 3, 4

    vpn2, vpn1, vpn0, offset = 1, 2, 3, 0x123
    va = (vpn2 << 30) | (vpn1 << 21) | (vpn0 << 12) | offset

    write_pte(cpu, root_ppn, vpn2, l1_ppn, PTE_V)  # pointer (no R/W/X)
    write_pte(cpu, l1_ppn, vpn1, l0_ppn, PTE_V)  # pointer
    write_pte(cpu, l0_ppn, vpn0, data_ppn, PTE_V | PTE_R | PTE_W)  # leaf

    cpu.csrs[CSR.SATP.value] = (8 << 60) | root_ppn

    pa = translate(cpu, va, 'r')
    assert pa == (data_ppn << 12) | offset

def test_sv39_cpu_read_write_end_to_end():
    cpu = make_cpu(ram_size=0x10000)
    root_ppn, l1_ppn, l0_ppn, data_ppn = 1, 2, 3, 4
    vpn2, vpn1, vpn0, offset = 0, 0, 0, 0x10
    va = (vpn2 << 30) | (vpn1 << 21) | (vpn0 << 12) | offset

    write_pte(cpu, root_ppn, vpn2, l1_ppn, PTE_V)
    write_pte(cpu, l1_ppn, vpn1, l0_ppn, PTE_V)
    write_pte(cpu, l0_ppn, vpn0, data_ppn, PTE_V | PTE_R | PTE_W)
    cpu.csrs[CSR.SATP.value] = (8 << 60) | root_ppn

    cpu.write(va, 8, 0x1122334455667788)
    assert cpu.read(va, 8) == 0x1122334455667788
    # confirm it actually landed at the translated physical address
    assert cpu.bus.read(data_ppn * PAGESIZE + offset, 8) == 0x1122334455667788

def test_sv39_gigapage_superpage():
    cpu = make_cpu()
    root_ppn = 1
    vpn2, vpn1, vpn0, offset = 5, 7, 9, 0x42
    va = (vpn2 << 30) | (vpn1 << 21) | (vpn0 << 12) | offset

    superpage_ppn = 100 << 18  # low 18 bits zero: 1GB-aligned
    write_pte(cpu, root_ppn, vpn2, superpage_ppn, PTE_V | PTE_R | PTE_W)
    cpu.csrs[CSR.SATP.value] = (8 << 60) | root_ppn

    pa = translate(cpu, va, 'r')
    expected_ppn = superpage_ppn | (vpn1 << 9) | vpn0
    assert pa == (expected_ppn << 12) | offset

def test_sv39_invalid_pte_faults():
    cpu = make_cpu()
    cpu.csrs[CSR.SATP.value] = (8 << 60) | 1  # root table page left all zero -> V=0
    with pytest.raises(InternalException):
        translate(cpu, 0x1000, 'r')

def test_sv39_permission_denied_faults():
    cpu = make_cpu()
    root_ppn, l1_ppn, l0_ppn, data_ppn = 1, 2, 3, 4
    va = 0  # vpn2=vpn1=vpn0=0
    write_pte(cpu, root_ppn, 0, l1_ppn, PTE_V)
    write_pte(cpu, l1_ppn, 0, l0_ppn, PTE_V)
    write_pte(cpu, l0_ppn, 0, data_ppn, PTE_V | PTE_R)  # read-only leaf
    cpu.csrs[CSR.SATP.value] = (8 << 60) | root_ppn

    assert translate(cpu, va, 'r') == data_ppn * PAGESIZE
    with pytest.raises(InternalException):
        translate(cpu, va, 'w')

def test_sv39_unsupported_mode_faults():
    cpu = make_cpu()
    cpu.csrs[CSR.SATP.value] = (1 << 60)  # mode 1 (Sv32) not implemented
    with pytest.raises(InternalException):
        translate(cpu, 0x1000, 'r')
