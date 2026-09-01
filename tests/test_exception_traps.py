"""Architectural traps: illegal instruction, misaligned access, breakpoint.

These used to abort the emulator rather than trap the guest, which meant a
program that faults could not be run at all -- and which made the emulator
unusable as a reference for hardware that does trap.
"""
from riscvm import Bus, RAM, CPU, Instruction
from riscvm.csr import CSR, PrivilegeLevel
from riscvm.exception import IllegalInstruction, InternalException
import pytest

TVEC = 0x1000


def make_cpu(pc=0x100):
    bus = Bus()
    ram = RAM(0x10000)
    bus.add_device(ram, (0, len(ram)))
    cpu = CPU(bus)
    cpu.pc.value = pc
    cpu.csrs[CSR.MTVEC.value] = TVEC
    return cpu


def run(cpu, encoding):
    cpu.execute(Instruction(encoding))


def test_illegal_instruction_traps_instead_of_aborting():
    cpu = make_cpu()
    run(cpu, 0xffffffff)                       # not a valid encoding
    assert cpu.pc.value == TVEC
    assert cpu.csrs[CSR.MCAUSE.value] == 2
    assert cpu.csrs[CSR.MEPC.value] == 0x100   # the faulting instruction
    assert cpu.csrs[CSR.MTVAL.value] == 0xffffffff


def test_strict_mode_still_aborts_for_development():
    # riscvm is developed by running xv6 and implementing whatever it stops on.
    # A silent trap would make a missing instruction look like a guest bug, so
    # the loud failure stays available.
    cpu = make_cpu()
    cpu.strict_illegal = True
    with pytest.raises(IllegalInstruction):
        run(cpu, 0xffffffff)


def test_ebreak_traps_with_its_own_address():
    cpu = make_cpu()
    run(cpu, 0x00100073)                       # ebreak
    assert cpu.pc.value == TVEC
    assert cpu.csrs[CSR.MCAUSE.value] == 3
    assert cpu.csrs[CSR.MTVAL.value] == 0x100  # the breakpoint itself


def test_misaligned_load_traps_with_the_effective_address():
    cpu = make_cpu()
    cpu.registers[1].value = 0x201             # ld x2, 0(x1) with x1 odd
    run(cpu, 0x0000b103)
    assert cpu.pc.value == TVEC
    assert cpu.csrs[CSR.MCAUSE.value] == 4
    assert cpu.csrs[CSR.MTVAL.value] == 0x201


def test_misaligned_store_traps_with_the_effective_address():
    cpu = make_cpu()
    cpu.registers[1].value = 0x202             # sw x2, 0(x1), needs 4-byte alignment
    run(cpu, 0x0020a023)
    assert cpu.pc.value == TVEC
    assert cpu.csrs[CSR.MCAUSE.value] == 6
    assert cpu.csrs[CSR.MTVAL.value] == 0x202


def test_byte_access_is_never_misaligned():
    cpu = make_cpu()
    cpu.registers[1].value = 0x203
    run(cpu, 0x00008103)                       # lb x2, 0(x1)
    assert cpu.pc.value == 0x104, 'a byte load has no alignment requirement'


def test_trap_stacks_the_interrupt_enable_bit():
    from riscvm.trap import MSTATUS_MIE, MSTATUS_MPIE
    cpu = make_cpu()
    cpu.csrs[CSR.MSTATUS.value] = MSTATUS_MIE
    run(cpu, 0xffffffff)
    ms = cpu.csrs[CSR.MSTATUS.value]
    assert not ms & MSTATUS_MIE,  'MIE must be cleared on trap entry'
    assert ms & MSTATUS_MPIE,     'MPIE must hold the previous MIE'


def test_internal_errors_are_still_distinct_from_guest_traps():
    # A bug in the emulator must not be delivered to the guest as a trap.
    assert not issubclass(InternalException, IllegalInstruction)
    assert not issubclass(IllegalInstruction, InternalException)
