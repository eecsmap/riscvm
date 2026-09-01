"""Commit trace, for co-simulating against a hardware implementation.

The format is deliberately minimal and line-oriented so that two independent
implementations can be compared with a plain diff:

    <pc:016x> <inst:08x> [x<rd>=<value:016x>]

One line per retired instruction; the register field is omitted when the
instruction writes nothing. That is enough to catch both control-flow
divergence (pc/inst) and datapath errors (the written value), while staying
cheap enough to emit for millions of instructions.

The write is captured by intercepting `cpu.rd()`, the single architectural
write path, rather than by diffing a register snapshot before and after. A
snapshot cannot tell "wrote the same value that was already there" from "did
not write at all" -- and hardware reports the former as a write, so the two
traces would disagree on every `sltu` that yields a zero into an
already-zero register.
"""


class Tracer:
    def __init__(self, cpu, stream):
        self.cpu = cpu
        self.stream = stream
        self._write = None
        self._install()

    def _install(self):
        cpu = self.cpu
        original = cpu.rd

        def traced_rd(value):
            self._write = (cpu.instruction.rd, value)
            return original(value)

        cpu.rd = traced_rd

    def before(self):
        self._write = None

    def after(self, pc, inst):
        line = f'{pc:016x} {inst:08x}'
        if self._write is not None:
            idx, val = self._write
            # x0 discards writes, so the architectural state does not change and
            # neither trace should report one.
            if idx != 0:
                line += f' x{idx}={val & ((1 << 64) - 1):016x}'
        self.stream.write(line + '\n')
