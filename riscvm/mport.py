import contextlib
import mmap
import os
import struct

def gen(filename, length=0):
    '''
    if length is 0, and filename does not exist, create file with at least 1 byte space.
    So that mmap object can be created successfully.

    if length is 0 and filename does exist, return whole mmap of the file.

    if length is non-zero, profile filename[0:length] as mmap object.

    if file does not have enough space, extend the file space to size of length.
    '''
    create_file = not os.path.isfile(filename)
    mode = 'w+b' if create_file else 'r+b'
    with open(filename, mode) as fileobj:
        total_length = fileobj.seek(0, 2)
        fileobj.seek(0)
        if create_file and length == 0: length = 1
        if length > total_length:
            fileobj.seek(length - 1)
            fileobj.write(b'\x00')
            fileobj.flush()
        with mmap.mmap(fileobj.fileno(),
                       length=0,
                       access=mmap.ACCESS_WRITE,
                       ) as mmap_obj:
            yield mmap_obj

@contextlib.contextmanager
def mio(filename, length=0):
    handle = gen(filename, length)
    yield next(handle)


class Port:
    
    # using struct type definition
    SIZE_MAP = {
        'b' : 1,
        'h' : 2,
        'i' : 4,
        'l' : 4,
        'q' : 8,
        'f' : 4,
        'd' : 8,
    }

    def __init__(self, filename, offset=0, port_type='B'):
        self.offset = offset
        self.port_type = port_type
        t = self.port_type.lower()
        t = t[1] if len(t) > 1 else t[0]
        self.end = self.offset + self.SIZE_MAP[t]
        self.mio_handle = gen(filename, length=self.end)
        self.io = next(self.mio_handle)

    @property
    def value(self):
        return struct.unpack(self.port_type, self.io[self.offset:self.end])[0]

    @value.setter
    def value(self, value):
        self.io[self.offset:self.end] = struct.pack(self.port_type, value)