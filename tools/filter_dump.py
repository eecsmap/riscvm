import sys

# python tools/filter_dump.py <tests/dump_qemu.txt > ref_dump.txt

skip = False
for line in sys.stdin:
    if line.startswith('=> '):
        #print(line, end='')
        skip = True
    if line.startswith('ra'):
        skip = False
    if not skip:
        parts = line.split()
        if parts[0] in ['ra', 'sp', 'gp', 'tp', 't0', 't1', 't2',
        'fp', 's1', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7',
        's2', 's3', 's4', 's5', 's6', 's7', 's8', 's9', 's10', 's11',
        't3', 't4', 't5', 't6', 'pc']:
            print(parts[0], parts[1])
        else:
            print(line, end='')
