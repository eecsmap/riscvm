from riscvm import error
from riscvm import RAM
from riscvm.rangemanager import RangeManger

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
        return device.read(address - range[0], size)

    def write(self, address, size, value):
        device, range = self.get_device(address, size)
        return device.write(address -range[0], size, value)

    def add_device(self, device, range):
        self.range_manager.add_range(range)
        assert range not in self.devices
        self.devices[range] = device
        return self
