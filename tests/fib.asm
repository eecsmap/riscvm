
fib.o:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <fib>:
   0:	fff50793          	addi	a5,a0,-1
   4:	02a05463          	blez	a0,2c <.L4>
   8:	00100713          	li	a4,1
   c:	00000693          	li	a3,0
  10:	fff00613          	li	a2,-1

0000000000000014 <.L3>:
  14:	00070513          	mv	a0,a4
  18:	fff78793          	addi	a5,a5,-1
  1c:	00d70733          	add	a4,a4,a3
  20:	00050693          	mv	a3,a0
  24:	fec798e3          	bne	a5,a2,14 <.L3>
  28:	00008067          	ret

000000000000002c <.L4>:
  2c:	00000513          	li	a0,0
  30:	00008067          	ret
