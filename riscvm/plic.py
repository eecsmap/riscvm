'''
Minimal SiFive-style PLIC (Platform-Level Interrupt Controller), matching
the subset qemu's riscv-virt machine exposes and xv6-riscv's kernel/plic.c
drives: priority registers, per-context enable bits, a per-context
priority threshold, and claim/complete.

refer: qemu-riscv64-virt.dts (plic@c000000), kernel/memlayout.h PLIC_*

A device's interrupt line is modeled as "pending whenever its own
interrupt_status has bit 0 set" (level-triggered), rather than tracking
a separate pending bit here — so completing an interrupt is a no-op:
the line drops on its own once the driver acks the device directly
(e.g. VIRTIO_MMIO_INTERRUPT_ACK), exactly mirroring real hardware
where completion re-arms the PLIC rather than clearing the source.
'''

PRIORITY_BASE = 0x0
PRIORITY_END = 0x1000
ENABLE_BASE = 0x2000
ENABLE_END = 0x1f2000  # per qemu virt: up to 0x1f_2000 with room for many contexts
ENABLE_STRIDE = 0x80
CONTEXT_BASE = 0x200000
CONTEXT_STRIDE = 0x1000
THRESHOLD_OFFSET = 0x0
CLAIM_OFFSET = 0x4

MAX_IRQ = 32  # this emulator's device set only uses IRQ 1 and 10; one word is plenty

class PLIC:

    def __init__(self, size, devices_by_irq=None):
        self.size = size
        self.devices_by_irq = devices_by_irq or {}  # irq -> device with .interrupt_status
        self.priority = [0] * MAX_IRQ
        self.enable = {}    # context -> bitmask
        self.threshold = {}  # context -> int

    def __len__(self):
        return self.size

    def _pending_mask(self):
        mask = 0
        for irq, device in self.devices_by_irq.items():
            if getattr(device, 'interrupt_status', 0) & 1:
                mask |= 1 << irq
        return mask

    def claimable(self, context):
        return self._claim_irq(context) != 0

    def _claim_irq(self, context):
        candidates = self._pending_mask() & self.enable.get(context, 0)
        threshold = self.threshold.get(context, 0)
        best_irq, best_priority = 0, threshold
        for irq in range(1, MAX_IRQ):
            if candidates & (1 << irq) and self.priority[irq] > best_priority:
                best_priority = self.priority[irq]
                best_irq = irq
        return best_irq

    def read(self, address, size):
        assert size == 4, f'plic accesses are 4 bytes, got {size}'
        if PRIORITY_BASE <= address < PRIORITY_END:
            irq = address // 4
            return self.priority[irq] if irq < MAX_IRQ else 0
        if ENABLE_BASE <= address < ENABLE_END:
            context = (address - ENABLE_BASE) // ENABLE_STRIDE
            return self.enable.get(context, 0)
        if address >= CONTEXT_BASE:
            context = (address - CONTEXT_BASE) // CONTEXT_STRIDE
            offset = (address - CONTEXT_BASE) % CONTEXT_STRIDE
            if offset == THRESHOLD_OFFSET:
                return self.threshold.get(context, 0)
            if offset == CLAIM_OFFSET:
                return self._claim_irq(context)  # claiming is read-triggered; no extra state to clear
        return 0

    def write(self, address, size, value):
        assert size == 4, f'plic accesses are 4 bytes, got {size}'
        if PRIORITY_BASE <= address < PRIORITY_END:
            irq = address // 4
            if irq < MAX_IRQ:
                self.priority[irq] = value
            return
        if ENABLE_BASE <= address < ENABLE_END:
            context = (address - ENABLE_BASE) // ENABLE_STRIDE
            self.enable[context] = value
            return
        if address >= CONTEXT_BASE:
            context = (address - CONTEXT_BASE) // CONTEXT_STRIDE
            offset = (address - CONTEXT_BASE) % CONTEXT_STRIDE
            if offset == THRESHOLD_OFFSET:
                self.threshold[context] = value
            # CLAIM_OFFSET write is "complete" -- no-op, see module docstring
