# 
set width 0
set height 0
set verbose off
set disassemble-next-line off
#set logging enabled on

#b *0x80000000
#b *0x800000f4
b *0x80000e72
commands
echo hello
c
end

set $count=1

while ($count <= 6460)
    x/i $pc
    si
    i r
    set $count=$count+1
end

quit