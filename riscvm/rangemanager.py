from bisect import bisect_left, bisect_right


class RangeMangerException(Exception):
    pass

class RangeManger:

    def __init__(self):
        self.starts = []
        self.sizes = []

    def add_range(self, range):
        if range[0] < 0 or range[1] <= 0:
            raise RangeMangerException(f'invalid range {range}')
        if range[0] + range[1] < range[0]:
            raise RangeMangerException(f'overflow range {range}')

        position = bisect_left(self.starts, range[0])
        if position == len(self.starts):
            self.starts.append(range[0])
            self.sizes.append(range[1])
            return

        assert position != len(self.starts)
        if self.starts[position] == range[0]:
            raise RangeMangerException(f'range {range} cannot fit in')
        
        assert self.starts[position] > range[0]
        if range[0] + range[1] > self.starts[position]:
            raise RangeMangerException(f'range {range} cannot fit in')
    
        self.starts.insert(position, range[0])
        self.sizes.insert(position, range[1])

    def get_range(self, start_address, size):
        range = (start_address, size)
        if range[0] < 0 or range[1] <= 0:
            raise RangeMangerException(f'invalid range {range}')
        if range[0] + range[1] < range[0]:
            raise RangeMangerException(f'overflow range {range}')

        # do not handle cross device access yet!
        position = bisect_right(self.starts, range[0]) - 1
        if position < 0:
            raise RangeMangerException('no device mapped to this address range')
        target_start = self.starts[position]
        target_size = self.sizes[position]
        assert target_start <= range[0]
        if range[0] + range[1] > target_start + target_size:
            raise RangeMangerException('access beyond the device address range')
        return (target_start, target_size)

def test_rangemanger():
    range_manger = RangeManger()
    range_manger.add_range((-1, 1))

