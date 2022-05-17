from riscvm import error
from riscvm import RAM
from riscvm.rangemanager import RangeManger

import logging
logger = logging.getLogger(__name__)

class Bus:

    def __init__(self):
        # we need a better data structure
        # for device register and address lookup
        self.range_manager = RangeManger()
        self.devices = {}

    def get_device(self, address, size):
        range = self.range_manager.get_range(address, size)
        return (self.devices[range], range)

    def read(self, address, size):
        device, range = self.get_device(address, size)
        value = device.read(address - range[0], size)
        #logger.debug(f'*** read 0x{size:x} bytes from 0x{address:x}: 0x{value:x}')
        return value

    def write(self, address, size, value):
        device, range = self.get_device(address, size)
        try:
            device.write(address - range[0], size, value)
        except IndexError as e:
            error(f'fail to write value {value} to {address:016x} (device: [{len(device):x}] ({range[0]:x}, {range[1]:x})) with size {size}\n{e}')

    def add_device(self, device, range):
        self.range_manager.add_range(range)
        assert range not in self.devices
        self.devices[range] = device
        return self
