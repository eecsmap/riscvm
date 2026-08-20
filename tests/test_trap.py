from riscvm import Bus, RAM, CPU, Instruction
from riscvm.csr import CSR, PrivilegeLevel
from riscvm.trap import csr_read, csr_write, raise_trap, check_interrupt, MSTATUS_SIE, MSTATUS_MIE
from riscvm.clint import CLINT
from riscvm.plic import PLIC
import pytest

def make_cpu():
    bus = Bus()
    ram = RAM(0x10000)
    bus.add_device(ram, (0, len(ram)))
    return CPU(bus)

def test_sstatus_aliases_mstatus():
    cpu = make_cpu()
    csr_write(cpu, CSR.MSTATUS.value, MSTATUS_MIE)  # set a machine-only bit
    csr_write(cpu, CSR.SSTATUS.value, MSTATUS_SIE)  # set SIE via the S-mode view
    # SIE write must land in the same mstatus storage, alongside the MIE bit set moments ago
    assert cpu.csrs[CSR.MSTATUS.value] & MSTATUS_SIE
    assert cpu.csrs[CSR.MSTATUS.value] & MSTATUS_MIE
    # and the S-mode view only exposes the S-mode-visible bits
    assert csr_read(cpu, CSR.SSTATUS.value) == MSTATUS_SIE

def test_sie_aliases_mie():
    cpu = make_cpu()
    csr_write(cpu, CSR.SIE.value, 0x222)  # SSIE|STIE|SEIE
    assert cpu.csrs[CSR.MIE.value] == 0x222
    assert csr_read(cpu, CSR.SIE.value) == 0x222

def test_csrrc_clears_bits():
    # sstatus is an aliased CSR (see test_sstatus_aliases_mstatus), which
    # only exposes bits 1/5/8 -- use a plain, unaliased CSR here so the test
    # exercises CSRRC's own clear-bits logic, not the masking.
    cpu = make_cpu()
    cpu.csrs[CSR.MSCRATCH.value] = 0b1111
    cpu.registers[10].value = 0b0101  # a0
    cpu.execute(Instruction(0x34053773))  # csrrc a4, mscratch, a0
    assert cpu.registers[14].value == 0b1111  # a4 <- old value
    assert cpu.csrs[CSR.MSCRATCH.value] == 0b1010  # cleared bits set in a0

def test_csrrwi_uses_immediate_not_register():
    cpu = make_cpu()
    cpu.csrs[CSR.MSCRATCH.value] = 0xff
    cpu.execute(Instruction(0x3402d0f3))  # csrrwi x1, mscratch, 5
    assert cpu.registers[1].value == 0xff  # x1 <- old mscratch
    assert cpu.csrs[CSR.MSCRATCH.value] == 5  # mscratch <- immediate 5, not a register

def test_csrrsi_sets_bits_from_immediate():
    cpu = make_cpu()
    cpu.csrs[CSR.MSCRATCH.value] = 0b1000
    cpu.execute(Instruction(0x3401e0f3))  # csrrsi x1, mscratch, 3
    assert cpu.csrs[CSR.MSCRATCH.value] == 0b1011

def test_csrrci_clears_bits_from_immediate():
    # the exact instruction that first exposed CSRRCI as unimplemented:
    # `csrrci s1, sstatus, 2` -- clears SIE via a 5-bit immediate mask.
    cpu = make_cpu()
    cpu.csrs[CSR.MSTATUS.value] = 0b111
    cpu.execute(Instruction(0x100174f3))  # csrrci s1, sstatus, 2
    assert cpu.registers[9].value == 0b010  # s1 <- old sstatus view (masked to bits 1/5/8: just SIE here)
    assert cpu.csrs[CSR.MSTATUS.value] == 0b101  # bit 1 (SIE) cleared; untouched bits (0, 2) survive

def test_ecall_from_u_mode_delegated_traps_to_s_mode():
    cpu = make_cpu()
    cpu.mode = PrivilegeLevel.U.value
    csr_write(cpu, CSR.MEDELEG.value, 1 << 8)  # delegate U-mode ecall to S
    cpu.csrs[CSR.STVEC.value] = 0x2000
    cpu.pc.value = 0x1000
    new_pc = raise_trap(cpu, 8, is_interrupt=False)
    assert new_pc == 0x2000
    assert cpu.mode == PrivilegeLevel.S.value
    assert cpu.csrs[CSR.SEPC.value] == 0x1000
    assert cpu.csrs[CSR.SCAUSE.value] == 8

def test_ecall_not_delegated_traps_to_m_mode():
    cpu = make_cpu()
    cpu.mode = PrivilegeLevel.U.value
    csr_write(cpu, CSR.MEDELEG.value, 0)  # nothing delegated
    cpu.csrs[CSR.MTVEC.value] = 0x3000
    cpu.pc.value = 0x1000
    new_pc = raise_trap(cpu, 8, is_interrupt=False)
    assert new_pc == 0x3000
    assert cpu.mode == PrivilegeLevel.M.value
    assert cpu.csrs[CSR.MEPC.value] == 0x1000

def test_ecall_execute_and_sret_round_trip():
    cpu = make_cpu()
    cpu.mode = PrivilegeLevel.U.value
    csr_write(cpu, CSR.MEDELEG.value, 1 << 8)
    csr_write(cpu, CSR.SSTATUS.value, MSTATUS_SIE)  # interrupts enabled before the trap
    cpu.csrs[CSR.STVEC.value] = 0x4000
    cpu.pc.value = 0x1000
    cpu.execute(Instruction(0x00000073))  # ecall
    assert cpu.pc.value == 0x4000
    assert cpu.mode == PrivilegeLevel.S.value
    assert not (csr_read(cpu, CSR.SSTATUS.value) & MSTATUS_SIE)  # SIE cleared on entry

    cpu.execute(Instruction(0x10200073))  # sret
    assert cpu.pc.value == 0x1000  # back to sepc
    assert cpu.mode == PrivilegeLevel.U.value
    assert csr_read(cpu, CSR.SSTATUS.value) & MSTATUS_SIE  # SIE restored from SPIE

def test_csrrw_self_swap_preserves_original_value():
    # xv6's timervec starts with `csrrw a0, mscratch, a0` -- rd and rs1 are
    # the same register. Writing rd before reading rs1 would clobber the
    # value being swapped in, silently dropping the original a0 (exactly
    # what caused a real "panic: release" once, from a0 coming back wrong
    # after the very first timer interrupt).
    cpu = make_cpu()
    cpu.csrs[CSR.MSCRATCH.value] = 0x9000
    cpu.registers[10].value = 0x1234  # a0
    cpu.execute(Instruction(0x34051573))  # csrrw a0, mscratch, a0
    assert cpu.registers[10].value == 0x9000       # a0 <- old mscratch
    assert cpu.csrs[CSR.MSCRATCH.value] == 0x1234   # mscratch <- old a0

def test_csrrs_self_alias_still_ors_original_value():
    cpu = make_cpu()
    cpu.csrs[CSR.MSCRATCH.value] = 0x0f0
    cpu.registers[10].value = 0x00f
    cpu.execute(Instruction(0x34052573))  # csrrs a0, mscratch, a0
    assert cpu.registers[10].value == 0x0f0          # a0 <- old mscratch
    assert cpu.csrs[CSR.MSCRATCH.value] == 0x0ff     # mscratch <- old | original a0

def test_wfi_is_a_noop():
    cpu = make_cpu()
    cpu.pc.value = 0x1000
    cpu.execute(Instruction(0x10500073))  # wfi
    assert cpu.pc.value == 0x1004

def test_clint_mtip_always_taken_in_m_mode_target_when_below_m():
    # base RISC-V has no S-mode timer hardware: CLINT only ever drives MIP.MTIP
    # (bit 7), which mideleg can't delegate, so it always traps to M-mode's
    # mtvec -- and does so unconditionally whenever the current mode is below
    # M, regardless of mstatus.MIE (that's how xv6's start.c leaves things:
    # mode is S for virtually all of boot, with the M-mode timervec doing the
    # real work of relaying a tick to S-mode via sip.SSIP).
    cpu = make_cpu()
    cpu.clint = CLINT(0x10000)
    cpu.clint.mtimecmp[0] = 5
    cpu.mode = PrivilegeLevel.S.value
    csr_write(cpu, CSR.MIE.value, 1 << 7)  # MTIE
    cpu.csrs[CSR.MTVEC.value] = 0x5000
    cpu.pc.value = 0x1000

    for _ in range(5):
        cpu.clint.tick()
    taken = check_interrupt(cpu)
    assert taken
    assert cpu.pc.value == 0x5000
    assert cpu.mode == PrivilegeLevel.M.value
    assert cpu.csrs[CSR.MCAUSE.value] == (7 | (1 << 63))

def test_clint_mtip_not_delivered_when_mtie_disabled():
    cpu = make_cpu()
    cpu.clint = CLINT(0x10000)
    cpu.clint.mtimecmp[0] = 5
    cpu.mode = PrivilegeLevel.S.value
    csr_write(cpu, CSR.MIE.value, 0)  # MTIE off
    cpu.pc.value = 0x1000

    for _ in range(10):
        cpu.clint.tick()
    taken = check_interrupt(cpu)
    assert not taken
    assert cpu.pc.value == 0x1000

def test_clint_mtip_never_delegated_even_if_mideleg_says_so():
    # xv6's start() sets mideleg = 0xffff (delegate everything) in one shot,
    # covering the M-mode-only interrupt bits too even though it's really
    # only trying to delegate SSI/STI/SEI. Real hardware hardwires those
    # bits in mideleg to zero; if we didn't too, a raw MTIP would land in
    # S-mode's scause as cause 7, which isn't a defined S-mode interrupt --
    # exactly the "panic: kerneltrap" this regressed to once.
    cpu = make_cpu()
    cpu.clint = CLINT(0x10000)
    cpu.clint.mtimecmp[0] = 5
    cpu.mode = PrivilegeLevel.S.value
    csr_write(cpu, CSR.MIDELEG.value, 0xffff)
    csr_write(cpu, CSR.MIE.value, 1 << 7)  # MTIE
    cpu.csrs[CSR.MTVEC.value] = 0x5000
    cpu.csrs[CSR.STVEC.value] = 0x6000
    cpu.pc.value = 0x1000

    for _ in range(5):
        cpu.clint.tick()
    taken = check_interrupt(cpu)
    assert taken
    assert cpu.mode == PrivilegeLevel.M.value
    assert cpu.pc.value == 0x5000  # mtvec, not stvec
    assert cpu.csrs[CSR.MCAUSE.value] == (7 | (1 << 63))

def test_supervisor_software_interrupt_delivered_via_sip():
    # this is the mechanism xv6's M-mode timervec actually uses to hand a
    # tick to S-mode: write bit 1 (SSIP) of sip after reprogramming mtimecmp.
    cpu = make_cpu()
    cpu.mode = PrivilegeLevel.S.value
    csr_write(cpu, CSR.MIDELEG.value, 1 << 1)  # delegate supervisor software interrupt
    csr_write(cpu, CSR.SIE.value, 1 << 1)      # SSIE
    csr_write(cpu, CSR.SSTATUS.value, MSTATUS_SIE)
    cpu.csrs[CSR.STVEC.value] = 0x6000
    cpu.pc.value = 0x1000

    csr_write(cpu, CSR.SIP.value, 1 << 1)  # sip.SSIP = 1, as the M-mode timervec would

    taken = check_interrupt(cpu)
    assert taken
    assert cpu.pc.value == 0x6000
    assert cpu.mode == PrivilegeLevel.S.value
    assert cpu.csrs[CSR.SCAUSE.value] == (1 | (1 << 63))

def test_plic_claim_respects_priority_enable_and_threshold():
    class FakeDevice:
        interrupt_status = 1

    dev = FakeDevice()
    plic = PLIC(0x400000, devices_by_irq={1: dev})

    # not enabled yet -> nothing claimable
    assert plic._claim_irq(1) == 0

    plic.write(0x2080, 4, 1 << 1)  # enable irq 1 for context 1 (S-mode, hart0)
    plic.write(1 * 4, 4, 1)        # priority[1] = 1
    plic.write(0x201000, 4, 0)     # threshold[context 1] = 0

    assert plic.claimable(1)
    assert plic.read(0x201004, 4) == 1  # SCLAIM(hart0) returns irq 1

    dev.interrupt_status = 0  # device acked -> line drops
    assert not plic.claimable(1)

def test_plic_threshold_masks_low_priority():
    class FakeDevice:
        interrupt_status = 1

    dev = FakeDevice()
    plic = PLIC(0x400000, devices_by_irq={1: dev})
    plic.write(0x2080, 4, 1 << 1)
    plic.write(1 * 4, 4, 1)
    plic.write(0x201000, 4, 2)  # threshold above the irq's priority
    assert not plic.claimable(1)
