from binascii import unhexlify
import struct

from riscvm.instruction import Instruction, get_asm, info

data = bytes.fromhex('9307f5ff6354a00213071000930600001306f0ff130507009387f7ff3307d70093060500e398c7fe678000001305000067800000')

pc = 0
while pc + 4 <= len(data):
    ins = Instruction(struct.unpack('<i', data[pc:pc+4])[0])
    print(f'0x{pc:016X}: ({ins.value:08X}) {get_asm(ins, use_symbol=True, pc=pc)}')
    #print(info(ins))
    pc += 4