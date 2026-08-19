from riscvm import error, gen

import logging
logger = logging.getLogger(__name__)

class RAM:

    def __init__(self, size=0):
        # handle hold the lifetime of mmap object
        self.size = size
        #self.handle = gen('mem.dat', size)
        #self.data = next(self.handle)
        self.data = bytearray(size)

    def __len__(self):
        return len(self.data)

    def read(self, address, size):
        '''
        values are all read as unsigned
        '''
        if size in (1, 2, 4, 8):
            return int.from_bytes(self.data[address:address + size], 'little')
        error(f'invalid address size {address}')

    def write(self, address, size, value):
        if size in (1, 2, 4, 8):
            self.data[address:address + size] = (value & ((1 << (size * 8)) - 1)).to_bytes(size, 'little')
        else:
            error(f'invalid address size {address}')

    def load(self, program):
        pos = 0
        for byte in program:
            self.data[pos] = byte
            pos += 1


def create_ram(size, content):
    size = max(size, len(content))
    ram = RAM(size)
    ram.data[:len(content)] = content
    return ram
