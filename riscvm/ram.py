from riscvm import error, gen

class RAM:

    def __init__(self, size):
        # handle hold the lifetime of mmap object
        self.size = size
        self.handle = gen('mem.dat', size)
        self.data = next(self.handle)
        #self.data = [0 for i in range(size)]

    def __len__(self):
        return self.size

    def read(self, address, size):
        if size == 1:
            return self.data[address] & 0xff
        if size == 2:
            return (
                (self.data[address] & 0xff)
                | (self.data[address + 1] & 0xff) << 8)
        if size == 4:
            return (
                (self.data[address] & 0xff)
                | (self.data[address + 1] & 0xff) << 8
                | (self.data[address + 2] & 0xff) << 16
                | (self.data[address + 3] & 0xff) << 24)
        if size == 8:
            return (
                (self.data[address] & 0xff)
                | (self.data[address + 1] & 0xff) << 8
                | (self.data[address + 2] & 0xff) << 16
                | (self.data[address + 3] & 0xff) << 24
                | (self.data[address + 4] & 0xff) << 32
                | (self.data[address + 5] & 0xff) << 40
                | (self.data[address + 6] & 0xff) << 48
                | (self.data[address + 7] & 0xff) << 56)
        error(f'invalid address size {address}')

    def write(self, address, size, value):
        if size == 1:
            self.data[address] = value & 0xff
        elif size == 2:
            self.data[address] = value & 0xff
            self.data[address + 1] = (value >> 8) & 0xff
        elif size == 4:
            self.data[address] = value & 0xff
            self.data[address + 1] = (value >> 8) & 0xff
            self.data[address + 2] = (value >> 16) & 0xff 
            self.data[address + 3] = (value >> 24) & 0xff
        elif size == 8:
            self.data[address] = value & 0xff
            self.data[address + 1] = (value >> 8) & 0xff
            self.data[address + 2] = (value >> 16) & 0xff
            self.data[address + 3] = (value >> 24) & 0xff
            self.data[address + 4] = (value >> 32) & 0xff
            self.data[address + 5] = (value >> 40) & 0xff
            self.data[address + 6] = (value >> 48) & 0xff
            self.data[address + 7] = (value >> 56) & 0xff
        else:
            error(f'invalid address size {address}')

    def load(self, program):
        pos = 0
        for byte in program:
            self.data[pos] = byte
            pos += 1

def create_ram(content):
    ram = RAM(len(content))
    ram.data[:len(content)] = content
    return ram