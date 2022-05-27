from bisect import bisect_left, bisect_right
from riscvm.exception import error

import logging
logger = logging.getLogger(__name__)

class RangeMangerException(Exception):
    pass

class RangeManger:

    def __init__(self):
        self.starts = []
        self.sizes = []

    def add_range(self, range):
        address = range[0]
        size = range[1]
        if address < 0 or size <= 0:
            error(f'invalid range {range}')
        if address + size < address:
            error(f'overflow range {range}')

        position = bisect_left(self.starts, address)
        if position == len(self.starts):
            if position > 0 and self.starts[-1] + self.sizes[-1] > address:
                error(f'range {range} cannot fit in {self}')
            self.starts.append(address)
            self.sizes.append(size)
            return

        assert position != len(self.starts)
        if self.starts[position] == address:
            error(f'range {range} cannot fit in {self}')
        
        assert self.starts[position] > address
        if address + size > self.starts[position]:
            error(f'range {range} cannot fit in {self}')
    
        self.starts.insert(position, address)
        self.sizes.insert(position, size)

    def get_range(self, address, size):
        '''
        return the range(s) holding access at given address with given size
        '''
        range = (address, size)
        if address < 0 or size <= 0:
            error(f'invalid range {range}')
        if address + size < address:
            error(f'overflow range {range}')

        # do not handle cross device access yet!
        position = bisect_right(self.starts, address) - 1
        if position < 0:
            error('no device mapped to this address range')
        target_start = self.starts[position]
        target_size = self.sizes[position]
        assert target_start <= address
        if address + size <= target_start + target_size:
            return (target_start, target_size)
        error(f'no device mapped to cover (0x{address:x}, 0x{address+size:x})')

    def __str__(self):
        s = ''    
        for start, size in zip(self.starts, self.sizes):
            s += (f'[{start:x} - {start + size:x})')
        return s

def test_rangemanger():
    range_manger = RangeManger()
    range_manger.add_range((-1, 1))
