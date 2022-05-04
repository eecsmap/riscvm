from riscvm import u64

class Register:
    '''
    Represent register as unsigned 64bit integer
    '''
    def __init__(self, value = 0, name='register'):
        self._value = u64(value)
        self.name = name

    @property
    def value(self):
        return self._value

    @value.setter
    def value(self, value):
        self._value = u64(value)

    def __repr__(self):
        return f'{self.name}: 0x{self.value:016x}'

class FixedRegister(Register):
    '''
    Initial value would not change.

    >>> x0 = FixedRegister(42)
    >>> x0.value
    42
    >>> x0.value = 13
    >>> x0.value
    42
    '''

    @property
    def value(self):
        return self._value

    @value.setter
    def value(self, _):
        '''
        just ignore the new value
        '''
