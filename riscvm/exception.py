class BaseException(Exception):
    '''riscvm base exception'''

class InternalException(BaseException):
    '''riscvm internal exception -- a bug in the emulator, not in the guest'''

class ArchitecturalTrap(BaseException):
    '''A trap the guest should see, raised from wherever it is detected.

    Traps are detected deep inside instruction execution (an unknown encoding
    in the decoder, a misaligned address inside a load), where returning a
    status code would mean threading it back through every caller. Raising
    unwinds to CPU.execute(), which is the one place that knows how to deliver
    a trap -- and it unwinds *before* the actor commits the new pc, so mepc is
    still the faulting instruction's address.
    '''
    def __init__(self, cause, tval=0, message=''):
        super().__init__(message or f'trap cause={cause} tval=0x{tval:x}')
        self.cause = cause
        self.tval = tval


class IllegalInstruction(ArchitecturalTrap):
    def __init__(self, encoding, message=''):
        super().__init__(cause=2, tval=encoding,
                         message=message or f'illegal instruction 0x{encoding:08x}')
        self.encoding = encoding


def error(message='default error message'):
    raise InternalException(message)
