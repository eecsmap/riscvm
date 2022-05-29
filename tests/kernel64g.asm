
kernel/kernel:     file format elf64-littleriscv


Disassembly of section .text:

0000000080000000 <_entry>:
    80000000:	0000b117          	auipc	sp,0xb
    80000004:	18010113          	addi	sp,sp,384 # 8000b180 <stack0>
    80000008:	00001537          	lui	a0,0x1
    8000000c:	f14025f3          	csrr	a1,mhartid
    80000010:	00158593          	addi	a1,a1,1
    80000014:	02b50533          	mul	a0,a0,a1
    80000018:	00a10133          	add	sp,sp,a0
    8000001c:	094000ef          	jal	ra,800000b0 <start>

0000000080000020 <spin>:
    80000020:	0000006f          	j	80000020 <spin>

0000000080000024 <timerinit>:
// which arrive at timervec in kernelvec.S,
// which turns them into software interrupts for
// devintr() in trap.c.
void
timerinit()
{
    80000024:	ff010113          	addi	sp,sp,-16
    80000028:	00813423          	sd	s0,8(sp)
    8000002c:	01010413          	addi	s0,sp,16
// which hart (core) is this?
static inline uint64
r_mhartid()
{
  uint64 x;
  asm volatile("csrr %0, mhartid" : "=r" (x) );
    80000030:	f14027f3          	csrr	a5,mhartid
  // each CPU has a separate source of timer interrupts.
  int id = r_mhartid();
    80000034:	0007859b          	sext.w	a1,a5

  // ask the CLINT for a timer interrupt.
  int interval = 1000000; // cycles; about 1/10th second in qemu.
  *(uint64*)CLINT_MTIMECMP(id) = *(uint64*)CLINT_MTIME + interval;
    80000038:	0037979b          	slliw	a5,a5,0x3
    8000003c:	02004737          	lui	a4,0x2004
    80000040:	00e787b3          	add	a5,a5,a4
    80000044:	0200c737          	lui	a4,0x200c
    80000048:	ff873703          	ld	a4,-8(a4) # 200bff8 <_entry-0x7dff4008>
    8000004c:	000f4637          	lui	a2,0xf4
    80000050:	24060613          	addi	a2,a2,576 # f4240 <_entry-0x7ff0bdc0>
    80000054:	00c70733          	add	a4,a4,a2
    80000058:	00e7b023          	sd	a4,0(a5)

  // prepare information in scratch[] for timervec.
  // scratch[0..2] : space for timervec to save registers.
  // scratch[3] : address of CLINT MTIMECMP register.
  // scratch[4] : desired interval (in cycles) between timer interrupts.
  uint64 *scratch = &timer_scratch[id][0];
    8000005c:	00259693          	slli	a3,a1,0x2
    80000060:	00b686b3          	add	a3,a3,a1
    80000064:	00369693          	slli	a3,a3,0x3
    80000068:	0000b717          	auipc	a4,0xb
    8000006c:	fd870713          	addi	a4,a4,-40 # 8000b040 <timer_scratch>
    80000070:	00d70733          	add	a4,a4,a3
  scratch[3] = CLINT_MTIMECMP(id);
    80000074:	00f73c23          	sd	a5,24(a4)
  scratch[4] = interval;
    80000078:	02c73023          	sd	a2,32(a4)
}

static inline void 
w_mscratch(uint64 x)
{
  asm volatile("csrw mscratch, %0" : : "r" (x));
    8000007c:	34071073          	csrw	mscratch,a4
  asm volatile("csrw mtvec, %0" : : "r" (x));
    80000080:	00008797          	auipc	a5,0x8
    80000084:	dd078793          	addi	a5,a5,-560 # 80007e50 <timervec>
    80000088:	30579073          	csrw	mtvec,a5
  asm volatile("csrr %0, mstatus" : "=r" (x) );
    8000008c:	300027f3          	csrr	a5,mstatus

  // set the machine-mode trap handler.
  w_mtvec((uint64)timervec);

  // enable machine-mode interrupts.
  w_mstatus(r_mstatus() | MSTATUS_MIE);
    80000090:	0087e793          	ori	a5,a5,8
  asm volatile("csrw mstatus, %0" : : "r" (x));
    80000094:	30079073          	csrw	mstatus,a5
  asm volatile("csrr %0, mie" : "=r" (x) );
    80000098:	304027f3          	csrr	a5,mie

  // enable machine-mode timer interrupts.
  w_mie(r_mie() | MIE_MTIE);
    8000009c:	0807e793          	ori	a5,a5,128
  asm volatile("csrw mie, %0" : : "r" (x));
    800000a0:	30479073          	csrw	mie,a5
}
    800000a4:	00813403          	ld	s0,8(sp)
    800000a8:	01010113          	addi	sp,sp,16
    800000ac:	00008067          	ret

00000000800000b0 <start>:
{
    800000b0:	ff010113          	addi	sp,sp,-16
    800000b4:	00113423          	sd	ra,8(sp)
    800000b8:	00813023          	sd	s0,0(sp)
    800000bc:	01010413          	addi	s0,sp,16
  asm volatile("csrr %0, mstatus" : "=r" (x) );
    800000c0:	300027f3          	csrr	a5,mstatus
  x &= ~MSTATUS_MPP_MASK;
    800000c4:	ffffe737          	lui	a4,0xffffe
    800000c8:	7ff70713          	addi	a4,a4,2047 # ffffffffffffe7ff <end+0xffffffff7ffd67ff>
    800000cc:	00e7f7b3          	and	a5,a5,a4
  x |= MSTATUS_MPP_S;
    800000d0:	00001737          	lui	a4,0x1
    800000d4:	80070713          	addi	a4,a4,-2048 # 800 <_entry-0x7ffff800>
    800000d8:	00e7e7b3          	or	a5,a5,a4
  asm volatile("csrw mstatus, %0" : : "r" (x));
    800000dc:	30079073          	csrw	mstatus,a5
  asm volatile("csrw mepc, %0" : : "r" (x));
    800000e0:	00001797          	auipc	a5,0x1
    800000e4:	2d878793          	addi	a5,a5,728 # 800013b8 <main>
    800000e8:	34179073          	csrw	mepc,a5
  asm volatile("csrw satp, %0" : : "r" (x));
    800000ec:	00000793          	li	a5,0
    800000f0:	18079073          	csrw	satp,a5
  asm volatile("csrw medeleg, %0" : : "r" (x));
    800000f4:	000107b7          	lui	a5,0x10
    800000f8:	fff78793          	addi	a5,a5,-1 # ffff <_entry-0x7fff0001>
    800000fc:	30279073          	csrw	medeleg,a5
  asm volatile("csrw mideleg, %0" : : "r" (x));
    80000100:	30379073          	csrw	mideleg,a5
  asm volatile("csrr %0, sie" : "=r" (x) );
    80000104:	104027f3          	csrr	a5,sie
  w_sie(r_sie() | SIE_SEIE | SIE_STIE | SIE_SSIE);
    80000108:	2227e793          	ori	a5,a5,546
  asm volatile("csrw sie, %0" : : "r" (x));
    8000010c:	10479073          	csrw	sie,a5
  asm volatile("csrw pmpaddr0, %0" : : "r" (x));
    80000110:	fff00793          	li	a5,-1
    80000114:	00a7d793          	srli	a5,a5,0xa
    80000118:	3b079073          	csrw	pmpaddr0,a5
  asm volatile("csrw pmpcfg0, %0" : : "r" (x));
    8000011c:	00f00793          	li	a5,15
    80000120:	3a079073          	csrw	pmpcfg0,a5
  timerinit();
    80000124:	00000097          	auipc	ra,0x0
    80000128:	f00080e7          	jalr	-256(ra) # 80000024 <timerinit>
  asm volatile("csrr %0, mhartid" : "=r" (x) );
    8000012c:	f14027f3          	csrr	a5,mhartid
  w_tp(id);
    80000130:	0007879b          	sext.w	a5,a5
}

static inline void 
w_tp(uint64 x)
{
  asm volatile("mv tp, %0" : : "r" (x));
    80000134:	00078213          	mv	tp,a5
  asm volatile("mret");
    80000138:	30200073          	mret
}
    8000013c:	00813083          	ld	ra,8(sp)
    80000140:	00013403          	ld	s0,0(sp)
    80000144:	01010113          	addi	sp,sp,16
    80000148:	00008067          	ret

000000008000014c <consolewrite>:
//
// user write()s to the console go here.
//
int
consolewrite(int user_src, uint64 src, int n)
{
    8000014c:	fb010113          	addi	sp,sp,-80
    80000150:	04113423          	sd	ra,72(sp)
    80000154:	04813023          	sd	s0,64(sp)
    80000158:	02913c23          	sd	s1,56(sp)
    8000015c:	03213823          	sd	s2,48(sp)
    80000160:	03313423          	sd	s3,40(sp)
    80000164:	03413023          	sd	s4,32(sp)
    80000168:	01513c23          	sd	s5,24(sp)
    8000016c:	05010413          	addi	s0,sp,80
  int i;

  for(i = 0; i < n; i++){
    80000170:	06c05c63          	blez	a2,800001e8 <consolewrite+0x9c>
    80000174:	00050a13          	mv	s4,a0
    80000178:	00058493          	mv	s1,a1
    8000017c:	00060993          	mv	s3,a2
    80000180:	00000913          	li	s2,0
    char c;
    if(either_copyin(&c, user_src, src+i, 1) == -1)
    80000184:	fff00a93          	li	s5,-1
    80000188:	00100693          	li	a3,1
    8000018c:	00048613          	mv	a2,s1
    80000190:	000a0593          	mv	a1,s4
    80000194:	fbf40513          	addi	a0,s0,-65
    80000198:	00003097          	auipc	ra,0x3
    8000019c:	19c080e7          	jalr	412(ra) # 80003334 <either_copyin>
    800001a0:	03550063          	beq	a0,s5,800001c0 <consolewrite+0x74>
      break;
    uartputc(c);
    800001a4:	fbf44503          	lbu	a0,-65(s0)
    800001a8:	00001097          	auipc	ra,0x1
    800001ac:	9c0080e7          	jalr	-1600(ra) # 80000b68 <uartputc>
  for(i = 0; i < n; i++){
    800001b0:	0019091b          	addiw	s2,s2,1
    800001b4:	00148493          	addi	s1,s1,1
    800001b8:	fd2998e3          	bne	s3,s2,80000188 <consolewrite+0x3c>
    800001bc:	00098913          	mv	s2,s3
  }

  return i;
}
    800001c0:	00090513          	mv	a0,s2
    800001c4:	04813083          	ld	ra,72(sp)
    800001c8:	04013403          	ld	s0,64(sp)
    800001cc:	03813483          	ld	s1,56(sp)
    800001d0:	03013903          	ld	s2,48(sp)
    800001d4:	02813983          	ld	s3,40(sp)
    800001d8:	02013a03          	ld	s4,32(sp)
    800001dc:	01813a83          	ld	s5,24(sp)
    800001e0:	05010113          	addi	sp,sp,80
    800001e4:	00008067          	ret
  for(i = 0; i < n; i++){
    800001e8:	00000913          	li	s2,0
    800001ec:	fd5ff06f          	j	800001c0 <consolewrite+0x74>

00000000800001f0 <consoleread>:
// user_dist indicates whether dst is a user
// or kernel address.
//
int
consoleread(int user_dst, uint64 dst, int n)
{
    800001f0:	f9010113          	addi	sp,sp,-112
    800001f4:	06113423          	sd	ra,104(sp)
    800001f8:	06813023          	sd	s0,96(sp)
    800001fc:	04913c23          	sd	s1,88(sp)
    80000200:	05213823          	sd	s2,80(sp)
    80000204:	05313423          	sd	s3,72(sp)
    80000208:	05413023          	sd	s4,64(sp)
    8000020c:	03513c23          	sd	s5,56(sp)
    80000210:	03613823          	sd	s6,48(sp)
    80000214:	03713423          	sd	s7,40(sp)
    80000218:	03813023          	sd	s8,32(sp)
    8000021c:	01913c23          	sd	s9,24(sp)
    80000220:	01a13823          	sd	s10,16(sp)
    80000224:	07010413          	addi	s0,sp,112
    80000228:	00050a93          	mv	s5,a0
    8000022c:	00058a13          	mv	s4,a1
    80000230:	00060993          	mv	s3,a2
  uint target;
  int c;
  char cbuf;

  target = n;
    80000234:	00060b1b          	sext.w	s6,a2
  acquire(&cons.lock);
    80000238:	00013517          	auipc	a0,0x13
    8000023c:	f4850513          	addi	a0,a0,-184 # 80013180 <cons>
    80000240:	00001097          	auipc	ra,0x1
    80000244:	d8c080e7          	jalr	-628(ra) # 80000fcc <acquire>
  while(n > 0){
    // wait until interrupt handler has put some
    // input into cons.buffer.
    while(cons.r == cons.w){
    80000248:	00013497          	auipc	s1,0x13
    8000024c:	f3848493          	addi	s1,s1,-200 # 80013180 <cons>
      if(myproc()->killed){
        release(&cons.lock);
        return -1;
      }
      sleep(&cons.r, &cons.lock);
    80000250:	00013917          	auipc	s2,0x13
    80000254:	fc890913          	addi	s2,s2,-56 # 80013218 <cons+0x98>
    }

    c = cons.buf[cons.r++ % INPUT_BUF];

    if(c == C('D')){  // end-of-file
    80000258:	00400b93          	li	s7,4
      break;
    }

    // copy the input byte to the user-space buffer.
    cbuf = c;
    if(either_copyout(user_dst, dst, &cbuf, 1) == -1)
    8000025c:	fff00c13          	li	s8,-1
      break;

    dst++;
    --n;

    if(c == '\n'){
    80000260:	00a00c93          	li	s9,10
  while(n > 0){
    80000264:	09305263          	blez	s3,800002e8 <consoleread+0xf8>
    while(cons.r == cons.w){
    80000268:	0984a783          	lw	a5,152(s1)
    8000026c:	09c4a703          	lw	a4,156(s1)
    80000270:	02f71863          	bne	a4,a5,800002a0 <consoleread+0xb0>
      if(myproc()->killed){
    80000274:	00002097          	auipc	ra,0x2
    80000278:	1c8080e7          	jalr	456(ra) # 8000243c <myproc>
    8000027c:	02852783          	lw	a5,40(a0)
    80000280:	08079063          	bnez	a5,80000300 <consoleread+0x110>
      sleep(&cons.r, &cons.lock);
    80000284:	00048593          	mv	a1,s1
    80000288:	00090513          	mv	a0,s2
    8000028c:	00003097          	auipc	ra,0x3
    80000290:	b20080e7          	jalr	-1248(ra) # 80002dac <sleep>
    while(cons.r == cons.w){
    80000294:	0984a783          	lw	a5,152(s1)
    80000298:	09c4a703          	lw	a4,156(s1)
    8000029c:	fcf70ce3          	beq	a4,a5,80000274 <consoleread+0x84>
    c = cons.buf[cons.r++ % INPUT_BUF];
    800002a0:	0017871b          	addiw	a4,a5,1
    800002a4:	08e4ac23          	sw	a4,152(s1)
    800002a8:	07f7f713          	andi	a4,a5,127
    800002ac:	00e48733          	add	a4,s1,a4
    800002b0:	01874703          	lbu	a4,24(a4)
    800002b4:	00070d1b          	sext.w	s10,a4
    if(c == C('D')){  // end-of-file
    800002b8:	097d0a63          	beq	s10,s7,8000034c <consoleread+0x15c>
    cbuf = c;
    800002bc:	f8e40fa3          	sb	a4,-97(s0)
    if(either_copyout(user_dst, dst, &cbuf, 1) == -1)
    800002c0:	00100693          	li	a3,1
    800002c4:	f9f40613          	addi	a2,s0,-97
    800002c8:	000a0593          	mv	a1,s4
    800002cc:	000a8513          	mv	a0,s5
    800002d0:	00003097          	auipc	ra,0x3
    800002d4:	fd4080e7          	jalr	-44(ra) # 800032a4 <either_copyout>
    800002d8:	01850863          	beq	a0,s8,800002e8 <consoleread+0xf8>
    dst++;
    800002dc:	001a0a13          	addi	s4,s4,1
    --n;
    800002e0:	fff9899b          	addiw	s3,s3,-1
    if(c == '\n'){
    800002e4:	f99d10e3          	bne	s10,s9,80000264 <consoleread+0x74>
      // a whole line has arrived, return to
      // the user-level read().
      break;
    }
  }
  release(&cons.lock);
    800002e8:	00013517          	auipc	a0,0x13
    800002ec:	e9850513          	addi	a0,a0,-360 # 80013180 <cons>
    800002f0:	00001097          	auipc	ra,0x1
    800002f4:	dd4080e7          	jalr	-556(ra) # 800010c4 <release>

  return target - n;
    800002f8:	413b053b          	subw	a0,s6,s3
    800002fc:	0180006f          	j	80000314 <consoleread+0x124>
        release(&cons.lock);
    80000300:	00013517          	auipc	a0,0x13
    80000304:	e8050513          	addi	a0,a0,-384 # 80013180 <cons>
    80000308:	00001097          	auipc	ra,0x1
    8000030c:	dbc080e7          	jalr	-580(ra) # 800010c4 <release>
        return -1;
    80000310:	fff00513          	li	a0,-1
}
    80000314:	06813083          	ld	ra,104(sp)
    80000318:	06013403          	ld	s0,96(sp)
    8000031c:	05813483          	ld	s1,88(sp)
    80000320:	05013903          	ld	s2,80(sp)
    80000324:	04813983          	ld	s3,72(sp)
    80000328:	04013a03          	ld	s4,64(sp)
    8000032c:	03813a83          	ld	s5,56(sp)
    80000330:	03013b03          	ld	s6,48(sp)
    80000334:	02813b83          	ld	s7,40(sp)
    80000338:	02013c03          	ld	s8,32(sp)
    8000033c:	01813c83          	ld	s9,24(sp)
    80000340:	01013d03          	ld	s10,16(sp)
    80000344:	07010113          	addi	sp,sp,112
    80000348:	00008067          	ret
      if(n < target){
    8000034c:	0009871b          	sext.w	a4,s3
    80000350:	f9677ce3          	bgeu	a4,s6,800002e8 <consoleread+0xf8>
        cons.r--;
    80000354:	00013717          	auipc	a4,0x13
    80000358:	ecf72223          	sw	a5,-316(a4) # 80013218 <cons+0x98>
    8000035c:	f8dff06f          	j	800002e8 <consoleread+0xf8>

0000000080000360 <consputc>:
{
    80000360:	ff010113          	addi	sp,sp,-16
    80000364:	00113423          	sd	ra,8(sp)
    80000368:	00813023          	sd	s0,0(sp)
    8000036c:	01010413          	addi	s0,sp,16
  if(c == BACKSPACE){
    80000370:	10000793          	li	a5,256
    80000374:	00f50e63          	beq	a0,a5,80000390 <consputc+0x30>
    uartputc_sync(c);
    80000378:	00000097          	auipc	ra,0x0
    8000037c:	6d0080e7          	jalr	1744(ra) # 80000a48 <uartputc_sync>
}
    80000380:	00813083          	ld	ra,8(sp)
    80000384:	00013403          	ld	s0,0(sp)
    80000388:	01010113          	addi	sp,sp,16
    8000038c:	00008067          	ret
    uartputc_sync('\b'); uartputc_sync(' '); uartputc_sync('\b');
    80000390:	00800513          	li	a0,8
    80000394:	00000097          	auipc	ra,0x0
    80000398:	6b4080e7          	jalr	1716(ra) # 80000a48 <uartputc_sync>
    8000039c:	02000513          	li	a0,32
    800003a0:	00000097          	auipc	ra,0x0
    800003a4:	6a8080e7          	jalr	1704(ra) # 80000a48 <uartputc_sync>
    800003a8:	00800513          	li	a0,8
    800003ac:	00000097          	auipc	ra,0x0
    800003b0:	69c080e7          	jalr	1692(ra) # 80000a48 <uartputc_sync>
    800003b4:	fcdff06f          	j	80000380 <consputc+0x20>

00000000800003b8 <consoleintr>:
// do erase/kill processing, append to cons.buf,
// wake up consoleread() if a whole line has arrived.
//
void
consoleintr(int c)
{
    800003b8:	fe010113          	addi	sp,sp,-32
    800003bc:	00113c23          	sd	ra,24(sp)
    800003c0:	00813823          	sd	s0,16(sp)
    800003c4:	00913423          	sd	s1,8(sp)
    800003c8:	01213023          	sd	s2,0(sp)
    800003cc:	02010413          	addi	s0,sp,32
    800003d0:	00050493          	mv	s1,a0
  acquire(&cons.lock);
    800003d4:	00013517          	auipc	a0,0x13
    800003d8:	dac50513          	addi	a0,a0,-596 # 80013180 <cons>
    800003dc:	00001097          	auipc	ra,0x1
    800003e0:	bf0080e7          	jalr	-1040(ra) # 80000fcc <acquire>

  switch(c){
    800003e4:	01500793          	li	a5,21
    800003e8:	0cf48663          	beq	s1,a5,800004b4 <consoleintr+0xfc>
    800003ec:	0497c263          	blt	a5,s1,80000430 <consoleintr+0x78>
    800003f0:	00800793          	li	a5,8
    800003f4:	10f48a63          	beq	s1,a5,80000508 <consoleintr+0x150>
    800003f8:	01000793          	li	a5,16
    800003fc:	12f49e63          	bne	s1,a5,80000538 <consoleintr+0x180>
  case C('P'):  // Print process list.
    procdump();
    80000400:	00003097          	auipc	ra,0x3
    80000404:	fc4080e7          	jalr	-60(ra) # 800033c4 <procdump>
      }
    }
    break;
  }
  
  release(&cons.lock);
    80000408:	00013517          	auipc	a0,0x13
    8000040c:	d7850513          	addi	a0,a0,-648 # 80013180 <cons>
    80000410:	00001097          	auipc	ra,0x1
    80000414:	cb4080e7          	jalr	-844(ra) # 800010c4 <release>
}
    80000418:	01813083          	ld	ra,24(sp)
    8000041c:	01013403          	ld	s0,16(sp)
    80000420:	00813483          	ld	s1,8(sp)
    80000424:	00013903          	ld	s2,0(sp)
    80000428:	02010113          	addi	sp,sp,32
    8000042c:	00008067          	ret
  switch(c){
    80000430:	07f00793          	li	a5,127
    80000434:	0cf48a63          	beq	s1,a5,80000508 <consoleintr+0x150>
    if(c != 0 && cons.e-cons.r < INPUT_BUF){
    80000438:	00013717          	auipc	a4,0x13
    8000043c:	d4870713          	addi	a4,a4,-696 # 80013180 <cons>
    80000440:	0a072783          	lw	a5,160(a4)
    80000444:	09872703          	lw	a4,152(a4)
    80000448:	40e787bb          	subw	a5,a5,a4
    8000044c:	07f00713          	li	a4,127
    80000450:	faf76ce3          	bltu	a4,a5,80000408 <consoleintr+0x50>
      c = (c == '\r') ? '\n' : c;
    80000454:	00d00793          	li	a5,13
    80000458:	0ef48463          	beq	s1,a5,80000540 <consoleintr+0x188>
      consputc(c);
    8000045c:	00048513          	mv	a0,s1
    80000460:	00000097          	auipc	ra,0x0
    80000464:	f00080e7          	jalr	-256(ra) # 80000360 <consputc>
      cons.buf[cons.e++ % INPUT_BUF] = c;
    80000468:	00013797          	auipc	a5,0x13
    8000046c:	d1878793          	addi	a5,a5,-744 # 80013180 <cons>
    80000470:	0a07a703          	lw	a4,160(a5)
    80000474:	0017069b          	addiw	a3,a4,1
    80000478:	0006861b          	sext.w	a2,a3
    8000047c:	0ad7a023          	sw	a3,160(a5)
    80000480:	07f77713          	andi	a4,a4,127
    80000484:	00e787b3          	add	a5,a5,a4
    80000488:	00978c23          	sb	s1,24(a5)
      if(c == '\n' || c == C('D') || cons.e == cons.r+INPUT_BUF){
    8000048c:	00a00793          	li	a5,10
    80000490:	0ef48263          	beq	s1,a5,80000574 <consoleintr+0x1bc>
    80000494:	00400793          	li	a5,4
    80000498:	0cf48e63          	beq	s1,a5,80000574 <consoleintr+0x1bc>
    8000049c:	00013797          	auipc	a5,0x13
    800004a0:	d7c7a783          	lw	a5,-644(a5) # 80013218 <cons+0x98>
    800004a4:	0807879b          	addiw	a5,a5,128
    800004a8:	f6f610e3          	bne	a2,a5,80000408 <consoleintr+0x50>
      cons.buf[cons.e++ % INPUT_BUF] = c;
    800004ac:	00078613          	mv	a2,a5
    800004b0:	0c40006f          	j	80000574 <consoleintr+0x1bc>
    while(cons.e != cons.w &&
    800004b4:	00013717          	auipc	a4,0x13
    800004b8:	ccc70713          	addi	a4,a4,-820 # 80013180 <cons>
    800004bc:	0a072783          	lw	a5,160(a4)
    800004c0:	09c72703          	lw	a4,156(a4)
          cons.buf[(cons.e-1) % INPUT_BUF] != '\n'){
    800004c4:	00013497          	auipc	s1,0x13
    800004c8:	cbc48493          	addi	s1,s1,-836 # 80013180 <cons>
    while(cons.e != cons.w &&
    800004cc:	00a00913          	li	s2,10
    800004d0:	f2f70ce3          	beq	a4,a5,80000408 <consoleintr+0x50>
          cons.buf[(cons.e-1) % INPUT_BUF] != '\n'){
    800004d4:	fff7879b          	addiw	a5,a5,-1
    800004d8:	07f7f713          	andi	a4,a5,127
    800004dc:	00e48733          	add	a4,s1,a4
    while(cons.e != cons.w &&
    800004e0:	01874703          	lbu	a4,24(a4)
    800004e4:	f32702e3          	beq	a4,s2,80000408 <consoleintr+0x50>
      cons.e--;
    800004e8:	0af4a023          	sw	a5,160(s1)
      consputc(BACKSPACE);
    800004ec:	10000513          	li	a0,256
    800004f0:	00000097          	auipc	ra,0x0
    800004f4:	e70080e7          	jalr	-400(ra) # 80000360 <consputc>
    while(cons.e != cons.w &&
    800004f8:	0a04a783          	lw	a5,160(s1)
    800004fc:	09c4a703          	lw	a4,156(s1)
    80000500:	fcf71ae3          	bne	a4,a5,800004d4 <consoleintr+0x11c>
    80000504:	f05ff06f          	j	80000408 <consoleintr+0x50>
    if(cons.e != cons.w){
    80000508:	00013717          	auipc	a4,0x13
    8000050c:	c7870713          	addi	a4,a4,-904 # 80013180 <cons>
    80000510:	0a072783          	lw	a5,160(a4)
    80000514:	09c72703          	lw	a4,156(a4)
    80000518:	eef708e3          	beq	a4,a5,80000408 <consoleintr+0x50>
      cons.e--;
    8000051c:	fff7879b          	addiw	a5,a5,-1
    80000520:	00013717          	auipc	a4,0x13
    80000524:	d0f72023          	sw	a5,-768(a4) # 80013220 <cons+0xa0>
      consputc(BACKSPACE);
    80000528:	10000513          	li	a0,256
    8000052c:	00000097          	auipc	ra,0x0
    80000530:	e34080e7          	jalr	-460(ra) # 80000360 <consputc>
    80000534:	ed5ff06f          	j	80000408 <consoleintr+0x50>
    if(c != 0 && cons.e-cons.r < INPUT_BUF){
    80000538:	ec0488e3          	beqz	s1,80000408 <consoleintr+0x50>
    8000053c:	efdff06f          	j	80000438 <consoleintr+0x80>
      consputc(c);
    80000540:	00a00513          	li	a0,10
    80000544:	00000097          	auipc	ra,0x0
    80000548:	e1c080e7          	jalr	-484(ra) # 80000360 <consputc>
      cons.buf[cons.e++ % INPUT_BUF] = c;
    8000054c:	00013797          	auipc	a5,0x13
    80000550:	c3478793          	addi	a5,a5,-972 # 80013180 <cons>
    80000554:	0a07a703          	lw	a4,160(a5)
    80000558:	0017069b          	addiw	a3,a4,1
    8000055c:	0006861b          	sext.w	a2,a3
    80000560:	0ad7a023          	sw	a3,160(a5)
    80000564:	07f77713          	andi	a4,a4,127
    80000568:	00e787b3          	add	a5,a5,a4
    8000056c:	00a00713          	li	a4,10
    80000570:	00e78c23          	sb	a4,24(a5)
        cons.w = cons.e;
    80000574:	00013797          	auipc	a5,0x13
    80000578:	cac7a423          	sw	a2,-856(a5) # 8001321c <cons+0x9c>
        wakeup(&cons.r);
    8000057c:	00013517          	auipc	a0,0x13
    80000580:	c9c50513          	addi	a0,a0,-868 # 80013218 <cons+0x98>
    80000584:	00003097          	auipc	ra,0x3
    80000588:	a48080e7          	jalr	-1464(ra) # 80002fcc <wakeup>
    8000058c:	e7dff06f          	j	80000408 <consoleintr+0x50>

0000000080000590 <consoleinit>:

void
consoleinit(void)
{
    80000590:	ff010113          	addi	sp,sp,-16
    80000594:	00113423          	sd	ra,8(sp)
    80000598:	00813023          	sd	s0,0(sp)
    8000059c:	01010413          	addi	s0,sp,16
  initlock(&cons.lock, "cons");
    800005a0:	0000a597          	auipc	a1,0xa
    800005a4:	a7058593          	addi	a1,a1,-1424 # 8000a010 <etext+0x10>
    800005a8:	00013517          	auipc	a0,0x13
    800005ac:	bd850513          	addi	a0,a0,-1064 # 80013180 <cons>
    800005b0:	00001097          	auipc	ra,0x1
    800005b4:	938080e7          	jalr	-1736(ra) # 80000ee8 <initlock>

  uartinit();
    800005b8:	00000097          	auipc	ra,0x0
    800005bc:	42c080e7          	jalr	1068(ra) # 800009e4 <uartinit>

  // connect read and write system calls
  // to consoleread and consolewrite.
  devsw[CONSOLE].read = consoleread;
    800005c0:	00023797          	auipc	a5,0x23
    800005c4:	d5878793          	addi	a5,a5,-680 # 80023318 <devsw>
    800005c8:	00000717          	auipc	a4,0x0
    800005cc:	c2870713          	addi	a4,a4,-984 # 800001f0 <consoleread>
    800005d0:	00e7b823          	sd	a4,16(a5)
  devsw[CONSOLE].write = consolewrite;
    800005d4:	00000717          	auipc	a4,0x0
    800005d8:	b7870713          	addi	a4,a4,-1160 # 8000014c <consolewrite>
    800005dc:	00e7bc23          	sd	a4,24(a5)
}
    800005e0:	00813083          	ld	ra,8(sp)
    800005e4:	00013403          	ld	s0,0(sp)
    800005e8:	01010113          	addi	sp,sp,16
    800005ec:	00008067          	ret

00000000800005f0 <printint>:

static char digits[] = "0123456789abcdef";

static void
printint(int xx, int base, int sign)
{
    800005f0:	fd010113          	addi	sp,sp,-48
    800005f4:	02113423          	sd	ra,40(sp)
    800005f8:	02813023          	sd	s0,32(sp)
    800005fc:	00913c23          	sd	s1,24(sp)
    80000600:	01213823          	sd	s2,16(sp)
    80000604:	03010413          	addi	s0,sp,48
  char buf[16];
  int i;
  uint x;

  if(sign && (sign = xx < 0))
    80000608:	00060463          	beqz	a2,80000610 <printint+0x20>
    8000060c:	0a054c63          	bltz	a0,800006c4 <printint+0xd4>
    x = -xx;
  else
    x = xx;
    80000610:	0005051b          	sext.w	a0,a0
    80000614:	00000893          	li	a7,0
    80000618:	fd040693          	addi	a3,s0,-48

  i = 0;
    8000061c:	00000713          	li	a4,0
  do {
    buf[i++] = digits[x % base];
    80000620:	0005859b          	sext.w	a1,a1
    80000624:	0000a617          	auipc	a2,0xa
    80000628:	a1c60613          	addi	a2,a2,-1508 # 8000a040 <digits>
    8000062c:	00070813          	mv	a6,a4
    80000630:	0017071b          	addiw	a4,a4,1
    80000634:	02b577bb          	remuw	a5,a0,a1
    80000638:	02079793          	slli	a5,a5,0x20
    8000063c:	0207d793          	srli	a5,a5,0x20
    80000640:	00f607b3          	add	a5,a2,a5
    80000644:	0007c783          	lbu	a5,0(a5)
    80000648:	00f68023          	sb	a5,0(a3)
  } while((x /= base) != 0);
    8000064c:	0005079b          	sext.w	a5,a0
    80000650:	02b5553b          	divuw	a0,a0,a1
    80000654:	00168693          	addi	a3,a3,1
    80000658:	fcb7fae3          	bgeu	a5,a1,8000062c <printint+0x3c>

  if(sign)
    8000065c:	00088c63          	beqz	a7,80000674 <printint+0x84>
    buf[i++] = '-';
    80000660:	fe070793          	addi	a5,a4,-32
    80000664:	00878733          	add	a4,a5,s0
    80000668:	02d00793          	li	a5,45
    8000066c:	fef70823          	sb	a5,-16(a4)
    80000670:	0028071b          	addiw	a4,a6,2

  while(--i >= 0)
    80000674:	02e05c63          	blez	a4,800006ac <printint+0xbc>
    80000678:	fd040793          	addi	a5,s0,-48
    8000067c:	00e784b3          	add	s1,a5,a4
    80000680:	fff78913          	addi	s2,a5,-1
    80000684:	00e90933          	add	s2,s2,a4
    80000688:	fff7071b          	addiw	a4,a4,-1
    8000068c:	02071713          	slli	a4,a4,0x20
    80000690:	02075713          	srli	a4,a4,0x20
    80000694:	40e90933          	sub	s2,s2,a4
    consputc(buf[i]);
    80000698:	fff4c503          	lbu	a0,-1(s1)
    8000069c:	00000097          	auipc	ra,0x0
    800006a0:	cc4080e7          	jalr	-828(ra) # 80000360 <consputc>
  while(--i >= 0)
    800006a4:	fff48493          	addi	s1,s1,-1
    800006a8:	ff2498e3          	bne	s1,s2,80000698 <printint+0xa8>
}
    800006ac:	02813083          	ld	ra,40(sp)
    800006b0:	02013403          	ld	s0,32(sp)
    800006b4:	01813483          	ld	s1,24(sp)
    800006b8:	01013903          	ld	s2,16(sp)
    800006bc:	03010113          	addi	sp,sp,48
    800006c0:	00008067          	ret
    x = -xx;
    800006c4:	40a0053b          	negw	a0,a0
  if(sign && (sign = xx < 0))
    800006c8:	00100893          	li	a7,1
    x = -xx;
    800006cc:	f4dff06f          	j	80000618 <printint+0x28>

00000000800006d0 <panic>:
    release(&pr.lock);
}

void
panic(char *s)
{
    800006d0:	fe010113          	addi	sp,sp,-32
    800006d4:	00113c23          	sd	ra,24(sp)
    800006d8:	00813823          	sd	s0,16(sp)
    800006dc:	00913423          	sd	s1,8(sp)
    800006e0:	02010413          	addi	s0,sp,32
    800006e4:	00050493          	mv	s1,a0
  pr.locking = 0;
    800006e8:	00013797          	auipc	a5,0x13
    800006ec:	b407ac23          	sw	zero,-1192(a5) # 80013240 <pr+0x18>
  printf("panic: ");
    800006f0:	0000a517          	auipc	a0,0xa
    800006f4:	92850513          	addi	a0,a0,-1752 # 8000a018 <etext+0x18>
    800006f8:	00000097          	auipc	ra,0x0
    800006fc:	034080e7          	jalr	52(ra) # 8000072c <printf>
  printf(s);
    80000700:	00048513          	mv	a0,s1
    80000704:	00000097          	auipc	ra,0x0
    80000708:	028080e7          	jalr	40(ra) # 8000072c <printf>
  printf("\n");
    8000070c:	0000a517          	auipc	a0,0xa
    80000710:	9bc50513          	addi	a0,a0,-1604 # 8000a0c8 <digits+0x88>
    80000714:	00000097          	auipc	ra,0x0
    80000718:	018080e7          	jalr	24(ra) # 8000072c <printf>
  panicked = 1; // freeze uart output from other CPUs
    8000071c:	00100793          	li	a5,1
    80000720:	0000b717          	auipc	a4,0xb
    80000724:	8ef72023          	sw	a5,-1824(a4) # 8000b000 <panicked>
  for(;;)
    80000728:	0000006f          	j	80000728 <panic+0x58>

000000008000072c <printf>:
{
    8000072c:	f4010113          	addi	sp,sp,-192
    80000730:	06113c23          	sd	ra,120(sp)
    80000734:	06813823          	sd	s0,112(sp)
    80000738:	06913423          	sd	s1,104(sp)
    8000073c:	07213023          	sd	s2,96(sp)
    80000740:	05313c23          	sd	s3,88(sp)
    80000744:	05413823          	sd	s4,80(sp)
    80000748:	05513423          	sd	s5,72(sp)
    8000074c:	05613023          	sd	s6,64(sp)
    80000750:	03713c23          	sd	s7,56(sp)
    80000754:	03813823          	sd	s8,48(sp)
    80000758:	03913423          	sd	s9,40(sp)
    8000075c:	03a13023          	sd	s10,32(sp)
    80000760:	01b13c23          	sd	s11,24(sp)
    80000764:	08010413          	addi	s0,sp,128
    80000768:	00050a13          	mv	s4,a0
    8000076c:	00b43423          	sd	a1,8(s0)
    80000770:	00c43823          	sd	a2,16(s0)
    80000774:	00d43c23          	sd	a3,24(s0)
    80000778:	02e43023          	sd	a4,32(s0)
    8000077c:	02f43423          	sd	a5,40(s0)
    80000780:	03043823          	sd	a6,48(s0)
    80000784:	03143c23          	sd	a7,56(s0)
  locking = pr.locking;
    80000788:	00013d97          	auipc	s11,0x13
    8000078c:	ab8dad83          	lw	s11,-1352(s11) # 80013240 <pr+0x18>
  if(locking)
    80000790:	020d9e63          	bnez	s11,800007cc <printf+0xa0>
  if (fmt == 0)
    80000794:	040a0663          	beqz	s4,800007e0 <printf+0xb4>
  va_start(ap, fmt);
    80000798:	00840793          	addi	a5,s0,8
    8000079c:	f8f43423          	sd	a5,-120(s0)
  for(i = 0; (c = fmt[i] & 0xff) != 0; i++){
    800007a0:	000a4503          	lbu	a0,0(s4)
    800007a4:	1a050063          	beqz	a0,80000944 <printf+0x218>
    800007a8:	00000993          	li	s3,0
    if(c != '%'){
    800007ac:	02500a93          	li	s5,37
    switch(c){
    800007b0:	07000b93          	li	s7,112
  consputc('x');
    800007b4:	01000d13          	li	s10,16
    consputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    800007b8:	0000ab17          	auipc	s6,0xa
    800007bc:	888b0b13          	addi	s6,s6,-1912 # 8000a040 <digits>
    switch(c){
    800007c0:	07300c93          	li	s9,115
    800007c4:	06400c13          	li	s8,100
    800007c8:	0400006f          	j	80000808 <printf+0xdc>
    acquire(&pr.lock);
    800007cc:	00013517          	auipc	a0,0x13
    800007d0:	a5c50513          	addi	a0,a0,-1444 # 80013228 <pr>
    800007d4:	00000097          	auipc	ra,0x0
    800007d8:	7f8080e7          	jalr	2040(ra) # 80000fcc <acquire>
    800007dc:	fb9ff06f          	j	80000794 <printf+0x68>
    panic("null fmt");
    800007e0:	0000a517          	auipc	a0,0xa
    800007e4:	84850513          	addi	a0,a0,-1976 # 8000a028 <etext+0x28>
    800007e8:	00000097          	auipc	ra,0x0
    800007ec:	ee8080e7          	jalr	-280(ra) # 800006d0 <panic>
      consputc(c);
    800007f0:	00000097          	auipc	ra,0x0
    800007f4:	b70080e7          	jalr	-1168(ra) # 80000360 <consputc>
  for(i = 0; (c = fmt[i] & 0xff) != 0; i++){
    800007f8:	0019899b          	addiw	s3,s3,1
    800007fc:	013a07b3          	add	a5,s4,s3
    80000800:	0007c503          	lbu	a0,0(a5)
    80000804:	14050063          	beqz	a0,80000944 <printf+0x218>
    if(c != '%'){
    80000808:	ff5514e3          	bne	a0,s5,800007f0 <printf+0xc4>
    c = fmt[++i] & 0xff;
    8000080c:	0019899b          	addiw	s3,s3,1
    80000810:	013a07b3          	add	a5,s4,s3
    80000814:	0007c783          	lbu	a5,0(a5)
    80000818:	0007849b          	sext.w	s1,a5
    if(c == 0)
    8000081c:	12078463          	beqz	a5,80000944 <printf+0x218>
    switch(c){
    80000820:	07778263          	beq	a5,s7,80000884 <printf+0x158>
    80000824:	02fbfa63          	bgeu	s7,a5,80000858 <printf+0x12c>
    80000828:	0b978663          	beq	a5,s9,800008d4 <printf+0x1a8>
    8000082c:	07800713          	li	a4,120
    80000830:	0ee79c63          	bne	a5,a4,80000928 <printf+0x1fc>
      printint(va_arg(ap, int), 16, 1);
    80000834:	f8843783          	ld	a5,-120(s0)
    80000838:	00878713          	addi	a4,a5,8
    8000083c:	f8e43423          	sd	a4,-120(s0)
    80000840:	00100613          	li	a2,1
    80000844:	000d0593          	mv	a1,s10
    80000848:	0007a503          	lw	a0,0(a5)
    8000084c:	00000097          	auipc	ra,0x0
    80000850:	da4080e7          	jalr	-604(ra) # 800005f0 <printint>
      break;
    80000854:	fa5ff06f          	j	800007f8 <printf+0xcc>
    switch(c){
    80000858:	0d578063          	beq	a5,s5,80000918 <printf+0x1ec>
    8000085c:	0d879663          	bne	a5,s8,80000928 <printf+0x1fc>
      printint(va_arg(ap, int), 10, 1);
    80000860:	f8843783          	ld	a5,-120(s0)
    80000864:	00878713          	addi	a4,a5,8
    80000868:	f8e43423          	sd	a4,-120(s0)
    8000086c:	00100613          	li	a2,1
    80000870:	00a00593          	li	a1,10
    80000874:	0007a503          	lw	a0,0(a5)
    80000878:	00000097          	auipc	ra,0x0
    8000087c:	d78080e7          	jalr	-648(ra) # 800005f0 <printint>
      break;
    80000880:	f79ff06f          	j	800007f8 <printf+0xcc>
      printptr(va_arg(ap, uint64));
    80000884:	f8843783          	ld	a5,-120(s0)
    80000888:	00878713          	addi	a4,a5,8
    8000088c:	f8e43423          	sd	a4,-120(s0)
    80000890:	0007b903          	ld	s2,0(a5)
  consputc('0');
    80000894:	03000513          	li	a0,48
    80000898:	00000097          	auipc	ra,0x0
    8000089c:	ac8080e7          	jalr	-1336(ra) # 80000360 <consputc>
  consputc('x');
    800008a0:	07800513          	li	a0,120
    800008a4:	00000097          	auipc	ra,0x0
    800008a8:	abc080e7          	jalr	-1348(ra) # 80000360 <consputc>
    800008ac:	000d0493          	mv	s1,s10
    consputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    800008b0:	03c95793          	srli	a5,s2,0x3c
    800008b4:	00fb07b3          	add	a5,s6,a5
    800008b8:	0007c503          	lbu	a0,0(a5)
    800008bc:	00000097          	auipc	ra,0x0
    800008c0:	aa4080e7          	jalr	-1372(ra) # 80000360 <consputc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
    800008c4:	00491913          	slli	s2,s2,0x4
    800008c8:	fff4849b          	addiw	s1,s1,-1
    800008cc:	fe0492e3          	bnez	s1,800008b0 <printf+0x184>
    800008d0:	f29ff06f          	j	800007f8 <printf+0xcc>
      if((s = va_arg(ap, char*)) == 0)
    800008d4:	f8843783          	ld	a5,-120(s0)
    800008d8:	00878713          	addi	a4,a5,8
    800008dc:	f8e43423          	sd	a4,-120(s0)
    800008e0:	0007b483          	ld	s1,0(a5)
    800008e4:	02048263          	beqz	s1,80000908 <printf+0x1dc>
      for(; *s; s++)
    800008e8:	0004c503          	lbu	a0,0(s1)
    800008ec:	f00506e3          	beqz	a0,800007f8 <printf+0xcc>
        consputc(*s);
    800008f0:	00000097          	auipc	ra,0x0
    800008f4:	a70080e7          	jalr	-1424(ra) # 80000360 <consputc>
      for(; *s; s++)
    800008f8:	00148493          	addi	s1,s1,1
    800008fc:	0004c503          	lbu	a0,0(s1)
    80000900:	fe0518e3          	bnez	a0,800008f0 <printf+0x1c4>
    80000904:	ef5ff06f          	j	800007f8 <printf+0xcc>
        s = "(null)";
    80000908:	00009497          	auipc	s1,0x9
    8000090c:	71848493          	addi	s1,s1,1816 # 8000a020 <etext+0x20>
      for(; *s; s++)
    80000910:	02800513          	li	a0,40
    80000914:	fddff06f          	j	800008f0 <printf+0x1c4>
      consputc('%');
    80000918:	000a8513          	mv	a0,s5
    8000091c:	00000097          	auipc	ra,0x0
    80000920:	a44080e7          	jalr	-1468(ra) # 80000360 <consputc>
      break;
    80000924:	ed5ff06f          	j	800007f8 <printf+0xcc>
      consputc('%');
    80000928:	000a8513          	mv	a0,s5
    8000092c:	00000097          	auipc	ra,0x0
    80000930:	a34080e7          	jalr	-1484(ra) # 80000360 <consputc>
      consputc(c);
    80000934:	00048513          	mv	a0,s1
    80000938:	00000097          	auipc	ra,0x0
    8000093c:	a28080e7          	jalr	-1496(ra) # 80000360 <consputc>
      break;
    80000940:	eb9ff06f          	j	800007f8 <printf+0xcc>
  if(locking)
    80000944:	040d9063          	bnez	s11,80000984 <printf+0x258>
}
    80000948:	07813083          	ld	ra,120(sp)
    8000094c:	07013403          	ld	s0,112(sp)
    80000950:	06813483          	ld	s1,104(sp)
    80000954:	06013903          	ld	s2,96(sp)
    80000958:	05813983          	ld	s3,88(sp)
    8000095c:	05013a03          	ld	s4,80(sp)
    80000960:	04813a83          	ld	s5,72(sp)
    80000964:	04013b03          	ld	s6,64(sp)
    80000968:	03813b83          	ld	s7,56(sp)
    8000096c:	03013c03          	ld	s8,48(sp)
    80000970:	02813c83          	ld	s9,40(sp)
    80000974:	02013d03          	ld	s10,32(sp)
    80000978:	01813d83          	ld	s11,24(sp)
    8000097c:	0c010113          	addi	sp,sp,192
    80000980:	00008067          	ret
    release(&pr.lock);
    80000984:	00013517          	auipc	a0,0x13
    80000988:	8a450513          	addi	a0,a0,-1884 # 80013228 <pr>
    8000098c:	00000097          	auipc	ra,0x0
    80000990:	738080e7          	jalr	1848(ra) # 800010c4 <release>
}
    80000994:	fb5ff06f          	j	80000948 <printf+0x21c>

0000000080000998 <printfinit>:
    ;
}

void
printfinit(void)
{
    80000998:	fe010113          	addi	sp,sp,-32
    8000099c:	00113c23          	sd	ra,24(sp)
    800009a0:	00813823          	sd	s0,16(sp)
    800009a4:	00913423          	sd	s1,8(sp)
    800009a8:	02010413          	addi	s0,sp,32
  initlock(&pr.lock, "pr");
    800009ac:	00013497          	auipc	s1,0x13
    800009b0:	87c48493          	addi	s1,s1,-1924 # 80013228 <pr>
    800009b4:	00009597          	auipc	a1,0x9
    800009b8:	68458593          	addi	a1,a1,1668 # 8000a038 <etext+0x38>
    800009bc:	00048513          	mv	a0,s1
    800009c0:	00000097          	auipc	ra,0x0
    800009c4:	528080e7          	jalr	1320(ra) # 80000ee8 <initlock>
  pr.locking = 1;
    800009c8:	00100793          	li	a5,1
    800009cc:	00f4ac23          	sw	a5,24(s1)
}
    800009d0:	01813083          	ld	ra,24(sp)
    800009d4:	01013403          	ld	s0,16(sp)
    800009d8:	00813483          	ld	s1,8(sp)
    800009dc:	02010113          	addi	sp,sp,32
    800009e0:	00008067          	ret

00000000800009e4 <uartinit>:

void uartstart();

void
uartinit(void)
{
    800009e4:	ff010113          	addi	sp,sp,-16
    800009e8:	00113423          	sd	ra,8(sp)
    800009ec:	00813023          	sd	s0,0(sp)
    800009f0:	01010413          	addi	s0,sp,16
  // disable interrupts.
  WriteReg(IER, 0x00);
    800009f4:	100007b7          	lui	a5,0x10000
    800009f8:	000780a3          	sb	zero,1(a5) # 10000001 <_entry-0x6fffffff>

  // special mode to set baud rate.
  WriteReg(LCR, LCR_BAUD_LATCH);
    800009fc:	f8000713          	li	a4,-128
    80000a00:	00e781a3          	sb	a4,3(a5)

  // LSB for baud rate of 38.4K.
  WriteReg(0, 0x03);
    80000a04:	00300713          	li	a4,3
    80000a08:	00e78023          	sb	a4,0(a5)

  // MSB for baud rate of 38.4K.
  WriteReg(1, 0x00);
    80000a0c:	000780a3          	sb	zero,1(a5)

  // leave set-baud mode,
  // and set word length to 8 bits, no parity.
  WriteReg(LCR, LCR_EIGHT_BITS);
    80000a10:	00e781a3          	sb	a4,3(a5)

  // reset and enable FIFOs.
  WriteReg(FCR, FCR_FIFO_ENABLE | FCR_FIFO_CLEAR);
    80000a14:	00700693          	li	a3,7
    80000a18:	00d78123          	sb	a3,2(a5)

  // enable transmit and receive interrupts.
  WriteReg(IER, IER_TX_ENABLE | IER_RX_ENABLE);
    80000a1c:	00e780a3          	sb	a4,1(a5)

  initlock(&uart_tx_lock, "uart");
    80000a20:	00009597          	auipc	a1,0x9
    80000a24:	63858593          	addi	a1,a1,1592 # 8000a058 <digits+0x18>
    80000a28:	00013517          	auipc	a0,0x13
    80000a2c:	82050513          	addi	a0,a0,-2016 # 80013248 <uart_tx_lock>
    80000a30:	00000097          	auipc	ra,0x0
    80000a34:	4b8080e7          	jalr	1208(ra) # 80000ee8 <initlock>
}
    80000a38:	00813083          	ld	ra,8(sp)
    80000a3c:	00013403          	ld	s0,0(sp)
    80000a40:	01010113          	addi	sp,sp,16
    80000a44:	00008067          	ret

0000000080000a48 <uartputc_sync>:
// use interrupts, for use by kernel printf() and
// to echo characters. it spins waiting for the uart's
// output register to be empty.
void
uartputc_sync(int c)
{
    80000a48:	fe010113          	addi	sp,sp,-32
    80000a4c:	00113c23          	sd	ra,24(sp)
    80000a50:	00813823          	sd	s0,16(sp)
    80000a54:	00913423          	sd	s1,8(sp)
    80000a58:	02010413          	addi	s0,sp,32
    80000a5c:	00050493          	mv	s1,a0
  push_off();
    80000a60:	00000097          	auipc	ra,0x0
    80000a64:	4f8080e7          	jalr	1272(ra) # 80000f58 <push_off>

  if(panicked){
    80000a68:	0000a797          	auipc	a5,0xa
    80000a6c:	5987a783          	lw	a5,1432(a5) # 8000b000 <panicked>
    for(;;)
      ;
  }

  // wait for Transmit Holding Empty to be set in LSR.
  while((ReadReg(LSR) & LSR_TX_IDLE) == 0)
    80000a70:	10000737          	lui	a4,0x10000
  if(panicked){
    80000a74:	00078463          	beqz	a5,80000a7c <uartputc_sync+0x34>
    for(;;)
    80000a78:	0000006f          	j	80000a78 <uartputc_sync+0x30>
  while((ReadReg(LSR) & LSR_TX_IDLE) == 0)
    80000a7c:	00574783          	lbu	a5,5(a4) # 10000005 <_entry-0x6ffffffb>
    80000a80:	0207f793          	andi	a5,a5,32
    80000a84:	fe078ce3          	beqz	a5,80000a7c <uartputc_sync+0x34>
    ;
  WriteReg(THR, c);
    80000a88:	0ff4f513          	zext.b	a0,s1
    80000a8c:	100007b7          	lui	a5,0x10000
    80000a90:	00a78023          	sb	a0,0(a5) # 10000000 <_entry-0x70000000>

  pop_off();
    80000a94:	00000097          	auipc	ra,0x0
    80000a98:	5b0080e7          	jalr	1456(ra) # 80001044 <pop_off>
}
    80000a9c:	01813083          	ld	ra,24(sp)
    80000aa0:	01013403          	ld	s0,16(sp)
    80000aa4:	00813483          	ld	s1,8(sp)
    80000aa8:	02010113          	addi	sp,sp,32
    80000aac:	00008067          	ret

0000000080000ab0 <uartstart>:
// called from both the top- and bottom-half.
void
uartstart()
{
  while(1){
    if(uart_tx_w == uart_tx_r){
    80000ab0:	0000a797          	auipc	a5,0xa
    80000ab4:	5587b783          	ld	a5,1368(a5) # 8000b008 <uart_tx_r>
    80000ab8:	0000a717          	auipc	a4,0xa
    80000abc:	55873703          	ld	a4,1368(a4) # 8000b010 <uart_tx_w>
    80000ac0:	0af70263          	beq	a4,a5,80000b64 <uartstart+0xb4>
{
    80000ac4:	fc010113          	addi	sp,sp,-64
    80000ac8:	02113c23          	sd	ra,56(sp)
    80000acc:	02813823          	sd	s0,48(sp)
    80000ad0:	02913423          	sd	s1,40(sp)
    80000ad4:	03213023          	sd	s2,32(sp)
    80000ad8:	01313c23          	sd	s3,24(sp)
    80000adc:	01413823          	sd	s4,16(sp)
    80000ae0:	01513423          	sd	s5,8(sp)
    80000ae4:	04010413          	addi	s0,sp,64
      // transmit buffer is empty.
      return;
    }
    
    if((ReadReg(LSR) & LSR_TX_IDLE) == 0){
    80000ae8:	10000937          	lui	s2,0x10000
      // so we cannot give it another byte.
      // it will interrupt when it's ready for a new byte.
      return;
    }
    
    int c = uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE];
    80000aec:	00012a17          	auipc	s4,0x12
    80000af0:	75ca0a13          	addi	s4,s4,1884 # 80013248 <uart_tx_lock>
    uart_tx_r += 1;
    80000af4:	0000a497          	auipc	s1,0xa
    80000af8:	51448493          	addi	s1,s1,1300 # 8000b008 <uart_tx_r>
    if(uart_tx_w == uart_tx_r){
    80000afc:	0000a997          	auipc	s3,0xa
    80000b00:	51498993          	addi	s3,s3,1300 # 8000b010 <uart_tx_w>
    if((ReadReg(LSR) & LSR_TX_IDLE) == 0){
    80000b04:	00594703          	lbu	a4,5(s2) # 10000005 <_entry-0x6ffffffb>
    80000b08:	02077713          	andi	a4,a4,32
    80000b0c:	02070a63          	beqz	a4,80000b40 <uartstart+0x90>
    int c = uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE];
    80000b10:	01f7f713          	andi	a4,a5,31
    80000b14:	00ea0733          	add	a4,s4,a4
    80000b18:	01874a83          	lbu	s5,24(a4)
    uart_tx_r += 1;
    80000b1c:	00178793          	addi	a5,a5,1
    80000b20:	00f4b023          	sd	a5,0(s1)
    
    // maybe uartputc() is waiting for space in the buffer.
    wakeup(&uart_tx_r);
    80000b24:	00048513          	mv	a0,s1
    80000b28:	00002097          	auipc	ra,0x2
    80000b2c:	4a4080e7          	jalr	1188(ra) # 80002fcc <wakeup>
    
    WriteReg(THR, c);
    80000b30:	01590023          	sb	s5,0(s2)
    if(uart_tx_w == uart_tx_r){
    80000b34:	0004b783          	ld	a5,0(s1)
    80000b38:	0009b703          	ld	a4,0(s3)
    80000b3c:	fcf714e3          	bne	a4,a5,80000b04 <uartstart+0x54>
  }
}
    80000b40:	03813083          	ld	ra,56(sp)
    80000b44:	03013403          	ld	s0,48(sp)
    80000b48:	02813483          	ld	s1,40(sp)
    80000b4c:	02013903          	ld	s2,32(sp)
    80000b50:	01813983          	ld	s3,24(sp)
    80000b54:	01013a03          	ld	s4,16(sp)
    80000b58:	00813a83          	ld	s5,8(sp)
    80000b5c:	04010113          	addi	sp,sp,64
    80000b60:	00008067          	ret
    80000b64:	00008067          	ret

0000000080000b68 <uartputc>:
{
    80000b68:	fd010113          	addi	sp,sp,-48
    80000b6c:	02113423          	sd	ra,40(sp)
    80000b70:	02813023          	sd	s0,32(sp)
    80000b74:	00913c23          	sd	s1,24(sp)
    80000b78:	01213823          	sd	s2,16(sp)
    80000b7c:	01313423          	sd	s3,8(sp)
    80000b80:	01413023          	sd	s4,0(sp)
    80000b84:	03010413          	addi	s0,sp,48
    80000b88:	00050a13          	mv	s4,a0
  acquire(&uart_tx_lock);
    80000b8c:	00012517          	auipc	a0,0x12
    80000b90:	6bc50513          	addi	a0,a0,1724 # 80013248 <uart_tx_lock>
    80000b94:	00000097          	auipc	ra,0x0
    80000b98:	438080e7          	jalr	1080(ra) # 80000fcc <acquire>
  if(panicked){
    80000b9c:	0000a797          	auipc	a5,0xa
    80000ba0:	4647a783          	lw	a5,1124(a5) # 8000b000 <panicked>
    80000ba4:	00078463          	beqz	a5,80000bac <uartputc+0x44>
    for(;;)
    80000ba8:	0000006f          	j	80000ba8 <uartputc+0x40>
    if(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    80000bac:	0000a717          	auipc	a4,0xa
    80000bb0:	46473703          	ld	a4,1124(a4) # 8000b010 <uart_tx_w>
    80000bb4:	0000a797          	auipc	a5,0xa
    80000bb8:	4547b783          	ld	a5,1108(a5) # 8000b008 <uart_tx_r>
    80000bbc:	02078793          	addi	a5,a5,32
    80000bc0:	02e79e63          	bne	a5,a4,80000bfc <uartputc+0x94>
      sleep(&uart_tx_r, &uart_tx_lock);
    80000bc4:	00012997          	auipc	s3,0x12
    80000bc8:	68498993          	addi	s3,s3,1668 # 80013248 <uart_tx_lock>
    80000bcc:	0000a497          	auipc	s1,0xa
    80000bd0:	43c48493          	addi	s1,s1,1084 # 8000b008 <uart_tx_r>
    if(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    80000bd4:	0000a917          	auipc	s2,0xa
    80000bd8:	43c90913          	addi	s2,s2,1084 # 8000b010 <uart_tx_w>
      sleep(&uart_tx_r, &uart_tx_lock);
    80000bdc:	00098593          	mv	a1,s3
    80000be0:	00048513          	mv	a0,s1
    80000be4:	00002097          	auipc	ra,0x2
    80000be8:	1c8080e7          	jalr	456(ra) # 80002dac <sleep>
    if(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    80000bec:	00093703          	ld	a4,0(s2)
    80000bf0:	0004b783          	ld	a5,0(s1)
    80000bf4:	02078793          	addi	a5,a5,32
    80000bf8:	fee782e3          	beq	a5,a4,80000bdc <uartputc+0x74>
      uart_tx_buf[uart_tx_w % UART_TX_BUF_SIZE] = c;
    80000bfc:	00012497          	auipc	s1,0x12
    80000c00:	64c48493          	addi	s1,s1,1612 # 80013248 <uart_tx_lock>
    80000c04:	01f77793          	andi	a5,a4,31
    80000c08:	00f487b3          	add	a5,s1,a5
    80000c0c:	01478c23          	sb	s4,24(a5)
      uart_tx_w += 1;
    80000c10:	00170713          	addi	a4,a4,1
    80000c14:	0000a797          	auipc	a5,0xa
    80000c18:	3ee7be23          	sd	a4,1020(a5) # 8000b010 <uart_tx_w>
      uartstart();
    80000c1c:	00000097          	auipc	ra,0x0
    80000c20:	e94080e7          	jalr	-364(ra) # 80000ab0 <uartstart>
      release(&uart_tx_lock);
    80000c24:	00048513          	mv	a0,s1
    80000c28:	00000097          	auipc	ra,0x0
    80000c2c:	49c080e7          	jalr	1180(ra) # 800010c4 <release>
}
    80000c30:	02813083          	ld	ra,40(sp)
    80000c34:	02013403          	ld	s0,32(sp)
    80000c38:	01813483          	ld	s1,24(sp)
    80000c3c:	01013903          	ld	s2,16(sp)
    80000c40:	00813983          	ld	s3,8(sp)
    80000c44:	00013a03          	ld	s4,0(sp)
    80000c48:	03010113          	addi	sp,sp,48
    80000c4c:	00008067          	ret

0000000080000c50 <uartgetc>:

// read one input character from the UART.
// return -1 if none is waiting.
int
uartgetc(void)
{
    80000c50:	ff010113          	addi	sp,sp,-16
    80000c54:	00813423          	sd	s0,8(sp)
    80000c58:	01010413          	addi	s0,sp,16
  if(ReadReg(LSR) & 0x01){
    80000c5c:	100007b7          	lui	a5,0x10000
    80000c60:	0057c783          	lbu	a5,5(a5) # 10000005 <_entry-0x6ffffffb>
    80000c64:	0017f793          	andi	a5,a5,1
    80000c68:	00078c63          	beqz	a5,80000c80 <uartgetc+0x30>
    // input data is ready.
    return ReadReg(RHR);
    80000c6c:	100007b7          	lui	a5,0x10000
    80000c70:	0007c503          	lbu	a0,0(a5) # 10000000 <_entry-0x70000000>
  } else {
    return -1;
  }
}
    80000c74:	00813403          	ld	s0,8(sp)
    80000c78:	01010113          	addi	sp,sp,16
    80000c7c:	00008067          	ret
    return -1;
    80000c80:	fff00513          	li	a0,-1
    80000c84:	ff1ff06f          	j	80000c74 <uartgetc+0x24>

0000000080000c88 <uartintr>:
// handle a uart interrupt, raised because input has
// arrived, or the uart is ready for more output, or
// both. called from trap.c.
void
uartintr(void)
{
    80000c88:	fe010113          	addi	sp,sp,-32
    80000c8c:	00113c23          	sd	ra,24(sp)
    80000c90:	00813823          	sd	s0,16(sp)
    80000c94:	00913423          	sd	s1,8(sp)
    80000c98:	02010413          	addi	s0,sp,32
  // read and process incoming characters.
  while(1){
    int c = uartgetc();
    if(c == -1)
    80000c9c:	fff00493          	li	s1,-1
    80000ca0:	00c0006f          	j	80000cac <uartintr+0x24>
      break;
    consoleintr(c);
    80000ca4:	fffff097          	auipc	ra,0xfffff
    80000ca8:	714080e7          	jalr	1812(ra) # 800003b8 <consoleintr>
    int c = uartgetc();
    80000cac:	00000097          	auipc	ra,0x0
    80000cb0:	fa4080e7          	jalr	-92(ra) # 80000c50 <uartgetc>
    if(c == -1)
    80000cb4:	fe9518e3          	bne	a0,s1,80000ca4 <uartintr+0x1c>
  }

  // send buffered characters.
  acquire(&uart_tx_lock);
    80000cb8:	00012497          	auipc	s1,0x12
    80000cbc:	59048493          	addi	s1,s1,1424 # 80013248 <uart_tx_lock>
    80000cc0:	00048513          	mv	a0,s1
    80000cc4:	00000097          	auipc	ra,0x0
    80000cc8:	308080e7          	jalr	776(ra) # 80000fcc <acquire>
  uartstart();
    80000ccc:	00000097          	auipc	ra,0x0
    80000cd0:	de4080e7          	jalr	-540(ra) # 80000ab0 <uartstart>
  release(&uart_tx_lock);
    80000cd4:	00048513          	mv	a0,s1
    80000cd8:	00000097          	auipc	ra,0x0
    80000cdc:	3ec080e7          	jalr	1004(ra) # 800010c4 <release>
}
    80000ce0:	01813083          	ld	ra,24(sp)
    80000ce4:	01013403          	ld	s0,16(sp)
    80000ce8:	00813483          	ld	s1,8(sp)
    80000cec:	02010113          	addi	sp,sp,32
    80000cf0:	00008067          	ret

0000000080000cf4 <kfree>:
// which normally should have been returned by a
// call to kalloc().  (The exception is when
// initializing the allocator; see kinit above.)
void
kfree(void *pa)
{
    80000cf4:	fe010113          	addi	sp,sp,-32
    80000cf8:	00113c23          	sd	ra,24(sp)
    80000cfc:	00813823          	sd	s0,16(sp)
    80000d00:	00913423          	sd	s1,8(sp)
    80000d04:	01213023          	sd	s2,0(sp)
    80000d08:	02010413          	addi	s0,sp,32
  struct run *r;

  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    80000d0c:	03451793          	slli	a5,a0,0x34
    80000d10:	06079a63          	bnez	a5,80000d84 <kfree+0x90>
    80000d14:	00050493          	mv	s1,a0
    80000d18:	00027797          	auipc	a5,0x27
    80000d1c:	2e878793          	addi	a5,a5,744 # 80028000 <end>
    80000d20:	06f56263          	bltu	a0,a5,80000d84 <kfree+0x90>
    80000d24:	01100793          	li	a5,17
    80000d28:	01b79793          	slli	a5,a5,0x1b
    80000d2c:	04f57c63          	bgeu	a0,a5,80000d84 <kfree+0x90>
    panic("kfree");

  // Fill with junk to catch dangling refs.
  memset(pa, 1, PGSIZE);
    80000d30:	00001637          	lui	a2,0x1
    80000d34:	00100593          	li	a1,1
    80000d38:	00000097          	auipc	ra,0x0
    80000d3c:	3ec080e7          	jalr	1004(ra) # 80001124 <memset>

  r = (struct run*)pa;

  acquire(&kmem.lock);
    80000d40:	00012917          	auipc	s2,0x12
    80000d44:	54090913          	addi	s2,s2,1344 # 80013280 <kmem>
    80000d48:	00090513          	mv	a0,s2
    80000d4c:	00000097          	auipc	ra,0x0
    80000d50:	280080e7          	jalr	640(ra) # 80000fcc <acquire>
  r->next = kmem.freelist;
    80000d54:	01893783          	ld	a5,24(s2)
    80000d58:	00f4b023          	sd	a5,0(s1)
  kmem.freelist = r;
    80000d5c:	00993c23          	sd	s1,24(s2)
  release(&kmem.lock);
    80000d60:	00090513          	mv	a0,s2
    80000d64:	00000097          	auipc	ra,0x0
    80000d68:	360080e7          	jalr	864(ra) # 800010c4 <release>
}
    80000d6c:	01813083          	ld	ra,24(sp)
    80000d70:	01013403          	ld	s0,16(sp)
    80000d74:	00813483          	ld	s1,8(sp)
    80000d78:	00013903          	ld	s2,0(sp)
    80000d7c:	02010113          	addi	sp,sp,32
    80000d80:	00008067          	ret
    panic("kfree");
    80000d84:	00009517          	auipc	a0,0x9
    80000d88:	2dc50513          	addi	a0,a0,732 # 8000a060 <digits+0x20>
    80000d8c:	00000097          	auipc	ra,0x0
    80000d90:	944080e7          	jalr	-1724(ra) # 800006d0 <panic>

0000000080000d94 <freerange>:
{
    80000d94:	fd010113          	addi	sp,sp,-48
    80000d98:	02113423          	sd	ra,40(sp)
    80000d9c:	02813023          	sd	s0,32(sp)
    80000da0:	00913c23          	sd	s1,24(sp)
    80000da4:	01213823          	sd	s2,16(sp)
    80000da8:	01313423          	sd	s3,8(sp)
    80000dac:	01413023          	sd	s4,0(sp)
    80000db0:	03010413          	addi	s0,sp,48
  p = (char*)PGROUNDUP((uint64)pa_start);
    80000db4:	000017b7          	lui	a5,0x1
    80000db8:	fff78713          	addi	a4,a5,-1 # fff <_entry-0x7ffff001>
    80000dbc:	00e504b3          	add	s1,a0,a4
    80000dc0:	fffff737          	lui	a4,0xfffff
    80000dc4:	00e4f4b3          	and	s1,s1,a4
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000dc8:	00f484b3          	add	s1,s1,a5
    80000dcc:	0295e263          	bltu	a1,s1,80000df0 <freerange+0x5c>
    80000dd0:	00058913          	mv	s2,a1
    kfree(p);
    80000dd4:	fffffa37          	lui	s4,0xfffff
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000dd8:	000019b7          	lui	s3,0x1
    kfree(p);
    80000ddc:	01448533          	add	a0,s1,s4
    80000de0:	00000097          	auipc	ra,0x0
    80000de4:	f14080e7          	jalr	-236(ra) # 80000cf4 <kfree>
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000de8:	013484b3          	add	s1,s1,s3
    80000dec:	fe9978e3          	bgeu	s2,s1,80000ddc <freerange+0x48>
}
    80000df0:	02813083          	ld	ra,40(sp)
    80000df4:	02013403          	ld	s0,32(sp)
    80000df8:	01813483          	ld	s1,24(sp)
    80000dfc:	01013903          	ld	s2,16(sp)
    80000e00:	00813983          	ld	s3,8(sp)
    80000e04:	00013a03          	ld	s4,0(sp)
    80000e08:	03010113          	addi	sp,sp,48
    80000e0c:	00008067          	ret

0000000080000e10 <kinit>:
{
    80000e10:	ff010113          	addi	sp,sp,-16
    80000e14:	00113423          	sd	ra,8(sp)
    80000e18:	00813023          	sd	s0,0(sp)
    80000e1c:	01010413          	addi	s0,sp,16
  initlock(&kmem.lock, "kmem");
    80000e20:	00009597          	auipc	a1,0x9
    80000e24:	24858593          	addi	a1,a1,584 # 8000a068 <digits+0x28>
    80000e28:	00012517          	auipc	a0,0x12
    80000e2c:	45850513          	addi	a0,a0,1112 # 80013280 <kmem>
    80000e30:	00000097          	auipc	ra,0x0
    80000e34:	0b8080e7          	jalr	184(ra) # 80000ee8 <initlock>
  freerange(end, (void*)PHYSTOP);
    80000e38:	01100593          	li	a1,17
    80000e3c:	01b59593          	slli	a1,a1,0x1b
    80000e40:	00027517          	auipc	a0,0x27
    80000e44:	1c050513          	addi	a0,a0,448 # 80028000 <end>
    80000e48:	00000097          	auipc	ra,0x0
    80000e4c:	f4c080e7          	jalr	-180(ra) # 80000d94 <freerange>
}
    80000e50:	00813083          	ld	ra,8(sp)
    80000e54:	00013403          	ld	s0,0(sp)
    80000e58:	01010113          	addi	sp,sp,16
    80000e5c:	00008067          	ret

0000000080000e60 <kalloc>:
// Allocate one 4096-byte page of physical memory.
// Returns a pointer that the kernel can use.
// Returns 0 if the memory cannot be allocated.
void *
kalloc(void)
{
    80000e60:	fe010113          	addi	sp,sp,-32
    80000e64:	00113c23          	sd	ra,24(sp)
    80000e68:	00813823          	sd	s0,16(sp)
    80000e6c:	00913423          	sd	s1,8(sp)
    80000e70:	02010413          	addi	s0,sp,32
  struct run *r;

  acquire(&kmem.lock);
    80000e74:	00012497          	auipc	s1,0x12
    80000e78:	40c48493          	addi	s1,s1,1036 # 80013280 <kmem>
    80000e7c:	00048513          	mv	a0,s1
    80000e80:	00000097          	auipc	ra,0x0
    80000e84:	14c080e7          	jalr	332(ra) # 80000fcc <acquire>
  r = kmem.freelist;
    80000e88:	0184b483          	ld	s1,24(s1)
  if(r)
    80000e8c:	04048463          	beqz	s1,80000ed4 <kalloc+0x74>
    kmem.freelist = r->next;
    80000e90:	0004b783          	ld	a5,0(s1)
    80000e94:	00012517          	auipc	a0,0x12
    80000e98:	3ec50513          	addi	a0,a0,1004 # 80013280 <kmem>
    80000e9c:	00f53c23          	sd	a5,24(a0)
  release(&kmem.lock);
    80000ea0:	00000097          	auipc	ra,0x0
    80000ea4:	224080e7          	jalr	548(ra) # 800010c4 <release>

  if(r)
    memset((char*)r, 5, PGSIZE); // fill with junk
    80000ea8:	00001637          	lui	a2,0x1
    80000eac:	00500593          	li	a1,5
    80000eb0:	00048513          	mv	a0,s1
    80000eb4:	00000097          	auipc	ra,0x0
    80000eb8:	270080e7          	jalr	624(ra) # 80001124 <memset>
  return (void*)r;
}
    80000ebc:	00048513          	mv	a0,s1
    80000ec0:	01813083          	ld	ra,24(sp)
    80000ec4:	01013403          	ld	s0,16(sp)
    80000ec8:	00813483          	ld	s1,8(sp)
    80000ecc:	02010113          	addi	sp,sp,32
    80000ed0:	00008067          	ret
  release(&kmem.lock);
    80000ed4:	00012517          	auipc	a0,0x12
    80000ed8:	3ac50513          	addi	a0,a0,940 # 80013280 <kmem>
    80000edc:	00000097          	auipc	ra,0x0
    80000ee0:	1e8080e7          	jalr	488(ra) # 800010c4 <release>
  if(r)
    80000ee4:	fd9ff06f          	j	80000ebc <kalloc+0x5c>

0000000080000ee8 <initlock>:
#include "proc.h"
#include "defs.h"

void
initlock(struct spinlock *lk, char *name)
{
    80000ee8:	ff010113          	addi	sp,sp,-16
    80000eec:	00813423          	sd	s0,8(sp)
    80000ef0:	01010413          	addi	s0,sp,16
  lk->name = name;
    80000ef4:	00b53423          	sd	a1,8(a0)
  lk->locked = 0;
    80000ef8:	00052023          	sw	zero,0(a0)
  lk->cpu = 0;
    80000efc:	00053823          	sd	zero,16(a0)
}
    80000f00:	00813403          	ld	s0,8(sp)
    80000f04:	01010113          	addi	sp,sp,16
    80000f08:	00008067          	ret

0000000080000f0c <holding>:
// Interrupts must be off.
int
holding(struct spinlock *lk)
{
  int r;
  r = (lk->locked && lk->cpu == mycpu());
    80000f0c:	00052783          	lw	a5,0(a0)
    80000f10:	00079663          	bnez	a5,80000f1c <holding+0x10>
    80000f14:	00000513          	li	a0,0
  return r;
}
    80000f18:	00008067          	ret
{
    80000f1c:	fe010113          	addi	sp,sp,-32
    80000f20:	00113c23          	sd	ra,24(sp)
    80000f24:	00813823          	sd	s0,16(sp)
    80000f28:	00913423          	sd	s1,8(sp)
    80000f2c:	02010413          	addi	s0,sp,32
  r = (lk->locked && lk->cpu == mycpu());
    80000f30:	01053483          	ld	s1,16(a0)
    80000f34:	00001097          	auipc	ra,0x1
    80000f38:	4d8080e7          	jalr	1240(ra) # 8000240c <mycpu>
    80000f3c:	40a48533          	sub	a0,s1,a0
    80000f40:	00153513          	seqz	a0,a0
}
    80000f44:	01813083          	ld	ra,24(sp)
    80000f48:	01013403          	ld	s0,16(sp)
    80000f4c:	00813483          	ld	s1,8(sp)
    80000f50:	02010113          	addi	sp,sp,32
    80000f54:	00008067          	ret

0000000080000f58 <push_off>:
// it takes two pop_off()s to undo two push_off()s.  Also, if interrupts
// are initially off, then push_off, pop_off leaves them off.

void
push_off(void)
{
    80000f58:	fe010113          	addi	sp,sp,-32
    80000f5c:	00113c23          	sd	ra,24(sp)
    80000f60:	00813823          	sd	s0,16(sp)
    80000f64:	00913423          	sd	s1,8(sp)
    80000f68:	02010413          	addi	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000f6c:	100024f3          	csrr	s1,sstatus
    80000f70:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    80000f74:	ffd7f793          	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80000f78:	10079073          	csrw	sstatus,a5
  int old = intr_get();

  intr_off();
  if(mycpu()->noff == 0)
    80000f7c:	00001097          	auipc	ra,0x1
    80000f80:	490080e7          	jalr	1168(ra) # 8000240c <mycpu>
    80000f84:	07852783          	lw	a5,120(a0)
    80000f88:	02078663          	beqz	a5,80000fb4 <push_off+0x5c>
    mycpu()->intena = old;
  mycpu()->noff += 1;
    80000f8c:	00001097          	auipc	ra,0x1
    80000f90:	480080e7          	jalr	1152(ra) # 8000240c <mycpu>
    80000f94:	07852783          	lw	a5,120(a0)
    80000f98:	0017879b          	addiw	a5,a5,1
    80000f9c:	06f52c23          	sw	a5,120(a0)
}
    80000fa0:	01813083          	ld	ra,24(sp)
    80000fa4:	01013403          	ld	s0,16(sp)
    80000fa8:	00813483          	ld	s1,8(sp)
    80000fac:	02010113          	addi	sp,sp,32
    80000fb0:	00008067          	ret
    mycpu()->intena = old;
    80000fb4:	00001097          	auipc	ra,0x1
    80000fb8:	458080e7          	jalr	1112(ra) # 8000240c <mycpu>
  return (x & SSTATUS_SIE) != 0;
    80000fbc:	0014d493          	srli	s1,s1,0x1
    80000fc0:	0014f493          	andi	s1,s1,1
    80000fc4:	06952e23          	sw	s1,124(a0)
    80000fc8:	fc5ff06f          	j	80000f8c <push_off+0x34>

0000000080000fcc <acquire>:
{
    80000fcc:	fe010113          	addi	sp,sp,-32
    80000fd0:	00113c23          	sd	ra,24(sp)
    80000fd4:	00813823          	sd	s0,16(sp)
    80000fd8:	00913423          	sd	s1,8(sp)
    80000fdc:	02010413          	addi	s0,sp,32
    80000fe0:	00050493          	mv	s1,a0
  push_off(); // disable interrupts to avoid deadlock.
    80000fe4:	00000097          	auipc	ra,0x0
    80000fe8:	f74080e7          	jalr	-140(ra) # 80000f58 <push_off>
  if(holding(lk))
    80000fec:	00048513          	mv	a0,s1
    80000ff0:	00000097          	auipc	ra,0x0
    80000ff4:	f1c080e7          	jalr	-228(ra) # 80000f0c <holding>
  while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
    80000ff8:	00100713          	li	a4,1
  if(holding(lk))
    80000ffc:	02051c63          	bnez	a0,80001034 <acquire+0x68>
  while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
    80001000:	00070793          	mv	a5,a4
    80001004:	0cf4a7af          	amoswap.w.aq	a5,a5,(s1)
    80001008:	0007879b          	sext.w	a5,a5
    8000100c:	fe079ae3          	bnez	a5,80001000 <acquire+0x34>
  __sync_synchronize();
    80001010:	0ff0000f          	fence
  lk->cpu = mycpu();
    80001014:	00001097          	auipc	ra,0x1
    80001018:	3f8080e7          	jalr	1016(ra) # 8000240c <mycpu>
    8000101c:	00a4b823          	sd	a0,16(s1)
}
    80001020:	01813083          	ld	ra,24(sp)
    80001024:	01013403          	ld	s0,16(sp)
    80001028:	00813483          	ld	s1,8(sp)
    8000102c:	02010113          	addi	sp,sp,32
    80001030:	00008067          	ret
    panic("acquire");
    80001034:	00009517          	auipc	a0,0x9
    80001038:	03c50513          	addi	a0,a0,60 # 8000a070 <digits+0x30>
    8000103c:	fffff097          	auipc	ra,0xfffff
    80001040:	694080e7          	jalr	1684(ra) # 800006d0 <panic>

0000000080001044 <pop_off>:

void
pop_off(void)
{
    80001044:	ff010113          	addi	sp,sp,-16
    80001048:	00113423          	sd	ra,8(sp)
    8000104c:	00813023          	sd	s0,0(sp)
    80001050:	01010413          	addi	s0,sp,16
  struct cpu *c = mycpu();
    80001054:	00001097          	auipc	ra,0x1
    80001058:	3b8080e7          	jalr	952(ra) # 8000240c <mycpu>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    8000105c:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80001060:	0027f793          	andi	a5,a5,2
  if(intr_get())
    80001064:	04079063          	bnez	a5,800010a4 <pop_off+0x60>
    panic("pop_off - interruptible");
  if(c->noff < 1)
    80001068:	07852783          	lw	a5,120(a0)
    8000106c:	04f05463          	blez	a5,800010b4 <pop_off+0x70>
    panic("pop_off");
  c->noff -= 1;
    80001070:	fff7879b          	addiw	a5,a5,-1
    80001074:	0007871b          	sext.w	a4,a5
    80001078:	06f52c23          	sw	a5,120(a0)
  if(c->noff == 0 && c->intena)
    8000107c:	00071c63          	bnez	a4,80001094 <pop_off+0x50>
    80001080:	07c52783          	lw	a5,124(a0)
    80001084:	00078863          	beqz	a5,80001094 <pop_off+0x50>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80001088:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    8000108c:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80001090:	10079073          	csrw	sstatus,a5
    intr_on();
}
    80001094:	00813083          	ld	ra,8(sp)
    80001098:	00013403          	ld	s0,0(sp)
    8000109c:	01010113          	addi	sp,sp,16
    800010a0:	00008067          	ret
    panic("pop_off - interruptible");
    800010a4:	00009517          	auipc	a0,0x9
    800010a8:	fd450513          	addi	a0,a0,-44 # 8000a078 <digits+0x38>
    800010ac:	fffff097          	auipc	ra,0xfffff
    800010b0:	624080e7          	jalr	1572(ra) # 800006d0 <panic>
    panic("pop_off");
    800010b4:	00009517          	auipc	a0,0x9
    800010b8:	fdc50513          	addi	a0,a0,-36 # 8000a090 <digits+0x50>
    800010bc:	fffff097          	auipc	ra,0xfffff
    800010c0:	614080e7          	jalr	1556(ra) # 800006d0 <panic>

00000000800010c4 <release>:
{
    800010c4:	fe010113          	addi	sp,sp,-32
    800010c8:	00113c23          	sd	ra,24(sp)
    800010cc:	00813823          	sd	s0,16(sp)
    800010d0:	00913423          	sd	s1,8(sp)
    800010d4:	02010413          	addi	s0,sp,32
    800010d8:	00050493          	mv	s1,a0
  if(!holding(lk))
    800010dc:	00000097          	auipc	ra,0x0
    800010e0:	e30080e7          	jalr	-464(ra) # 80000f0c <holding>
    800010e4:	02050863          	beqz	a0,80001114 <release+0x50>
  lk->cpu = 0;
    800010e8:	0004b823          	sd	zero,16(s1)
  __sync_synchronize();
    800010ec:	0ff0000f          	fence
  __sync_lock_release(&lk->locked);
    800010f0:	0f50000f          	fence	iorw,ow
    800010f4:	0804a02f          	amoswap.w	zero,zero,(s1)
  pop_off();
    800010f8:	00000097          	auipc	ra,0x0
    800010fc:	f4c080e7          	jalr	-180(ra) # 80001044 <pop_off>
}
    80001100:	01813083          	ld	ra,24(sp)
    80001104:	01013403          	ld	s0,16(sp)
    80001108:	00813483          	ld	s1,8(sp)
    8000110c:	02010113          	addi	sp,sp,32
    80001110:	00008067          	ret
    panic("release");
    80001114:	00009517          	auipc	a0,0x9
    80001118:	f8450513          	addi	a0,a0,-124 # 8000a098 <digits+0x58>
    8000111c:	fffff097          	auipc	ra,0xfffff
    80001120:	5b4080e7          	jalr	1460(ra) # 800006d0 <panic>

0000000080001124 <memset>:
#include "types.h"

void*
memset(void *dst, int c, uint n)
{
    80001124:	ff010113          	addi	sp,sp,-16
    80001128:	00813423          	sd	s0,8(sp)
    8000112c:	01010413          	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
    80001130:	02060063          	beqz	a2,80001150 <memset+0x2c>
    80001134:	00050793          	mv	a5,a0
    80001138:	02061613          	slli	a2,a2,0x20
    8000113c:	02065613          	srli	a2,a2,0x20
    80001140:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
    80001144:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
    80001148:	00178793          	addi	a5,a5,1
    8000114c:	fee79ce3          	bne	a5,a4,80001144 <memset+0x20>
  }
  return dst;
}
    80001150:	00813403          	ld	s0,8(sp)
    80001154:	01010113          	addi	sp,sp,16
    80001158:	00008067          	ret

000000008000115c <memcmp>:

int
memcmp(const void *v1, const void *v2, uint n)
{
    8000115c:	ff010113          	addi	sp,sp,-16
    80001160:	00813423          	sd	s0,8(sp)
    80001164:	01010413          	addi	s0,sp,16
  const uchar *s1, *s2;

  s1 = v1;
  s2 = v2;
  while(n-- > 0){
    80001168:	04060463          	beqz	a2,800011b0 <memcmp+0x54>
    8000116c:	fff6069b          	addiw	a3,a2,-1 # fff <_entry-0x7ffff001>
    80001170:	02069693          	slli	a3,a3,0x20
    80001174:	0206d693          	srli	a3,a3,0x20
    80001178:	00168693          	addi	a3,a3,1
    8000117c:	00d506b3          	add	a3,a0,a3
    if(*s1 != *s2)
    80001180:	00054783          	lbu	a5,0(a0)
    80001184:	0005c703          	lbu	a4,0(a1)
    80001188:	00e79c63          	bne	a5,a4,800011a0 <memcmp+0x44>
      return *s1 - *s2;
    s1++, s2++;
    8000118c:	00150513          	addi	a0,a0,1
    80001190:	00158593          	addi	a1,a1,1
  while(n-- > 0){
    80001194:	fed516e3          	bne	a0,a3,80001180 <memcmp+0x24>
  }

  return 0;
    80001198:	00000513          	li	a0,0
    8000119c:	0080006f          	j	800011a4 <memcmp+0x48>
      return *s1 - *s2;
    800011a0:	40e7853b          	subw	a0,a5,a4
}
    800011a4:	00813403          	ld	s0,8(sp)
    800011a8:	01010113          	addi	sp,sp,16
    800011ac:	00008067          	ret
  return 0;
    800011b0:	00000513          	li	a0,0
    800011b4:	ff1ff06f          	j	800011a4 <memcmp+0x48>

00000000800011b8 <memmove>:

void*
memmove(void *dst, const void *src, uint n)
{
    800011b8:	ff010113          	addi	sp,sp,-16
    800011bc:	00813423          	sd	s0,8(sp)
    800011c0:	01010413          	addi	s0,sp,16
  const char *s;
  char *d;

  if(n == 0)
    800011c4:	02060663          	beqz	a2,800011f0 <memmove+0x38>
    return dst;
  
  s = src;
  d = dst;
  if(s < d && s + n > d){
    800011c8:	02a5ea63          	bltu	a1,a0,800011fc <memmove+0x44>
    s += n;
    d += n;
    while(n-- > 0)
      *--d = *--s;
  } else
    while(n-- > 0)
    800011cc:	02061613          	slli	a2,a2,0x20
    800011d0:	02065613          	srli	a2,a2,0x20
    800011d4:	00c587b3          	add	a5,a1,a2
{
    800011d8:	00050713          	mv	a4,a0
      *d++ = *s++;
    800011dc:	00158593          	addi	a1,a1,1
    800011e0:	00170713          	addi	a4,a4,1 # fffffffffffff001 <end+0xffffffff7ffd7001>
    800011e4:	fff5c683          	lbu	a3,-1(a1)
    800011e8:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
    800011ec:	fef598e3          	bne	a1,a5,800011dc <memmove+0x24>

  return dst;
}
    800011f0:	00813403          	ld	s0,8(sp)
    800011f4:	01010113          	addi	sp,sp,16
    800011f8:	00008067          	ret
  if(s < d && s + n > d){
    800011fc:	02061693          	slli	a3,a2,0x20
    80001200:	0206d693          	srli	a3,a3,0x20
    80001204:	00d58733          	add	a4,a1,a3
    80001208:	fce572e3          	bgeu	a0,a4,800011cc <memmove+0x14>
    d += n;
    8000120c:	00d506b3          	add	a3,a0,a3
    while(n-- > 0)
    80001210:	fff6079b          	addiw	a5,a2,-1
    80001214:	02079793          	slli	a5,a5,0x20
    80001218:	0207d793          	srli	a5,a5,0x20
    8000121c:	fff7c793          	not	a5,a5
    80001220:	00f707b3          	add	a5,a4,a5
      *--d = *--s;
    80001224:	fff70713          	addi	a4,a4,-1
    80001228:	fff68693          	addi	a3,a3,-1
    8000122c:	00074603          	lbu	a2,0(a4)
    80001230:	00c68023          	sb	a2,0(a3)
    while(n-- > 0)
    80001234:	fee798e3          	bne	a5,a4,80001224 <memmove+0x6c>
    80001238:	fb9ff06f          	j	800011f0 <memmove+0x38>

000000008000123c <memcpy>:

// memcpy exists to placate GCC.  Use memmove.
void*
memcpy(void *dst, const void *src, uint n)
{
    8000123c:	ff010113          	addi	sp,sp,-16
    80001240:	00113423          	sd	ra,8(sp)
    80001244:	00813023          	sd	s0,0(sp)
    80001248:	01010413          	addi	s0,sp,16
  return memmove(dst, src, n);
    8000124c:	00000097          	auipc	ra,0x0
    80001250:	f6c080e7          	jalr	-148(ra) # 800011b8 <memmove>
}
    80001254:	00813083          	ld	ra,8(sp)
    80001258:	00013403          	ld	s0,0(sp)
    8000125c:	01010113          	addi	sp,sp,16
    80001260:	00008067          	ret

0000000080001264 <strncmp>:

int
strncmp(const char *p, const char *q, uint n)
{
    80001264:	ff010113          	addi	sp,sp,-16
    80001268:	00813423          	sd	s0,8(sp)
    8000126c:	01010413          	addi	s0,sp,16
  while(n > 0 && *p && *p == *q)
    80001270:	02060663          	beqz	a2,8000129c <strncmp+0x38>
    80001274:	00054783          	lbu	a5,0(a0)
    80001278:	02078663          	beqz	a5,800012a4 <strncmp+0x40>
    8000127c:	0005c703          	lbu	a4,0(a1)
    80001280:	02f71263          	bne	a4,a5,800012a4 <strncmp+0x40>
    n--, p++, q++;
    80001284:	fff6061b          	addiw	a2,a2,-1
    80001288:	00150513          	addi	a0,a0,1
    8000128c:	00158593          	addi	a1,a1,1
  while(n > 0 && *p && *p == *q)
    80001290:	fe0612e3          	bnez	a2,80001274 <strncmp+0x10>
  if(n == 0)
    return 0;
    80001294:	00000513          	li	a0,0
    80001298:	01c0006f          	j	800012b4 <strncmp+0x50>
    8000129c:	00000513          	li	a0,0
    800012a0:	0140006f          	j	800012b4 <strncmp+0x50>
  if(n == 0)
    800012a4:	00060e63          	beqz	a2,800012c0 <strncmp+0x5c>
  return (uchar)*p - (uchar)*q;
    800012a8:	00054503          	lbu	a0,0(a0)
    800012ac:	0005c783          	lbu	a5,0(a1)
    800012b0:	40f5053b          	subw	a0,a0,a5
}
    800012b4:	00813403          	ld	s0,8(sp)
    800012b8:	01010113          	addi	sp,sp,16
    800012bc:	00008067          	ret
    return 0;
    800012c0:	00000513          	li	a0,0
    800012c4:	ff1ff06f          	j	800012b4 <strncmp+0x50>

00000000800012c8 <strncpy>:

char*
strncpy(char *s, const char *t, int n)
{
    800012c8:	ff010113          	addi	sp,sp,-16
    800012cc:	00813423          	sd	s0,8(sp)
    800012d0:	01010413          	addi	s0,sp,16
  char *os;

  os = s;
  while(n-- > 0 && (*s++ = *t++) != 0)
    800012d4:	00050713          	mv	a4,a0
    800012d8:	00060813          	mv	a6,a2
    800012dc:	fff6061b          	addiw	a2,a2,-1
    800012e0:	01005c63          	blez	a6,800012f8 <strncpy+0x30>
    800012e4:	00170713          	addi	a4,a4,1
    800012e8:	0005c783          	lbu	a5,0(a1)
    800012ec:	fef70fa3          	sb	a5,-1(a4)
    800012f0:	00158593          	addi	a1,a1,1
    800012f4:	fe0792e3          	bnez	a5,800012d8 <strncpy+0x10>
    ;
  while(n-- > 0)
    800012f8:	00070693          	mv	a3,a4
    800012fc:	00c05e63          	blez	a2,80001318 <strncpy+0x50>
    *s++ = 0;
    80001300:	00168693          	addi	a3,a3,1
    80001304:	fe068fa3          	sb	zero,-1(a3)
  while(n-- > 0)
    80001308:	40d707bb          	subw	a5,a4,a3
    8000130c:	fff7879b          	addiw	a5,a5,-1
    80001310:	010787bb          	addw	a5,a5,a6
    80001314:	fef046e3          	bgtz	a5,80001300 <strncpy+0x38>
  return os;
}
    80001318:	00813403          	ld	s0,8(sp)
    8000131c:	01010113          	addi	sp,sp,16
    80001320:	00008067          	ret

0000000080001324 <safestrcpy>:

// Like strncpy but guaranteed to NUL-terminate.
char*
safestrcpy(char *s, const char *t, int n)
{
    80001324:	ff010113          	addi	sp,sp,-16
    80001328:	00813423          	sd	s0,8(sp)
    8000132c:	01010413          	addi	s0,sp,16
  char *os;

  os = s;
  if(n <= 0)
    80001330:	02c05a63          	blez	a2,80001364 <safestrcpy+0x40>
    80001334:	fff6069b          	addiw	a3,a2,-1
    80001338:	02069693          	slli	a3,a3,0x20
    8000133c:	0206d693          	srli	a3,a3,0x20
    80001340:	00d586b3          	add	a3,a1,a3
    80001344:	00050793          	mv	a5,a0
    return os;
  while(--n > 0 && (*s++ = *t++) != 0)
    80001348:	00d58c63          	beq	a1,a3,80001360 <safestrcpy+0x3c>
    8000134c:	00158593          	addi	a1,a1,1
    80001350:	00178793          	addi	a5,a5,1
    80001354:	fff5c703          	lbu	a4,-1(a1)
    80001358:	fee78fa3          	sb	a4,-1(a5)
    8000135c:	fe0716e3          	bnez	a4,80001348 <safestrcpy+0x24>
    ;
  *s = 0;
    80001360:	00078023          	sb	zero,0(a5)
  return os;
}
    80001364:	00813403          	ld	s0,8(sp)
    80001368:	01010113          	addi	sp,sp,16
    8000136c:	00008067          	ret

0000000080001370 <strlen>:

int
strlen(const char *s)
{
    80001370:	ff010113          	addi	sp,sp,-16
    80001374:	00813423          	sd	s0,8(sp)
    80001378:	01010413          	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
    8000137c:	00054783          	lbu	a5,0(a0)
    80001380:	02078863          	beqz	a5,800013b0 <strlen+0x40>
    80001384:	00150513          	addi	a0,a0,1
    80001388:	00050793          	mv	a5,a0
    8000138c:	00100693          	li	a3,1
    80001390:	40a686bb          	subw	a3,a3,a0
    80001394:	00f6853b          	addw	a0,a3,a5
    80001398:	00178793          	addi	a5,a5,1
    8000139c:	fff7c703          	lbu	a4,-1(a5)
    800013a0:	fe071ae3          	bnez	a4,80001394 <strlen+0x24>
    ;
  return n;
}
    800013a4:	00813403          	ld	s0,8(sp)
    800013a8:	01010113          	addi	sp,sp,16
    800013ac:	00008067          	ret
  for(n = 0; s[n]; n++)
    800013b0:	00000513          	li	a0,0
    800013b4:	ff1ff06f          	j	800013a4 <strlen+0x34>

00000000800013b8 <main>:
volatile static int started = 0;

// start() jumps here in supervisor mode on all CPUs.
void
main()
{
    800013b8:	ff010113          	addi	sp,sp,-16
    800013bc:	00113423          	sd	ra,8(sp)
    800013c0:	00813023          	sd	s0,0(sp)
    800013c4:	01010413          	addi	s0,sp,16
  if(cpuid() == 0){
    800013c8:	00001097          	auipc	ra,0x1
    800013cc:	024080e7          	jalr	36(ra) # 800023ec <cpuid>
    virtio_disk_init(); // emulated hard disk
    userinit();      // first user process
    __sync_synchronize();
    started = 1;
  } else {
    while(started == 0)
    800013d0:	0000a717          	auipc	a4,0xa
    800013d4:	c4870713          	addi	a4,a4,-952 # 8000b018 <started>
  if(cpuid() == 0){
    800013d8:	04050863          	beqz	a0,80001428 <main+0x70>
    while(started == 0)
    800013dc:	00072783          	lw	a5,0(a4)
    800013e0:	0007879b          	sext.w	a5,a5
    800013e4:	fe078ce3          	beqz	a5,800013dc <main+0x24>
      ;
    __sync_synchronize();
    800013e8:	0ff0000f          	fence
    printf("hart %d starting\n", cpuid());
    800013ec:	00001097          	auipc	ra,0x1
    800013f0:	000080e7          	jalr	ra # 800023ec <cpuid>
    800013f4:	00050593          	mv	a1,a0
    800013f8:	00009517          	auipc	a0,0x9
    800013fc:	cc050513          	addi	a0,a0,-832 # 8000a0b8 <digits+0x78>
    80001400:	fffff097          	auipc	ra,0xfffff
    80001404:	32c080e7          	jalr	812(ra) # 8000072c <printf>
    kvminithart();    // turn on paging
    80001408:	00000097          	auipc	ra,0x0
    8000140c:	0dc080e7          	jalr	220(ra) # 800014e4 <kvminithart>
    trapinithart();   // install kernel trap vector
    80001410:	00002097          	auipc	ra,0x2
    80001414:	154080e7          	jalr	340(ra) # 80003564 <trapinithart>
    plicinithart();   // ask PLIC for device interrupts
    80001418:	00007097          	auipc	ra,0x7
    8000141c:	aa0080e7          	jalr	-1376(ra) # 80007eb8 <plicinithart>
  }

  scheduler();        
    80001420:	00001097          	auipc	ra,0x1
    80001424:	744080e7          	jalr	1860(ra) # 80002b64 <scheduler>
    consoleinit();
    80001428:	fffff097          	auipc	ra,0xfffff
    8000142c:	168080e7          	jalr	360(ra) # 80000590 <consoleinit>
    printfinit();
    80001430:	fffff097          	auipc	ra,0xfffff
    80001434:	568080e7          	jalr	1384(ra) # 80000998 <printfinit>
    printf("\n");
    80001438:	00009517          	auipc	a0,0x9
    8000143c:	c9050513          	addi	a0,a0,-880 # 8000a0c8 <digits+0x88>
    80001440:	fffff097          	auipc	ra,0xfffff
    80001444:	2ec080e7          	jalr	748(ra) # 8000072c <printf>
    printf("xv6 kernel is booting\n");
    80001448:	00009517          	auipc	a0,0x9
    8000144c:	c5850513          	addi	a0,a0,-936 # 8000a0a0 <digits+0x60>
    80001450:	fffff097          	auipc	ra,0xfffff
    80001454:	2dc080e7          	jalr	732(ra) # 8000072c <printf>
    printf("\n");
    80001458:	00009517          	auipc	a0,0x9
    8000145c:	c7050513          	addi	a0,a0,-912 # 8000a0c8 <digits+0x88>
    80001460:	fffff097          	auipc	ra,0xfffff
    80001464:	2cc080e7          	jalr	716(ra) # 8000072c <printf>
    kinit();         // physical page allocator
    80001468:	00000097          	auipc	ra,0x0
    8000146c:	9a8080e7          	jalr	-1624(ra) # 80000e10 <kinit>
    kvminit();       // create kernel page table
    80001470:	00000097          	auipc	ra,0x0
    80001474:	47c080e7          	jalr	1148(ra) # 800018ec <kvminit>
    kvminithart();   // turn on paging
    80001478:	00000097          	auipc	ra,0x0
    8000147c:	06c080e7          	jalr	108(ra) # 800014e4 <kvminithart>
    procinit();      // process table
    80001480:	00001097          	auipc	ra,0x1
    80001484:	e84080e7          	jalr	-380(ra) # 80002304 <procinit>
    trapinit();      // trap vectors
    80001488:	00002097          	auipc	ra,0x2
    8000148c:	0a4080e7          	jalr	164(ra) # 8000352c <trapinit>
    trapinithart();  // install kernel trap vector
    80001490:	00002097          	auipc	ra,0x2
    80001494:	0d4080e7          	jalr	212(ra) # 80003564 <trapinithart>
    plicinit();      // set up interrupt controller
    80001498:	00007097          	auipc	ra,0x7
    8000149c:	9f8080e7          	jalr	-1544(ra) # 80007e90 <plicinit>
    plicinithart();  // ask PLIC for device interrupts
    800014a0:	00007097          	auipc	ra,0x7
    800014a4:	a18080e7          	jalr	-1512(ra) # 80007eb8 <plicinithart>
    binit();         // buffer cache
    800014a8:	00003097          	auipc	ra,0x3
    800014ac:	b24080e7          	jalr	-1244(ra) # 80003fcc <binit>
    iinit();         // inode table
    800014b0:	00003097          	auipc	ra,0x3
    800014b4:	3f4080e7          	jalr	1012(ra) # 800048a4 <iinit>
    fileinit();      // file table
    800014b8:	00005097          	auipc	ra,0x5
    800014bc:	9f0080e7          	jalr	-1552(ra) # 80005ea8 <fileinit>
    virtio_disk_init(); // emulated hard disk
    800014c0:	00007097          	auipc	ra,0x7
    800014c4:	b8c080e7          	jalr	-1140(ra) # 8000804c <virtio_disk_init>
    userinit();      // first user process
    800014c8:	00001097          	auipc	ra,0x1
    800014cc:	398080e7          	jalr	920(ra) # 80002860 <userinit>
    __sync_synchronize();
    800014d0:	0ff0000f          	fence
    started = 1;
    800014d4:	00100793          	li	a5,1
    800014d8:	0000a717          	auipc	a4,0xa
    800014dc:	b4f72023          	sw	a5,-1216(a4) # 8000b018 <started>
    800014e0:	f41ff06f          	j	80001420 <main+0x68>

00000000800014e4 <kvminithart>:

// Switch h/w page table register to the kernel's page table,
// and enable paging.
void
kvminithart()
{
    800014e4:	ff010113          	addi	sp,sp,-16
    800014e8:	00813423          	sd	s0,8(sp)
    800014ec:	01010413          	addi	s0,sp,16
  w_satp(MAKE_SATP(kernel_pagetable));
    800014f0:	0000a797          	auipc	a5,0xa
    800014f4:	b307b783          	ld	a5,-1232(a5) # 8000b020 <kernel_pagetable>
    800014f8:	00c7d793          	srli	a5,a5,0xc
    800014fc:	fff00713          	li	a4,-1
    80001500:	03f71713          	slli	a4,a4,0x3f
    80001504:	00e7e7b3          	or	a5,a5,a4
  asm volatile("csrw satp, %0" : : "r" (x));
    80001508:	18079073          	csrw	satp,a5
// flush the TLB.
static inline void
sfence_vma()
{
  // the zero, zero means flush all TLB entries.
  asm volatile("sfence.vma zero, zero");
    8000150c:	12000073          	sfence.vma
  sfence_vma();
}
    80001510:	00813403          	ld	s0,8(sp)
    80001514:	01010113          	addi	sp,sp,16
    80001518:	00008067          	ret

000000008000151c <walk>:
//   21..29 -- 9 bits of level-1 index.
//   12..20 -- 9 bits of level-0 index.
//    0..11 -- 12 bits of byte offset within the page.
pte_t *
walk(pagetable_t pagetable, uint64 va, int alloc)
{
    8000151c:	fc010113          	addi	sp,sp,-64
    80001520:	02113c23          	sd	ra,56(sp)
    80001524:	02813823          	sd	s0,48(sp)
    80001528:	02913423          	sd	s1,40(sp)
    8000152c:	03213023          	sd	s2,32(sp)
    80001530:	01313c23          	sd	s3,24(sp)
    80001534:	01413823          	sd	s4,16(sp)
    80001538:	01513423          	sd	s5,8(sp)
    8000153c:	01613023          	sd	s6,0(sp)
    80001540:	04010413          	addi	s0,sp,64
    80001544:	00050493          	mv	s1,a0
    80001548:	00058993          	mv	s3,a1
    8000154c:	00060a93          	mv	s5,a2
  if(va >= MAXVA)
    80001550:	fff00793          	li	a5,-1
    80001554:	01a7d793          	srli	a5,a5,0x1a
    80001558:	01e00a13          	li	s4,30
    panic("walk");

  for(int level = 2; level > 0; level--) {
    8000155c:	00c00b13          	li	s6,12
  if(va >= MAXVA)
    80001560:	04b7f863          	bgeu	a5,a1,800015b0 <walk+0x94>
    panic("walk");
    80001564:	00009517          	auipc	a0,0x9
    80001568:	b6c50513          	addi	a0,a0,-1172 # 8000a0d0 <digits+0x90>
    8000156c:	fffff097          	auipc	ra,0xfffff
    80001570:	164080e7          	jalr	356(ra) # 800006d0 <panic>
    pte_t *pte = &pagetable[PX(level, va)];
    if(*pte & PTE_V) {
      pagetable = (pagetable_t)PTE2PA(*pte);
    } else {
      if(!alloc || (pagetable = (pde_t*)kalloc()) == 0)
    80001574:	080a8e63          	beqz	s5,80001610 <walk+0xf4>
    80001578:	00000097          	auipc	ra,0x0
    8000157c:	8e8080e7          	jalr	-1816(ra) # 80000e60 <kalloc>
    80001580:	00050493          	mv	s1,a0
    80001584:	06050263          	beqz	a0,800015e8 <walk+0xcc>
        return 0;
      memset(pagetable, 0, PGSIZE);
    80001588:	00001637          	lui	a2,0x1
    8000158c:	00000593          	li	a1,0
    80001590:	00000097          	auipc	ra,0x0
    80001594:	b94080e7          	jalr	-1132(ra) # 80001124 <memset>
      *pte = PA2PTE(pagetable) | PTE_V;
    80001598:	00c4d793          	srli	a5,s1,0xc
    8000159c:	00a79793          	slli	a5,a5,0xa
    800015a0:	0017e793          	ori	a5,a5,1
    800015a4:	00f93023          	sd	a5,0(s2)
  for(int level = 2; level > 0; level--) {
    800015a8:	ff7a0a1b          	addiw	s4,s4,-9 # ffffffffffffeff7 <end+0xffffffff7ffd6ff7>
    800015ac:	036a0663          	beq	s4,s6,800015d8 <walk+0xbc>
    pte_t *pte = &pagetable[PX(level, va)];
    800015b0:	0149d933          	srl	s2,s3,s4
    800015b4:	1ff97913          	andi	s2,s2,511
    800015b8:	00391913          	slli	s2,s2,0x3
    800015bc:	01248933          	add	s2,s1,s2
    if(*pte & PTE_V) {
    800015c0:	00093483          	ld	s1,0(s2)
    800015c4:	0014f793          	andi	a5,s1,1
    800015c8:	fa0786e3          	beqz	a5,80001574 <walk+0x58>
      pagetable = (pagetable_t)PTE2PA(*pte);
    800015cc:	00a4d493          	srli	s1,s1,0xa
    800015d0:	00c49493          	slli	s1,s1,0xc
    800015d4:	fd5ff06f          	j	800015a8 <walk+0x8c>
    }
  }
  return &pagetable[PX(0, va)];
    800015d8:	00c9d513          	srli	a0,s3,0xc
    800015dc:	1ff57513          	andi	a0,a0,511
    800015e0:	00351513          	slli	a0,a0,0x3
    800015e4:	00a48533          	add	a0,s1,a0
}
    800015e8:	03813083          	ld	ra,56(sp)
    800015ec:	03013403          	ld	s0,48(sp)
    800015f0:	02813483          	ld	s1,40(sp)
    800015f4:	02013903          	ld	s2,32(sp)
    800015f8:	01813983          	ld	s3,24(sp)
    800015fc:	01013a03          	ld	s4,16(sp)
    80001600:	00813a83          	ld	s5,8(sp)
    80001604:	00013b03          	ld	s6,0(sp)
    80001608:	04010113          	addi	sp,sp,64
    8000160c:	00008067          	ret
        return 0;
    80001610:	00000513          	li	a0,0
    80001614:	fd5ff06f          	j	800015e8 <walk+0xcc>

0000000080001618 <walkaddr>:
walkaddr(pagetable_t pagetable, uint64 va)
{
  pte_t *pte;
  uint64 pa;

  if(va >= MAXVA)
    80001618:	fff00793          	li	a5,-1
    8000161c:	01a7d793          	srli	a5,a5,0x1a
    80001620:	00b7f663          	bgeu	a5,a1,8000162c <walkaddr+0x14>
    return 0;
    80001624:	00000513          	li	a0,0
    return 0;
  if((*pte & PTE_U) == 0)
    return 0;
  pa = PTE2PA(*pte);
  return pa;
}
    80001628:	00008067          	ret
{
    8000162c:	ff010113          	addi	sp,sp,-16
    80001630:	00113423          	sd	ra,8(sp)
    80001634:	00813023          	sd	s0,0(sp)
    80001638:	01010413          	addi	s0,sp,16
  pte = walk(pagetable, va, 0);
    8000163c:	00000613          	li	a2,0
    80001640:	00000097          	auipc	ra,0x0
    80001644:	edc080e7          	jalr	-292(ra) # 8000151c <walk>
  if(pte == 0)
    80001648:	02050a63          	beqz	a0,8000167c <walkaddr+0x64>
  if((*pte & PTE_V) == 0)
    8000164c:	00053783          	ld	a5,0(a0)
  if((*pte & PTE_U) == 0)
    80001650:	0117f693          	andi	a3,a5,17
    80001654:	01100713          	li	a4,17
    return 0;
    80001658:	00000513          	li	a0,0
  if((*pte & PTE_U) == 0)
    8000165c:	00e68a63          	beq	a3,a4,80001670 <walkaddr+0x58>
}
    80001660:	00813083          	ld	ra,8(sp)
    80001664:	00013403          	ld	s0,0(sp)
    80001668:	01010113          	addi	sp,sp,16
    8000166c:	00008067          	ret
  pa = PTE2PA(*pte);
    80001670:	00a7d793          	srli	a5,a5,0xa
    80001674:	00c79513          	slli	a0,a5,0xc
  return pa;
    80001678:	fe9ff06f          	j	80001660 <walkaddr+0x48>
    return 0;
    8000167c:	00000513          	li	a0,0
    80001680:	fe1ff06f          	j	80001660 <walkaddr+0x48>

0000000080001684 <mappages>:
// physical addresses starting at pa. va and size might not
// be page-aligned. Returns 0 on success, -1 if walk() couldn't
// allocate a needed page-table page.
int
mappages(pagetable_t pagetable, uint64 va, uint64 size, uint64 pa, int perm)
{
    80001684:	fb010113          	addi	sp,sp,-80
    80001688:	04113423          	sd	ra,72(sp)
    8000168c:	04813023          	sd	s0,64(sp)
    80001690:	02913c23          	sd	s1,56(sp)
    80001694:	03213823          	sd	s2,48(sp)
    80001698:	03313423          	sd	s3,40(sp)
    8000169c:	03413023          	sd	s4,32(sp)
    800016a0:	01513c23          	sd	s5,24(sp)
    800016a4:	01613823          	sd	s6,16(sp)
    800016a8:	01713423          	sd	s7,8(sp)
    800016ac:	05010413          	addi	s0,sp,80
  uint64 a, last;
  pte_t *pte;

  if(size == 0)
    800016b0:	06060a63          	beqz	a2,80001724 <mappages+0xa0>
    800016b4:	00050a93          	mv	s5,a0
    800016b8:	00070b13          	mv	s6,a4
    panic("mappages: size");
  
  a = PGROUNDDOWN(va);
    800016bc:	fffff737          	lui	a4,0xfffff
    800016c0:	00e5f7b3          	and	a5,a1,a4
  last = PGROUNDDOWN(va + size - 1);
    800016c4:	fff58993          	addi	s3,a1,-1
    800016c8:	00c989b3          	add	s3,s3,a2
    800016cc:	00e9f9b3          	and	s3,s3,a4
  a = PGROUNDDOWN(va);
    800016d0:	00078913          	mv	s2,a5
    800016d4:	40f68a33          	sub	s4,a3,a5
    if(*pte & PTE_V)
      panic("mappages: remap");
    *pte = PA2PTE(pa) | perm | PTE_V;
    if(a == last)
      break;
    a += PGSIZE;
    800016d8:	00001bb7          	lui	s7,0x1
    800016dc:	012a04b3          	add	s1,s4,s2
    if((pte = walk(pagetable, a, 1)) == 0)
    800016e0:	00100613          	li	a2,1
    800016e4:	00090593          	mv	a1,s2
    800016e8:	000a8513          	mv	a0,s5
    800016ec:	00000097          	auipc	ra,0x0
    800016f0:	e30080e7          	jalr	-464(ra) # 8000151c <walk>
    800016f4:	04050863          	beqz	a0,80001744 <mappages+0xc0>
    if(*pte & PTE_V)
    800016f8:	00053783          	ld	a5,0(a0)
    800016fc:	0017f793          	andi	a5,a5,1
    80001700:	02079a63          	bnez	a5,80001734 <mappages+0xb0>
    *pte = PA2PTE(pa) | perm | PTE_V;
    80001704:	00c4d493          	srli	s1,s1,0xc
    80001708:	00a49493          	slli	s1,s1,0xa
    8000170c:	0164e4b3          	or	s1,s1,s6
    80001710:	0014e493          	ori	s1,s1,1
    80001714:	00953023          	sd	s1,0(a0)
    if(a == last)
    80001718:	05390e63          	beq	s2,s3,80001774 <mappages+0xf0>
    a += PGSIZE;
    8000171c:	01790933          	add	s2,s2,s7
    if((pte = walk(pagetable, a, 1)) == 0)
    80001720:	fbdff06f          	j	800016dc <mappages+0x58>
    panic("mappages: size");
    80001724:	00009517          	auipc	a0,0x9
    80001728:	9b450513          	addi	a0,a0,-1612 # 8000a0d8 <digits+0x98>
    8000172c:	fffff097          	auipc	ra,0xfffff
    80001730:	fa4080e7          	jalr	-92(ra) # 800006d0 <panic>
      panic("mappages: remap");
    80001734:	00009517          	auipc	a0,0x9
    80001738:	9b450513          	addi	a0,a0,-1612 # 8000a0e8 <digits+0xa8>
    8000173c:	fffff097          	auipc	ra,0xfffff
    80001740:	f94080e7          	jalr	-108(ra) # 800006d0 <panic>
      return -1;
    80001744:	fff00513          	li	a0,-1
    pa += PGSIZE;
  }
  return 0;
}
    80001748:	04813083          	ld	ra,72(sp)
    8000174c:	04013403          	ld	s0,64(sp)
    80001750:	03813483          	ld	s1,56(sp)
    80001754:	03013903          	ld	s2,48(sp)
    80001758:	02813983          	ld	s3,40(sp)
    8000175c:	02013a03          	ld	s4,32(sp)
    80001760:	01813a83          	ld	s5,24(sp)
    80001764:	01013b03          	ld	s6,16(sp)
    80001768:	00813b83          	ld	s7,8(sp)
    8000176c:	05010113          	addi	sp,sp,80
    80001770:	00008067          	ret
  return 0;
    80001774:	00000513          	li	a0,0
    80001778:	fd1ff06f          	j	80001748 <mappages+0xc4>

000000008000177c <kvmmap>:
{
    8000177c:	ff010113          	addi	sp,sp,-16
    80001780:	00113423          	sd	ra,8(sp)
    80001784:	00813023          	sd	s0,0(sp)
    80001788:	01010413          	addi	s0,sp,16
    8000178c:	00068793          	mv	a5,a3
  if(mappages(kpgtbl, va, sz, pa, perm) != 0)
    80001790:	00060693          	mv	a3,a2
    80001794:	00078613          	mv	a2,a5
    80001798:	00000097          	auipc	ra,0x0
    8000179c:	eec080e7          	jalr	-276(ra) # 80001684 <mappages>
    800017a0:	00051a63          	bnez	a0,800017b4 <kvmmap+0x38>
}
    800017a4:	00813083          	ld	ra,8(sp)
    800017a8:	00013403          	ld	s0,0(sp)
    800017ac:	01010113          	addi	sp,sp,16
    800017b0:	00008067          	ret
    panic("kvmmap");
    800017b4:	00009517          	auipc	a0,0x9
    800017b8:	94450513          	addi	a0,a0,-1724 # 8000a0f8 <digits+0xb8>
    800017bc:	fffff097          	auipc	ra,0xfffff
    800017c0:	f14080e7          	jalr	-236(ra) # 800006d0 <panic>

00000000800017c4 <kvmmake>:
{
    800017c4:	fe010113          	addi	sp,sp,-32
    800017c8:	00113c23          	sd	ra,24(sp)
    800017cc:	00813823          	sd	s0,16(sp)
    800017d0:	00913423          	sd	s1,8(sp)
    800017d4:	01213023          	sd	s2,0(sp)
    800017d8:	02010413          	addi	s0,sp,32
  kpgtbl = (pagetable_t) kalloc();
    800017dc:	fffff097          	auipc	ra,0xfffff
    800017e0:	684080e7          	jalr	1668(ra) # 80000e60 <kalloc>
    800017e4:	00050493          	mv	s1,a0
  memset(kpgtbl, 0, PGSIZE);
    800017e8:	00001637          	lui	a2,0x1
    800017ec:	00000593          	li	a1,0
    800017f0:	00000097          	auipc	ra,0x0
    800017f4:	934080e7          	jalr	-1740(ra) # 80001124 <memset>
  kvmmap(kpgtbl, UART0, UART0, PGSIZE, PTE_R | PTE_W);
    800017f8:	00600713          	li	a4,6
    800017fc:	000016b7          	lui	a3,0x1
    80001800:	10000637          	lui	a2,0x10000
    80001804:	100005b7          	lui	a1,0x10000
    80001808:	00048513          	mv	a0,s1
    8000180c:	00000097          	auipc	ra,0x0
    80001810:	f70080e7          	jalr	-144(ra) # 8000177c <kvmmap>
  kvmmap(kpgtbl, VIRTIO0, VIRTIO0, PGSIZE, PTE_R | PTE_W);
    80001814:	00600713          	li	a4,6
    80001818:	000016b7          	lui	a3,0x1
    8000181c:	10001637          	lui	a2,0x10001
    80001820:	100015b7          	lui	a1,0x10001
    80001824:	00048513          	mv	a0,s1
    80001828:	00000097          	auipc	ra,0x0
    8000182c:	f54080e7          	jalr	-172(ra) # 8000177c <kvmmap>
  kvmmap(kpgtbl, PLIC, PLIC, 0x400000, PTE_R | PTE_W);
    80001830:	00600713          	li	a4,6
    80001834:	004006b7          	lui	a3,0x400
    80001838:	0c000637          	lui	a2,0xc000
    8000183c:	0c0005b7          	lui	a1,0xc000
    80001840:	00048513          	mv	a0,s1
    80001844:	00000097          	auipc	ra,0x0
    80001848:	f38080e7          	jalr	-200(ra) # 8000177c <kvmmap>
  kvmmap(kpgtbl, KERNBASE, KERNBASE, (uint64)etext-KERNBASE, PTE_R | PTE_X);
    8000184c:	00008917          	auipc	s2,0x8
    80001850:	7b490913          	addi	s2,s2,1972 # 8000a000 <etext>
    80001854:	00a00713          	li	a4,10
    80001858:	80008697          	auipc	a3,0x80008
    8000185c:	7a868693          	addi	a3,a3,1960 # a000 <_entry-0x7fff6000>
    80001860:	00100613          	li	a2,1
    80001864:	01f61613          	slli	a2,a2,0x1f
    80001868:	00060593          	mv	a1,a2
    8000186c:	00048513          	mv	a0,s1
    80001870:	00000097          	auipc	ra,0x0
    80001874:	f0c080e7          	jalr	-244(ra) # 8000177c <kvmmap>
  kvmmap(kpgtbl, (uint64)etext, (uint64)etext, PHYSTOP-(uint64)etext, PTE_R | PTE_W);
    80001878:	00600713          	li	a4,6
    8000187c:	01100693          	li	a3,17
    80001880:	01b69693          	slli	a3,a3,0x1b
    80001884:	412686b3          	sub	a3,a3,s2
    80001888:	00090613          	mv	a2,s2
    8000188c:	00090593          	mv	a1,s2
    80001890:	00048513          	mv	a0,s1
    80001894:	00000097          	auipc	ra,0x0
    80001898:	ee8080e7          	jalr	-280(ra) # 8000177c <kvmmap>
  kvmmap(kpgtbl, TRAMPOLINE, (uint64)trampoline, PGSIZE, PTE_R | PTE_X);
    8000189c:	00a00713          	li	a4,10
    800018a0:	000016b7          	lui	a3,0x1
    800018a4:	00007617          	auipc	a2,0x7
    800018a8:	75c60613          	addi	a2,a2,1884 # 80009000 <_trampoline>
    800018ac:	040005b7          	lui	a1,0x4000
    800018b0:	fff58593          	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    800018b4:	00c59593          	slli	a1,a1,0xc
    800018b8:	00048513          	mv	a0,s1
    800018bc:	00000097          	auipc	ra,0x0
    800018c0:	ec0080e7          	jalr	-320(ra) # 8000177c <kvmmap>
  proc_mapstacks(kpgtbl);
    800018c4:	00048513          	mv	a0,s1
    800018c8:	00001097          	auipc	ra,0x1
    800018cc:	968080e7          	jalr	-1688(ra) # 80002230 <proc_mapstacks>
}
    800018d0:	00048513          	mv	a0,s1
    800018d4:	01813083          	ld	ra,24(sp)
    800018d8:	01013403          	ld	s0,16(sp)
    800018dc:	00813483          	ld	s1,8(sp)
    800018e0:	00013903          	ld	s2,0(sp)
    800018e4:	02010113          	addi	sp,sp,32
    800018e8:	00008067          	ret

00000000800018ec <kvminit>:
{
    800018ec:	ff010113          	addi	sp,sp,-16
    800018f0:	00113423          	sd	ra,8(sp)
    800018f4:	00813023          	sd	s0,0(sp)
    800018f8:	01010413          	addi	s0,sp,16
  kernel_pagetable = kvmmake();
    800018fc:	00000097          	auipc	ra,0x0
    80001900:	ec8080e7          	jalr	-312(ra) # 800017c4 <kvmmake>
    80001904:	00009797          	auipc	a5,0x9
    80001908:	70a7be23          	sd	a0,1820(a5) # 8000b020 <kernel_pagetable>
}
    8000190c:	00813083          	ld	ra,8(sp)
    80001910:	00013403          	ld	s0,0(sp)
    80001914:	01010113          	addi	sp,sp,16
    80001918:	00008067          	ret

000000008000191c <uvmunmap>:
// Remove npages of mappings starting from va. va must be
// page-aligned. The mappings must exist.
// Optionally free the physical memory.
void
uvmunmap(pagetable_t pagetable, uint64 va, uint64 npages, int do_free)
{
    8000191c:	fb010113          	addi	sp,sp,-80
    80001920:	04113423          	sd	ra,72(sp)
    80001924:	04813023          	sd	s0,64(sp)
    80001928:	02913c23          	sd	s1,56(sp)
    8000192c:	03213823          	sd	s2,48(sp)
    80001930:	03313423          	sd	s3,40(sp)
    80001934:	03413023          	sd	s4,32(sp)
    80001938:	01513c23          	sd	s5,24(sp)
    8000193c:	01613823          	sd	s6,16(sp)
    80001940:	01713423          	sd	s7,8(sp)
    80001944:	05010413          	addi	s0,sp,80
  uint64 a;
  pte_t *pte;

  if((va % PGSIZE) != 0)
    80001948:	03459793          	slli	a5,a1,0x34
    8000194c:	04079863          	bnez	a5,8000199c <uvmunmap+0x80>
    80001950:	00050a13          	mv	s4,a0
    80001954:	00058913          	mv	s2,a1
    80001958:	00068a93          	mv	s5,a3
    panic("uvmunmap: not aligned");

  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    8000195c:	00c61613          	slli	a2,a2,0xc
    80001960:	00b609b3          	add	s3,a2,a1
    if((pte = walk(pagetable, a, 0)) == 0)
      panic("uvmunmap: walk");
    if((*pte & PTE_V) == 0)
      panic("uvmunmap: not mapped");
    if(PTE_FLAGS(*pte) == PTE_V)
    80001964:	00100b93          	li	s7,1
  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    80001968:	00001b37          	lui	s6,0x1
    8000196c:	0735ee63          	bltu	a1,s3,800019e8 <uvmunmap+0xcc>
      uint64 pa = PTE2PA(*pte);
      kfree((void*)pa);
    }
    *pte = 0;
  }
}
    80001970:	04813083          	ld	ra,72(sp)
    80001974:	04013403          	ld	s0,64(sp)
    80001978:	03813483          	ld	s1,56(sp)
    8000197c:	03013903          	ld	s2,48(sp)
    80001980:	02813983          	ld	s3,40(sp)
    80001984:	02013a03          	ld	s4,32(sp)
    80001988:	01813a83          	ld	s5,24(sp)
    8000198c:	01013b03          	ld	s6,16(sp)
    80001990:	00813b83          	ld	s7,8(sp)
    80001994:	05010113          	addi	sp,sp,80
    80001998:	00008067          	ret
    panic("uvmunmap: not aligned");
    8000199c:	00008517          	auipc	a0,0x8
    800019a0:	76450513          	addi	a0,a0,1892 # 8000a100 <digits+0xc0>
    800019a4:	fffff097          	auipc	ra,0xfffff
    800019a8:	d2c080e7          	jalr	-724(ra) # 800006d0 <panic>
      panic("uvmunmap: walk");
    800019ac:	00008517          	auipc	a0,0x8
    800019b0:	76c50513          	addi	a0,a0,1900 # 8000a118 <digits+0xd8>
    800019b4:	fffff097          	auipc	ra,0xfffff
    800019b8:	d1c080e7          	jalr	-740(ra) # 800006d0 <panic>
      panic("uvmunmap: not mapped");
    800019bc:	00008517          	auipc	a0,0x8
    800019c0:	76c50513          	addi	a0,a0,1900 # 8000a128 <digits+0xe8>
    800019c4:	fffff097          	auipc	ra,0xfffff
    800019c8:	d0c080e7          	jalr	-756(ra) # 800006d0 <panic>
      panic("uvmunmap: not a leaf");
    800019cc:	00008517          	auipc	a0,0x8
    800019d0:	77450513          	addi	a0,a0,1908 # 8000a140 <digits+0x100>
    800019d4:	fffff097          	auipc	ra,0xfffff
    800019d8:	cfc080e7          	jalr	-772(ra) # 800006d0 <panic>
    *pte = 0;
    800019dc:	0004b023          	sd	zero,0(s1)
  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    800019e0:	01690933          	add	s2,s2,s6
    800019e4:	f93976e3          	bgeu	s2,s3,80001970 <uvmunmap+0x54>
    if((pte = walk(pagetable, a, 0)) == 0)
    800019e8:	00000613          	li	a2,0
    800019ec:	00090593          	mv	a1,s2
    800019f0:	000a0513          	mv	a0,s4
    800019f4:	00000097          	auipc	ra,0x0
    800019f8:	b28080e7          	jalr	-1240(ra) # 8000151c <walk>
    800019fc:	00050493          	mv	s1,a0
    80001a00:	fa0506e3          	beqz	a0,800019ac <uvmunmap+0x90>
    if((*pte & PTE_V) == 0)
    80001a04:	00053503          	ld	a0,0(a0)
    80001a08:	00157793          	andi	a5,a0,1
    80001a0c:	fa0788e3          	beqz	a5,800019bc <uvmunmap+0xa0>
    if(PTE_FLAGS(*pte) == PTE_V)
    80001a10:	3ff57793          	andi	a5,a0,1023
    80001a14:	fb778ce3          	beq	a5,s7,800019cc <uvmunmap+0xb0>
    if(do_free){
    80001a18:	fc0a82e3          	beqz	s5,800019dc <uvmunmap+0xc0>
      uint64 pa = PTE2PA(*pte);
    80001a1c:	00a55513          	srli	a0,a0,0xa
      kfree((void*)pa);
    80001a20:	00c51513          	slli	a0,a0,0xc
    80001a24:	fffff097          	auipc	ra,0xfffff
    80001a28:	2d0080e7          	jalr	720(ra) # 80000cf4 <kfree>
    80001a2c:	fb1ff06f          	j	800019dc <uvmunmap+0xc0>

0000000080001a30 <uvmcreate>:

// create an empty user page table.
// returns 0 if out of memory.
pagetable_t
uvmcreate()
{
    80001a30:	fe010113          	addi	sp,sp,-32
    80001a34:	00113c23          	sd	ra,24(sp)
    80001a38:	00813823          	sd	s0,16(sp)
    80001a3c:	00913423          	sd	s1,8(sp)
    80001a40:	02010413          	addi	s0,sp,32
  pagetable_t pagetable;
  pagetable = (pagetable_t) kalloc();
    80001a44:	fffff097          	auipc	ra,0xfffff
    80001a48:	41c080e7          	jalr	1052(ra) # 80000e60 <kalloc>
    80001a4c:	00050493          	mv	s1,a0
  if(pagetable == 0)
    80001a50:	00050a63          	beqz	a0,80001a64 <uvmcreate+0x34>
    return 0;
  memset(pagetable, 0, PGSIZE);
    80001a54:	00001637          	lui	a2,0x1
    80001a58:	00000593          	li	a1,0
    80001a5c:	fffff097          	auipc	ra,0xfffff
    80001a60:	6c8080e7          	jalr	1736(ra) # 80001124 <memset>
  return pagetable;
}
    80001a64:	00048513          	mv	a0,s1
    80001a68:	01813083          	ld	ra,24(sp)
    80001a6c:	01013403          	ld	s0,16(sp)
    80001a70:	00813483          	ld	s1,8(sp)
    80001a74:	02010113          	addi	sp,sp,32
    80001a78:	00008067          	ret

0000000080001a7c <uvminit>:
// Load the user initcode into address 0 of pagetable,
// for the very first process.
// sz must be less than a page.
void
uvminit(pagetable_t pagetable, uchar *src, uint sz)
{
    80001a7c:	fd010113          	addi	sp,sp,-48
    80001a80:	02113423          	sd	ra,40(sp)
    80001a84:	02813023          	sd	s0,32(sp)
    80001a88:	00913c23          	sd	s1,24(sp)
    80001a8c:	01213823          	sd	s2,16(sp)
    80001a90:	01313423          	sd	s3,8(sp)
    80001a94:	01413023          	sd	s4,0(sp)
    80001a98:	03010413          	addi	s0,sp,48
  char *mem;

  if(sz >= PGSIZE)
    80001a9c:	000017b7          	lui	a5,0x1
    80001aa0:	06f67e63          	bgeu	a2,a5,80001b1c <uvminit+0xa0>
    80001aa4:	00050a13          	mv	s4,a0
    80001aa8:	00058993          	mv	s3,a1
    80001aac:	00060493          	mv	s1,a2
    panic("inituvm: more than a page");
  mem = kalloc();
    80001ab0:	fffff097          	auipc	ra,0xfffff
    80001ab4:	3b0080e7          	jalr	944(ra) # 80000e60 <kalloc>
    80001ab8:	00050913          	mv	s2,a0
  memset(mem, 0, PGSIZE);
    80001abc:	00001637          	lui	a2,0x1
    80001ac0:	00000593          	li	a1,0
    80001ac4:	fffff097          	auipc	ra,0xfffff
    80001ac8:	660080e7          	jalr	1632(ra) # 80001124 <memset>
  mappages(pagetable, 0, PGSIZE, (uint64)mem, PTE_W|PTE_R|PTE_X|PTE_U);
    80001acc:	01e00713          	li	a4,30
    80001ad0:	00090693          	mv	a3,s2
    80001ad4:	00001637          	lui	a2,0x1
    80001ad8:	00000593          	li	a1,0
    80001adc:	000a0513          	mv	a0,s4
    80001ae0:	00000097          	auipc	ra,0x0
    80001ae4:	ba4080e7          	jalr	-1116(ra) # 80001684 <mappages>
  memmove(mem, src, sz);
    80001ae8:	00048613          	mv	a2,s1
    80001aec:	00098593          	mv	a1,s3
    80001af0:	00090513          	mv	a0,s2
    80001af4:	fffff097          	auipc	ra,0xfffff
    80001af8:	6c4080e7          	jalr	1732(ra) # 800011b8 <memmove>
}
    80001afc:	02813083          	ld	ra,40(sp)
    80001b00:	02013403          	ld	s0,32(sp)
    80001b04:	01813483          	ld	s1,24(sp)
    80001b08:	01013903          	ld	s2,16(sp)
    80001b0c:	00813983          	ld	s3,8(sp)
    80001b10:	00013a03          	ld	s4,0(sp)
    80001b14:	03010113          	addi	sp,sp,48
    80001b18:	00008067          	ret
    panic("inituvm: more than a page");
    80001b1c:	00008517          	auipc	a0,0x8
    80001b20:	63c50513          	addi	a0,a0,1596 # 8000a158 <digits+0x118>
    80001b24:	fffff097          	auipc	ra,0xfffff
    80001b28:	bac080e7          	jalr	-1108(ra) # 800006d0 <panic>

0000000080001b2c <uvmdealloc>:
// newsz.  oldsz and newsz need not be page-aligned, nor does newsz
// need to be less than oldsz.  oldsz can be larger than the actual
// process size.  Returns the new process size.
uint64
uvmdealloc(pagetable_t pagetable, uint64 oldsz, uint64 newsz)
{
    80001b2c:	fe010113          	addi	sp,sp,-32
    80001b30:	00113c23          	sd	ra,24(sp)
    80001b34:	00813823          	sd	s0,16(sp)
    80001b38:	00913423          	sd	s1,8(sp)
    80001b3c:	02010413          	addi	s0,sp,32
  if(newsz >= oldsz)
    return oldsz;
    80001b40:	00058493          	mv	s1,a1
  if(newsz >= oldsz)
    80001b44:	02b67463          	bgeu	a2,a1,80001b6c <uvmdealloc+0x40>
    80001b48:	00060493          	mv	s1,a2

  if(PGROUNDUP(newsz) < PGROUNDUP(oldsz)){
    80001b4c:	000017b7          	lui	a5,0x1
    80001b50:	fff78793          	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    80001b54:	00f60733          	add	a4,a2,a5
    80001b58:	fffff6b7          	lui	a3,0xfffff
    80001b5c:	00d77733          	and	a4,a4,a3
    80001b60:	00f587b3          	add	a5,a1,a5
    80001b64:	00d7f7b3          	and	a5,a5,a3
    80001b68:	00f76e63          	bltu	a4,a5,80001b84 <uvmdealloc+0x58>
    int npages = (PGROUNDUP(oldsz) - PGROUNDUP(newsz)) / PGSIZE;
    uvmunmap(pagetable, PGROUNDUP(newsz), npages, 1);
  }

  return newsz;
}
    80001b6c:	00048513          	mv	a0,s1
    80001b70:	01813083          	ld	ra,24(sp)
    80001b74:	01013403          	ld	s0,16(sp)
    80001b78:	00813483          	ld	s1,8(sp)
    80001b7c:	02010113          	addi	sp,sp,32
    80001b80:	00008067          	ret
    int npages = (PGROUNDUP(oldsz) - PGROUNDUP(newsz)) / PGSIZE;
    80001b84:	40e787b3          	sub	a5,a5,a4
    80001b88:	00c7d793          	srli	a5,a5,0xc
    uvmunmap(pagetable, PGROUNDUP(newsz), npages, 1);
    80001b8c:	00100693          	li	a3,1
    80001b90:	0007861b          	sext.w	a2,a5
    80001b94:	00070593          	mv	a1,a4
    80001b98:	00000097          	auipc	ra,0x0
    80001b9c:	d84080e7          	jalr	-636(ra) # 8000191c <uvmunmap>
    80001ba0:	fcdff06f          	j	80001b6c <uvmdealloc+0x40>

0000000080001ba4 <uvmalloc>:
  if(newsz < oldsz)
    80001ba4:	10b66263          	bltu	a2,a1,80001ca8 <uvmalloc+0x104>
{
    80001ba8:	fc010113          	addi	sp,sp,-64
    80001bac:	02113c23          	sd	ra,56(sp)
    80001bb0:	02813823          	sd	s0,48(sp)
    80001bb4:	02913423          	sd	s1,40(sp)
    80001bb8:	03213023          	sd	s2,32(sp)
    80001bbc:	01313c23          	sd	s3,24(sp)
    80001bc0:	01413823          	sd	s4,16(sp)
    80001bc4:	01513423          	sd	s5,8(sp)
    80001bc8:	04010413          	addi	s0,sp,64
    80001bcc:	00050a93          	mv	s5,a0
    80001bd0:	00060a13          	mv	s4,a2
  oldsz = PGROUNDUP(oldsz);
    80001bd4:	000017b7          	lui	a5,0x1
    80001bd8:	fff78793          	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    80001bdc:	00f585b3          	add	a1,a1,a5
    80001be0:	fffff7b7          	lui	a5,0xfffff
    80001be4:	00f5f9b3          	and	s3,a1,a5
  for(a = oldsz; a < newsz; a += PGSIZE){
    80001be8:	0cc9f463          	bgeu	s3,a2,80001cb0 <uvmalloc+0x10c>
    80001bec:	00098913          	mv	s2,s3
    mem = kalloc();
    80001bf0:	fffff097          	auipc	ra,0xfffff
    80001bf4:	270080e7          	jalr	624(ra) # 80000e60 <kalloc>
    80001bf8:	00050493          	mv	s1,a0
    if(mem == 0){
    80001bfc:	04050463          	beqz	a0,80001c44 <uvmalloc+0xa0>
    memset(mem, 0, PGSIZE);
    80001c00:	00001637          	lui	a2,0x1
    80001c04:	00000593          	li	a1,0
    80001c08:	fffff097          	auipc	ra,0xfffff
    80001c0c:	51c080e7          	jalr	1308(ra) # 80001124 <memset>
    if(mappages(pagetable, a, PGSIZE, (uint64)mem, PTE_W|PTE_X|PTE_R|PTE_U) != 0){
    80001c10:	01e00713          	li	a4,30
    80001c14:	00048693          	mv	a3,s1
    80001c18:	00001637          	lui	a2,0x1
    80001c1c:	00090593          	mv	a1,s2
    80001c20:	000a8513          	mv	a0,s5
    80001c24:	00000097          	auipc	ra,0x0
    80001c28:	a60080e7          	jalr	-1440(ra) # 80001684 <mappages>
    80001c2c:	04051a63          	bnez	a0,80001c80 <uvmalloc+0xdc>
  for(a = oldsz; a < newsz; a += PGSIZE){
    80001c30:	000017b7          	lui	a5,0x1
    80001c34:	00f90933          	add	s2,s2,a5
    80001c38:	fb496ce3          	bltu	s2,s4,80001bf0 <uvmalloc+0x4c>
  return newsz;
    80001c3c:	000a0513          	mv	a0,s4
    80001c40:	01c0006f          	j	80001c5c <uvmalloc+0xb8>
      uvmdealloc(pagetable, a, oldsz);
    80001c44:	00098613          	mv	a2,s3
    80001c48:	00090593          	mv	a1,s2
    80001c4c:	000a8513          	mv	a0,s5
    80001c50:	00000097          	auipc	ra,0x0
    80001c54:	edc080e7          	jalr	-292(ra) # 80001b2c <uvmdealloc>
      return 0;
    80001c58:	00000513          	li	a0,0
}
    80001c5c:	03813083          	ld	ra,56(sp)
    80001c60:	03013403          	ld	s0,48(sp)
    80001c64:	02813483          	ld	s1,40(sp)
    80001c68:	02013903          	ld	s2,32(sp)
    80001c6c:	01813983          	ld	s3,24(sp)
    80001c70:	01013a03          	ld	s4,16(sp)
    80001c74:	00813a83          	ld	s5,8(sp)
    80001c78:	04010113          	addi	sp,sp,64
    80001c7c:	00008067          	ret
      kfree(mem);
    80001c80:	00048513          	mv	a0,s1
    80001c84:	fffff097          	auipc	ra,0xfffff
    80001c88:	070080e7          	jalr	112(ra) # 80000cf4 <kfree>
      uvmdealloc(pagetable, a, oldsz);
    80001c8c:	00098613          	mv	a2,s3
    80001c90:	00090593          	mv	a1,s2
    80001c94:	000a8513          	mv	a0,s5
    80001c98:	00000097          	auipc	ra,0x0
    80001c9c:	e94080e7          	jalr	-364(ra) # 80001b2c <uvmdealloc>
      return 0;
    80001ca0:	00000513          	li	a0,0
    80001ca4:	fb9ff06f          	j	80001c5c <uvmalloc+0xb8>
    return oldsz;
    80001ca8:	00058513          	mv	a0,a1
}
    80001cac:	00008067          	ret
  return newsz;
    80001cb0:	00060513          	mv	a0,a2
    80001cb4:	fa9ff06f          	j	80001c5c <uvmalloc+0xb8>

0000000080001cb8 <freewalk>:

// Recursively free page-table pages.
// All leaf mappings must already have been removed.
void
freewalk(pagetable_t pagetable)
{
    80001cb8:	fd010113          	addi	sp,sp,-48
    80001cbc:	02113423          	sd	ra,40(sp)
    80001cc0:	02813023          	sd	s0,32(sp)
    80001cc4:	00913c23          	sd	s1,24(sp)
    80001cc8:	01213823          	sd	s2,16(sp)
    80001ccc:	01313423          	sd	s3,8(sp)
    80001cd0:	01413023          	sd	s4,0(sp)
    80001cd4:	03010413          	addi	s0,sp,48
    80001cd8:	00050a13          	mv	s4,a0
  // there are 2^9 = 512 PTEs in a page table.
  for(int i = 0; i < 512; i++){
    80001cdc:	00050493          	mv	s1,a0
    80001ce0:	00001937          	lui	s2,0x1
    80001ce4:	01250933          	add	s2,a0,s2
    pte_t pte = pagetable[i];
    if((pte & PTE_V) && (pte & (PTE_R|PTE_W|PTE_X)) == 0){
    80001ce8:	00100993          	li	s3,1
    80001cec:	0200006f          	j	80001d0c <freewalk+0x54>
      // this PTE points to a lower-level page table.
      uint64 child = PTE2PA(pte);
    80001cf0:	00a7d793          	srli	a5,a5,0xa
      freewalk((pagetable_t)child);
    80001cf4:	00c79513          	slli	a0,a5,0xc
    80001cf8:	00000097          	auipc	ra,0x0
    80001cfc:	fc0080e7          	jalr	-64(ra) # 80001cb8 <freewalk>
      pagetable[i] = 0;
    80001d00:	0004b023          	sd	zero,0(s1)
  for(int i = 0; i < 512; i++){
    80001d04:	00848493          	addi	s1,s1,8
    80001d08:	03248463          	beq	s1,s2,80001d30 <freewalk+0x78>
    pte_t pte = pagetable[i];
    80001d0c:	0004b783          	ld	a5,0(s1)
    if((pte & PTE_V) && (pte & (PTE_R|PTE_W|PTE_X)) == 0){
    80001d10:	00f7f713          	andi	a4,a5,15
    80001d14:	fd370ee3          	beq	a4,s3,80001cf0 <freewalk+0x38>
    } else if(pte & PTE_V){
    80001d18:	0017f793          	andi	a5,a5,1
    80001d1c:	fe0784e3          	beqz	a5,80001d04 <freewalk+0x4c>
      panic("freewalk: leaf");
    80001d20:	00008517          	auipc	a0,0x8
    80001d24:	45850513          	addi	a0,a0,1112 # 8000a178 <digits+0x138>
    80001d28:	fffff097          	auipc	ra,0xfffff
    80001d2c:	9a8080e7          	jalr	-1624(ra) # 800006d0 <panic>
    }
  }
  kfree((void*)pagetable);
    80001d30:	000a0513          	mv	a0,s4
    80001d34:	fffff097          	auipc	ra,0xfffff
    80001d38:	fc0080e7          	jalr	-64(ra) # 80000cf4 <kfree>
}
    80001d3c:	02813083          	ld	ra,40(sp)
    80001d40:	02013403          	ld	s0,32(sp)
    80001d44:	01813483          	ld	s1,24(sp)
    80001d48:	01013903          	ld	s2,16(sp)
    80001d4c:	00813983          	ld	s3,8(sp)
    80001d50:	00013a03          	ld	s4,0(sp)
    80001d54:	03010113          	addi	sp,sp,48
    80001d58:	00008067          	ret

0000000080001d5c <uvmfree>:

// Free user memory pages,
// then free page-table pages.
void
uvmfree(pagetable_t pagetable, uint64 sz)
{
    80001d5c:	fe010113          	addi	sp,sp,-32
    80001d60:	00113c23          	sd	ra,24(sp)
    80001d64:	00813823          	sd	s0,16(sp)
    80001d68:	00913423          	sd	s1,8(sp)
    80001d6c:	02010413          	addi	s0,sp,32
    80001d70:	00050493          	mv	s1,a0
  if(sz > 0)
    80001d74:	02059263          	bnez	a1,80001d98 <uvmfree+0x3c>
    uvmunmap(pagetable, 0, PGROUNDUP(sz)/PGSIZE, 1);
  freewalk(pagetable);
    80001d78:	00048513          	mv	a0,s1
    80001d7c:	00000097          	auipc	ra,0x0
    80001d80:	f3c080e7          	jalr	-196(ra) # 80001cb8 <freewalk>
}
    80001d84:	01813083          	ld	ra,24(sp)
    80001d88:	01013403          	ld	s0,16(sp)
    80001d8c:	00813483          	ld	s1,8(sp)
    80001d90:	02010113          	addi	sp,sp,32
    80001d94:	00008067          	ret
    uvmunmap(pagetable, 0, PGROUNDUP(sz)/PGSIZE, 1);
    80001d98:	000017b7          	lui	a5,0x1
    80001d9c:	fff78793          	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    80001da0:	00f585b3          	add	a1,a1,a5
    80001da4:	00100693          	li	a3,1
    80001da8:	00c5d613          	srli	a2,a1,0xc
    80001dac:	00000593          	li	a1,0
    80001db0:	00000097          	auipc	ra,0x0
    80001db4:	b6c080e7          	jalr	-1172(ra) # 8000191c <uvmunmap>
    80001db8:	fc1ff06f          	j	80001d78 <uvmfree+0x1c>

0000000080001dbc <uvmcopy>:
  pte_t *pte;
  uint64 pa, i;
  uint flags;
  char *mem;

  for(i = 0; i < sz; i += PGSIZE){
    80001dbc:	12060a63          	beqz	a2,80001ef0 <uvmcopy+0x134>
{
    80001dc0:	fb010113          	addi	sp,sp,-80
    80001dc4:	04113423          	sd	ra,72(sp)
    80001dc8:	04813023          	sd	s0,64(sp)
    80001dcc:	02913c23          	sd	s1,56(sp)
    80001dd0:	03213823          	sd	s2,48(sp)
    80001dd4:	03313423          	sd	s3,40(sp)
    80001dd8:	03413023          	sd	s4,32(sp)
    80001ddc:	01513c23          	sd	s5,24(sp)
    80001de0:	01613823          	sd	s6,16(sp)
    80001de4:	01713423          	sd	s7,8(sp)
    80001de8:	05010413          	addi	s0,sp,80
    80001dec:	00050b13          	mv	s6,a0
    80001df0:	00058a93          	mv	s5,a1
    80001df4:	00060a13          	mv	s4,a2
  for(i = 0; i < sz; i += PGSIZE){
    80001df8:	00000993          	li	s3,0
    if((pte = walk(old, i, 0)) == 0)
    80001dfc:	00000613          	li	a2,0
    80001e00:	00098593          	mv	a1,s3
    80001e04:	000b0513          	mv	a0,s6
    80001e08:	fffff097          	auipc	ra,0xfffff
    80001e0c:	714080e7          	jalr	1812(ra) # 8000151c <walk>
    80001e10:	06050663          	beqz	a0,80001e7c <uvmcopy+0xc0>
      panic("uvmcopy: pte should exist");
    if((*pte & PTE_V) == 0)
    80001e14:	00053703          	ld	a4,0(a0)
    80001e18:	00177793          	andi	a5,a4,1
    80001e1c:	06078863          	beqz	a5,80001e8c <uvmcopy+0xd0>
      panic("uvmcopy: page not present");
    pa = PTE2PA(*pte);
    80001e20:	00a75593          	srli	a1,a4,0xa
    80001e24:	00c59b93          	slli	s7,a1,0xc
    flags = PTE_FLAGS(*pte);
    80001e28:	3ff77493          	andi	s1,a4,1023
    if((mem = kalloc()) == 0)
    80001e2c:	fffff097          	auipc	ra,0xfffff
    80001e30:	034080e7          	jalr	52(ra) # 80000e60 <kalloc>
    80001e34:	00050913          	mv	s2,a0
    80001e38:	06050863          	beqz	a0,80001ea8 <uvmcopy+0xec>
      goto err;
    memmove(mem, (char*)pa, PGSIZE);
    80001e3c:	00001637          	lui	a2,0x1
    80001e40:	000b8593          	mv	a1,s7
    80001e44:	fffff097          	auipc	ra,0xfffff
    80001e48:	374080e7          	jalr	884(ra) # 800011b8 <memmove>
    if(mappages(new, i, PGSIZE, (uint64)mem, flags) != 0){
    80001e4c:	00048713          	mv	a4,s1
    80001e50:	00090693          	mv	a3,s2
    80001e54:	00001637          	lui	a2,0x1
    80001e58:	00098593          	mv	a1,s3
    80001e5c:	000a8513          	mv	a0,s5
    80001e60:	00000097          	auipc	ra,0x0
    80001e64:	824080e7          	jalr	-2012(ra) # 80001684 <mappages>
    80001e68:	02051a63          	bnez	a0,80001e9c <uvmcopy+0xe0>
  for(i = 0; i < sz; i += PGSIZE){
    80001e6c:	000017b7          	lui	a5,0x1
    80001e70:	00f989b3          	add	s3,s3,a5
    80001e74:	f949e4e3          	bltu	s3,s4,80001dfc <uvmcopy+0x40>
    80001e78:	04c0006f          	j	80001ec4 <uvmcopy+0x108>
      panic("uvmcopy: pte should exist");
    80001e7c:	00008517          	auipc	a0,0x8
    80001e80:	30c50513          	addi	a0,a0,780 # 8000a188 <digits+0x148>
    80001e84:	fffff097          	auipc	ra,0xfffff
    80001e88:	84c080e7          	jalr	-1972(ra) # 800006d0 <panic>
      panic("uvmcopy: page not present");
    80001e8c:	00008517          	auipc	a0,0x8
    80001e90:	31c50513          	addi	a0,a0,796 # 8000a1a8 <digits+0x168>
    80001e94:	fffff097          	auipc	ra,0xfffff
    80001e98:	83c080e7          	jalr	-1988(ra) # 800006d0 <panic>
      kfree(mem);
    80001e9c:	00090513          	mv	a0,s2
    80001ea0:	fffff097          	auipc	ra,0xfffff
    80001ea4:	e54080e7          	jalr	-428(ra) # 80000cf4 <kfree>
    }
  }
  return 0;

 err:
  uvmunmap(new, 0, i / PGSIZE, 1);
    80001ea8:	00100693          	li	a3,1
    80001eac:	00c9d613          	srli	a2,s3,0xc
    80001eb0:	00000593          	li	a1,0
    80001eb4:	000a8513          	mv	a0,s5
    80001eb8:	00000097          	auipc	ra,0x0
    80001ebc:	a64080e7          	jalr	-1436(ra) # 8000191c <uvmunmap>
  return -1;
    80001ec0:	fff00513          	li	a0,-1
}
    80001ec4:	04813083          	ld	ra,72(sp)
    80001ec8:	04013403          	ld	s0,64(sp)
    80001ecc:	03813483          	ld	s1,56(sp)
    80001ed0:	03013903          	ld	s2,48(sp)
    80001ed4:	02813983          	ld	s3,40(sp)
    80001ed8:	02013a03          	ld	s4,32(sp)
    80001edc:	01813a83          	ld	s5,24(sp)
    80001ee0:	01013b03          	ld	s6,16(sp)
    80001ee4:	00813b83          	ld	s7,8(sp)
    80001ee8:	05010113          	addi	sp,sp,80
    80001eec:	00008067          	ret
  return 0;
    80001ef0:	00000513          	li	a0,0
}
    80001ef4:	00008067          	ret

0000000080001ef8 <uvmclear>:

// mark a PTE invalid for user access.
// used by exec for the user stack guard page.
void
uvmclear(pagetable_t pagetable, uint64 va)
{
    80001ef8:	ff010113          	addi	sp,sp,-16
    80001efc:	00113423          	sd	ra,8(sp)
    80001f00:	00813023          	sd	s0,0(sp)
    80001f04:	01010413          	addi	s0,sp,16
  pte_t *pte;
  
  pte = walk(pagetable, va, 0);
    80001f08:	00000613          	li	a2,0
    80001f0c:	fffff097          	auipc	ra,0xfffff
    80001f10:	610080e7          	jalr	1552(ra) # 8000151c <walk>
  if(pte == 0)
    80001f14:	02050063          	beqz	a0,80001f34 <uvmclear+0x3c>
    panic("uvmclear");
  *pte &= ~PTE_U;
    80001f18:	00053783          	ld	a5,0(a0)
    80001f1c:	fef7f793          	andi	a5,a5,-17
    80001f20:	00f53023          	sd	a5,0(a0)
}
    80001f24:	00813083          	ld	ra,8(sp)
    80001f28:	00013403          	ld	s0,0(sp)
    80001f2c:	01010113          	addi	sp,sp,16
    80001f30:	00008067          	ret
    panic("uvmclear");
    80001f34:	00008517          	auipc	a0,0x8
    80001f38:	29450513          	addi	a0,a0,660 # 8000a1c8 <digits+0x188>
    80001f3c:	ffffe097          	auipc	ra,0xffffe
    80001f40:	794080e7          	jalr	1940(ra) # 800006d0 <panic>

0000000080001f44 <copyout>:
int
copyout(pagetable_t pagetable, uint64 dstva, char *src, uint64 len)
{
  uint64 n, va0, pa0;

  while(len > 0){
    80001f44:	0a068663          	beqz	a3,80001ff0 <copyout+0xac>
{
    80001f48:	fb010113          	addi	sp,sp,-80
    80001f4c:	04113423          	sd	ra,72(sp)
    80001f50:	04813023          	sd	s0,64(sp)
    80001f54:	02913c23          	sd	s1,56(sp)
    80001f58:	03213823          	sd	s2,48(sp)
    80001f5c:	03313423          	sd	s3,40(sp)
    80001f60:	03413023          	sd	s4,32(sp)
    80001f64:	01513c23          	sd	s5,24(sp)
    80001f68:	01613823          	sd	s6,16(sp)
    80001f6c:	01713423          	sd	s7,8(sp)
    80001f70:	01813023          	sd	s8,0(sp)
    80001f74:	05010413          	addi	s0,sp,80
    80001f78:	00050b13          	mv	s6,a0
    80001f7c:	00058c13          	mv	s8,a1
    80001f80:	00060a13          	mv	s4,a2
    80001f84:	00068993          	mv	s3,a3
    va0 = PGROUNDDOWN(dstva);
    80001f88:	fffffbb7          	lui	s7,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if(pa0 == 0)
      return -1;
    n = PGSIZE - (dstva - va0);
    80001f8c:	00001ab7          	lui	s5,0x1
    80001f90:	02c0006f          	j	80001fbc <copyout+0x78>
    if(n > len)
      n = len;
    memmove((void *)(pa0 + (dstva - va0)), src, n);
    80001f94:	01850533          	add	a0,a0,s8
    80001f98:	0004861b          	sext.w	a2,s1
    80001f9c:	000a0593          	mv	a1,s4
    80001fa0:	41250533          	sub	a0,a0,s2
    80001fa4:	fffff097          	auipc	ra,0xfffff
    80001fa8:	214080e7          	jalr	532(ra) # 800011b8 <memmove>

    len -= n;
    80001fac:	409989b3          	sub	s3,s3,s1
    src += n;
    80001fb0:	009a0a33          	add	s4,s4,s1
    dstva = va0 + PGSIZE;
    80001fb4:	01590c33          	add	s8,s2,s5
  while(len > 0){
    80001fb8:	02098863          	beqz	s3,80001fe8 <copyout+0xa4>
    va0 = PGROUNDDOWN(dstva);
    80001fbc:	017c7933          	and	s2,s8,s7
    pa0 = walkaddr(pagetable, va0);
    80001fc0:	00090593          	mv	a1,s2
    80001fc4:	000b0513          	mv	a0,s6
    80001fc8:	fffff097          	auipc	ra,0xfffff
    80001fcc:	650080e7          	jalr	1616(ra) # 80001618 <walkaddr>
    if(pa0 == 0)
    80001fd0:	02050463          	beqz	a0,80001ff8 <copyout+0xb4>
    n = PGSIZE - (dstva - va0);
    80001fd4:	418904b3          	sub	s1,s2,s8
    80001fd8:	015484b3          	add	s1,s1,s5
    80001fdc:	fa99fce3          	bgeu	s3,s1,80001f94 <copyout+0x50>
    80001fe0:	00098493          	mv	s1,s3
    80001fe4:	fb1ff06f          	j	80001f94 <copyout+0x50>
  }
  return 0;
    80001fe8:	00000513          	li	a0,0
    80001fec:	0100006f          	j	80001ffc <copyout+0xb8>
    80001ff0:	00000513          	li	a0,0
}
    80001ff4:	00008067          	ret
      return -1;
    80001ff8:	fff00513          	li	a0,-1
}
    80001ffc:	04813083          	ld	ra,72(sp)
    80002000:	04013403          	ld	s0,64(sp)
    80002004:	03813483          	ld	s1,56(sp)
    80002008:	03013903          	ld	s2,48(sp)
    8000200c:	02813983          	ld	s3,40(sp)
    80002010:	02013a03          	ld	s4,32(sp)
    80002014:	01813a83          	ld	s5,24(sp)
    80002018:	01013b03          	ld	s6,16(sp)
    8000201c:	00813b83          	ld	s7,8(sp)
    80002020:	00013c03          	ld	s8,0(sp)
    80002024:	05010113          	addi	sp,sp,80
    80002028:	00008067          	ret

000000008000202c <copyin>:
int
copyin(pagetable_t pagetable, char *dst, uint64 srcva, uint64 len)
{
  uint64 n, va0, pa0;

  while(len > 0){
    8000202c:	0a068663          	beqz	a3,800020d8 <copyin+0xac>
{
    80002030:	fb010113          	addi	sp,sp,-80
    80002034:	04113423          	sd	ra,72(sp)
    80002038:	04813023          	sd	s0,64(sp)
    8000203c:	02913c23          	sd	s1,56(sp)
    80002040:	03213823          	sd	s2,48(sp)
    80002044:	03313423          	sd	s3,40(sp)
    80002048:	03413023          	sd	s4,32(sp)
    8000204c:	01513c23          	sd	s5,24(sp)
    80002050:	01613823          	sd	s6,16(sp)
    80002054:	01713423          	sd	s7,8(sp)
    80002058:	01813023          	sd	s8,0(sp)
    8000205c:	05010413          	addi	s0,sp,80
    80002060:	00050b13          	mv	s6,a0
    80002064:	00058a13          	mv	s4,a1
    80002068:	00060c13          	mv	s8,a2
    8000206c:	00068993          	mv	s3,a3
    va0 = PGROUNDDOWN(srcva);
    80002070:	fffffbb7          	lui	s7,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if(pa0 == 0)
      return -1;
    n = PGSIZE - (srcva - va0);
    80002074:	00001ab7          	lui	s5,0x1
    80002078:	02c0006f          	j	800020a4 <copyin+0x78>
    if(n > len)
      n = len;
    memmove(dst, (void *)(pa0 + (srcva - va0)), n);
    8000207c:	018505b3          	add	a1,a0,s8
    80002080:	0004861b          	sext.w	a2,s1
    80002084:	412585b3          	sub	a1,a1,s2
    80002088:	000a0513          	mv	a0,s4
    8000208c:	fffff097          	auipc	ra,0xfffff
    80002090:	12c080e7          	jalr	300(ra) # 800011b8 <memmove>

    len -= n;
    80002094:	409989b3          	sub	s3,s3,s1
    dst += n;
    80002098:	009a0a33          	add	s4,s4,s1
    srcva = va0 + PGSIZE;
    8000209c:	01590c33          	add	s8,s2,s5
  while(len > 0){
    800020a0:	02098863          	beqz	s3,800020d0 <copyin+0xa4>
    va0 = PGROUNDDOWN(srcva);
    800020a4:	017c7933          	and	s2,s8,s7
    pa0 = walkaddr(pagetable, va0);
    800020a8:	00090593          	mv	a1,s2
    800020ac:	000b0513          	mv	a0,s6
    800020b0:	fffff097          	auipc	ra,0xfffff
    800020b4:	568080e7          	jalr	1384(ra) # 80001618 <walkaddr>
    if(pa0 == 0)
    800020b8:	02050463          	beqz	a0,800020e0 <copyin+0xb4>
    n = PGSIZE - (srcva - va0);
    800020bc:	418904b3          	sub	s1,s2,s8
    800020c0:	015484b3          	add	s1,s1,s5
    800020c4:	fa99fce3          	bgeu	s3,s1,8000207c <copyin+0x50>
    800020c8:	00098493          	mv	s1,s3
    800020cc:	fb1ff06f          	j	8000207c <copyin+0x50>
  }
  return 0;
    800020d0:	00000513          	li	a0,0
    800020d4:	0100006f          	j	800020e4 <copyin+0xb8>
    800020d8:	00000513          	li	a0,0
}
    800020dc:	00008067          	ret
      return -1;
    800020e0:	fff00513          	li	a0,-1
}
    800020e4:	04813083          	ld	ra,72(sp)
    800020e8:	04013403          	ld	s0,64(sp)
    800020ec:	03813483          	ld	s1,56(sp)
    800020f0:	03013903          	ld	s2,48(sp)
    800020f4:	02813983          	ld	s3,40(sp)
    800020f8:	02013a03          	ld	s4,32(sp)
    800020fc:	01813a83          	ld	s5,24(sp)
    80002100:	01013b03          	ld	s6,16(sp)
    80002104:	00813b83          	ld	s7,8(sp)
    80002108:	00013c03          	ld	s8,0(sp)
    8000210c:	05010113          	addi	sp,sp,80
    80002110:	00008067          	ret

0000000080002114 <copyinstr>:
copyinstr(pagetable_t pagetable, char *dst, uint64 srcva, uint64 max)
{
  uint64 n, va0, pa0;
  int got_null = 0;

  while(got_null == 0 && max > 0){
    80002114:	10068663          	beqz	a3,80002220 <copyinstr+0x10c>
{
    80002118:	fb010113          	addi	sp,sp,-80
    8000211c:	04113423          	sd	ra,72(sp)
    80002120:	04813023          	sd	s0,64(sp)
    80002124:	02913c23          	sd	s1,56(sp)
    80002128:	03213823          	sd	s2,48(sp)
    8000212c:	03313423          	sd	s3,40(sp)
    80002130:	03413023          	sd	s4,32(sp)
    80002134:	01513c23          	sd	s5,24(sp)
    80002138:	01613823          	sd	s6,16(sp)
    8000213c:	01713423          	sd	s7,8(sp)
    80002140:	05010413          	addi	s0,sp,80
    80002144:	00050a13          	mv	s4,a0
    80002148:	00058b13          	mv	s6,a1
    8000214c:	00060b93          	mv	s7,a2
    80002150:	00068493          	mv	s1,a3
    va0 = PGROUNDDOWN(srcva);
    80002154:	fffffab7          	lui	s5,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if(pa0 == 0)
      return -1;
    n = PGSIZE - (srcva - va0);
    80002158:	000019b7          	lui	s3,0x1
    8000215c:	0480006f          	j	800021a4 <copyinstr+0x90>
      n = max;

    char *p = (char *) (pa0 + (srcva - va0));
    while(n > 0){
      if(*p == '\0'){
        *dst = '\0';
    80002160:	00078023          	sb	zero,0(a5) # 1000 <_entry-0x7ffff000>
    80002164:	00100793          	li	a5,1
      dst++;
    }

    srcva = va0 + PGSIZE;
  }
  if(got_null){
    80002168:	fff7879b          	addiw	a5,a5,-1
    8000216c:	0007851b          	sext.w	a0,a5
    return 0;
  } else {
    return -1;
  }
}
    80002170:	04813083          	ld	ra,72(sp)
    80002174:	04013403          	ld	s0,64(sp)
    80002178:	03813483          	ld	s1,56(sp)
    8000217c:	03013903          	ld	s2,48(sp)
    80002180:	02813983          	ld	s3,40(sp)
    80002184:	02013a03          	ld	s4,32(sp)
    80002188:	01813a83          	ld	s5,24(sp)
    8000218c:	01013b03          	ld	s6,16(sp)
    80002190:	00813b83          	ld	s7,8(sp)
    80002194:	05010113          	addi	sp,sp,80
    80002198:	00008067          	ret
    srcva = va0 + PGSIZE;
    8000219c:	01390bb3          	add	s7,s2,s3
  while(got_null == 0 && max > 0){
    800021a0:	06048863          	beqz	s1,80002210 <copyinstr+0xfc>
    va0 = PGROUNDDOWN(srcva);
    800021a4:	015bf933          	and	s2,s7,s5
    pa0 = walkaddr(pagetable, va0);
    800021a8:	00090593          	mv	a1,s2
    800021ac:	000a0513          	mv	a0,s4
    800021b0:	fffff097          	auipc	ra,0xfffff
    800021b4:	468080e7          	jalr	1128(ra) # 80001618 <walkaddr>
    if(pa0 == 0)
    800021b8:	06050063          	beqz	a0,80002218 <copyinstr+0x104>
    n = PGSIZE - (srcva - va0);
    800021bc:	417906b3          	sub	a3,s2,s7
    800021c0:	013686b3          	add	a3,a3,s3
    800021c4:	00d4f463          	bgeu	s1,a3,800021cc <copyinstr+0xb8>
    800021c8:	00048693          	mv	a3,s1
    char *p = (char *) (pa0 + (srcva - va0));
    800021cc:	01750533          	add	a0,a0,s7
    800021d0:	41250533          	sub	a0,a0,s2
    while(n > 0){
    800021d4:	fc0684e3          	beqz	a3,8000219c <copyinstr+0x88>
    800021d8:	000b0793          	mv	a5,s6
      if(*p == '\0'){
    800021dc:	41650633          	sub	a2,a0,s6
    800021e0:	fff48593          	addi	a1,s1,-1
    800021e4:	00bb05b3          	add	a1,s6,a1
    while(n > 0){
    800021e8:	00db06b3          	add	a3,s6,a3
      if(*p == '\0'){
    800021ec:	00f60733          	add	a4,a2,a5
    800021f0:	00074703          	lbu	a4,0(a4) # fffffffffffff000 <end+0xffffffff7ffd7000>
    800021f4:	f60706e3          	beqz	a4,80002160 <copyinstr+0x4c>
        *dst = *p;
    800021f8:	00e78023          	sb	a4,0(a5)
      --max;
    800021fc:	40f584b3          	sub	s1,a1,a5
      dst++;
    80002200:	00178793          	addi	a5,a5,1
    while(n > 0){
    80002204:	fed794e3          	bne	a5,a3,800021ec <copyinstr+0xd8>
      dst++;
    80002208:	00078b13          	mv	s6,a5
    8000220c:	f91ff06f          	j	8000219c <copyinstr+0x88>
    80002210:	00000793          	li	a5,0
    80002214:	f55ff06f          	j	80002168 <copyinstr+0x54>
      return -1;
    80002218:	fff00513          	li	a0,-1
    8000221c:	f55ff06f          	j	80002170 <copyinstr+0x5c>
  int got_null = 0;
    80002220:	00000793          	li	a5,0
  if(got_null){
    80002224:	fff7879b          	addiw	a5,a5,-1
    80002228:	0007851b          	sext.w	a0,a5
}
    8000222c:	00008067          	ret

0000000080002230 <proc_mapstacks>:

// Allocate a page for each process's kernel stack.
// Map it high in memory, followed by an invalid
// guard page.
void
proc_mapstacks(pagetable_t kpgtbl) {
    80002230:	fc010113          	addi	sp,sp,-64
    80002234:	02113c23          	sd	ra,56(sp)
    80002238:	02813823          	sd	s0,48(sp)
    8000223c:	02913423          	sd	s1,40(sp)
    80002240:	03213023          	sd	s2,32(sp)
    80002244:	01313c23          	sd	s3,24(sp)
    80002248:	01413823          	sd	s4,16(sp)
    8000224c:	01513423          	sd	s5,8(sp)
    80002250:	01613023          	sd	s6,0(sp)
    80002254:	04010413          	addi	s0,sp,64
    80002258:	00050993          	mv	s3,a0
  struct proc *p;
  
  for(p = proc; p < &proc[NPROC]; p++) {
    8000225c:	00011497          	auipc	s1,0x11
    80002260:	47448493          	addi	s1,s1,1140 # 800136d0 <proc>
    char *pa = kalloc();
    if(pa == 0)
      panic("kalloc");
    uint64 va = KSTACK((int) (p - proc));
    80002264:	00048b13          	mv	s6,s1
    80002268:	00008a97          	auipc	s5,0x8
    8000226c:	d98a8a93          	addi	s5,s5,-616 # 8000a000 <etext>
    80002270:	04000937          	lui	s2,0x4000
    80002274:	fff90913          	addi	s2,s2,-1 # 3ffffff <_entry-0x7c000001>
    80002278:	00c91913          	slli	s2,s2,0xc
  for(p = proc; p < &proc[NPROC]; p++) {
    8000227c:	00017a17          	auipc	s4,0x17
    80002280:	e54a0a13          	addi	s4,s4,-428 # 800190d0 <tickslock>
    char *pa = kalloc();
    80002284:	fffff097          	auipc	ra,0xfffff
    80002288:	bdc080e7          	jalr	-1060(ra) # 80000e60 <kalloc>
    8000228c:	00050613          	mv	a2,a0
    if(pa == 0)
    80002290:	06050263          	beqz	a0,800022f4 <proc_mapstacks+0xc4>
    uint64 va = KSTACK((int) (p - proc));
    80002294:	416485b3          	sub	a1,s1,s6
    80002298:	4035d593          	srai	a1,a1,0x3
    8000229c:	000ab783          	ld	a5,0(s5)
    800022a0:	02f585b3          	mul	a1,a1,a5
    800022a4:	0015859b          	addiw	a1,a1,1
    800022a8:	00d5959b          	slliw	a1,a1,0xd
    kvmmap(kpgtbl, va, (uint64)pa, PGSIZE, PTE_R | PTE_W);
    800022ac:	00600713          	li	a4,6
    800022b0:	000016b7          	lui	a3,0x1
    800022b4:	40b905b3          	sub	a1,s2,a1
    800022b8:	00098513          	mv	a0,s3
    800022bc:	fffff097          	auipc	ra,0xfffff
    800022c0:	4c0080e7          	jalr	1216(ra) # 8000177c <kvmmap>
  for(p = proc; p < &proc[NPROC]; p++) {
    800022c4:	16848493          	addi	s1,s1,360
    800022c8:	fb449ee3          	bne	s1,s4,80002284 <proc_mapstacks+0x54>
  }
}
    800022cc:	03813083          	ld	ra,56(sp)
    800022d0:	03013403          	ld	s0,48(sp)
    800022d4:	02813483          	ld	s1,40(sp)
    800022d8:	02013903          	ld	s2,32(sp)
    800022dc:	01813983          	ld	s3,24(sp)
    800022e0:	01013a03          	ld	s4,16(sp)
    800022e4:	00813a83          	ld	s5,8(sp)
    800022e8:	00013b03          	ld	s6,0(sp)
    800022ec:	04010113          	addi	sp,sp,64
    800022f0:	00008067          	ret
      panic("kalloc");
    800022f4:	00008517          	auipc	a0,0x8
    800022f8:	ee450513          	addi	a0,a0,-284 # 8000a1d8 <digits+0x198>
    800022fc:	ffffe097          	auipc	ra,0xffffe
    80002300:	3d4080e7          	jalr	980(ra) # 800006d0 <panic>

0000000080002304 <procinit>:

// initialize the proc table at boot time.
void
procinit(void)
{
    80002304:	fc010113          	addi	sp,sp,-64
    80002308:	02113c23          	sd	ra,56(sp)
    8000230c:	02813823          	sd	s0,48(sp)
    80002310:	02913423          	sd	s1,40(sp)
    80002314:	03213023          	sd	s2,32(sp)
    80002318:	01313c23          	sd	s3,24(sp)
    8000231c:	01413823          	sd	s4,16(sp)
    80002320:	01513423          	sd	s5,8(sp)
    80002324:	01613023          	sd	s6,0(sp)
    80002328:	04010413          	addi	s0,sp,64
  struct proc *p;
  
  initlock(&pid_lock, "nextpid");
    8000232c:	00008597          	auipc	a1,0x8
    80002330:	eb458593          	addi	a1,a1,-332 # 8000a1e0 <digits+0x1a0>
    80002334:	00011517          	auipc	a0,0x11
    80002338:	f6c50513          	addi	a0,a0,-148 # 800132a0 <pid_lock>
    8000233c:	fffff097          	auipc	ra,0xfffff
    80002340:	bac080e7          	jalr	-1108(ra) # 80000ee8 <initlock>
  initlock(&wait_lock, "wait_lock");
    80002344:	00008597          	auipc	a1,0x8
    80002348:	ea458593          	addi	a1,a1,-348 # 8000a1e8 <digits+0x1a8>
    8000234c:	00011517          	auipc	a0,0x11
    80002350:	f6c50513          	addi	a0,a0,-148 # 800132b8 <wait_lock>
    80002354:	fffff097          	auipc	ra,0xfffff
    80002358:	b94080e7          	jalr	-1132(ra) # 80000ee8 <initlock>
  for(p = proc; p < &proc[NPROC]; p++) {
    8000235c:	00011497          	auipc	s1,0x11
    80002360:	37448493          	addi	s1,s1,884 # 800136d0 <proc>
      initlock(&p->lock, "proc");
    80002364:	00008b17          	auipc	s6,0x8
    80002368:	e94b0b13          	addi	s6,s6,-364 # 8000a1f8 <digits+0x1b8>
      p->kstack = KSTACK((int) (p - proc));
    8000236c:	00048a93          	mv	s5,s1
    80002370:	00008a17          	auipc	s4,0x8
    80002374:	c90a0a13          	addi	s4,s4,-880 # 8000a000 <etext>
    80002378:	04000937          	lui	s2,0x4000
    8000237c:	fff90913          	addi	s2,s2,-1 # 3ffffff <_entry-0x7c000001>
    80002380:	00c91913          	slli	s2,s2,0xc
  for(p = proc; p < &proc[NPROC]; p++) {
    80002384:	00017997          	auipc	s3,0x17
    80002388:	d4c98993          	addi	s3,s3,-692 # 800190d0 <tickslock>
      initlock(&p->lock, "proc");
    8000238c:	000b0593          	mv	a1,s6
    80002390:	00048513          	mv	a0,s1
    80002394:	fffff097          	auipc	ra,0xfffff
    80002398:	b54080e7          	jalr	-1196(ra) # 80000ee8 <initlock>
      p->kstack = KSTACK((int) (p - proc));
    8000239c:	415487b3          	sub	a5,s1,s5
    800023a0:	4037d793          	srai	a5,a5,0x3
    800023a4:	000a3703          	ld	a4,0(s4)
    800023a8:	02e787b3          	mul	a5,a5,a4
    800023ac:	0017879b          	addiw	a5,a5,1
    800023b0:	00d7979b          	slliw	a5,a5,0xd
    800023b4:	40f907b3          	sub	a5,s2,a5
    800023b8:	04f4b023          	sd	a5,64(s1)
  for(p = proc; p < &proc[NPROC]; p++) {
    800023bc:	16848493          	addi	s1,s1,360
    800023c0:	fd3496e3          	bne	s1,s3,8000238c <procinit+0x88>
  }
}
    800023c4:	03813083          	ld	ra,56(sp)
    800023c8:	03013403          	ld	s0,48(sp)
    800023cc:	02813483          	ld	s1,40(sp)
    800023d0:	02013903          	ld	s2,32(sp)
    800023d4:	01813983          	ld	s3,24(sp)
    800023d8:	01013a03          	ld	s4,16(sp)
    800023dc:	00813a83          	ld	s5,8(sp)
    800023e0:	00013b03          	ld	s6,0(sp)
    800023e4:	04010113          	addi	sp,sp,64
    800023e8:	00008067          	ret

00000000800023ec <cpuid>:
// Must be called with interrupts disabled,
// to prevent race with process being moved
// to a different CPU.
int
cpuid()
{
    800023ec:	ff010113          	addi	sp,sp,-16
    800023f0:	00813423          	sd	s0,8(sp)
    800023f4:	01010413          	addi	s0,sp,16
  asm volatile("mv %0, tp" : "=r" (x) );
    800023f8:	00020513          	mv	a0,tp
  int id = r_tp();
  return id;
}
    800023fc:	0005051b          	sext.w	a0,a0
    80002400:	00813403          	ld	s0,8(sp)
    80002404:	01010113          	addi	sp,sp,16
    80002408:	00008067          	ret

000000008000240c <mycpu>:

// Return this CPU's cpu struct.
// Interrupts must be disabled.
struct cpu*
mycpu(void) {
    8000240c:	ff010113          	addi	sp,sp,-16
    80002410:	00813423          	sd	s0,8(sp)
    80002414:	01010413          	addi	s0,sp,16
    80002418:	00020793          	mv	a5,tp
  int id = cpuid();
  struct cpu *c = &cpus[id];
    8000241c:	0007879b          	sext.w	a5,a5
    80002420:	00779793          	slli	a5,a5,0x7
  return c;
}
    80002424:	00011517          	auipc	a0,0x11
    80002428:	eac50513          	addi	a0,a0,-340 # 800132d0 <cpus>
    8000242c:	00f50533          	add	a0,a0,a5
    80002430:	00813403          	ld	s0,8(sp)
    80002434:	01010113          	addi	sp,sp,16
    80002438:	00008067          	ret

000000008000243c <myproc>:

// Return the current struct proc *, or zero if none.
struct proc*
myproc(void) {
    8000243c:	fe010113          	addi	sp,sp,-32
    80002440:	00113c23          	sd	ra,24(sp)
    80002444:	00813823          	sd	s0,16(sp)
    80002448:	00913423          	sd	s1,8(sp)
    8000244c:	02010413          	addi	s0,sp,32
  push_off();
    80002450:	fffff097          	auipc	ra,0xfffff
    80002454:	b08080e7          	jalr	-1272(ra) # 80000f58 <push_off>
    80002458:	00020793          	mv	a5,tp
  struct cpu *c = mycpu();
  struct proc *p = c->proc;
    8000245c:	0007879b          	sext.w	a5,a5
    80002460:	00779793          	slli	a5,a5,0x7
    80002464:	00011717          	auipc	a4,0x11
    80002468:	e3c70713          	addi	a4,a4,-452 # 800132a0 <pid_lock>
    8000246c:	00f707b3          	add	a5,a4,a5
    80002470:	0307b483          	ld	s1,48(a5)
  pop_off();
    80002474:	fffff097          	auipc	ra,0xfffff
    80002478:	bd0080e7          	jalr	-1072(ra) # 80001044 <pop_off>
  return p;
}
    8000247c:	00048513          	mv	a0,s1
    80002480:	01813083          	ld	ra,24(sp)
    80002484:	01013403          	ld	s0,16(sp)
    80002488:	00813483          	ld	s1,8(sp)
    8000248c:	02010113          	addi	sp,sp,32
    80002490:	00008067          	ret

0000000080002494 <forkret>:

// A fork child's very first scheduling by scheduler()
// will swtch to forkret.
void
forkret(void)
{
    80002494:	ff010113          	addi	sp,sp,-16
    80002498:	00113423          	sd	ra,8(sp)
    8000249c:	00813023          	sd	s0,0(sp)
    800024a0:	01010413          	addi	s0,sp,16
  static int first = 1;

  // Still holding p->lock from scheduler.
  release(&myproc()->lock);
    800024a4:	00000097          	auipc	ra,0x0
    800024a8:	f98080e7          	jalr	-104(ra) # 8000243c <myproc>
    800024ac:	fffff097          	auipc	ra,0xfffff
    800024b0:	c18080e7          	jalr	-1000(ra) # 800010c4 <release>

  if (first) {
    800024b4:	00008797          	auipc	a5,0x8
    800024b8:	35c7a783          	lw	a5,860(a5) # 8000a810 <first.1>
    800024bc:	00079e63          	bnez	a5,800024d8 <forkret+0x44>
    // be run from main().
    first = 0;
    fsinit(ROOTDEV);
  }

  usertrapret();
    800024c0:	00001097          	auipc	ra,0x1
    800024c4:	0c8080e7          	jalr	200(ra) # 80003588 <usertrapret>
}
    800024c8:	00813083          	ld	ra,8(sp)
    800024cc:	00013403          	ld	s0,0(sp)
    800024d0:	01010113          	addi	sp,sp,16
    800024d4:	00008067          	ret
    first = 0;
    800024d8:	00008797          	auipc	a5,0x8
    800024dc:	3207ac23          	sw	zero,824(a5) # 8000a810 <first.1>
    fsinit(ROOTDEV);
    800024e0:	00100513          	li	a0,1
    800024e4:	00002097          	auipc	ra,0x2
    800024e8:	318080e7          	jalr	792(ra) # 800047fc <fsinit>
    800024ec:	fd5ff06f          	j	800024c0 <forkret+0x2c>

00000000800024f0 <allocpid>:
allocpid() {
    800024f0:	fe010113          	addi	sp,sp,-32
    800024f4:	00113c23          	sd	ra,24(sp)
    800024f8:	00813823          	sd	s0,16(sp)
    800024fc:	00913423          	sd	s1,8(sp)
    80002500:	01213023          	sd	s2,0(sp)
    80002504:	02010413          	addi	s0,sp,32
  acquire(&pid_lock);
    80002508:	00011917          	auipc	s2,0x11
    8000250c:	d9890913          	addi	s2,s2,-616 # 800132a0 <pid_lock>
    80002510:	00090513          	mv	a0,s2
    80002514:	fffff097          	auipc	ra,0xfffff
    80002518:	ab8080e7          	jalr	-1352(ra) # 80000fcc <acquire>
  pid = nextpid;
    8000251c:	00008797          	auipc	a5,0x8
    80002520:	2f878793          	addi	a5,a5,760 # 8000a814 <nextpid>
    80002524:	0007a483          	lw	s1,0(a5)
  nextpid = nextpid + 1;
    80002528:	0014871b          	addiw	a4,s1,1
    8000252c:	00e7a023          	sw	a4,0(a5)
  release(&pid_lock);
    80002530:	00090513          	mv	a0,s2
    80002534:	fffff097          	auipc	ra,0xfffff
    80002538:	b90080e7          	jalr	-1136(ra) # 800010c4 <release>
}
    8000253c:	00048513          	mv	a0,s1
    80002540:	01813083          	ld	ra,24(sp)
    80002544:	01013403          	ld	s0,16(sp)
    80002548:	00813483          	ld	s1,8(sp)
    8000254c:	00013903          	ld	s2,0(sp)
    80002550:	02010113          	addi	sp,sp,32
    80002554:	00008067          	ret

0000000080002558 <proc_pagetable>:
{
    80002558:	fe010113          	addi	sp,sp,-32
    8000255c:	00113c23          	sd	ra,24(sp)
    80002560:	00813823          	sd	s0,16(sp)
    80002564:	00913423          	sd	s1,8(sp)
    80002568:	01213023          	sd	s2,0(sp)
    8000256c:	02010413          	addi	s0,sp,32
    80002570:	00050913          	mv	s2,a0
  pagetable = uvmcreate();
    80002574:	fffff097          	auipc	ra,0xfffff
    80002578:	4bc080e7          	jalr	1212(ra) # 80001a30 <uvmcreate>
    8000257c:	00050493          	mv	s1,a0
  if(pagetable == 0)
    80002580:	04050a63          	beqz	a0,800025d4 <proc_pagetable+0x7c>
  if(mappages(pagetable, TRAMPOLINE, PGSIZE,
    80002584:	00a00713          	li	a4,10
    80002588:	00007697          	auipc	a3,0x7
    8000258c:	a7868693          	addi	a3,a3,-1416 # 80009000 <_trampoline>
    80002590:	00001637          	lui	a2,0x1
    80002594:	040005b7          	lui	a1,0x4000
    80002598:	fff58593          	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    8000259c:	00c59593          	slli	a1,a1,0xc
    800025a0:	fffff097          	auipc	ra,0xfffff
    800025a4:	0e4080e7          	jalr	228(ra) # 80001684 <mappages>
    800025a8:	04054463          	bltz	a0,800025f0 <proc_pagetable+0x98>
  if(mappages(pagetable, TRAPFRAME, PGSIZE,
    800025ac:	00600713          	li	a4,6
    800025b0:	05893683          	ld	a3,88(s2)
    800025b4:	00001637          	lui	a2,0x1
    800025b8:	020005b7          	lui	a1,0x2000
    800025bc:	fff58593          	addi	a1,a1,-1 # 1ffffff <_entry-0x7e000001>
    800025c0:	00d59593          	slli	a1,a1,0xd
    800025c4:	00048513          	mv	a0,s1
    800025c8:	fffff097          	auipc	ra,0xfffff
    800025cc:	0bc080e7          	jalr	188(ra) # 80001684 <mappages>
    800025d0:	02054c63          	bltz	a0,80002608 <proc_pagetable+0xb0>
}
    800025d4:	00048513          	mv	a0,s1
    800025d8:	01813083          	ld	ra,24(sp)
    800025dc:	01013403          	ld	s0,16(sp)
    800025e0:	00813483          	ld	s1,8(sp)
    800025e4:	00013903          	ld	s2,0(sp)
    800025e8:	02010113          	addi	sp,sp,32
    800025ec:	00008067          	ret
    uvmfree(pagetable, 0);
    800025f0:	00000593          	li	a1,0
    800025f4:	00048513          	mv	a0,s1
    800025f8:	fffff097          	auipc	ra,0xfffff
    800025fc:	764080e7          	jalr	1892(ra) # 80001d5c <uvmfree>
    return 0;
    80002600:	00000493          	li	s1,0
    80002604:	fd1ff06f          	j	800025d4 <proc_pagetable+0x7c>
    uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    80002608:	00000693          	li	a3,0
    8000260c:	00100613          	li	a2,1
    80002610:	040005b7          	lui	a1,0x4000
    80002614:	fff58593          	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    80002618:	00c59593          	slli	a1,a1,0xc
    8000261c:	00048513          	mv	a0,s1
    80002620:	fffff097          	auipc	ra,0xfffff
    80002624:	2fc080e7          	jalr	764(ra) # 8000191c <uvmunmap>
    uvmfree(pagetable, 0);
    80002628:	00000593          	li	a1,0
    8000262c:	00048513          	mv	a0,s1
    80002630:	fffff097          	auipc	ra,0xfffff
    80002634:	72c080e7          	jalr	1836(ra) # 80001d5c <uvmfree>
    return 0;
    80002638:	00000493          	li	s1,0
    8000263c:	f99ff06f          	j	800025d4 <proc_pagetable+0x7c>

0000000080002640 <proc_freepagetable>:
{
    80002640:	fe010113          	addi	sp,sp,-32
    80002644:	00113c23          	sd	ra,24(sp)
    80002648:	00813823          	sd	s0,16(sp)
    8000264c:	00913423          	sd	s1,8(sp)
    80002650:	01213023          	sd	s2,0(sp)
    80002654:	02010413          	addi	s0,sp,32
    80002658:	00050493          	mv	s1,a0
    8000265c:	00058913          	mv	s2,a1
  uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    80002660:	00000693          	li	a3,0
    80002664:	00100613          	li	a2,1
    80002668:	040005b7          	lui	a1,0x4000
    8000266c:	fff58593          	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    80002670:	00c59593          	slli	a1,a1,0xc
    80002674:	fffff097          	auipc	ra,0xfffff
    80002678:	2a8080e7          	jalr	680(ra) # 8000191c <uvmunmap>
  uvmunmap(pagetable, TRAPFRAME, 1, 0);
    8000267c:	00000693          	li	a3,0
    80002680:	00100613          	li	a2,1
    80002684:	020005b7          	lui	a1,0x2000
    80002688:	fff58593          	addi	a1,a1,-1 # 1ffffff <_entry-0x7e000001>
    8000268c:	00d59593          	slli	a1,a1,0xd
    80002690:	00048513          	mv	a0,s1
    80002694:	fffff097          	auipc	ra,0xfffff
    80002698:	288080e7          	jalr	648(ra) # 8000191c <uvmunmap>
  uvmfree(pagetable, sz);
    8000269c:	00090593          	mv	a1,s2
    800026a0:	00048513          	mv	a0,s1
    800026a4:	fffff097          	auipc	ra,0xfffff
    800026a8:	6b8080e7          	jalr	1720(ra) # 80001d5c <uvmfree>
}
    800026ac:	01813083          	ld	ra,24(sp)
    800026b0:	01013403          	ld	s0,16(sp)
    800026b4:	00813483          	ld	s1,8(sp)
    800026b8:	00013903          	ld	s2,0(sp)
    800026bc:	02010113          	addi	sp,sp,32
    800026c0:	00008067          	ret

00000000800026c4 <freeproc>:
{
    800026c4:	fe010113          	addi	sp,sp,-32
    800026c8:	00113c23          	sd	ra,24(sp)
    800026cc:	00813823          	sd	s0,16(sp)
    800026d0:	00913423          	sd	s1,8(sp)
    800026d4:	02010413          	addi	s0,sp,32
    800026d8:	00050493          	mv	s1,a0
  if(p->trapframe)
    800026dc:	05853503          	ld	a0,88(a0)
    800026e0:	00050663          	beqz	a0,800026ec <freeproc+0x28>
    kfree((void*)p->trapframe);
    800026e4:	ffffe097          	auipc	ra,0xffffe
    800026e8:	610080e7          	jalr	1552(ra) # 80000cf4 <kfree>
  p->trapframe = 0;
    800026ec:	0404bc23          	sd	zero,88(s1)
  if(p->pagetable)
    800026f0:	0504b503          	ld	a0,80(s1)
    800026f4:	00050863          	beqz	a0,80002704 <freeproc+0x40>
    proc_freepagetable(p->pagetable, p->sz);
    800026f8:	0484b583          	ld	a1,72(s1)
    800026fc:	00000097          	auipc	ra,0x0
    80002700:	f44080e7          	jalr	-188(ra) # 80002640 <proc_freepagetable>
  p->pagetable = 0;
    80002704:	0404b823          	sd	zero,80(s1)
  p->sz = 0;
    80002708:	0404b423          	sd	zero,72(s1)
  p->pid = 0;
    8000270c:	0204a823          	sw	zero,48(s1)
  p->parent = 0;
    80002710:	0204bc23          	sd	zero,56(s1)
  p->name[0] = 0;
    80002714:	14048c23          	sb	zero,344(s1)
  p->chan = 0;
    80002718:	0204b023          	sd	zero,32(s1)
  p->killed = 0;
    8000271c:	0204a423          	sw	zero,40(s1)
  p->xstate = 0;
    80002720:	0204a623          	sw	zero,44(s1)
  p->state = UNUSED;
    80002724:	0004ac23          	sw	zero,24(s1)
}
    80002728:	01813083          	ld	ra,24(sp)
    8000272c:	01013403          	ld	s0,16(sp)
    80002730:	00813483          	ld	s1,8(sp)
    80002734:	02010113          	addi	sp,sp,32
    80002738:	00008067          	ret

000000008000273c <allocproc>:
{
    8000273c:	fe010113          	addi	sp,sp,-32
    80002740:	00113c23          	sd	ra,24(sp)
    80002744:	00813823          	sd	s0,16(sp)
    80002748:	00913423          	sd	s1,8(sp)
    8000274c:	01213023          	sd	s2,0(sp)
    80002750:	02010413          	addi	s0,sp,32
  for(p = proc; p < &proc[NPROC]; p++) {
    80002754:	00011497          	auipc	s1,0x11
    80002758:	f7c48493          	addi	s1,s1,-132 # 800136d0 <proc>
    8000275c:	00017917          	auipc	s2,0x17
    80002760:	97490913          	addi	s2,s2,-1676 # 800190d0 <tickslock>
    acquire(&p->lock);
    80002764:	00048513          	mv	a0,s1
    80002768:	fffff097          	auipc	ra,0xfffff
    8000276c:	864080e7          	jalr	-1948(ra) # 80000fcc <acquire>
    if(p->state == UNUSED) {
    80002770:	0184a783          	lw	a5,24(s1)
    80002774:	02078063          	beqz	a5,80002794 <allocproc+0x58>
      release(&p->lock);
    80002778:	00048513          	mv	a0,s1
    8000277c:	fffff097          	auipc	ra,0xfffff
    80002780:	948080e7          	jalr	-1720(ra) # 800010c4 <release>
  for(p = proc; p < &proc[NPROC]; p++) {
    80002784:	16848493          	addi	s1,s1,360
    80002788:	fd249ee3          	bne	s1,s2,80002764 <allocproc+0x28>
  return 0;
    8000278c:	00000493          	li	s1,0
    80002790:	0740006f          	j	80002804 <allocproc+0xc8>
  p->pid = allocpid();
    80002794:	00000097          	auipc	ra,0x0
    80002798:	d5c080e7          	jalr	-676(ra) # 800024f0 <allocpid>
    8000279c:	02a4a823          	sw	a0,48(s1)
  p->state = USED;
    800027a0:	00100793          	li	a5,1
    800027a4:	00f4ac23          	sw	a5,24(s1)
  if((p->trapframe = (struct trapframe *)kalloc()) == 0){
    800027a8:	ffffe097          	auipc	ra,0xffffe
    800027ac:	6b8080e7          	jalr	1720(ra) # 80000e60 <kalloc>
    800027b0:	00050913          	mv	s2,a0
    800027b4:	04a4bc23          	sd	a0,88(s1)
    800027b8:	06050463          	beqz	a0,80002820 <allocproc+0xe4>
  p->pagetable = proc_pagetable(p);
    800027bc:	00048513          	mv	a0,s1
    800027c0:	00000097          	auipc	ra,0x0
    800027c4:	d98080e7          	jalr	-616(ra) # 80002558 <proc_pagetable>
    800027c8:	00050913          	mv	s2,a0
    800027cc:	04a4b823          	sd	a0,80(s1)
  if(p->pagetable == 0){
    800027d0:	06050863          	beqz	a0,80002840 <allocproc+0x104>
  memset(&p->context, 0, sizeof(p->context));
    800027d4:	07000613          	li	a2,112
    800027d8:	00000593          	li	a1,0
    800027dc:	06048513          	addi	a0,s1,96
    800027e0:	fffff097          	auipc	ra,0xfffff
    800027e4:	944080e7          	jalr	-1724(ra) # 80001124 <memset>
  p->context.ra = (uint64)forkret;
    800027e8:	00000797          	auipc	a5,0x0
    800027ec:	cac78793          	addi	a5,a5,-852 # 80002494 <forkret>
    800027f0:	06f4b023          	sd	a5,96(s1)
  p->context.sp = p->kstack + PGSIZE;
    800027f4:	0404b783          	ld	a5,64(s1)
    800027f8:	00001737          	lui	a4,0x1
    800027fc:	00e787b3          	add	a5,a5,a4
    80002800:	06f4b423          	sd	a5,104(s1)
}
    80002804:	00048513          	mv	a0,s1
    80002808:	01813083          	ld	ra,24(sp)
    8000280c:	01013403          	ld	s0,16(sp)
    80002810:	00813483          	ld	s1,8(sp)
    80002814:	00013903          	ld	s2,0(sp)
    80002818:	02010113          	addi	sp,sp,32
    8000281c:	00008067          	ret
    freeproc(p);
    80002820:	00048513          	mv	a0,s1
    80002824:	00000097          	auipc	ra,0x0
    80002828:	ea0080e7          	jalr	-352(ra) # 800026c4 <freeproc>
    release(&p->lock);
    8000282c:	00048513          	mv	a0,s1
    80002830:	fffff097          	auipc	ra,0xfffff
    80002834:	894080e7          	jalr	-1900(ra) # 800010c4 <release>
    return 0;
    80002838:	00090493          	mv	s1,s2
    8000283c:	fc9ff06f          	j	80002804 <allocproc+0xc8>
    freeproc(p);
    80002840:	00048513          	mv	a0,s1
    80002844:	00000097          	auipc	ra,0x0
    80002848:	e80080e7          	jalr	-384(ra) # 800026c4 <freeproc>
    release(&p->lock);
    8000284c:	00048513          	mv	a0,s1
    80002850:	fffff097          	auipc	ra,0xfffff
    80002854:	874080e7          	jalr	-1932(ra) # 800010c4 <release>
    return 0;
    80002858:	00090493          	mv	s1,s2
    8000285c:	fa9ff06f          	j	80002804 <allocproc+0xc8>

0000000080002860 <userinit>:
{
    80002860:	fe010113          	addi	sp,sp,-32
    80002864:	00113c23          	sd	ra,24(sp)
    80002868:	00813823          	sd	s0,16(sp)
    8000286c:	00913423          	sd	s1,8(sp)
    80002870:	02010413          	addi	s0,sp,32
  p = allocproc();
    80002874:	00000097          	auipc	ra,0x0
    80002878:	ec8080e7          	jalr	-312(ra) # 8000273c <allocproc>
    8000287c:	00050493          	mv	s1,a0
  initproc = p;
    80002880:	00008797          	auipc	a5,0x8
    80002884:	7aa7b423          	sd	a0,1960(a5) # 8000b028 <initproc>
  uvminit(p->pagetable, initcode, sizeof(initcode));
    80002888:	03400613          	li	a2,52
    8000288c:	00008597          	auipc	a1,0x8
    80002890:	f9458593          	addi	a1,a1,-108 # 8000a820 <initcode>
    80002894:	05053503          	ld	a0,80(a0)
    80002898:	fffff097          	auipc	ra,0xfffff
    8000289c:	1e4080e7          	jalr	484(ra) # 80001a7c <uvminit>
  p->sz = PGSIZE;
    800028a0:	000017b7          	lui	a5,0x1
    800028a4:	04f4b423          	sd	a5,72(s1)
  p->trapframe->epc = 0;      // user program counter
    800028a8:	0584b703          	ld	a4,88(s1)
    800028ac:	00073c23          	sd	zero,24(a4) # 1018 <_entry-0x7fffefe8>
  p->trapframe->sp = PGSIZE;  // user stack pointer
    800028b0:	0584b703          	ld	a4,88(s1)
    800028b4:	02f73823          	sd	a5,48(a4)
  safestrcpy(p->name, "initcode", sizeof(p->name));
    800028b8:	01000613          	li	a2,16
    800028bc:	00008597          	auipc	a1,0x8
    800028c0:	94458593          	addi	a1,a1,-1724 # 8000a200 <digits+0x1c0>
    800028c4:	15848513          	addi	a0,s1,344
    800028c8:	fffff097          	auipc	ra,0xfffff
    800028cc:	a5c080e7          	jalr	-1444(ra) # 80001324 <safestrcpy>
  p->cwd = namei("/");
    800028d0:	00008517          	auipc	a0,0x8
    800028d4:	94050513          	addi	a0,a0,-1728 # 8000a210 <digits+0x1d0>
    800028d8:	00003097          	auipc	ra,0x3
    800028dc:	d88080e7          	jalr	-632(ra) # 80005660 <namei>
    800028e0:	14a4b823          	sd	a0,336(s1)
  p->state = RUNNABLE;
    800028e4:	00300793          	li	a5,3
    800028e8:	00f4ac23          	sw	a5,24(s1)
  release(&p->lock);
    800028ec:	00048513          	mv	a0,s1
    800028f0:	ffffe097          	auipc	ra,0xffffe
    800028f4:	7d4080e7          	jalr	2004(ra) # 800010c4 <release>
}
    800028f8:	01813083          	ld	ra,24(sp)
    800028fc:	01013403          	ld	s0,16(sp)
    80002900:	00813483          	ld	s1,8(sp)
    80002904:	02010113          	addi	sp,sp,32
    80002908:	00008067          	ret

000000008000290c <growproc>:
{
    8000290c:	fe010113          	addi	sp,sp,-32
    80002910:	00113c23          	sd	ra,24(sp)
    80002914:	00813823          	sd	s0,16(sp)
    80002918:	00913423          	sd	s1,8(sp)
    8000291c:	01213023          	sd	s2,0(sp)
    80002920:	02010413          	addi	s0,sp,32
    80002924:	00050493          	mv	s1,a0
  struct proc *p = myproc();
    80002928:	00000097          	auipc	ra,0x0
    8000292c:	b14080e7          	jalr	-1260(ra) # 8000243c <myproc>
    80002930:	00050913          	mv	s2,a0
  sz = p->sz;
    80002934:	04853583          	ld	a1,72(a0)
    80002938:	0005879b          	sext.w	a5,a1
  if(n > 0){
    8000293c:	02904863          	bgtz	s1,8000296c <growproc+0x60>
  } else if(n < 0){
    80002940:	0404ce63          	bltz	s1,8000299c <growproc+0x90>
  p->sz = sz;
    80002944:	02079793          	slli	a5,a5,0x20
    80002948:	0207d793          	srli	a5,a5,0x20
    8000294c:	04f93423          	sd	a5,72(s2)
  return 0;
    80002950:	00000513          	li	a0,0
}
    80002954:	01813083          	ld	ra,24(sp)
    80002958:	01013403          	ld	s0,16(sp)
    8000295c:	00813483          	ld	s1,8(sp)
    80002960:	00013903          	ld	s2,0(sp)
    80002964:	02010113          	addi	sp,sp,32
    80002968:	00008067          	ret
    if((sz = uvmalloc(p->pagetable, sz, sz + n)) == 0) {
    8000296c:	00f4863b          	addw	a2,s1,a5
    80002970:	02061613          	slli	a2,a2,0x20
    80002974:	02065613          	srli	a2,a2,0x20
    80002978:	02059593          	slli	a1,a1,0x20
    8000297c:	0205d593          	srli	a1,a1,0x20
    80002980:	05053503          	ld	a0,80(a0)
    80002984:	fffff097          	auipc	ra,0xfffff
    80002988:	220080e7          	jalr	544(ra) # 80001ba4 <uvmalloc>
    8000298c:	0005079b          	sext.w	a5,a0
    80002990:	fa079ae3          	bnez	a5,80002944 <growproc+0x38>
      return -1;
    80002994:	fff00513          	li	a0,-1
    80002998:	fbdff06f          	j	80002954 <growproc+0x48>
    sz = uvmdealloc(p->pagetable, sz, sz + n);
    8000299c:	00f4863b          	addw	a2,s1,a5
    800029a0:	02061613          	slli	a2,a2,0x20
    800029a4:	02065613          	srli	a2,a2,0x20
    800029a8:	02059593          	slli	a1,a1,0x20
    800029ac:	0205d593          	srli	a1,a1,0x20
    800029b0:	05053503          	ld	a0,80(a0)
    800029b4:	fffff097          	auipc	ra,0xfffff
    800029b8:	178080e7          	jalr	376(ra) # 80001b2c <uvmdealloc>
    800029bc:	0005079b          	sext.w	a5,a0
    800029c0:	f85ff06f          	j	80002944 <growproc+0x38>

00000000800029c4 <fork>:
{
    800029c4:	fc010113          	addi	sp,sp,-64
    800029c8:	02113c23          	sd	ra,56(sp)
    800029cc:	02813823          	sd	s0,48(sp)
    800029d0:	02913423          	sd	s1,40(sp)
    800029d4:	03213023          	sd	s2,32(sp)
    800029d8:	01313c23          	sd	s3,24(sp)
    800029dc:	01413823          	sd	s4,16(sp)
    800029e0:	01513423          	sd	s5,8(sp)
    800029e4:	04010413          	addi	s0,sp,64
  struct proc *p = myproc();
    800029e8:	00000097          	auipc	ra,0x0
    800029ec:	a54080e7          	jalr	-1452(ra) # 8000243c <myproc>
    800029f0:	00050a93          	mv	s5,a0
  if((np = allocproc()) == 0){
    800029f4:	00000097          	auipc	ra,0x0
    800029f8:	d48080e7          	jalr	-696(ra) # 8000273c <allocproc>
    800029fc:	16050063          	beqz	a0,80002b5c <fork+0x198>
    80002a00:	00050a13          	mv	s4,a0
  if(uvmcopy(p->pagetable, np->pagetable, p->sz) < 0){
    80002a04:	048ab603          	ld	a2,72(s5)
    80002a08:	05053583          	ld	a1,80(a0)
    80002a0c:	050ab503          	ld	a0,80(s5)
    80002a10:	fffff097          	auipc	ra,0xfffff
    80002a14:	3ac080e7          	jalr	940(ra) # 80001dbc <uvmcopy>
    80002a18:	06054063          	bltz	a0,80002a78 <fork+0xb4>
  np->sz = p->sz;
    80002a1c:	048ab783          	ld	a5,72(s5)
    80002a20:	04fa3423          	sd	a5,72(s4)
  *(np->trapframe) = *(p->trapframe);
    80002a24:	058ab683          	ld	a3,88(s5)
    80002a28:	00068793          	mv	a5,a3
    80002a2c:	058a3703          	ld	a4,88(s4)
    80002a30:	12068693          	addi	a3,a3,288
    80002a34:	0007b803          	ld	a6,0(a5) # 1000 <_entry-0x7ffff000>
    80002a38:	0087b503          	ld	a0,8(a5)
    80002a3c:	0107b583          	ld	a1,16(a5)
    80002a40:	0187b603          	ld	a2,24(a5)
    80002a44:	01073023          	sd	a6,0(a4)
    80002a48:	00a73423          	sd	a0,8(a4)
    80002a4c:	00b73823          	sd	a1,16(a4)
    80002a50:	00c73c23          	sd	a2,24(a4)
    80002a54:	02078793          	addi	a5,a5,32
    80002a58:	02070713          	addi	a4,a4,32
    80002a5c:	fcd79ce3          	bne	a5,a3,80002a34 <fork+0x70>
  np->trapframe->a0 = 0;
    80002a60:	058a3783          	ld	a5,88(s4)
    80002a64:	0607b823          	sd	zero,112(a5)
  for(i = 0; i < NOFILE; i++)
    80002a68:	0d0a8493          	addi	s1,s5,208
    80002a6c:	0d0a0913          	addi	s2,s4,208
    80002a70:	150a8993          	addi	s3,s5,336
    80002a74:	0300006f          	j	80002aa4 <fork+0xe0>
    freeproc(np);
    80002a78:	000a0513          	mv	a0,s4
    80002a7c:	00000097          	auipc	ra,0x0
    80002a80:	c48080e7          	jalr	-952(ra) # 800026c4 <freeproc>
    release(&np->lock);
    80002a84:	000a0513          	mv	a0,s4
    80002a88:	ffffe097          	auipc	ra,0xffffe
    80002a8c:	63c080e7          	jalr	1596(ra) # 800010c4 <release>
    return -1;
    80002a90:	fff00913          	li	s2,-1
    80002a94:	0a00006f          	j	80002b34 <fork+0x170>
  for(i = 0; i < NOFILE; i++)
    80002a98:	00848493          	addi	s1,s1,8
    80002a9c:	00890913          	addi	s2,s2,8
    80002aa0:	01348e63          	beq	s1,s3,80002abc <fork+0xf8>
    if(p->ofile[i])
    80002aa4:	0004b503          	ld	a0,0(s1)
    80002aa8:	fe0508e3          	beqz	a0,80002a98 <fork+0xd4>
      np->ofile[i] = filedup(p->ofile[i]);
    80002aac:	00003097          	auipc	ra,0x3
    80002ab0:	4c0080e7          	jalr	1216(ra) # 80005f6c <filedup>
    80002ab4:	00a93023          	sd	a0,0(s2)
    80002ab8:	fe1ff06f          	j	80002a98 <fork+0xd4>
  np->cwd = idup(p->cwd);
    80002abc:	150ab503          	ld	a0,336(s5)
    80002ac0:	00002097          	auipc	ra,0x2
    80002ac4:	040080e7          	jalr	64(ra) # 80004b00 <idup>
    80002ac8:	14aa3823          	sd	a0,336(s4)
  safestrcpy(np->name, p->name, sizeof(p->name));
    80002acc:	01000613          	li	a2,16
    80002ad0:	158a8593          	addi	a1,s5,344
    80002ad4:	158a0513          	addi	a0,s4,344
    80002ad8:	fffff097          	auipc	ra,0xfffff
    80002adc:	84c080e7          	jalr	-1972(ra) # 80001324 <safestrcpy>
  pid = np->pid;
    80002ae0:	030a2903          	lw	s2,48(s4)
  release(&np->lock);
    80002ae4:	000a0513          	mv	a0,s4
    80002ae8:	ffffe097          	auipc	ra,0xffffe
    80002aec:	5dc080e7          	jalr	1500(ra) # 800010c4 <release>
  acquire(&wait_lock);
    80002af0:	00010497          	auipc	s1,0x10
    80002af4:	7c848493          	addi	s1,s1,1992 # 800132b8 <wait_lock>
    80002af8:	00048513          	mv	a0,s1
    80002afc:	ffffe097          	auipc	ra,0xffffe
    80002b00:	4d0080e7          	jalr	1232(ra) # 80000fcc <acquire>
  np->parent = p;
    80002b04:	035a3c23          	sd	s5,56(s4)
  release(&wait_lock);
    80002b08:	00048513          	mv	a0,s1
    80002b0c:	ffffe097          	auipc	ra,0xffffe
    80002b10:	5b8080e7          	jalr	1464(ra) # 800010c4 <release>
  acquire(&np->lock);
    80002b14:	000a0513          	mv	a0,s4
    80002b18:	ffffe097          	auipc	ra,0xffffe
    80002b1c:	4b4080e7          	jalr	1204(ra) # 80000fcc <acquire>
  np->state = RUNNABLE;
    80002b20:	00300793          	li	a5,3
    80002b24:	00fa2c23          	sw	a5,24(s4)
  release(&np->lock);
    80002b28:	000a0513          	mv	a0,s4
    80002b2c:	ffffe097          	auipc	ra,0xffffe
    80002b30:	598080e7          	jalr	1432(ra) # 800010c4 <release>
}
    80002b34:	00090513          	mv	a0,s2
    80002b38:	03813083          	ld	ra,56(sp)
    80002b3c:	03013403          	ld	s0,48(sp)
    80002b40:	02813483          	ld	s1,40(sp)
    80002b44:	02013903          	ld	s2,32(sp)
    80002b48:	01813983          	ld	s3,24(sp)
    80002b4c:	01013a03          	ld	s4,16(sp)
    80002b50:	00813a83          	ld	s5,8(sp)
    80002b54:	04010113          	addi	sp,sp,64
    80002b58:	00008067          	ret
    return -1;
    80002b5c:	fff00913          	li	s2,-1
    80002b60:	fd5ff06f          	j	80002b34 <fork+0x170>

0000000080002b64 <scheduler>:
{
    80002b64:	fc010113          	addi	sp,sp,-64
    80002b68:	02113c23          	sd	ra,56(sp)
    80002b6c:	02813823          	sd	s0,48(sp)
    80002b70:	02913423          	sd	s1,40(sp)
    80002b74:	03213023          	sd	s2,32(sp)
    80002b78:	01313c23          	sd	s3,24(sp)
    80002b7c:	01413823          	sd	s4,16(sp)
    80002b80:	01513423          	sd	s5,8(sp)
    80002b84:	01613023          	sd	s6,0(sp)
    80002b88:	04010413          	addi	s0,sp,64
    80002b8c:	00020793          	mv	a5,tp
  int id = r_tp();
    80002b90:	0007879b          	sext.w	a5,a5
  c->proc = 0;
    80002b94:	00779a93          	slli	s5,a5,0x7
    80002b98:	00010717          	auipc	a4,0x10
    80002b9c:	70870713          	addi	a4,a4,1800 # 800132a0 <pid_lock>
    80002ba0:	01570733          	add	a4,a4,s5
    80002ba4:	02073823          	sd	zero,48(a4)
        swtch(&c->context, &p->context);
    80002ba8:	00010717          	auipc	a4,0x10
    80002bac:	73070713          	addi	a4,a4,1840 # 800132d8 <cpus+0x8>
    80002bb0:	00ea8ab3          	add	s5,s5,a4
      if(p->state == RUNNABLE) {
    80002bb4:	00300993          	li	s3,3
        p->state = RUNNING;
    80002bb8:	00400b13          	li	s6,4
        c->proc = p;
    80002bbc:	00779793          	slli	a5,a5,0x7
    80002bc0:	00010a17          	auipc	s4,0x10
    80002bc4:	6e0a0a13          	addi	s4,s4,1760 # 800132a0 <pid_lock>
    80002bc8:	00fa0a33          	add	s4,s4,a5
    for(p = proc; p < &proc[NPROC]; p++) {
    80002bcc:	00016917          	auipc	s2,0x16
    80002bd0:	50490913          	addi	s2,s2,1284 # 800190d0 <tickslock>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002bd4:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80002bd8:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002bdc:	10079073          	csrw	sstatus,a5
    80002be0:	00011497          	auipc	s1,0x11
    80002be4:	af048493          	addi	s1,s1,-1296 # 800136d0 <proc>
    80002be8:	0180006f          	j	80002c00 <scheduler+0x9c>
      release(&p->lock);
    80002bec:	00048513          	mv	a0,s1
    80002bf0:	ffffe097          	auipc	ra,0xffffe
    80002bf4:	4d4080e7          	jalr	1236(ra) # 800010c4 <release>
    for(p = proc; p < &proc[NPROC]; p++) {
    80002bf8:	16848493          	addi	s1,s1,360
    80002bfc:	fd248ce3          	beq	s1,s2,80002bd4 <scheduler+0x70>
      acquire(&p->lock);
    80002c00:	00048513          	mv	a0,s1
    80002c04:	ffffe097          	auipc	ra,0xffffe
    80002c08:	3c8080e7          	jalr	968(ra) # 80000fcc <acquire>
      if(p->state == RUNNABLE) {
    80002c0c:	0184a783          	lw	a5,24(s1)
    80002c10:	fd379ee3          	bne	a5,s3,80002bec <scheduler+0x88>
        p->state = RUNNING;
    80002c14:	0164ac23          	sw	s6,24(s1)
        c->proc = p;
    80002c18:	029a3823          	sd	s1,48(s4)
        swtch(&c->context, &p->context);
    80002c1c:	06048593          	addi	a1,s1,96
    80002c20:	000a8513          	mv	a0,s5
    80002c24:	00001097          	auipc	ra,0x1
    80002c28:	894080e7          	jalr	-1900(ra) # 800034b8 <swtch>
        c->proc = 0;
    80002c2c:	020a3823          	sd	zero,48(s4)
    80002c30:	fbdff06f          	j	80002bec <scheduler+0x88>

0000000080002c34 <sched>:
{
    80002c34:	fd010113          	addi	sp,sp,-48
    80002c38:	02113423          	sd	ra,40(sp)
    80002c3c:	02813023          	sd	s0,32(sp)
    80002c40:	00913c23          	sd	s1,24(sp)
    80002c44:	01213823          	sd	s2,16(sp)
    80002c48:	01313423          	sd	s3,8(sp)
    80002c4c:	03010413          	addi	s0,sp,48
  struct proc *p = myproc();
    80002c50:	fffff097          	auipc	ra,0xfffff
    80002c54:	7ec080e7          	jalr	2028(ra) # 8000243c <myproc>
    80002c58:	00050493          	mv	s1,a0
  if(!holding(&p->lock))
    80002c5c:	ffffe097          	auipc	ra,0xffffe
    80002c60:	2b0080e7          	jalr	688(ra) # 80000f0c <holding>
    80002c64:	0a050863          	beqz	a0,80002d14 <sched+0xe0>
  asm volatile("mv %0, tp" : "=r" (x) );
    80002c68:	00020793          	mv	a5,tp
  if(mycpu()->noff != 1)
    80002c6c:	0007879b          	sext.w	a5,a5
    80002c70:	00779793          	slli	a5,a5,0x7
    80002c74:	00010717          	auipc	a4,0x10
    80002c78:	62c70713          	addi	a4,a4,1580 # 800132a0 <pid_lock>
    80002c7c:	00f707b3          	add	a5,a4,a5
    80002c80:	0a87a703          	lw	a4,168(a5)
    80002c84:	00100793          	li	a5,1
    80002c88:	08f71e63          	bne	a4,a5,80002d24 <sched+0xf0>
  if(p->state == RUNNING)
    80002c8c:	0184a703          	lw	a4,24(s1)
    80002c90:	00400793          	li	a5,4
    80002c94:	0af70063          	beq	a4,a5,80002d34 <sched+0x100>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002c98:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80002c9c:	0027f793          	andi	a5,a5,2
  if(intr_get())
    80002ca0:	0a079263          	bnez	a5,80002d44 <sched+0x110>
  asm volatile("mv %0, tp" : "=r" (x) );
    80002ca4:	00020793          	mv	a5,tp
  intena = mycpu()->intena;
    80002ca8:	00010917          	auipc	s2,0x10
    80002cac:	5f890913          	addi	s2,s2,1528 # 800132a0 <pid_lock>
    80002cb0:	0007879b          	sext.w	a5,a5
    80002cb4:	00779793          	slli	a5,a5,0x7
    80002cb8:	00f907b3          	add	a5,s2,a5
    80002cbc:	0ac7a983          	lw	s3,172(a5)
    80002cc0:	00020793          	mv	a5,tp
  swtch(&p->context, &mycpu()->context);
    80002cc4:	0007879b          	sext.w	a5,a5
    80002cc8:	00779793          	slli	a5,a5,0x7
    80002ccc:	00010597          	auipc	a1,0x10
    80002cd0:	60c58593          	addi	a1,a1,1548 # 800132d8 <cpus+0x8>
    80002cd4:	00b785b3          	add	a1,a5,a1
    80002cd8:	06048513          	addi	a0,s1,96
    80002cdc:	00000097          	auipc	ra,0x0
    80002ce0:	7dc080e7          	jalr	2012(ra) # 800034b8 <swtch>
    80002ce4:	00020793          	mv	a5,tp
  mycpu()->intena = intena;
    80002ce8:	0007879b          	sext.w	a5,a5
    80002cec:	00779793          	slli	a5,a5,0x7
    80002cf0:	00f90933          	add	s2,s2,a5
    80002cf4:	0b392623          	sw	s3,172(s2)
}
    80002cf8:	02813083          	ld	ra,40(sp)
    80002cfc:	02013403          	ld	s0,32(sp)
    80002d00:	01813483          	ld	s1,24(sp)
    80002d04:	01013903          	ld	s2,16(sp)
    80002d08:	00813983          	ld	s3,8(sp)
    80002d0c:	03010113          	addi	sp,sp,48
    80002d10:	00008067          	ret
    panic("sched p->lock");
    80002d14:	00007517          	auipc	a0,0x7
    80002d18:	50450513          	addi	a0,a0,1284 # 8000a218 <digits+0x1d8>
    80002d1c:	ffffe097          	auipc	ra,0xffffe
    80002d20:	9b4080e7          	jalr	-1612(ra) # 800006d0 <panic>
    panic("sched locks");
    80002d24:	00007517          	auipc	a0,0x7
    80002d28:	50450513          	addi	a0,a0,1284 # 8000a228 <digits+0x1e8>
    80002d2c:	ffffe097          	auipc	ra,0xffffe
    80002d30:	9a4080e7          	jalr	-1628(ra) # 800006d0 <panic>
    panic("sched running");
    80002d34:	00007517          	auipc	a0,0x7
    80002d38:	50450513          	addi	a0,a0,1284 # 8000a238 <digits+0x1f8>
    80002d3c:	ffffe097          	auipc	ra,0xffffe
    80002d40:	994080e7          	jalr	-1644(ra) # 800006d0 <panic>
    panic("sched interruptible");
    80002d44:	00007517          	auipc	a0,0x7
    80002d48:	50450513          	addi	a0,a0,1284 # 8000a248 <digits+0x208>
    80002d4c:	ffffe097          	auipc	ra,0xffffe
    80002d50:	984080e7          	jalr	-1660(ra) # 800006d0 <panic>

0000000080002d54 <yield>:
{
    80002d54:	fe010113          	addi	sp,sp,-32
    80002d58:	00113c23          	sd	ra,24(sp)
    80002d5c:	00813823          	sd	s0,16(sp)
    80002d60:	00913423          	sd	s1,8(sp)
    80002d64:	02010413          	addi	s0,sp,32
  struct proc *p = myproc();
    80002d68:	fffff097          	auipc	ra,0xfffff
    80002d6c:	6d4080e7          	jalr	1748(ra) # 8000243c <myproc>
    80002d70:	00050493          	mv	s1,a0
  acquire(&p->lock);
    80002d74:	ffffe097          	auipc	ra,0xffffe
    80002d78:	258080e7          	jalr	600(ra) # 80000fcc <acquire>
  p->state = RUNNABLE;
    80002d7c:	00300793          	li	a5,3
    80002d80:	00f4ac23          	sw	a5,24(s1)
  sched();
    80002d84:	00000097          	auipc	ra,0x0
    80002d88:	eb0080e7          	jalr	-336(ra) # 80002c34 <sched>
  release(&p->lock);
    80002d8c:	00048513          	mv	a0,s1
    80002d90:	ffffe097          	auipc	ra,0xffffe
    80002d94:	334080e7          	jalr	820(ra) # 800010c4 <release>
}
    80002d98:	01813083          	ld	ra,24(sp)
    80002d9c:	01013403          	ld	s0,16(sp)
    80002da0:	00813483          	ld	s1,8(sp)
    80002da4:	02010113          	addi	sp,sp,32
    80002da8:	00008067          	ret

0000000080002dac <sleep>:

// Atomically release lock and sleep on chan.
// Reacquires lock when awakened.
void
sleep(void *chan, struct spinlock *lk)
{
    80002dac:	fd010113          	addi	sp,sp,-48
    80002db0:	02113423          	sd	ra,40(sp)
    80002db4:	02813023          	sd	s0,32(sp)
    80002db8:	00913c23          	sd	s1,24(sp)
    80002dbc:	01213823          	sd	s2,16(sp)
    80002dc0:	01313423          	sd	s3,8(sp)
    80002dc4:	03010413          	addi	s0,sp,48
    80002dc8:	00050993          	mv	s3,a0
    80002dcc:	00058913          	mv	s2,a1
  struct proc *p = myproc();
    80002dd0:	fffff097          	auipc	ra,0xfffff
    80002dd4:	66c080e7          	jalr	1644(ra) # 8000243c <myproc>
    80002dd8:	00050493          	mv	s1,a0
  // Once we hold p->lock, we can be
  // guaranteed that we won't miss any wakeup
  // (wakeup locks p->lock),
  // so it's okay to release lk.

  acquire(&p->lock);  //DOC: sleeplock1
    80002ddc:	ffffe097          	auipc	ra,0xffffe
    80002de0:	1f0080e7          	jalr	496(ra) # 80000fcc <acquire>
  release(lk);
    80002de4:	00090513          	mv	a0,s2
    80002de8:	ffffe097          	auipc	ra,0xffffe
    80002dec:	2dc080e7          	jalr	732(ra) # 800010c4 <release>

  // Go to sleep.
  p->chan = chan;
    80002df0:	0334b023          	sd	s3,32(s1)
  p->state = SLEEPING;
    80002df4:	00200793          	li	a5,2
    80002df8:	00f4ac23          	sw	a5,24(s1)

  sched();
    80002dfc:	00000097          	auipc	ra,0x0
    80002e00:	e38080e7          	jalr	-456(ra) # 80002c34 <sched>

  // Tidy up.
  p->chan = 0;
    80002e04:	0204b023          	sd	zero,32(s1)

  // Reacquire original lock.
  release(&p->lock);
    80002e08:	00048513          	mv	a0,s1
    80002e0c:	ffffe097          	auipc	ra,0xffffe
    80002e10:	2b8080e7          	jalr	696(ra) # 800010c4 <release>
  acquire(lk);
    80002e14:	00090513          	mv	a0,s2
    80002e18:	ffffe097          	auipc	ra,0xffffe
    80002e1c:	1b4080e7          	jalr	436(ra) # 80000fcc <acquire>
}
    80002e20:	02813083          	ld	ra,40(sp)
    80002e24:	02013403          	ld	s0,32(sp)
    80002e28:	01813483          	ld	s1,24(sp)
    80002e2c:	01013903          	ld	s2,16(sp)
    80002e30:	00813983          	ld	s3,8(sp)
    80002e34:	03010113          	addi	sp,sp,48
    80002e38:	00008067          	ret

0000000080002e3c <wait>:
{
    80002e3c:	fb010113          	addi	sp,sp,-80
    80002e40:	04113423          	sd	ra,72(sp)
    80002e44:	04813023          	sd	s0,64(sp)
    80002e48:	02913c23          	sd	s1,56(sp)
    80002e4c:	03213823          	sd	s2,48(sp)
    80002e50:	03313423          	sd	s3,40(sp)
    80002e54:	03413023          	sd	s4,32(sp)
    80002e58:	01513c23          	sd	s5,24(sp)
    80002e5c:	01613823          	sd	s6,16(sp)
    80002e60:	01713423          	sd	s7,8(sp)
    80002e64:	01813023          	sd	s8,0(sp)
    80002e68:	05010413          	addi	s0,sp,80
    80002e6c:	00050b13          	mv	s6,a0
  struct proc *p = myproc();
    80002e70:	fffff097          	auipc	ra,0xfffff
    80002e74:	5cc080e7          	jalr	1484(ra) # 8000243c <myproc>
    80002e78:	00050913          	mv	s2,a0
  acquire(&wait_lock);
    80002e7c:	00010517          	auipc	a0,0x10
    80002e80:	43c50513          	addi	a0,a0,1084 # 800132b8 <wait_lock>
    80002e84:	ffffe097          	auipc	ra,0xffffe
    80002e88:	148080e7          	jalr	328(ra) # 80000fcc <acquire>
    havekids = 0;
    80002e8c:	00000b93          	li	s7,0
        if(np->state == ZOMBIE){
    80002e90:	00500a13          	li	s4,5
        havekids = 1;
    80002e94:	00100a93          	li	s5,1
    for(np = proc; np < &proc[NPROC]; np++){
    80002e98:	00016997          	auipc	s3,0x16
    80002e9c:	23898993          	addi	s3,s3,568 # 800190d0 <tickslock>
    sleep(p, &wait_lock);  //DOC: wait-sleep
    80002ea0:	00010c17          	auipc	s8,0x10
    80002ea4:	418c0c13          	addi	s8,s8,1048 # 800132b8 <wait_lock>
    havekids = 0;
    80002ea8:	000b8713          	mv	a4,s7
    for(np = proc; np < &proc[NPROC]; np++){
    80002eac:	00011497          	auipc	s1,0x11
    80002eb0:	82448493          	addi	s1,s1,-2012 # 800136d0 <proc>
    80002eb4:	0800006f          	j	80002f34 <wait+0xf8>
          pid = np->pid;
    80002eb8:	0304a983          	lw	s3,48(s1)
          if(addr != 0 && copyout(p->pagetable, addr, (char *)&np->xstate,
    80002ebc:	020b0063          	beqz	s6,80002edc <wait+0xa0>
    80002ec0:	00400693          	li	a3,4
    80002ec4:	02c48613          	addi	a2,s1,44
    80002ec8:	000b0593          	mv	a1,s6
    80002ecc:	05093503          	ld	a0,80(s2)
    80002ed0:	fffff097          	auipc	ra,0xfffff
    80002ed4:	074080e7          	jalr	116(ra) # 80001f44 <copyout>
    80002ed8:	02054863          	bltz	a0,80002f08 <wait+0xcc>
          freeproc(np);
    80002edc:	00048513          	mv	a0,s1
    80002ee0:	fffff097          	auipc	ra,0xfffff
    80002ee4:	7e4080e7          	jalr	2020(ra) # 800026c4 <freeproc>
          release(&np->lock);
    80002ee8:	00048513          	mv	a0,s1
    80002eec:	ffffe097          	auipc	ra,0xffffe
    80002ef0:	1d8080e7          	jalr	472(ra) # 800010c4 <release>
          release(&wait_lock);
    80002ef4:	00010517          	auipc	a0,0x10
    80002ef8:	3c450513          	addi	a0,a0,964 # 800132b8 <wait_lock>
    80002efc:	ffffe097          	auipc	ra,0xffffe
    80002f00:	1c8080e7          	jalr	456(ra) # 800010c4 <release>
          return pid;
    80002f04:	0800006f          	j	80002f84 <wait+0x148>
            release(&np->lock);
    80002f08:	00048513          	mv	a0,s1
    80002f0c:	ffffe097          	auipc	ra,0xffffe
    80002f10:	1b8080e7          	jalr	440(ra) # 800010c4 <release>
            release(&wait_lock);
    80002f14:	00010517          	auipc	a0,0x10
    80002f18:	3a450513          	addi	a0,a0,932 # 800132b8 <wait_lock>
    80002f1c:	ffffe097          	auipc	ra,0xffffe
    80002f20:	1a8080e7          	jalr	424(ra) # 800010c4 <release>
            return -1;
    80002f24:	fff00993          	li	s3,-1
    80002f28:	05c0006f          	j	80002f84 <wait+0x148>
    for(np = proc; np < &proc[NPROC]; np++){
    80002f2c:	16848493          	addi	s1,s1,360
    80002f30:	03348a63          	beq	s1,s3,80002f64 <wait+0x128>
      if(np->parent == p){
    80002f34:	0384b783          	ld	a5,56(s1)
    80002f38:	ff279ae3          	bne	a5,s2,80002f2c <wait+0xf0>
        acquire(&np->lock);
    80002f3c:	00048513          	mv	a0,s1
    80002f40:	ffffe097          	auipc	ra,0xffffe
    80002f44:	08c080e7          	jalr	140(ra) # 80000fcc <acquire>
        if(np->state == ZOMBIE){
    80002f48:	0184a783          	lw	a5,24(s1)
    80002f4c:	f74786e3          	beq	a5,s4,80002eb8 <wait+0x7c>
        release(&np->lock);
    80002f50:	00048513          	mv	a0,s1
    80002f54:	ffffe097          	auipc	ra,0xffffe
    80002f58:	170080e7          	jalr	368(ra) # 800010c4 <release>
        havekids = 1;
    80002f5c:	000a8713          	mv	a4,s5
    80002f60:	fcdff06f          	j	80002f2c <wait+0xf0>
    if(!havekids || p->killed){
    80002f64:	00070663          	beqz	a4,80002f70 <wait+0x134>
    80002f68:	02892783          	lw	a5,40(s2)
    80002f6c:	04078663          	beqz	a5,80002fb8 <wait+0x17c>
      release(&wait_lock);
    80002f70:	00010517          	auipc	a0,0x10
    80002f74:	34850513          	addi	a0,a0,840 # 800132b8 <wait_lock>
    80002f78:	ffffe097          	auipc	ra,0xffffe
    80002f7c:	14c080e7          	jalr	332(ra) # 800010c4 <release>
      return -1;
    80002f80:	fff00993          	li	s3,-1
}
    80002f84:	00098513          	mv	a0,s3
    80002f88:	04813083          	ld	ra,72(sp)
    80002f8c:	04013403          	ld	s0,64(sp)
    80002f90:	03813483          	ld	s1,56(sp)
    80002f94:	03013903          	ld	s2,48(sp)
    80002f98:	02813983          	ld	s3,40(sp)
    80002f9c:	02013a03          	ld	s4,32(sp)
    80002fa0:	01813a83          	ld	s5,24(sp)
    80002fa4:	01013b03          	ld	s6,16(sp)
    80002fa8:	00813b83          	ld	s7,8(sp)
    80002fac:	00013c03          	ld	s8,0(sp)
    80002fb0:	05010113          	addi	sp,sp,80
    80002fb4:	00008067          	ret
    sleep(p, &wait_lock);  //DOC: wait-sleep
    80002fb8:	000c0593          	mv	a1,s8
    80002fbc:	00090513          	mv	a0,s2
    80002fc0:	00000097          	auipc	ra,0x0
    80002fc4:	dec080e7          	jalr	-532(ra) # 80002dac <sleep>
    havekids = 0;
    80002fc8:	ee1ff06f          	j	80002ea8 <wait+0x6c>

0000000080002fcc <wakeup>:

// Wake up all processes sleeping on chan.
// Must be called without any p->lock.
void
wakeup(void *chan)
{
    80002fcc:	fc010113          	addi	sp,sp,-64
    80002fd0:	02113c23          	sd	ra,56(sp)
    80002fd4:	02813823          	sd	s0,48(sp)
    80002fd8:	02913423          	sd	s1,40(sp)
    80002fdc:	03213023          	sd	s2,32(sp)
    80002fe0:	01313c23          	sd	s3,24(sp)
    80002fe4:	01413823          	sd	s4,16(sp)
    80002fe8:	01513423          	sd	s5,8(sp)
    80002fec:	04010413          	addi	s0,sp,64
    80002ff0:	00050a13          	mv	s4,a0
  struct proc *p;

  for(p = proc; p < &proc[NPROC]; p++) {
    80002ff4:	00010497          	auipc	s1,0x10
    80002ff8:	6dc48493          	addi	s1,s1,1756 # 800136d0 <proc>
    if(p != myproc()){
      acquire(&p->lock);
      if(p->state == SLEEPING && p->chan == chan) {
    80002ffc:	00200993          	li	s3,2
        p->state = RUNNABLE;
    80003000:	00300a93          	li	s5,3
  for(p = proc; p < &proc[NPROC]; p++) {
    80003004:	00016917          	auipc	s2,0x16
    80003008:	0cc90913          	addi	s2,s2,204 # 800190d0 <tickslock>
    8000300c:	0180006f          	j	80003024 <wakeup+0x58>
      }
      release(&p->lock);
    80003010:	00048513          	mv	a0,s1
    80003014:	ffffe097          	auipc	ra,0xffffe
    80003018:	0b0080e7          	jalr	176(ra) # 800010c4 <release>
  for(p = proc; p < &proc[NPROC]; p++) {
    8000301c:	16848493          	addi	s1,s1,360
    80003020:	03248a63          	beq	s1,s2,80003054 <wakeup+0x88>
    if(p != myproc()){
    80003024:	fffff097          	auipc	ra,0xfffff
    80003028:	418080e7          	jalr	1048(ra) # 8000243c <myproc>
    8000302c:	fea488e3          	beq	s1,a0,8000301c <wakeup+0x50>
      acquire(&p->lock);
    80003030:	00048513          	mv	a0,s1
    80003034:	ffffe097          	auipc	ra,0xffffe
    80003038:	f98080e7          	jalr	-104(ra) # 80000fcc <acquire>
      if(p->state == SLEEPING && p->chan == chan) {
    8000303c:	0184a783          	lw	a5,24(s1)
    80003040:	fd3798e3          	bne	a5,s3,80003010 <wakeup+0x44>
    80003044:	0204b783          	ld	a5,32(s1)
    80003048:	fd4794e3          	bne	a5,s4,80003010 <wakeup+0x44>
        p->state = RUNNABLE;
    8000304c:	0154ac23          	sw	s5,24(s1)
    80003050:	fc1ff06f          	j	80003010 <wakeup+0x44>
    }
  }
}
    80003054:	03813083          	ld	ra,56(sp)
    80003058:	03013403          	ld	s0,48(sp)
    8000305c:	02813483          	ld	s1,40(sp)
    80003060:	02013903          	ld	s2,32(sp)
    80003064:	01813983          	ld	s3,24(sp)
    80003068:	01013a03          	ld	s4,16(sp)
    8000306c:	00813a83          	ld	s5,8(sp)
    80003070:	04010113          	addi	sp,sp,64
    80003074:	00008067          	ret

0000000080003078 <reparent>:
{
    80003078:	fd010113          	addi	sp,sp,-48
    8000307c:	02113423          	sd	ra,40(sp)
    80003080:	02813023          	sd	s0,32(sp)
    80003084:	00913c23          	sd	s1,24(sp)
    80003088:	01213823          	sd	s2,16(sp)
    8000308c:	01313423          	sd	s3,8(sp)
    80003090:	01413023          	sd	s4,0(sp)
    80003094:	03010413          	addi	s0,sp,48
    80003098:	00050913          	mv	s2,a0
  for(pp = proc; pp < &proc[NPROC]; pp++){
    8000309c:	00010497          	auipc	s1,0x10
    800030a0:	63448493          	addi	s1,s1,1588 # 800136d0 <proc>
      pp->parent = initproc;
    800030a4:	00008a17          	auipc	s4,0x8
    800030a8:	f84a0a13          	addi	s4,s4,-124 # 8000b028 <initproc>
  for(pp = proc; pp < &proc[NPROC]; pp++){
    800030ac:	00016997          	auipc	s3,0x16
    800030b0:	02498993          	addi	s3,s3,36 # 800190d0 <tickslock>
    800030b4:	00c0006f          	j	800030c0 <reparent+0x48>
    800030b8:	16848493          	addi	s1,s1,360
    800030bc:	03348063          	beq	s1,s3,800030dc <reparent+0x64>
    if(pp->parent == p){
    800030c0:	0384b783          	ld	a5,56(s1)
    800030c4:	ff279ae3          	bne	a5,s2,800030b8 <reparent+0x40>
      pp->parent = initproc;
    800030c8:	000a3503          	ld	a0,0(s4)
    800030cc:	02a4bc23          	sd	a0,56(s1)
      wakeup(initproc);
    800030d0:	00000097          	auipc	ra,0x0
    800030d4:	efc080e7          	jalr	-260(ra) # 80002fcc <wakeup>
    800030d8:	fe1ff06f          	j	800030b8 <reparent+0x40>
}
    800030dc:	02813083          	ld	ra,40(sp)
    800030e0:	02013403          	ld	s0,32(sp)
    800030e4:	01813483          	ld	s1,24(sp)
    800030e8:	01013903          	ld	s2,16(sp)
    800030ec:	00813983          	ld	s3,8(sp)
    800030f0:	00013a03          	ld	s4,0(sp)
    800030f4:	03010113          	addi	sp,sp,48
    800030f8:	00008067          	ret

00000000800030fc <exit>:
{
    800030fc:	fd010113          	addi	sp,sp,-48
    80003100:	02113423          	sd	ra,40(sp)
    80003104:	02813023          	sd	s0,32(sp)
    80003108:	00913c23          	sd	s1,24(sp)
    8000310c:	01213823          	sd	s2,16(sp)
    80003110:	01313423          	sd	s3,8(sp)
    80003114:	01413023          	sd	s4,0(sp)
    80003118:	03010413          	addi	s0,sp,48
    8000311c:	00050a13          	mv	s4,a0
  struct proc *p = myproc();
    80003120:	fffff097          	auipc	ra,0xfffff
    80003124:	31c080e7          	jalr	796(ra) # 8000243c <myproc>
    80003128:	00050993          	mv	s3,a0
  if(p == initproc)
    8000312c:	00008797          	auipc	a5,0x8
    80003130:	efc7b783          	ld	a5,-260(a5) # 8000b028 <initproc>
    80003134:	0d050493          	addi	s1,a0,208
    80003138:	15050913          	addi	s2,a0,336
    8000313c:	02a79463          	bne	a5,a0,80003164 <exit+0x68>
    panic("init exiting");
    80003140:	00007517          	auipc	a0,0x7
    80003144:	12050513          	addi	a0,a0,288 # 8000a260 <digits+0x220>
    80003148:	ffffd097          	auipc	ra,0xffffd
    8000314c:	588080e7          	jalr	1416(ra) # 800006d0 <panic>
      fileclose(f);
    80003150:	00003097          	auipc	ra,0x3
    80003154:	e8c080e7          	jalr	-372(ra) # 80005fdc <fileclose>
      p->ofile[fd] = 0;
    80003158:	0004b023          	sd	zero,0(s1)
  for(int fd = 0; fd < NOFILE; fd++){
    8000315c:	00848493          	addi	s1,s1,8
    80003160:	01248863          	beq	s1,s2,80003170 <exit+0x74>
    if(p->ofile[fd]){
    80003164:	0004b503          	ld	a0,0(s1)
    80003168:	fe0514e3          	bnez	a0,80003150 <exit+0x54>
    8000316c:	ff1ff06f          	j	8000315c <exit+0x60>
  begin_op();
    80003170:	00002097          	auipc	ra,0x2
    80003174:	7e0080e7          	jalr	2016(ra) # 80005950 <begin_op>
  iput(p->cwd);
    80003178:	1509b503          	ld	a0,336(s3)
    8000317c:	00002097          	auipc	ra,0x2
    80003180:	c40080e7          	jalr	-960(ra) # 80004dbc <iput>
  end_op();
    80003184:	00003097          	auipc	ra,0x3
    80003188:	880080e7          	jalr	-1920(ra) # 80005a04 <end_op>
  p->cwd = 0;
    8000318c:	1409b823          	sd	zero,336(s3)
  acquire(&wait_lock);
    80003190:	00010497          	auipc	s1,0x10
    80003194:	12848493          	addi	s1,s1,296 # 800132b8 <wait_lock>
    80003198:	00048513          	mv	a0,s1
    8000319c:	ffffe097          	auipc	ra,0xffffe
    800031a0:	e30080e7          	jalr	-464(ra) # 80000fcc <acquire>
  reparent(p);
    800031a4:	00098513          	mv	a0,s3
    800031a8:	00000097          	auipc	ra,0x0
    800031ac:	ed0080e7          	jalr	-304(ra) # 80003078 <reparent>
  wakeup(p->parent);
    800031b0:	0389b503          	ld	a0,56(s3)
    800031b4:	00000097          	auipc	ra,0x0
    800031b8:	e18080e7          	jalr	-488(ra) # 80002fcc <wakeup>
  acquire(&p->lock);
    800031bc:	00098513          	mv	a0,s3
    800031c0:	ffffe097          	auipc	ra,0xffffe
    800031c4:	e0c080e7          	jalr	-500(ra) # 80000fcc <acquire>
  p->xstate = status;
    800031c8:	0349a623          	sw	s4,44(s3)
  p->state = ZOMBIE;
    800031cc:	00500793          	li	a5,5
    800031d0:	00f9ac23          	sw	a5,24(s3)
  release(&wait_lock);
    800031d4:	00048513          	mv	a0,s1
    800031d8:	ffffe097          	auipc	ra,0xffffe
    800031dc:	eec080e7          	jalr	-276(ra) # 800010c4 <release>
  sched();
    800031e0:	00000097          	auipc	ra,0x0
    800031e4:	a54080e7          	jalr	-1452(ra) # 80002c34 <sched>
  panic("zombie exit");
    800031e8:	00007517          	auipc	a0,0x7
    800031ec:	08850513          	addi	a0,a0,136 # 8000a270 <digits+0x230>
    800031f0:	ffffd097          	auipc	ra,0xffffd
    800031f4:	4e0080e7          	jalr	1248(ra) # 800006d0 <panic>

00000000800031f8 <kill>:
// Kill the process with the given pid.
// The victim won't exit until it tries to return
// to user space (see usertrap() in trap.c).
int
kill(int pid)
{
    800031f8:	fd010113          	addi	sp,sp,-48
    800031fc:	02113423          	sd	ra,40(sp)
    80003200:	02813023          	sd	s0,32(sp)
    80003204:	00913c23          	sd	s1,24(sp)
    80003208:	01213823          	sd	s2,16(sp)
    8000320c:	01313423          	sd	s3,8(sp)
    80003210:	03010413          	addi	s0,sp,48
    80003214:	00050913          	mv	s2,a0
  struct proc *p;

  for(p = proc; p < &proc[NPROC]; p++){
    80003218:	00010497          	auipc	s1,0x10
    8000321c:	4b848493          	addi	s1,s1,1208 # 800136d0 <proc>
    80003220:	00016997          	auipc	s3,0x16
    80003224:	eb098993          	addi	s3,s3,-336 # 800190d0 <tickslock>
    acquire(&p->lock);
    80003228:	00048513          	mv	a0,s1
    8000322c:	ffffe097          	auipc	ra,0xffffe
    80003230:	da0080e7          	jalr	-608(ra) # 80000fcc <acquire>
    if(p->pid == pid){
    80003234:	0304a783          	lw	a5,48(s1)
    80003238:	03278063          	beq	a5,s2,80003258 <kill+0x60>
        p->state = RUNNABLE;
      }
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
    8000323c:	00048513          	mv	a0,s1
    80003240:	ffffe097          	auipc	ra,0xffffe
    80003244:	e84080e7          	jalr	-380(ra) # 800010c4 <release>
  for(p = proc; p < &proc[NPROC]; p++){
    80003248:	16848493          	addi	s1,s1,360
    8000324c:	fd349ee3          	bne	s1,s3,80003228 <kill+0x30>
  }
  return -1;
    80003250:	fff00513          	li	a0,-1
    80003254:	0280006f          	j	8000327c <kill+0x84>
      p->killed = 1;
    80003258:	00100793          	li	a5,1
    8000325c:	02f4a423          	sw	a5,40(s1)
      if(p->state == SLEEPING){
    80003260:	0184a703          	lw	a4,24(s1)
    80003264:	00200793          	li	a5,2
    80003268:	02f70863          	beq	a4,a5,80003298 <kill+0xa0>
      release(&p->lock);
    8000326c:	00048513          	mv	a0,s1
    80003270:	ffffe097          	auipc	ra,0xffffe
    80003274:	e54080e7          	jalr	-428(ra) # 800010c4 <release>
      return 0;
    80003278:	00000513          	li	a0,0
}
    8000327c:	02813083          	ld	ra,40(sp)
    80003280:	02013403          	ld	s0,32(sp)
    80003284:	01813483          	ld	s1,24(sp)
    80003288:	01013903          	ld	s2,16(sp)
    8000328c:	00813983          	ld	s3,8(sp)
    80003290:	03010113          	addi	sp,sp,48
    80003294:	00008067          	ret
        p->state = RUNNABLE;
    80003298:	00300793          	li	a5,3
    8000329c:	00f4ac23          	sw	a5,24(s1)
    800032a0:	fcdff06f          	j	8000326c <kill+0x74>

00000000800032a4 <either_copyout>:
// Copy to either a user address, or kernel address,
// depending on usr_dst.
// Returns 0 on success, -1 on error.
int
either_copyout(int user_dst, uint64 dst, void *src, uint64 len)
{
    800032a4:	fd010113          	addi	sp,sp,-48
    800032a8:	02113423          	sd	ra,40(sp)
    800032ac:	02813023          	sd	s0,32(sp)
    800032b0:	00913c23          	sd	s1,24(sp)
    800032b4:	01213823          	sd	s2,16(sp)
    800032b8:	01313423          	sd	s3,8(sp)
    800032bc:	01413023          	sd	s4,0(sp)
    800032c0:	03010413          	addi	s0,sp,48
    800032c4:	00050493          	mv	s1,a0
    800032c8:	00058913          	mv	s2,a1
    800032cc:	00060993          	mv	s3,a2
    800032d0:	00068a13          	mv	s4,a3
  struct proc *p = myproc();
    800032d4:	fffff097          	auipc	ra,0xfffff
    800032d8:	168080e7          	jalr	360(ra) # 8000243c <myproc>
  if(user_dst){
    800032dc:	02048e63          	beqz	s1,80003318 <either_copyout+0x74>
    return copyout(p->pagetable, dst, src, len);
    800032e0:	000a0693          	mv	a3,s4
    800032e4:	00098613          	mv	a2,s3
    800032e8:	00090593          	mv	a1,s2
    800032ec:	05053503          	ld	a0,80(a0)
    800032f0:	fffff097          	auipc	ra,0xfffff
    800032f4:	c54080e7          	jalr	-940(ra) # 80001f44 <copyout>
  } else {
    memmove((char *)dst, src, len);
    return 0;
  }
}
    800032f8:	02813083          	ld	ra,40(sp)
    800032fc:	02013403          	ld	s0,32(sp)
    80003300:	01813483          	ld	s1,24(sp)
    80003304:	01013903          	ld	s2,16(sp)
    80003308:	00813983          	ld	s3,8(sp)
    8000330c:	00013a03          	ld	s4,0(sp)
    80003310:	03010113          	addi	sp,sp,48
    80003314:	00008067          	ret
    memmove((char *)dst, src, len);
    80003318:	000a061b          	sext.w	a2,s4
    8000331c:	00098593          	mv	a1,s3
    80003320:	00090513          	mv	a0,s2
    80003324:	ffffe097          	auipc	ra,0xffffe
    80003328:	e94080e7          	jalr	-364(ra) # 800011b8 <memmove>
    return 0;
    8000332c:	00048513          	mv	a0,s1
    80003330:	fc9ff06f          	j	800032f8 <either_copyout+0x54>

0000000080003334 <either_copyin>:
// Copy from either a user address, or kernel address,
// depending on usr_src.
// Returns 0 on success, -1 on error.
int
either_copyin(void *dst, int user_src, uint64 src, uint64 len)
{
    80003334:	fd010113          	addi	sp,sp,-48
    80003338:	02113423          	sd	ra,40(sp)
    8000333c:	02813023          	sd	s0,32(sp)
    80003340:	00913c23          	sd	s1,24(sp)
    80003344:	01213823          	sd	s2,16(sp)
    80003348:	01313423          	sd	s3,8(sp)
    8000334c:	01413023          	sd	s4,0(sp)
    80003350:	03010413          	addi	s0,sp,48
    80003354:	00050913          	mv	s2,a0
    80003358:	00058493          	mv	s1,a1
    8000335c:	00060993          	mv	s3,a2
    80003360:	00068a13          	mv	s4,a3
  struct proc *p = myproc();
    80003364:	fffff097          	auipc	ra,0xfffff
    80003368:	0d8080e7          	jalr	216(ra) # 8000243c <myproc>
  if(user_src){
    8000336c:	02048e63          	beqz	s1,800033a8 <either_copyin+0x74>
    return copyin(p->pagetable, dst, src, len);
    80003370:	000a0693          	mv	a3,s4
    80003374:	00098613          	mv	a2,s3
    80003378:	00090593          	mv	a1,s2
    8000337c:	05053503          	ld	a0,80(a0)
    80003380:	fffff097          	auipc	ra,0xfffff
    80003384:	cac080e7          	jalr	-852(ra) # 8000202c <copyin>
  } else {
    memmove(dst, (char*)src, len);
    return 0;
  }
}
    80003388:	02813083          	ld	ra,40(sp)
    8000338c:	02013403          	ld	s0,32(sp)
    80003390:	01813483          	ld	s1,24(sp)
    80003394:	01013903          	ld	s2,16(sp)
    80003398:	00813983          	ld	s3,8(sp)
    8000339c:	00013a03          	ld	s4,0(sp)
    800033a0:	03010113          	addi	sp,sp,48
    800033a4:	00008067          	ret
    memmove(dst, (char*)src, len);
    800033a8:	000a061b          	sext.w	a2,s4
    800033ac:	00098593          	mv	a1,s3
    800033b0:	00090513          	mv	a0,s2
    800033b4:	ffffe097          	auipc	ra,0xffffe
    800033b8:	e04080e7          	jalr	-508(ra) # 800011b8 <memmove>
    return 0;
    800033bc:	00048513          	mv	a0,s1
    800033c0:	fc9ff06f          	j	80003388 <either_copyin+0x54>

00000000800033c4 <procdump>:
// Print a process listing to console.  For debugging.
// Runs when user types ^P on console.
// No lock to avoid wedging a stuck machine further.
void
procdump(void)
{
    800033c4:	fb010113          	addi	sp,sp,-80
    800033c8:	04113423          	sd	ra,72(sp)
    800033cc:	04813023          	sd	s0,64(sp)
    800033d0:	02913c23          	sd	s1,56(sp)
    800033d4:	03213823          	sd	s2,48(sp)
    800033d8:	03313423          	sd	s3,40(sp)
    800033dc:	03413023          	sd	s4,32(sp)
    800033e0:	01513c23          	sd	s5,24(sp)
    800033e4:	01613823          	sd	s6,16(sp)
    800033e8:	01713423          	sd	s7,8(sp)
    800033ec:	05010413          	addi	s0,sp,80
  [ZOMBIE]    "zombie"
  };
  struct proc *p;
  char *state;

  printf("\n");
    800033f0:	00007517          	auipc	a0,0x7
    800033f4:	cd850513          	addi	a0,a0,-808 # 8000a0c8 <digits+0x88>
    800033f8:	ffffd097          	auipc	ra,0xffffd
    800033fc:	334080e7          	jalr	820(ra) # 8000072c <printf>
  for(p = proc; p < &proc[NPROC]; p++){
    80003400:	00010497          	auipc	s1,0x10
    80003404:	42848493          	addi	s1,s1,1064 # 80013828 <proc+0x158>
    80003408:	00016917          	auipc	s2,0x16
    8000340c:	e2090913          	addi	s2,s2,-480 # 80019228 <bcache+0x140>
    if(p->state == UNUSED)
      continue;
    if(p->state >= 0 && p->state < NELEM(states) && states[p->state])
    80003410:	00500b13          	li	s6,5
      state = states[p->state];
    else
      state = "???";
    80003414:	00007997          	auipc	s3,0x7
    80003418:	e6c98993          	addi	s3,s3,-404 # 8000a280 <digits+0x240>
    printf("%d %s %s", p->pid, state, p->name);
    8000341c:	00007a97          	auipc	s5,0x7
    80003420:	e6ca8a93          	addi	s5,s5,-404 # 8000a288 <digits+0x248>
    printf("\n");
    80003424:	00007a17          	auipc	s4,0x7
    80003428:	ca4a0a13          	addi	s4,s4,-860 # 8000a0c8 <digits+0x88>
    if(p->state >= 0 && p->state < NELEM(states) && states[p->state])
    8000342c:	00007b97          	auipc	s7,0x7
    80003430:	e94b8b93          	addi	s7,s7,-364 # 8000a2c0 <states.0>
    80003434:	0280006f          	j	8000345c <procdump+0x98>
    printf("%d %s %s", p->pid, state, p->name);
    80003438:	ed86a583          	lw	a1,-296(a3)
    8000343c:	000a8513          	mv	a0,s5
    80003440:	ffffd097          	auipc	ra,0xffffd
    80003444:	2ec080e7          	jalr	748(ra) # 8000072c <printf>
    printf("\n");
    80003448:	000a0513          	mv	a0,s4
    8000344c:	ffffd097          	auipc	ra,0xffffd
    80003450:	2e0080e7          	jalr	736(ra) # 8000072c <printf>
  for(p = proc; p < &proc[NPROC]; p++){
    80003454:	16848493          	addi	s1,s1,360
    80003458:	03248a63          	beq	s1,s2,8000348c <procdump+0xc8>
    if(p->state == UNUSED)
    8000345c:	00048693          	mv	a3,s1
    80003460:	ec04a783          	lw	a5,-320(s1)
    80003464:	fe0788e3          	beqz	a5,80003454 <procdump+0x90>
      state = "???";
    80003468:	00098613          	mv	a2,s3
    if(p->state >= 0 && p->state < NELEM(states) && states[p->state])
    8000346c:	fcfb66e3          	bltu	s6,a5,80003438 <procdump+0x74>
    80003470:	02079713          	slli	a4,a5,0x20
    80003474:	01d75793          	srli	a5,a4,0x1d
    80003478:	00fb87b3          	add	a5,s7,a5
    8000347c:	0007b603          	ld	a2,0(a5)
    80003480:	fa061ce3          	bnez	a2,80003438 <procdump+0x74>
      state = "???";
    80003484:	00098613          	mv	a2,s3
    80003488:	fb1ff06f          	j	80003438 <procdump+0x74>
  }
}
    8000348c:	04813083          	ld	ra,72(sp)
    80003490:	04013403          	ld	s0,64(sp)
    80003494:	03813483          	ld	s1,56(sp)
    80003498:	03013903          	ld	s2,48(sp)
    8000349c:	02813983          	ld	s3,40(sp)
    800034a0:	02013a03          	ld	s4,32(sp)
    800034a4:	01813a83          	ld	s5,24(sp)
    800034a8:	01013b03          	ld	s6,16(sp)
    800034ac:	00813b83          	ld	s7,8(sp)
    800034b0:	05010113          	addi	sp,sp,80
    800034b4:	00008067          	ret

00000000800034b8 <swtch>:
    800034b8:	00153023          	sd	ra,0(a0)
    800034bc:	00253423          	sd	sp,8(a0)
    800034c0:	00853823          	sd	s0,16(a0)
    800034c4:	00953c23          	sd	s1,24(a0)
    800034c8:	03253023          	sd	s2,32(a0)
    800034cc:	03353423          	sd	s3,40(a0)
    800034d0:	03453823          	sd	s4,48(a0)
    800034d4:	03553c23          	sd	s5,56(a0)
    800034d8:	05653023          	sd	s6,64(a0)
    800034dc:	05753423          	sd	s7,72(a0)
    800034e0:	05853823          	sd	s8,80(a0)
    800034e4:	05953c23          	sd	s9,88(a0)
    800034e8:	07a53023          	sd	s10,96(a0)
    800034ec:	07b53423          	sd	s11,104(a0)
    800034f0:	0005b083          	ld	ra,0(a1)
    800034f4:	0085b103          	ld	sp,8(a1)
    800034f8:	0105b403          	ld	s0,16(a1)
    800034fc:	0185b483          	ld	s1,24(a1)
    80003500:	0205b903          	ld	s2,32(a1)
    80003504:	0285b983          	ld	s3,40(a1)
    80003508:	0305ba03          	ld	s4,48(a1)
    8000350c:	0385ba83          	ld	s5,56(a1)
    80003510:	0405bb03          	ld	s6,64(a1)
    80003514:	0485bb83          	ld	s7,72(a1)
    80003518:	0505bc03          	ld	s8,80(a1)
    8000351c:	0585bc83          	ld	s9,88(a1)
    80003520:	0605bd03          	ld	s10,96(a1)
    80003524:	0685bd83          	ld	s11,104(a1)
    80003528:	00008067          	ret

000000008000352c <trapinit>:

extern int devintr();

void
trapinit(void)
{
    8000352c:	ff010113          	addi	sp,sp,-16
    80003530:	00113423          	sd	ra,8(sp)
    80003534:	00813023          	sd	s0,0(sp)
    80003538:	01010413          	addi	s0,sp,16
  initlock(&tickslock, "time");
    8000353c:	00007597          	auipc	a1,0x7
    80003540:	db458593          	addi	a1,a1,-588 # 8000a2f0 <states.0+0x30>
    80003544:	00016517          	auipc	a0,0x16
    80003548:	b8c50513          	addi	a0,a0,-1140 # 800190d0 <tickslock>
    8000354c:	ffffe097          	auipc	ra,0xffffe
    80003550:	99c080e7          	jalr	-1636(ra) # 80000ee8 <initlock>
}
    80003554:	00813083          	ld	ra,8(sp)
    80003558:	00013403          	ld	s0,0(sp)
    8000355c:	01010113          	addi	sp,sp,16
    80003560:	00008067          	ret

0000000080003564 <trapinithart>:

// set up to take exceptions and traps while in the kernel.
void
trapinithart(void)
{
    80003564:	ff010113          	addi	sp,sp,-16
    80003568:	00813423          	sd	s0,8(sp)
    8000356c:	01010413          	addi	s0,sp,16
  asm volatile("csrw stvec, %0" : : "r" (x));
    80003570:	00004797          	auipc	a5,0x4
    80003574:	7d078793          	addi	a5,a5,2000 # 80007d40 <kernelvec>
    80003578:	10579073          	csrw	stvec,a5
  w_stvec((uint64)kernelvec);
}
    8000357c:	00813403          	ld	s0,8(sp)
    80003580:	01010113          	addi	sp,sp,16
    80003584:	00008067          	ret

0000000080003588 <usertrapret>:
//
// return to user space
//
void
usertrapret(void)
{
    80003588:	ff010113          	addi	sp,sp,-16
    8000358c:	00113423          	sd	ra,8(sp)
    80003590:	00813023          	sd	s0,0(sp)
    80003594:	01010413          	addi	s0,sp,16
  struct proc *p = myproc();
    80003598:	fffff097          	auipc	ra,0xfffff
    8000359c:	ea4080e7          	jalr	-348(ra) # 8000243c <myproc>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    800035a0:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    800035a4:	ffd7f793          	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    800035a8:	10079073          	csrw	sstatus,a5
  // kerneltrap() to usertrap(), so turn off interrupts until
  // we're back in user space, where usertrap() is correct.
  intr_off();

  // send syscalls, interrupts, and exceptions to trampoline.S
  w_stvec(TRAMPOLINE + (uservec - trampoline));
    800035ac:	00006697          	auipc	a3,0x6
    800035b0:	a5468693          	addi	a3,a3,-1452 # 80009000 <_trampoline>
    800035b4:	00006717          	auipc	a4,0x6
    800035b8:	a4c70713          	addi	a4,a4,-1460 # 80009000 <_trampoline>
    800035bc:	40d70733          	sub	a4,a4,a3
    800035c0:	040007b7          	lui	a5,0x4000
    800035c4:	fff78793          	addi	a5,a5,-1 # 3ffffff <_entry-0x7c000001>
    800035c8:	00c79793          	slli	a5,a5,0xc
    800035cc:	00f70733          	add	a4,a4,a5
  asm volatile("csrw stvec, %0" : : "r" (x));
    800035d0:	10571073          	csrw	stvec,a4

  // set up trapframe values that uservec will need when
  // the process next re-enters the kernel.
  p->trapframe->kernel_satp = r_satp();         // kernel page table
    800035d4:	05853703          	ld	a4,88(a0)
  asm volatile("csrr %0, satp" : "=r" (x) );
    800035d8:	18002673          	csrr	a2,satp
    800035dc:	00c73023          	sd	a2,0(a4)
  p->trapframe->kernel_sp = p->kstack + PGSIZE; // process's kernel stack
    800035e0:	05853603          	ld	a2,88(a0)
    800035e4:	04053703          	ld	a4,64(a0)
    800035e8:	000015b7          	lui	a1,0x1
    800035ec:	00b70733          	add	a4,a4,a1
    800035f0:	00e63423          	sd	a4,8(a2) # 1008 <_entry-0x7fffeff8>
  p->trapframe->kernel_trap = (uint64)usertrap;
    800035f4:	05853703          	ld	a4,88(a0)
    800035f8:	00000617          	auipc	a2,0x0
    800035fc:	1bc60613          	addi	a2,a2,444 # 800037b4 <usertrap>
    80003600:	00c73823          	sd	a2,16(a4)
  p->trapframe->kernel_hartid = r_tp();         // hartid for cpuid()
    80003604:	05853703          	ld	a4,88(a0)
  asm volatile("mv %0, tp" : "=r" (x) );
    80003608:	00020613          	mv	a2,tp
    8000360c:	02c73023          	sd	a2,32(a4)
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80003610:	10002773          	csrr	a4,sstatus
  // set up the registers that trampoline.S's sret will use
  // to get to user space.
  
  // set S Previous Privilege mode to User.
  unsigned long x = r_sstatus();
  x &= ~SSTATUS_SPP; // clear SPP to 0 for user mode
    80003614:	eff77713          	andi	a4,a4,-257
  x |= SSTATUS_SPIE; // enable interrupts in user mode
    80003618:	02076713          	ori	a4,a4,32
  asm volatile("csrw sstatus, %0" : : "r" (x));
    8000361c:	10071073          	csrw	sstatus,a4
  w_sstatus(x);

  // set S Exception Program Counter to the saved user pc.
  w_sepc(p->trapframe->epc);
    80003620:	05853703          	ld	a4,88(a0)
  asm volatile("csrw sepc, %0" : : "r" (x));
    80003624:	01873703          	ld	a4,24(a4)
    80003628:	14171073          	csrw	sepc,a4

  // tell trampoline.S the user page table to switch to.
  uint64 satp = MAKE_SATP(p->pagetable);
    8000362c:	05053583          	ld	a1,80(a0)
    80003630:	00c5d593          	srli	a1,a1,0xc

  // jump to trampoline.S at the top of memory, which 
  // switches to the user page table, restores user registers,
  // and switches to user mode with sret.
  uint64 fn = TRAMPOLINE + (userret - trampoline);
    80003634:	00006717          	auipc	a4,0x6
    80003638:	a6c70713          	addi	a4,a4,-1428 # 800090a0 <userret>
    8000363c:	40d70733          	sub	a4,a4,a3
    80003640:	00f707b3          	add	a5,a4,a5
  ((void (*)(uint64,uint64))fn)(TRAPFRAME, satp);
    80003644:	fff00713          	li	a4,-1
    80003648:	03f71713          	slli	a4,a4,0x3f
    8000364c:	00e5e5b3          	or	a1,a1,a4
    80003650:	02000537          	lui	a0,0x2000
    80003654:	fff50513          	addi	a0,a0,-1 # 1ffffff <_entry-0x7e000001>
    80003658:	00d51513          	slli	a0,a0,0xd
    8000365c:	000780e7          	jalr	a5
}
    80003660:	00813083          	ld	ra,8(sp)
    80003664:	00013403          	ld	s0,0(sp)
    80003668:	01010113          	addi	sp,sp,16
    8000366c:	00008067          	ret

0000000080003670 <clockintr>:
  w_sstatus(sstatus);
}

void
clockintr()
{
    80003670:	fe010113          	addi	sp,sp,-32
    80003674:	00113c23          	sd	ra,24(sp)
    80003678:	00813823          	sd	s0,16(sp)
    8000367c:	00913423          	sd	s1,8(sp)
    80003680:	02010413          	addi	s0,sp,32
  acquire(&tickslock);
    80003684:	00016497          	auipc	s1,0x16
    80003688:	a4c48493          	addi	s1,s1,-1460 # 800190d0 <tickslock>
    8000368c:	00048513          	mv	a0,s1
    80003690:	ffffe097          	auipc	ra,0xffffe
    80003694:	93c080e7          	jalr	-1732(ra) # 80000fcc <acquire>
  ticks++;
    80003698:	00008517          	auipc	a0,0x8
    8000369c:	99850513          	addi	a0,a0,-1640 # 8000b030 <ticks>
    800036a0:	00052783          	lw	a5,0(a0)
    800036a4:	0017879b          	addiw	a5,a5,1
    800036a8:	00f52023          	sw	a5,0(a0)
  wakeup(&ticks);
    800036ac:	00000097          	auipc	ra,0x0
    800036b0:	920080e7          	jalr	-1760(ra) # 80002fcc <wakeup>
  release(&tickslock);
    800036b4:	00048513          	mv	a0,s1
    800036b8:	ffffe097          	auipc	ra,0xffffe
    800036bc:	a0c080e7          	jalr	-1524(ra) # 800010c4 <release>
}
    800036c0:	01813083          	ld	ra,24(sp)
    800036c4:	01013403          	ld	s0,16(sp)
    800036c8:	00813483          	ld	s1,8(sp)
    800036cc:	02010113          	addi	sp,sp,32
    800036d0:	00008067          	ret

00000000800036d4 <devintr>:
// returns 2 if timer interrupt,
// 1 if other device,
// 0 if not recognized.
int
devintr()
{
    800036d4:	fe010113          	addi	sp,sp,-32
    800036d8:	00113c23          	sd	ra,24(sp)
    800036dc:	00813823          	sd	s0,16(sp)
    800036e0:	00913423          	sd	s1,8(sp)
    800036e4:	02010413          	addi	s0,sp,32
  asm volatile("csrr %0, scause" : "=r" (x) );
    800036e8:	14202773          	csrr	a4,scause
  uint64 scause = r_scause();

  if((scause & 0x8000000000000000L) &&
    800036ec:	02074663          	bltz	a4,80003718 <devintr+0x44>
    // now allowed to interrupt again.
    if(irq)
      plic_complete(irq);

    return 1;
  } else if(scause == 0x8000000000000001L){
    800036f0:	fff00793          	li	a5,-1
    800036f4:	03f79793          	slli	a5,a5,0x3f
    800036f8:	00178793          	addi	a5,a5,1
    // the SSIP bit in sip.
    w_sip(r_sip() & ~2);

    return 2;
  } else {
    return 0;
    800036fc:	00000513          	li	a0,0
  } else if(scause == 0x8000000000000001L){
    80003700:	08f70463          	beq	a4,a5,80003788 <devintr+0xb4>
  }
}
    80003704:	01813083          	ld	ra,24(sp)
    80003708:	01013403          	ld	s0,16(sp)
    8000370c:	00813483          	ld	s1,8(sp)
    80003710:	02010113          	addi	sp,sp,32
    80003714:	00008067          	ret
     (scause & 0xff) == 9){
    80003718:	0ff77793          	zext.b	a5,a4
  if((scause & 0x8000000000000000L) &&
    8000371c:	00900693          	li	a3,9
    80003720:	fcd798e3          	bne	a5,a3,800036f0 <devintr+0x1c>
    int irq = plic_claim();
    80003724:	00004097          	auipc	ra,0x4
    80003728:	7e0080e7          	jalr	2016(ra) # 80007f04 <plic_claim>
    8000372c:	00050493          	mv	s1,a0
    if(irq == UART0_IRQ){
    80003730:	00a00793          	li	a5,10
    80003734:	02f50e63          	beq	a0,a5,80003770 <devintr+0x9c>
    } else if(irq == VIRTIO0_IRQ){
    80003738:	00100793          	li	a5,1
    8000373c:	04f50063          	beq	a0,a5,8000377c <devintr+0xa8>
    return 1;
    80003740:	00100513          	li	a0,1
    } else if(irq){
    80003744:	fc0480e3          	beqz	s1,80003704 <devintr+0x30>
      printf("unexpected interrupt irq=%d\n", irq);
    80003748:	00048593          	mv	a1,s1
    8000374c:	00007517          	auipc	a0,0x7
    80003750:	bac50513          	addi	a0,a0,-1108 # 8000a2f8 <states.0+0x38>
    80003754:	ffffd097          	auipc	ra,0xffffd
    80003758:	fd8080e7          	jalr	-40(ra) # 8000072c <printf>
      plic_complete(irq);
    8000375c:	00048513          	mv	a0,s1
    80003760:	00004097          	auipc	ra,0x4
    80003764:	7dc080e7          	jalr	2012(ra) # 80007f3c <plic_complete>
    return 1;
    80003768:	00100513          	li	a0,1
    8000376c:	f99ff06f          	j	80003704 <devintr+0x30>
      uartintr();
    80003770:	ffffd097          	auipc	ra,0xffffd
    80003774:	518080e7          	jalr	1304(ra) # 80000c88 <uartintr>
    80003778:	fe5ff06f          	j	8000375c <devintr+0x88>
      virtio_disk_intr();
    8000377c:	00005097          	auipc	ra,0x5
    80003780:	de0080e7          	jalr	-544(ra) # 8000855c <virtio_disk_intr>
    80003784:	fd9ff06f          	j	8000375c <devintr+0x88>
    if(cpuid() == 0){
    80003788:	fffff097          	auipc	ra,0xfffff
    8000378c:	c64080e7          	jalr	-924(ra) # 800023ec <cpuid>
    80003790:	00050c63          	beqz	a0,800037a8 <devintr+0xd4>
  asm volatile("csrr %0, sip" : "=r" (x) );
    80003794:	144027f3          	csrr	a5,sip
    w_sip(r_sip() & ~2);
    80003798:	ffd7f793          	andi	a5,a5,-3
  asm volatile("csrw sip, %0" : : "r" (x));
    8000379c:	14479073          	csrw	sip,a5
    return 2;
    800037a0:	00200513          	li	a0,2
    800037a4:	f61ff06f          	j	80003704 <devintr+0x30>
      clockintr();
    800037a8:	00000097          	auipc	ra,0x0
    800037ac:	ec8080e7          	jalr	-312(ra) # 80003670 <clockintr>
    800037b0:	fe5ff06f          	j	80003794 <devintr+0xc0>

00000000800037b4 <usertrap>:
{
    800037b4:	fe010113          	addi	sp,sp,-32
    800037b8:	00113c23          	sd	ra,24(sp)
    800037bc:	00813823          	sd	s0,16(sp)
    800037c0:	00913423          	sd	s1,8(sp)
    800037c4:	01213023          	sd	s2,0(sp)
    800037c8:	02010413          	addi	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    800037cc:	100027f3          	csrr	a5,sstatus
  if((r_sstatus() & SSTATUS_SPP) != 0)
    800037d0:	1007f793          	andi	a5,a5,256
    800037d4:	08079463          	bnez	a5,8000385c <usertrap+0xa8>
  asm volatile("csrw stvec, %0" : : "r" (x));
    800037d8:	00004797          	auipc	a5,0x4
    800037dc:	56878793          	addi	a5,a5,1384 # 80007d40 <kernelvec>
    800037e0:	10579073          	csrw	stvec,a5
  struct proc *p = myproc();
    800037e4:	fffff097          	auipc	ra,0xfffff
    800037e8:	c58080e7          	jalr	-936(ra) # 8000243c <myproc>
    800037ec:	00050493          	mv	s1,a0
  p->trapframe->epc = r_sepc();
    800037f0:	05853783          	ld	a5,88(a0)
  asm volatile("csrr %0, sepc" : "=r" (x) );
    800037f4:	14102773          	csrr	a4,sepc
    800037f8:	00e7bc23          	sd	a4,24(a5)
  asm volatile("csrr %0, scause" : "=r" (x) );
    800037fc:	14202773          	csrr	a4,scause
  if(r_scause() == 8){
    80003800:	00800793          	li	a5,8
    80003804:	06f71c63          	bne	a4,a5,8000387c <usertrap+0xc8>
    if(p->killed)
    80003808:	02852783          	lw	a5,40(a0)
    8000380c:	06079063          	bnez	a5,8000386c <usertrap+0xb8>
    p->trapframe->epc += 4;
    80003810:	0584b703          	ld	a4,88(s1)
    80003814:	01873783          	ld	a5,24(a4)
    80003818:	00478793          	addi	a5,a5,4
    8000381c:	00f73c23          	sd	a5,24(a4)
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80003820:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80003824:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80003828:	10079073          	csrw	sstatus,a5
    syscall();
    8000382c:	00000097          	auipc	ra,0x0
    80003830:	430080e7          	jalr	1072(ra) # 80003c5c <syscall>
  if(p->killed)
    80003834:	0284a783          	lw	a5,40(s1)
    80003838:	0a079c63          	bnez	a5,800038f0 <usertrap+0x13c>
  usertrapret();
    8000383c:	00000097          	auipc	ra,0x0
    80003840:	d4c080e7          	jalr	-692(ra) # 80003588 <usertrapret>
}
    80003844:	01813083          	ld	ra,24(sp)
    80003848:	01013403          	ld	s0,16(sp)
    8000384c:	00813483          	ld	s1,8(sp)
    80003850:	00013903          	ld	s2,0(sp)
    80003854:	02010113          	addi	sp,sp,32
    80003858:	00008067          	ret
    panic("usertrap: not from user mode");
    8000385c:	00007517          	auipc	a0,0x7
    80003860:	abc50513          	addi	a0,a0,-1348 # 8000a318 <states.0+0x58>
    80003864:	ffffd097          	auipc	ra,0xffffd
    80003868:	e6c080e7          	jalr	-404(ra) # 800006d0 <panic>
      exit(-1);
    8000386c:	fff00513          	li	a0,-1
    80003870:	00000097          	auipc	ra,0x0
    80003874:	88c080e7          	jalr	-1908(ra) # 800030fc <exit>
    80003878:	f99ff06f          	j	80003810 <usertrap+0x5c>
  } else if((which_dev = devintr()) != 0){
    8000387c:	00000097          	auipc	ra,0x0
    80003880:	e58080e7          	jalr	-424(ra) # 800036d4 <devintr>
    80003884:	00050913          	mv	s2,a0
    80003888:	00050863          	beqz	a0,80003898 <usertrap+0xe4>
  if(p->killed)
    8000388c:	0284a783          	lw	a5,40(s1)
    80003890:	04078663          	beqz	a5,800038dc <usertrap+0x128>
    80003894:	03c0006f          	j	800038d0 <usertrap+0x11c>
  asm volatile("csrr %0, scause" : "=r" (x) );
    80003898:	142025f3          	csrr	a1,scause
    printf("usertrap(): unexpected scause %p pid=%d\n", r_scause(), p->pid);
    8000389c:	0304a603          	lw	a2,48(s1)
    800038a0:	00007517          	auipc	a0,0x7
    800038a4:	a9850513          	addi	a0,a0,-1384 # 8000a338 <states.0+0x78>
    800038a8:	ffffd097          	auipc	ra,0xffffd
    800038ac:	e84080e7          	jalr	-380(ra) # 8000072c <printf>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    800038b0:	141025f3          	csrr	a1,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    800038b4:	14302673          	csrr	a2,stval
    printf("            sepc=%p stval=%p\n", r_sepc(), r_stval());
    800038b8:	00007517          	auipc	a0,0x7
    800038bc:	ab050513          	addi	a0,a0,-1360 # 8000a368 <states.0+0xa8>
    800038c0:	ffffd097          	auipc	ra,0xffffd
    800038c4:	e6c080e7          	jalr	-404(ra) # 8000072c <printf>
    p->killed = 1;
    800038c8:	00100793          	li	a5,1
    800038cc:	02f4a423          	sw	a5,40(s1)
    exit(-1);
    800038d0:	fff00513          	li	a0,-1
    800038d4:	00000097          	auipc	ra,0x0
    800038d8:	828080e7          	jalr	-2008(ra) # 800030fc <exit>
  if(which_dev == 2)
    800038dc:	00200793          	li	a5,2
    800038e0:	f4f91ee3          	bne	s2,a5,8000383c <usertrap+0x88>
    yield();
    800038e4:	fffff097          	auipc	ra,0xfffff
    800038e8:	470080e7          	jalr	1136(ra) # 80002d54 <yield>
    800038ec:	f51ff06f          	j	8000383c <usertrap+0x88>
  int which_dev = 0;
    800038f0:	00000913          	li	s2,0
    800038f4:	fddff06f          	j	800038d0 <usertrap+0x11c>

00000000800038f8 <kerneltrap>:
{
    800038f8:	fd010113          	addi	sp,sp,-48
    800038fc:	02113423          	sd	ra,40(sp)
    80003900:	02813023          	sd	s0,32(sp)
    80003904:	00913c23          	sd	s1,24(sp)
    80003908:	01213823          	sd	s2,16(sp)
    8000390c:	01313423          	sd	s3,8(sp)
    80003910:	03010413          	addi	s0,sp,48
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80003914:	14102973          	csrr	s2,sepc
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80003918:	100024f3          	csrr	s1,sstatus
  asm volatile("csrr %0, scause" : "=r" (x) );
    8000391c:	142029f3          	csrr	s3,scause
  if((sstatus & SSTATUS_SPP) == 0)
    80003920:	1004f793          	andi	a5,s1,256
    80003924:	04078463          	beqz	a5,8000396c <kerneltrap+0x74>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80003928:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    8000392c:	0027f793          	andi	a5,a5,2
  if(intr_get() != 0)
    80003930:	04079663          	bnez	a5,8000397c <kerneltrap+0x84>
  if((which_dev = devintr()) == 0){
    80003934:	00000097          	auipc	ra,0x0
    80003938:	da0080e7          	jalr	-608(ra) # 800036d4 <devintr>
    8000393c:	04050863          	beqz	a0,8000398c <kerneltrap+0x94>
  if(which_dev == 2 && myproc() != 0 && myproc()->state == RUNNING)
    80003940:	00200793          	li	a5,2
    80003944:	08f50263          	beq	a0,a5,800039c8 <kerneltrap+0xd0>
  asm volatile("csrw sepc, %0" : : "r" (x));
    80003948:	14191073          	csrw	sepc,s2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    8000394c:	10049073          	csrw	sstatus,s1
}
    80003950:	02813083          	ld	ra,40(sp)
    80003954:	02013403          	ld	s0,32(sp)
    80003958:	01813483          	ld	s1,24(sp)
    8000395c:	01013903          	ld	s2,16(sp)
    80003960:	00813983          	ld	s3,8(sp)
    80003964:	03010113          	addi	sp,sp,48
    80003968:	00008067          	ret
    panic("kerneltrap: not from supervisor mode");
    8000396c:	00007517          	auipc	a0,0x7
    80003970:	a1c50513          	addi	a0,a0,-1508 # 8000a388 <states.0+0xc8>
    80003974:	ffffd097          	auipc	ra,0xffffd
    80003978:	d5c080e7          	jalr	-676(ra) # 800006d0 <panic>
    panic("kerneltrap: interrupts enabled");
    8000397c:	00007517          	auipc	a0,0x7
    80003980:	a3450513          	addi	a0,a0,-1484 # 8000a3b0 <states.0+0xf0>
    80003984:	ffffd097          	auipc	ra,0xffffd
    80003988:	d4c080e7          	jalr	-692(ra) # 800006d0 <panic>
    printf("scause %p\n", scause);
    8000398c:	00098593          	mv	a1,s3
    80003990:	00007517          	auipc	a0,0x7
    80003994:	a4050513          	addi	a0,a0,-1472 # 8000a3d0 <states.0+0x110>
    80003998:	ffffd097          	auipc	ra,0xffffd
    8000399c:	d94080e7          	jalr	-620(ra) # 8000072c <printf>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    800039a0:	141025f3          	csrr	a1,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    800039a4:	14302673          	csrr	a2,stval
    printf("sepc=%p stval=%p\n", r_sepc(), r_stval());
    800039a8:	00007517          	auipc	a0,0x7
    800039ac:	a3850513          	addi	a0,a0,-1480 # 8000a3e0 <states.0+0x120>
    800039b0:	ffffd097          	auipc	ra,0xffffd
    800039b4:	d7c080e7          	jalr	-644(ra) # 8000072c <printf>
    panic("kerneltrap");
    800039b8:	00007517          	auipc	a0,0x7
    800039bc:	a4050513          	addi	a0,a0,-1472 # 8000a3f8 <states.0+0x138>
    800039c0:	ffffd097          	auipc	ra,0xffffd
    800039c4:	d10080e7          	jalr	-752(ra) # 800006d0 <panic>
  if(which_dev == 2 && myproc() != 0 && myproc()->state == RUNNING)
    800039c8:	fffff097          	auipc	ra,0xfffff
    800039cc:	a74080e7          	jalr	-1420(ra) # 8000243c <myproc>
    800039d0:	f6050ce3          	beqz	a0,80003948 <kerneltrap+0x50>
    800039d4:	fffff097          	auipc	ra,0xfffff
    800039d8:	a68080e7          	jalr	-1432(ra) # 8000243c <myproc>
    800039dc:	01852703          	lw	a4,24(a0)
    800039e0:	00400793          	li	a5,4
    800039e4:	f6f712e3          	bne	a4,a5,80003948 <kerneltrap+0x50>
    yield();
    800039e8:	fffff097          	auipc	ra,0xfffff
    800039ec:	36c080e7          	jalr	876(ra) # 80002d54 <yield>
    800039f0:	f59ff06f          	j	80003948 <kerneltrap+0x50>

00000000800039f4 <argraw>:
  return strlen(buf);
}

static uint64
argraw(int n)
{
    800039f4:	fe010113          	addi	sp,sp,-32
    800039f8:	00113c23          	sd	ra,24(sp)
    800039fc:	00813823          	sd	s0,16(sp)
    80003a00:	00913423          	sd	s1,8(sp)
    80003a04:	02010413          	addi	s0,sp,32
    80003a08:	00050493          	mv	s1,a0
  struct proc *p = myproc();
    80003a0c:	fffff097          	auipc	ra,0xfffff
    80003a10:	a30080e7          	jalr	-1488(ra) # 8000243c <myproc>
  switch (n) {
    80003a14:	00500793          	li	a5,5
    80003a18:	0697ec63          	bltu	a5,s1,80003a90 <argraw+0x9c>
    80003a1c:	00249493          	slli	s1,s1,0x2
    80003a20:	00007717          	auipc	a4,0x7
    80003a24:	a1070713          	addi	a4,a4,-1520 # 8000a430 <states.0+0x170>
    80003a28:	00e484b3          	add	s1,s1,a4
    80003a2c:	0004a783          	lw	a5,0(s1)
    80003a30:	00e787b3          	add	a5,a5,a4
    80003a34:	00078067          	jr	a5
  case 0:
    return p->trapframe->a0;
    80003a38:	05853783          	ld	a5,88(a0)
    80003a3c:	0707b503          	ld	a0,112(a5)
  case 5:
    return p->trapframe->a5;
  }
  panic("argraw");
  return -1;
}
    80003a40:	01813083          	ld	ra,24(sp)
    80003a44:	01013403          	ld	s0,16(sp)
    80003a48:	00813483          	ld	s1,8(sp)
    80003a4c:	02010113          	addi	sp,sp,32
    80003a50:	00008067          	ret
    return p->trapframe->a1;
    80003a54:	05853783          	ld	a5,88(a0)
    80003a58:	0787b503          	ld	a0,120(a5)
    80003a5c:	fe5ff06f          	j	80003a40 <argraw+0x4c>
    return p->trapframe->a2;
    80003a60:	05853783          	ld	a5,88(a0)
    80003a64:	0807b503          	ld	a0,128(a5)
    80003a68:	fd9ff06f          	j	80003a40 <argraw+0x4c>
    return p->trapframe->a3;
    80003a6c:	05853783          	ld	a5,88(a0)
    80003a70:	0887b503          	ld	a0,136(a5)
    80003a74:	fcdff06f          	j	80003a40 <argraw+0x4c>
    return p->trapframe->a4;
    80003a78:	05853783          	ld	a5,88(a0)
    80003a7c:	0907b503          	ld	a0,144(a5)
    80003a80:	fc1ff06f          	j	80003a40 <argraw+0x4c>
    return p->trapframe->a5;
    80003a84:	05853783          	ld	a5,88(a0)
    80003a88:	0987b503          	ld	a0,152(a5)
    80003a8c:	fb5ff06f          	j	80003a40 <argraw+0x4c>
  panic("argraw");
    80003a90:	00007517          	auipc	a0,0x7
    80003a94:	97850513          	addi	a0,a0,-1672 # 8000a408 <states.0+0x148>
    80003a98:	ffffd097          	auipc	ra,0xffffd
    80003a9c:	c38080e7          	jalr	-968(ra) # 800006d0 <panic>

0000000080003aa0 <fetchaddr>:
{
    80003aa0:	fe010113          	addi	sp,sp,-32
    80003aa4:	00113c23          	sd	ra,24(sp)
    80003aa8:	00813823          	sd	s0,16(sp)
    80003aac:	00913423          	sd	s1,8(sp)
    80003ab0:	01213023          	sd	s2,0(sp)
    80003ab4:	02010413          	addi	s0,sp,32
    80003ab8:	00050493          	mv	s1,a0
    80003abc:	00058913          	mv	s2,a1
  struct proc *p = myproc();
    80003ac0:	fffff097          	auipc	ra,0xfffff
    80003ac4:	97c080e7          	jalr	-1668(ra) # 8000243c <myproc>
  if(addr >= p->sz || addr+sizeof(uint64) > p->sz)
    80003ac8:	04853783          	ld	a5,72(a0)
    80003acc:	04f4f263          	bgeu	s1,a5,80003b10 <fetchaddr+0x70>
    80003ad0:	00848713          	addi	a4,s1,8
    80003ad4:	04e7e263          	bltu	a5,a4,80003b18 <fetchaddr+0x78>
  if(copyin(p->pagetable, (char *)ip, addr, sizeof(*ip)) != 0)
    80003ad8:	00800693          	li	a3,8
    80003adc:	00048613          	mv	a2,s1
    80003ae0:	00090593          	mv	a1,s2
    80003ae4:	05053503          	ld	a0,80(a0)
    80003ae8:	ffffe097          	auipc	ra,0xffffe
    80003aec:	544080e7          	jalr	1348(ra) # 8000202c <copyin>
    80003af0:	00a03533          	snez	a0,a0
    80003af4:	40a00533          	neg	a0,a0
}
    80003af8:	01813083          	ld	ra,24(sp)
    80003afc:	01013403          	ld	s0,16(sp)
    80003b00:	00813483          	ld	s1,8(sp)
    80003b04:	00013903          	ld	s2,0(sp)
    80003b08:	02010113          	addi	sp,sp,32
    80003b0c:	00008067          	ret
    return -1;
    80003b10:	fff00513          	li	a0,-1
    80003b14:	fe5ff06f          	j	80003af8 <fetchaddr+0x58>
    80003b18:	fff00513          	li	a0,-1
    80003b1c:	fddff06f          	j	80003af8 <fetchaddr+0x58>

0000000080003b20 <fetchstr>:
{
    80003b20:	fd010113          	addi	sp,sp,-48
    80003b24:	02113423          	sd	ra,40(sp)
    80003b28:	02813023          	sd	s0,32(sp)
    80003b2c:	00913c23          	sd	s1,24(sp)
    80003b30:	01213823          	sd	s2,16(sp)
    80003b34:	01313423          	sd	s3,8(sp)
    80003b38:	03010413          	addi	s0,sp,48
    80003b3c:	00050913          	mv	s2,a0
    80003b40:	00058493          	mv	s1,a1
    80003b44:	00060993          	mv	s3,a2
  struct proc *p = myproc();
    80003b48:	fffff097          	auipc	ra,0xfffff
    80003b4c:	8f4080e7          	jalr	-1804(ra) # 8000243c <myproc>
  int err = copyinstr(p->pagetable, buf, addr, max);
    80003b50:	00098693          	mv	a3,s3
    80003b54:	00090613          	mv	a2,s2
    80003b58:	00048593          	mv	a1,s1
    80003b5c:	05053503          	ld	a0,80(a0)
    80003b60:	ffffe097          	auipc	ra,0xffffe
    80003b64:	5b4080e7          	jalr	1460(ra) # 80002114 <copyinstr>
  if(err < 0)
    80003b68:	00054863          	bltz	a0,80003b78 <fetchstr+0x58>
  return strlen(buf);
    80003b6c:	00048513          	mv	a0,s1
    80003b70:	ffffe097          	auipc	ra,0xffffe
    80003b74:	800080e7          	jalr	-2048(ra) # 80001370 <strlen>
}
    80003b78:	02813083          	ld	ra,40(sp)
    80003b7c:	02013403          	ld	s0,32(sp)
    80003b80:	01813483          	ld	s1,24(sp)
    80003b84:	01013903          	ld	s2,16(sp)
    80003b88:	00813983          	ld	s3,8(sp)
    80003b8c:	03010113          	addi	sp,sp,48
    80003b90:	00008067          	ret

0000000080003b94 <argint>:

// Fetch the nth 32-bit system call argument.
int
argint(int n, int *ip)
{
    80003b94:	fe010113          	addi	sp,sp,-32
    80003b98:	00113c23          	sd	ra,24(sp)
    80003b9c:	00813823          	sd	s0,16(sp)
    80003ba0:	00913423          	sd	s1,8(sp)
    80003ba4:	02010413          	addi	s0,sp,32
    80003ba8:	00058493          	mv	s1,a1
  *ip = argraw(n);
    80003bac:	00000097          	auipc	ra,0x0
    80003bb0:	e48080e7          	jalr	-440(ra) # 800039f4 <argraw>
    80003bb4:	00a4a023          	sw	a0,0(s1)
  return 0;
}
    80003bb8:	00000513          	li	a0,0
    80003bbc:	01813083          	ld	ra,24(sp)
    80003bc0:	01013403          	ld	s0,16(sp)
    80003bc4:	00813483          	ld	s1,8(sp)
    80003bc8:	02010113          	addi	sp,sp,32
    80003bcc:	00008067          	ret

0000000080003bd0 <argaddr>:
// Retrieve an argument as a pointer.
// Doesn't check for legality, since
// copyin/copyout will do that.
int
argaddr(int n, uint64 *ip)
{
    80003bd0:	fe010113          	addi	sp,sp,-32
    80003bd4:	00113c23          	sd	ra,24(sp)
    80003bd8:	00813823          	sd	s0,16(sp)
    80003bdc:	00913423          	sd	s1,8(sp)
    80003be0:	02010413          	addi	s0,sp,32
    80003be4:	00058493          	mv	s1,a1
  *ip = argraw(n);
    80003be8:	00000097          	auipc	ra,0x0
    80003bec:	e0c080e7          	jalr	-500(ra) # 800039f4 <argraw>
    80003bf0:	00a4b023          	sd	a0,0(s1)
  return 0;
}
    80003bf4:	00000513          	li	a0,0
    80003bf8:	01813083          	ld	ra,24(sp)
    80003bfc:	01013403          	ld	s0,16(sp)
    80003c00:	00813483          	ld	s1,8(sp)
    80003c04:	02010113          	addi	sp,sp,32
    80003c08:	00008067          	ret

0000000080003c0c <argstr>:
// Fetch the nth word-sized system call argument as a null-terminated string.
// Copies into buf, at most max.
// Returns string length if OK (including nul), -1 if error.
int
argstr(int n, char *buf, int max)
{
    80003c0c:	fe010113          	addi	sp,sp,-32
    80003c10:	00113c23          	sd	ra,24(sp)
    80003c14:	00813823          	sd	s0,16(sp)
    80003c18:	00913423          	sd	s1,8(sp)
    80003c1c:	01213023          	sd	s2,0(sp)
    80003c20:	02010413          	addi	s0,sp,32
    80003c24:	00058493          	mv	s1,a1
    80003c28:	00060913          	mv	s2,a2
  *ip = argraw(n);
    80003c2c:	00000097          	auipc	ra,0x0
    80003c30:	dc8080e7          	jalr	-568(ra) # 800039f4 <argraw>
  uint64 addr;
  if(argaddr(n, &addr) < 0)
    return -1;
  return fetchstr(addr, buf, max);
    80003c34:	00090613          	mv	a2,s2
    80003c38:	00048593          	mv	a1,s1
    80003c3c:	00000097          	auipc	ra,0x0
    80003c40:	ee4080e7          	jalr	-284(ra) # 80003b20 <fetchstr>
}
    80003c44:	01813083          	ld	ra,24(sp)
    80003c48:	01013403          	ld	s0,16(sp)
    80003c4c:	00813483          	ld	s1,8(sp)
    80003c50:	00013903          	ld	s2,0(sp)
    80003c54:	02010113          	addi	sp,sp,32
    80003c58:	00008067          	ret

0000000080003c5c <syscall>:
[SYS_close]   sys_close,
};

void
syscall(void)
{
    80003c5c:	fe010113          	addi	sp,sp,-32
    80003c60:	00113c23          	sd	ra,24(sp)
    80003c64:	00813823          	sd	s0,16(sp)
    80003c68:	00913423          	sd	s1,8(sp)
    80003c6c:	01213023          	sd	s2,0(sp)
    80003c70:	02010413          	addi	s0,sp,32
  int num;
  struct proc *p = myproc();
    80003c74:	ffffe097          	auipc	ra,0xffffe
    80003c78:	7c8080e7          	jalr	1992(ra) # 8000243c <myproc>
    80003c7c:	00050493          	mv	s1,a0

  num = p->trapframe->a7;
    80003c80:	05853903          	ld	s2,88(a0)
    80003c84:	0a893783          	ld	a5,168(s2)
    80003c88:	0007869b          	sext.w	a3,a5
  if(num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    80003c8c:	fff7879b          	addiw	a5,a5,-1
    80003c90:	01400713          	li	a4,20
    80003c94:	02f76463          	bltu	a4,a5,80003cbc <syscall+0x60>
    80003c98:	00369713          	slli	a4,a3,0x3
    80003c9c:	00006797          	auipc	a5,0x6
    80003ca0:	7ac78793          	addi	a5,a5,1964 # 8000a448 <syscalls>
    80003ca4:	00e787b3          	add	a5,a5,a4
    80003ca8:	0007b783          	ld	a5,0(a5)
    80003cac:	00078863          	beqz	a5,80003cbc <syscall+0x60>
    p->trapframe->a0 = syscalls[num]();
    80003cb0:	000780e7          	jalr	a5
    80003cb4:	06a93823          	sd	a0,112(s2)
    80003cb8:	0280006f          	j	80003ce0 <syscall+0x84>
  } else {
    printf("%d %s: unknown sys call %d\n",
    80003cbc:	15848613          	addi	a2,s1,344
    80003cc0:	0304a583          	lw	a1,48(s1)
    80003cc4:	00006517          	auipc	a0,0x6
    80003cc8:	74c50513          	addi	a0,a0,1868 # 8000a410 <states.0+0x150>
    80003ccc:	ffffd097          	auipc	ra,0xffffd
    80003cd0:	a60080e7          	jalr	-1440(ra) # 8000072c <printf>
            p->pid, p->name, num);
    p->trapframe->a0 = -1;
    80003cd4:	0584b783          	ld	a5,88(s1)
    80003cd8:	fff00713          	li	a4,-1
    80003cdc:	06e7b823          	sd	a4,112(a5)
  }
}
    80003ce0:	01813083          	ld	ra,24(sp)
    80003ce4:	01013403          	ld	s0,16(sp)
    80003ce8:	00813483          	ld	s1,8(sp)
    80003cec:	00013903          	ld	s2,0(sp)
    80003cf0:	02010113          	addi	sp,sp,32
    80003cf4:	00008067          	ret

0000000080003cf8 <sys_exit>:
#include "spinlock.h"
#include "proc.h"

uint64
sys_exit(void)
{
    80003cf8:	fe010113          	addi	sp,sp,-32
    80003cfc:	00113c23          	sd	ra,24(sp)
    80003d00:	00813823          	sd	s0,16(sp)
    80003d04:	02010413          	addi	s0,sp,32
  int n;
  if(argint(0, &n) < 0)
    80003d08:	fec40593          	addi	a1,s0,-20
    80003d0c:	00000513          	li	a0,0
    80003d10:	00000097          	auipc	ra,0x0
    80003d14:	e84080e7          	jalr	-380(ra) # 80003b94 <argint>
    return -1;
    80003d18:	fff00793          	li	a5,-1
  if(argint(0, &n) < 0)
    80003d1c:	00054a63          	bltz	a0,80003d30 <sys_exit+0x38>
  exit(n);
    80003d20:	fec42503          	lw	a0,-20(s0)
    80003d24:	fffff097          	auipc	ra,0xfffff
    80003d28:	3d8080e7          	jalr	984(ra) # 800030fc <exit>
  return 0;  // not reached
    80003d2c:	00000793          	li	a5,0
}
    80003d30:	00078513          	mv	a0,a5
    80003d34:	01813083          	ld	ra,24(sp)
    80003d38:	01013403          	ld	s0,16(sp)
    80003d3c:	02010113          	addi	sp,sp,32
    80003d40:	00008067          	ret

0000000080003d44 <sys_getpid>:

uint64
sys_getpid(void)
{
    80003d44:	ff010113          	addi	sp,sp,-16
    80003d48:	00113423          	sd	ra,8(sp)
    80003d4c:	00813023          	sd	s0,0(sp)
    80003d50:	01010413          	addi	s0,sp,16
  return myproc()->pid;
    80003d54:	ffffe097          	auipc	ra,0xffffe
    80003d58:	6e8080e7          	jalr	1768(ra) # 8000243c <myproc>
}
    80003d5c:	03052503          	lw	a0,48(a0)
    80003d60:	00813083          	ld	ra,8(sp)
    80003d64:	00013403          	ld	s0,0(sp)
    80003d68:	01010113          	addi	sp,sp,16
    80003d6c:	00008067          	ret

0000000080003d70 <sys_fork>:

uint64
sys_fork(void)
{
    80003d70:	ff010113          	addi	sp,sp,-16
    80003d74:	00113423          	sd	ra,8(sp)
    80003d78:	00813023          	sd	s0,0(sp)
    80003d7c:	01010413          	addi	s0,sp,16
  return fork();
    80003d80:	fffff097          	auipc	ra,0xfffff
    80003d84:	c44080e7          	jalr	-956(ra) # 800029c4 <fork>
}
    80003d88:	00813083          	ld	ra,8(sp)
    80003d8c:	00013403          	ld	s0,0(sp)
    80003d90:	01010113          	addi	sp,sp,16
    80003d94:	00008067          	ret

0000000080003d98 <sys_wait>:

uint64
sys_wait(void)
{
    80003d98:	fe010113          	addi	sp,sp,-32
    80003d9c:	00113c23          	sd	ra,24(sp)
    80003da0:	00813823          	sd	s0,16(sp)
    80003da4:	02010413          	addi	s0,sp,32
  uint64 p;
  if(argaddr(0, &p) < 0)
    80003da8:	fe840593          	addi	a1,s0,-24
    80003dac:	00000513          	li	a0,0
    80003db0:	00000097          	auipc	ra,0x0
    80003db4:	e20080e7          	jalr	-480(ra) # 80003bd0 <argaddr>
    80003db8:	00050793          	mv	a5,a0
    return -1;
    80003dbc:	fff00513          	li	a0,-1
  if(argaddr(0, &p) < 0)
    80003dc0:	0007c863          	bltz	a5,80003dd0 <sys_wait+0x38>
  return wait(p);
    80003dc4:	fe843503          	ld	a0,-24(s0)
    80003dc8:	fffff097          	auipc	ra,0xfffff
    80003dcc:	074080e7          	jalr	116(ra) # 80002e3c <wait>
}
    80003dd0:	01813083          	ld	ra,24(sp)
    80003dd4:	01013403          	ld	s0,16(sp)
    80003dd8:	02010113          	addi	sp,sp,32
    80003ddc:	00008067          	ret

0000000080003de0 <sys_sbrk>:

uint64
sys_sbrk(void)
{
    80003de0:	fd010113          	addi	sp,sp,-48
    80003de4:	02113423          	sd	ra,40(sp)
    80003de8:	02813023          	sd	s0,32(sp)
    80003dec:	00913c23          	sd	s1,24(sp)
    80003df0:	03010413          	addi	s0,sp,48
  int addr;
  int n;

  if(argint(0, &n) < 0)
    80003df4:	fdc40593          	addi	a1,s0,-36
    80003df8:	00000513          	li	a0,0
    80003dfc:	00000097          	auipc	ra,0x0
    80003e00:	d98080e7          	jalr	-616(ra) # 80003b94 <argint>
    80003e04:	00050793          	mv	a5,a0
    return -1;
    80003e08:	fff00513          	li	a0,-1
  if(argint(0, &n) < 0)
    80003e0c:	0207c263          	bltz	a5,80003e30 <sys_sbrk+0x50>
  addr = myproc()->sz;
    80003e10:	ffffe097          	auipc	ra,0xffffe
    80003e14:	62c080e7          	jalr	1580(ra) # 8000243c <myproc>
    80003e18:	04852483          	lw	s1,72(a0)
  if(growproc(n) < 0)
    80003e1c:	fdc42503          	lw	a0,-36(s0)
    80003e20:	fffff097          	auipc	ra,0xfffff
    80003e24:	aec080e7          	jalr	-1300(ra) # 8000290c <growproc>
    80003e28:	00054e63          	bltz	a0,80003e44 <sys_sbrk+0x64>
    return -1;
  return addr;
    80003e2c:	00048513          	mv	a0,s1
}
    80003e30:	02813083          	ld	ra,40(sp)
    80003e34:	02013403          	ld	s0,32(sp)
    80003e38:	01813483          	ld	s1,24(sp)
    80003e3c:	03010113          	addi	sp,sp,48
    80003e40:	00008067          	ret
    return -1;
    80003e44:	fff00513          	li	a0,-1
    80003e48:	fe9ff06f          	j	80003e30 <sys_sbrk+0x50>

0000000080003e4c <sys_sleep>:

uint64
sys_sleep(void)
{
    80003e4c:	fc010113          	addi	sp,sp,-64
    80003e50:	02113c23          	sd	ra,56(sp)
    80003e54:	02813823          	sd	s0,48(sp)
    80003e58:	02913423          	sd	s1,40(sp)
    80003e5c:	03213023          	sd	s2,32(sp)
    80003e60:	01313c23          	sd	s3,24(sp)
    80003e64:	04010413          	addi	s0,sp,64
  int n;
  uint ticks0;

  if(argint(0, &n) < 0)
    80003e68:	fcc40593          	addi	a1,s0,-52
    80003e6c:	00000513          	li	a0,0
    80003e70:	00000097          	auipc	ra,0x0
    80003e74:	d24080e7          	jalr	-732(ra) # 80003b94 <argint>
    return -1;
    80003e78:	fff00793          	li	a5,-1
  if(argint(0, &n) < 0)
    80003e7c:	06054c63          	bltz	a0,80003ef4 <sys_sleep+0xa8>
  acquire(&tickslock);
    80003e80:	00015517          	auipc	a0,0x15
    80003e84:	25050513          	addi	a0,a0,592 # 800190d0 <tickslock>
    80003e88:	ffffd097          	auipc	ra,0xffffd
    80003e8c:	144080e7          	jalr	324(ra) # 80000fcc <acquire>
  ticks0 = ticks;
    80003e90:	00007917          	auipc	s2,0x7
    80003e94:	1a092903          	lw	s2,416(s2) # 8000b030 <ticks>
  while(ticks - ticks0 < n){
    80003e98:	fcc42783          	lw	a5,-52(s0)
    80003e9c:	04078263          	beqz	a5,80003ee0 <sys_sleep+0x94>
    if(myproc()->killed){
      release(&tickslock);
      return -1;
    }
    sleep(&ticks, &tickslock);
    80003ea0:	00015997          	auipc	s3,0x15
    80003ea4:	23098993          	addi	s3,s3,560 # 800190d0 <tickslock>
    80003ea8:	00007497          	auipc	s1,0x7
    80003eac:	18848493          	addi	s1,s1,392 # 8000b030 <ticks>
    if(myproc()->killed){
    80003eb0:	ffffe097          	auipc	ra,0xffffe
    80003eb4:	58c080e7          	jalr	1420(ra) # 8000243c <myproc>
    80003eb8:	02852783          	lw	a5,40(a0)
    80003ebc:	04079c63          	bnez	a5,80003f14 <sys_sleep+0xc8>
    sleep(&ticks, &tickslock);
    80003ec0:	00098593          	mv	a1,s3
    80003ec4:	00048513          	mv	a0,s1
    80003ec8:	fffff097          	auipc	ra,0xfffff
    80003ecc:	ee4080e7          	jalr	-284(ra) # 80002dac <sleep>
  while(ticks - ticks0 < n){
    80003ed0:	0004a783          	lw	a5,0(s1)
    80003ed4:	412787bb          	subw	a5,a5,s2
    80003ed8:	fcc42703          	lw	a4,-52(s0)
    80003edc:	fce7eae3          	bltu	a5,a4,80003eb0 <sys_sleep+0x64>
  }
  release(&tickslock);
    80003ee0:	00015517          	auipc	a0,0x15
    80003ee4:	1f050513          	addi	a0,a0,496 # 800190d0 <tickslock>
    80003ee8:	ffffd097          	auipc	ra,0xffffd
    80003eec:	1dc080e7          	jalr	476(ra) # 800010c4 <release>
  return 0;
    80003ef0:	00000793          	li	a5,0
}
    80003ef4:	00078513          	mv	a0,a5
    80003ef8:	03813083          	ld	ra,56(sp)
    80003efc:	03013403          	ld	s0,48(sp)
    80003f00:	02813483          	ld	s1,40(sp)
    80003f04:	02013903          	ld	s2,32(sp)
    80003f08:	01813983          	ld	s3,24(sp)
    80003f0c:	04010113          	addi	sp,sp,64
    80003f10:	00008067          	ret
      release(&tickslock);
    80003f14:	00015517          	auipc	a0,0x15
    80003f18:	1bc50513          	addi	a0,a0,444 # 800190d0 <tickslock>
    80003f1c:	ffffd097          	auipc	ra,0xffffd
    80003f20:	1a8080e7          	jalr	424(ra) # 800010c4 <release>
      return -1;
    80003f24:	fff00793          	li	a5,-1
    80003f28:	fcdff06f          	j	80003ef4 <sys_sleep+0xa8>

0000000080003f2c <sys_kill>:

uint64
sys_kill(void)
{
    80003f2c:	fe010113          	addi	sp,sp,-32
    80003f30:	00113c23          	sd	ra,24(sp)
    80003f34:	00813823          	sd	s0,16(sp)
    80003f38:	02010413          	addi	s0,sp,32
  int pid;

  if(argint(0, &pid) < 0)
    80003f3c:	fec40593          	addi	a1,s0,-20
    80003f40:	00000513          	li	a0,0
    80003f44:	00000097          	auipc	ra,0x0
    80003f48:	c50080e7          	jalr	-944(ra) # 80003b94 <argint>
    80003f4c:	00050793          	mv	a5,a0
    return -1;
    80003f50:	fff00513          	li	a0,-1
  if(argint(0, &pid) < 0)
    80003f54:	0007c863          	bltz	a5,80003f64 <sys_kill+0x38>
  return kill(pid);
    80003f58:	fec42503          	lw	a0,-20(s0)
    80003f5c:	fffff097          	auipc	ra,0xfffff
    80003f60:	29c080e7          	jalr	668(ra) # 800031f8 <kill>
}
    80003f64:	01813083          	ld	ra,24(sp)
    80003f68:	01013403          	ld	s0,16(sp)
    80003f6c:	02010113          	addi	sp,sp,32
    80003f70:	00008067          	ret

0000000080003f74 <sys_uptime>:

// return how many clock tick interrupts have occurred
// since start.
uint64
sys_uptime(void)
{
    80003f74:	fe010113          	addi	sp,sp,-32
    80003f78:	00113c23          	sd	ra,24(sp)
    80003f7c:	00813823          	sd	s0,16(sp)
    80003f80:	00913423          	sd	s1,8(sp)
    80003f84:	02010413          	addi	s0,sp,32
  uint xticks;

  acquire(&tickslock);
    80003f88:	00015517          	auipc	a0,0x15
    80003f8c:	14850513          	addi	a0,a0,328 # 800190d0 <tickslock>
    80003f90:	ffffd097          	auipc	ra,0xffffd
    80003f94:	03c080e7          	jalr	60(ra) # 80000fcc <acquire>
  xticks = ticks;
    80003f98:	00007497          	auipc	s1,0x7
    80003f9c:	0984a483          	lw	s1,152(s1) # 8000b030 <ticks>
  release(&tickslock);
    80003fa0:	00015517          	auipc	a0,0x15
    80003fa4:	13050513          	addi	a0,a0,304 # 800190d0 <tickslock>
    80003fa8:	ffffd097          	auipc	ra,0xffffd
    80003fac:	11c080e7          	jalr	284(ra) # 800010c4 <release>
  return xticks;
}
    80003fb0:	02049513          	slli	a0,s1,0x20
    80003fb4:	02055513          	srli	a0,a0,0x20
    80003fb8:	01813083          	ld	ra,24(sp)
    80003fbc:	01013403          	ld	s0,16(sp)
    80003fc0:	00813483          	ld	s1,8(sp)
    80003fc4:	02010113          	addi	sp,sp,32
    80003fc8:	00008067          	ret

0000000080003fcc <binit>:
  struct buf head;
} bcache;

void
binit(void)
{
    80003fcc:	fd010113          	addi	sp,sp,-48
    80003fd0:	02113423          	sd	ra,40(sp)
    80003fd4:	02813023          	sd	s0,32(sp)
    80003fd8:	00913c23          	sd	s1,24(sp)
    80003fdc:	01213823          	sd	s2,16(sp)
    80003fe0:	01313423          	sd	s3,8(sp)
    80003fe4:	01413023          	sd	s4,0(sp)
    80003fe8:	03010413          	addi	s0,sp,48
  struct buf *b;

  initlock(&bcache.lock, "bcache");
    80003fec:	00006597          	auipc	a1,0x6
    80003ff0:	50c58593          	addi	a1,a1,1292 # 8000a4f8 <syscalls+0xb0>
    80003ff4:	00015517          	auipc	a0,0x15
    80003ff8:	0f450513          	addi	a0,a0,244 # 800190e8 <bcache>
    80003ffc:	ffffd097          	auipc	ra,0xffffd
    80004000:	eec080e7          	jalr	-276(ra) # 80000ee8 <initlock>

  // Create linked list of buffers
  bcache.head.prev = &bcache.head;
    80004004:	0001d797          	auipc	a5,0x1d
    80004008:	0e478793          	addi	a5,a5,228 # 800210e8 <bcache+0x8000>
    8000400c:	0001d717          	auipc	a4,0x1d
    80004010:	34470713          	addi	a4,a4,836 # 80021350 <bcache+0x8268>
    80004014:	2ae7b823          	sd	a4,688(a5)
  bcache.head.next = &bcache.head;
    80004018:	2ae7bc23          	sd	a4,696(a5)
  for(b = bcache.buf; b < bcache.buf+NBUF; b++){
    8000401c:	00015497          	auipc	s1,0x15
    80004020:	0e448493          	addi	s1,s1,228 # 80019100 <bcache+0x18>
    b->next = bcache.head.next;
    80004024:	00078913          	mv	s2,a5
    b->prev = &bcache.head;
    80004028:	00070993          	mv	s3,a4
    initsleeplock(&b->lock, "buffer");
    8000402c:	00006a17          	auipc	s4,0x6
    80004030:	4d4a0a13          	addi	s4,s4,1236 # 8000a500 <syscalls+0xb8>
    b->next = bcache.head.next;
    80004034:	2b893783          	ld	a5,696(s2)
    80004038:	04f4b823          	sd	a5,80(s1)
    b->prev = &bcache.head;
    8000403c:	0534b423          	sd	s3,72(s1)
    initsleeplock(&b->lock, "buffer");
    80004040:	000a0593          	mv	a1,s4
    80004044:	01048513          	addi	a0,s1,16
    80004048:	00002097          	auipc	ra,0x2
    8000404c:	c98080e7          	jalr	-872(ra) # 80005ce0 <initsleeplock>
    bcache.head.next->prev = b;
    80004050:	2b893783          	ld	a5,696(s2)
    80004054:	0497b423          	sd	s1,72(a5)
    bcache.head.next = b;
    80004058:	2a993c23          	sd	s1,696(s2)
  for(b = bcache.buf; b < bcache.buf+NBUF; b++){
    8000405c:	45848493          	addi	s1,s1,1112
    80004060:	fd349ae3          	bne	s1,s3,80004034 <binit+0x68>
  }
}
    80004064:	02813083          	ld	ra,40(sp)
    80004068:	02013403          	ld	s0,32(sp)
    8000406c:	01813483          	ld	s1,24(sp)
    80004070:	01013903          	ld	s2,16(sp)
    80004074:	00813983          	ld	s3,8(sp)
    80004078:	00013a03          	ld	s4,0(sp)
    8000407c:	03010113          	addi	sp,sp,48
    80004080:	00008067          	ret

0000000080004084 <bread>:
}

// Return a locked buf with the contents of the indicated block.
struct buf*
bread(uint dev, uint blockno)
{
    80004084:	fd010113          	addi	sp,sp,-48
    80004088:	02113423          	sd	ra,40(sp)
    8000408c:	02813023          	sd	s0,32(sp)
    80004090:	00913c23          	sd	s1,24(sp)
    80004094:	01213823          	sd	s2,16(sp)
    80004098:	01313423          	sd	s3,8(sp)
    8000409c:	03010413          	addi	s0,sp,48
    800040a0:	00050913          	mv	s2,a0
    800040a4:	00058993          	mv	s3,a1
  acquire(&bcache.lock);
    800040a8:	00015517          	auipc	a0,0x15
    800040ac:	04050513          	addi	a0,a0,64 # 800190e8 <bcache>
    800040b0:	ffffd097          	auipc	ra,0xffffd
    800040b4:	f1c080e7          	jalr	-228(ra) # 80000fcc <acquire>
  for(b = bcache.head.next; b != &bcache.head; b = b->next){
    800040b8:	0001d497          	auipc	s1,0x1d
    800040bc:	2e84b483          	ld	s1,744(s1) # 800213a0 <bcache+0x82b8>
    800040c0:	0001d797          	auipc	a5,0x1d
    800040c4:	29078793          	addi	a5,a5,656 # 80021350 <bcache+0x8268>
    800040c8:	04f48863          	beq	s1,a5,80004118 <bread+0x94>
    800040cc:	00078713          	mv	a4,a5
    800040d0:	00c0006f          	j	800040dc <bread+0x58>
    800040d4:	0504b483          	ld	s1,80(s1)
    800040d8:	04e48063          	beq	s1,a4,80004118 <bread+0x94>
    if(b->dev == dev && b->blockno == blockno){
    800040dc:	0084a783          	lw	a5,8(s1)
    800040e0:	ff279ae3          	bne	a5,s2,800040d4 <bread+0x50>
    800040e4:	00c4a783          	lw	a5,12(s1)
    800040e8:	ff3796e3          	bne	a5,s3,800040d4 <bread+0x50>
      b->refcnt++;
    800040ec:	0404a783          	lw	a5,64(s1)
    800040f0:	0017879b          	addiw	a5,a5,1
    800040f4:	04f4a023          	sw	a5,64(s1)
      release(&bcache.lock);
    800040f8:	00015517          	auipc	a0,0x15
    800040fc:	ff050513          	addi	a0,a0,-16 # 800190e8 <bcache>
    80004100:	ffffd097          	auipc	ra,0xffffd
    80004104:	fc4080e7          	jalr	-60(ra) # 800010c4 <release>
      acquiresleep(&b->lock);
    80004108:	01048513          	addi	a0,s1,16
    8000410c:	00002097          	auipc	ra,0x2
    80004110:	c2c080e7          	jalr	-980(ra) # 80005d38 <acquiresleep>
      return b;
    80004114:	06c0006f          	j	80004180 <bread+0xfc>
  for(b = bcache.head.prev; b != &bcache.head; b = b->prev){
    80004118:	0001d497          	auipc	s1,0x1d
    8000411c:	2804b483          	ld	s1,640(s1) # 80021398 <bcache+0x82b0>
    80004120:	0001d797          	auipc	a5,0x1d
    80004124:	23078793          	addi	a5,a5,560 # 80021350 <bcache+0x8268>
    80004128:	00f48c63          	beq	s1,a5,80004140 <bread+0xbc>
    8000412c:	00078713          	mv	a4,a5
    if(b->refcnt == 0) {
    80004130:	0404a783          	lw	a5,64(s1)
    80004134:	00078e63          	beqz	a5,80004150 <bread+0xcc>
  for(b = bcache.head.prev; b != &bcache.head; b = b->prev){
    80004138:	0484b483          	ld	s1,72(s1)
    8000413c:	fee49ae3          	bne	s1,a4,80004130 <bread+0xac>
  panic("bget: no buffers");
    80004140:	00006517          	auipc	a0,0x6
    80004144:	3c850513          	addi	a0,a0,968 # 8000a508 <syscalls+0xc0>
    80004148:	ffffc097          	auipc	ra,0xffffc
    8000414c:	588080e7          	jalr	1416(ra) # 800006d0 <panic>
      b->dev = dev;
    80004150:	0124a423          	sw	s2,8(s1)
      b->blockno = blockno;
    80004154:	0134a623          	sw	s3,12(s1)
      b->valid = 0;
    80004158:	0004a023          	sw	zero,0(s1)
      b->refcnt = 1;
    8000415c:	00100793          	li	a5,1
    80004160:	04f4a023          	sw	a5,64(s1)
      release(&bcache.lock);
    80004164:	00015517          	auipc	a0,0x15
    80004168:	f8450513          	addi	a0,a0,-124 # 800190e8 <bcache>
    8000416c:	ffffd097          	auipc	ra,0xffffd
    80004170:	f58080e7          	jalr	-168(ra) # 800010c4 <release>
      acquiresleep(&b->lock);
    80004174:	01048513          	addi	a0,s1,16
    80004178:	00002097          	auipc	ra,0x2
    8000417c:	bc0080e7          	jalr	-1088(ra) # 80005d38 <acquiresleep>
  struct buf *b;

  b = bget(dev, blockno);
  if(!b->valid) {
    80004180:	0004a783          	lw	a5,0(s1)
    80004184:	02078263          	beqz	a5,800041a8 <bread+0x124>
    virtio_disk_rw(b, 0);
    b->valid = 1;
  }
  return b;
}
    80004188:	00048513          	mv	a0,s1
    8000418c:	02813083          	ld	ra,40(sp)
    80004190:	02013403          	ld	s0,32(sp)
    80004194:	01813483          	ld	s1,24(sp)
    80004198:	01013903          	ld	s2,16(sp)
    8000419c:	00813983          	ld	s3,8(sp)
    800041a0:	03010113          	addi	sp,sp,48
    800041a4:	00008067          	ret
    virtio_disk_rw(b, 0);
    800041a8:	00000593          	li	a1,0
    800041ac:	00048513          	mv	a0,s1
    800041b0:	00004097          	auipc	ra,0x4
    800041b4:	03c080e7          	jalr	60(ra) # 800081ec <virtio_disk_rw>
    b->valid = 1;
    800041b8:	00100793          	li	a5,1
    800041bc:	00f4a023          	sw	a5,0(s1)
  return b;
    800041c0:	fc9ff06f          	j	80004188 <bread+0x104>

00000000800041c4 <bwrite>:

// Write b's contents to disk.  Must be locked.
void
bwrite(struct buf *b)
{
    800041c4:	fe010113          	addi	sp,sp,-32
    800041c8:	00113c23          	sd	ra,24(sp)
    800041cc:	00813823          	sd	s0,16(sp)
    800041d0:	00913423          	sd	s1,8(sp)
    800041d4:	02010413          	addi	s0,sp,32
    800041d8:	00050493          	mv	s1,a0
  if(!holdingsleep(&b->lock))
    800041dc:	01050513          	addi	a0,a0,16
    800041e0:	00002097          	auipc	ra,0x2
    800041e4:	c44080e7          	jalr	-956(ra) # 80005e24 <holdingsleep>
    800041e8:	02050463          	beqz	a0,80004210 <bwrite+0x4c>
    panic("bwrite");
  virtio_disk_rw(b, 1);
    800041ec:	00100593          	li	a1,1
    800041f0:	00048513          	mv	a0,s1
    800041f4:	00004097          	auipc	ra,0x4
    800041f8:	ff8080e7          	jalr	-8(ra) # 800081ec <virtio_disk_rw>
}
    800041fc:	01813083          	ld	ra,24(sp)
    80004200:	01013403          	ld	s0,16(sp)
    80004204:	00813483          	ld	s1,8(sp)
    80004208:	02010113          	addi	sp,sp,32
    8000420c:	00008067          	ret
    panic("bwrite");
    80004210:	00006517          	auipc	a0,0x6
    80004214:	31050513          	addi	a0,a0,784 # 8000a520 <syscalls+0xd8>
    80004218:	ffffc097          	auipc	ra,0xffffc
    8000421c:	4b8080e7          	jalr	1208(ra) # 800006d0 <panic>

0000000080004220 <brelse>:

// Release a locked buffer.
// Move to the head of the most-recently-used list.
void
brelse(struct buf *b)
{
    80004220:	fe010113          	addi	sp,sp,-32
    80004224:	00113c23          	sd	ra,24(sp)
    80004228:	00813823          	sd	s0,16(sp)
    8000422c:	00913423          	sd	s1,8(sp)
    80004230:	01213023          	sd	s2,0(sp)
    80004234:	02010413          	addi	s0,sp,32
    80004238:	00050493          	mv	s1,a0
  if(!holdingsleep(&b->lock))
    8000423c:	01050913          	addi	s2,a0,16
    80004240:	00090513          	mv	a0,s2
    80004244:	00002097          	auipc	ra,0x2
    80004248:	be0080e7          	jalr	-1056(ra) # 80005e24 <holdingsleep>
    8000424c:	08050e63          	beqz	a0,800042e8 <brelse+0xc8>
    panic("brelse");

  releasesleep(&b->lock);
    80004250:	00090513          	mv	a0,s2
    80004254:	00002097          	auipc	ra,0x2
    80004258:	b6c080e7          	jalr	-1172(ra) # 80005dc0 <releasesleep>

  acquire(&bcache.lock);
    8000425c:	00015517          	auipc	a0,0x15
    80004260:	e8c50513          	addi	a0,a0,-372 # 800190e8 <bcache>
    80004264:	ffffd097          	auipc	ra,0xffffd
    80004268:	d68080e7          	jalr	-664(ra) # 80000fcc <acquire>
  b->refcnt--;
    8000426c:	0404a783          	lw	a5,64(s1)
    80004270:	fff7879b          	addiw	a5,a5,-1
    80004274:	0007871b          	sext.w	a4,a5
    80004278:	04f4a023          	sw	a5,64(s1)
  if (b->refcnt == 0) {
    8000427c:	04071263          	bnez	a4,800042c0 <brelse+0xa0>
    // no one is waiting for it.
    b->next->prev = b->prev;
    80004280:	0504b783          	ld	a5,80(s1)
    80004284:	0484b703          	ld	a4,72(s1)
    80004288:	04e7b423          	sd	a4,72(a5)
    b->prev->next = b->next;
    8000428c:	0484b783          	ld	a5,72(s1)
    80004290:	0504b703          	ld	a4,80(s1)
    80004294:	04e7b823          	sd	a4,80(a5)
    b->next = bcache.head.next;
    80004298:	0001d797          	auipc	a5,0x1d
    8000429c:	e5078793          	addi	a5,a5,-432 # 800210e8 <bcache+0x8000>
    800042a0:	2b87b703          	ld	a4,696(a5)
    800042a4:	04e4b823          	sd	a4,80(s1)
    b->prev = &bcache.head;
    800042a8:	0001d717          	auipc	a4,0x1d
    800042ac:	0a870713          	addi	a4,a4,168 # 80021350 <bcache+0x8268>
    800042b0:	04e4b423          	sd	a4,72(s1)
    bcache.head.next->prev = b;
    800042b4:	2b87b703          	ld	a4,696(a5)
    800042b8:	04973423          	sd	s1,72(a4)
    bcache.head.next = b;
    800042bc:	2a97bc23          	sd	s1,696(a5)
  }
  
  release(&bcache.lock);
    800042c0:	00015517          	auipc	a0,0x15
    800042c4:	e2850513          	addi	a0,a0,-472 # 800190e8 <bcache>
    800042c8:	ffffd097          	auipc	ra,0xffffd
    800042cc:	dfc080e7          	jalr	-516(ra) # 800010c4 <release>
}
    800042d0:	01813083          	ld	ra,24(sp)
    800042d4:	01013403          	ld	s0,16(sp)
    800042d8:	00813483          	ld	s1,8(sp)
    800042dc:	00013903          	ld	s2,0(sp)
    800042e0:	02010113          	addi	sp,sp,32
    800042e4:	00008067          	ret
    panic("brelse");
    800042e8:	00006517          	auipc	a0,0x6
    800042ec:	24050513          	addi	a0,a0,576 # 8000a528 <syscalls+0xe0>
    800042f0:	ffffc097          	auipc	ra,0xffffc
    800042f4:	3e0080e7          	jalr	992(ra) # 800006d0 <panic>

00000000800042f8 <bpin>:

void
bpin(struct buf *b) {
    800042f8:	fe010113          	addi	sp,sp,-32
    800042fc:	00113c23          	sd	ra,24(sp)
    80004300:	00813823          	sd	s0,16(sp)
    80004304:	00913423          	sd	s1,8(sp)
    80004308:	02010413          	addi	s0,sp,32
    8000430c:	00050493          	mv	s1,a0
  acquire(&bcache.lock);
    80004310:	00015517          	auipc	a0,0x15
    80004314:	dd850513          	addi	a0,a0,-552 # 800190e8 <bcache>
    80004318:	ffffd097          	auipc	ra,0xffffd
    8000431c:	cb4080e7          	jalr	-844(ra) # 80000fcc <acquire>
  b->refcnt++;
    80004320:	0404a783          	lw	a5,64(s1)
    80004324:	0017879b          	addiw	a5,a5,1
    80004328:	04f4a023          	sw	a5,64(s1)
  release(&bcache.lock);
    8000432c:	00015517          	auipc	a0,0x15
    80004330:	dbc50513          	addi	a0,a0,-580 # 800190e8 <bcache>
    80004334:	ffffd097          	auipc	ra,0xffffd
    80004338:	d90080e7          	jalr	-624(ra) # 800010c4 <release>
}
    8000433c:	01813083          	ld	ra,24(sp)
    80004340:	01013403          	ld	s0,16(sp)
    80004344:	00813483          	ld	s1,8(sp)
    80004348:	02010113          	addi	sp,sp,32
    8000434c:	00008067          	ret

0000000080004350 <bunpin>:

void
bunpin(struct buf *b) {
    80004350:	fe010113          	addi	sp,sp,-32
    80004354:	00113c23          	sd	ra,24(sp)
    80004358:	00813823          	sd	s0,16(sp)
    8000435c:	00913423          	sd	s1,8(sp)
    80004360:	02010413          	addi	s0,sp,32
    80004364:	00050493          	mv	s1,a0
  acquire(&bcache.lock);
    80004368:	00015517          	auipc	a0,0x15
    8000436c:	d8050513          	addi	a0,a0,-640 # 800190e8 <bcache>
    80004370:	ffffd097          	auipc	ra,0xffffd
    80004374:	c5c080e7          	jalr	-932(ra) # 80000fcc <acquire>
  b->refcnt--;
    80004378:	0404a783          	lw	a5,64(s1)
    8000437c:	fff7879b          	addiw	a5,a5,-1
    80004380:	04f4a023          	sw	a5,64(s1)
  release(&bcache.lock);
    80004384:	00015517          	auipc	a0,0x15
    80004388:	d6450513          	addi	a0,a0,-668 # 800190e8 <bcache>
    8000438c:	ffffd097          	auipc	ra,0xffffd
    80004390:	d38080e7          	jalr	-712(ra) # 800010c4 <release>
}
    80004394:	01813083          	ld	ra,24(sp)
    80004398:	01013403          	ld	s0,16(sp)
    8000439c:	00813483          	ld	s1,8(sp)
    800043a0:	02010113          	addi	sp,sp,32
    800043a4:	00008067          	ret

00000000800043a8 <bfree>:
}

// Free a disk block.
static void
bfree(int dev, uint b)
{
    800043a8:	fe010113          	addi	sp,sp,-32
    800043ac:	00113c23          	sd	ra,24(sp)
    800043b0:	00813823          	sd	s0,16(sp)
    800043b4:	00913423          	sd	s1,8(sp)
    800043b8:	01213023          	sd	s2,0(sp)
    800043bc:	02010413          	addi	s0,sp,32
    800043c0:	00058493          	mv	s1,a1
  struct buf *bp;
  int bi, m;

  bp = bread(dev, BBLOCK(b, sb));
    800043c4:	00d5d59b          	srliw	a1,a1,0xd
    800043c8:	0001d797          	auipc	a5,0x1d
    800043cc:	3fc7a783          	lw	a5,1020(a5) # 800217c4 <sb+0x1c>
    800043d0:	00f585bb          	addw	a1,a1,a5
    800043d4:	00000097          	auipc	ra,0x0
    800043d8:	cb0080e7          	jalr	-848(ra) # 80004084 <bread>
  bi = b % BPB;
  m = 1 << (bi % 8);
    800043dc:	0074f713          	andi	a4,s1,7
    800043e0:	00100793          	li	a5,1
    800043e4:	00e797bb          	sllw	a5,a5,a4
  if((bp->data[bi/8] & m) == 0)
    800043e8:	03349493          	slli	s1,s1,0x33
    800043ec:	0364d493          	srli	s1,s1,0x36
    800043f0:	00950733          	add	a4,a0,s1
    800043f4:	05874703          	lbu	a4,88(a4)
    800043f8:	00e7f6b3          	and	a3,a5,a4
    800043fc:	04068263          	beqz	a3,80004440 <bfree+0x98>
    80004400:	00050913          	mv	s2,a0
    panic("freeing free block");
  bp->data[bi/8] &= ~m;
    80004404:	009504b3          	add	s1,a0,s1
    80004408:	fff7c793          	not	a5,a5
    8000440c:	00f77733          	and	a4,a4,a5
    80004410:	04e48c23          	sb	a4,88(s1)
  log_write(bp);
    80004414:	00001097          	auipc	ra,0x1
    80004418:	7a0080e7          	jalr	1952(ra) # 80005bb4 <log_write>
  brelse(bp);
    8000441c:	00090513          	mv	a0,s2
    80004420:	00000097          	auipc	ra,0x0
    80004424:	e00080e7          	jalr	-512(ra) # 80004220 <brelse>
}
    80004428:	01813083          	ld	ra,24(sp)
    8000442c:	01013403          	ld	s0,16(sp)
    80004430:	00813483          	ld	s1,8(sp)
    80004434:	00013903          	ld	s2,0(sp)
    80004438:	02010113          	addi	sp,sp,32
    8000443c:	00008067          	ret
    panic("freeing free block");
    80004440:	00006517          	auipc	a0,0x6
    80004444:	0f050513          	addi	a0,a0,240 # 8000a530 <syscalls+0xe8>
    80004448:	ffffc097          	auipc	ra,0xffffc
    8000444c:	288080e7          	jalr	648(ra) # 800006d0 <panic>

0000000080004450 <balloc>:
{
    80004450:	fa010113          	addi	sp,sp,-96
    80004454:	04113c23          	sd	ra,88(sp)
    80004458:	04813823          	sd	s0,80(sp)
    8000445c:	04913423          	sd	s1,72(sp)
    80004460:	05213023          	sd	s2,64(sp)
    80004464:	03313c23          	sd	s3,56(sp)
    80004468:	03413823          	sd	s4,48(sp)
    8000446c:	03513423          	sd	s5,40(sp)
    80004470:	03613023          	sd	s6,32(sp)
    80004474:	01713c23          	sd	s7,24(sp)
    80004478:	01813823          	sd	s8,16(sp)
    8000447c:	01913423          	sd	s9,8(sp)
    80004480:	06010413          	addi	s0,sp,96
  for(b = 0; b < sb.size; b += BPB){
    80004484:	0001d797          	auipc	a5,0x1d
    80004488:	3287a783          	lw	a5,808(a5) # 800217ac <sb+0x4>
    8000448c:	0a078a63          	beqz	a5,80004540 <balloc+0xf0>
    80004490:	00050b93          	mv	s7,a0
    80004494:	00000a93          	li	s5,0
    bp = bread(dev, BBLOCK(b, sb));
    80004498:	0001db17          	auipc	s6,0x1d
    8000449c:	310b0b13          	addi	s6,s6,784 # 800217a8 <sb>
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    800044a0:	00000c13          	li	s8,0
      m = 1 << (bi % 8);
    800044a4:	00100993          	li	s3,1
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    800044a8:	00002a37          	lui	s4,0x2
  for(b = 0; b < sb.size; b += BPB){
    800044ac:	00002cb7          	lui	s9,0x2
    800044b0:	0200006f          	j	800044d0 <balloc+0x80>
    brelse(bp);
    800044b4:	00090513          	mv	a0,s2
    800044b8:	00000097          	auipc	ra,0x0
    800044bc:	d68080e7          	jalr	-664(ra) # 80004220 <brelse>
  for(b = 0; b < sb.size; b += BPB){
    800044c0:	015c87bb          	addw	a5,s9,s5
    800044c4:	00078a9b          	sext.w	s5,a5
    800044c8:	004b2703          	lw	a4,4(s6)
    800044cc:	06eafa63          	bgeu	s5,a4,80004540 <balloc+0xf0>
    bp = bread(dev, BBLOCK(b, sb));
    800044d0:	41fad79b          	sraiw	a5,s5,0x1f
    800044d4:	0137d79b          	srliw	a5,a5,0x13
    800044d8:	015787bb          	addw	a5,a5,s5
    800044dc:	40d7d79b          	sraiw	a5,a5,0xd
    800044e0:	01cb2583          	lw	a1,28(s6)
    800044e4:	00b785bb          	addw	a1,a5,a1
    800044e8:	000b8513          	mv	a0,s7
    800044ec:	00000097          	auipc	ra,0x0
    800044f0:	b98080e7          	jalr	-1128(ra) # 80004084 <bread>
    800044f4:	00050913          	mv	s2,a0
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    800044f8:	004b2503          	lw	a0,4(s6)
    800044fc:	000a849b          	sext.w	s1,s5
    80004500:	000c0713          	mv	a4,s8
    80004504:	faa4f8e3          	bgeu	s1,a0,800044b4 <balloc+0x64>
      m = 1 << (bi % 8);
    80004508:	00777693          	andi	a3,a4,7
    8000450c:	00d996bb          	sllw	a3,s3,a3
      if((bp->data[bi/8] & m) == 0){  // Is block free?
    80004510:	41f7579b          	sraiw	a5,a4,0x1f
    80004514:	01d7d79b          	srliw	a5,a5,0x1d
    80004518:	00e787bb          	addw	a5,a5,a4
    8000451c:	4037d79b          	sraiw	a5,a5,0x3
    80004520:	00f90633          	add	a2,s2,a5
    80004524:	05864603          	lbu	a2,88(a2)
    80004528:	00c6f5b3          	and	a1,a3,a2
    8000452c:	02058263          	beqz	a1,80004550 <balloc+0x100>
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    80004530:	0017071b          	addiw	a4,a4,1
    80004534:	0014849b          	addiw	s1,s1,1
    80004538:	fd4716e3          	bne	a4,s4,80004504 <balloc+0xb4>
    8000453c:	f79ff06f          	j	800044b4 <balloc+0x64>
  panic("balloc: out of blocks");
    80004540:	00006517          	auipc	a0,0x6
    80004544:	00850513          	addi	a0,a0,8 # 8000a548 <syscalls+0x100>
    80004548:	ffffc097          	auipc	ra,0xffffc
    8000454c:	188080e7          	jalr	392(ra) # 800006d0 <panic>
        bp->data[bi/8] |= m;  // Mark block in use.
    80004550:	00f907b3          	add	a5,s2,a5
    80004554:	00d66633          	or	a2,a2,a3
    80004558:	04c78c23          	sb	a2,88(a5)
        log_write(bp);
    8000455c:	00090513          	mv	a0,s2
    80004560:	00001097          	auipc	ra,0x1
    80004564:	654080e7          	jalr	1620(ra) # 80005bb4 <log_write>
        brelse(bp);
    80004568:	00090513          	mv	a0,s2
    8000456c:	00000097          	auipc	ra,0x0
    80004570:	cb4080e7          	jalr	-844(ra) # 80004220 <brelse>
  bp = bread(dev, bno);
    80004574:	00048593          	mv	a1,s1
    80004578:	000b8513          	mv	a0,s7
    8000457c:	00000097          	auipc	ra,0x0
    80004580:	b08080e7          	jalr	-1272(ra) # 80004084 <bread>
    80004584:	00050913          	mv	s2,a0
  memset(bp->data, 0, BSIZE);
    80004588:	40000613          	li	a2,1024
    8000458c:	00000593          	li	a1,0
    80004590:	05850513          	addi	a0,a0,88
    80004594:	ffffd097          	auipc	ra,0xffffd
    80004598:	b90080e7          	jalr	-1136(ra) # 80001124 <memset>
  log_write(bp);
    8000459c:	00090513          	mv	a0,s2
    800045a0:	00001097          	auipc	ra,0x1
    800045a4:	614080e7          	jalr	1556(ra) # 80005bb4 <log_write>
  brelse(bp);
    800045a8:	00090513          	mv	a0,s2
    800045ac:	00000097          	auipc	ra,0x0
    800045b0:	c74080e7          	jalr	-908(ra) # 80004220 <brelse>
}
    800045b4:	00048513          	mv	a0,s1
    800045b8:	05813083          	ld	ra,88(sp)
    800045bc:	05013403          	ld	s0,80(sp)
    800045c0:	04813483          	ld	s1,72(sp)
    800045c4:	04013903          	ld	s2,64(sp)
    800045c8:	03813983          	ld	s3,56(sp)
    800045cc:	03013a03          	ld	s4,48(sp)
    800045d0:	02813a83          	ld	s5,40(sp)
    800045d4:	02013b03          	ld	s6,32(sp)
    800045d8:	01813b83          	ld	s7,24(sp)
    800045dc:	01013c03          	ld	s8,16(sp)
    800045e0:	00813c83          	ld	s9,8(sp)
    800045e4:	06010113          	addi	sp,sp,96
    800045e8:	00008067          	ret

00000000800045ec <bmap>:

// Return the disk block address of the nth block in inode ip.
// If there is no such block, bmap allocates one.
static uint
bmap(struct inode *ip, uint bn)
{
    800045ec:	fd010113          	addi	sp,sp,-48
    800045f0:	02113423          	sd	ra,40(sp)
    800045f4:	02813023          	sd	s0,32(sp)
    800045f8:	00913c23          	sd	s1,24(sp)
    800045fc:	01213823          	sd	s2,16(sp)
    80004600:	01313423          	sd	s3,8(sp)
    80004604:	01413023          	sd	s4,0(sp)
    80004608:	03010413          	addi	s0,sp,48
    8000460c:	00050913          	mv	s2,a0
  uint addr, *a;
  struct buf *bp;

  if(bn < NDIRECT){
    80004610:	00b00793          	li	a5,11
    80004614:	06b7fa63          	bgeu	a5,a1,80004688 <bmap+0x9c>
    if((addr = ip->addrs[bn]) == 0)
      ip->addrs[bn] = addr = balloc(ip->dev);
    return addr;
  }
  bn -= NDIRECT;
    80004618:	ff45849b          	addiw	s1,a1,-12
    8000461c:	0004871b          	sext.w	a4,s1

  if(bn < NINDIRECT){
    80004620:	0ff00793          	li	a5,255
    80004624:	0ce7e663          	bltu	a5,a4,800046f0 <bmap+0x104>
    // Load indirect block, allocating if necessary.
    if((addr = ip->addrs[NDIRECT]) == 0)
    80004628:	08052583          	lw	a1,128(a0)
    8000462c:	08058463          	beqz	a1,800046b4 <bmap+0xc8>
      ip->addrs[NDIRECT] = addr = balloc(ip->dev);
    bp = bread(ip->dev, addr);
    80004630:	00092503          	lw	a0,0(s2)
    80004634:	00000097          	auipc	ra,0x0
    80004638:	a50080e7          	jalr	-1456(ra) # 80004084 <bread>
    8000463c:	00050a13          	mv	s4,a0
    a = (uint*)bp->data;
    80004640:	05850793          	addi	a5,a0,88
    if((addr = a[bn]) == 0){
    80004644:	02049713          	slli	a4,s1,0x20
    80004648:	01e75593          	srli	a1,a4,0x1e
    8000464c:	00b784b3          	add	s1,a5,a1
    80004650:	0004a983          	lw	s3,0(s1)
    80004654:	06098c63          	beqz	s3,800046cc <bmap+0xe0>
      a[bn] = addr = balloc(ip->dev);
      log_write(bp);
    }
    brelse(bp);
    80004658:	000a0513          	mv	a0,s4
    8000465c:	00000097          	auipc	ra,0x0
    80004660:	bc4080e7          	jalr	-1084(ra) # 80004220 <brelse>
    return addr;
  }

  panic("bmap: out of range");
}
    80004664:	00098513          	mv	a0,s3
    80004668:	02813083          	ld	ra,40(sp)
    8000466c:	02013403          	ld	s0,32(sp)
    80004670:	01813483          	ld	s1,24(sp)
    80004674:	01013903          	ld	s2,16(sp)
    80004678:	00813983          	ld	s3,8(sp)
    8000467c:	00013a03          	ld	s4,0(sp)
    80004680:	03010113          	addi	sp,sp,48
    80004684:	00008067          	ret
    if((addr = ip->addrs[bn]) == 0)
    80004688:	02059793          	slli	a5,a1,0x20
    8000468c:	01e7d593          	srli	a1,a5,0x1e
    80004690:	00b504b3          	add	s1,a0,a1
    80004694:	0504a983          	lw	s3,80(s1)
    80004698:	fc0996e3          	bnez	s3,80004664 <bmap+0x78>
      ip->addrs[bn] = addr = balloc(ip->dev);
    8000469c:	00052503          	lw	a0,0(a0)
    800046a0:	00000097          	auipc	ra,0x0
    800046a4:	db0080e7          	jalr	-592(ra) # 80004450 <balloc>
    800046a8:	0005099b          	sext.w	s3,a0
    800046ac:	0534a823          	sw	s3,80(s1)
    800046b0:	fb5ff06f          	j	80004664 <bmap+0x78>
      ip->addrs[NDIRECT] = addr = balloc(ip->dev);
    800046b4:	00052503          	lw	a0,0(a0)
    800046b8:	00000097          	auipc	ra,0x0
    800046bc:	d98080e7          	jalr	-616(ra) # 80004450 <balloc>
    800046c0:	0005059b          	sext.w	a1,a0
    800046c4:	08b92023          	sw	a1,128(s2)
    800046c8:	f69ff06f          	j	80004630 <bmap+0x44>
      a[bn] = addr = balloc(ip->dev);
    800046cc:	00092503          	lw	a0,0(s2)
    800046d0:	00000097          	auipc	ra,0x0
    800046d4:	d80080e7          	jalr	-640(ra) # 80004450 <balloc>
    800046d8:	0005099b          	sext.w	s3,a0
    800046dc:	0134a023          	sw	s3,0(s1)
      log_write(bp);
    800046e0:	000a0513          	mv	a0,s4
    800046e4:	00001097          	auipc	ra,0x1
    800046e8:	4d0080e7          	jalr	1232(ra) # 80005bb4 <log_write>
    800046ec:	f6dff06f          	j	80004658 <bmap+0x6c>
  panic("bmap: out of range");
    800046f0:	00006517          	auipc	a0,0x6
    800046f4:	e7050513          	addi	a0,a0,-400 # 8000a560 <syscalls+0x118>
    800046f8:	ffffc097          	auipc	ra,0xffffc
    800046fc:	fd8080e7          	jalr	-40(ra) # 800006d0 <panic>

0000000080004700 <iget>:
{
    80004700:	fd010113          	addi	sp,sp,-48
    80004704:	02113423          	sd	ra,40(sp)
    80004708:	02813023          	sd	s0,32(sp)
    8000470c:	00913c23          	sd	s1,24(sp)
    80004710:	01213823          	sd	s2,16(sp)
    80004714:	01313423          	sd	s3,8(sp)
    80004718:	01413023          	sd	s4,0(sp)
    8000471c:	03010413          	addi	s0,sp,48
    80004720:	00050993          	mv	s3,a0
    80004724:	00058a13          	mv	s4,a1
  acquire(&itable.lock);
    80004728:	0001d517          	auipc	a0,0x1d
    8000472c:	0a050513          	addi	a0,a0,160 # 800217c8 <itable>
    80004730:	ffffd097          	auipc	ra,0xffffd
    80004734:	89c080e7          	jalr	-1892(ra) # 80000fcc <acquire>
  empty = 0;
    80004738:	00000913          	li	s2,0
  for(ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++){
    8000473c:	0001d497          	auipc	s1,0x1d
    80004740:	0a448493          	addi	s1,s1,164 # 800217e0 <itable+0x18>
    80004744:	0001f697          	auipc	a3,0x1f
    80004748:	b2c68693          	addi	a3,a3,-1236 # 80023270 <log>
    8000474c:	0100006f          	j	8000475c <iget+0x5c>
    if(empty == 0 && ip->ref == 0)    // Remember empty slot.
    80004750:	04090263          	beqz	s2,80004794 <iget+0x94>
  for(ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++){
    80004754:	08848493          	addi	s1,s1,136
    80004758:	04d48463          	beq	s1,a3,800047a0 <iget+0xa0>
    if(ip->ref > 0 && ip->dev == dev && ip->inum == inum){
    8000475c:	0084a783          	lw	a5,8(s1)
    80004760:	fef058e3          	blez	a5,80004750 <iget+0x50>
    80004764:	0004a703          	lw	a4,0(s1)
    80004768:	ff3714e3          	bne	a4,s3,80004750 <iget+0x50>
    8000476c:	0044a703          	lw	a4,4(s1)
    80004770:	ff4710e3          	bne	a4,s4,80004750 <iget+0x50>
      ip->ref++;
    80004774:	0017879b          	addiw	a5,a5,1
    80004778:	00f4a423          	sw	a5,8(s1)
      release(&itable.lock);
    8000477c:	0001d517          	auipc	a0,0x1d
    80004780:	04c50513          	addi	a0,a0,76 # 800217c8 <itable>
    80004784:	ffffd097          	auipc	ra,0xffffd
    80004788:	940080e7          	jalr	-1728(ra) # 800010c4 <release>
      return ip;
    8000478c:	00048913          	mv	s2,s1
    80004790:	0380006f          	j	800047c8 <iget+0xc8>
    if(empty == 0 && ip->ref == 0)    // Remember empty slot.
    80004794:	fc0790e3          	bnez	a5,80004754 <iget+0x54>
    80004798:	00048913          	mv	s2,s1
    8000479c:	fb9ff06f          	j	80004754 <iget+0x54>
  if(empty == 0)
    800047a0:	04090663          	beqz	s2,800047ec <iget+0xec>
  ip->dev = dev;
    800047a4:	01392023          	sw	s3,0(s2)
  ip->inum = inum;
    800047a8:	01492223          	sw	s4,4(s2)
  ip->ref = 1;
    800047ac:	00100793          	li	a5,1
    800047b0:	00f92423          	sw	a5,8(s2)
  ip->valid = 0;
    800047b4:	04092023          	sw	zero,64(s2)
  release(&itable.lock);
    800047b8:	0001d517          	auipc	a0,0x1d
    800047bc:	01050513          	addi	a0,a0,16 # 800217c8 <itable>
    800047c0:	ffffd097          	auipc	ra,0xffffd
    800047c4:	904080e7          	jalr	-1788(ra) # 800010c4 <release>
}
    800047c8:	00090513          	mv	a0,s2
    800047cc:	02813083          	ld	ra,40(sp)
    800047d0:	02013403          	ld	s0,32(sp)
    800047d4:	01813483          	ld	s1,24(sp)
    800047d8:	01013903          	ld	s2,16(sp)
    800047dc:	00813983          	ld	s3,8(sp)
    800047e0:	00013a03          	ld	s4,0(sp)
    800047e4:	03010113          	addi	sp,sp,48
    800047e8:	00008067          	ret
    panic("iget: no inodes");
    800047ec:	00006517          	auipc	a0,0x6
    800047f0:	d8c50513          	addi	a0,a0,-628 # 8000a578 <syscalls+0x130>
    800047f4:	ffffc097          	auipc	ra,0xffffc
    800047f8:	edc080e7          	jalr	-292(ra) # 800006d0 <panic>

00000000800047fc <fsinit>:
fsinit(int dev) {
    800047fc:	fd010113          	addi	sp,sp,-48
    80004800:	02113423          	sd	ra,40(sp)
    80004804:	02813023          	sd	s0,32(sp)
    80004808:	00913c23          	sd	s1,24(sp)
    8000480c:	01213823          	sd	s2,16(sp)
    80004810:	01313423          	sd	s3,8(sp)
    80004814:	03010413          	addi	s0,sp,48
    80004818:	00050913          	mv	s2,a0
  bp = bread(dev, 1);
    8000481c:	00100593          	li	a1,1
    80004820:	00000097          	auipc	ra,0x0
    80004824:	864080e7          	jalr	-1948(ra) # 80004084 <bread>
    80004828:	00050493          	mv	s1,a0
  memmove(sb, bp->data, sizeof(*sb));
    8000482c:	0001d997          	auipc	s3,0x1d
    80004830:	f7c98993          	addi	s3,s3,-132 # 800217a8 <sb>
    80004834:	02000613          	li	a2,32
    80004838:	05850593          	addi	a1,a0,88
    8000483c:	00098513          	mv	a0,s3
    80004840:	ffffd097          	auipc	ra,0xffffd
    80004844:	978080e7          	jalr	-1672(ra) # 800011b8 <memmove>
  brelse(bp);
    80004848:	00048513          	mv	a0,s1
    8000484c:	00000097          	auipc	ra,0x0
    80004850:	9d4080e7          	jalr	-1580(ra) # 80004220 <brelse>
  if(sb.magic != FSMAGIC)
    80004854:	0009a703          	lw	a4,0(s3)
    80004858:	102037b7          	lui	a5,0x10203
    8000485c:	04078793          	addi	a5,a5,64 # 10203040 <_entry-0x6fdfcfc0>
    80004860:	02f71a63          	bne	a4,a5,80004894 <fsinit+0x98>
  initlog(dev, &sb);
    80004864:	0001d597          	auipc	a1,0x1d
    80004868:	f4458593          	addi	a1,a1,-188 # 800217a8 <sb>
    8000486c:	00090513          	mv	a0,s2
    80004870:	00001097          	auipc	ra,0x1
    80004874:	000080e7          	jalr	ra # 80005870 <initlog>
}
    80004878:	02813083          	ld	ra,40(sp)
    8000487c:	02013403          	ld	s0,32(sp)
    80004880:	01813483          	ld	s1,24(sp)
    80004884:	01013903          	ld	s2,16(sp)
    80004888:	00813983          	ld	s3,8(sp)
    8000488c:	03010113          	addi	sp,sp,48
    80004890:	00008067          	ret
    panic("invalid file system");
    80004894:	00006517          	auipc	a0,0x6
    80004898:	cf450513          	addi	a0,a0,-780 # 8000a588 <syscalls+0x140>
    8000489c:	ffffc097          	auipc	ra,0xffffc
    800048a0:	e34080e7          	jalr	-460(ra) # 800006d0 <panic>

00000000800048a4 <iinit>:
{
    800048a4:	fd010113          	addi	sp,sp,-48
    800048a8:	02113423          	sd	ra,40(sp)
    800048ac:	02813023          	sd	s0,32(sp)
    800048b0:	00913c23          	sd	s1,24(sp)
    800048b4:	01213823          	sd	s2,16(sp)
    800048b8:	01313423          	sd	s3,8(sp)
    800048bc:	03010413          	addi	s0,sp,48
  initlock(&itable.lock, "itable");
    800048c0:	00006597          	auipc	a1,0x6
    800048c4:	ce058593          	addi	a1,a1,-800 # 8000a5a0 <syscalls+0x158>
    800048c8:	0001d517          	auipc	a0,0x1d
    800048cc:	f0050513          	addi	a0,a0,-256 # 800217c8 <itable>
    800048d0:	ffffc097          	auipc	ra,0xffffc
    800048d4:	618080e7          	jalr	1560(ra) # 80000ee8 <initlock>
  for(i = 0; i < NINODE; i++) {
    800048d8:	0001d497          	auipc	s1,0x1d
    800048dc:	f1848493          	addi	s1,s1,-232 # 800217f0 <itable+0x28>
    800048e0:	0001f997          	auipc	s3,0x1f
    800048e4:	9a098993          	addi	s3,s3,-1632 # 80023280 <log+0x10>
    initsleeplock(&itable.inode[i].lock, "inode");
    800048e8:	00006917          	auipc	s2,0x6
    800048ec:	cc090913          	addi	s2,s2,-832 # 8000a5a8 <syscalls+0x160>
    800048f0:	00090593          	mv	a1,s2
    800048f4:	00048513          	mv	a0,s1
    800048f8:	00001097          	auipc	ra,0x1
    800048fc:	3e8080e7          	jalr	1000(ra) # 80005ce0 <initsleeplock>
  for(i = 0; i < NINODE; i++) {
    80004900:	08848493          	addi	s1,s1,136
    80004904:	ff3496e3          	bne	s1,s3,800048f0 <iinit+0x4c>
}
    80004908:	02813083          	ld	ra,40(sp)
    8000490c:	02013403          	ld	s0,32(sp)
    80004910:	01813483          	ld	s1,24(sp)
    80004914:	01013903          	ld	s2,16(sp)
    80004918:	00813983          	ld	s3,8(sp)
    8000491c:	03010113          	addi	sp,sp,48
    80004920:	00008067          	ret

0000000080004924 <ialloc>:
{
    80004924:	fb010113          	addi	sp,sp,-80
    80004928:	04113423          	sd	ra,72(sp)
    8000492c:	04813023          	sd	s0,64(sp)
    80004930:	02913c23          	sd	s1,56(sp)
    80004934:	03213823          	sd	s2,48(sp)
    80004938:	03313423          	sd	s3,40(sp)
    8000493c:	03413023          	sd	s4,32(sp)
    80004940:	01513c23          	sd	s5,24(sp)
    80004944:	01613823          	sd	s6,16(sp)
    80004948:	01713423          	sd	s7,8(sp)
    8000494c:	05010413          	addi	s0,sp,80
  for(inum = 1; inum < sb.ninodes; inum++){
    80004950:	0001d717          	auipc	a4,0x1d
    80004954:	e6472703          	lw	a4,-412(a4) # 800217b4 <sb+0xc>
    80004958:	00100793          	li	a5,1
    8000495c:	06e7f463          	bgeu	a5,a4,800049c4 <ialloc+0xa0>
    80004960:	00050a93          	mv	s5,a0
    80004964:	00058b93          	mv	s7,a1
    80004968:	00100493          	li	s1,1
    bp = bread(dev, IBLOCK(inum, sb));
    8000496c:	0001da17          	auipc	s4,0x1d
    80004970:	e3ca0a13          	addi	s4,s4,-452 # 800217a8 <sb>
    80004974:	00048b1b          	sext.w	s6,s1
    80004978:	0044d593          	srli	a1,s1,0x4
    8000497c:	018a2783          	lw	a5,24(s4)
    80004980:	00b785bb          	addw	a1,a5,a1
    80004984:	000a8513          	mv	a0,s5
    80004988:	fffff097          	auipc	ra,0xfffff
    8000498c:	6fc080e7          	jalr	1788(ra) # 80004084 <bread>
    80004990:	00050913          	mv	s2,a0
    dip = (struct dinode*)bp->data + inum%IPB;
    80004994:	05850993          	addi	s3,a0,88
    80004998:	00f4f793          	andi	a5,s1,15
    8000499c:	00679793          	slli	a5,a5,0x6
    800049a0:	00f989b3          	add	s3,s3,a5
    if(dip->type == 0){  // a free inode
    800049a4:	00099783          	lh	a5,0(s3)
    800049a8:	02078663          	beqz	a5,800049d4 <ialloc+0xb0>
    brelse(bp);
    800049ac:	00000097          	auipc	ra,0x0
    800049b0:	874080e7          	jalr	-1932(ra) # 80004220 <brelse>
  for(inum = 1; inum < sb.ninodes; inum++){
    800049b4:	00148493          	addi	s1,s1,1
    800049b8:	00ca2703          	lw	a4,12(s4)
    800049bc:	0004879b          	sext.w	a5,s1
    800049c0:	fae7eae3          	bltu	a5,a4,80004974 <ialloc+0x50>
  panic("ialloc: no inodes");
    800049c4:	00006517          	auipc	a0,0x6
    800049c8:	bec50513          	addi	a0,a0,-1044 # 8000a5b0 <syscalls+0x168>
    800049cc:	ffffc097          	auipc	ra,0xffffc
    800049d0:	d04080e7          	jalr	-764(ra) # 800006d0 <panic>
      memset(dip, 0, sizeof(*dip));
    800049d4:	04000613          	li	a2,64
    800049d8:	00000593          	li	a1,0
    800049dc:	00098513          	mv	a0,s3
    800049e0:	ffffc097          	auipc	ra,0xffffc
    800049e4:	744080e7          	jalr	1860(ra) # 80001124 <memset>
      dip->type = type;
    800049e8:	01799023          	sh	s7,0(s3)
      log_write(bp);   // mark it allocated on the disk
    800049ec:	00090513          	mv	a0,s2
    800049f0:	00001097          	auipc	ra,0x1
    800049f4:	1c4080e7          	jalr	452(ra) # 80005bb4 <log_write>
      brelse(bp);
    800049f8:	00090513          	mv	a0,s2
    800049fc:	00000097          	auipc	ra,0x0
    80004a00:	824080e7          	jalr	-2012(ra) # 80004220 <brelse>
      return iget(dev, inum);
    80004a04:	000b0593          	mv	a1,s6
    80004a08:	000a8513          	mv	a0,s5
    80004a0c:	00000097          	auipc	ra,0x0
    80004a10:	cf4080e7          	jalr	-780(ra) # 80004700 <iget>
}
    80004a14:	04813083          	ld	ra,72(sp)
    80004a18:	04013403          	ld	s0,64(sp)
    80004a1c:	03813483          	ld	s1,56(sp)
    80004a20:	03013903          	ld	s2,48(sp)
    80004a24:	02813983          	ld	s3,40(sp)
    80004a28:	02013a03          	ld	s4,32(sp)
    80004a2c:	01813a83          	ld	s5,24(sp)
    80004a30:	01013b03          	ld	s6,16(sp)
    80004a34:	00813b83          	ld	s7,8(sp)
    80004a38:	05010113          	addi	sp,sp,80
    80004a3c:	00008067          	ret

0000000080004a40 <iupdate>:
{
    80004a40:	fe010113          	addi	sp,sp,-32
    80004a44:	00113c23          	sd	ra,24(sp)
    80004a48:	00813823          	sd	s0,16(sp)
    80004a4c:	00913423          	sd	s1,8(sp)
    80004a50:	01213023          	sd	s2,0(sp)
    80004a54:	02010413          	addi	s0,sp,32
    80004a58:	00050493          	mv	s1,a0
  bp = bread(ip->dev, IBLOCK(ip->inum, sb));
    80004a5c:	00452783          	lw	a5,4(a0)
    80004a60:	0047d79b          	srliw	a5,a5,0x4
    80004a64:	0001d597          	auipc	a1,0x1d
    80004a68:	d5c5a583          	lw	a1,-676(a1) # 800217c0 <sb+0x18>
    80004a6c:	00b785bb          	addw	a1,a5,a1
    80004a70:	00052503          	lw	a0,0(a0)
    80004a74:	fffff097          	auipc	ra,0xfffff
    80004a78:	610080e7          	jalr	1552(ra) # 80004084 <bread>
    80004a7c:	00050913          	mv	s2,a0
  dip = (struct dinode*)bp->data + ip->inum%IPB;
    80004a80:	05850793          	addi	a5,a0,88
    80004a84:	0044a703          	lw	a4,4(s1)
    80004a88:	00f77713          	andi	a4,a4,15
    80004a8c:	00671713          	slli	a4,a4,0x6
    80004a90:	00e787b3          	add	a5,a5,a4
  dip->type = ip->type;
    80004a94:	04449703          	lh	a4,68(s1)
    80004a98:	00e79023          	sh	a4,0(a5)
  dip->major = ip->major;
    80004a9c:	04649703          	lh	a4,70(s1)
    80004aa0:	00e79123          	sh	a4,2(a5)
  dip->minor = ip->minor;
    80004aa4:	04849703          	lh	a4,72(s1)
    80004aa8:	00e79223          	sh	a4,4(a5)
  dip->nlink = ip->nlink;
    80004aac:	04a49703          	lh	a4,74(s1)
    80004ab0:	00e79323          	sh	a4,6(a5)
  dip->size = ip->size;
    80004ab4:	04c4a703          	lw	a4,76(s1)
    80004ab8:	00e7a423          	sw	a4,8(a5)
  memmove(dip->addrs, ip->addrs, sizeof(ip->addrs));
    80004abc:	03400613          	li	a2,52
    80004ac0:	05048593          	addi	a1,s1,80
    80004ac4:	00c78513          	addi	a0,a5,12
    80004ac8:	ffffc097          	auipc	ra,0xffffc
    80004acc:	6f0080e7          	jalr	1776(ra) # 800011b8 <memmove>
  log_write(bp);
    80004ad0:	00090513          	mv	a0,s2
    80004ad4:	00001097          	auipc	ra,0x1
    80004ad8:	0e0080e7          	jalr	224(ra) # 80005bb4 <log_write>
  brelse(bp);
    80004adc:	00090513          	mv	a0,s2
    80004ae0:	fffff097          	auipc	ra,0xfffff
    80004ae4:	740080e7          	jalr	1856(ra) # 80004220 <brelse>
}
    80004ae8:	01813083          	ld	ra,24(sp)
    80004aec:	01013403          	ld	s0,16(sp)
    80004af0:	00813483          	ld	s1,8(sp)
    80004af4:	00013903          	ld	s2,0(sp)
    80004af8:	02010113          	addi	sp,sp,32
    80004afc:	00008067          	ret

0000000080004b00 <idup>:
{
    80004b00:	fe010113          	addi	sp,sp,-32
    80004b04:	00113c23          	sd	ra,24(sp)
    80004b08:	00813823          	sd	s0,16(sp)
    80004b0c:	00913423          	sd	s1,8(sp)
    80004b10:	02010413          	addi	s0,sp,32
    80004b14:	00050493          	mv	s1,a0
  acquire(&itable.lock);
    80004b18:	0001d517          	auipc	a0,0x1d
    80004b1c:	cb050513          	addi	a0,a0,-848 # 800217c8 <itable>
    80004b20:	ffffc097          	auipc	ra,0xffffc
    80004b24:	4ac080e7          	jalr	1196(ra) # 80000fcc <acquire>
  ip->ref++;
    80004b28:	0084a783          	lw	a5,8(s1)
    80004b2c:	0017879b          	addiw	a5,a5,1
    80004b30:	00f4a423          	sw	a5,8(s1)
  release(&itable.lock);
    80004b34:	0001d517          	auipc	a0,0x1d
    80004b38:	c9450513          	addi	a0,a0,-876 # 800217c8 <itable>
    80004b3c:	ffffc097          	auipc	ra,0xffffc
    80004b40:	588080e7          	jalr	1416(ra) # 800010c4 <release>
}
    80004b44:	00048513          	mv	a0,s1
    80004b48:	01813083          	ld	ra,24(sp)
    80004b4c:	01013403          	ld	s0,16(sp)
    80004b50:	00813483          	ld	s1,8(sp)
    80004b54:	02010113          	addi	sp,sp,32
    80004b58:	00008067          	ret

0000000080004b5c <ilock>:
{
    80004b5c:	fe010113          	addi	sp,sp,-32
    80004b60:	00113c23          	sd	ra,24(sp)
    80004b64:	00813823          	sd	s0,16(sp)
    80004b68:	00913423          	sd	s1,8(sp)
    80004b6c:	01213023          	sd	s2,0(sp)
    80004b70:	02010413          	addi	s0,sp,32
  if(ip == 0 || ip->ref < 1)
    80004b74:	02050e63          	beqz	a0,80004bb0 <ilock+0x54>
    80004b78:	00050493          	mv	s1,a0
    80004b7c:	00852783          	lw	a5,8(a0)
    80004b80:	02f05863          	blez	a5,80004bb0 <ilock+0x54>
  acquiresleep(&ip->lock);
    80004b84:	01050513          	addi	a0,a0,16
    80004b88:	00001097          	auipc	ra,0x1
    80004b8c:	1b0080e7          	jalr	432(ra) # 80005d38 <acquiresleep>
  if(ip->valid == 0){
    80004b90:	0404a783          	lw	a5,64(s1)
    80004b94:	02078663          	beqz	a5,80004bc0 <ilock+0x64>
}
    80004b98:	01813083          	ld	ra,24(sp)
    80004b9c:	01013403          	ld	s0,16(sp)
    80004ba0:	00813483          	ld	s1,8(sp)
    80004ba4:	00013903          	ld	s2,0(sp)
    80004ba8:	02010113          	addi	sp,sp,32
    80004bac:	00008067          	ret
    panic("ilock");
    80004bb0:	00006517          	auipc	a0,0x6
    80004bb4:	a1850513          	addi	a0,a0,-1512 # 8000a5c8 <syscalls+0x180>
    80004bb8:	ffffc097          	auipc	ra,0xffffc
    80004bbc:	b18080e7          	jalr	-1256(ra) # 800006d0 <panic>
    bp = bread(ip->dev, IBLOCK(ip->inum, sb));
    80004bc0:	0044a783          	lw	a5,4(s1)
    80004bc4:	0047d79b          	srliw	a5,a5,0x4
    80004bc8:	0001d597          	auipc	a1,0x1d
    80004bcc:	bf85a583          	lw	a1,-1032(a1) # 800217c0 <sb+0x18>
    80004bd0:	00b785bb          	addw	a1,a5,a1
    80004bd4:	0004a503          	lw	a0,0(s1)
    80004bd8:	fffff097          	auipc	ra,0xfffff
    80004bdc:	4ac080e7          	jalr	1196(ra) # 80004084 <bread>
    80004be0:	00050913          	mv	s2,a0
    dip = (struct dinode*)bp->data + ip->inum%IPB;
    80004be4:	05850593          	addi	a1,a0,88
    80004be8:	0044a783          	lw	a5,4(s1)
    80004bec:	00f7f793          	andi	a5,a5,15
    80004bf0:	00679793          	slli	a5,a5,0x6
    80004bf4:	00f585b3          	add	a1,a1,a5
    ip->type = dip->type;
    80004bf8:	00059783          	lh	a5,0(a1)
    80004bfc:	04f49223          	sh	a5,68(s1)
    ip->major = dip->major;
    80004c00:	00259783          	lh	a5,2(a1)
    80004c04:	04f49323          	sh	a5,70(s1)
    ip->minor = dip->minor;
    80004c08:	00459783          	lh	a5,4(a1)
    80004c0c:	04f49423          	sh	a5,72(s1)
    ip->nlink = dip->nlink;
    80004c10:	00659783          	lh	a5,6(a1)
    80004c14:	04f49523          	sh	a5,74(s1)
    ip->size = dip->size;
    80004c18:	0085a783          	lw	a5,8(a1)
    80004c1c:	04f4a623          	sw	a5,76(s1)
    memmove(ip->addrs, dip->addrs, sizeof(ip->addrs));
    80004c20:	03400613          	li	a2,52
    80004c24:	00c58593          	addi	a1,a1,12
    80004c28:	05048513          	addi	a0,s1,80
    80004c2c:	ffffc097          	auipc	ra,0xffffc
    80004c30:	58c080e7          	jalr	1420(ra) # 800011b8 <memmove>
    brelse(bp);
    80004c34:	00090513          	mv	a0,s2
    80004c38:	fffff097          	auipc	ra,0xfffff
    80004c3c:	5e8080e7          	jalr	1512(ra) # 80004220 <brelse>
    ip->valid = 1;
    80004c40:	00100793          	li	a5,1
    80004c44:	04f4a023          	sw	a5,64(s1)
    if(ip->type == 0)
    80004c48:	04449783          	lh	a5,68(s1)
    80004c4c:	f40796e3          	bnez	a5,80004b98 <ilock+0x3c>
      panic("ilock: no type");
    80004c50:	00006517          	auipc	a0,0x6
    80004c54:	98050513          	addi	a0,a0,-1664 # 8000a5d0 <syscalls+0x188>
    80004c58:	ffffc097          	auipc	ra,0xffffc
    80004c5c:	a78080e7          	jalr	-1416(ra) # 800006d0 <panic>

0000000080004c60 <iunlock>:
{
    80004c60:	fe010113          	addi	sp,sp,-32
    80004c64:	00113c23          	sd	ra,24(sp)
    80004c68:	00813823          	sd	s0,16(sp)
    80004c6c:	00913423          	sd	s1,8(sp)
    80004c70:	01213023          	sd	s2,0(sp)
    80004c74:	02010413          	addi	s0,sp,32
  if(ip == 0 || !holdingsleep(&ip->lock) || ip->ref < 1)
    80004c78:	04050463          	beqz	a0,80004cc0 <iunlock+0x60>
    80004c7c:	00050493          	mv	s1,a0
    80004c80:	01050913          	addi	s2,a0,16
    80004c84:	00090513          	mv	a0,s2
    80004c88:	00001097          	auipc	ra,0x1
    80004c8c:	19c080e7          	jalr	412(ra) # 80005e24 <holdingsleep>
    80004c90:	02050863          	beqz	a0,80004cc0 <iunlock+0x60>
    80004c94:	0084a783          	lw	a5,8(s1)
    80004c98:	02f05463          	blez	a5,80004cc0 <iunlock+0x60>
  releasesleep(&ip->lock);
    80004c9c:	00090513          	mv	a0,s2
    80004ca0:	00001097          	auipc	ra,0x1
    80004ca4:	120080e7          	jalr	288(ra) # 80005dc0 <releasesleep>
}
    80004ca8:	01813083          	ld	ra,24(sp)
    80004cac:	01013403          	ld	s0,16(sp)
    80004cb0:	00813483          	ld	s1,8(sp)
    80004cb4:	00013903          	ld	s2,0(sp)
    80004cb8:	02010113          	addi	sp,sp,32
    80004cbc:	00008067          	ret
    panic("iunlock");
    80004cc0:	00006517          	auipc	a0,0x6
    80004cc4:	92050513          	addi	a0,a0,-1760 # 8000a5e0 <syscalls+0x198>
    80004cc8:	ffffc097          	auipc	ra,0xffffc
    80004ccc:	a08080e7          	jalr	-1528(ra) # 800006d0 <panic>

0000000080004cd0 <itrunc>:

// Truncate inode (discard contents).
// Caller must hold ip->lock.
void
itrunc(struct inode *ip)
{
    80004cd0:	fd010113          	addi	sp,sp,-48
    80004cd4:	02113423          	sd	ra,40(sp)
    80004cd8:	02813023          	sd	s0,32(sp)
    80004cdc:	00913c23          	sd	s1,24(sp)
    80004ce0:	01213823          	sd	s2,16(sp)
    80004ce4:	01313423          	sd	s3,8(sp)
    80004ce8:	01413023          	sd	s4,0(sp)
    80004cec:	03010413          	addi	s0,sp,48
    80004cf0:	00050993          	mv	s3,a0
  int i, j;
  struct buf *bp;
  uint *a;

  for(i = 0; i < NDIRECT; i++){
    80004cf4:	05050493          	addi	s1,a0,80
    80004cf8:	08050913          	addi	s2,a0,128
    80004cfc:	00c0006f          	j	80004d08 <itrunc+0x38>
    80004d00:	00448493          	addi	s1,s1,4
    80004d04:	03248063          	beq	s1,s2,80004d24 <itrunc+0x54>
    if(ip->addrs[i]){
    80004d08:	0004a583          	lw	a1,0(s1)
    80004d0c:	fe058ae3          	beqz	a1,80004d00 <itrunc+0x30>
      bfree(ip->dev, ip->addrs[i]);
    80004d10:	0009a503          	lw	a0,0(s3)
    80004d14:	fffff097          	auipc	ra,0xfffff
    80004d18:	694080e7          	jalr	1684(ra) # 800043a8 <bfree>
      ip->addrs[i] = 0;
    80004d1c:	0004a023          	sw	zero,0(s1)
    80004d20:	fe1ff06f          	j	80004d00 <itrunc+0x30>
    }
  }

  if(ip->addrs[NDIRECT]){
    80004d24:	0809a583          	lw	a1,128(s3)
    80004d28:	02059a63          	bnez	a1,80004d5c <itrunc+0x8c>
    brelse(bp);
    bfree(ip->dev, ip->addrs[NDIRECT]);
    ip->addrs[NDIRECT] = 0;
  }

  ip->size = 0;
    80004d2c:	0409a623          	sw	zero,76(s3)
  iupdate(ip);
    80004d30:	00098513          	mv	a0,s3
    80004d34:	00000097          	auipc	ra,0x0
    80004d38:	d0c080e7          	jalr	-756(ra) # 80004a40 <iupdate>
}
    80004d3c:	02813083          	ld	ra,40(sp)
    80004d40:	02013403          	ld	s0,32(sp)
    80004d44:	01813483          	ld	s1,24(sp)
    80004d48:	01013903          	ld	s2,16(sp)
    80004d4c:	00813983          	ld	s3,8(sp)
    80004d50:	00013a03          	ld	s4,0(sp)
    80004d54:	03010113          	addi	sp,sp,48
    80004d58:	00008067          	ret
    bp = bread(ip->dev, ip->addrs[NDIRECT]);
    80004d5c:	0009a503          	lw	a0,0(s3)
    80004d60:	fffff097          	auipc	ra,0xfffff
    80004d64:	324080e7          	jalr	804(ra) # 80004084 <bread>
    80004d68:	00050a13          	mv	s4,a0
    for(j = 0; j < NINDIRECT; j++){
    80004d6c:	05850493          	addi	s1,a0,88
    80004d70:	45850913          	addi	s2,a0,1112
    80004d74:	00c0006f          	j	80004d80 <itrunc+0xb0>
    80004d78:	00448493          	addi	s1,s1,4
    80004d7c:	01248e63          	beq	s1,s2,80004d98 <itrunc+0xc8>
      if(a[j])
    80004d80:	0004a583          	lw	a1,0(s1)
    80004d84:	fe058ae3          	beqz	a1,80004d78 <itrunc+0xa8>
        bfree(ip->dev, a[j]);
    80004d88:	0009a503          	lw	a0,0(s3)
    80004d8c:	fffff097          	auipc	ra,0xfffff
    80004d90:	61c080e7          	jalr	1564(ra) # 800043a8 <bfree>
    80004d94:	fe5ff06f          	j	80004d78 <itrunc+0xa8>
    brelse(bp);
    80004d98:	000a0513          	mv	a0,s4
    80004d9c:	fffff097          	auipc	ra,0xfffff
    80004da0:	484080e7          	jalr	1156(ra) # 80004220 <brelse>
    bfree(ip->dev, ip->addrs[NDIRECT]);
    80004da4:	0809a583          	lw	a1,128(s3)
    80004da8:	0009a503          	lw	a0,0(s3)
    80004dac:	fffff097          	auipc	ra,0xfffff
    80004db0:	5fc080e7          	jalr	1532(ra) # 800043a8 <bfree>
    ip->addrs[NDIRECT] = 0;
    80004db4:	0809a023          	sw	zero,128(s3)
    80004db8:	f75ff06f          	j	80004d2c <itrunc+0x5c>

0000000080004dbc <iput>:
{
    80004dbc:	fe010113          	addi	sp,sp,-32
    80004dc0:	00113c23          	sd	ra,24(sp)
    80004dc4:	00813823          	sd	s0,16(sp)
    80004dc8:	00913423          	sd	s1,8(sp)
    80004dcc:	01213023          	sd	s2,0(sp)
    80004dd0:	02010413          	addi	s0,sp,32
    80004dd4:	00050493          	mv	s1,a0
  acquire(&itable.lock);
    80004dd8:	0001d517          	auipc	a0,0x1d
    80004ddc:	9f050513          	addi	a0,a0,-1552 # 800217c8 <itable>
    80004de0:	ffffc097          	auipc	ra,0xffffc
    80004de4:	1ec080e7          	jalr	492(ra) # 80000fcc <acquire>
  if(ip->ref == 1 && ip->valid && ip->nlink == 0){
    80004de8:	0084a703          	lw	a4,8(s1)
    80004dec:	00100793          	li	a5,1
    80004df0:	02f70c63          	beq	a4,a5,80004e28 <iput+0x6c>
  ip->ref--;
    80004df4:	0084a783          	lw	a5,8(s1)
    80004df8:	fff7879b          	addiw	a5,a5,-1
    80004dfc:	00f4a423          	sw	a5,8(s1)
  release(&itable.lock);
    80004e00:	0001d517          	auipc	a0,0x1d
    80004e04:	9c850513          	addi	a0,a0,-1592 # 800217c8 <itable>
    80004e08:	ffffc097          	auipc	ra,0xffffc
    80004e0c:	2bc080e7          	jalr	700(ra) # 800010c4 <release>
}
    80004e10:	01813083          	ld	ra,24(sp)
    80004e14:	01013403          	ld	s0,16(sp)
    80004e18:	00813483          	ld	s1,8(sp)
    80004e1c:	00013903          	ld	s2,0(sp)
    80004e20:	02010113          	addi	sp,sp,32
    80004e24:	00008067          	ret
  if(ip->ref == 1 && ip->valid && ip->nlink == 0){
    80004e28:	0404a783          	lw	a5,64(s1)
    80004e2c:	fc0784e3          	beqz	a5,80004df4 <iput+0x38>
    80004e30:	04a49783          	lh	a5,74(s1)
    80004e34:	fc0790e3          	bnez	a5,80004df4 <iput+0x38>
    acquiresleep(&ip->lock);
    80004e38:	01048913          	addi	s2,s1,16
    80004e3c:	00090513          	mv	a0,s2
    80004e40:	00001097          	auipc	ra,0x1
    80004e44:	ef8080e7          	jalr	-264(ra) # 80005d38 <acquiresleep>
    release(&itable.lock);
    80004e48:	0001d517          	auipc	a0,0x1d
    80004e4c:	98050513          	addi	a0,a0,-1664 # 800217c8 <itable>
    80004e50:	ffffc097          	auipc	ra,0xffffc
    80004e54:	274080e7          	jalr	628(ra) # 800010c4 <release>
    itrunc(ip);
    80004e58:	00048513          	mv	a0,s1
    80004e5c:	00000097          	auipc	ra,0x0
    80004e60:	e74080e7          	jalr	-396(ra) # 80004cd0 <itrunc>
    ip->type = 0;
    80004e64:	04049223          	sh	zero,68(s1)
    iupdate(ip);
    80004e68:	00048513          	mv	a0,s1
    80004e6c:	00000097          	auipc	ra,0x0
    80004e70:	bd4080e7          	jalr	-1068(ra) # 80004a40 <iupdate>
    ip->valid = 0;
    80004e74:	0404a023          	sw	zero,64(s1)
    releasesleep(&ip->lock);
    80004e78:	00090513          	mv	a0,s2
    80004e7c:	00001097          	auipc	ra,0x1
    80004e80:	f44080e7          	jalr	-188(ra) # 80005dc0 <releasesleep>
    acquire(&itable.lock);
    80004e84:	0001d517          	auipc	a0,0x1d
    80004e88:	94450513          	addi	a0,a0,-1724 # 800217c8 <itable>
    80004e8c:	ffffc097          	auipc	ra,0xffffc
    80004e90:	140080e7          	jalr	320(ra) # 80000fcc <acquire>
    80004e94:	f61ff06f          	j	80004df4 <iput+0x38>

0000000080004e98 <iunlockput>:
{
    80004e98:	fe010113          	addi	sp,sp,-32
    80004e9c:	00113c23          	sd	ra,24(sp)
    80004ea0:	00813823          	sd	s0,16(sp)
    80004ea4:	00913423          	sd	s1,8(sp)
    80004ea8:	02010413          	addi	s0,sp,32
    80004eac:	00050493          	mv	s1,a0
  iunlock(ip);
    80004eb0:	00000097          	auipc	ra,0x0
    80004eb4:	db0080e7          	jalr	-592(ra) # 80004c60 <iunlock>
  iput(ip);
    80004eb8:	00048513          	mv	a0,s1
    80004ebc:	00000097          	auipc	ra,0x0
    80004ec0:	f00080e7          	jalr	-256(ra) # 80004dbc <iput>
}
    80004ec4:	01813083          	ld	ra,24(sp)
    80004ec8:	01013403          	ld	s0,16(sp)
    80004ecc:	00813483          	ld	s1,8(sp)
    80004ed0:	02010113          	addi	sp,sp,32
    80004ed4:	00008067          	ret

0000000080004ed8 <stati>:

// Copy stat information from inode.
// Caller must hold ip->lock.
void
stati(struct inode *ip, struct stat *st)
{
    80004ed8:	ff010113          	addi	sp,sp,-16
    80004edc:	00813423          	sd	s0,8(sp)
    80004ee0:	01010413          	addi	s0,sp,16
  st->dev = ip->dev;
    80004ee4:	00052783          	lw	a5,0(a0)
    80004ee8:	00f5a023          	sw	a5,0(a1)
  st->ino = ip->inum;
    80004eec:	00452783          	lw	a5,4(a0)
    80004ef0:	00f5a223          	sw	a5,4(a1)
  st->type = ip->type;
    80004ef4:	04451783          	lh	a5,68(a0)
    80004ef8:	00f59423          	sh	a5,8(a1)
  st->nlink = ip->nlink;
    80004efc:	04a51783          	lh	a5,74(a0)
    80004f00:	00f59523          	sh	a5,10(a1)
  st->size = ip->size;
    80004f04:	04c56783          	lwu	a5,76(a0)
    80004f08:	00f5b823          	sd	a5,16(a1)
}
    80004f0c:	00813403          	ld	s0,8(sp)
    80004f10:	01010113          	addi	sp,sp,16
    80004f14:	00008067          	ret

0000000080004f18 <readi>:
readi(struct inode *ip, int user_dst, uint64 dst, uint off, uint n)
{
  uint tot, m;
  struct buf *bp;

  if(off > ip->size || off + n < off)
    80004f18:	04c52783          	lw	a5,76(a0)
    80004f1c:	16d7e263          	bltu	a5,a3,80005080 <readi+0x168>
{
    80004f20:	f9010113          	addi	sp,sp,-112
    80004f24:	06113423          	sd	ra,104(sp)
    80004f28:	06813023          	sd	s0,96(sp)
    80004f2c:	04913c23          	sd	s1,88(sp)
    80004f30:	05213823          	sd	s2,80(sp)
    80004f34:	05313423          	sd	s3,72(sp)
    80004f38:	05413023          	sd	s4,64(sp)
    80004f3c:	03513c23          	sd	s5,56(sp)
    80004f40:	03613823          	sd	s6,48(sp)
    80004f44:	03713423          	sd	s7,40(sp)
    80004f48:	03813023          	sd	s8,32(sp)
    80004f4c:	01913c23          	sd	s9,24(sp)
    80004f50:	01a13823          	sd	s10,16(sp)
    80004f54:	01b13423          	sd	s11,8(sp)
    80004f58:	07010413          	addi	s0,sp,112
    80004f5c:	00050b93          	mv	s7,a0
    80004f60:	00058c13          	mv	s8,a1
    80004f64:	00060a93          	mv	s5,a2
    80004f68:	00068493          	mv	s1,a3
    80004f6c:	00070b13          	mv	s6,a4
  if(off > ip->size || off + n < off)
    80004f70:	00e6873b          	addw	a4,a3,a4
    return 0;
    80004f74:	00000513          	li	a0,0
  if(off > ip->size || off + n < off)
    80004f78:	0cd76263          	bltu	a4,a3,8000503c <readi+0x124>
  if(off + n > ip->size)
    80004f7c:	00e7f463          	bgeu	a5,a4,80004f84 <readi+0x6c>
    n = ip->size - off;
    80004f80:	40d78b3b          	subw	s6,a5,a3

  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    80004f84:	0e0b0a63          	beqz	s6,80005078 <readi+0x160>
    80004f88:	00000993          	li	s3,0
    bp = bread(ip->dev, bmap(ip, off/BSIZE));
    m = min(n - tot, BSIZE - off%BSIZE);
    80004f8c:	40000d13          	li	s10,1024
    if(either_copyout(user_dst, dst, bp->data + (off % BSIZE), m) == -1) {
    80004f90:	fff00c93          	li	s9,-1
    80004f94:	0480006f          	j	80004fdc <readi+0xc4>
    80004f98:	020a1d93          	slli	s11,s4,0x20
    80004f9c:	020ddd93          	srli	s11,s11,0x20
    80004fa0:	05890613          	addi	a2,s2,88
    80004fa4:	000d8693          	mv	a3,s11
    80004fa8:	00e60633          	add	a2,a2,a4
    80004fac:	000a8593          	mv	a1,s5
    80004fb0:	000c0513          	mv	a0,s8
    80004fb4:	ffffe097          	auipc	ra,0xffffe
    80004fb8:	2f0080e7          	jalr	752(ra) # 800032a4 <either_copyout>
    80004fbc:	07950663          	beq	a0,s9,80005028 <readi+0x110>
      brelse(bp);
      tot = -1;
      break;
    }
    brelse(bp);
    80004fc0:	00090513          	mv	a0,s2
    80004fc4:	fffff097          	auipc	ra,0xfffff
    80004fc8:	25c080e7          	jalr	604(ra) # 80004220 <brelse>
  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    80004fcc:	013a09bb          	addw	s3,s4,s3
    80004fd0:	009a04bb          	addw	s1,s4,s1
    80004fd4:	01ba8ab3          	add	s5,s5,s11
    80004fd8:	0769f063          	bgeu	s3,s6,80005038 <readi+0x120>
    bp = bread(ip->dev, bmap(ip, off/BSIZE));
    80004fdc:	000ba903          	lw	s2,0(s7)
    80004fe0:	00a4d59b          	srliw	a1,s1,0xa
    80004fe4:	000b8513          	mv	a0,s7
    80004fe8:	fffff097          	auipc	ra,0xfffff
    80004fec:	604080e7          	jalr	1540(ra) # 800045ec <bmap>
    80004ff0:	0005059b          	sext.w	a1,a0
    80004ff4:	00090513          	mv	a0,s2
    80004ff8:	fffff097          	auipc	ra,0xfffff
    80004ffc:	08c080e7          	jalr	140(ra) # 80004084 <bread>
    80005000:	00050913          	mv	s2,a0
    m = min(n - tot, BSIZE - off%BSIZE);
    80005004:	3ff4f713          	andi	a4,s1,1023
    80005008:	40ed07bb          	subw	a5,s10,a4
    8000500c:	413b06bb          	subw	a3,s6,s3
    80005010:	00078a13          	mv	s4,a5
    80005014:	0007879b          	sext.w	a5,a5
    80005018:	0006861b          	sext.w	a2,a3
    8000501c:	f6f67ee3          	bgeu	a2,a5,80004f98 <readi+0x80>
    80005020:	00068a13          	mv	s4,a3
    80005024:	f75ff06f          	j	80004f98 <readi+0x80>
      brelse(bp);
    80005028:	00090513          	mv	a0,s2
    8000502c:	fffff097          	auipc	ra,0xfffff
    80005030:	1f4080e7          	jalr	500(ra) # 80004220 <brelse>
      tot = -1;
    80005034:	fff00993          	li	s3,-1
  }
  return tot;
    80005038:	0009851b          	sext.w	a0,s3
}
    8000503c:	06813083          	ld	ra,104(sp)
    80005040:	06013403          	ld	s0,96(sp)
    80005044:	05813483          	ld	s1,88(sp)
    80005048:	05013903          	ld	s2,80(sp)
    8000504c:	04813983          	ld	s3,72(sp)
    80005050:	04013a03          	ld	s4,64(sp)
    80005054:	03813a83          	ld	s5,56(sp)
    80005058:	03013b03          	ld	s6,48(sp)
    8000505c:	02813b83          	ld	s7,40(sp)
    80005060:	02013c03          	ld	s8,32(sp)
    80005064:	01813c83          	ld	s9,24(sp)
    80005068:	01013d03          	ld	s10,16(sp)
    8000506c:	00813d83          	ld	s11,8(sp)
    80005070:	07010113          	addi	sp,sp,112
    80005074:	00008067          	ret
  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    80005078:	000b0993          	mv	s3,s6
    8000507c:	fbdff06f          	j	80005038 <readi+0x120>
    return 0;
    80005080:	00000513          	li	a0,0
}
    80005084:	00008067          	ret

0000000080005088 <writei>:
writei(struct inode *ip, int user_src, uint64 src, uint off, uint n)
{
  uint tot, m;
  struct buf *bp;

  if(off > ip->size || off + n < off)
    80005088:	04c52783          	lw	a5,76(a0)
    8000508c:	18d7e063          	bltu	a5,a3,8000520c <writei+0x184>
{
    80005090:	f9010113          	addi	sp,sp,-112
    80005094:	06113423          	sd	ra,104(sp)
    80005098:	06813023          	sd	s0,96(sp)
    8000509c:	04913c23          	sd	s1,88(sp)
    800050a0:	05213823          	sd	s2,80(sp)
    800050a4:	05313423          	sd	s3,72(sp)
    800050a8:	05413023          	sd	s4,64(sp)
    800050ac:	03513c23          	sd	s5,56(sp)
    800050b0:	03613823          	sd	s6,48(sp)
    800050b4:	03713423          	sd	s7,40(sp)
    800050b8:	03813023          	sd	s8,32(sp)
    800050bc:	01913c23          	sd	s9,24(sp)
    800050c0:	01a13823          	sd	s10,16(sp)
    800050c4:	01b13423          	sd	s11,8(sp)
    800050c8:	07010413          	addi	s0,sp,112
    800050cc:	00050b13          	mv	s6,a0
    800050d0:	00058c13          	mv	s8,a1
    800050d4:	00060a93          	mv	s5,a2
    800050d8:	00068913          	mv	s2,a3
    800050dc:	00070b93          	mv	s7,a4
  if(off > ip->size || off + n < off)
    800050e0:	00e687bb          	addw	a5,a3,a4
    800050e4:	12d7e863          	bltu	a5,a3,80005214 <writei+0x18c>
    return -1;
  if(off + n > MAXFILE*BSIZE)
    800050e8:	00043737          	lui	a4,0x43
    800050ec:	12f76863          	bltu	a4,a5,8000521c <writei+0x194>
    return -1;

  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    800050f0:	100b8a63          	beqz	s7,80005204 <writei+0x17c>
    800050f4:	00000a13          	li	s4,0
    bp = bread(ip->dev, bmap(ip, off/BSIZE));
    m = min(n - tot, BSIZE - off%BSIZE);
    800050f8:	40000d13          	li	s10,1024
    if(either_copyin(bp->data + (off % BSIZE), user_src, src, m) == -1) {
    800050fc:	fff00c93          	li	s9,-1
    80005100:	0540006f          	j	80005154 <writei+0xcc>
    80005104:	02099d93          	slli	s11,s3,0x20
    80005108:	020ddd93          	srli	s11,s11,0x20
    8000510c:	05848513          	addi	a0,s1,88
    80005110:	000d8693          	mv	a3,s11
    80005114:	000a8613          	mv	a2,s5
    80005118:	000c0593          	mv	a1,s8
    8000511c:	00e50533          	add	a0,a0,a4
    80005120:	ffffe097          	auipc	ra,0xffffe
    80005124:	214080e7          	jalr	532(ra) # 80003334 <either_copyin>
    80005128:	07950c63          	beq	a0,s9,800051a0 <writei+0x118>
      brelse(bp);
      break;
    }
    log_write(bp);
    8000512c:	00048513          	mv	a0,s1
    80005130:	00001097          	auipc	ra,0x1
    80005134:	a84080e7          	jalr	-1404(ra) # 80005bb4 <log_write>
    brelse(bp);
    80005138:	00048513          	mv	a0,s1
    8000513c:	fffff097          	auipc	ra,0xfffff
    80005140:	0e4080e7          	jalr	228(ra) # 80004220 <brelse>
  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    80005144:	01498a3b          	addw	s4,s3,s4
    80005148:	0129893b          	addw	s2,s3,s2
    8000514c:	01ba8ab3          	add	s5,s5,s11
    80005150:	057a7e63          	bgeu	s4,s7,800051ac <writei+0x124>
    bp = bread(ip->dev, bmap(ip, off/BSIZE));
    80005154:	000b2483          	lw	s1,0(s6)
    80005158:	00a9559b          	srliw	a1,s2,0xa
    8000515c:	000b0513          	mv	a0,s6
    80005160:	fffff097          	auipc	ra,0xfffff
    80005164:	48c080e7          	jalr	1164(ra) # 800045ec <bmap>
    80005168:	0005059b          	sext.w	a1,a0
    8000516c:	00048513          	mv	a0,s1
    80005170:	fffff097          	auipc	ra,0xfffff
    80005174:	f14080e7          	jalr	-236(ra) # 80004084 <bread>
    80005178:	00050493          	mv	s1,a0
    m = min(n - tot, BSIZE - off%BSIZE);
    8000517c:	3ff97713          	andi	a4,s2,1023
    80005180:	40ed07bb          	subw	a5,s10,a4
    80005184:	414b86bb          	subw	a3,s7,s4
    80005188:	00078993          	mv	s3,a5
    8000518c:	0007879b          	sext.w	a5,a5
    80005190:	0006861b          	sext.w	a2,a3
    80005194:	f6f678e3          	bgeu	a2,a5,80005104 <writei+0x7c>
    80005198:	00068993          	mv	s3,a3
    8000519c:	f69ff06f          	j	80005104 <writei+0x7c>
      brelse(bp);
    800051a0:	00048513          	mv	a0,s1
    800051a4:	fffff097          	auipc	ra,0xfffff
    800051a8:	07c080e7          	jalr	124(ra) # 80004220 <brelse>
  }

  if(off > ip->size)
    800051ac:	04cb2783          	lw	a5,76(s6)
    800051b0:	0127f463          	bgeu	a5,s2,800051b8 <writei+0x130>
    ip->size = off;
    800051b4:	052b2623          	sw	s2,76(s6)

  // write the i-node back to disk even if the size didn't change
  // because the loop above might have called bmap() and added a new
  // block to ip->addrs[].
  iupdate(ip);
    800051b8:	000b0513          	mv	a0,s6
    800051bc:	00000097          	auipc	ra,0x0
    800051c0:	884080e7          	jalr	-1916(ra) # 80004a40 <iupdate>

  return tot;
    800051c4:	000a051b          	sext.w	a0,s4
}
    800051c8:	06813083          	ld	ra,104(sp)
    800051cc:	06013403          	ld	s0,96(sp)
    800051d0:	05813483          	ld	s1,88(sp)
    800051d4:	05013903          	ld	s2,80(sp)
    800051d8:	04813983          	ld	s3,72(sp)
    800051dc:	04013a03          	ld	s4,64(sp)
    800051e0:	03813a83          	ld	s5,56(sp)
    800051e4:	03013b03          	ld	s6,48(sp)
    800051e8:	02813b83          	ld	s7,40(sp)
    800051ec:	02013c03          	ld	s8,32(sp)
    800051f0:	01813c83          	ld	s9,24(sp)
    800051f4:	01013d03          	ld	s10,16(sp)
    800051f8:	00813d83          	ld	s11,8(sp)
    800051fc:	07010113          	addi	sp,sp,112
    80005200:	00008067          	ret
  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    80005204:	000b8a13          	mv	s4,s7
    80005208:	fb1ff06f          	j	800051b8 <writei+0x130>
    return -1;
    8000520c:	fff00513          	li	a0,-1
}
    80005210:	00008067          	ret
    return -1;
    80005214:	fff00513          	li	a0,-1
    80005218:	fb1ff06f          	j	800051c8 <writei+0x140>
    return -1;
    8000521c:	fff00513          	li	a0,-1
    80005220:	fa9ff06f          	j	800051c8 <writei+0x140>

0000000080005224 <namecmp>:

// Directories

int
namecmp(const char *s, const char *t)
{
    80005224:	ff010113          	addi	sp,sp,-16
    80005228:	00113423          	sd	ra,8(sp)
    8000522c:	00813023          	sd	s0,0(sp)
    80005230:	01010413          	addi	s0,sp,16
  return strncmp(s, t, DIRSIZ);
    80005234:	00e00613          	li	a2,14
    80005238:	ffffc097          	auipc	ra,0xffffc
    8000523c:	02c080e7          	jalr	44(ra) # 80001264 <strncmp>
}
    80005240:	00813083          	ld	ra,8(sp)
    80005244:	00013403          	ld	s0,0(sp)
    80005248:	01010113          	addi	sp,sp,16
    8000524c:	00008067          	ret

0000000080005250 <dirlookup>:

// Look for a directory entry in a directory.
// If found, set *poff to byte offset of entry.
struct inode*
dirlookup(struct inode *dp, char *name, uint *poff)
{
    80005250:	fc010113          	addi	sp,sp,-64
    80005254:	02113c23          	sd	ra,56(sp)
    80005258:	02813823          	sd	s0,48(sp)
    8000525c:	02913423          	sd	s1,40(sp)
    80005260:	03213023          	sd	s2,32(sp)
    80005264:	01313c23          	sd	s3,24(sp)
    80005268:	01413823          	sd	s4,16(sp)
    8000526c:	04010413          	addi	s0,sp,64
  uint off, inum;
  struct dirent de;

  if(dp->type != T_DIR)
    80005270:	04451703          	lh	a4,68(a0)
    80005274:	00100793          	li	a5,1
    80005278:	02f71263          	bne	a4,a5,8000529c <dirlookup+0x4c>
    8000527c:	00050913          	mv	s2,a0
    80005280:	00058993          	mv	s3,a1
    80005284:	00060a13          	mv	s4,a2
    panic("dirlookup not DIR");

  for(off = 0; off < dp->size; off += sizeof(de)){
    80005288:	04c52783          	lw	a5,76(a0)
    8000528c:	00000493          	li	s1,0
      inum = de.inum;
      return iget(dp->dev, inum);
    }
  }

  return 0;
    80005290:	00000513          	li	a0,0
  for(off = 0; off < dp->size; off += sizeof(de)){
    80005294:	02079a63          	bnez	a5,800052c8 <dirlookup+0x78>
    80005298:	0900006f          	j	80005328 <dirlookup+0xd8>
    panic("dirlookup not DIR");
    8000529c:	00005517          	auipc	a0,0x5
    800052a0:	34c50513          	addi	a0,a0,844 # 8000a5e8 <syscalls+0x1a0>
    800052a4:	ffffb097          	auipc	ra,0xffffb
    800052a8:	42c080e7          	jalr	1068(ra) # 800006d0 <panic>
      panic("dirlookup read");
    800052ac:	00005517          	auipc	a0,0x5
    800052b0:	35450513          	addi	a0,a0,852 # 8000a600 <syscalls+0x1b8>
    800052b4:	ffffb097          	auipc	ra,0xffffb
    800052b8:	41c080e7          	jalr	1052(ra) # 800006d0 <panic>
  for(off = 0; off < dp->size; off += sizeof(de)){
    800052bc:	0104849b          	addiw	s1,s1,16
    800052c0:	04c92783          	lw	a5,76(s2)
    800052c4:	06f4f063          	bgeu	s1,a5,80005324 <dirlookup+0xd4>
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    800052c8:	01000713          	li	a4,16
    800052cc:	00048693          	mv	a3,s1
    800052d0:	fc040613          	addi	a2,s0,-64
    800052d4:	00000593          	li	a1,0
    800052d8:	00090513          	mv	a0,s2
    800052dc:	00000097          	auipc	ra,0x0
    800052e0:	c3c080e7          	jalr	-964(ra) # 80004f18 <readi>
    800052e4:	01000793          	li	a5,16
    800052e8:	fcf512e3          	bne	a0,a5,800052ac <dirlookup+0x5c>
    if(de.inum == 0)
    800052ec:	fc045783          	lhu	a5,-64(s0)
    800052f0:	fc0786e3          	beqz	a5,800052bc <dirlookup+0x6c>
    if(namecmp(name, de.name) == 0){
    800052f4:	fc240593          	addi	a1,s0,-62
    800052f8:	00098513          	mv	a0,s3
    800052fc:	00000097          	auipc	ra,0x0
    80005300:	f28080e7          	jalr	-216(ra) # 80005224 <namecmp>
    80005304:	fa051ce3          	bnez	a0,800052bc <dirlookup+0x6c>
      if(poff)
    80005308:	000a0463          	beqz	s4,80005310 <dirlookup+0xc0>
        *poff = off;
    8000530c:	009a2023          	sw	s1,0(s4)
      return iget(dp->dev, inum);
    80005310:	fc045583          	lhu	a1,-64(s0)
    80005314:	00092503          	lw	a0,0(s2)
    80005318:	fffff097          	auipc	ra,0xfffff
    8000531c:	3e8080e7          	jalr	1000(ra) # 80004700 <iget>
    80005320:	0080006f          	j	80005328 <dirlookup+0xd8>
  return 0;
    80005324:	00000513          	li	a0,0
}
    80005328:	03813083          	ld	ra,56(sp)
    8000532c:	03013403          	ld	s0,48(sp)
    80005330:	02813483          	ld	s1,40(sp)
    80005334:	02013903          	ld	s2,32(sp)
    80005338:	01813983          	ld	s3,24(sp)
    8000533c:	01013a03          	ld	s4,16(sp)
    80005340:	04010113          	addi	sp,sp,64
    80005344:	00008067          	ret

0000000080005348 <namex>:
// If parent != 0, return the inode for the parent and copy the final
// path element into name, which must have room for DIRSIZ bytes.
// Must be called inside a transaction since it calls iput().
static struct inode*
namex(char *path, int nameiparent, char *name)
{
    80005348:	fa010113          	addi	sp,sp,-96
    8000534c:	04113c23          	sd	ra,88(sp)
    80005350:	04813823          	sd	s0,80(sp)
    80005354:	04913423          	sd	s1,72(sp)
    80005358:	05213023          	sd	s2,64(sp)
    8000535c:	03313c23          	sd	s3,56(sp)
    80005360:	03413823          	sd	s4,48(sp)
    80005364:	03513423          	sd	s5,40(sp)
    80005368:	03613023          	sd	s6,32(sp)
    8000536c:	01713c23          	sd	s7,24(sp)
    80005370:	01813823          	sd	s8,16(sp)
    80005374:	01913423          	sd	s9,8(sp)
    80005378:	01a13023          	sd	s10,0(sp)
    8000537c:	06010413          	addi	s0,sp,96
    80005380:	00050493          	mv	s1,a0
    80005384:	00058b13          	mv	s6,a1
    80005388:	00060a93          	mv	s5,a2
  struct inode *ip, *next;

  if(*path == '/')
    8000538c:	00054703          	lbu	a4,0(a0)
    80005390:	02f00793          	li	a5,47
    80005394:	02f70863          	beq	a4,a5,800053c4 <namex+0x7c>
    ip = iget(ROOTDEV, ROOTINO);
  else
    ip = idup(myproc()->cwd);
    80005398:	ffffd097          	auipc	ra,0xffffd
    8000539c:	0a4080e7          	jalr	164(ra) # 8000243c <myproc>
    800053a0:	15053503          	ld	a0,336(a0)
    800053a4:	fffff097          	auipc	ra,0xfffff
    800053a8:	75c080e7          	jalr	1884(ra) # 80004b00 <idup>
    800053ac:	00050a13          	mv	s4,a0
  while(*path == '/')
    800053b0:	02f00913          	li	s2,47
  if(len >= DIRSIZ)
    800053b4:	00d00c93          	li	s9,13
  len = path - s;
    800053b8:	00000b93          	li	s7,0

  while((path = skipelem(path, name)) != 0){
    ilock(ip);
    if(ip->type != T_DIR){
    800053bc:	00100c13          	li	s8,1
    800053c0:	1100006f          	j	800054d0 <namex+0x188>
    ip = iget(ROOTDEV, ROOTINO);
    800053c4:	00100593          	li	a1,1
    800053c8:	00100513          	li	a0,1
    800053cc:	fffff097          	auipc	ra,0xfffff
    800053d0:	334080e7          	jalr	820(ra) # 80004700 <iget>
    800053d4:	00050a13          	mv	s4,a0
    800053d8:	fd9ff06f          	j	800053b0 <namex+0x68>
      iunlockput(ip);
    800053dc:	000a0513          	mv	a0,s4
    800053e0:	00000097          	auipc	ra,0x0
    800053e4:	ab8080e7          	jalr	-1352(ra) # 80004e98 <iunlockput>
      return 0;
    800053e8:	00000a13          	li	s4,0
  if(nameiparent){
    iput(ip);
    return 0;
  }
  return ip;
}
    800053ec:	000a0513          	mv	a0,s4
    800053f0:	05813083          	ld	ra,88(sp)
    800053f4:	05013403          	ld	s0,80(sp)
    800053f8:	04813483          	ld	s1,72(sp)
    800053fc:	04013903          	ld	s2,64(sp)
    80005400:	03813983          	ld	s3,56(sp)
    80005404:	03013a03          	ld	s4,48(sp)
    80005408:	02813a83          	ld	s5,40(sp)
    8000540c:	02013b03          	ld	s6,32(sp)
    80005410:	01813b83          	ld	s7,24(sp)
    80005414:	01013c03          	ld	s8,16(sp)
    80005418:	00813c83          	ld	s9,8(sp)
    8000541c:	00013d03          	ld	s10,0(sp)
    80005420:	06010113          	addi	sp,sp,96
    80005424:	00008067          	ret
      iunlock(ip);
    80005428:	000a0513          	mv	a0,s4
    8000542c:	00000097          	auipc	ra,0x0
    80005430:	834080e7          	jalr	-1996(ra) # 80004c60 <iunlock>
      return ip;
    80005434:	fb9ff06f          	j	800053ec <namex+0xa4>
      iunlockput(ip);
    80005438:	000a0513          	mv	a0,s4
    8000543c:	00000097          	auipc	ra,0x0
    80005440:	a5c080e7          	jalr	-1444(ra) # 80004e98 <iunlockput>
      return 0;
    80005444:	00098a13          	mv	s4,s3
    80005448:	fa5ff06f          	j	800053ec <namex+0xa4>
  len = path - s;
    8000544c:	40998633          	sub	a2,s3,s1
    80005450:	00060d1b          	sext.w	s10,a2
  if(len >= DIRSIZ)
    80005454:	0bacde63          	bge	s9,s10,80005510 <namex+0x1c8>
    memmove(name, s, DIRSIZ);
    80005458:	00e00613          	li	a2,14
    8000545c:	00048593          	mv	a1,s1
    80005460:	000a8513          	mv	a0,s5
    80005464:	ffffc097          	auipc	ra,0xffffc
    80005468:	d54080e7          	jalr	-684(ra) # 800011b8 <memmove>
    8000546c:	00098493          	mv	s1,s3
  while(*path == '/')
    80005470:	0004c783          	lbu	a5,0(s1)
    80005474:	01279863          	bne	a5,s2,80005484 <namex+0x13c>
    path++;
    80005478:	00148493          	addi	s1,s1,1
  while(*path == '/')
    8000547c:	0004c783          	lbu	a5,0(s1)
    80005480:	ff278ce3          	beq	a5,s2,80005478 <namex+0x130>
    ilock(ip);
    80005484:	000a0513          	mv	a0,s4
    80005488:	fffff097          	auipc	ra,0xfffff
    8000548c:	6d4080e7          	jalr	1748(ra) # 80004b5c <ilock>
    if(ip->type != T_DIR){
    80005490:	044a1783          	lh	a5,68(s4)
    80005494:	f58794e3          	bne	a5,s8,800053dc <namex+0x94>
    if(nameiparent && *path == '\0'){
    80005498:	000b0663          	beqz	s6,800054a4 <namex+0x15c>
    8000549c:	0004c783          	lbu	a5,0(s1)
    800054a0:	f80784e3          	beqz	a5,80005428 <namex+0xe0>
    if((next = dirlookup(ip, name, 0)) == 0){
    800054a4:	000b8613          	mv	a2,s7
    800054a8:	000a8593          	mv	a1,s5
    800054ac:	000a0513          	mv	a0,s4
    800054b0:	00000097          	auipc	ra,0x0
    800054b4:	da0080e7          	jalr	-608(ra) # 80005250 <dirlookup>
    800054b8:	00050993          	mv	s3,a0
    800054bc:	f6050ee3          	beqz	a0,80005438 <namex+0xf0>
    iunlockput(ip);
    800054c0:	000a0513          	mv	a0,s4
    800054c4:	00000097          	auipc	ra,0x0
    800054c8:	9d4080e7          	jalr	-1580(ra) # 80004e98 <iunlockput>
    ip = next;
    800054cc:	00098a13          	mv	s4,s3
  while(*path == '/')
    800054d0:	0004c783          	lbu	a5,0(s1)
    800054d4:	01279863          	bne	a5,s2,800054e4 <namex+0x19c>
    path++;
    800054d8:	00148493          	addi	s1,s1,1
  while(*path == '/')
    800054dc:	0004c783          	lbu	a5,0(s1)
    800054e0:	ff278ce3          	beq	a5,s2,800054d8 <namex+0x190>
  if(*path == 0)
    800054e4:	04078863          	beqz	a5,80005534 <namex+0x1ec>
  while(*path != '/' && *path != 0)
    800054e8:	0004c783          	lbu	a5,0(s1)
    800054ec:	00048993          	mv	s3,s1
  len = path - s;
    800054f0:	000b8d13          	mv	s10,s7
    800054f4:	000b8613          	mv	a2,s7
  while(*path != '/' && *path != 0)
    800054f8:	01278c63          	beq	a5,s2,80005510 <namex+0x1c8>
    800054fc:	f40788e3          	beqz	a5,8000544c <namex+0x104>
    path++;
    80005500:	00198993          	addi	s3,s3,1
  while(*path != '/' && *path != 0)
    80005504:	0009c783          	lbu	a5,0(s3)
    80005508:	ff279ae3          	bne	a5,s2,800054fc <namex+0x1b4>
    8000550c:	f41ff06f          	j	8000544c <namex+0x104>
    memmove(name, s, len);
    80005510:	0006061b          	sext.w	a2,a2
    80005514:	00048593          	mv	a1,s1
    80005518:	000a8513          	mv	a0,s5
    8000551c:	ffffc097          	auipc	ra,0xffffc
    80005520:	c9c080e7          	jalr	-868(ra) # 800011b8 <memmove>
    name[len] = 0;
    80005524:	01aa8d33          	add	s10,s5,s10
    80005528:	000d0023          	sb	zero,0(s10)
    8000552c:	00098493          	mv	s1,s3
    80005530:	f41ff06f          	j	80005470 <namex+0x128>
  if(nameiparent){
    80005534:	ea0b0ce3          	beqz	s6,800053ec <namex+0xa4>
    iput(ip);
    80005538:	000a0513          	mv	a0,s4
    8000553c:	00000097          	auipc	ra,0x0
    80005540:	880080e7          	jalr	-1920(ra) # 80004dbc <iput>
    return 0;
    80005544:	00000a13          	li	s4,0
    80005548:	ea5ff06f          	j	800053ec <namex+0xa4>

000000008000554c <dirlink>:
{
    8000554c:	fc010113          	addi	sp,sp,-64
    80005550:	02113c23          	sd	ra,56(sp)
    80005554:	02813823          	sd	s0,48(sp)
    80005558:	02913423          	sd	s1,40(sp)
    8000555c:	03213023          	sd	s2,32(sp)
    80005560:	01313c23          	sd	s3,24(sp)
    80005564:	01413823          	sd	s4,16(sp)
    80005568:	04010413          	addi	s0,sp,64
    8000556c:	00050913          	mv	s2,a0
    80005570:	00058a13          	mv	s4,a1
    80005574:	00060993          	mv	s3,a2
  if((ip = dirlookup(dp, name, 0)) != 0){
    80005578:	00000613          	li	a2,0
    8000557c:	00000097          	auipc	ra,0x0
    80005580:	cd4080e7          	jalr	-812(ra) # 80005250 <dirlookup>
    80005584:	0a051663          	bnez	a0,80005630 <dirlink+0xe4>
  for(off = 0; off < dp->size; off += sizeof(de)){
    80005588:	04c92483          	lw	s1,76(s2)
    8000558c:	04048063          	beqz	s1,800055cc <dirlink+0x80>
    80005590:	00000493          	li	s1,0
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80005594:	01000713          	li	a4,16
    80005598:	00048693          	mv	a3,s1
    8000559c:	fc040613          	addi	a2,s0,-64
    800055a0:	00000593          	li	a1,0
    800055a4:	00090513          	mv	a0,s2
    800055a8:	00000097          	auipc	ra,0x0
    800055ac:	970080e7          	jalr	-1680(ra) # 80004f18 <readi>
    800055b0:	01000793          	li	a5,16
    800055b4:	08f51663          	bne	a0,a5,80005640 <dirlink+0xf4>
    if(de.inum == 0)
    800055b8:	fc045783          	lhu	a5,-64(s0)
    800055bc:	00078863          	beqz	a5,800055cc <dirlink+0x80>
  for(off = 0; off < dp->size; off += sizeof(de)){
    800055c0:	0104849b          	addiw	s1,s1,16
    800055c4:	04c92783          	lw	a5,76(s2)
    800055c8:	fcf4e6e3          	bltu	s1,a5,80005594 <dirlink+0x48>
  strncpy(de.name, name, DIRSIZ);
    800055cc:	00e00613          	li	a2,14
    800055d0:	000a0593          	mv	a1,s4
    800055d4:	fc240513          	addi	a0,s0,-62
    800055d8:	ffffc097          	auipc	ra,0xffffc
    800055dc:	cf0080e7          	jalr	-784(ra) # 800012c8 <strncpy>
  de.inum = inum;
    800055e0:	fd341023          	sh	s3,-64(s0)
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    800055e4:	01000713          	li	a4,16
    800055e8:	00048693          	mv	a3,s1
    800055ec:	fc040613          	addi	a2,s0,-64
    800055f0:	00000593          	li	a1,0
    800055f4:	00090513          	mv	a0,s2
    800055f8:	00000097          	auipc	ra,0x0
    800055fc:	a90080e7          	jalr	-1392(ra) # 80005088 <writei>
    80005600:	00050713          	mv	a4,a0
    80005604:	01000793          	li	a5,16
  return 0;
    80005608:	00000513          	li	a0,0
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    8000560c:	04f71263          	bne	a4,a5,80005650 <dirlink+0x104>
}
    80005610:	03813083          	ld	ra,56(sp)
    80005614:	03013403          	ld	s0,48(sp)
    80005618:	02813483          	ld	s1,40(sp)
    8000561c:	02013903          	ld	s2,32(sp)
    80005620:	01813983          	ld	s3,24(sp)
    80005624:	01013a03          	ld	s4,16(sp)
    80005628:	04010113          	addi	sp,sp,64
    8000562c:	00008067          	ret
    iput(ip);
    80005630:	fffff097          	auipc	ra,0xfffff
    80005634:	78c080e7          	jalr	1932(ra) # 80004dbc <iput>
    return -1;
    80005638:	fff00513          	li	a0,-1
    8000563c:	fd5ff06f          	j	80005610 <dirlink+0xc4>
      panic("dirlink read");
    80005640:	00005517          	auipc	a0,0x5
    80005644:	fd050513          	addi	a0,a0,-48 # 8000a610 <syscalls+0x1c8>
    80005648:	ffffb097          	auipc	ra,0xffffb
    8000564c:	088080e7          	jalr	136(ra) # 800006d0 <panic>
    panic("dirlink");
    80005650:	00005517          	auipc	a0,0x5
    80005654:	0d050513          	addi	a0,a0,208 # 8000a720 <syscalls+0x2d8>
    80005658:	ffffb097          	auipc	ra,0xffffb
    8000565c:	078080e7          	jalr	120(ra) # 800006d0 <panic>

0000000080005660 <namei>:

struct inode*
namei(char *path)
{
    80005660:	fe010113          	addi	sp,sp,-32
    80005664:	00113c23          	sd	ra,24(sp)
    80005668:	00813823          	sd	s0,16(sp)
    8000566c:	02010413          	addi	s0,sp,32
  char name[DIRSIZ];
  return namex(path, 0, name);
    80005670:	fe040613          	addi	a2,s0,-32
    80005674:	00000593          	li	a1,0
    80005678:	00000097          	auipc	ra,0x0
    8000567c:	cd0080e7          	jalr	-816(ra) # 80005348 <namex>
}
    80005680:	01813083          	ld	ra,24(sp)
    80005684:	01013403          	ld	s0,16(sp)
    80005688:	02010113          	addi	sp,sp,32
    8000568c:	00008067          	ret

0000000080005690 <nameiparent>:

struct inode*
nameiparent(char *path, char *name)
{
    80005690:	ff010113          	addi	sp,sp,-16
    80005694:	00113423          	sd	ra,8(sp)
    80005698:	00813023          	sd	s0,0(sp)
    8000569c:	01010413          	addi	s0,sp,16
    800056a0:	00058613          	mv	a2,a1
  return namex(path, 1, name);
    800056a4:	00100593          	li	a1,1
    800056a8:	00000097          	auipc	ra,0x0
    800056ac:	ca0080e7          	jalr	-864(ra) # 80005348 <namex>
}
    800056b0:	00813083          	ld	ra,8(sp)
    800056b4:	00013403          	ld	s0,0(sp)
    800056b8:	01010113          	addi	sp,sp,16
    800056bc:	00008067          	ret

00000000800056c0 <write_head>:
// Write in-memory log header to disk.
// This is the true point at which the
// current transaction commits.
static void
write_head(void)
{
    800056c0:	fe010113          	addi	sp,sp,-32
    800056c4:	00113c23          	sd	ra,24(sp)
    800056c8:	00813823          	sd	s0,16(sp)
    800056cc:	00913423          	sd	s1,8(sp)
    800056d0:	01213023          	sd	s2,0(sp)
    800056d4:	02010413          	addi	s0,sp,32
  struct buf *buf = bread(log.dev, log.start);
    800056d8:	0001e917          	auipc	s2,0x1e
    800056dc:	b9890913          	addi	s2,s2,-1128 # 80023270 <log>
    800056e0:	01892583          	lw	a1,24(s2)
    800056e4:	02892503          	lw	a0,40(s2)
    800056e8:	fffff097          	auipc	ra,0xfffff
    800056ec:	99c080e7          	jalr	-1636(ra) # 80004084 <bread>
    800056f0:	00050493          	mv	s1,a0
  struct logheader *hb = (struct logheader *) (buf->data);
  int i;
  hb->n = log.lh.n;
    800056f4:	02c92683          	lw	a3,44(s2)
    800056f8:	04d52c23          	sw	a3,88(a0)
  for (i = 0; i < log.lh.n; i++) {
    800056fc:	02d05e63          	blez	a3,80005738 <write_head+0x78>
    80005700:	0001e797          	auipc	a5,0x1e
    80005704:	ba078793          	addi	a5,a5,-1120 # 800232a0 <log+0x30>
    80005708:	05c50713          	addi	a4,a0,92
    8000570c:	fff6869b          	addiw	a3,a3,-1
    80005710:	02069613          	slli	a2,a3,0x20
    80005714:	01e65693          	srli	a3,a2,0x1e
    80005718:	0001e617          	auipc	a2,0x1e
    8000571c:	b8c60613          	addi	a2,a2,-1140 # 800232a4 <log+0x34>
    80005720:	00c686b3          	add	a3,a3,a2
    hb->block[i] = log.lh.block[i];
    80005724:	0007a603          	lw	a2,0(a5)
    80005728:	00c72023          	sw	a2,0(a4) # 43000 <_entry-0x7ffbd000>
  for (i = 0; i < log.lh.n; i++) {
    8000572c:	00478793          	addi	a5,a5,4
    80005730:	00470713          	addi	a4,a4,4
    80005734:	fed798e3          	bne	a5,a3,80005724 <write_head+0x64>
  }
  bwrite(buf);
    80005738:	00048513          	mv	a0,s1
    8000573c:	fffff097          	auipc	ra,0xfffff
    80005740:	a88080e7          	jalr	-1400(ra) # 800041c4 <bwrite>
  brelse(buf);
    80005744:	00048513          	mv	a0,s1
    80005748:	fffff097          	auipc	ra,0xfffff
    8000574c:	ad8080e7          	jalr	-1320(ra) # 80004220 <brelse>
}
    80005750:	01813083          	ld	ra,24(sp)
    80005754:	01013403          	ld	s0,16(sp)
    80005758:	00813483          	ld	s1,8(sp)
    8000575c:	00013903          	ld	s2,0(sp)
    80005760:	02010113          	addi	sp,sp,32
    80005764:	00008067          	ret

0000000080005768 <install_trans>:
  for (tail = 0; tail < log.lh.n; tail++) {
    80005768:	0001e797          	auipc	a5,0x1e
    8000576c:	b347a783          	lw	a5,-1228(a5) # 8002329c <log+0x2c>
    80005770:	0ef05e63          	blez	a5,8000586c <install_trans+0x104>
{
    80005774:	fc010113          	addi	sp,sp,-64
    80005778:	02113c23          	sd	ra,56(sp)
    8000577c:	02813823          	sd	s0,48(sp)
    80005780:	02913423          	sd	s1,40(sp)
    80005784:	03213023          	sd	s2,32(sp)
    80005788:	01313c23          	sd	s3,24(sp)
    8000578c:	01413823          	sd	s4,16(sp)
    80005790:	01513423          	sd	s5,8(sp)
    80005794:	01613023          	sd	s6,0(sp)
    80005798:	04010413          	addi	s0,sp,64
    8000579c:	00050b13          	mv	s6,a0
    800057a0:	0001ea97          	auipc	s5,0x1e
    800057a4:	b00a8a93          	addi	s5,s5,-1280 # 800232a0 <log+0x30>
  for (tail = 0; tail < log.lh.n; tail++) {
    800057a8:	00000a13          	li	s4,0
    struct buf *lbuf = bread(log.dev, log.start+tail+1); // read log block
    800057ac:	0001e997          	auipc	s3,0x1e
    800057b0:	ac498993          	addi	s3,s3,-1340 # 80023270 <log>
    800057b4:	02c0006f          	j	800057e0 <install_trans+0x78>
    brelse(lbuf);
    800057b8:	00090513          	mv	a0,s2
    800057bc:	fffff097          	auipc	ra,0xfffff
    800057c0:	a64080e7          	jalr	-1436(ra) # 80004220 <brelse>
    brelse(dbuf);
    800057c4:	00048513          	mv	a0,s1
    800057c8:	fffff097          	auipc	ra,0xfffff
    800057cc:	a58080e7          	jalr	-1448(ra) # 80004220 <brelse>
  for (tail = 0; tail < log.lh.n; tail++) {
    800057d0:	001a0a1b          	addiw	s4,s4,1
    800057d4:	004a8a93          	addi	s5,s5,4
    800057d8:	02c9a783          	lw	a5,44(s3)
    800057dc:	06fa5463          	bge	s4,a5,80005844 <install_trans+0xdc>
    struct buf *lbuf = bread(log.dev, log.start+tail+1); // read log block
    800057e0:	0189a583          	lw	a1,24(s3)
    800057e4:	014585bb          	addw	a1,a1,s4
    800057e8:	0015859b          	addiw	a1,a1,1
    800057ec:	0289a503          	lw	a0,40(s3)
    800057f0:	fffff097          	auipc	ra,0xfffff
    800057f4:	894080e7          	jalr	-1900(ra) # 80004084 <bread>
    800057f8:	00050913          	mv	s2,a0
    struct buf *dbuf = bread(log.dev, log.lh.block[tail]); // read dst
    800057fc:	000aa583          	lw	a1,0(s5)
    80005800:	0289a503          	lw	a0,40(s3)
    80005804:	fffff097          	auipc	ra,0xfffff
    80005808:	880080e7          	jalr	-1920(ra) # 80004084 <bread>
    8000580c:	00050493          	mv	s1,a0
    memmove(dbuf->data, lbuf->data, BSIZE);  // copy block to dst
    80005810:	40000613          	li	a2,1024
    80005814:	05890593          	addi	a1,s2,88
    80005818:	05850513          	addi	a0,a0,88
    8000581c:	ffffc097          	auipc	ra,0xffffc
    80005820:	99c080e7          	jalr	-1636(ra) # 800011b8 <memmove>
    bwrite(dbuf);  // write dst to disk
    80005824:	00048513          	mv	a0,s1
    80005828:	fffff097          	auipc	ra,0xfffff
    8000582c:	99c080e7          	jalr	-1636(ra) # 800041c4 <bwrite>
    if(recovering == 0)
    80005830:	f80b14e3          	bnez	s6,800057b8 <install_trans+0x50>
      bunpin(dbuf);
    80005834:	00048513          	mv	a0,s1
    80005838:	fffff097          	auipc	ra,0xfffff
    8000583c:	b18080e7          	jalr	-1256(ra) # 80004350 <bunpin>
    80005840:	f79ff06f          	j	800057b8 <install_trans+0x50>
}
    80005844:	03813083          	ld	ra,56(sp)
    80005848:	03013403          	ld	s0,48(sp)
    8000584c:	02813483          	ld	s1,40(sp)
    80005850:	02013903          	ld	s2,32(sp)
    80005854:	01813983          	ld	s3,24(sp)
    80005858:	01013a03          	ld	s4,16(sp)
    8000585c:	00813a83          	ld	s5,8(sp)
    80005860:	00013b03          	ld	s6,0(sp)
    80005864:	04010113          	addi	sp,sp,64
    80005868:	00008067          	ret
    8000586c:	00008067          	ret

0000000080005870 <initlog>:
{
    80005870:	fd010113          	addi	sp,sp,-48
    80005874:	02113423          	sd	ra,40(sp)
    80005878:	02813023          	sd	s0,32(sp)
    8000587c:	00913c23          	sd	s1,24(sp)
    80005880:	01213823          	sd	s2,16(sp)
    80005884:	01313423          	sd	s3,8(sp)
    80005888:	03010413          	addi	s0,sp,48
    8000588c:	00050913          	mv	s2,a0
    80005890:	00058993          	mv	s3,a1
  initlock(&log.lock, "log");
    80005894:	0001e497          	auipc	s1,0x1e
    80005898:	9dc48493          	addi	s1,s1,-1572 # 80023270 <log>
    8000589c:	00005597          	auipc	a1,0x5
    800058a0:	d8458593          	addi	a1,a1,-636 # 8000a620 <syscalls+0x1d8>
    800058a4:	00048513          	mv	a0,s1
    800058a8:	ffffb097          	auipc	ra,0xffffb
    800058ac:	640080e7          	jalr	1600(ra) # 80000ee8 <initlock>
  log.start = sb->logstart;
    800058b0:	0149a583          	lw	a1,20(s3)
    800058b4:	00b4ac23          	sw	a1,24(s1)
  log.size = sb->nlog;
    800058b8:	0109a783          	lw	a5,16(s3)
    800058bc:	00f4ae23          	sw	a5,28(s1)
  log.dev = dev;
    800058c0:	0324a423          	sw	s2,40(s1)
  struct buf *buf = bread(log.dev, log.start);
    800058c4:	00090513          	mv	a0,s2
    800058c8:	ffffe097          	auipc	ra,0xffffe
    800058cc:	7bc080e7          	jalr	1980(ra) # 80004084 <bread>
  log.lh.n = lh->n;
    800058d0:	05852683          	lw	a3,88(a0)
    800058d4:	02d4a623          	sw	a3,44(s1)
  for (i = 0; i < log.lh.n; i++) {
    800058d8:	02d05c63          	blez	a3,80005910 <initlog+0xa0>
    800058dc:	05c50793          	addi	a5,a0,92
    800058e0:	0001e717          	auipc	a4,0x1e
    800058e4:	9c070713          	addi	a4,a4,-1600 # 800232a0 <log+0x30>
    800058e8:	fff6869b          	addiw	a3,a3,-1
    800058ec:	02069613          	slli	a2,a3,0x20
    800058f0:	01e65693          	srli	a3,a2,0x1e
    800058f4:	06050613          	addi	a2,a0,96
    800058f8:	00c686b3          	add	a3,a3,a2
    log.lh.block[i] = lh->block[i];
    800058fc:	0007a603          	lw	a2,0(a5)
    80005900:	00c72023          	sw	a2,0(a4)
  for (i = 0; i < log.lh.n; i++) {
    80005904:	00478793          	addi	a5,a5,4
    80005908:	00470713          	addi	a4,a4,4
    8000590c:	fed798e3          	bne	a5,a3,800058fc <initlog+0x8c>
  brelse(buf);
    80005910:	fffff097          	auipc	ra,0xfffff
    80005914:	910080e7          	jalr	-1776(ra) # 80004220 <brelse>

static void
recover_from_log(void)
{
  read_head();
  install_trans(1); // if committed, copy from log to disk
    80005918:	00100513          	li	a0,1
    8000591c:	00000097          	auipc	ra,0x0
    80005920:	e4c080e7          	jalr	-436(ra) # 80005768 <install_trans>
  log.lh.n = 0;
    80005924:	0001e797          	auipc	a5,0x1e
    80005928:	9607ac23          	sw	zero,-1672(a5) # 8002329c <log+0x2c>
  write_head(); // clear the log
    8000592c:	00000097          	auipc	ra,0x0
    80005930:	d94080e7          	jalr	-620(ra) # 800056c0 <write_head>
}
    80005934:	02813083          	ld	ra,40(sp)
    80005938:	02013403          	ld	s0,32(sp)
    8000593c:	01813483          	ld	s1,24(sp)
    80005940:	01013903          	ld	s2,16(sp)
    80005944:	00813983          	ld	s3,8(sp)
    80005948:	03010113          	addi	sp,sp,48
    8000594c:	00008067          	ret

0000000080005950 <begin_op>:
}

// called at the start of each FS system call.
void
begin_op(void)
{
    80005950:	fe010113          	addi	sp,sp,-32
    80005954:	00113c23          	sd	ra,24(sp)
    80005958:	00813823          	sd	s0,16(sp)
    8000595c:	00913423          	sd	s1,8(sp)
    80005960:	01213023          	sd	s2,0(sp)
    80005964:	02010413          	addi	s0,sp,32
  acquire(&log.lock);
    80005968:	0001e517          	auipc	a0,0x1e
    8000596c:	90850513          	addi	a0,a0,-1784 # 80023270 <log>
    80005970:	ffffb097          	auipc	ra,0xffffb
    80005974:	65c080e7          	jalr	1628(ra) # 80000fcc <acquire>
  while(1){
    if(log.committing){
    80005978:	0001e497          	auipc	s1,0x1e
    8000597c:	8f848493          	addi	s1,s1,-1800 # 80023270 <log>
      sleep(&log, &log.lock);
    } else if(log.lh.n + (log.outstanding+1)*MAXOPBLOCKS > LOGSIZE){
    80005980:	01e00913          	li	s2,30
    80005984:	0140006f          	j	80005998 <begin_op+0x48>
      sleep(&log, &log.lock);
    80005988:	00048593          	mv	a1,s1
    8000598c:	00048513          	mv	a0,s1
    80005990:	ffffd097          	auipc	ra,0xffffd
    80005994:	41c080e7          	jalr	1052(ra) # 80002dac <sleep>
    if(log.committing){
    80005998:	0244a783          	lw	a5,36(s1)
    8000599c:	fe0796e3          	bnez	a5,80005988 <begin_op+0x38>
    } else if(log.lh.n + (log.outstanding+1)*MAXOPBLOCKS > LOGSIZE){
    800059a0:	0204a703          	lw	a4,32(s1)
    800059a4:	0017071b          	addiw	a4,a4,1
    800059a8:	0007069b          	sext.w	a3,a4
    800059ac:	0027179b          	slliw	a5,a4,0x2
    800059b0:	00e787bb          	addw	a5,a5,a4
    800059b4:	0017979b          	slliw	a5,a5,0x1
    800059b8:	02c4a703          	lw	a4,44(s1)
    800059bc:	00e787bb          	addw	a5,a5,a4
    800059c0:	00f95c63          	bge	s2,a5,800059d8 <begin_op+0x88>
      // this op might exhaust log space; wait for commit.
      sleep(&log, &log.lock);
    800059c4:	00048593          	mv	a1,s1
    800059c8:	00048513          	mv	a0,s1
    800059cc:	ffffd097          	auipc	ra,0xffffd
    800059d0:	3e0080e7          	jalr	992(ra) # 80002dac <sleep>
    800059d4:	fc5ff06f          	j	80005998 <begin_op+0x48>
    } else {
      log.outstanding += 1;
    800059d8:	0001e517          	auipc	a0,0x1e
    800059dc:	89850513          	addi	a0,a0,-1896 # 80023270 <log>
    800059e0:	02d52023          	sw	a3,32(a0)
      release(&log.lock);
    800059e4:	ffffb097          	auipc	ra,0xffffb
    800059e8:	6e0080e7          	jalr	1760(ra) # 800010c4 <release>
      break;
    }
  }
}
    800059ec:	01813083          	ld	ra,24(sp)
    800059f0:	01013403          	ld	s0,16(sp)
    800059f4:	00813483          	ld	s1,8(sp)
    800059f8:	00013903          	ld	s2,0(sp)
    800059fc:	02010113          	addi	sp,sp,32
    80005a00:	00008067          	ret

0000000080005a04 <end_op>:

// called at the end of each FS system call.
// commits if this was the last outstanding operation.
void
end_op(void)
{
    80005a04:	fc010113          	addi	sp,sp,-64
    80005a08:	02113c23          	sd	ra,56(sp)
    80005a0c:	02813823          	sd	s0,48(sp)
    80005a10:	02913423          	sd	s1,40(sp)
    80005a14:	03213023          	sd	s2,32(sp)
    80005a18:	01313c23          	sd	s3,24(sp)
    80005a1c:	01413823          	sd	s4,16(sp)
    80005a20:	01513423          	sd	s5,8(sp)
    80005a24:	04010413          	addi	s0,sp,64
  int do_commit = 0;

  acquire(&log.lock);
    80005a28:	0001e497          	auipc	s1,0x1e
    80005a2c:	84848493          	addi	s1,s1,-1976 # 80023270 <log>
    80005a30:	00048513          	mv	a0,s1
    80005a34:	ffffb097          	auipc	ra,0xffffb
    80005a38:	598080e7          	jalr	1432(ra) # 80000fcc <acquire>
  log.outstanding -= 1;
    80005a3c:	0204a783          	lw	a5,32(s1)
    80005a40:	fff7879b          	addiw	a5,a5,-1
    80005a44:	0007891b          	sext.w	s2,a5
    80005a48:	02f4a023          	sw	a5,32(s1)
  if(log.committing)
    80005a4c:	0244a783          	lw	a5,36(s1)
    80005a50:	06079063          	bnez	a5,80005ab0 <end_op+0xac>
    panic("log.committing");
  if(log.outstanding == 0){
    80005a54:	06091663          	bnez	s2,80005ac0 <end_op+0xbc>
    do_commit = 1;
    log.committing = 1;
    80005a58:	0001e497          	auipc	s1,0x1e
    80005a5c:	81848493          	addi	s1,s1,-2024 # 80023270 <log>
    80005a60:	00100793          	li	a5,1
    80005a64:	02f4a223          	sw	a5,36(s1)
    // begin_op() may be waiting for log space,
    // and decrementing log.outstanding has decreased
    // the amount of reserved space.
    wakeup(&log);
  }
  release(&log.lock);
    80005a68:	00048513          	mv	a0,s1
    80005a6c:	ffffb097          	auipc	ra,0xffffb
    80005a70:	658080e7          	jalr	1624(ra) # 800010c4 <release>
}

static void
commit()
{
  if (log.lh.n > 0) {
    80005a74:	02c4a783          	lw	a5,44(s1)
    80005a78:	08f04663          	bgtz	a5,80005b04 <end_op+0x100>
    acquire(&log.lock);
    80005a7c:	0001d497          	auipc	s1,0x1d
    80005a80:	7f448493          	addi	s1,s1,2036 # 80023270 <log>
    80005a84:	00048513          	mv	a0,s1
    80005a88:	ffffb097          	auipc	ra,0xffffb
    80005a8c:	544080e7          	jalr	1348(ra) # 80000fcc <acquire>
    log.committing = 0;
    80005a90:	0204a223          	sw	zero,36(s1)
    wakeup(&log);
    80005a94:	00048513          	mv	a0,s1
    80005a98:	ffffd097          	auipc	ra,0xffffd
    80005a9c:	534080e7          	jalr	1332(ra) # 80002fcc <wakeup>
    release(&log.lock);
    80005aa0:	00048513          	mv	a0,s1
    80005aa4:	ffffb097          	auipc	ra,0xffffb
    80005aa8:	620080e7          	jalr	1568(ra) # 800010c4 <release>
}
    80005aac:	0340006f          	j	80005ae0 <end_op+0xdc>
    panic("log.committing");
    80005ab0:	00005517          	auipc	a0,0x5
    80005ab4:	b7850513          	addi	a0,a0,-1160 # 8000a628 <syscalls+0x1e0>
    80005ab8:	ffffb097          	auipc	ra,0xffffb
    80005abc:	c18080e7          	jalr	-1000(ra) # 800006d0 <panic>
    wakeup(&log);
    80005ac0:	0001d497          	auipc	s1,0x1d
    80005ac4:	7b048493          	addi	s1,s1,1968 # 80023270 <log>
    80005ac8:	00048513          	mv	a0,s1
    80005acc:	ffffd097          	auipc	ra,0xffffd
    80005ad0:	500080e7          	jalr	1280(ra) # 80002fcc <wakeup>
  release(&log.lock);
    80005ad4:	00048513          	mv	a0,s1
    80005ad8:	ffffb097          	auipc	ra,0xffffb
    80005adc:	5ec080e7          	jalr	1516(ra) # 800010c4 <release>
}
    80005ae0:	03813083          	ld	ra,56(sp)
    80005ae4:	03013403          	ld	s0,48(sp)
    80005ae8:	02813483          	ld	s1,40(sp)
    80005aec:	02013903          	ld	s2,32(sp)
    80005af0:	01813983          	ld	s3,24(sp)
    80005af4:	01013a03          	ld	s4,16(sp)
    80005af8:	00813a83          	ld	s5,8(sp)
    80005afc:	04010113          	addi	sp,sp,64
    80005b00:	00008067          	ret
  for (tail = 0; tail < log.lh.n; tail++) {
    80005b04:	0001da97          	auipc	s5,0x1d
    80005b08:	79ca8a93          	addi	s5,s5,1948 # 800232a0 <log+0x30>
    struct buf *to = bread(log.dev, log.start+tail+1); // log block
    80005b0c:	0001da17          	auipc	s4,0x1d
    80005b10:	764a0a13          	addi	s4,s4,1892 # 80023270 <log>
    80005b14:	018a2583          	lw	a1,24(s4)
    80005b18:	012585bb          	addw	a1,a1,s2
    80005b1c:	0015859b          	addiw	a1,a1,1
    80005b20:	028a2503          	lw	a0,40(s4)
    80005b24:	ffffe097          	auipc	ra,0xffffe
    80005b28:	560080e7          	jalr	1376(ra) # 80004084 <bread>
    80005b2c:	00050493          	mv	s1,a0
    struct buf *from = bread(log.dev, log.lh.block[tail]); // cache block
    80005b30:	000aa583          	lw	a1,0(s5)
    80005b34:	028a2503          	lw	a0,40(s4)
    80005b38:	ffffe097          	auipc	ra,0xffffe
    80005b3c:	54c080e7          	jalr	1356(ra) # 80004084 <bread>
    80005b40:	00050993          	mv	s3,a0
    memmove(to->data, from->data, BSIZE);
    80005b44:	40000613          	li	a2,1024
    80005b48:	05850593          	addi	a1,a0,88
    80005b4c:	05848513          	addi	a0,s1,88
    80005b50:	ffffb097          	auipc	ra,0xffffb
    80005b54:	668080e7          	jalr	1640(ra) # 800011b8 <memmove>
    bwrite(to);  // write the log
    80005b58:	00048513          	mv	a0,s1
    80005b5c:	ffffe097          	auipc	ra,0xffffe
    80005b60:	668080e7          	jalr	1640(ra) # 800041c4 <bwrite>
    brelse(from);
    80005b64:	00098513          	mv	a0,s3
    80005b68:	ffffe097          	auipc	ra,0xffffe
    80005b6c:	6b8080e7          	jalr	1720(ra) # 80004220 <brelse>
    brelse(to);
    80005b70:	00048513          	mv	a0,s1
    80005b74:	ffffe097          	auipc	ra,0xffffe
    80005b78:	6ac080e7          	jalr	1708(ra) # 80004220 <brelse>
  for (tail = 0; tail < log.lh.n; tail++) {
    80005b7c:	0019091b          	addiw	s2,s2,1
    80005b80:	004a8a93          	addi	s5,s5,4
    80005b84:	02ca2783          	lw	a5,44(s4)
    80005b88:	f8f946e3          	blt	s2,a5,80005b14 <end_op+0x110>
    write_log();     // Write modified blocks from cache to log
    write_head();    // Write header to disk -- the real commit
    80005b8c:	00000097          	auipc	ra,0x0
    80005b90:	b34080e7          	jalr	-1228(ra) # 800056c0 <write_head>
    install_trans(0); // Now install writes to home locations
    80005b94:	00000513          	li	a0,0
    80005b98:	00000097          	auipc	ra,0x0
    80005b9c:	bd0080e7          	jalr	-1072(ra) # 80005768 <install_trans>
    log.lh.n = 0;
    80005ba0:	0001d797          	auipc	a5,0x1d
    80005ba4:	6e07ae23          	sw	zero,1788(a5) # 8002329c <log+0x2c>
    write_head();    // Erase the transaction from the log
    80005ba8:	00000097          	auipc	ra,0x0
    80005bac:	b18080e7          	jalr	-1256(ra) # 800056c0 <write_head>
    80005bb0:	ecdff06f          	j	80005a7c <end_op+0x78>

0000000080005bb4 <log_write>:
//   modify bp->data[]
//   log_write(bp)
//   brelse(bp)
void
log_write(struct buf *b)
{
    80005bb4:	fe010113          	addi	sp,sp,-32
    80005bb8:	00113c23          	sd	ra,24(sp)
    80005bbc:	00813823          	sd	s0,16(sp)
    80005bc0:	00913423          	sd	s1,8(sp)
    80005bc4:	01213023          	sd	s2,0(sp)
    80005bc8:	02010413          	addi	s0,sp,32
    80005bcc:	00050493          	mv	s1,a0
  int i;

  acquire(&log.lock);
    80005bd0:	0001d917          	auipc	s2,0x1d
    80005bd4:	6a090913          	addi	s2,s2,1696 # 80023270 <log>
    80005bd8:	00090513          	mv	a0,s2
    80005bdc:	ffffb097          	auipc	ra,0xffffb
    80005be0:	3f0080e7          	jalr	1008(ra) # 80000fcc <acquire>
  if (log.lh.n >= LOGSIZE || log.lh.n >= log.size - 1)
    80005be4:	02c92603          	lw	a2,44(s2)
    80005be8:	01d00793          	li	a5,29
    80005bec:	08c7c663          	blt	a5,a2,80005c78 <log_write+0xc4>
    80005bf0:	0001d797          	auipc	a5,0x1d
    80005bf4:	69c7a783          	lw	a5,1692(a5) # 8002328c <log+0x1c>
    80005bf8:	fff7879b          	addiw	a5,a5,-1
    80005bfc:	06f65e63          	bge	a2,a5,80005c78 <log_write+0xc4>
    panic("too big a transaction");
  if (log.outstanding < 1)
    80005c00:	0001d797          	auipc	a5,0x1d
    80005c04:	6907a783          	lw	a5,1680(a5) # 80023290 <log+0x20>
    80005c08:	08f05063          	blez	a5,80005c88 <log_write+0xd4>
    panic("log_write outside of trans");

  for (i = 0; i < log.lh.n; i++) {
    80005c0c:	00000793          	li	a5,0
    80005c10:	08c05463          	blez	a2,80005c98 <log_write+0xe4>
    if (log.lh.block[i] == b->blockno)   // log absorption
    80005c14:	00c4a583          	lw	a1,12(s1)
    80005c18:	0001d717          	auipc	a4,0x1d
    80005c1c:	68870713          	addi	a4,a4,1672 # 800232a0 <log+0x30>
  for (i = 0; i < log.lh.n; i++) {
    80005c20:	00000793          	li	a5,0
    if (log.lh.block[i] == b->blockno)   // log absorption
    80005c24:	00072683          	lw	a3,0(a4)
    80005c28:	06b68863          	beq	a3,a1,80005c98 <log_write+0xe4>
  for (i = 0; i < log.lh.n; i++) {
    80005c2c:	0017879b          	addiw	a5,a5,1
    80005c30:	00470713          	addi	a4,a4,4
    80005c34:	fef618e3          	bne	a2,a5,80005c24 <log_write+0x70>
      break;
  }
  log.lh.block[i] = b->blockno;
    80005c38:	00860613          	addi	a2,a2,8
    80005c3c:	00261613          	slli	a2,a2,0x2
    80005c40:	0001d797          	auipc	a5,0x1d
    80005c44:	63078793          	addi	a5,a5,1584 # 80023270 <log>
    80005c48:	00c787b3          	add	a5,a5,a2
    80005c4c:	00c4a703          	lw	a4,12(s1)
    80005c50:	00e7a823          	sw	a4,16(a5)
  if (i == log.lh.n) {  // Add new block to log?
    bpin(b);
    80005c54:	00048513          	mv	a0,s1
    80005c58:	ffffe097          	auipc	ra,0xffffe
    80005c5c:	6a0080e7          	jalr	1696(ra) # 800042f8 <bpin>
    log.lh.n++;
    80005c60:	0001d717          	auipc	a4,0x1d
    80005c64:	61070713          	addi	a4,a4,1552 # 80023270 <log>
    80005c68:	02c72783          	lw	a5,44(a4)
    80005c6c:	0017879b          	addiw	a5,a5,1
    80005c70:	02f72623          	sw	a5,44(a4)
    80005c74:	0440006f          	j	80005cb8 <log_write+0x104>
    panic("too big a transaction");
    80005c78:	00005517          	auipc	a0,0x5
    80005c7c:	9c050513          	addi	a0,a0,-1600 # 8000a638 <syscalls+0x1f0>
    80005c80:	ffffb097          	auipc	ra,0xffffb
    80005c84:	a50080e7          	jalr	-1456(ra) # 800006d0 <panic>
    panic("log_write outside of trans");
    80005c88:	00005517          	auipc	a0,0x5
    80005c8c:	9c850513          	addi	a0,a0,-1592 # 8000a650 <syscalls+0x208>
    80005c90:	ffffb097          	auipc	ra,0xffffb
    80005c94:	a40080e7          	jalr	-1472(ra) # 800006d0 <panic>
  log.lh.block[i] = b->blockno;
    80005c98:	00878693          	addi	a3,a5,8
    80005c9c:	00269693          	slli	a3,a3,0x2
    80005ca0:	0001d717          	auipc	a4,0x1d
    80005ca4:	5d070713          	addi	a4,a4,1488 # 80023270 <log>
    80005ca8:	00d70733          	add	a4,a4,a3
    80005cac:	00c4a683          	lw	a3,12(s1)
    80005cb0:	00d72823          	sw	a3,16(a4)
  if (i == log.lh.n) {  // Add new block to log?
    80005cb4:	faf600e3          	beq	a2,a5,80005c54 <log_write+0xa0>
  }
  release(&log.lock);
    80005cb8:	0001d517          	auipc	a0,0x1d
    80005cbc:	5b850513          	addi	a0,a0,1464 # 80023270 <log>
    80005cc0:	ffffb097          	auipc	ra,0xffffb
    80005cc4:	404080e7          	jalr	1028(ra) # 800010c4 <release>
}
    80005cc8:	01813083          	ld	ra,24(sp)
    80005ccc:	01013403          	ld	s0,16(sp)
    80005cd0:	00813483          	ld	s1,8(sp)
    80005cd4:	00013903          	ld	s2,0(sp)
    80005cd8:	02010113          	addi	sp,sp,32
    80005cdc:	00008067          	ret

0000000080005ce0 <initsleeplock>:
#include "proc.h"
#include "sleeplock.h"

void
initsleeplock(struct sleeplock *lk, char *name)
{
    80005ce0:	fe010113          	addi	sp,sp,-32
    80005ce4:	00113c23          	sd	ra,24(sp)
    80005ce8:	00813823          	sd	s0,16(sp)
    80005cec:	00913423          	sd	s1,8(sp)
    80005cf0:	01213023          	sd	s2,0(sp)
    80005cf4:	02010413          	addi	s0,sp,32
    80005cf8:	00050493          	mv	s1,a0
    80005cfc:	00058913          	mv	s2,a1
  initlock(&lk->lk, "sleep lock");
    80005d00:	00005597          	auipc	a1,0x5
    80005d04:	97058593          	addi	a1,a1,-1680 # 8000a670 <syscalls+0x228>
    80005d08:	00850513          	addi	a0,a0,8
    80005d0c:	ffffb097          	auipc	ra,0xffffb
    80005d10:	1dc080e7          	jalr	476(ra) # 80000ee8 <initlock>
  lk->name = name;
    80005d14:	0324b023          	sd	s2,32(s1)
  lk->locked = 0;
    80005d18:	0004a023          	sw	zero,0(s1)
  lk->pid = 0;
    80005d1c:	0204a423          	sw	zero,40(s1)
}
    80005d20:	01813083          	ld	ra,24(sp)
    80005d24:	01013403          	ld	s0,16(sp)
    80005d28:	00813483          	ld	s1,8(sp)
    80005d2c:	00013903          	ld	s2,0(sp)
    80005d30:	02010113          	addi	sp,sp,32
    80005d34:	00008067          	ret

0000000080005d38 <acquiresleep>:

void
acquiresleep(struct sleeplock *lk)
{
    80005d38:	fe010113          	addi	sp,sp,-32
    80005d3c:	00113c23          	sd	ra,24(sp)
    80005d40:	00813823          	sd	s0,16(sp)
    80005d44:	00913423          	sd	s1,8(sp)
    80005d48:	01213023          	sd	s2,0(sp)
    80005d4c:	02010413          	addi	s0,sp,32
    80005d50:	00050493          	mv	s1,a0
  acquire(&lk->lk);
    80005d54:	00850913          	addi	s2,a0,8
    80005d58:	00090513          	mv	a0,s2
    80005d5c:	ffffb097          	auipc	ra,0xffffb
    80005d60:	270080e7          	jalr	624(ra) # 80000fcc <acquire>
  while (lk->locked) {
    80005d64:	0004a783          	lw	a5,0(s1)
    80005d68:	00078e63          	beqz	a5,80005d84 <acquiresleep+0x4c>
    sleep(lk, &lk->lk);
    80005d6c:	00090593          	mv	a1,s2
    80005d70:	00048513          	mv	a0,s1
    80005d74:	ffffd097          	auipc	ra,0xffffd
    80005d78:	038080e7          	jalr	56(ra) # 80002dac <sleep>
  while (lk->locked) {
    80005d7c:	0004a783          	lw	a5,0(s1)
    80005d80:	fe0796e3          	bnez	a5,80005d6c <acquiresleep+0x34>
  }
  lk->locked = 1;
    80005d84:	00100793          	li	a5,1
    80005d88:	00f4a023          	sw	a5,0(s1)
  lk->pid = myproc()->pid;
    80005d8c:	ffffc097          	auipc	ra,0xffffc
    80005d90:	6b0080e7          	jalr	1712(ra) # 8000243c <myproc>
    80005d94:	03052783          	lw	a5,48(a0)
    80005d98:	02f4a423          	sw	a5,40(s1)
  release(&lk->lk);
    80005d9c:	00090513          	mv	a0,s2
    80005da0:	ffffb097          	auipc	ra,0xffffb
    80005da4:	324080e7          	jalr	804(ra) # 800010c4 <release>
}
    80005da8:	01813083          	ld	ra,24(sp)
    80005dac:	01013403          	ld	s0,16(sp)
    80005db0:	00813483          	ld	s1,8(sp)
    80005db4:	00013903          	ld	s2,0(sp)
    80005db8:	02010113          	addi	sp,sp,32
    80005dbc:	00008067          	ret

0000000080005dc0 <releasesleep>:

void
releasesleep(struct sleeplock *lk)
{
    80005dc0:	fe010113          	addi	sp,sp,-32
    80005dc4:	00113c23          	sd	ra,24(sp)
    80005dc8:	00813823          	sd	s0,16(sp)
    80005dcc:	00913423          	sd	s1,8(sp)
    80005dd0:	01213023          	sd	s2,0(sp)
    80005dd4:	02010413          	addi	s0,sp,32
    80005dd8:	00050493          	mv	s1,a0
  acquire(&lk->lk);
    80005ddc:	00850913          	addi	s2,a0,8
    80005de0:	00090513          	mv	a0,s2
    80005de4:	ffffb097          	auipc	ra,0xffffb
    80005de8:	1e8080e7          	jalr	488(ra) # 80000fcc <acquire>
  lk->locked = 0;
    80005dec:	0004a023          	sw	zero,0(s1)
  lk->pid = 0;
    80005df0:	0204a423          	sw	zero,40(s1)
  wakeup(lk);
    80005df4:	00048513          	mv	a0,s1
    80005df8:	ffffd097          	auipc	ra,0xffffd
    80005dfc:	1d4080e7          	jalr	468(ra) # 80002fcc <wakeup>
  release(&lk->lk);
    80005e00:	00090513          	mv	a0,s2
    80005e04:	ffffb097          	auipc	ra,0xffffb
    80005e08:	2c0080e7          	jalr	704(ra) # 800010c4 <release>
}
    80005e0c:	01813083          	ld	ra,24(sp)
    80005e10:	01013403          	ld	s0,16(sp)
    80005e14:	00813483          	ld	s1,8(sp)
    80005e18:	00013903          	ld	s2,0(sp)
    80005e1c:	02010113          	addi	sp,sp,32
    80005e20:	00008067          	ret

0000000080005e24 <holdingsleep>:

int
holdingsleep(struct sleeplock *lk)
{
    80005e24:	fd010113          	addi	sp,sp,-48
    80005e28:	02113423          	sd	ra,40(sp)
    80005e2c:	02813023          	sd	s0,32(sp)
    80005e30:	00913c23          	sd	s1,24(sp)
    80005e34:	01213823          	sd	s2,16(sp)
    80005e38:	01313423          	sd	s3,8(sp)
    80005e3c:	03010413          	addi	s0,sp,48
    80005e40:	00050493          	mv	s1,a0
  int r;
  
  acquire(&lk->lk);
    80005e44:	00850913          	addi	s2,a0,8
    80005e48:	00090513          	mv	a0,s2
    80005e4c:	ffffb097          	auipc	ra,0xffffb
    80005e50:	180080e7          	jalr	384(ra) # 80000fcc <acquire>
  r = lk->locked && (lk->pid == myproc()->pid);
    80005e54:	0004a783          	lw	a5,0(s1)
    80005e58:	02079a63          	bnez	a5,80005e8c <holdingsleep+0x68>
    80005e5c:	00000493          	li	s1,0
  release(&lk->lk);
    80005e60:	00090513          	mv	a0,s2
    80005e64:	ffffb097          	auipc	ra,0xffffb
    80005e68:	260080e7          	jalr	608(ra) # 800010c4 <release>
  return r;
}
    80005e6c:	00048513          	mv	a0,s1
    80005e70:	02813083          	ld	ra,40(sp)
    80005e74:	02013403          	ld	s0,32(sp)
    80005e78:	01813483          	ld	s1,24(sp)
    80005e7c:	01013903          	ld	s2,16(sp)
    80005e80:	00813983          	ld	s3,8(sp)
    80005e84:	03010113          	addi	sp,sp,48
    80005e88:	00008067          	ret
  r = lk->locked && (lk->pid == myproc()->pid);
    80005e8c:	0284a983          	lw	s3,40(s1)
    80005e90:	ffffc097          	auipc	ra,0xffffc
    80005e94:	5ac080e7          	jalr	1452(ra) # 8000243c <myproc>
    80005e98:	03052483          	lw	s1,48(a0)
    80005e9c:	413484b3          	sub	s1,s1,s3
    80005ea0:	0014b493          	seqz	s1,s1
    80005ea4:	fbdff06f          	j	80005e60 <holdingsleep+0x3c>

0000000080005ea8 <fileinit>:
  struct file file[NFILE];
} ftable;

void
fileinit(void)
{
    80005ea8:	ff010113          	addi	sp,sp,-16
    80005eac:	00113423          	sd	ra,8(sp)
    80005eb0:	00813023          	sd	s0,0(sp)
    80005eb4:	01010413          	addi	s0,sp,16
  initlock(&ftable.lock, "ftable");
    80005eb8:	00004597          	auipc	a1,0x4
    80005ebc:	7c858593          	addi	a1,a1,1992 # 8000a680 <syscalls+0x238>
    80005ec0:	0001d517          	auipc	a0,0x1d
    80005ec4:	4f850513          	addi	a0,a0,1272 # 800233b8 <ftable>
    80005ec8:	ffffb097          	auipc	ra,0xffffb
    80005ecc:	020080e7          	jalr	32(ra) # 80000ee8 <initlock>
}
    80005ed0:	00813083          	ld	ra,8(sp)
    80005ed4:	00013403          	ld	s0,0(sp)
    80005ed8:	01010113          	addi	sp,sp,16
    80005edc:	00008067          	ret

0000000080005ee0 <filealloc>:

// Allocate a file structure.
struct file*
filealloc(void)
{
    80005ee0:	fe010113          	addi	sp,sp,-32
    80005ee4:	00113c23          	sd	ra,24(sp)
    80005ee8:	00813823          	sd	s0,16(sp)
    80005eec:	00913423          	sd	s1,8(sp)
    80005ef0:	02010413          	addi	s0,sp,32
  struct file *f;

  acquire(&ftable.lock);
    80005ef4:	0001d517          	auipc	a0,0x1d
    80005ef8:	4c450513          	addi	a0,a0,1220 # 800233b8 <ftable>
    80005efc:	ffffb097          	auipc	ra,0xffffb
    80005f00:	0d0080e7          	jalr	208(ra) # 80000fcc <acquire>
  for(f = ftable.file; f < ftable.file + NFILE; f++){
    80005f04:	0001d497          	auipc	s1,0x1d
    80005f08:	4cc48493          	addi	s1,s1,1228 # 800233d0 <ftable+0x18>
    80005f0c:	0001e717          	auipc	a4,0x1e
    80005f10:	46470713          	addi	a4,a4,1124 # 80024370 <ftable+0xfb8>
    if(f->ref == 0){
    80005f14:	0044a783          	lw	a5,4(s1)
    80005f18:	02078263          	beqz	a5,80005f3c <filealloc+0x5c>
  for(f = ftable.file; f < ftable.file + NFILE; f++){
    80005f1c:	02848493          	addi	s1,s1,40
    80005f20:	fee49ae3          	bne	s1,a4,80005f14 <filealloc+0x34>
      f->ref = 1;
      release(&ftable.lock);
      return f;
    }
  }
  release(&ftable.lock);
    80005f24:	0001d517          	auipc	a0,0x1d
    80005f28:	49450513          	addi	a0,a0,1172 # 800233b8 <ftable>
    80005f2c:	ffffb097          	auipc	ra,0xffffb
    80005f30:	198080e7          	jalr	408(ra) # 800010c4 <release>
  return 0;
    80005f34:	00000493          	li	s1,0
    80005f38:	01c0006f          	j	80005f54 <filealloc+0x74>
      f->ref = 1;
    80005f3c:	00100793          	li	a5,1
    80005f40:	00f4a223          	sw	a5,4(s1)
      release(&ftable.lock);
    80005f44:	0001d517          	auipc	a0,0x1d
    80005f48:	47450513          	addi	a0,a0,1140 # 800233b8 <ftable>
    80005f4c:	ffffb097          	auipc	ra,0xffffb
    80005f50:	178080e7          	jalr	376(ra) # 800010c4 <release>
}
    80005f54:	00048513          	mv	a0,s1
    80005f58:	01813083          	ld	ra,24(sp)
    80005f5c:	01013403          	ld	s0,16(sp)
    80005f60:	00813483          	ld	s1,8(sp)
    80005f64:	02010113          	addi	sp,sp,32
    80005f68:	00008067          	ret

0000000080005f6c <filedup>:

// Increment ref count for file f.
struct file*
filedup(struct file *f)
{
    80005f6c:	fe010113          	addi	sp,sp,-32
    80005f70:	00113c23          	sd	ra,24(sp)
    80005f74:	00813823          	sd	s0,16(sp)
    80005f78:	00913423          	sd	s1,8(sp)
    80005f7c:	02010413          	addi	s0,sp,32
    80005f80:	00050493          	mv	s1,a0
  acquire(&ftable.lock);
    80005f84:	0001d517          	auipc	a0,0x1d
    80005f88:	43450513          	addi	a0,a0,1076 # 800233b8 <ftable>
    80005f8c:	ffffb097          	auipc	ra,0xffffb
    80005f90:	040080e7          	jalr	64(ra) # 80000fcc <acquire>
  if(f->ref < 1)
    80005f94:	0044a783          	lw	a5,4(s1)
    80005f98:	02f05a63          	blez	a5,80005fcc <filedup+0x60>
    panic("filedup");
  f->ref++;
    80005f9c:	0017879b          	addiw	a5,a5,1
    80005fa0:	00f4a223          	sw	a5,4(s1)
  release(&ftable.lock);
    80005fa4:	0001d517          	auipc	a0,0x1d
    80005fa8:	41450513          	addi	a0,a0,1044 # 800233b8 <ftable>
    80005fac:	ffffb097          	auipc	ra,0xffffb
    80005fb0:	118080e7          	jalr	280(ra) # 800010c4 <release>
  return f;
}
    80005fb4:	00048513          	mv	a0,s1
    80005fb8:	01813083          	ld	ra,24(sp)
    80005fbc:	01013403          	ld	s0,16(sp)
    80005fc0:	00813483          	ld	s1,8(sp)
    80005fc4:	02010113          	addi	sp,sp,32
    80005fc8:	00008067          	ret
    panic("filedup");
    80005fcc:	00004517          	auipc	a0,0x4
    80005fd0:	6bc50513          	addi	a0,a0,1724 # 8000a688 <syscalls+0x240>
    80005fd4:	ffffa097          	auipc	ra,0xffffa
    80005fd8:	6fc080e7          	jalr	1788(ra) # 800006d0 <panic>

0000000080005fdc <fileclose>:

// Close file f.  (Decrement ref count, close when reaches 0.)
void
fileclose(struct file *f)
{
    80005fdc:	fc010113          	addi	sp,sp,-64
    80005fe0:	02113c23          	sd	ra,56(sp)
    80005fe4:	02813823          	sd	s0,48(sp)
    80005fe8:	02913423          	sd	s1,40(sp)
    80005fec:	03213023          	sd	s2,32(sp)
    80005ff0:	01313c23          	sd	s3,24(sp)
    80005ff4:	01413823          	sd	s4,16(sp)
    80005ff8:	01513423          	sd	s5,8(sp)
    80005ffc:	04010413          	addi	s0,sp,64
    80006000:	00050493          	mv	s1,a0
  struct file ff;

  acquire(&ftable.lock);
    80006004:	0001d517          	auipc	a0,0x1d
    80006008:	3b450513          	addi	a0,a0,948 # 800233b8 <ftable>
    8000600c:	ffffb097          	auipc	ra,0xffffb
    80006010:	fc0080e7          	jalr	-64(ra) # 80000fcc <acquire>
  if(f->ref < 1)
    80006014:	0044a783          	lw	a5,4(s1)
    80006018:	06f05863          	blez	a5,80006088 <fileclose+0xac>
    panic("fileclose");
  if(--f->ref > 0){
    8000601c:	fff7879b          	addiw	a5,a5,-1
    80006020:	0007871b          	sext.w	a4,a5
    80006024:	00f4a223          	sw	a5,4(s1)
    80006028:	06e04863          	bgtz	a4,80006098 <fileclose+0xbc>
    release(&ftable.lock);
    return;
  }
  ff = *f;
    8000602c:	0004a903          	lw	s2,0(s1)
    80006030:	0094ca83          	lbu	s5,9(s1)
    80006034:	0104ba03          	ld	s4,16(s1)
    80006038:	0184b983          	ld	s3,24(s1)
  f->ref = 0;
    8000603c:	0004a223          	sw	zero,4(s1)
  f->type = FD_NONE;
    80006040:	0004a023          	sw	zero,0(s1)
  release(&ftable.lock);
    80006044:	0001d517          	auipc	a0,0x1d
    80006048:	37450513          	addi	a0,a0,884 # 800233b8 <ftable>
    8000604c:	ffffb097          	auipc	ra,0xffffb
    80006050:	078080e7          	jalr	120(ra) # 800010c4 <release>

  if(ff.type == FD_PIPE){
    80006054:	00100793          	li	a5,1
    80006058:	06f90a63          	beq	s2,a5,800060cc <fileclose+0xf0>
    pipeclose(ff.pipe, ff.writable);
  } else if(ff.type == FD_INODE || ff.type == FD_DEVICE){
    8000605c:	ffe9091b          	addiw	s2,s2,-2
    80006060:	00100793          	li	a5,1
    80006064:	0527e263          	bltu	a5,s2,800060a8 <fileclose+0xcc>
    begin_op();
    80006068:	00000097          	auipc	ra,0x0
    8000606c:	8e8080e7          	jalr	-1816(ra) # 80005950 <begin_op>
    iput(ff.ip);
    80006070:	00098513          	mv	a0,s3
    80006074:	fffff097          	auipc	ra,0xfffff
    80006078:	d48080e7          	jalr	-696(ra) # 80004dbc <iput>
    end_op();
    8000607c:	00000097          	auipc	ra,0x0
    80006080:	988080e7          	jalr	-1656(ra) # 80005a04 <end_op>
    80006084:	0240006f          	j	800060a8 <fileclose+0xcc>
    panic("fileclose");
    80006088:	00004517          	auipc	a0,0x4
    8000608c:	60850513          	addi	a0,a0,1544 # 8000a690 <syscalls+0x248>
    80006090:	ffffa097          	auipc	ra,0xffffa
    80006094:	640080e7          	jalr	1600(ra) # 800006d0 <panic>
    release(&ftable.lock);
    80006098:	0001d517          	auipc	a0,0x1d
    8000609c:	32050513          	addi	a0,a0,800 # 800233b8 <ftable>
    800060a0:	ffffb097          	auipc	ra,0xffffb
    800060a4:	024080e7          	jalr	36(ra) # 800010c4 <release>
  }
}
    800060a8:	03813083          	ld	ra,56(sp)
    800060ac:	03013403          	ld	s0,48(sp)
    800060b0:	02813483          	ld	s1,40(sp)
    800060b4:	02013903          	ld	s2,32(sp)
    800060b8:	01813983          	ld	s3,24(sp)
    800060bc:	01013a03          	ld	s4,16(sp)
    800060c0:	00813a83          	ld	s5,8(sp)
    800060c4:	04010113          	addi	sp,sp,64
    800060c8:	00008067          	ret
    pipeclose(ff.pipe, ff.writable);
    800060cc:	000a8593          	mv	a1,s5
    800060d0:	000a0513          	mv	a0,s4
    800060d4:	00000097          	auipc	ra,0x0
    800060d8:	4c0080e7          	jalr	1216(ra) # 80006594 <pipeclose>
    800060dc:	fcdff06f          	j	800060a8 <fileclose+0xcc>

00000000800060e0 <filestat>:

// Get metadata about file f.
// addr is a user virtual address, pointing to a struct stat.
int
filestat(struct file *f, uint64 addr)
{
    800060e0:	fb010113          	addi	sp,sp,-80
    800060e4:	04113423          	sd	ra,72(sp)
    800060e8:	04813023          	sd	s0,64(sp)
    800060ec:	02913c23          	sd	s1,56(sp)
    800060f0:	03213823          	sd	s2,48(sp)
    800060f4:	03313423          	sd	s3,40(sp)
    800060f8:	05010413          	addi	s0,sp,80
    800060fc:	00050493          	mv	s1,a0
    80006100:	00058993          	mv	s3,a1
  struct proc *p = myproc();
    80006104:	ffffc097          	auipc	ra,0xffffc
    80006108:	338080e7          	jalr	824(ra) # 8000243c <myproc>
  struct stat st;
  
  if(f->type == FD_INODE || f->type == FD_DEVICE){
    8000610c:	0004a783          	lw	a5,0(s1)
    80006110:	ffe7879b          	addiw	a5,a5,-2
    80006114:	00100713          	li	a4,1
    80006118:	06f76463          	bltu	a4,a5,80006180 <filestat+0xa0>
    8000611c:	00050913          	mv	s2,a0
    ilock(f->ip);
    80006120:	0184b503          	ld	a0,24(s1)
    80006124:	fffff097          	auipc	ra,0xfffff
    80006128:	a38080e7          	jalr	-1480(ra) # 80004b5c <ilock>
    stati(f->ip, &st);
    8000612c:	fb840593          	addi	a1,s0,-72
    80006130:	0184b503          	ld	a0,24(s1)
    80006134:	fffff097          	auipc	ra,0xfffff
    80006138:	da4080e7          	jalr	-604(ra) # 80004ed8 <stati>
    iunlock(f->ip);
    8000613c:	0184b503          	ld	a0,24(s1)
    80006140:	fffff097          	auipc	ra,0xfffff
    80006144:	b20080e7          	jalr	-1248(ra) # 80004c60 <iunlock>
    if(copyout(p->pagetable, addr, (char *)&st, sizeof(st)) < 0)
    80006148:	01800693          	li	a3,24
    8000614c:	fb840613          	addi	a2,s0,-72
    80006150:	00098593          	mv	a1,s3
    80006154:	05093503          	ld	a0,80(s2)
    80006158:	ffffc097          	auipc	ra,0xffffc
    8000615c:	dec080e7          	jalr	-532(ra) # 80001f44 <copyout>
    80006160:	41f5551b          	sraiw	a0,a0,0x1f
      return -1;
    return 0;
  }
  return -1;
}
    80006164:	04813083          	ld	ra,72(sp)
    80006168:	04013403          	ld	s0,64(sp)
    8000616c:	03813483          	ld	s1,56(sp)
    80006170:	03013903          	ld	s2,48(sp)
    80006174:	02813983          	ld	s3,40(sp)
    80006178:	05010113          	addi	sp,sp,80
    8000617c:	00008067          	ret
  return -1;
    80006180:	fff00513          	li	a0,-1
    80006184:	fe1ff06f          	j	80006164 <filestat+0x84>

0000000080006188 <fileread>:

// Read from file f.
// addr is a user virtual address.
int
fileread(struct file *f, uint64 addr, int n)
{
    80006188:	fd010113          	addi	sp,sp,-48
    8000618c:	02113423          	sd	ra,40(sp)
    80006190:	02813023          	sd	s0,32(sp)
    80006194:	00913c23          	sd	s1,24(sp)
    80006198:	01213823          	sd	s2,16(sp)
    8000619c:	01313423          	sd	s3,8(sp)
    800061a0:	03010413          	addi	s0,sp,48
  int r = 0;

  if(f->readable == 0)
    800061a4:	00854783          	lbu	a5,8(a0)
    800061a8:	0e078a63          	beqz	a5,8000629c <fileread+0x114>
    800061ac:	00050493          	mv	s1,a0
    800061b0:	00058993          	mv	s3,a1
    800061b4:	00060913          	mv	s2,a2
    return -1;

  if(f->type == FD_PIPE){
    800061b8:	00052783          	lw	a5,0(a0)
    800061bc:	00100713          	li	a4,1
    800061c0:	06e78e63          	beq	a5,a4,8000623c <fileread+0xb4>
    r = piperead(f->pipe, addr, n);
  } else if(f->type == FD_DEVICE){
    800061c4:	00300713          	li	a4,3
    800061c8:	08e78463          	beq	a5,a4,80006250 <fileread+0xc8>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
      return -1;
    r = devsw[f->major].read(1, addr, n);
  } else if(f->type == FD_INODE){
    800061cc:	00200713          	li	a4,2
    800061d0:	0ae79e63          	bne	a5,a4,8000628c <fileread+0x104>
    ilock(f->ip);
    800061d4:	01853503          	ld	a0,24(a0)
    800061d8:	fffff097          	auipc	ra,0xfffff
    800061dc:	984080e7          	jalr	-1660(ra) # 80004b5c <ilock>
    if((r = readi(f->ip, 1, addr, f->off, n)) > 0)
    800061e0:	00090713          	mv	a4,s2
    800061e4:	0204a683          	lw	a3,32(s1)
    800061e8:	00098613          	mv	a2,s3
    800061ec:	00100593          	li	a1,1
    800061f0:	0184b503          	ld	a0,24(s1)
    800061f4:	fffff097          	auipc	ra,0xfffff
    800061f8:	d24080e7          	jalr	-732(ra) # 80004f18 <readi>
    800061fc:	00050913          	mv	s2,a0
    80006200:	00a05863          	blez	a0,80006210 <fileread+0x88>
      f->off += r;
    80006204:	0204a783          	lw	a5,32(s1)
    80006208:	00a787bb          	addw	a5,a5,a0
    8000620c:	02f4a023          	sw	a5,32(s1)
    iunlock(f->ip);
    80006210:	0184b503          	ld	a0,24(s1)
    80006214:	fffff097          	auipc	ra,0xfffff
    80006218:	a4c080e7          	jalr	-1460(ra) # 80004c60 <iunlock>
  } else {
    panic("fileread");
  }

  return r;
}
    8000621c:	00090513          	mv	a0,s2
    80006220:	02813083          	ld	ra,40(sp)
    80006224:	02013403          	ld	s0,32(sp)
    80006228:	01813483          	ld	s1,24(sp)
    8000622c:	01013903          	ld	s2,16(sp)
    80006230:	00813983          	ld	s3,8(sp)
    80006234:	03010113          	addi	sp,sp,48
    80006238:	00008067          	ret
    r = piperead(f->pipe, addr, n);
    8000623c:	01053503          	ld	a0,16(a0)
    80006240:	00000097          	auipc	ra,0x0
    80006244:	53c080e7          	jalr	1340(ra) # 8000677c <piperead>
    80006248:	00050913          	mv	s2,a0
    8000624c:	fd1ff06f          	j	8000621c <fileread+0x94>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
    80006250:	02451783          	lh	a5,36(a0)
    80006254:	03079693          	slli	a3,a5,0x30
    80006258:	0306d693          	srli	a3,a3,0x30
    8000625c:	00900713          	li	a4,9
    80006260:	04d76263          	bltu	a4,a3,800062a4 <fileread+0x11c>
    80006264:	00479793          	slli	a5,a5,0x4
    80006268:	0001d717          	auipc	a4,0x1d
    8000626c:	0b070713          	addi	a4,a4,176 # 80023318 <devsw>
    80006270:	00f707b3          	add	a5,a4,a5
    80006274:	0007b783          	ld	a5,0(a5)
    80006278:	02078a63          	beqz	a5,800062ac <fileread+0x124>
    r = devsw[f->major].read(1, addr, n);
    8000627c:	00100513          	li	a0,1
    80006280:	000780e7          	jalr	a5
    80006284:	00050913          	mv	s2,a0
    80006288:	f95ff06f          	j	8000621c <fileread+0x94>
    panic("fileread");
    8000628c:	00004517          	auipc	a0,0x4
    80006290:	41450513          	addi	a0,a0,1044 # 8000a6a0 <syscalls+0x258>
    80006294:	ffffa097          	auipc	ra,0xffffa
    80006298:	43c080e7          	jalr	1084(ra) # 800006d0 <panic>
    return -1;
    8000629c:	fff00913          	li	s2,-1
    800062a0:	f7dff06f          	j	8000621c <fileread+0x94>
      return -1;
    800062a4:	fff00913          	li	s2,-1
    800062a8:	f75ff06f          	j	8000621c <fileread+0x94>
    800062ac:	fff00913          	li	s2,-1
    800062b0:	f6dff06f          	j	8000621c <fileread+0x94>

00000000800062b4 <filewrite>:

// Write to file f.
// addr is a user virtual address.
int
filewrite(struct file *f, uint64 addr, int n)
{
    800062b4:	fb010113          	addi	sp,sp,-80
    800062b8:	04113423          	sd	ra,72(sp)
    800062bc:	04813023          	sd	s0,64(sp)
    800062c0:	02913c23          	sd	s1,56(sp)
    800062c4:	03213823          	sd	s2,48(sp)
    800062c8:	03313423          	sd	s3,40(sp)
    800062cc:	03413023          	sd	s4,32(sp)
    800062d0:	01513c23          	sd	s5,24(sp)
    800062d4:	01613823          	sd	s6,16(sp)
    800062d8:	01713423          	sd	s7,8(sp)
    800062dc:	01813023          	sd	s8,0(sp)
    800062e0:	05010413          	addi	s0,sp,80
  int r, ret = 0;

  if(f->writable == 0)
    800062e4:	00954783          	lbu	a5,9(a0)
    800062e8:	16078463          	beqz	a5,80006450 <filewrite+0x19c>
    800062ec:	00050913          	mv	s2,a0
    800062f0:	00058b13          	mv	s6,a1
    800062f4:	00060a13          	mv	s4,a2
    return -1;

  if(f->type == FD_PIPE){
    800062f8:	00052783          	lw	a5,0(a0)
    800062fc:	00100713          	li	a4,1
    80006300:	02e78863          	beq	a5,a4,80006330 <filewrite+0x7c>
    ret = pipewrite(f->pipe, addr, n);
  } else if(f->type == FD_DEVICE){
    80006304:	00300713          	li	a4,3
    80006308:	02e78e63          	beq	a5,a4,80006344 <filewrite+0x90>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
      return -1;
    ret = devsw[f->major].write(1, addr, n);
  } else if(f->type == FD_INODE){
    8000630c:	00200713          	li	a4,2
    80006310:	12e79863          	bne	a5,a4,80006440 <filewrite+0x18c>
    // and 2 blocks of slop for non-aligned writes.
    // this really belongs lower down, since writei()
    // might be writing a device like the console.
    int max = ((MAXOPBLOCKS-1-1-2) / 2) * BSIZE;
    int i = 0;
    while(i < n){
    80006314:	0ec05463          	blez	a2,800063fc <filewrite+0x148>
    int i = 0;
    80006318:	00000993          	li	s3,0
    8000631c:	00001bb7          	lui	s7,0x1
    80006320:	c00b8b93          	addi	s7,s7,-1024 # c00 <_entry-0x7ffff400>
    80006324:	00001c37          	lui	s8,0x1
    80006328:	c00c0c1b          	addiw	s8,s8,-1024 # c00 <_entry-0x7ffff400>
    8000632c:	0bc0006f          	j	800063e8 <filewrite+0x134>
    ret = pipewrite(f->pipe, addr, n);
    80006330:	01053503          	ld	a0,16(a0)
    80006334:	00000097          	auipc	ra,0x0
    80006338:	2f8080e7          	jalr	760(ra) # 8000662c <pipewrite>
    8000633c:	00050a13          	mv	s4,a0
    80006340:	0c40006f          	j	80006404 <filewrite+0x150>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
    80006344:	02451783          	lh	a5,36(a0)
    80006348:	03079693          	slli	a3,a5,0x30
    8000634c:	0306d693          	srli	a3,a3,0x30
    80006350:	00900713          	li	a4,9
    80006354:	10d76263          	bltu	a4,a3,80006458 <filewrite+0x1a4>
    80006358:	00479793          	slli	a5,a5,0x4
    8000635c:	0001d717          	auipc	a4,0x1d
    80006360:	fbc70713          	addi	a4,a4,-68 # 80023318 <devsw>
    80006364:	00f707b3          	add	a5,a4,a5
    80006368:	0087b783          	ld	a5,8(a5)
    8000636c:	0e078a63          	beqz	a5,80006460 <filewrite+0x1ac>
    ret = devsw[f->major].write(1, addr, n);
    80006370:	00100513          	li	a0,1
    80006374:	000780e7          	jalr	a5
    80006378:	00050a13          	mv	s4,a0
    8000637c:	0880006f          	j	80006404 <filewrite+0x150>
    80006380:	00048a9b          	sext.w	s5,s1
      int n1 = n - i;
      if(n1 > max)
        n1 = max;

      begin_op();
    80006384:	fffff097          	auipc	ra,0xfffff
    80006388:	5cc080e7          	jalr	1484(ra) # 80005950 <begin_op>
      ilock(f->ip);
    8000638c:	01893503          	ld	a0,24(s2)
    80006390:	ffffe097          	auipc	ra,0xffffe
    80006394:	7cc080e7          	jalr	1996(ra) # 80004b5c <ilock>
      if ((r = writei(f->ip, 1, addr + i, f->off, n1)) > 0)
    80006398:	000a8713          	mv	a4,s5
    8000639c:	02092683          	lw	a3,32(s2)
    800063a0:	01698633          	add	a2,s3,s6
    800063a4:	00100593          	li	a1,1
    800063a8:	01893503          	ld	a0,24(s2)
    800063ac:	fffff097          	auipc	ra,0xfffff
    800063b0:	cdc080e7          	jalr	-804(ra) # 80005088 <writei>
    800063b4:	00050493          	mv	s1,a0
    800063b8:	00a05863          	blez	a0,800063c8 <filewrite+0x114>
        f->off += r;
    800063bc:	02092783          	lw	a5,32(s2)
    800063c0:	00a787bb          	addw	a5,a5,a0
    800063c4:	02f92023          	sw	a5,32(s2)
      iunlock(f->ip);
    800063c8:	01893503          	ld	a0,24(s2)
    800063cc:	fffff097          	auipc	ra,0xfffff
    800063d0:	894080e7          	jalr	-1900(ra) # 80004c60 <iunlock>
      end_op();
    800063d4:	fffff097          	auipc	ra,0xfffff
    800063d8:	630080e7          	jalr	1584(ra) # 80005a04 <end_op>

      if(r != n1){
    800063dc:	029a9263          	bne	s5,s1,80006400 <filewrite+0x14c>
        // error from writei
        break;
      }
      i += r;
    800063e0:	013489bb          	addw	s3,s1,s3
    while(i < n){
    800063e4:	0149de63          	bge	s3,s4,80006400 <filewrite+0x14c>
      int n1 = n - i;
    800063e8:	413a04bb          	subw	s1,s4,s3
    800063ec:	0004879b          	sext.w	a5,s1
    800063f0:	f8fbd8e3          	bge	s7,a5,80006380 <filewrite+0xcc>
    800063f4:	000c0493          	mv	s1,s8
    800063f8:	f89ff06f          	j	80006380 <filewrite+0xcc>
    int i = 0;
    800063fc:	00000993          	li	s3,0
    }
    ret = (i == n ? n : -1);
    80006400:	033a1c63          	bne	s4,s3,80006438 <filewrite+0x184>
  } else {
    panic("filewrite");
  }

  return ret;
}
    80006404:	000a0513          	mv	a0,s4
    80006408:	04813083          	ld	ra,72(sp)
    8000640c:	04013403          	ld	s0,64(sp)
    80006410:	03813483          	ld	s1,56(sp)
    80006414:	03013903          	ld	s2,48(sp)
    80006418:	02813983          	ld	s3,40(sp)
    8000641c:	02013a03          	ld	s4,32(sp)
    80006420:	01813a83          	ld	s5,24(sp)
    80006424:	01013b03          	ld	s6,16(sp)
    80006428:	00813b83          	ld	s7,8(sp)
    8000642c:	00013c03          	ld	s8,0(sp)
    80006430:	05010113          	addi	sp,sp,80
    80006434:	00008067          	ret
    ret = (i == n ? n : -1);
    80006438:	fff00a13          	li	s4,-1
    8000643c:	fc9ff06f          	j	80006404 <filewrite+0x150>
    panic("filewrite");
    80006440:	00004517          	auipc	a0,0x4
    80006444:	27050513          	addi	a0,a0,624 # 8000a6b0 <syscalls+0x268>
    80006448:	ffffa097          	auipc	ra,0xffffa
    8000644c:	288080e7          	jalr	648(ra) # 800006d0 <panic>
    return -1;
    80006450:	fff00a13          	li	s4,-1
    80006454:	fb1ff06f          	j	80006404 <filewrite+0x150>
      return -1;
    80006458:	fff00a13          	li	s4,-1
    8000645c:	fa9ff06f          	j	80006404 <filewrite+0x150>
    80006460:	fff00a13          	li	s4,-1
    80006464:	fa1ff06f          	j	80006404 <filewrite+0x150>

0000000080006468 <pipealloc>:
  int writeopen;  // write fd is still open
};

int
pipealloc(struct file **f0, struct file **f1)
{
    80006468:	fd010113          	addi	sp,sp,-48
    8000646c:	02113423          	sd	ra,40(sp)
    80006470:	02813023          	sd	s0,32(sp)
    80006474:	00913c23          	sd	s1,24(sp)
    80006478:	01213823          	sd	s2,16(sp)
    8000647c:	01313423          	sd	s3,8(sp)
    80006480:	01413023          	sd	s4,0(sp)
    80006484:	03010413          	addi	s0,sp,48
    80006488:	00050493          	mv	s1,a0
    8000648c:	00058a13          	mv	s4,a1
  struct pipe *pi;

  pi = 0;
  *f0 = *f1 = 0;
    80006490:	0005b023          	sd	zero,0(a1)
    80006494:	00053023          	sd	zero,0(a0)
  if((*f0 = filealloc()) == 0 || (*f1 = filealloc()) == 0)
    80006498:	00000097          	auipc	ra,0x0
    8000649c:	a48080e7          	jalr	-1464(ra) # 80005ee0 <filealloc>
    800064a0:	00a4b023          	sd	a0,0(s1)
    800064a4:	0a050663          	beqz	a0,80006550 <pipealloc+0xe8>
    800064a8:	00000097          	auipc	ra,0x0
    800064ac:	a38080e7          	jalr	-1480(ra) # 80005ee0 <filealloc>
    800064b0:	00aa3023          	sd	a0,0(s4)
    800064b4:	08050663          	beqz	a0,80006540 <pipealloc+0xd8>
    goto bad;
  if((pi = (struct pipe*)kalloc()) == 0)
    800064b8:	ffffb097          	auipc	ra,0xffffb
    800064bc:	9a8080e7          	jalr	-1624(ra) # 80000e60 <kalloc>
    800064c0:	00050913          	mv	s2,a0
    800064c4:	06050863          	beqz	a0,80006534 <pipealloc+0xcc>
    goto bad;
  pi->readopen = 1;
    800064c8:	00100993          	li	s3,1
    800064cc:	23352023          	sw	s3,544(a0)
  pi->writeopen = 1;
    800064d0:	23352223          	sw	s3,548(a0)
  pi->nwrite = 0;
    800064d4:	20052e23          	sw	zero,540(a0)
  pi->nread = 0;
    800064d8:	20052c23          	sw	zero,536(a0)
  initlock(&pi->lock, "pipe");
    800064dc:	00004597          	auipc	a1,0x4
    800064e0:	1e458593          	addi	a1,a1,484 # 8000a6c0 <syscalls+0x278>
    800064e4:	ffffb097          	auipc	ra,0xffffb
    800064e8:	a04080e7          	jalr	-1532(ra) # 80000ee8 <initlock>
  (*f0)->type = FD_PIPE;
    800064ec:	0004b783          	ld	a5,0(s1)
    800064f0:	0137a023          	sw	s3,0(a5)
  (*f0)->readable = 1;
    800064f4:	0004b783          	ld	a5,0(s1)
    800064f8:	01378423          	sb	s3,8(a5)
  (*f0)->writable = 0;
    800064fc:	0004b783          	ld	a5,0(s1)
    80006500:	000784a3          	sb	zero,9(a5)
  (*f0)->pipe = pi;
    80006504:	0004b783          	ld	a5,0(s1)
    80006508:	0127b823          	sd	s2,16(a5)
  (*f1)->type = FD_PIPE;
    8000650c:	000a3783          	ld	a5,0(s4)
    80006510:	0137a023          	sw	s3,0(a5)
  (*f1)->readable = 0;
    80006514:	000a3783          	ld	a5,0(s4)
    80006518:	00078423          	sb	zero,8(a5)
  (*f1)->writable = 1;
    8000651c:	000a3783          	ld	a5,0(s4)
    80006520:	013784a3          	sb	s3,9(a5)
  (*f1)->pipe = pi;
    80006524:	000a3783          	ld	a5,0(s4)
    80006528:	0127b823          	sd	s2,16(a5)
  return 0;
    8000652c:	00000513          	li	a0,0
    80006530:	03c0006f          	j	8000656c <pipealloc+0x104>

 bad:
  if(pi)
    kfree((char*)pi);
  if(*f0)
    80006534:	0004b503          	ld	a0,0(s1)
    80006538:	00051863          	bnez	a0,80006548 <pipealloc+0xe0>
    8000653c:	0140006f          	j	80006550 <pipealloc+0xe8>
    80006540:	0004b503          	ld	a0,0(s1)
    80006544:	04050463          	beqz	a0,8000658c <pipealloc+0x124>
    fileclose(*f0);
    80006548:	00000097          	auipc	ra,0x0
    8000654c:	a94080e7          	jalr	-1388(ra) # 80005fdc <fileclose>
  if(*f1)
    80006550:	000a3783          	ld	a5,0(s4)
    fileclose(*f1);
  return -1;
    80006554:	fff00513          	li	a0,-1
  if(*f1)
    80006558:	00078a63          	beqz	a5,8000656c <pipealloc+0x104>
    fileclose(*f1);
    8000655c:	00078513          	mv	a0,a5
    80006560:	00000097          	auipc	ra,0x0
    80006564:	a7c080e7          	jalr	-1412(ra) # 80005fdc <fileclose>
  return -1;
    80006568:	fff00513          	li	a0,-1
}
    8000656c:	02813083          	ld	ra,40(sp)
    80006570:	02013403          	ld	s0,32(sp)
    80006574:	01813483          	ld	s1,24(sp)
    80006578:	01013903          	ld	s2,16(sp)
    8000657c:	00813983          	ld	s3,8(sp)
    80006580:	00013a03          	ld	s4,0(sp)
    80006584:	03010113          	addi	sp,sp,48
    80006588:	00008067          	ret
  return -1;
    8000658c:	fff00513          	li	a0,-1
    80006590:	fddff06f          	j	8000656c <pipealloc+0x104>

0000000080006594 <pipeclose>:

void
pipeclose(struct pipe *pi, int writable)
{
    80006594:	fe010113          	addi	sp,sp,-32
    80006598:	00113c23          	sd	ra,24(sp)
    8000659c:	00813823          	sd	s0,16(sp)
    800065a0:	00913423          	sd	s1,8(sp)
    800065a4:	01213023          	sd	s2,0(sp)
    800065a8:	02010413          	addi	s0,sp,32
    800065ac:	00050493          	mv	s1,a0
    800065b0:	00058913          	mv	s2,a1
  acquire(&pi->lock);
    800065b4:	ffffb097          	auipc	ra,0xffffb
    800065b8:	a18080e7          	jalr	-1512(ra) # 80000fcc <acquire>
  if(writable){
    800065bc:	04090663          	beqz	s2,80006608 <pipeclose+0x74>
    pi->writeopen = 0;
    800065c0:	2204a223          	sw	zero,548(s1)
    wakeup(&pi->nread);
    800065c4:	21848513          	addi	a0,s1,536
    800065c8:	ffffd097          	auipc	ra,0xffffd
    800065cc:	a04080e7          	jalr	-1532(ra) # 80002fcc <wakeup>
  } else {
    pi->readopen = 0;
    wakeup(&pi->nwrite);
  }
  if(pi->readopen == 0 && pi->writeopen == 0){
    800065d0:	2204b783          	ld	a5,544(s1)
    800065d4:	04079463          	bnez	a5,8000661c <pipeclose+0x88>
    release(&pi->lock);
    800065d8:	00048513          	mv	a0,s1
    800065dc:	ffffb097          	auipc	ra,0xffffb
    800065e0:	ae8080e7          	jalr	-1304(ra) # 800010c4 <release>
    kfree((char*)pi);
    800065e4:	00048513          	mv	a0,s1
    800065e8:	ffffa097          	auipc	ra,0xffffa
    800065ec:	70c080e7          	jalr	1804(ra) # 80000cf4 <kfree>
  } else
    release(&pi->lock);
}
    800065f0:	01813083          	ld	ra,24(sp)
    800065f4:	01013403          	ld	s0,16(sp)
    800065f8:	00813483          	ld	s1,8(sp)
    800065fc:	00013903          	ld	s2,0(sp)
    80006600:	02010113          	addi	sp,sp,32
    80006604:	00008067          	ret
    pi->readopen = 0;
    80006608:	2204a023          	sw	zero,544(s1)
    wakeup(&pi->nwrite);
    8000660c:	21c48513          	addi	a0,s1,540
    80006610:	ffffd097          	auipc	ra,0xffffd
    80006614:	9bc080e7          	jalr	-1604(ra) # 80002fcc <wakeup>
    80006618:	fb9ff06f          	j	800065d0 <pipeclose+0x3c>
    release(&pi->lock);
    8000661c:	00048513          	mv	a0,s1
    80006620:	ffffb097          	auipc	ra,0xffffb
    80006624:	aa4080e7          	jalr	-1372(ra) # 800010c4 <release>
}
    80006628:	fc9ff06f          	j	800065f0 <pipeclose+0x5c>

000000008000662c <pipewrite>:

int
pipewrite(struct pipe *pi, uint64 addr, int n)
{
    8000662c:	fa010113          	addi	sp,sp,-96
    80006630:	04113c23          	sd	ra,88(sp)
    80006634:	04813823          	sd	s0,80(sp)
    80006638:	04913423          	sd	s1,72(sp)
    8000663c:	05213023          	sd	s2,64(sp)
    80006640:	03313c23          	sd	s3,56(sp)
    80006644:	03413823          	sd	s4,48(sp)
    80006648:	03513423          	sd	s5,40(sp)
    8000664c:	03613023          	sd	s6,32(sp)
    80006650:	01713c23          	sd	s7,24(sp)
    80006654:	01813823          	sd	s8,16(sp)
    80006658:	06010413          	addi	s0,sp,96
    8000665c:	00050493          	mv	s1,a0
    80006660:	00058a93          	mv	s5,a1
    80006664:	00060a13          	mv	s4,a2
  int i = 0;
  struct proc *pr = myproc();
    80006668:	ffffc097          	auipc	ra,0xffffc
    8000666c:	dd4080e7          	jalr	-556(ra) # 8000243c <myproc>
    80006670:	00050993          	mv	s3,a0

  acquire(&pi->lock);
    80006674:	00048513          	mv	a0,s1
    80006678:	ffffb097          	auipc	ra,0xffffb
    8000667c:	954080e7          	jalr	-1708(ra) # 80000fcc <acquire>
  while(i < n){
    80006680:	0d405e63          	blez	s4,8000675c <pipewrite+0x130>
  int i = 0;
    80006684:	00000913          	li	s2,0
    if(pi->nwrite == pi->nread + PIPESIZE){ //DOC: pipewrite-full
      wakeup(&pi->nread);
      sleep(&pi->nwrite, &pi->lock);
    } else {
      char ch;
      if(copyin(pr->pagetable, &ch, addr + i, 1) == -1)
    80006688:	fff00b13          	li	s6,-1
      wakeup(&pi->nread);
    8000668c:	21848c13          	addi	s8,s1,536
      sleep(&pi->nwrite, &pi->lock);
    80006690:	21c48b93          	addi	s7,s1,540
    80006694:	0680006f          	j	800066fc <pipewrite+0xd0>
      release(&pi->lock);
    80006698:	00048513          	mv	a0,s1
    8000669c:	ffffb097          	auipc	ra,0xffffb
    800066a0:	a28080e7          	jalr	-1496(ra) # 800010c4 <release>
      return -1;
    800066a4:	fff00913          	li	s2,-1
  }
  wakeup(&pi->nread);
  release(&pi->lock);

  return i;
}
    800066a8:	00090513          	mv	a0,s2
    800066ac:	05813083          	ld	ra,88(sp)
    800066b0:	05013403          	ld	s0,80(sp)
    800066b4:	04813483          	ld	s1,72(sp)
    800066b8:	04013903          	ld	s2,64(sp)
    800066bc:	03813983          	ld	s3,56(sp)
    800066c0:	03013a03          	ld	s4,48(sp)
    800066c4:	02813a83          	ld	s5,40(sp)
    800066c8:	02013b03          	ld	s6,32(sp)
    800066cc:	01813b83          	ld	s7,24(sp)
    800066d0:	01013c03          	ld	s8,16(sp)
    800066d4:	06010113          	addi	sp,sp,96
    800066d8:	00008067          	ret
      wakeup(&pi->nread);
    800066dc:	000c0513          	mv	a0,s8
    800066e0:	ffffd097          	auipc	ra,0xffffd
    800066e4:	8ec080e7          	jalr	-1812(ra) # 80002fcc <wakeup>
      sleep(&pi->nwrite, &pi->lock);
    800066e8:	00048593          	mv	a1,s1
    800066ec:	000b8513          	mv	a0,s7
    800066f0:	ffffc097          	auipc	ra,0xffffc
    800066f4:	6bc080e7          	jalr	1724(ra) # 80002dac <sleep>
  while(i < n){
    800066f8:	07495463          	bge	s2,s4,80006760 <pipewrite+0x134>
    if(pi->readopen == 0 || pr->killed){
    800066fc:	2204a783          	lw	a5,544(s1)
    80006700:	f8078ce3          	beqz	a5,80006698 <pipewrite+0x6c>
    80006704:	0289a783          	lw	a5,40(s3)
    80006708:	f80798e3          	bnez	a5,80006698 <pipewrite+0x6c>
    if(pi->nwrite == pi->nread + PIPESIZE){ //DOC: pipewrite-full
    8000670c:	2184a783          	lw	a5,536(s1)
    80006710:	21c4a703          	lw	a4,540(s1)
    80006714:	2007879b          	addiw	a5,a5,512
    80006718:	fcf702e3          	beq	a4,a5,800066dc <pipewrite+0xb0>
      if(copyin(pr->pagetable, &ch, addr + i, 1) == -1)
    8000671c:	00100693          	li	a3,1
    80006720:	01590633          	add	a2,s2,s5
    80006724:	faf40593          	addi	a1,s0,-81
    80006728:	0509b503          	ld	a0,80(s3)
    8000672c:	ffffc097          	auipc	ra,0xffffc
    80006730:	900080e7          	jalr	-1792(ra) # 8000202c <copyin>
    80006734:	03650663          	beq	a0,s6,80006760 <pipewrite+0x134>
      pi->data[pi->nwrite++ % PIPESIZE] = ch;
    80006738:	21c4a783          	lw	a5,540(s1)
    8000673c:	0017871b          	addiw	a4,a5,1
    80006740:	20e4ae23          	sw	a4,540(s1)
    80006744:	1ff7f793          	andi	a5,a5,511
    80006748:	00f487b3          	add	a5,s1,a5
    8000674c:	faf44703          	lbu	a4,-81(s0)
    80006750:	00e78c23          	sb	a4,24(a5)
      i++;
    80006754:	0019091b          	addiw	s2,s2,1
    80006758:	fa1ff06f          	j	800066f8 <pipewrite+0xcc>
  int i = 0;
    8000675c:	00000913          	li	s2,0
  wakeup(&pi->nread);
    80006760:	21848513          	addi	a0,s1,536
    80006764:	ffffd097          	auipc	ra,0xffffd
    80006768:	868080e7          	jalr	-1944(ra) # 80002fcc <wakeup>
  release(&pi->lock);
    8000676c:	00048513          	mv	a0,s1
    80006770:	ffffb097          	auipc	ra,0xffffb
    80006774:	954080e7          	jalr	-1708(ra) # 800010c4 <release>
  return i;
    80006778:	f31ff06f          	j	800066a8 <pipewrite+0x7c>

000000008000677c <piperead>:

int
piperead(struct pipe *pi, uint64 addr, int n)
{
    8000677c:	fb010113          	addi	sp,sp,-80
    80006780:	04113423          	sd	ra,72(sp)
    80006784:	04813023          	sd	s0,64(sp)
    80006788:	02913c23          	sd	s1,56(sp)
    8000678c:	03213823          	sd	s2,48(sp)
    80006790:	03313423          	sd	s3,40(sp)
    80006794:	03413023          	sd	s4,32(sp)
    80006798:	01513c23          	sd	s5,24(sp)
    8000679c:	01613823          	sd	s6,16(sp)
    800067a0:	05010413          	addi	s0,sp,80
    800067a4:	00050493          	mv	s1,a0
    800067a8:	00058913          	mv	s2,a1
    800067ac:	00060a93          	mv	s5,a2
  int i;
  struct proc *pr = myproc();
    800067b0:	ffffc097          	auipc	ra,0xffffc
    800067b4:	c8c080e7          	jalr	-884(ra) # 8000243c <myproc>
    800067b8:	00050a13          	mv	s4,a0
  char ch;

  acquire(&pi->lock);
    800067bc:	00048513          	mv	a0,s1
    800067c0:	ffffb097          	auipc	ra,0xffffb
    800067c4:	80c080e7          	jalr	-2036(ra) # 80000fcc <acquire>
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    800067c8:	2184a703          	lw	a4,536(s1)
    800067cc:	21c4a783          	lw	a5,540(s1)
    if(pr->killed){
      release(&pi->lock);
      return -1;
    }
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
    800067d0:	21848993          	addi	s3,s1,536
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    800067d4:	02f71863          	bne	a4,a5,80006804 <piperead+0x88>
    800067d8:	2244a783          	lw	a5,548(s1)
    800067dc:	02078463          	beqz	a5,80006804 <piperead+0x88>
    if(pr->killed){
    800067e0:	028a2783          	lw	a5,40(s4)
    800067e4:	0c079063          	bnez	a5,800068a4 <piperead+0x128>
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
    800067e8:	00048593          	mv	a1,s1
    800067ec:	00098513          	mv	a0,s3
    800067f0:	ffffc097          	auipc	ra,0xffffc
    800067f4:	5bc080e7          	jalr	1468(ra) # 80002dac <sleep>
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    800067f8:	2184a703          	lw	a4,536(s1)
    800067fc:	21c4a783          	lw	a5,540(s1)
    80006800:	fcf70ce3          	beq	a4,a5,800067d8 <piperead+0x5c>
  }
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    80006804:	00000993          	li	s3,0
    if(pi->nread == pi->nwrite)
      break;
    ch = pi->data[pi->nread++ % PIPESIZE];
    if(copyout(pr->pagetable, addr + i, &ch, 1) == -1)
    80006808:	fff00b13          	li	s6,-1
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    8000680c:	05505a63          	blez	s5,80006860 <piperead+0xe4>
    if(pi->nread == pi->nwrite)
    80006810:	2184a783          	lw	a5,536(s1)
    80006814:	21c4a703          	lw	a4,540(s1)
    80006818:	04f70463          	beq	a4,a5,80006860 <piperead+0xe4>
    ch = pi->data[pi->nread++ % PIPESIZE];
    8000681c:	0017871b          	addiw	a4,a5,1
    80006820:	20e4ac23          	sw	a4,536(s1)
    80006824:	1ff7f793          	andi	a5,a5,511
    80006828:	00f487b3          	add	a5,s1,a5
    8000682c:	0187c783          	lbu	a5,24(a5)
    80006830:	faf40fa3          	sb	a5,-65(s0)
    if(copyout(pr->pagetable, addr + i, &ch, 1) == -1)
    80006834:	00100693          	li	a3,1
    80006838:	fbf40613          	addi	a2,s0,-65
    8000683c:	00090593          	mv	a1,s2
    80006840:	050a3503          	ld	a0,80(s4)
    80006844:	ffffb097          	auipc	ra,0xffffb
    80006848:	700080e7          	jalr	1792(ra) # 80001f44 <copyout>
    8000684c:	01650a63          	beq	a0,s6,80006860 <piperead+0xe4>
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    80006850:	0019899b          	addiw	s3,s3,1
    80006854:	00190913          	addi	s2,s2,1
    80006858:	fb3a9ce3          	bne	s5,s3,80006810 <piperead+0x94>
    8000685c:	000a8993          	mv	s3,s5
      break;
  }
  wakeup(&pi->nwrite);  //DOC: piperead-wakeup
    80006860:	21c48513          	addi	a0,s1,540
    80006864:	ffffc097          	auipc	ra,0xffffc
    80006868:	768080e7          	jalr	1896(ra) # 80002fcc <wakeup>
  release(&pi->lock);
    8000686c:	00048513          	mv	a0,s1
    80006870:	ffffb097          	auipc	ra,0xffffb
    80006874:	854080e7          	jalr	-1964(ra) # 800010c4 <release>
  return i;
}
    80006878:	00098513          	mv	a0,s3
    8000687c:	04813083          	ld	ra,72(sp)
    80006880:	04013403          	ld	s0,64(sp)
    80006884:	03813483          	ld	s1,56(sp)
    80006888:	03013903          	ld	s2,48(sp)
    8000688c:	02813983          	ld	s3,40(sp)
    80006890:	02013a03          	ld	s4,32(sp)
    80006894:	01813a83          	ld	s5,24(sp)
    80006898:	01013b03          	ld	s6,16(sp)
    8000689c:	05010113          	addi	sp,sp,80
    800068a0:	00008067          	ret
      release(&pi->lock);
    800068a4:	00048513          	mv	a0,s1
    800068a8:	ffffb097          	auipc	ra,0xffffb
    800068ac:	81c080e7          	jalr	-2020(ra) # 800010c4 <release>
      return -1;
    800068b0:	fff00993          	li	s3,-1
    800068b4:	fc5ff06f          	j	80006878 <piperead+0xfc>

00000000800068b8 <exec>:

static int loadseg(pde_t *pgdir, uint64 addr, struct inode *ip, uint offset, uint sz);

int
exec(char *path, char **argv)
{
    800068b8:	de010113          	addi	sp,sp,-544
    800068bc:	20113c23          	sd	ra,536(sp)
    800068c0:	20813823          	sd	s0,528(sp)
    800068c4:	20913423          	sd	s1,520(sp)
    800068c8:	21213023          	sd	s2,512(sp)
    800068cc:	1f313c23          	sd	s3,504(sp)
    800068d0:	1f413823          	sd	s4,496(sp)
    800068d4:	1f513423          	sd	s5,488(sp)
    800068d8:	1f613023          	sd	s6,480(sp)
    800068dc:	1d713c23          	sd	s7,472(sp)
    800068e0:	1d813823          	sd	s8,464(sp)
    800068e4:	1d913423          	sd	s9,456(sp)
    800068e8:	1da13023          	sd	s10,448(sp)
    800068ec:	1bb13c23          	sd	s11,440(sp)
    800068f0:	22010413          	addi	s0,sp,544
    800068f4:	00050913          	mv	s2,a0
    800068f8:	dea43423          	sd	a0,-536(s0)
    800068fc:	deb43823          	sd	a1,-528(s0)
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
  struct elfhdr elf;
  struct inode *ip;
  struct proghdr ph;
  pagetable_t pagetable = 0, oldpagetable;
  struct proc *p = myproc();
    80006900:	ffffc097          	auipc	ra,0xffffc
    80006904:	b3c080e7          	jalr	-1220(ra) # 8000243c <myproc>
    80006908:	00050493          	mv	s1,a0

  begin_op();
    8000690c:	fffff097          	auipc	ra,0xfffff
    80006910:	044080e7          	jalr	68(ra) # 80005950 <begin_op>

  if((ip = namei(path)) == 0){
    80006914:	00090513          	mv	a0,s2
    80006918:	fffff097          	auipc	ra,0xfffff
    8000691c:	d48080e7          	jalr	-696(ra) # 80005660 <namei>
    80006920:	08050c63          	beqz	a0,800069b8 <exec+0x100>
    80006924:	00050a93          	mv	s5,a0
    end_op();
    return -1;
  }
  ilock(ip);
    80006928:	ffffe097          	auipc	ra,0xffffe
    8000692c:	234080e7          	jalr	564(ra) # 80004b5c <ilock>

  // Check ELF header
  if(readi(ip, 0, (uint64)&elf, 0, sizeof(elf)) != sizeof(elf))
    80006930:	04000713          	li	a4,64
    80006934:	00000693          	li	a3,0
    80006938:	e5040613          	addi	a2,s0,-432
    8000693c:	00000593          	li	a1,0
    80006940:	000a8513          	mv	a0,s5
    80006944:	ffffe097          	auipc	ra,0xffffe
    80006948:	5d4080e7          	jalr	1492(ra) # 80004f18 <readi>
    8000694c:	04000793          	li	a5,64
    80006950:	00f51a63          	bne	a0,a5,80006964 <exec+0xac>
    goto bad;
  if(elf.magic != ELF_MAGIC)
    80006954:	e5042703          	lw	a4,-432(s0)
    80006958:	464c47b7          	lui	a5,0x464c4
    8000695c:	57f78793          	addi	a5,a5,1407 # 464c457f <_entry-0x39b3ba81>
    80006960:	06f70463          	beq	a4,a5,800069c8 <exec+0x110>

 bad:
  if(pagetable)
    proc_freepagetable(pagetable, sz);
  if(ip){
    iunlockput(ip);
    80006964:	000a8513          	mv	a0,s5
    80006968:	ffffe097          	auipc	ra,0xffffe
    8000696c:	530080e7          	jalr	1328(ra) # 80004e98 <iunlockput>
    end_op();
    80006970:	fffff097          	auipc	ra,0xfffff
    80006974:	094080e7          	jalr	148(ra) # 80005a04 <end_op>
  }
  return -1;
    80006978:	fff00513          	li	a0,-1
}
    8000697c:	21813083          	ld	ra,536(sp)
    80006980:	21013403          	ld	s0,528(sp)
    80006984:	20813483          	ld	s1,520(sp)
    80006988:	20013903          	ld	s2,512(sp)
    8000698c:	1f813983          	ld	s3,504(sp)
    80006990:	1f013a03          	ld	s4,496(sp)
    80006994:	1e813a83          	ld	s5,488(sp)
    80006998:	1e013b03          	ld	s6,480(sp)
    8000699c:	1d813b83          	ld	s7,472(sp)
    800069a0:	1d013c03          	ld	s8,464(sp)
    800069a4:	1c813c83          	ld	s9,456(sp)
    800069a8:	1c013d03          	ld	s10,448(sp)
    800069ac:	1b813d83          	ld	s11,440(sp)
    800069b0:	22010113          	addi	sp,sp,544
    800069b4:	00008067          	ret
    end_op();
    800069b8:	fffff097          	auipc	ra,0xfffff
    800069bc:	04c080e7          	jalr	76(ra) # 80005a04 <end_op>
    return -1;
    800069c0:	fff00513          	li	a0,-1
    800069c4:	fb9ff06f          	j	8000697c <exec+0xc4>
  if((pagetable = proc_pagetable(p)) == 0)
    800069c8:	00048513          	mv	a0,s1
    800069cc:	ffffc097          	auipc	ra,0xffffc
    800069d0:	b8c080e7          	jalr	-1140(ra) # 80002558 <proc_pagetable>
    800069d4:	00050b13          	mv	s6,a0
    800069d8:	f80506e3          	beqz	a0,80006964 <exec+0xac>
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    800069dc:	e7042783          	lw	a5,-400(s0)
    800069e0:	e8845703          	lhu	a4,-376(s0)
    800069e4:	08070863          	beqz	a4,80006a74 <exec+0x1bc>
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
    800069e8:	00000493          	li	s1,0
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    800069ec:	e0043423          	sd	zero,-504(s0)
    if((ph.vaddr % PGSIZE) != 0)
    800069f0:	00001a37          	lui	s4,0x1
    800069f4:	fffa0713          	addi	a4,s4,-1 # fff <_entry-0x7ffff001>
    800069f8:	dee43023          	sd	a4,-544(s0)
loadseg(pagetable_t pagetable, uint64 va, struct inode *ip, uint offset, uint sz)
{
  uint i, n;
  uint64 pa;

  for(i = 0; i < sz; i += PGSIZE){
    800069fc:	00001db7          	lui	s11,0x1
    80006a00:	fffffd37          	lui	s10,0xfffff
    80006a04:	2cc0006f          	j	80006cd0 <exec+0x418>
    pa = walkaddr(pagetable, va + i);
    if(pa == 0)
      panic("loadseg: address should exist");
    80006a08:	00004517          	auipc	a0,0x4
    80006a0c:	cc050513          	addi	a0,a0,-832 # 8000a6c8 <syscalls+0x280>
    80006a10:	ffffa097          	auipc	ra,0xffffa
    80006a14:	cc0080e7          	jalr	-832(ra) # 800006d0 <panic>
    if(sz - i < PGSIZE)
      n = sz - i;
    else
      n = PGSIZE;
    if(readi(ip, 0, (uint64)pa, offset+i, n) != n)
    80006a18:	00090713          	mv	a4,s2
    80006a1c:	009c86bb          	addw	a3,s9,s1
    80006a20:	00000593          	li	a1,0
    80006a24:	000a8513          	mv	a0,s5
    80006a28:	ffffe097          	auipc	ra,0xffffe
    80006a2c:	4f0080e7          	jalr	1264(ra) # 80004f18 <readi>
    80006a30:	0005051b          	sext.w	a0,a0
    80006a34:	22a91263          	bne	s2,a0,80006c58 <exec+0x3a0>
  for(i = 0; i < sz; i += PGSIZE){
    80006a38:	009d84bb          	addw	s1,s11,s1
    80006a3c:	013d09bb          	addw	s3,s10,s3
    80006a40:	2774f863          	bgeu	s1,s7,80006cb0 <exec+0x3f8>
    pa = walkaddr(pagetable, va + i);
    80006a44:	02049593          	slli	a1,s1,0x20
    80006a48:	0205d593          	srli	a1,a1,0x20
    80006a4c:	018585b3          	add	a1,a1,s8
    80006a50:	000b0513          	mv	a0,s6
    80006a54:	ffffb097          	auipc	ra,0xffffb
    80006a58:	bc4080e7          	jalr	-1084(ra) # 80001618 <walkaddr>
    80006a5c:	00050613          	mv	a2,a0
    if(pa == 0)
    80006a60:	fa0504e3          	beqz	a0,80006a08 <exec+0x150>
      n = PGSIZE;
    80006a64:	000a0913          	mv	s2,s4
    if(sz - i < PGSIZE)
    80006a68:	fb49f8e3          	bgeu	s3,s4,80006a18 <exec+0x160>
      n = sz - i;
    80006a6c:	00098913          	mv	s2,s3
    80006a70:	fa9ff06f          	j	80006a18 <exec+0x160>
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
    80006a74:	00000493          	li	s1,0
  iunlockput(ip);
    80006a78:	000a8513          	mv	a0,s5
    80006a7c:	ffffe097          	auipc	ra,0xffffe
    80006a80:	41c080e7          	jalr	1052(ra) # 80004e98 <iunlockput>
  end_op();
    80006a84:	fffff097          	auipc	ra,0xfffff
    80006a88:	f80080e7          	jalr	-128(ra) # 80005a04 <end_op>
  p = myproc();
    80006a8c:	ffffc097          	auipc	ra,0xffffc
    80006a90:	9b0080e7          	jalr	-1616(ra) # 8000243c <myproc>
    80006a94:	00050b93          	mv	s7,a0
  uint64 oldsz = p->sz;
    80006a98:	04853d03          	ld	s10,72(a0)
  sz = PGROUNDUP(sz);
    80006a9c:	000017b7          	lui	a5,0x1
    80006aa0:	fff78793          	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    80006aa4:	00f487b3          	add	a5,s1,a5
    80006aa8:	fffff737          	lui	a4,0xfffff
    80006aac:	00e7f7b3          	and	a5,a5,a4
    80006ab0:	def43c23          	sd	a5,-520(s0)
  if((sz1 = uvmalloc(pagetable, sz, sz + 2*PGSIZE)) == 0)
    80006ab4:	00002637          	lui	a2,0x2
    80006ab8:	00c78633          	add	a2,a5,a2
    80006abc:	00078593          	mv	a1,a5
    80006ac0:	000b0513          	mv	a0,s6
    80006ac4:	ffffb097          	auipc	ra,0xffffb
    80006ac8:	0e0080e7          	jalr	224(ra) # 80001ba4 <uvmalloc>
    80006acc:	00050c13          	mv	s8,a0
  ip = 0;
    80006ad0:	00000a93          	li	s5,0
  if((sz1 = uvmalloc(pagetable, sz, sz + 2*PGSIZE)) == 0)
    80006ad4:	18050263          	beqz	a0,80006c58 <exec+0x3a0>
  uvmclear(pagetable, sz-2*PGSIZE);
    80006ad8:	ffffe5b7          	lui	a1,0xffffe
    80006adc:	00b505b3          	add	a1,a0,a1
    80006ae0:	000b0513          	mv	a0,s6
    80006ae4:	ffffb097          	auipc	ra,0xffffb
    80006ae8:	414080e7          	jalr	1044(ra) # 80001ef8 <uvmclear>
  stackbase = sp - PGSIZE;
    80006aec:	fffffab7          	lui	s5,0xfffff
    80006af0:	015c0ab3          	add	s5,s8,s5
  for(argc = 0; argv[argc]; argc++) {
    80006af4:	df043783          	ld	a5,-528(s0)
    80006af8:	0007b503          	ld	a0,0(a5)
    80006afc:	08050463          	beqz	a0,80006b84 <exec+0x2cc>
    80006b00:	e9040993          	addi	s3,s0,-368
    80006b04:	f9040c93          	addi	s9,s0,-112
  sp = sz;
    80006b08:	000c0913          	mv	s2,s8
  for(argc = 0; argv[argc]; argc++) {
    80006b0c:	00000493          	li	s1,0
    sp -= strlen(argv[argc]) + 1;
    80006b10:	ffffb097          	auipc	ra,0xffffb
    80006b14:	860080e7          	jalr	-1952(ra) # 80001370 <strlen>
    80006b18:	0015079b          	addiw	a5,a0,1
    80006b1c:	40f907b3          	sub	a5,s2,a5
    sp -= sp % 16; // riscv sp must be 16-byte aligned
    80006b20:	ff07f913          	andi	s2,a5,-16
    if(sp < stackbase)
    80006b24:	17596463          	bltu	s2,s5,80006c8c <exec+0x3d4>
    if(copyout(pagetable, sp, argv[argc], strlen(argv[argc]) + 1) < 0)
    80006b28:	df043d83          	ld	s11,-528(s0)
    80006b2c:	000dba03          	ld	s4,0(s11) # 1000 <_entry-0x7ffff000>
    80006b30:	000a0513          	mv	a0,s4
    80006b34:	ffffb097          	auipc	ra,0xffffb
    80006b38:	83c080e7          	jalr	-1988(ra) # 80001370 <strlen>
    80006b3c:	0015069b          	addiw	a3,a0,1
    80006b40:	000a0613          	mv	a2,s4
    80006b44:	00090593          	mv	a1,s2
    80006b48:	000b0513          	mv	a0,s6
    80006b4c:	ffffb097          	auipc	ra,0xffffb
    80006b50:	3f8080e7          	jalr	1016(ra) # 80001f44 <copyout>
    80006b54:	14054263          	bltz	a0,80006c98 <exec+0x3e0>
    ustack[argc] = sp;
    80006b58:	0129b023          	sd	s2,0(s3)
  for(argc = 0; argv[argc]; argc++) {
    80006b5c:	00148493          	addi	s1,s1,1
    80006b60:	008d8793          	addi	a5,s11,8
    80006b64:	def43823          	sd	a5,-528(s0)
    80006b68:	008db503          	ld	a0,8(s11)
    80006b6c:	02050063          	beqz	a0,80006b8c <exec+0x2d4>
    if(argc >= MAXARG)
    80006b70:	00898993          	addi	s3,s3,8
    80006b74:	f93c9ee3          	bne	s9,s3,80006b10 <exec+0x258>
  sz = sz1;
    80006b78:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    80006b7c:	00000a93          	li	s5,0
    80006b80:	0d80006f          	j	80006c58 <exec+0x3a0>
  sp = sz;
    80006b84:	000c0913          	mv	s2,s8
  for(argc = 0; argv[argc]; argc++) {
    80006b88:	00000493          	li	s1,0
  ustack[argc] = 0;
    80006b8c:	00349793          	slli	a5,s1,0x3
    80006b90:	f9078793          	addi	a5,a5,-112
    80006b94:	008787b3          	add	a5,a5,s0
    80006b98:	f007b023          	sd	zero,-256(a5)
  sp -= (argc+1) * sizeof(uint64);
    80006b9c:	00148693          	addi	a3,s1,1
    80006ba0:	00369693          	slli	a3,a3,0x3
    80006ba4:	40d90933          	sub	s2,s2,a3
  sp -= sp % 16;
    80006ba8:	ff097913          	andi	s2,s2,-16
  if(sp < stackbase)
    80006bac:	01597863          	bgeu	s2,s5,80006bbc <exec+0x304>
  sz = sz1;
    80006bb0:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    80006bb4:	00000a93          	li	s5,0
    80006bb8:	0a00006f          	j	80006c58 <exec+0x3a0>
  if(copyout(pagetable, sp, (char *)ustack, (argc+1)*sizeof(uint64)) < 0)
    80006bbc:	e9040613          	addi	a2,s0,-368
    80006bc0:	00090593          	mv	a1,s2
    80006bc4:	000b0513          	mv	a0,s6
    80006bc8:	ffffb097          	auipc	ra,0xffffb
    80006bcc:	37c080e7          	jalr	892(ra) # 80001f44 <copyout>
    80006bd0:	0c054a63          	bltz	a0,80006ca4 <exec+0x3ec>
  p->trapframe->a1 = sp;
    80006bd4:	058bb783          	ld	a5,88(s7)
    80006bd8:	0727bc23          	sd	s2,120(a5)
  for(last=s=path; *s; s++)
    80006bdc:	de843783          	ld	a5,-536(s0)
    80006be0:	0007c703          	lbu	a4,0(a5)
    80006be4:	02070463          	beqz	a4,80006c0c <exec+0x354>
    80006be8:	00178793          	addi	a5,a5,1
    if(*s == '/')
    80006bec:	02f00693          	li	a3,47
    80006bf0:	0140006f          	j	80006c04 <exec+0x34c>
      last = s+1;
    80006bf4:	def43423          	sd	a5,-536(s0)
  for(last=s=path; *s; s++)
    80006bf8:	00178793          	addi	a5,a5,1
    80006bfc:	fff7c703          	lbu	a4,-1(a5)
    80006c00:	00070663          	beqz	a4,80006c0c <exec+0x354>
    if(*s == '/')
    80006c04:	fed71ae3          	bne	a4,a3,80006bf8 <exec+0x340>
    80006c08:	fedff06f          	j	80006bf4 <exec+0x33c>
  safestrcpy(p->name, last, sizeof(p->name));
    80006c0c:	01000613          	li	a2,16
    80006c10:	de843583          	ld	a1,-536(s0)
    80006c14:	158b8513          	addi	a0,s7,344
    80006c18:	ffffa097          	auipc	ra,0xffffa
    80006c1c:	70c080e7          	jalr	1804(ra) # 80001324 <safestrcpy>
  oldpagetable = p->pagetable;
    80006c20:	050bb503          	ld	a0,80(s7)
  p->pagetable = pagetable;
    80006c24:	056bb823          	sd	s6,80(s7)
  p->sz = sz;
    80006c28:	058bb423          	sd	s8,72(s7)
  p->trapframe->epc = elf.entry;  // initial program counter = main
    80006c2c:	058bb783          	ld	a5,88(s7)
    80006c30:	e6843703          	ld	a4,-408(s0)
    80006c34:	00e7bc23          	sd	a4,24(a5)
  p->trapframe->sp = sp; // initial stack pointer
    80006c38:	058bb783          	ld	a5,88(s7)
    80006c3c:	0327b823          	sd	s2,48(a5)
  proc_freepagetable(oldpagetable, oldsz);
    80006c40:	000d0593          	mv	a1,s10
    80006c44:	ffffc097          	auipc	ra,0xffffc
    80006c48:	9fc080e7          	jalr	-1540(ra) # 80002640 <proc_freepagetable>
  return argc; // this ends up in a0, the first argument to main(argc, argv)
    80006c4c:	0004851b          	sext.w	a0,s1
    80006c50:	d2dff06f          	j	8000697c <exec+0xc4>
    80006c54:	de943c23          	sd	s1,-520(s0)
    proc_freepagetable(pagetable, sz);
    80006c58:	df843583          	ld	a1,-520(s0)
    80006c5c:	000b0513          	mv	a0,s6
    80006c60:	ffffc097          	auipc	ra,0xffffc
    80006c64:	9e0080e7          	jalr	-1568(ra) # 80002640 <proc_freepagetable>
  if(ip){
    80006c68:	ce0a9ee3          	bnez	s5,80006964 <exec+0xac>
  return -1;
    80006c6c:	fff00513          	li	a0,-1
    80006c70:	d0dff06f          	j	8000697c <exec+0xc4>
    80006c74:	de943c23          	sd	s1,-520(s0)
    80006c78:	fe1ff06f          	j	80006c58 <exec+0x3a0>
    80006c7c:	de943c23          	sd	s1,-520(s0)
    80006c80:	fd9ff06f          	j	80006c58 <exec+0x3a0>
    80006c84:	de943c23          	sd	s1,-520(s0)
    80006c88:	fd1ff06f          	j	80006c58 <exec+0x3a0>
  sz = sz1;
    80006c8c:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    80006c90:	00000a93          	li	s5,0
    80006c94:	fc5ff06f          	j	80006c58 <exec+0x3a0>
  sz = sz1;
    80006c98:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    80006c9c:	00000a93          	li	s5,0
    80006ca0:	fb9ff06f          	j	80006c58 <exec+0x3a0>
  sz = sz1;
    80006ca4:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    80006ca8:	00000a93          	li	s5,0
    80006cac:	fadff06f          	j	80006c58 <exec+0x3a0>
    if((sz1 = uvmalloc(pagetable, sz, ph.vaddr + ph.memsz)) == 0)
    80006cb0:	df843483          	ld	s1,-520(s0)
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    80006cb4:	e0843783          	ld	a5,-504(s0)
    80006cb8:	0017869b          	addiw	a3,a5,1
    80006cbc:	e0d43423          	sd	a3,-504(s0)
    80006cc0:	e0043783          	ld	a5,-512(s0)
    80006cc4:	0387879b          	addiw	a5,a5,56
    80006cc8:	e8845703          	lhu	a4,-376(s0)
    80006ccc:	dae6d6e3          	bge	a3,a4,80006a78 <exec+0x1c0>
    if(readi(ip, 0, (uint64)&ph, off, sizeof(ph)) != sizeof(ph))
    80006cd0:	0007879b          	sext.w	a5,a5
    80006cd4:	e0f43023          	sd	a5,-512(s0)
    80006cd8:	03800713          	li	a4,56
    80006cdc:	00078693          	mv	a3,a5
    80006ce0:	e1840613          	addi	a2,s0,-488
    80006ce4:	00000593          	li	a1,0
    80006ce8:	000a8513          	mv	a0,s5
    80006cec:	ffffe097          	auipc	ra,0xffffe
    80006cf0:	22c080e7          	jalr	556(ra) # 80004f18 <readi>
    80006cf4:	03800793          	li	a5,56
    80006cf8:	f4f51ee3          	bne	a0,a5,80006c54 <exec+0x39c>
    if(ph.type != ELF_PROG_LOAD)
    80006cfc:	e1842783          	lw	a5,-488(s0)
    80006d00:	00100713          	li	a4,1
    80006d04:	fae798e3          	bne	a5,a4,80006cb4 <exec+0x3fc>
    if(ph.memsz < ph.filesz)
    80006d08:	e4043603          	ld	a2,-448(s0)
    80006d0c:	e3843783          	ld	a5,-456(s0)
    80006d10:	f6f662e3          	bltu	a2,a5,80006c74 <exec+0x3bc>
    if(ph.vaddr + ph.memsz < ph.vaddr)
    80006d14:	e2843783          	ld	a5,-472(s0)
    80006d18:	00f60633          	add	a2,a2,a5
    80006d1c:	f6f660e3          	bltu	a2,a5,80006c7c <exec+0x3c4>
    if((sz1 = uvmalloc(pagetable, sz, ph.vaddr + ph.memsz)) == 0)
    80006d20:	00048593          	mv	a1,s1
    80006d24:	000b0513          	mv	a0,s6
    80006d28:	ffffb097          	auipc	ra,0xffffb
    80006d2c:	e7c080e7          	jalr	-388(ra) # 80001ba4 <uvmalloc>
    80006d30:	dea43c23          	sd	a0,-520(s0)
    80006d34:	f40508e3          	beqz	a0,80006c84 <exec+0x3cc>
    if((ph.vaddr % PGSIZE) != 0)
    80006d38:	e2843c03          	ld	s8,-472(s0)
    80006d3c:	de043783          	ld	a5,-544(s0)
    80006d40:	00fc77b3          	and	a5,s8,a5
    80006d44:	f0079ae3          	bnez	a5,80006c58 <exec+0x3a0>
    if(loadseg(pagetable, ph.vaddr, ip, ph.off, ph.filesz) < 0)
    80006d48:	e2042c83          	lw	s9,-480(s0)
    80006d4c:	e3842b83          	lw	s7,-456(s0)
  for(i = 0; i < sz; i += PGSIZE){
    80006d50:	f60b80e3          	beqz	s7,80006cb0 <exec+0x3f8>
    80006d54:	000b8993          	mv	s3,s7
    80006d58:	00000493          	li	s1,0
    80006d5c:	ce9ff06f          	j	80006a44 <exec+0x18c>

0000000080006d60 <argfd>:

// Fetch the nth word-sized system call argument as a file descriptor
// and return both the descriptor and the corresponding struct file.
static int
argfd(int n, int *pfd, struct file **pf)
{
    80006d60:	fd010113          	addi	sp,sp,-48
    80006d64:	02113423          	sd	ra,40(sp)
    80006d68:	02813023          	sd	s0,32(sp)
    80006d6c:	00913c23          	sd	s1,24(sp)
    80006d70:	01213823          	sd	s2,16(sp)
    80006d74:	03010413          	addi	s0,sp,48
    80006d78:	00058913          	mv	s2,a1
    80006d7c:	00060493          	mv	s1,a2
  int fd;
  struct file *f;

  if(argint(n, &fd) < 0)
    80006d80:	fdc40593          	addi	a1,s0,-36
    80006d84:	ffffd097          	auipc	ra,0xffffd
    80006d88:	e10080e7          	jalr	-496(ra) # 80003b94 <argint>
    80006d8c:	04054e63          	bltz	a0,80006de8 <argfd+0x88>
    return -1;
  if(fd < 0 || fd >= NOFILE || (f=myproc()->ofile[fd]) == 0)
    80006d90:	fdc42703          	lw	a4,-36(s0)
    80006d94:	00f00793          	li	a5,15
    80006d98:	04e7ec63          	bltu	a5,a4,80006df0 <argfd+0x90>
    80006d9c:	ffffb097          	auipc	ra,0xffffb
    80006da0:	6a0080e7          	jalr	1696(ra) # 8000243c <myproc>
    80006da4:	fdc42703          	lw	a4,-36(s0)
    80006da8:	01a70793          	addi	a5,a4,26 # fffffffffffff01a <end+0xffffffff7ffd701a>
    80006dac:	00379793          	slli	a5,a5,0x3
    80006db0:	00f50533          	add	a0,a0,a5
    80006db4:	00053783          	ld	a5,0(a0)
    80006db8:	04078063          	beqz	a5,80006df8 <argfd+0x98>
    return -1;
  if(pfd)
    80006dbc:	00090463          	beqz	s2,80006dc4 <argfd+0x64>
    *pfd = fd;
    80006dc0:	00e92023          	sw	a4,0(s2)
  if(pf)
    *pf = f;
  return 0;
    80006dc4:	00000513          	li	a0,0
  if(pf)
    80006dc8:	00048463          	beqz	s1,80006dd0 <argfd+0x70>
    *pf = f;
    80006dcc:	00f4b023          	sd	a5,0(s1)
}
    80006dd0:	02813083          	ld	ra,40(sp)
    80006dd4:	02013403          	ld	s0,32(sp)
    80006dd8:	01813483          	ld	s1,24(sp)
    80006ddc:	01013903          	ld	s2,16(sp)
    80006de0:	03010113          	addi	sp,sp,48
    80006de4:	00008067          	ret
    return -1;
    80006de8:	fff00513          	li	a0,-1
    80006dec:	fe5ff06f          	j	80006dd0 <argfd+0x70>
    return -1;
    80006df0:	fff00513          	li	a0,-1
    80006df4:	fddff06f          	j	80006dd0 <argfd+0x70>
    80006df8:	fff00513          	li	a0,-1
    80006dfc:	fd5ff06f          	j	80006dd0 <argfd+0x70>

0000000080006e00 <fdalloc>:

// Allocate a file descriptor for the given file.
// Takes over file reference from caller on success.
static int
fdalloc(struct file *f)
{
    80006e00:	fe010113          	addi	sp,sp,-32
    80006e04:	00113c23          	sd	ra,24(sp)
    80006e08:	00813823          	sd	s0,16(sp)
    80006e0c:	00913423          	sd	s1,8(sp)
    80006e10:	02010413          	addi	s0,sp,32
    80006e14:	00050493          	mv	s1,a0
  int fd;
  struct proc *p = myproc();
    80006e18:	ffffb097          	auipc	ra,0xffffb
    80006e1c:	624080e7          	jalr	1572(ra) # 8000243c <myproc>
    80006e20:	00050613          	mv	a2,a0

  for(fd = 0; fd < NOFILE; fd++){
    80006e24:	0d050793          	addi	a5,a0,208
    80006e28:	00000513          	li	a0,0
    80006e2c:	01000693          	li	a3,16
    if(p->ofile[fd] == 0){
    80006e30:	0007b703          	ld	a4,0(a5)
    80006e34:	02070463          	beqz	a4,80006e5c <fdalloc+0x5c>
  for(fd = 0; fd < NOFILE; fd++){
    80006e38:	0015051b          	addiw	a0,a0,1
    80006e3c:	00878793          	addi	a5,a5,8
    80006e40:	fed518e3          	bne	a0,a3,80006e30 <fdalloc+0x30>
      p->ofile[fd] = f;
      return fd;
    }
  }
  return -1;
    80006e44:	fff00513          	li	a0,-1
}
    80006e48:	01813083          	ld	ra,24(sp)
    80006e4c:	01013403          	ld	s0,16(sp)
    80006e50:	00813483          	ld	s1,8(sp)
    80006e54:	02010113          	addi	sp,sp,32
    80006e58:	00008067          	ret
      p->ofile[fd] = f;
    80006e5c:	01a50793          	addi	a5,a0,26
    80006e60:	00379793          	slli	a5,a5,0x3
    80006e64:	00f60633          	add	a2,a2,a5
    80006e68:	00963023          	sd	s1,0(a2) # 2000 <_entry-0x7fffe000>
      return fd;
    80006e6c:	fddff06f          	j	80006e48 <fdalloc+0x48>

0000000080006e70 <create>:
  return -1;
}

static struct inode*
create(char *path, short type, short major, short minor)
{
    80006e70:	fb010113          	addi	sp,sp,-80
    80006e74:	04113423          	sd	ra,72(sp)
    80006e78:	04813023          	sd	s0,64(sp)
    80006e7c:	02913c23          	sd	s1,56(sp)
    80006e80:	03213823          	sd	s2,48(sp)
    80006e84:	03313423          	sd	s3,40(sp)
    80006e88:	03413023          	sd	s4,32(sp)
    80006e8c:	01513c23          	sd	s5,24(sp)
    80006e90:	05010413          	addi	s0,sp,80
    80006e94:	00058993          	mv	s3,a1
    80006e98:	00060a93          	mv	s5,a2
    80006e9c:	00068a13          	mv	s4,a3
  struct inode *ip, *dp;
  char name[DIRSIZ];

  if((dp = nameiparent(path, name)) == 0)
    80006ea0:	fb040593          	addi	a1,s0,-80
    80006ea4:	ffffe097          	auipc	ra,0xffffe
    80006ea8:	7ec080e7          	jalr	2028(ra) # 80005690 <nameiparent>
    80006eac:	00050913          	mv	s2,a0
    80006eb0:	18050663          	beqz	a0,8000703c <create+0x1cc>
    return 0;

  ilock(dp);
    80006eb4:	ffffe097          	auipc	ra,0xffffe
    80006eb8:	ca8080e7          	jalr	-856(ra) # 80004b5c <ilock>

  if((ip = dirlookup(dp, name, 0)) != 0){
    80006ebc:	00000613          	li	a2,0
    80006ec0:	fb040593          	addi	a1,s0,-80
    80006ec4:	00090513          	mv	a0,s2
    80006ec8:	ffffe097          	auipc	ra,0xffffe
    80006ecc:	388080e7          	jalr	904(ra) # 80005250 <dirlookup>
    80006ed0:	00050493          	mv	s1,a0
    80006ed4:	06050e63          	beqz	a0,80006f50 <create+0xe0>
    iunlockput(dp);
    80006ed8:	00090513          	mv	a0,s2
    80006edc:	ffffe097          	auipc	ra,0xffffe
    80006ee0:	fbc080e7          	jalr	-68(ra) # 80004e98 <iunlockput>
    ilock(ip);
    80006ee4:	00048513          	mv	a0,s1
    80006ee8:	ffffe097          	auipc	ra,0xffffe
    80006eec:	c74080e7          	jalr	-908(ra) # 80004b5c <ilock>
    if(type == T_FILE && (ip->type == T_FILE || ip->type == T_DEVICE))
    80006ef0:	0009899b          	sext.w	s3,s3
    80006ef4:	00200793          	li	a5,2
    80006ef8:	04f99263          	bne	s3,a5,80006f3c <create+0xcc>
    80006efc:	0444d783          	lhu	a5,68(s1)
    80006f00:	ffe7879b          	addiw	a5,a5,-2
    80006f04:	03079793          	slli	a5,a5,0x30
    80006f08:	0307d793          	srli	a5,a5,0x30
    80006f0c:	00100713          	li	a4,1
    80006f10:	02f76663          	bltu	a4,a5,80006f3c <create+0xcc>
    panic("create: dirlink");

  iunlockput(dp);

  return ip;
}
    80006f14:	00048513          	mv	a0,s1
    80006f18:	04813083          	ld	ra,72(sp)
    80006f1c:	04013403          	ld	s0,64(sp)
    80006f20:	03813483          	ld	s1,56(sp)
    80006f24:	03013903          	ld	s2,48(sp)
    80006f28:	02813983          	ld	s3,40(sp)
    80006f2c:	02013a03          	ld	s4,32(sp)
    80006f30:	01813a83          	ld	s5,24(sp)
    80006f34:	05010113          	addi	sp,sp,80
    80006f38:	00008067          	ret
    iunlockput(ip);
    80006f3c:	00048513          	mv	a0,s1
    80006f40:	ffffe097          	auipc	ra,0xffffe
    80006f44:	f58080e7          	jalr	-168(ra) # 80004e98 <iunlockput>
    return 0;
    80006f48:	00000493          	li	s1,0
    80006f4c:	fc9ff06f          	j	80006f14 <create+0xa4>
  if((ip = ialloc(dp->dev, type)) == 0)
    80006f50:	00098593          	mv	a1,s3
    80006f54:	00092503          	lw	a0,0(s2)
    80006f58:	ffffe097          	auipc	ra,0xffffe
    80006f5c:	9cc080e7          	jalr	-1588(ra) # 80004924 <ialloc>
    80006f60:	00050493          	mv	s1,a0
    80006f64:	04050c63          	beqz	a0,80006fbc <create+0x14c>
  ilock(ip);
    80006f68:	ffffe097          	auipc	ra,0xffffe
    80006f6c:	bf4080e7          	jalr	-1036(ra) # 80004b5c <ilock>
  ip->major = major;
    80006f70:	05549323          	sh	s5,70(s1)
  ip->minor = minor;
    80006f74:	05449423          	sh	s4,72(s1)
  ip->nlink = 1;
    80006f78:	00100a13          	li	s4,1
    80006f7c:	05449523          	sh	s4,74(s1)
  iupdate(ip);
    80006f80:	00048513          	mv	a0,s1
    80006f84:	ffffe097          	auipc	ra,0xffffe
    80006f88:	abc080e7          	jalr	-1348(ra) # 80004a40 <iupdate>
  if(type == T_DIR){  // Create . and .. entries.
    80006f8c:	0009899b          	sext.w	s3,s3
    80006f90:	03498e63          	beq	s3,s4,80006fcc <create+0x15c>
  if(dirlink(dp, name, ip->inum) < 0)
    80006f94:	0044a603          	lw	a2,4(s1)
    80006f98:	fb040593          	addi	a1,s0,-80
    80006f9c:	00090513          	mv	a0,s2
    80006fa0:	ffffe097          	auipc	ra,0xffffe
    80006fa4:	5ac080e7          	jalr	1452(ra) # 8000554c <dirlink>
    80006fa8:	08054263          	bltz	a0,8000702c <create+0x1bc>
  iunlockput(dp);
    80006fac:	00090513          	mv	a0,s2
    80006fb0:	ffffe097          	auipc	ra,0xffffe
    80006fb4:	ee8080e7          	jalr	-280(ra) # 80004e98 <iunlockput>
  return ip;
    80006fb8:	f5dff06f          	j	80006f14 <create+0xa4>
    panic("create: ialloc");
    80006fbc:	00003517          	auipc	a0,0x3
    80006fc0:	72c50513          	addi	a0,a0,1836 # 8000a6e8 <syscalls+0x2a0>
    80006fc4:	ffff9097          	auipc	ra,0xffff9
    80006fc8:	70c080e7          	jalr	1804(ra) # 800006d0 <panic>
    dp->nlink++;  // for ".."
    80006fcc:	04a95783          	lhu	a5,74(s2)
    80006fd0:	0017879b          	addiw	a5,a5,1
    80006fd4:	04f91523          	sh	a5,74(s2)
    iupdate(dp);
    80006fd8:	00090513          	mv	a0,s2
    80006fdc:	ffffe097          	auipc	ra,0xffffe
    80006fe0:	a64080e7          	jalr	-1436(ra) # 80004a40 <iupdate>
    if(dirlink(ip, ".", ip->inum) < 0 || dirlink(ip, "..", dp->inum) < 0)
    80006fe4:	0044a603          	lw	a2,4(s1)
    80006fe8:	00003597          	auipc	a1,0x3
    80006fec:	71058593          	addi	a1,a1,1808 # 8000a6f8 <syscalls+0x2b0>
    80006ff0:	00048513          	mv	a0,s1
    80006ff4:	ffffe097          	auipc	ra,0xffffe
    80006ff8:	558080e7          	jalr	1368(ra) # 8000554c <dirlink>
    80006ffc:	02054063          	bltz	a0,8000701c <create+0x1ac>
    80007000:	00492603          	lw	a2,4(s2)
    80007004:	00003597          	auipc	a1,0x3
    80007008:	6fc58593          	addi	a1,a1,1788 # 8000a700 <syscalls+0x2b8>
    8000700c:	00048513          	mv	a0,s1
    80007010:	ffffe097          	auipc	ra,0xffffe
    80007014:	53c080e7          	jalr	1340(ra) # 8000554c <dirlink>
    80007018:	f6055ee3          	bgez	a0,80006f94 <create+0x124>
      panic("create dots");
    8000701c:	00003517          	auipc	a0,0x3
    80007020:	6ec50513          	addi	a0,a0,1772 # 8000a708 <syscalls+0x2c0>
    80007024:	ffff9097          	auipc	ra,0xffff9
    80007028:	6ac080e7          	jalr	1708(ra) # 800006d0 <panic>
    panic("create: dirlink");
    8000702c:	00003517          	auipc	a0,0x3
    80007030:	6ec50513          	addi	a0,a0,1772 # 8000a718 <syscalls+0x2d0>
    80007034:	ffff9097          	auipc	ra,0xffff9
    80007038:	69c080e7          	jalr	1692(ra) # 800006d0 <panic>
    return 0;
    8000703c:	00050493          	mv	s1,a0
    80007040:	ed5ff06f          	j	80006f14 <create+0xa4>

0000000080007044 <sys_dup>:
{
    80007044:	fd010113          	addi	sp,sp,-48
    80007048:	02113423          	sd	ra,40(sp)
    8000704c:	02813023          	sd	s0,32(sp)
    80007050:	00913c23          	sd	s1,24(sp)
    80007054:	01213823          	sd	s2,16(sp)
    80007058:	03010413          	addi	s0,sp,48
  if(argfd(0, 0, &f) < 0)
    8000705c:	fd840613          	addi	a2,s0,-40
    80007060:	00000593          	li	a1,0
    80007064:	00000513          	li	a0,0
    80007068:	00000097          	auipc	ra,0x0
    8000706c:	cf8080e7          	jalr	-776(ra) # 80006d60 <argfd>
    return -1;
    80007070:	fff00793          	li	a5,-1
  if(argfd(0, 0, &f) < 0)
    80007074:	02054863          	bltz	a0,800070a4 <sys_dup+0x60>
  if((fd=fdalloc(f)) < 0)
    80007078:	fd843903          	ld	s2,-40(s0)
    8000707c:	00090513          	mv	a0,s2
    80007080:	00000097          	auipc	ra,0x0
    80007084:	d80080e7          	jalr	-640(ra) # 80006e00 <fdalloc>
    80007088:	00050493          	mv	s1,a0
    return -1;
    8000708c:	fff00793          	li	a5,-1
  if((fd=fdalloc(f)) < 0)
    80007090:	00054a63          	bltz	a0,800070a4 <sys_dup+0x60>
  filedup(f);
    80007094:	00090513          	mv	a0,s2
    80007098:	fffff097          	auipc	ra,0xfffff
    8000709c:	ed4080e7          	jalr	-300(ra) # 80005f6c <filedup>
  return fd;
    800070a0:	00048793          	mv	a5,s1
}
    800070a4:	00078513          	mv	a0,a5
    800070a8:	02813083          	ld	ra,40(sp)
    800070ac:	02013403          	ld	s0,32(sp)
    800070b0:	01813483          	ld	s1,24(sp)
    800070b4:	01013903          	ld	s2,16(sp)
    800070b8:	03010113          	addi	sp,sp,48
    800070bc:	00008067          	ret

00000000800070c0 <sys_read>:
{
    800070c0:	fd010113          	addi	sp,sp,-48
    800070c4:	02113423          	sd	ra,40(sp)
    800070c8:	02813023          	sd	s0,32(sp)
    800070cc:	03010413          	addi	s0,sp,48
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    800070d0:	fe840613          	addi	a2,s0,-24
    800070d4:	00000593          	li	a1,0
    800070d8:	00000513          	li	a0,0
    800070dc:	00000097          	auipc	ra,0x0
    800070e0:	c84080e7          	jalr	-892(ra) # 80006d60 <argfd>
    return -1;
    800070e4:	fff00793          	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    800070e8:	04054663          	bltz	a0,80007134 <sys_read+0x74>
    800070ec:	fe440593          	addi	a1,s0,-28
    800070f0:	00200513          	li	a0,2
    800070f4:	ffffd097          	auipc	ra,0xffffd
    800070f8:	aa0080e7          	jalr	-1376(ra) # 80003b94 <argint>
    return -1;
    800070fc:	fff00793          	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    80007100:	02054a63          	bltz	a0,80007134 <sys_read+0x74>
    80007104:	fd840593          	addi	a1,s0,-40
    80007108:	00100513          	li	a0,1
    8000710c:	ffffd097          	auipc	ra,0xffffd
    80007110:	ac4080e7          	jalr	-1340(ra) # 80003bd0 <argaddr>
    return -1;
    80007114:	fff00793          	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    80007118:	00054e63          	bltz	a0,80007134 <sys_read+0x74>
  return fileread(f, p, n);
    8000711c:	fe442603          	lw	a2,-28(s0)
    80007120:	fd843583          	ld	a1,-40(s0)
    80007124:	fe843503          	ld	a0,-24(s0)
    80007128:	fffff097          	auipc	ra,0xfffff
    8000712c:	060080e7          	jalr	96(ra) # 80006188 <fileread>
    80007130:	00050793          	mv	a5,a0
}
    80007134:	00078513          	mv	a0,a5
    80007138:	02813083          	ld	ra,40(sp)
    8000713c:	02013403          	ld	s0,32(sp)
    80007140:	03010113          	addi	sp,sp,48
    80007144:	00008067          	ret

0000000080007148 <sys_write>:
{
    80007148:	fd010113          	addi	sp,sp,-48
    8000714c:	02113423          	sd	ra,40(sp)
    80007150:	02813023          	sd	s0,32(sp)
    80007154:	03010413          	addi	s0,sp,48
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    80007158:	fe840613          	addi	a2,s0,-24
    8000715c:	00000593          	li	a1,0
    80007160:	00000513          	li	a0,0
    80007164:	00000097          	auipc	ra,0x0
    80007168:	bfc080e7          	jalr	-1028(ra) # 80006d60 <argfd>
    return -1;
    8000716c:	fff00793          	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    80007170:	04054663          	bltz	a0,800071bc <sys_write+0x74>
    80007174:	fe440593          	addi	a1,s0,-28
    80007178:	00200513          	li	a0,2
    8000717c:	ffffd097          	auipc	ra,0xffffd
    80007180:	a18080e7          	jalr	-1512(ra) # 80003b94 <argint>
    return -1;
    80007184:	fff00793          	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    80007188:	02054a63          	bltz	a0,800071bc <sys_write+0x74>
    8000718c:	fd840593          	addi	a1,s0,-40
    80007190:	00100513          	li	a0,1
    80007194:	ffffd097          	auipc	ra,0xffffd
    80007198:	a3c080e7          	jalr	-1476(ra) # 80003bd0 <argaddr>
    return -1;
    8000719c:	fff00793          	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    800071a0:	00054e63          	bltz	a0,800071bc <sys_write+0x74>
  return filewrite(f, p, n);
    800071a4:	fe442603          	lw	a2,-28(s0)
    800071a8:	fd843583          	ld	a1,-40(s0)
    800071ac:	fe843503          	ld	a0,-24(s0)
    800071b0:	fffff097          	auipc	ra,0xfffff
    800071b4:	104080e7          	jalr	260(ra) # 800062b4 <filewrite>
    800071b8:	00050793          	mv	a5,a0
}
    800071bc:	00078513          	mv	a0,a5
    800071c0:	02813083          	ld	ra,40(sp)
    800071c4:	02013403          	ld	s0,32(sp)
    800071c8:	03010113          	addi	sp,sp,48
    800071cc:	00008067          	ret

00000000800071d0 <sys_close>:
{
    800071d0:	fe010113          	addi	sp,sp,-32
    800071d4:	00113c23          	sd	ra,24(sp)
    800071d8:	00813823          	sd	s0,16(sp)
    800071dc:	02010413          	addi	s0,sp,32
  if(argfd(0, &fd, &f) < 0)
    800071e0:	fe040613          	addi	a2,s0,-32
    800071e4:	fec40593          	addi	a1,s0,-20
    800071e8:	00000513          	li	a0,0
    800071ec:	00000097          	auipc	ra,0x0
    800071f0:	b74080e7          	jalr	-1164(ra) # 80006d60 <argfd>
    return -1;
    800071f4:	fff00793          	li	a5,-1
  if(argfd(0, &fd, &f) < 0)
    800071f8:	02054863          	bltz	a0,80007228 <sys_close+0x58>
  myproc()->ofile[fd] = 0;
    800071fc:	ffffb097          	auipc	ra,0xffffb
    80007200:	240080e7          	jalr	576(ra) # 8000243c <myproc>
    80007204:	fec42783          	lw	a5,-20(s0)
    80007208:	01a78793          	addi	a5,a5,26
    8000720c:	00379793          	slli	a5,a5,0x3
    80007210:	00f50533          	add	a0,a0,a5
    80007214:	00053023          	sd	zero,0(a0)
  fileclose(f);
    80007218:	fe043503          	ld	a0,-32(s0)
    8000721c:	fffff097          	auipc	ra,0xfffff
    80007220:	dc0080e7          	jalr	-576(ra) # 80005fdc <fileclose>
  return 0;
    80007224:	00000793          	li	a5,0
}
    80007228:	00078513          	mv	a0,a5
    8000722c:	01813083          	ld	ra,24(sp)
    80007230:	01013403          	ld	s0,16(sp)
    80007234:	02010113          	addi	sp,sp,32
    80007238:	00008067          	ret

000000008000723c <sys_fstat>:
{
    8000723c:	fe010113          	addi	sp,sp,-32
    80007240:	00113c23          	sd	ra,24(sp)
    80007244:	00813823          	sd	s0,16(sp)
    80007248:	02010413          	addi	s0,sp,32
  if(argfd(0, 0, &f) < 0 || argaddr(1, &st) < 0)
    8000724c:	fe840613          	addi	a2,s0,-24
    80007250:	00000593          	li	a1,0
    80007254:	00000513          	li	a0,0
    80007258:	00000097          	auipc	ra,0x0
    8000725c:	b08080e7          	jalr	-1272(ra) # 80006d60 <argfd>
    return -1;
    80007260:	fff00793          	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argaddr(1, &st) < 0)
    80007264:	02054863          	bltz	a0,80007294 <sys_fstat+0x58>
    80007268:	fe040593          	addi	a1,s0,-32
    8000726c:	00100513          	li	a0,1
    80007270:	ffffd097          	auipc	ra,0xffffd
    80007274:	960080e7          	jalr	-1696(ra) # 80003bd0 <argaddr>
    return -1;
    80007278:	fff00793          	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argaddr(1, &st) < 0)
    8000727c:	00054c63          	bltz	a0,80007294 <sys_fstat+0x58>
  return filestat(f, st);
    80007280:	fe043583          	ld	a1,-32(s0)
    80007284:	fe843503          	ld	a0,-24(s0)
    80007288:	fffff097          	auipc	ra,0xfffff
    8000728c:	e58080e7          	jalr	-424(ra) # 800060e0 <filestat>
    80007290:	00050793          	mv	a5,a0
}
    80007294:	00078513          	mv	a0,a5
    80007298:	01813083          	ld	ra,24(sp)
    8000729c:	01013403          	ld	s0,16(sp)
    800072a0:	02010113          	addi	sp,sp,32
    800072a4:	00008067          	ret

00000000800072a8 <sys_link>:
{
    800072a8:	ed010113          	addi	sp,sp,-304
    800072ac:	12113423          	sd	ra,296(sp)
    800072b0:	12813023          	sd	s0,288(sp)
    800072b4:	10913c23          	sd	s1,280(sp)
    800072b8:	11213823          	sd	s2,272(sp)
    800072bc:	13010413          	addi	s0,sp,304
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    800072c0:	08000613          	li	a2,128
    800072c4:	ed040593          	addi	a1,s0,-304
    800072c8:	00000513          	li	a0,0
    800072cc:	ffffd097          	auipc	ra,0xffffd
    800072d0:	940080e7          	jalr	-1728(ra) # 80003c0c <argstr>
    return -1;
    800072d4:	fff00793          	li	a5,-1
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    800072d8:	14054a63          	bltz	a0,8000742c <sys_link+0x184>
    800072dc:	08000613          	li	a2,128
    800072e0:	f5040593          	addi	a1,s0,-176
    800072e4:	00100513          	li	a0,1
    800072e8:	ffffd097          	auipc	ra,0xffffd
    800072ec:	924080e7          	jalr	-1756(ra) # 80003c0c <argstr>
    return -1;
    800072f0:	fff00793          	li	a5,-1
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    800072f4:	12054c63          	bltz	a0,8000742c <sys_link+0x184>
  begin_op();
    800072f8:	ffffe097          	auipc	ra,0xffffe
    800072fc:	658080e7          	jalr	1624(ra) # 80005950 <begin_op>
  if((ip = namei(old)) == 0){
    80007300:	ed040513          	addi	a0,s0,-304
    80007304:	ffffe097          	auipc	ra,0xffffe
    80007308:	35c080e7          	jalr	860(ra) # 80005660 <namei>
    8000730c:	00050493          	mv	s1,a0
    80007310:	0a050463          	beqz	a0,800073b8 <sys_link+0x110>
  ilock(ip);
    80007314:	ffffe097          	auipc	ra,0xffffe
    80007318:	848080e7          	jalr	-1976(ra) # 80004b5c <ilock>
  if(ip->type == T_DIR){
    8000731c:	04449703          	lh	a4,68(s1)
    80007320:	00100793          	li	a5,1
    80007324:	0af70263          	beq	a4,a5,800073c8 <sys_link+0x120>
  ip->nlink++;
    80007328:	04a4d783          	lhu	a5,74(s1)
    8000732c:	0017879b          	addiw	a5,a5,1
    80007330:	04f49523          	sh	a5,74(s1)
  iupdate(ip);
    80007334:	00048513          	mv	a0,s1
    80007338:	ffffd097          	auipc	ra,0xffffd
    8000733c:	708080e7          	jalr	1800(ra) # 80004a40 <iupdate>
  iunlock(ip);
    80007340:	00048513          	mv	a0,s1
    80007344:	ffffe097          	auipc	ra,0xffffe
    80007348:	91c080e7          	jalr	-1764(ra) # 80004c60 <iunlock>
  if((dp = nameiparent(new, name)) == 0)
    8000734c:	fd040593          	addi	a1,s0,-48
    80007350:	f5040513          	addi	a0,s0,-176
    80007354:	ffffe097          	auipc	ra,0xffffe
    80007358:	33c080e7          	jalr	828(ra) # 80005690 <nameiparent>
    8000735c:	00050913          	mv	s2,a0
    80007360:	08050863          	beqz	a0,800073f0 <sys_link+0x148>
  ilock(dp);
    80007364:	ffffd097          	auipc	ra,0xffffd
    80007368:	7f8080e7          	jalr	2040(ra) # 80004b5c <ilock>
  if(dp->dev != ip->dev || dirlink(dp, name, ip->inum) < 0){
    8000736c:	00092703          	lw	a4,0(s2)
    80007370:	0004a783          	lw	a5,0(s1)
    80007374:	06f71863          	bne	a4,a5,800073e4 <sys_link+0x13c>
    80007378:	0044a603          	lw	a2,4(s1)
    8000737c:	fd040593          	addi	a1,s0,-48
    80007380:	00090513          	mv	a0,s2
    80007384:	ffffe097          	auipc	ra,0xffffe
    80007388:	1c8080e7          	jalr	456(ra) # 8000554c <dirlink>
    8000738c:	04054c63          	bltz	a0,800073e4 <sys_link+0x13c>
  iunlockput(dp);
    80007390:	00090513          	mv	a0,s2
    80007394:	ffffe097          	auipc	ra,0xffffe
    80007398:	b04080e7          	jalr	-1276(ra) # 80004e98 <iunlockput>
  iput(ip);
    8000739c:	00048513          	mv	a0,s1
    800073a0:	ffffe097          	auipc	ra,0xffffe
    800073a4:	a1c080e7          	jalr	-1508(ra) # 80004dbc <iput>
  end_op();
    800073a8:	ffffe097          	auipc	ra,0xffffe
    800073ac:	65c080e7          	jalr	1628(ra) # 80005a04 <end_op>
  return 0;
    800073b0:	00000793          	li	a5,0
    800073b4:	0780006f          	j	8000742c <sys_link+0x184>
    end_op();
    800073b8:	ffffe097          	auipc	ra,0xffffe
    800073bc:	64c080e7          	jalr	1612(ra) # 80005a04 <end_op>
    return -1;
    800073c0:	fff00793          	li	a5,-1
    800073c4:	0680006f          	j	8000742c <sys_link+0x184>
    iunlockput(ip);
    800073c8:	00048513          	mv	a0,s1
    800073cc:	ffffe097          	auipc	ra,0xffffe
    800073d0:	acc080e7          	jalr	-1332(ra) # 80004e98 <iunlockput>
    end_op();
    800073d4:	ffffe097          	auipc	ra,0xffffe
    800073d8:	630080e7          	jalr	1584(ra) # 80005a04 <end_op>
    return -1;
    800073dc:	fff00793          	li	a5,-1
    800073e0:	04c0006f          	j	8000742c <sys_link+0x184>
    iunlockput(dp);
    800073e4:	00090513          	mv	a0,s2
    800073e8:	ffffe097          	auipc	ra,0xffffe
    800073ec:	ab0080e7          	jalr	-1360(ra) # 80004e98 <iunlockput>
  ilock(ip);
    800073f0:	00048513          	mv	a0,s1
    800073f4:	ffffd097          	auipc	ra,0xffffd
    800073f8:	768080e7          	jalr	1896(ra) # 80004b5c <ilock>
  ip->nlink--;
    800073fc:	04a4d783          	lhu	a5,74(s1)
    80007400:	fff7879b          	addiw	a5,a5,-1
    80007404:	04f49523          	sh	a5,74(s1)
  iupdate(ip);
    80007408:	00048513          	mv	a0,s1
    8000740c:	ffffd097          	auipc	ra,0xffffd
    80007410:	634080e7          	jalr	1588(ra) # 80004a40 <iupdate>
  iunlockput(ip);
    80007414:	00048513          	mv	a0,s1
    80007418:	ffffe097          	auipc	ra,0xffffe
    8000741c:	a80080e7          	jalr	-1408(ra) # 80004e98 <iunlockput>
  end_op();
    80007420:	ffffe097          	auipc	ra,0xffffe
    80007424:	5e4080e7          	jalr	1508(ra) # 80005a04 <end_op>
  return -1;
    80007428:	fff00793          	li	a5,-1
}
    8000742c:	00078513          	mv	a0,a5
    80007430:	12813083          	ld	ra,296(sp)
    80007434:	12013403          	ld	s0,288(sp)
    80007438:	11813483          	ld	s1,280(sp)
    8000743c:	11013903          	ld	s2,272(sp)
    80007440:	13010113          	addi	sp,sp,304
    80007444:	00008067          	ret

0000000080007448 <sys_unlink>:
{
    80007448:	f1010113          	addi	sp,sp,-240
    8000744c:	0e113423          	sd	ra,232(sp)
    80007450:	0e813023          	sd	s0,224(sp)
    80007454:	0c913c23          	sd	s1,216(sp)
    80007458:	0d213823          	sd	s2,208(sp)
    8000745c:	0d313423          	sd	s3,200(sp)
    80007460:	0f010413          	addi	s0,sp,240
  if(argstr(0, path, MAXPATH) < 0)
    80007464:	08000613          	li	a2,128
    80007468:	f3040593          	addi	a1,s0,-208
    8000746c:	00000513          	li	a0,0
    80007470:	ffffc097          	auipc	ra,0xffffc
    80007474:	79c080e7          	jalr	1948(ra) # 80003c0c <argstr>
    80007478:	1c054063          	bltz	a0,80007638 <sys_unlink+0x1f0>
  begin_op();
    8000747c:	ffffe097          	auipc	ra,0xffffe
    80007480:	4d4080e7          	jalr	1236(ra) # 80005950 <begin_op>
  if((dp = nameiparent(path, name)) == 0){
    80007484:	fb040593          	addi	a1,s0,-80
    80007488:	f3040513          	addi	a0,s0,-208
    8000748c:	ffffe097          	auipc	ra,0xffffe
    80007490:	204080e7          	jalr	516(ra) # 80005690 <nameiparent>
    80007494:	00050493          	mv	s1,a0
    80007498:	0e050c63          	beqz	a0,80007590 <sys_unlink+0x148>
  ilock(dp);
    8000749c:	ffffd097          	auipc	ra,0xffffd
    800074a0:	6c0080e7          	jalr	1728(ra) # 80004b5c <ilock>
  if(namecmp(name, ".") == 0 || namecmp(name, "..") == 0)
    800074a4:	00003597          	auipc	a1,0x3
    800074a8:	25458593          	addi	a1,a1,596 # 8000a6f8 <syscalls+0x2b0>
    800074ac:	fb040513          	addi	a0,s0,-80
    800074b0:	ffffe097          	auipc	ra,0xffffe
    800074b4:	d74080e7          	jalr	-652(ra) # 80005224 <namecmp>
    800074b8:	18050a63          	beqz	a0,8000764c <sys_unlink+0x204>
    800074bc:	00003597          	auipc	a1,0x3
    800074c0:	24458593          	addi	a1,a1,580 # 8000a700 <syscalls+0x2b8>
    800074c4:	fb040513          	addi	a0,s0,-80
    800074c8:	ffffe097          	auipc	ra,0xffffe
    800074cc:	d5c080e7          	jalr	-676(ra) # 80005224 <namecmp>
    800074d0:	16050e63          	beqz	a0,8000764c <sys_unlink+0x204>
  if((ip = dirlookup(dp, name, &off)) == 0)
    800074d4:	f2c40613          	addi	a2,s0,-212
    800074d8:	fb040593          	addi	a1,s0,-80
    800074dc:	00048513          	mv	a0,s1
    800074e0:	ffffe097          	auipc	ra,0xffffe
    800074e4:	d70080e7          	jalr	-656(ra) # 80005250 <dirlookup>
    800074e8:	00050913          	mv	s2,a0
    800074ec:	16050063          	beqz	a0,8000764c <sys_unlink+0x204>
  ilock(ip);
    800074f0:	ffffd097          	auipc	ra,0xffffd
    800074f4:	66c080e7          	jalr	1644(ra) # 80004b5c <ilock>
  if(ip->nlink < 1)
    800074f8:	04a91783          	lh	a5,74(s2)
    800074fc:	0af05263          	blez	a5,800075a0 <sys_unlink+0x158>
  if(ip->type == T_DIR && !isdirempty(ip)){
    80007500:	04491703          	lh	a4,68(s2)
    80007504:	00100793          	li	a5,1
    80007508:	0af70463          	beq	a4,a5,800075b0 <sys_unlink+0x168>
  memset(&de, 0, sizeof(de));
    8000750c:	01000613          	li	a2,16
    80007510:	00000593          	li	a1,0
    80007514:	fc040513          	addi	a0,s0,-64
    80007518:	ffffa097          	auipc	ra,0xffffa
    8000751c:	c0c080e7          	jalr	-1012(ra) # 80001124 <memset>
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80007520:	01000713          	li	a4,16
    80007524:	f2c42683          	lw	a3,-212(s0)
    80007528:	fc040613          	addi	a2,s0,-64
    8000752c:	00000593          	li	a1,0
    80007530:	00048513          	mv	a0,s1
    80007534:	ffffe097          	auipc	ra,0xffffe
    80007538:	b54080e7          	jalr	-1196(ra) # 80005088 <writei>
    8000753c:	01000793          	li	a5,16
    80007540:	0cf51663          	bne	a0,a5,8000760c <sys_unlink+0x1c4>
  if(ip->type == T_DIR){
    80007544:	04491703          	lh	a4,68(s2)
    80007548:	00100793          	li	a5,1
    8000754c:	0cf70863          	beq	a4,a5,8000761c <sys_unlink+0x1d4>
  iunlockput(dp);
    80007550:	00048513          	mv	a0,s1
    80007554:	ffffe097          	auipc	ra,0xffffe
    80007558:	944080e7          	jalr	-1724(ra) # 80004e98 <iunlockput>
  ip->nlink--;
    8000755c:	04a95783          	lhu	a5,74(s2)
    80007560:	fff7879b          	addiw	a5,a5,-1
    80007564:	04f91523          	sh	a5,74(s2)
  iupdate(ip);
    80007568:	00090513          	mv	a0,s2
    8000756c:	ffffd097          	auipc	ra,0xffffd
    80007570:	4d4080e7          	jalr	1236(ra) # 80004a40 <iupdate>
  iunlockput(ip);
    80007574:	00090513          	mv	a0,s2
    80007578:	ffffe097          	auipc	ra,0xffffe
    8000757c:	920080e7          	jalr	-1760(ra) # 80004e98 <iunlockput>
  end_op();
    80007580:	ffffe097          	auipc	ra,0xffffe
    80007584:	484080e7          	jalr	1156(ra) # 80005a04 <end_op>
  return 0;
    80007588:	00000513          	li	a0,0
    8000758c:	0d80006f          	j	80007664 <sys_unlink+0x21c>
    end_op();
    80007590:	ffffe097          	auipc	ra,0xffffe
    80007594:	474080e7          	jalr	1140(ra) # 80005a04 <end_op>
    return -1;
    80007598:	fff00513          	li	a0,-1
    8000759c:	0c80006f          	j	80007664 <sys_unlink+0x21c>
    panic("unlink: nlink < 1");
    800075a0:	00003517          	auipc	a0,0x3
    800075a4:	18850513          	addi	a0,a0,392 # 8000a728 <syscalls+0x2e0>
    800075a8:	ffff9097          	auipc	ra,0xffff9
    800075ac:	128080e7          	jalr	296(ra) # 800006d0 <panic>
  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    800075b0:	04c92703          	lw	a4,76(s2)
    800075b4:	02000793          	li	a5,32
    800075b8:	f4e7fae3          	bgeu	a5,a4,8000750c <sys_unlink+0xc4>
    800075bc:	02000993          	li	s3,32
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    800075c0:	01000713          	li	a4,16
    800075c4:	00098693          	mv	a3,s3
    800075c8:	f1840613          	addi	a2,s0,-232
    800075cc:	00000593          	li	a1,0
    800075d0:	00090513          	mv	a0,s2
    800075d4:	ffffe097          	auipc	ra,0xffffe
    800075d8:	944080e7          	jalr	-1724(ra) # 80004f18 <readi>
    800075dc:	01000793          	li	a5,16
    800075e0:	00f51e63          	bne	a0,a5,800075fc <sys_unlink+0x1b4>
    if(de.inum != 0)
    800075e4:	f1845783          	lhu	a5,-232(s0)
    800075e8:	04079c63          	bnez	a5,80007640 <sys_unlink+0x1f8>
  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    800075ec:	0109899b          	addiw	s3,s3,16
    800075f0:	04c92783          	lw	a5,76(s2)
    800075f4:	fcf9e6e3          	bltu	s3,a5,800075c0 <sys_unlink+0x178>
    800075f8:	f15ff06f          	j	8000750c <sys_unlink+0xc4>
      panic("isdirempty: readi");
    800075fc:	00003517          	auipc	a0,0x3
    80007600:	14450513          	addi	a0,a0,324 # 8000a740 <syscalls+0x2f8>
    80007604:	ffff9097          	auipc	ra,0xffff9
    80007608:	0cc080e7          	jalr	204(ra) # 800006d0 <panic>
    panic("unlink: writei");
    8000760c:	00003517          	auipc	a0,0x3
    80007610:	14c50513          	addi	a0,a0,332 # 8000a758 <syscalls+0x310>
    80007614:	ffff9097          	auipc	ra,0xffff9
    80007618:	0bc080e7          	jalr	188(ra) # 800006d0 <panic>
    dp->nlink--;
    8000761c:	04a4d783          	lhu	a5,74(s1)
    80007620:	fff7879b          	addiw	a5,a5,-1
    80007624:	04f49523          	sh	a5,74(s1)
    iupdate(dp);
    80007628:	00048513          	mv	a0,s1
    8000762c:	ffffd097          	auipc	ra,0xffffd
    80007630:	414080e7          	jalr	1044(ra) # 80004a40 <iupdate>
    80007634:	f1dff06f          	j	80007550 <sys_unlink+0x108>
    return -1;
    80007638:	fff00513          	li	a0,-1
    8000763c:	0280006f          	j	80007664 <sys_unlink+0x21c>
    iunlockput(ip);
    80007640:	00090513          	mv	a0,s2
    80007644:	ffffe097          	auipc	ra,0xffffe
    80007648:	854080e7          	jalr	-1964(ra) # 80004e98 <iunlockput>
  iunlockput(dp);
    8000764c:	00048513          	mv	a0,s1
    80007650:	ffffe097          	auipc	ra,0xffffe
    80007654:	848080e7          	jalr	-1976(ra) # 80004e98 <iunlockput>
  end_op();
    80007658:	ffffe097          	auipc	ra,0xffffe
    8000765c:	3ac080e7          	jalr	940(ra) # 80005a04 <end_op>
  return -1;
    80007660:	fff00513          	li	a0,-1
}
    80007664:	0e813083          	ld	ra,232(sp)
    80007668:	0e013403          	ld	s0,224(sp)
    8000766c:	0d813483          	ld	s1,216(sp)
    80007670:	0d013903          	ld	s2,208(sp)
    80007674:	0c813983          	ld	s3,200(sp)
    80007678:	0f010113          	addi	sp,sp,240
    8000767c:	00008067          	ret

0000000080007680 <sys_open>:

uint64
sys_open(void)
{
    80007680:	f4010113          	addi	sp,sp,-192
    80007684:	0a113c23          	sd	ra,184(sp)
    80007688:	0a813823          	sd	s0,176(sp)
    8000768c:	0a913423          	sd	s1,168(sp)
    80007690:	0b213023          	sd	s2,160(sp)
    80007694:	09313c23          	sd	s3,152(sp)
    80007698:	0c010413          	addi	s0,sp,192
  int fd, omode;
  struct file *f;
  struct inode *ip;
  int n;

  if((n = argstr(0, path, MAXPATH)) < 0 || argint(1, &omode) < 0)
    8000769c:	08000613          	li	a2,128
    800076a0:	f5040593          	addi	a1,s0,-176
    800076a4:	00000513          	li	a0,0
    800076a8:	ffffc097          	auipc	ra,0xffffc
    800076ac:	564080e7          	jalr	1380(ra) # 80003c0c <argstr>
    return -1;
    800076b0:	fff00493          	li	s1,-1
  if((n = argstr(0, path, MAXPATH)) < 0 || argint(1, &omode) < 0)
    800076b4:	0e054263          	bltz	a0,80007798 <sys_open+0x118>
    800076b8:	f4c40593          	addi	a1,s0,-180
    800076bc:	00100513          	li	a0,1
    800076c0:	ffffc097          	auipc	ra,0xffffc
    800076c4:	4d4080e7          	jalr	1236(ra) # 80003b94 <argint>
    800076c8:	0c054863          	bltz	a0,80007798 <sys_open+0x118>

  begin_op();
    800076cc:	ffffe097          	auipc	ra,0xffffe
    800076d0:	284080e7          	jalr	644(ra) # 80005950 <begin_op>

  if(omode & O_CREATE){
    800076d4:	f4c42783          	lw	a5,-180(s0)
    800076d8:	2007f793          	andi	a5,a5,512
    800076dc:	0e078463          	beqz	a5,800077c4 <sys_open+0x144>
    ip = create(path, T_FILE, 0, 0);
    800076e0:	00000693          	li	a3,0
    800076e4:	00000613          	li	a2,0
    800076e8:	00200593          	li	a1,2
    800076ec:	f5040513          	addi	a0,s0,-176
    800076f0:	fffff097          	auipc	ra,0xfffff
    800076f4:	780080e7          	jalr	1920(ra) # 80006e70 <create>
    800076f8:	00050913          	mv	s2,a0
    if(ip == 0){
    800076fc:	0a050e63          	beqz	a0,800077b8 <sys_open+0x138>
      end_op();
      return -1;
    }
  }

  if(ip->type == T_DEVICE && (ip->major < 0 || ip->major >= NDEV)){
    80007700:	04491703          	lh	a4,68(s2)
    80007704:	00300793          	li	a5,3
    80007708:	00f71863          	bne	a4,a5,80007718 <sys_open+0x98>
    8000770c:	04695703          	lhu	a4,70(s2)
    80007710:	00900793          	li	a5,9
    80007714:	10e7e663          	bltu	a5,a4,80007820 <sys_open+0x1a0>
    iunlockput(ip);
    end_op();
    return -1;
  }

  if((f = filealloc()) == 0 || (fd = fdalloc(f)) < 0){
    80007718:	ffffe097          	auipc	ra,0xffffe
    8000771c:	7c8080e7          	jalr	1992(ra) # 80005ee0 <filealloc>
    80007720:	00050993          	mv	s3,a0
    80007724:	14050263          	beqz	a0,80007868 <sys_open+0x1e8>
    80007728:	fffff097          	auipc	ra,0xfffff
    8000772c:	6d8080e7          	jalr	1752(ra) # 80006e00 <fdalloc>
    80007730:	00050493          	mv	s1,a0
    80007734:	12054463          	bltz	a0,8000785c <sys_open+0x1dc>
    iunlockput(ip);
    end_op();
    return -1;
  }

  if(ip->type == T_DEVICE){
    80007738:	04491703          	lh	a4,68(s2)
    8000773c:	00300793          	li	a5,3
    80007740:	0ef70e63          	beq	a4,a5,8000783c <sys_open+0x1bc>
    f->type = FD_DEVICE;
    f->major = ip->major;
  } else {
    f->type = FD_INODE;
    80007744:	00200793          	li	a5,2
    80007748:	00f9a023          	sw	a5,0(s3)
    f->off = 0;
    8000774c:	0209a023          	sw	zero,32(s3)
  }
  f->ip = ip;
    80007750:	0129bc23          	sd	s2,24(s3)
  f->readable = !(omode & O_WRONLY);
    80007754:	f4c42783          	lw	a5,-180(s0)
    80007758:	0017c713          	xori	a4,a5,1
    8000775c:	00177713          	andi	a4,a4,1
    80007760:	00e98423          	sb	a4,8(s3)
  f->writable = (omode & O_WRONLY) || (omode & O_RDWR);
    80007764:	0037f713          	andi	a4,a5,3
    80007768:	00e03733          	snez	a4,a4
    8000776c:	00e984a3          	sb	a4,9(s3)

  if((omode & O_TRUNC) && ip->type == T_FILE){
    80007770:	4007f793          	andi	a5,a5,1024
    80007774:	00078863          	beqz	a5,80007784 <sys_open+0x104>
    80007778:	04491703          	lh	a4,68(s2)
    8000777c:	00200793          	li	a5,2
    80007780:	0cf70663          	beq	a4,a5,8000784c <sys_open+0x1cc>
    itrunc(ip);
  }

  iunlock(ip);
    80007784:	00090513          	mv	a0,s2
    80007788:	ffffd097          	auipc	ra,0xffffd
    8000778c:	4d8080e7          	jalr	1240(ra) # 80004c60 <iunlock>
  end_op();
    80007790:	ffffe097          	auipc	ra,0xffffe
    80007794:	274080e7          	jalr	628(ra) # 80005a04 <end_op>

  return fd;
}
    80007798:	00048513          	mv	a0,s1
    8000779c:	0b813083          	ld	ra,184(sp)
    800077a0:	0b013403          	ld	s0,176(sp)
    800077a4:	0a813483          	ld	s1,168(sp)
    800077a8:	0a013903          	ld	s2,160(sp)
    800077ac:	09813983          	ld	s3,152(sp)
    800077b0:	0c010113          	addi	sp,sp,192
    800077b4:	00008067          	ret
      end_op();
    800077b8:	ffffe097          	auipc	ra,0xffffe
    800077bc:	24c080e7          	jalr	588(ra) # 80005a04 <end_op>
      return -1;
    800077c0:	fd9ff06f          	j	80007798 <sys_open+0x118>
    if((ip = namei(path)) == 0){
    800077c4:	f5040513          	addi	a0,s0,-176
    800077c8:	ffffe097          	auipc	ra,0xffffe
    800077cc:	e98080e7          	jalr	-360(ra) # 80005660 <namei>
    800077d0:	00050913          	mv	s2,a0
    800077d4:	02050e63          	beqz	a0,80007810 <sys_open+0x190>
    ilock(ip);
    800077d8:	ffffd097          	auipc	ra,0xffffd
    800077dc:	384080e7          	jalr	900(ra) # 80004b5c <ilock>
    if(ip->type == T_DIR && omode != O_RDONLY){
    800077e0:	04491703          	lh	a4,68(s2)
    800077e4:	00100793          	li	a5,1
    800077e8:	f0f71ce3          	bne	a4,a5,80007700 <sys_open+0x80>
    800077ec:	f4c42783          	lw	a5,-180(s0)
    800077f0:	f20784e3          	beqz	a5,80007718 <sys_open+0x98>
      iunlockput(ip);
    800077f4:	00090513          	mv	a0,s2
    800077f8:	ffffd097          	auipc	ra,0xffffd
    800077fc:	6a0080e7          	jalr	1696(ra) # 80004e98 <iunlockput>
      end_op();
    80007800:	ffffe097          	auipc	ra,0xffffe
    80007804:	204080e7          	jalr	516(ra) # 80005a04 <end_op>
      return -1;
    80007808:	fff00493          	li	s1,-1
    8000780c:	f8dff06f          	j	80007798 <sys_open+0x118>
      end_op();
    80007810:	ffffe097          	auipc	ra,0xffffe
    80007814:	1f4080e7          	jalr	500(ra) # 80005a04 <end_op>
      return -1;
    80007818:	fff00493          	li	s1,-1
    8000781c:	f7dff06f          	j	80007798 <sys_open+0x118>
    iunlockput(ip);
    80007820:	00090513          	mv	a0,s2
    80007824:	ffffd097          	auipc	ra,0xffffd
    80007828:	674080e7          	jalr	1652(ra) # 80004e98 <iunlockput>
    end_op();
    8000782c:	ffffe097          	auipc	ra,0xffffe
    80007830:	1d8080e7          	jalr	472(ra) # 80005a04 <end_op>
    return -1;
    80007834:	fff00493          	li	s1,-1
    80007838:	f61ff06f          	j	80007798 <sys_open+0x118>
    f->type = FD_DEVICE;
    8000783c:	00f9a023          	sw	a5,0(s3)
    f->major = ip->major;
    80007840:	04691783          	lh	a5,70(s2)
    80007844:	02f99223          	sh	a5,36(s3)
    80007848:	f09ff06f          	j	80007750 <sys_open+0xd0>
    itrunc(ip);
    8000784c:	00090513          	mv	a0,s2
    80007850:	ffffd097          	auipc	ra,0xffffd
    80007854:	480080e7          	jalr	1152(ra) # 80004cd0 <itrunc>
    80007858:	f2dff06f          	j	80007784 <sys_open+0x104>
      fileclose(f);
    8000785c:	00098513          	mv	a0,s3
    80007860:	ffffe097          	auipc	ra,0xffffe
    80007864:	77c080e7          	jalr	1916(ra) # 80005fdc <fileclose>
    iunlockput(ip);
    80007868:	00090513          	mv	a0,s2
    8000786c:	ffffd097          	auipc	ra,0xffffd
    80007870:	62c080e7          	jalr	1580(ra) # 80004e98 <iunlockput>
    end_op();
    80007874:	ffffe097          	auipc	ra,0xffffe
    80007878:	190080e7          	jalr	400(ra) # 80005a04 <end_op>
    return -1;
    8000787c:	fff00493          	li	s1,-1
    80007880:	f19ff06f          	j	80007798 <sys_open+0x118>

0000000080007884 <sys_mkdir>:

uint64
sys_mkdir(void)
{
    80007884:	f7010113          	addi	sp,sp,-144
    80007888:	08113423          	sd	ra,136(sp)
    8000788c:	08813023          	sd	s0,128(sp)
    80007890:	09010413          	addi	s0,sp,144
  char path[MAXPATH];
  struct inode *ip;

  begin_op();
    80007894:	ffffe097          	auipc	ra,0xffffe
    80007898:	0bc080e7          	jalr	188(ra) # 80005950 <begin_op>
  if(argstr(0, path, MAXPATH) < 0 || (ip = create(path, T_DIR, 0, 0)) == 0){
    8000789c:	08000613          	li	a2,128
    800078a0:	f7040593          	addi	a1,s0,-144
    800078a4:	00000513          	li	a0,0
    800078a8:	ffffc097          	auipc	ra,0xffffc
    800078ac:	364080e7          	jalr	868(ra) # 80003c0c <argstr>
    800078b0:	04054263          	bltz	a0,800078f4 <sys_mkdir+0x70>
    800078b4:	00000693          	li	a3,0
    800078b8:	00000613          	li	a2,0
    800078bc:	00100593          	li	a1,1
    800078c0:	f7040513          	addi	a0,s0,-144
    800078c4:	fffff097          	auipc	ra,0xfffff
    800078c8:	5ac080e7          	jalr	1452(ra) # 80006e70 <create>
    800078cc:	02050463          	beqz	a0,800078f4 <sys_mkdir+0x70>
    end_op();
    return -1;
  }
  iunlockput(ip);
    800078d0:	ffffd097          	auipc	ra,0xffffd
    800078d4:	5c8080e7          	jalr	1480(ra) # 80004e98 <iunlockput>
  end_op();
    800078d8:	ffffe097          	auipc	ra,0xffffe
    800078dc:	12c080e7          	jalr	300(ra) # 80005a04 <end_op>
  return 0;
    800078e0:	00000513          	li	a0,0
}
    800078e4:	08813083          	ld	ra,136(sp)
    800078e8:	08013403          	ld	s0,128(sp)
    800078ec:	09010113          	addi	sp,sp,144
    800078f0:	00008067          	ret
    end_op();
    800078f4:	ffffe097          	auipc	ra,0xffffe
    800078f8:	110080e7          	jalr	272(ra) # 80005a04 <end_op>
    return -1;
    800078fc:	fff00513          	li	a0,-1
    80007900:	fe5ff06f          	j	800078e4 <sys_mkdir+0x60>

0000000080007904 <sys_mknod>:

uint64
sys_mknod(void)
{
    80007904:	f6010113          	addi	sp,sp,-160
    80007908:	08113c23          	sd	ra,152(sp)
    8000790c:	08813823          	sd	s0,144(sp)
    80007910:	0a010413          	addi	s0,sp,160
  struct inode *ip;
  char path[MAXPATH];
  int major, minor;

  begin_op();
    80007914:	ffffe097          	auipc	ra,0xffffe
    80007918:	03c080e7          	jalr	60(ra) # 80005950 <begin_op>
  if((argstr(0, path, MAXPATH)) < 0 ||
    8000791c:	08000613          	li	a2,128
    80007920:	f7040593          	addi	a1,s0,-144
    80007924:	00000513          	li	a0,0
    80007928:	ffffc097          	auipc	ra,0xffffc
    8000792c:	2e4080e7          	jalr	740(ra) # 80003c0c <argstr>
    80007930:	06054063          	bltz	a0,80007990 <sys_mknod+0x8c>
     argint(1, &major) < 0 ||
    80007934:	f6c40593          	addi	a1,s0,-148
    80007938:	00100513          	li	a0,1
    8000793c:	ffffc097          	auipc	ra,0xffffc
    80007940:	258080e7          	jalr	600(ra) # 80003b94 <argint>
  if((argstr(0, path, MAXPATH)) < 0 ||
    80007944:	04054663          	bltz	a0,80007990 <sys_mknod+0x8c>
     argint(2, &minor) < 0 ||
    80007948:	f6840593          	addi	a1,s0,-152
    8000794c:	00200513          	li	a0,2
    80007950:	ffffc097          	auipc	ra,0xffffc
    80007954:	244080e7          	jalr	580(ra) # 80003b94 <argint>
     argint(1, &major) < 0 ||
    80007958:	02054c63          	bltz	a0,80007990 <sys_mknod+0x8c>
     (ip = create(path, T_DEVICE, major, minor)) == 0){
    8000795c:	f6841683          	lh	a3,-152(s0)
    80007960:	f6c41603          	lh	a2,-148(s0)
    80007964:	00300593          	li	a1,3
    80007968:	f7040513          	addi	a0,s0,-144
    8000796c:	fffff097          	auipc	ra,0xfffff
    80007970:	504080e7          	jalr	1284(ra) # 80006e70 <create>
     argint(2, &minor) < 0 ||
    80007974:	00050e63          	beqz	a0,80007990 <sys_mknod+0x8c>
    end_op();
    return -1;
  }
  iunlockput(ip);
    80007978:	ffffd097          	auipc	ra,0xffffd
    8000797c:	520080e7          	jalr	1312(ra) # 80004e98 <iunlockput>
  end_op();
    80007980:	ffffe097          	auipc	ra,0xffffe
    80007984:	084080e7          	jalr	132(ra) # 80005a04 <end_op>
  return 0;
    80007988:	00000513          	li	a0,0
    8000798c:	0100006f          	j	8000799c <sys_mknod+0x98>
    end_op();
    80007990:	ffffe097          	auipc	ra,0xffffe
    80007994:	074080e7          	jalr	116(ra) # 80005a04 <end_op>
    return -1;
    80007998:	fff00513          	li	a0,-1
}
    8000799c:	09813083          	ld	ra,152(sp)
    800079a0:	09013403          	ld	s0,144(sp)
    800079a4:	0a010113          	addi	sp,sp,160
    800079a8:	00008067          	ret

00000000800079ac <sys_chdir>:

uint64
sys_chdir(void)
{
    800079ac:	f6010113          	addi	sp,sp,-160
    800079b0:	08113c23          	sd	ra,152(sp)
    800079b4:	08813823          	sd	s0,144(sp)
    800079b8:	08913423          	sd	s1,136(sp)
    800079bc:	09213023          	sd	s2,128(sp)
    800079c0:	0a010413          	addi	s0,sp,160
  char path[MAXPATH];
  struct inode *ip;
  struct proc *p = myproc();
    800079c4:	ffffb097          	auipc	ra,0xffffb
    800079c8:	a78080e7          	jalr	-1416(ra) # 8000243c <myproc>
    800079cc:	00050913          	mv	s2,a0
  
  begin_op();
    800079d0:	ffffe097          	auipc	ra,0xffffe
    800079d4:	f80080e7          	jalr	-128(ra) # 80005950 <begin_op>
  if(argstr(0, path, MAXPATH) < 0 || (ip = namei(path)) == 0){
    800079d8:	08000613          	li	a2,128
    800079dc:	f6040593          	addi	a1,s0,-160
    800079e0:	00000513          	li	a0,0
    800079e4:	ffffc097          	auipc	ra,0xffffc
    800079e8:	228080e7          	jalr	552(ra) # 80003c0c <argstr>
    800079ec:	06054663          	bltz	a0,80007a58 <sys_chdir+0xac>
    800079f0:	f6040513          	addi	a0,s0,-160
    800079f4:	ffffe097          	auipc	ra,0xffffe
    800079f8:	c6c080e7          	jalr	-916(ra) # 80005660 <namei>
    800079fc:	00050493          	mv	s1,a0
    80007a00:	04050c63          	beqz	a0,80007a58 <sys_chdir+0xac>
    end_op();
    return -1;
  }
  ilock(ip);
    80007a04:	ffffd097          	auipc	ra,0xffffd
    80007a08:	158080e7          	jalr	344(ra) # 80004b5c <ilock>
  if(ip->type != T_DIR){
    80007a0c:	04449703          	lh	a4,68(s1)
    80007a10:	00100793          	li	a5,1
    80007a14:	04f71a63          	bne	a4,a5,80007a68 <sys_chdir+0xbc>
    iunlockput(ip);
    end_op();
    return -1;
  }
  iunlock(ip);
    80007a18:	00048513          	mv	a0,s1
    80007a1c:	ffffd097          	auipc	ra,0xffffd
    80007a20:	244080e7          	jalr	580(ra) # 80004c60 <iunlock>
  iput(p->cwd);
    80007a24:	15093503          	ld	a0,336(s2)
    80007a28:	ffffd097          	auipc	ra,0xffffd
    80007a2c:	394080e7          	jalr	916(ra) # 80004dbc <iput>
  end_op();
    80007a30:	ffffe097          	auipc	ra,0xffffe
    80007a34:	fd4080e7          	jalr	-44(ra) # 80005a04 <end_op>
  p->cwd = ip;
    80007a38:	14993823          	sd	s1,336(s2)
  return 0;
    80007a3c:	00000513          	li	a0,0
}
    80007a40:	09813083          	ld	ra,152(sp)
    80007a44:	09013403          	ld	s0,144(sp)
    80007a48:	08813483          	ld	s1,136(sp)
    80007a4c:	08013903          	ld	s2,128(sp)
    80007a50:	0a010113          	addi	sp,sp,160
    80007a54:	00008067          	ret
    end_op();
    80007a58:	ffffe097          	auipc	ra,0xffffe
    80007a5c:	fac080e7          	jalr	-84(ra) # 80005a04 <end_op>
    return -1;
    80007a60:	fff00513          	li	a0,-1
    80007a64:	fddff06f          	j	80007a40 <sys_chdir+0x94>
    iunlockput(ip);
    80007a68:	00048513          	mv	a0,s1
    80007a6c:	ffffd097          	auipc	ra,0xffffd
    80007a70:	42c080e7          	jalr	1068(ra) # 80004e98 <iunlockput>
    end_op();
    80007a74:	ffffe097          	auipc	ra,0xffffe
    80007a78:	f90080e7          	jalr	-112(ra) # 80005a04 <end_op>
    return -1;
    80007a7c:	fff00513          	li	a0,-1
    80007a80:	fc1ff06f          	j	80007a40 <sys_chdir+0x94>

0000000080007a84 <sys_exec>:

uint64
sys_exec(void)
{
    80007a84:	e3010113          	addi	sp,sp,-464
    80007a88:	1c113423          	sd	ra,456(sp)
    80007a8c:	1c813023          	sd	s0,448(sp)
    80007a90:	1a913c23          	sd	s1,440(sp)
    80007a94:	1b213823          	sd	s2,432(sp)
    80007a98:	1b313423          	sd	s3,424(sp)
    80007a9c:	1b413023          	sd	s4,416(sp)
    80007aa0:	19513c23          	sd	s5,408(sp)
    80007aa4:	1d010413          	addi	s0,sp,464
  char path[MAXPATH], *argv[MAXARG];
  int i;
  uint64 uargv, uarg;

  if(argstr(0, path, MAXPATH) < 0 || argaddr(1, &uargv) < 0){
    80007aa8:	08000613          	li	a2,128
    80007aac:	f4040593          	addi	a1,s0,-192
    80007ab0:	00000513          	li	a0,0
    80007ab4:	ffffc097          	auipc	ra,0xffffc
    80007ab8:	158080e7          	jalr	344(ra) # 80003c0c <argstr>
    return -1;
    80007abc:	fff00913          	li	s2,-1
  if(argstr(0, path, MAXPATH) < 0 || argaddr(1, &uargv) < 0){
    80007ac0:	10054263          	bltz	a0,80007bc4 <sys_exec+0x140>
    80007ac4:	e3840593          	addi	a1,s0,-456
    80007ac8:	00100513          	li	a0,1
    80007acc:	ffffc097          	auipc	ra,0xffffc
    80007ad0:	104080e7          	jalr	260(ra) # 80003bd0 <argaddr>
    80007ad4:	0e054863          	bltz	a0,80007bc4 <sys_exec+0x140>
  }
  memset(argv, 0, sizeof(argv));
    80007ad8:	10000613          	li	a2,256
    80007adc:	00000593          	li	a1,0
    80007ae0:	e4040513          	addi	a0,s0,-448
    80007ae4:	ffff9097          	auipc	ra,0xffff9
    80007ae8:	640080e7          	jalr	1600(ra) # 80001124 <memset>
  for(i=0;; i++){
    if(i >= NELEM(argv)){
    80007aec:	e4040493          	addi	s1,s0,-448
  memset(argv, 0, sizeof(argv));
    80007af0:	00048993          	mv	s3,s1
    80007af4:	00000913          	li	s2,0
    if(i >= NELEM(argv)){
    80007af8:	02000a13          	li	s4,32
    80007afc:	00090a9b          	sext.w	s5,s2
      goto bad;
    }
    if(fetchaddr(uargv+sizeof(uint64)*i, (uint64*)&uarg) < 0){
    80007b00:	00391513          	slli	a0,s2,0x3
    80007b04:	e3040593          	addi	a1,s0,-464
    80007b08:	e3843783          	ld	a5,-456(s0)
    80007b0c:	00f50533          	add	a0,a0,a5
    80007b10:	ffffc097          	auipc	ra,0xffffc
    80007b14:	f90080e7          	jalr	-112(ra) # 80003aa0 <fetchaddr>
    80007b18:	04054063          	bltz	a0,80007b58 <sys_exec+0xd4>
      goto bad;
    }
    if(uarg == 0){
    80007b1c:	e3043783          	ld	a5,-464(s0)
    80007b20:	04078e63          	beqz	a5,80007b7c <sys_exec+0xf8>
      argv[i] = 0;
      break;
    }
    argv[i] = kalloc();
    80007b24:	ffff9097          	auipc	ra,0xffff9
    80007b28:	33c080e7          	jalr	828(ra) # 80000e60 <kalloc>
    80007b2c:	00050593          	mv	a1,a0
    80007b30:	00a9b023          	sd	a0,0(s3)
    if(argv[i] == 0)
    80007b34:	02050263          	beqz	a0,80007b58 <sys_exec+0xd4>
      goto bad;
    if(fetchstr(uarg, argv[i], PGSIZE) < 0)
    80007b38:	00001637          	lui	a2,0x1
    80007b3c:	e3043503          	ld	a0,-464(s0)
    80007b40:	ffffc097          	auipc	ra,0xffffc
    80007b44:	fe0080e7          	jalr	-32(ra) # 80003b20 <fetchstr>
    80007b48:	00054863          	bltz	a0,80007b58 <sys_exec+0xd4>
    if(i >= NELEM(argv)){
    80007b4c:	00190913          	addi	s2,s2,1
    80007b50:	00898993          	addi	s3,s3,8
    80007b54:	fb4914e3          	bne	s2,s4,80007afc <sys_exec+0x78>
    kfree(argv[i]);

  return ret;

 bad:
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80007b58:	f4040913          	addi	s2,s0,-192
    80007b5c:	0004b503          	ld	a0,0(s1)
    80007b60:	06050063          	beqz	a0,80007bc0 <sys_exec+0x13c>
    kfree(argv[i]);
    80007b64:	ffff9097          	auipc	ra,0xffff9
    80007b68:	190080e7          	jalr	400(ra) # 80000cf4 <kfree>
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80007b6c:	00848493          	addi	s1,s1,8
    80007b70:	ff2496e3          	bne	s1,s2,80007b5c <sys_exec+0xd8>
  return -1;
    80007b74:	fff00913          	li	s2,-1
    80007b78:	04c0006f          	j	80007bc4 <sys_exec+0x140>
      argv[i] = 0;
    80007b7c:	003a9a93          	slli	s5,s5,0x3
    80007b80:	fc0a8793          	addi	a5,s5,-64 # ffffffffffffefc0 <end+0xffffffff7ffd6fc0>
    80007b84:	00878ab3          	add	s5,a5,s0
    80007b88:	e80ab023          	sd	zero,-384(s5)
  int ret = exec(path, argv);
    80007b8c:	e4040593          	addi	a1,s0,-448
    80007b90:	f4040513          	addi	a0,s0,-192
    80007b94:	fffff097          	auipc	ra,0xfffff
    80007b98:	d24080e7          	jalr	-732(ra) # 800068b8 <exec>
    80007b9c:	00050913          	mv	s2,a0
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80007ba0:	f4040993          	addi	s3,s0,-192
    80007ba4:	0004b503          	ld	a0,0(s1)
    80007ba8:	00050e63          	beqz	a0,80007bc4 <sys_exec+0x140>
    kfree(argv[i]);
    80007bac:	ffff9097          	auipc	ra,0xffff9
    80007bb0:	148080e7          	jalr	328(ra) # 80000cf4 <kfree>
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80007bb4:	00848493          	addi	s1,s1,8
    80007bb8:	ff3496e3          	bne	s1,s3,80007ba4 <sys_exec+0x120>
    80007bbc:	0080006f          	j	80007bc4 <sys_exec+0x140>
  return -1;
    80007bc0:	fff00913          	li	s2,-1
}
    80007bc4:	00090513          	mv	a0,s2
    80007bc8:	1c813083          	ld	ra,456(sp)
    80007bcc:	1c013403          	ld	s0,448(sp)
    80007bd0:	1b813483          	ld	s1,440(sp)
    80007bd4:	1b013903          	ld	s2,432(sp)
    80007bd8:	1a813983          	ld	s3,424(sp)
    80007bdc:	1a013a03          	ld	s4,416(sp)
    80007be0:	19813a83          	ld	s5,408(sp)
    80007be4:	1d010113          	addi	sp,sp,464
    80007be8:	00008067          	ret

0000000080007bec <sys_pipe>:

uint64
sys_pipe(void)
{
    80007bec:	fc010113          	addi	sp,sp,-64
    80007bf0:	02113c23          	sd	ra,56(sp)
    80007bf4:	02813823          	sd	s0,48(sp)
    80007bf8:	02913423          	sd	s1,40(sp)
    80007bfc:	04010413          	addi	s0,sp,64
  uint64 fdarray; // user pointer to array of two integers
  struct file *rf, *wf;
  int fd0, fd1;
  struct proc *p = myproc();
    80007c00:	ffffb097          	auipc	ra,0xffffb
    80007c04:	83c080e7          	jalr	-1988(ra) # 8000243c <myproc>
    80007c08:	00050493          	mv	s1,a0

  if(argaddr(0, &fdarray) < 0)
    80007c0c:	fd840593          	addi	a1,s0,-40
    80007c10:	00000513          	li	a0,0
    80007c14:	ffffc097          	auipc	ra,0xffffc
    80007c18:	fbc080e7          	jalr	-68(ra) # 80003bd0 <argaddr>
    return -1;
    80007c1c:	fff00793          	li	a5,-1
  if(argaddr(0, &fdarray) < 0)
    80007c20:	10054263          	bltz	a0,80007d24 <sys_pipe+0x138>
  if(pipealloc(&rf, &wf) < 0)
    80007c24:	fc840593          	addi	a1,s0,-56
    80007c28:	fd040513          	addi	a0,s0,-48
    80007c2c:	fffff097          	auipc	ra,0xfffff
    80007c30:	83c080e7          	jalr	-1988(ra) # 80006468 <pipealloc>
    return -1;
    80007c34:	fff00793          	li	a5,-1
  if(pipealloc(&rf, &wf) < 0)
    80007c38:	0e054663          	bltz	a0,80007d24 <sys_pipe+0x138>
  fd0 = -1;
    80007c3c:	fcf42223          	sw	a5,-60(s0)
  if((fd0 = fdalloc(rf)) < 0 || (fd1 = fdalloc(wf)) < 0){
    80007c40:	fd043503          	ld	a0,-48(s0)
    80007c44:	fffff097          	auipc	ra,0xfffff
    80007c48:	1bc080e7          	jalr	444(ra) # 80006e00 <fdalloc>
    80007c4c:	fca42223          	sw	a0,-60(s0)
    80007c50:	0a054c63          	bltz	a0,80007d08 <sys_pipe+0x11c>
    80007c54:	fc843503          	ld	a0,-56(s0)
    80007c58:	fffff097          	auipc	ra,0xfffff
    80007c5c:	1a8080e7          	jalr	424(ra) # 80006e00 <fdalloc>
    80007c60:	fca42023          	sw	a0,-64(s0)
    80007c64:	08054663          	bltz	a0,80007cf0 <sys_pipe+0x104>
      p->ofile[fd0] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  if(copyout(p->pagetable, fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
    80007c68:	00400693          	li	a3,4
    80007c6c:	fc440613          	addi	a2,s0,-60
    80007c70:	fd843583          	ld	a1,-40(s0)
    80007c74:	0504b503          	ld	a0,80(s1)
    80007c78:	ffffa097          	auipc	ra,0xffffa
    80007c7c:	2cc080e7          	jalr	716(ra) # 80001f44 <copyout>
    80007c80:	02054463          	bltz	a0,80007ca8 <sys_pipe+0xbc>
     copyout(p->pagetable, fdarray+sizeof(fd0), (char *)&fd1, sizeof(fd1)) < 0){
    80007c84:	00400693          	li	a3,4
    80007c88:	fc040613          	addi	a2,s0,-64
    80007c8c:	fd843583          	ld	a1,-40(s0)
    80007c90:	00458593          	addi	a1,a1,4
    80007c94:	0504b503          	ld	a0,80(s1)
    80007c98:	ffffa097          	auipc	ra,0xffffa
    80007c9c:	2ac080e7          	jalr	684(ra) # 80001f44 <copyout>
    p->ofile[fd1] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  return 0;
    80007ca0:	00000793          	li	a5,0
  if(copyout(p->pagetable, fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
    80007ca4:	08055063          	bgez	a0,80007d24 <sys_pipe+0x138>
    p->ofile[fd0] = 0;
    80007ca8:	fc442783          	lw	a5,-60(s0)
    80007cac:	01a78793          	addi	a5,a5,26
    80007cb0:	00379793          	slli	a5,a5,0x3
    80007cb4:	00f487b3          	add	a5,s1,a5
    80007cb8:	0007b023          	sd	zero,0(a5)
    p->ofile[fd1] = 0;
    80007cbc:	fc042783          	lw	a5,-64(s0)
    80007cc0:	01a78793          	addi	a5,a5,26
    80007cc4:	00379793          	slli	a5,a5,0x3
    80007cc8:	00f48533          	add	a0,s1,a5
    80007ccc:	00053023          	sd	zero,0(a0)
    fileclose(rf);
    80007cd0:	fd043503          	ld	a0,-48(s0)
    80007cd4:	ffffe097          	auipc	ra,0xffffe
    80007cd8:	308080e7          	jalr	776(ra) # 80005fdc <fileclose>
    fileclose(wf);
    80007cdc:	fc843503          	ld	a0,-56(s0)
    80007ce0:	ffffe097          	auipc	ra,0xffffe
    80007ce4:	2fc080e7          	jalr	764(ra) # 80005fdc <fileclose>
    return -1;
    80007ce8:	fff00793          	li	a5,-1
    80007cec:	0380006f          	j	80007d24 <sys_pipe+0x138>
    if(fd0 >= 0)
    80007cf0:	fc442783          	lw	a5,-60(s0)
    80007cf4:	0007ca63          	bltz	a5,80007d08 <sys_pipe+0x11c>
      p->ofile[fd0] = 0;
    80007cf8:	01a78793          	addi	a5,a5,26
    80007cfc:	00379793          	slli	a5,a5,0x3
    80007d00:	00f487b3          	add	a5,s1,a5
    80007d04:	0007b023          	sd	zero,0(a5)
    fileclose(rf);
    80007d08:	fd043503          	ld	a0,-48(s0)
    80007d0c:	ffffe097          	auipc	ra,0xffffe
    80007d10:	2d0080e7          	jalr	720(ra) # 80005fdc <fileclose>
    fileclose(wf);
    80007d14:	fc843503          	ld	a0,-56(s0)
    80007d18:	ffffe097          	auipc	ra,0xffffe
    80007d1c:	2c4080e7          	jalr	708(ra) # 80005fdc <fileclose>
    return -1;
    80007d20:	fff00793          	li	a5,-1
}
    80007d24:	00078513          	mv	a0,a5
    80007d28:	03813083          	ld	ra,56(sp)
    80007d2c:	03013403          	ld	s0,48(sp)
    80007d30:	02813483          	ld	s1,40(sp)
    80007d34:	04010113          	addi	sp,sp,64
    80007d38:	00008067          	ret
    80007d3c:	0000                	.2byte	0x0
	...

0000000080007d40 <kernelvec>:
    80007d40:	f0010113          	addi	sp,sp,-256
    80007d44:	00113023          	sd	ra,0(sp)
    80007d48:	00213423          	sd	sp,8(sp)
    80007d4c:	00313823          	sd	gp,16(sp)
    80007d50:	00413c23          	sd	tp,24(sp)
    80007d54:	02513023          	sd	t0,32(sp)
    80007d58:	02613423          	sd	t1,40(sp)
    80007d5c:	02713823          	sd	t2,48(sp)
    80007d60:	02813c23          	sd	s0,56(sp)
    80007d64:	04913023          	sd	s1,64(sp)
    80007d68:	04a13423          	sd	a0,72(sp)
    80007d6c:	04b13823          	sd	a1,80(sp)
    80007d70:	04c13c23          	sd	a2,88(sp)
    80007d74:	06d13023          	sd	a3,96(sp)
    80007d78:	06e13423          	sd	a4,104(sp)
    80007d7c:	06f13823          	sd	a5,112(sp)
    80007d80:	07013c23          	sd	a6,120(sp)
    80007d84:	09113023          	sd	a7,128(sp)
    80007d88:	09213423          	sd	s2,136(sp)
    80007d8c:	09313823          	sd	s3,144(sp)
    80007d90:	09413c23          	sd	s4,152(sp)
    80007d94:	0b513023          	sd	s5,160(sp)
    80007d98:	0b613423          	sd	s6,168(sp)
    80007d9c:	0b713823          	sd	s7,176(sp)
    80007da0:	0b813c23          	sd	s8,184(sp)
    80007da4:	0d913023          	sd	s9,192(sp)
    80007da8:	0da13423          	sd	s10,200(sp)
    80007dac:	0db13823          	sd	s11,208(sp)
    80007db0:	0dc13c23          	sd	t3,216(sp)
    80007db4:	0fd13023          	sd	t4,224(sp)
    80007db8:	0fe13423          	sd	t5,232(sp)
    80007dbc:	0ff13823          	sd	t6,240(sp)
    80007dc0:	b39fb0ef          	jal	ra,800038f8 <kerneltrap>
    80007dc4:	00013083          	ld	ra,0(sp)
    80007dc8:	00813103          	ld	sp,8(sp)
    80007dcc:	01013183          	ld	gp,16(sp)
    80007dd0:	02013283          	ld	t0,32(sp)
    80007dd4:	02813303          	ld	t1,40(sp)
    80007dd8:	03013383          	ld	t2,48(sp)
    80007ddc:	03813403          	ld	s0,56(sp)
    80007de0:	04013483          	ld	s1,64(sp)
    80007de4:	04813503          	ld	a0,72(sp)
    80007de8:	05013583          	ld	a1,80(sp)
    80007dec:	05813603          	ld	a2,88(sp)
    80007df0:	06013683          	ld	a3,96(sp)
    80007df4:	06813703          	ld	a4,104(sp)
    80007df8:	07013783          	ld	a5,112(sp)
    80007dfc:	07813803          	ld	a6,120(sp)
    80007e00:	08013883          	ld	a7,128(sp)
    80007e04:	08813903          	ld	s2,136(sp)
    80007e08:	09013983          	ld	s3,144(sp)
    80007e0c:	09813a03          	ld	s4,152(sp)
    80007e10:	0a013a83          	ld	s5,160(sp)
    80007e14:	0a813b03          	ld	s6,168(sp)
    80007e18:	0b013b83          	ld	s7,176(sp)
    80007e1c:	0b813c03          	ld	s8,184(sp)
    80007e20:	0c013c83          	ld	s9,192(sp)
    80007e24:	0c813d03          	ld	s10,200(sp)
    80007e28:	0d013d83          	ld	s11,208(sp)
    80007e2c:	0d813e03          	ld	t3,216(sp)
    80007e30:	0e013e83          	ld	t4,224(sp)
    80007e34:	0e813f03          	ld	t5,232(sp)
    80007e38:	0f013f83          	ld	t6,240(sp)
    80007e3c:	10010113          	addi	sp,sp,256
    80007e40:	10200073          	sret
    80007e44:	00000013          	nop
    80007e48:	00000013          	nop
    80007e4c:	00000013          	nop

0000000080007e50 <timervec>:
    80007e50:	34051573          	csrrw	a0,mscratch,a0
    80007e54:	00b53023          	sd	a1,0(a0)
    80007e58:	00c53423          	sd	a2,8(a0)
    80007e5c:	00d53823          	sd	a3,16(a0)
    80007e60:	01853583          	ld	a1,24(a0)
    80007e64:	02053603          	ld	a2,32(a0)
    80007e68:	0005b683          	ld	a3,0(a1)
    80007e6c:	00c686b3          	add	a3,a3,a2
    80007e70:	00d5b023          	sd	a3,0(a1)
    80007e74:	00200593          	li	a1,2
    80007e78:	14459073          	csrw	sip,a1
    80007e7c:	01053683          	ld	a3,16(a0)
    80007e80:	00853603          	ld	a2,8(a0)
    80007e84:	00053583          	ld	a1,0(a0)
    80007e88:	34051573          	csrrw	a0,mscratch,a0
    80007e8c:	30200073          	mret

0000000080007e90 <plicinit>:
// the riscv Platform Level Interrupt Controller (PLIC).
//

void
plicinit(void)
{
    80007e90:	ff010113          	addi	sp,sp,-16
    80007e94:	00813423          	sd	s0,8(sp)
    80007e98:	01010413          	addi	s0,sp,16
  // set desired IRQ priorities non-zero (otherwise disabled).
  *(uint32*)(PLIC + UART0_IRQ*4) = 1;
    80007e9c:	0c0007b7          	lui	a5,0xc000
    80007ea0:	00100713          	li	a4,1
    80007ea4:	02e7a423          	sw	a4,40(a5) # c000028 <_entry-0x73ffffd8>
  *(uint32*)(PLIC + VIRTIO0_IRQ*4) = 1;
    80007ea8:	00e7a223          	sw	a4,4(a5)
}
    80007eac:	00813403          	ld	s0,8(sp)
    80007eb0:	01010113          	addi	sp,sp,16
    80007eb4:	00008067          	ret

0000000080007eb8 <plicinithart>:

void
plicinithart(void)
{
    80007eb8:	ff010113          	addi	sp,sp,-16
    80007ebc:	00113423          	sd	ra,8(sp)
    80007ec0:	00813023          	sd	s0,0(sp)
    80007ec4:	01010413          	addi	s0,sp,16
  int hart = cpuid();
    80007ec8:	ffffa097          	auipc	ra,0xffffa
    80007ecc:	524080e7          	jalr	1316(ra) # 800023ec <cpuid>
  
  // set uart's enable bit for this hart's S-mode. 
  *(uint32*)PLIC_SENABLE(hart)= (1 << UART0_IRQ) | (1 << VIRTIO0_IRQ);
    80007ed0:	0085171b          	slliw	a4,a0,0x8
    80007ed4:	0c0027b7          	lui	a5,0xc002
    80007ed8:	00e787b3          	add	a5,a5,a4
    80007edc:	40200713          	li	a4,1026
    80007ee0:	08e7a023          	sw	a4,128(a5) # c002080 <_entry-0x73ffdf80>

  // set this hart's S-mode priority threshold to 0.
  *(uint32*)PLIC_SPRIORITY(hart) = 0;
    80007ee4:	00d5151b          	slliw	a0,a0,0xd
    80007ee8:	0c2017b7          	lui	a5,0xc201
    80007eec:	00a787b3          	add	a5,a5,a0
    80007ef0:	0007a023          	sw	zero,0(a5) # c201000 <_entry-0x73dff000>
}
    80007ef4:	00813083          	ld	ra,8(sp)
    80007ef8:	00013403          	ld	s0,0(sp)
    80007efc:	01010113          	addi	sp,sp,16
    80007f00:	00008067          	ret

0000000080007f04 <plic_claim>:

// ask the PLIC what interrupt we should serve.
int
plic_claim(void)
{
    80007f04:	ff010113          	addi	sp,sp,-16
    80007f08:	00113423          	sd	ra,8(sp)
    80007f0c:	00813023          	sd	s0,0(sp)
    80007f10:	01010413          	addi	s0,sp,16
  int hart = cpuid();
    80007f14:	ffffa097          	auipc	ra,0xffffa
    80007f18:	4d8080e7          	jalr	1240(ra) # 800023ec <cpuid>
  int irq = *(uint32*)PLIC_SCLAIM(hart);
    80007f1c:	00d5151b          	slliw	a0,a0,0xd
    80007f20:	0c2017b7          	lui	a5,0xc201
    80007f24:	00a787b3          	add	a5,a5,a0
  return irq;
}
    80007f28:	0047a503          	lw	a0,4(a5) # c201004 <_entry-0x73dfeffc>
    80007f2c:	00813083          	ld	ra,8(sp)
    80007f30:	00013403          	ld	s0,0(sp)
    80007f34:	01010113          	addi	sp,sp,16
    80007f38:	00008067          	ret

0000000080007f3c <plic_complete>:

// tell the PLIC we've served this IRQ.
void
plic_complete(int irq)
{
    80007f3c:	fe010113          	addi	sp,sp,-32
    80007f40:	00113c23          	sd	ra,24(sp)
    80007f44:	00813823          	sd	s0,16(sp)
    80007f48:	00913423          	sd	s1,8(sp)
    80007f4c:	02010413          	addi	s0,sp,32
    80007f50:	00050493          	mv	s1,a0
  int hart = cpuid();
    80007f54:	ffffa097          	auipc	ra,0xffffa
    80007f58:	498080e7          	jalr	1176(ra) # 800023ec <cpuid>
  *(uint32*)PLIC_SCLAIM(hart) = irq;
    80007f5c:	00d5151b          	slliw	a0,a0,0xd
    80007f60:	0c2017b7          	lui	a5,0xc201
    80007f64:	00a787b3          	add	a5,a5,a0
    80007f68:	0097a223          	sw	s1,4(a5) # c201004 <_entry-0x73dfeffc>
}
    80007f6c:	01813083          	ld	ra,24(sp)
    80007f70:	01013403          	ld	s0,16(sp)
    80007f74:	00813483          	ld	s1,8(sp)
    80007f78:	02010113          	addi	sp,sp,32
    80007f7c:	00008067          	ret

0000000080007f80 <free_desc>:
}

// mark a descriptor as free.
static void
free_desc(int i)
{
    80007f80:	ff010113          	addi	sp,sp,-16
    80007f84:	00113423          	sd	ra,8(sp)
    80007f88:	00813023          	sd	s0,0(sp)
    80007f8c:	01010413          	addi	s0,sp,16
  if(i >= NUM)
    80007f90:	00700793          	li	a5,7
    80007f94:	08a7cc63          	blt	a5,a0,8000802c <free_desc+0xac>
    panic("free_desc 1");
  if(disk.free[i])
    80007f98:	0001d717          	auipc	a4,0x1d
    80007f9c:	06870713          	addi	a4,a4,104 # 80025000 <disk>
    80007fa0:	00a70733          	add	a4,a4,a0
    80007fa4:	000027b7          	lui	a5,0x2
    80007fa8:	00e787b3          	add	a5,a5,a4
    80007fac:	0187c783          	lbu	a5,24(a5) # 2018 <_entry-0x7fffdfe8>
    80007fb0:	08079663          	bnez	a5,8000803c <free_desc+0xbc>
    panic("free_desc 2");
  disk.desc[i].addr = 0;
    80007fb4:	00451793          	slli	a5,a0,0x4
    80007fb8:	0001f717          	auipc	a4,0x1f
    80007fbc:	04870713          	addi	a4,a4,72 # 80027000 <disk+0x2000>
    80007fc0:	00073683          	ld	a3,0(a4)
    80007fc4:	00f686b3          	add	a3,a3,a5
    80007fc8:	0006b023          	sd	zero,0(a3)
  disk.desc[i].len = 0;
    80007fcc:	00073683          	ld	a3,0(a4)
    80007fd0:	00f686b3          	add	a3,a3,a5
    80007fd4:	0006a423          	sw	zero,8(a3)
  disk.desc[i].flags = 0;
    80007fd8:	00073683          	ld	a3,0(a4)
    80007fdc:	00f686b3          	add	a3,a3,a5
    80007fe0:	00069623          	sh	zero,12(a3)
  disk.desc[i].next = 0;
    80007fe4:	00073703          	ld	a4,0(a4)
    80007fe8:	00f707b3          	add	a5,a4,a5
    80007fec:	00079723          	sh	zero,14(a5)
  disk.free[i] = 1;
    80007ff0:	0001d717          	auipc	a4,0x1d
    80007ff4:	01070713          	addi	a4,a4,16 # 80025000 <disk>
    80007ff8:	00a70733          	add	a4,a4,a0
    80007ffc:	000027b7          	lui	a5,0x2
    80008000:	00e787b3          	add	a5,a5,a4
    80008004:	00100713          	li	a4,1
    80008008:	00e78c23          	sb	a4,24(a5) # 2018 <_entry-0x7fffdfe8>
  wakeup(&disk.free[0]);
    8000800c:	0001f517          	auipc	a0,0x1f
    80008010:	00c50513          	addi	a0,a0,12 # 80027018 <disk+0x2018>
    80008014:	ffffb097          	auipc	ra,0xffffb
    80008018:	fb8080e7          	jalr	-72(ra) # 80002fcc <wakeup>
}
    8000801c:	00813083          	ld	ra,8(sp)
    80008020:	00013403          	ld	s0,0(sp)
    80008024:	01010113          	addi	sp,sp,16
    80008028:	00008067          	ret
    panic("free_desc 1");
    8000802c:	00002517          	auipc	a0,0x2
    80008030:	73c50513          	addi	a0,a0,1852 # 8000a768 <syscalls+0x320>
    80008034:	ffff8097          	auipc	ra,0xffff8
    80008038:	69c080e7          	jalr	1692(ra) # 800006d0 <panic>
    panic("free_desc 2");
    8000803c:	00002517          	auipc	a0,0x2
    80008040:	73c50513          	addi	a0,a0,1852 # 8000a778 <syscalls+0x330>
    80008044:	ffff8097          	auipc	ra,0xffff8
    80008048:	68c080e7          	jalr	1676(ra) # 800006d0 <panic>

000000008000804c <virtio_disk_init>:
{
    8000804c:	fe010113          	addi	sp,sp,-32
    80008050:	00113c23          	sd	ra,24(sp)
    80008054:	00813823          	sd	s0,16(sp)
    80008058:	00913423          	sd	s1,8(sp)
    8000805c:	02010413          	addi	s0,sp,32
  initlock(&disk.vdisk_lock, "virtio_disk");
    80008060:	00002597          	auipc	a1,0x2
    80008064:	72858593          	addi	a1,a1,1832 # 8000a788 <syscalls+0x340>
    80008068:	0001f517          	auipc	a0,0x1f
    8000806c:	0c050513          	addi	a0,a0,192 # 80027128 <disk+0x2128>
    80008070:	ffff9097          	auipc	ra,0xffff9
    80008074:	e78080e7          	jalr	-392(ra) # 80000ee8 <initlock>
  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
    80008078:	100017b7          	lui	a5,0x10001
    8000807c:	0007a703          	lw	a4,0(a5) # 10001000 <_entry-0x6ffff000>
    80008080:	0007071b          	sext.w	a4,a4
    80008084:	747277b7          	lui	a5,0x74727
    80008088:	97678793          	addi	a5,a5,-1674 # 74726976 <_entry-0xb8d968a>
    8000808c:	12f71863          	bne	a4,a5,800081bc <virtio_disk_init+0x170>
     *R(VIRTIO_MMIO_VERSION) != 1 ||
    80008090:	100017b7          	lui	a5,0x10001
    80008094:	0047a783          	lw	a5,4(a5) # 10001004 <_entry-0x6fffeffc>
    80008098:	0007879b          	sext.w	a5,a5
  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
    8000809c:	00100713          	li	a4,1
    800080a0:	10e79e63          	bne	a5,a4,800081bc <virtio_disk_init+0x170>
     *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
    800080a4:	100017b7          	lui	a5,0x10001
    800080a8:	0087a783          	lw	a5,8(a5) # 10001008 <_entry-0x6fffeff8>
    800080ac:	0007879b          	sext.w	a5,a5
     *R(VIRTIO_MMIO_VERSION) != 1 ||
    800080b0:	00200713          	li	a4,2
    800080b4:	10e79463          	bne	a5,a4,800081bc <virtio_disk_init+0x170>
     *R(VIRTIO_MMIO_VENDOR_ID) != 0x554d4551){
    800080b8:	100017b7          	lui	a5,0x10001
    800080bc:	00c7a703          	lw	a4,12(a5) # 1000100c <_entry-0x6fffeff4>
    800080c0:	0007071b          	sext.w	a4,a4
     *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
    800080c4:	554d47b7          	lui	a5,0x554d4
    800080c8:	55178793          	addi	a5,a5,1361 # 554d4551 <_entry-0x2ab2baaf>
    800080cc:	0ef71863          	bne	a4,a5,800081bc <virtio_disk_init+0x170>
  *R(VIRTIO_MMIO_STATUS) = status;
    800080d0:	100017b7          	lui	a5,0x10001
    800080d4:	00100713          	li	a4,1
    800080d8:	06e7a823          	sw	a4,112(a5) # 10001070 <_entry-0x6fffef90>
  *R(VIRTIO_MMIO_STATUS) = status;
    800080dc:	00300713          	li	a4,3
    800080e0:	06e7a823          	sw	a4,112(a5)
  uint64 features = *R(VIRTIO_MMIO_DEVICE_FEATURES);
    800080e4:	0107a703          	lw	a4,16(a5)
  *R(VIRTIO_MMIO_DRIVER_FEATURES) = features;
    800080e8:	c7ffe6b7          	lui	a3,0xc7ffe
    800080ec:	75f68693          	addi	a3,a3,1887 # ffffffffc7ffe75f <end+0xffffffff47fd675f>
    800080f0:	00d77733          	and	a4,a4,a3
    800080f4:	02e7a023          	sw	a4,32(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    800080f8:	00b00713          	li	a4,11
    800080fc:	06e7a823          	sw	a4,112(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    80008100:	00f00713          	li	a4,15
    80008104:	06e7a823          	sw	a4,112(a5)
  *R(VIRTIO_MMIO_GUEST_PAGE_SIZE) = PGSIZE;
    80008108:	00001737          	lui	a4,0x1
    8000810c:	02e7a423          	sw	a4,40(a5)
  *R(VIRTIO_MMIO_QUEUE_SEL) = 0;
    80008110:	0207a823          	sw	zero,48(a5)
  uint32 max = *R(VIRTIO_MMIO_QUEUE_NUM_MAX);
    80008114:	0347a783          	lw	a5,52(a5)
    80008118:	0007879b          	sext.w	a5,a5
  if(max == 0)
    8000811c:	0a078863          	beqz	a5,800081cc <virtio_disk_init+0x180>
  if(max < NUM)
    80008120:	00700713          	li	a4,7
    80008124:	0af77c63          	bgeu	a4,a5,800081dc <virtio_disk_init+0x190>
  *R(VIRTIO_MMIO_QUEUE_NUM) = NUM;
    80008128:	100014b7          	lui	s1,0x10001
    8000812c:	00800793          	li	a5,8
    80008130:	02f4ac23          	sw	a5,56(s1) # 10001038 <_entry-0x6fffefc8>
  memset(disk.pages, 0, sizeof(disk.pages));
    80008134:	00002637          	lui	a2,0x2
    80008138:	00000593          	li	a1,0
    8000813c:	0001d517          	auipc	a0,0x1d
    80008140:	ec450513          	addi	a0,a0,-316 # 80025000 <disk>
    80008144:	ffff9097          	auipc	ra,0xffff9
    80008148:	fe0080e7          	jalr	-32(ra) # 80001124 <memset>
  *R(VIRTIO_MMIO_QUEUE_PFN) = ((uint64)disk.pages) >> PGSHIFT;
    8000814c:	0001d717          	auipc	a4,0x1d
    80008150:	eb470713          	addi	a4,a4,-332 # 80025000 <disk>
    80008154:	00c75793          	srli	a5,a4,0xc
    80008158:	0007879b          	sext.w	a5,a5
    8000815c:	04f4a023          	sw	a5,64(s1)
  disk.desc = (struct virtq_desc *) disk.pages;
    80008160:	0001f797          	auipc	a5,0x1f
    80008164:	ea078793          	addi	a5,a5,-352 # 80027000 <disk+0x2000>
    80008168:	00e7b023          	sd	a4,0(a5)
  disk.avail = (struct virtq_avail *)(disk.pages + NUM*sizeof(struct virtq_desc));
    8000816c:	0001d717          	auipc	a4,0x1d
    80008170:	f1470713          	addi	a4,a4,-236 # 80025080 <disk+0x80>
    80008174:	00e7b423          	sd	a4,8(a5)
  disk.used = (struct virtq_used *) (disk.pages + PGSIZE);
    80008178:	0001e717          	auipc	a4,0x1e
    8000817c:	e8870713          	addi	a4,a4,-376 # 80026000 <disk+0x1000>
    80008180:	00e7b823          	sd	a4,16(a5)
    disk.free[i] = 1;
    80008184:	00100713          	li	a4,1
    80008188:	00e78c23          	sb	a4,24(a5)
    8000818c:	00e78ca3          	sb	a4,25(a5)
    80008190:	00e78d23          	sb	a4,26(a5)
    80008194:	00e78da3          	sb	a4,27(a5)
    80008198:	00e78e23          	sb	a4,28(a5)
    8000819c:	00e78ea3          	sb	a4,29(a5)
    800081a0:	00e78f23          	sb	a4,30(a5)
    800081a4:	00e78fa3          	sb	a4,31(a5)
}
    800081a8:	01813083          	ld	ra,24(sp)
    800081ac:	01013403          	ld	s0,16(sp)
    800081b0:	00813483          	ld	s1,8(sp)
    800081b4:	02010113          	addi	sp,sp,32
    800081b8:	00008067          	ret
    panic("could not find virtio disk");
    800081bc:	00002517          	auipc	a0,0x2
    800081c0:	5dc50513          	addi	a0,a0,1500 # 8000a798 <syscalls+0x350>
    800081c4:	ffff8097          	auipc	ra,0xffff8
    800081c8:	50c080e7          	jalr	1292(ra) # 800006d0 <panic>
    panic("virtio disk has no queue 0");
    800081cc:	00002517          	auipc	a0,0x2
    800081d0:	5ec50513          	addi	a0,a0,1516 # 8000a7b8 <syscalls+0x370>
    800081d4:	ffff8097          	auipc	ra,0xffff8
    800081d8:	4fc080e7          	jalr	1276(ra) # 800006d0 <panic>
    panic("virtio disk max queue too short");
    800081dc:	00002517          	auipc	a0,0x2
    800081e0:	5fc50513          	addi	a0,a0,1532 # 8000a7d8 <syscalls+0x390>
    800081e4:	ffff8097          	auipc	ra,0xffff8
    800081e8:	4ec080e7          	jalr	1260(ra) # 800006d0 <panic>

00000000800081ec <virtio_disk_rw>:
  return 0;
}

void
virtio_disk_rw(struct buf *b, int write)
{
    800081ec:	f8010113          	addi	sp,sp,-128
    800081f0:	06113c23          	sd	ra,120(sp)
    800081f4:	06813823          	sd	s0,112(sp)
    800081f8:	06913423          	sd	s1,104(sp)
    800081fc:	07213023          	sd	s2,96(sp)
    80008200:	05313c23          	sd	s3,88(sp)
    80008204:	05413823          	sd	s4,80(sp)
    80008208:	05513423          	sd	s5,72(sp)
    8000820c:	05613023          	sd	s6,64(sp)
    80008210:	03713c23          	sd	s7,56(sp)
    80008214:	03813823          	sd	s8,48(sp)
    80008218:	03913423          	sd	s9,40(sp)
    8000821c:	03a13023          	sd	s10,32(sp)
    80008220:	01b13c23          	sd	s11,24(sp)
    80008224:	08010413          	addi	s0,sp,128
    80008228:	00050a93          	mv	s5,a0
    8000822c:	00058d13          	mv	s10,a1
  uint64 sector = b->blockno * (BSIZE / 512);
    80008230:	00c52c83          	lw	s9,12(a0)
    80008234:	001c9c9b          	slliw	s9,s9,0x1
    80008238:	020c9c93          	slli	s9,s9,0x20
    8000823c:	020cdc93          	srli	s9,s9,0x20

  acquire(&disk.vdisk_lock);
    80008240:	0001f517          	auipc	a0,0x1f
    80008244:	ee850513          	addi	a0,a0,-280 # 80027128 <disk+0x2128>
    80008248:	ffff9097          	auipc	ra,0xffff9
    8000824c:	d84080e7          	jalr	-636(ra) # 80000fcc <acquire>
  for(int i = 0; i < 3; i++){
    80008250:	00000993          	li	s3,0
  for(int i = 0; i < NUM; i++){
    80008254:	00800493          	li	s1,8
      disk.free[i] = 0;
    80008258:	0001dc17          	auipc	s8,0x1d
    8000825c:	da8c0c13          	addi	s8,s8,-600 # 80025000 <disk>
    80008260:	00002bb7          	lui	s7,0x2
  for(int i = 0; i < 3; i++){
    80008264:	00300b13          	li	s6,3
    80008268:	0880006f          	j	800082f0 <virtio_disk_rw+0x104>
      disk.free[i] = 0;
    8000826c:	00fc0733          	add	a4,s8,a5
    80008270:	00eb8733          	add	a4,s7,a4
    80008274:	00070c23          	sb	zero,24(a4)
    idx[i] = alloc_desc();
    80008278:	00f5a023          	sw	a5,0(a1)
    if(idx[i] < 0){
    8000827c:	0207ce63          	bltz	a5,800082b8 <virtio_disk_rw+0xcc>
  for(int i = 0; i < 3; i++){
    80008280:	0019091b          	addiw	s2,s2,1
    80008284:	00460613          	addi	a2,a2,4 # 2004 <_entry-0x7fffdffc>
    80008288:	21690c63          	beq	s2,s6,800084a0 <virtio_disk_rw+0x2b4>
    idx[i] = alloc_desc();
    8000828c:	00060593          	mv	a1,a2
  for(int i = 0; i < NUM; i++){
    80008290:	0001f717          	auipc	a4,0x1f
    80008294:	d8870713          	addi	a4,a4,-632 # 80027018 <disk+0x2018>
    80008298:	00098793          	mv	a5,s3
    if(disk.free[i]){
    8000829c:	00074683          	lbu	a3,0(a4)
    800082a0:	fc0696e3          	bnez	a3,8000826c <virtio_disk_rw+0x80>
  for(int i = 0; i < NUM; i++){
    800082a4:	0017879b          	addiw	a5,a5,1
    800082a8:	00170713          	addi	a4,a4,1
    800082ac:	fe9798e3          	bne	a5,s1,8000829c <virtio_disk_rw+0xb0>
    idx[i] = alloc_desc();
    800082b0:	fff00793          	li	a5,-1
    800082b4:	00f5a023          	sw	a5,0(a1)
      for(int j = 0; j < i; j++)
    800082b8:	03205063          	blez	s2,800082d8 <virtio_disk_rw+0xec>
    800082bc:	00098d93          	mv	s11,s3
        free_desc(idx[j]);
    800082c0:	000a2503          	lw	a0,0(s4)
    800082c4:	00000097          	auipc	ra,0x0
    800082c8:	cbc080e7          	jalr	-836(ra) # 80007f80 <free_desc>
      for(int j = 0; j < i; j++)
    800082cc:	001d8d9b          	addiw	s11,s11,1
    800082d0:	004a0a13          	addi	s4,s4,4
    800082d4:	ff2d96e3          	bne	s11,s2,800082c0 <virtio_disk_rw+0xd4>
  int idx[3];
  while(1){
    if(alloc3_desc(idx) == 0) {
      break;
    }
    sleep(&disk.free[0], &disk.vdisk_lock);
    800082d8:	0001f597          	auipc	a1,0x1f
    800082dc:	e5058593          	addi	a1,a1,-432 # 80027128 <disk+0x2128>
    800082e0:	0001f517          	auipc	a0,0x1f
    800082e4:	d3850513          	addi	a0,a0,-712 # 80027018 <disk+0x2018>
    800082e8:	ffffb097          	auipc	ra,0xffffb
    800082ec:	ac4080e7          	jalr	-1340(ra) # 80002dac <sleep>
  for(int i = 0; i < 3; i++){
    800082f0:	f8040a13          	addi	s4,s0,-128
{
    800082f4:	000a0613          	mv	a2,s4
  for(int i = 0; i < 3; i++){
    800082f8:	00098913          	mv	s2,s3
    800082fc:	f91ff06f          	j	8000828c <virtio_disk_rw+0xa0>
  disk.desc[idx[0]].next = idx[1];

  disk.desc[idx[1]].addr = (uint64) b->data;
  disk.desc[idx[1]].len = BSIZE;
  if(write)
    disk.desc[idx[1]].flags = 0; // device reads b->data
    80008300:	0001f697          	auipc	a3,0x1f
    80008304:	d006b683          	ld	a3,-768(a3) # 80027000 <disk+0x2000>
    80008308:	00e686b3          	add	a3,a3,a4
    8000830c:	00069623          	sh	zero,12(a3)
  else
    disk.desc[idx[1]].flags = VRING_DESC_F_WRITE; // device writes b->data
  disk.desc[idx[1]].flags |= VRING_DESC_F_NEXT;
    80008310:	0001d817          	auipc	a6,0x1d
    80008314:	cf080813          	addi	a6,a6,-784 # 80025000 <disk>
    80008318:	0001f697          	auipc	a3,0x1f
    8000831c:	ce868693          	addi	a3,a3,-792 # 80027000 <disk+0x2000>
    80008320:	0006b603          	ld	a2,0(a3)
    80008324:	00e60633          	add	a2,a2,a4
    80008328:	00c65583          	lhu	a1,12(a2)
    8000832c:	0015e593          	ori	a1,a1,1
    80008330:	00b61623          	sh	a1,12(a2)
  disk.desc[idx[1]].next = idx[2];
    80008334:	f8842603          	lw	a2,-120(s0)
    80008338:	0006b583          	ld	a1,0(a3)
    8000833c:	00e58733          	add	a4,a1,a4
    80008340:	00c71723          	sh	a2,14(a4)

  disk.info[idx[0]].status = 0xff; // device writes 0 on success
    80008344:	20050593          	addi	a1,a0,512
    80008348:	00459593          	slli	a1,a1,0x4
    8000834c:	00b805b3          	add	a1,a6,a1
    80008350:	fff00713          	li	a4,-1
    80008354:	02e58823          	sb	a4,48(a1)
  disk.desc[idx[2]].addr = (uint64) &disk.info[idx[0]].status;
    80008358:	00461713          	slli	a4,a2,0x4
    8000835c:	0006b603          	ld	a2,0(a3)
    80008360:	00e60633          	add	a2,a2,a4
    80008364:	03078793          	addi	a5,a5,48
    80008368:	010787b3          	add	a5,a5,a6
    8000836c:	00f63023          	sd	a5,0(a2)
  disk.desc[idx[2]].len = 1;
    80008370:	0006b783          	ld	a5,0(a3)
    80008374:	00e787b3          	add	a5,a5,a4
    80008378:	00100613          	li	a2,1
    8000837c:	00c7a423          	sw	a2,8(a5)
  disk.desc[idx[2]].flags = VRING_DESC_F_WRITE; // device writes the status
    80008380:	0006b783          	ld	a5,0(a3)
    80008384:	00e787b3          	add	a5,a5,a4
    80008388:	00200813          	li	a6,2
    8000838c:	01079623          	sh	a6,12(a5)
  disk.desc[idx[2]].next = 0;
    80008390:	0006b783          	ld	a5,0(a3)
    80008394:	00e787b3          	add	a5,a5,a4
    80008398:	00079723          	sh	zero,14(a5)

  // record struct buf for virtio_disk_intr().
  b->disk = 1;
    8000839c:	00caa223          	sw	a2,4(s5)
  disk.info[idx[0]].b = b;
    800083a0:	0355b423          	sd	s5,40(a1)

  // tell the device the first index in our chain of descriptors.
  disk.avail->ring[disk.avail->idx % NUM] = idx[0];
    800083a4:	0086b703          	ld	a4,8(a3)
    800083a8:	00275783          	lhu	a5,2(a4)
    800083ac:	0077f793          	andi	a5,a5,7
    800083b0:	00179793          	slli	a5,a5,0x1
    800083b4:	00f70733          	add	a4,a4,a5
    800083b8:	00a71223          	sh	a0,4(a4)

  __sync_synchronize();
    800083bc:	0ff0000f          	fence

  // tell the device another avail ring entry is available.
  disk.avail->idx += 1; // not % NUM ...
    800083c0:	0086b703          	ld	a4,8(a3)
    800083c4:	00275783          	lhu	a5,2(a4)
    800083c8:	0017879b          	addiw	a5,a5,1
    800083cc:	00f71123          	sh	a5,2(a4)

  __sync_synchronize();
    800083d0:	0ff0000f          	fence

  *R(VIRTIO_MMIO_QUEUE_NOTIFY) = 0; // value is queue number
    800083d4:	100017b7          	lui	a5,0x10001
    800083d8:	0407a823          	sw	zero,80(a5) # 10001050 <_entry-0x6fffefb0>

  // Wait for virtio_disk_intr() to say request has finished.
  while(b->disk == 1) {
    800083dc:	004aa783          	lw	a5,4(s5)
    800083e0:	02c79463          	bne	a5,a2,80008408 <virtio_disk_rw+0x21c>
    sleep(b, &disk.vdisk_lock);
    800083e4:	0001f917          	auipc	s2,0x1f
    800083e8:	d4490913          	addi	s2,s2,-700 # 80027128 <disk+0x2128>
  while(b->disk == 1) {
    800083ec:	00100493          	li	s1,1
    sleep(b, &disk.vdisk_lock);
    800083f0:	00090593          	mv	a1,s2
    800083f4:	000a8513          	mv	a0,s5
    800083f8:	ffffb097          	auipc	ra,0xffffb
    800083fc:	9b4080e7          	jalr	-1612(ra) # 80002dac <sleep>
  while(b->disk == 1) {
    80008400:	004aa783          	lw	a5,4(s5)
    80008404:	fe9786e3          	beq	a5,s1,800083f0 <virtio_disk_rw+0x204>
  }

  disk.info[idx[0]].b = 0;
    80008408:	f8042903          	lw	s2,-128(s0)
    8000840c:	20090713          	addi	a4,s2,512
    80008410:	00471713          	slli	a4,a4,0x4
    80008414:	0001d797          	auipc	a5,0x1d
    80008418:	bec78793          	addi	a5,a5,-1044 # 80025000 <disk>
    8000841c:	00e787b3          	add	a5,a5,a4
    80008420:	0207b423          	sd	zero,40(a5)
    int flag = disk.desc[i].flags;
    80008424:	0001f997          	auipc	s3,0x1f
    80008428:	bdc98993          	addi	s3,s3,-1060 # 80027000 <disk+0x2000>
    8000842c:	00491713          	slli	a4,s2,0x4
    80008430:	0009b783          	ld	a5,0(s3)
    80008434:	00e787b3          	add	a5,a5,a4
    80008438:	00c7d483          	lhu	s1,12(a5)
    int nxt = disk.desc[i].next;
    8000843c:	00090513          	mv	a0,s2
    80008440:	00e7d903          	lhu	s2,14(a5)
    free_desc(i);
    80008444:	00000097          	auipc	ra,0x0
    80008448:	b3c080e7          	jalr	-1220(ra) # 80007f80 <free_desc>
    if(flag & VRING_DESC_F_NEXT)
    8000844c:	0014f493          	andi	s1,s1,1
    80008450:	fc049ee3          	bnez	s1,8000842c <virtio_disk_rw+0x240>
  free_chain(idx[0]);

  release(&disk.vdisk_lock);
    80008454:	0001f517          	auipc	a0,0x1f
    80008458:	cd450513          	addi	a0,a0,-812 # 80027128 <disk+0x2128>
    8000845c:	ffff9097          	auipc	ra,0xffff9
    80008460:	c68080e7          	jalr	-920(ra) # 800010c4 <release>
}
    80008464:	07813083          	ld	ra,120(sp)
    80008468:	07013403          	ld	s0,112(sp)
    8000846c:	06813483          	ld	s1,104(sp)
    80008470:	06013903          	ld	s2,96(sp)
    80008474:	05813983          	ld	s3,88(sp)
    80008478:	05013a03          	ld	s4,80(sp)
    8000847c:	04813a83          	ld	s5,72(sp)
    80008480:	04013b03          	ld	s6,64(sp)
    80008484:	03813b83          	ld	s7,56(sp)
    80008488:	03013c03          	ld	s8,48(sp)
    8000848c:	02813c83          	ld	s9,40(sp)
    80008490:	02013d03          	ld	s10,32(sp)
    80008494:	01813d83          	ld	s11,24(sp)
    80008498:	08010113          	addi	sp,sp,128
    8000849c:	00008067          	ret
  struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    800084a0:	f8042503          	lw	a0,-128(s0)
    800084a4:	20050793          	addi	a5,a0,512
    800084a8:	00479793          	slli	a5,a5,0x4
  if(write)
    800084ac:	0001d817          	auipc	a6,0x1d
    800084b0:	b5480813          	addi	a6,a6,-1196 # 80025000 <disk>
    800084b4:	00f80733          	add	a4,a6,a5
    800084b8:	01a036b3          	snez	a3,s10
    800084bc:	0ad72423          	sw	a3,168(a4)
  buf0->reserved = 0;
    800084c0:	0a072623          	sw	zero,172(a4)
  buf0->sector = sector;
    800084c4:	0b973823          	sd	s9,176(a4)
  disk.desc[idx[0]].addr = (uint64) buf0;
    800084c8:	ffffe637          	lui	a2,0xffffe
    800084cc:	00c78633          	add	a2,a5,a2
    800084d0:	0001f697          	auipc	a3,0x1f
    800084d4:	b3068693          	addi	a3,a3,-1232 # 80027000 <disk+0x2000>
    800084d8:	0006b703          	ld	a4,0(a3)
    800084dc:	00c70733          	add	a4,a4,a2
  struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    800084e0:	0a878593          	addi	a1,a5,168
    800084e4:	010585b3          	add	a1,a1,a6
  disk.desc[idx[0]].addr = (uint64) buf0;
    800084e8:	00b73023          	sd	a1,0(a4)
  disk.desc[idx[0]].len = sizeof(struct virtio_blk_req);
    800084ec:	0006b703          	ld	a4,0(a3)
    800084f0:	00c70733          	add	a4,a4,a2
    800084f4:	01000593          	li	a1,16
    800084f8:	00b72423          	sw	a1,8(a4)
  disk.desc[idx[0]].flags = VRING_DESC_F_NEXT;
    800084fc:	0006b703          	ld	a4,0(a3)
    80008500:	00c70733          	add	a4,a4,a2
    80008504:	00100593          	li	a1,1
    80008508:	00b71623          	sh	a1,12(a4)
  disk.desc[idx[0]].next = idx[1];
    8000850c:	f8442703          	lw	a4,-124(s0)
    80008510:	0006b583          	ld	a1,0(a3)
    80008514:	00c58633          	add	a2,a1,a2
    80008518:	00e61723          	sh	a4,14(a2) # ffffffffffffe00e <end+0xffffffff7ffd600e>
  disk.desc[idx[1]].addr = (uint64) b->data;
    8000851c:	00471713          	slli	a4,a4,0x4
    80008520:	0006b603          	ld	a2,0(a3)
    80008524:	00e60633          	add	a2,a2,a4
    80008528:	058a8593          	addi	a1,s5,88
    8000852c:	00b63023          	sd	a1,0(a2)
  disk.desc[idx[1]].len = BSIZE;
    80008530:	0006b683          	ld	a3,0(a3)
    80008534:	00e686b3          	add	a3,a3,a4
    80008538:	40000613          	li	a2,1024
    8000853c:	00c6a423          	sw	a2,8(a3)
  if(write)
    80008540:	dc0d10e3          	bnez	s10,80008300 <virtio_disk_rw+0x114>
    disk.desc[idx[1]].flags = VRING_DESC_F_WRITE; // device writes b->data
    80008544:	0001f697          	auipc	a3,0x1f
    80008548:	abc6b683          	ld	a3,-1348(a3) # 80027000 <disk+0x2000>
    8000854c:	00e686b3          	add	a3,a3,a4
    80008550:	00200613          	li	a2,2
    80008554:	00c69623          	sh	a2,12(a3)
    80008558:	db9ff06f          	j	80008310 <virtio_disk_rw+0x124>

000000008000855c <virtio_disk_intr>:

void
virtio_disk_intr()
{
    8000855c:	fe010113          	addi	sp,sp,-32
    80008560:	00113c23          	sd	ra,24(sp)
    80008564:	00813823          	sd	s0,16(sp)
    80008568:	00913423          	sd	s1,8(sp)
    8000856c:	01213023          	sd	s2,0(sp)
    80008570:	02010413          	addi	s0,sp,32
  acquire(&disk.vdisk_lock);
    80008574:	0001f517          	auipc	a0,0x1f
    80008578:	bb450513          	addi	a0,a0,-1100 # 80027128 <disk+0x2128>
    8000857c:	ffff9097          	auipc	ra,0xffff9
    80008580:	a50080e7          	jalr	-1456(ra) # 80000fcc <acquire>
  // we've seen this interrupt, which the following line does.
  // this may race with the device writing new entries to
  // the "used" ring, in which case we may process the new
  // completion entries in this interrupt, and have nothing to do
  // in the next interrupt, which is harmless.
  *R(VIRTIO_MMIO_INTERRUPT_ACK) = *R(VIRTIO_MMIO_INTERRUPT_STATUS) & 0x3;
    80008584:	10001737          	lui	a4,0x10001
    80008588:	06072783          	lw	a5,96(a4) # 10001060 <_entry-0x6fffefa0>
    8000858c:	0037f793          	andi	a5,a5,3
    80008590:	06f72223          	sw	a5,100(a4)

  __sync_synchronize();
    80008594:	0ff0000f          	fence

  // the device increments disk.used->idx when it
  // adds an entry to the used ring.

  while(disk.used_idx != disk.used->idx){
    80008598:	0001f797          	auipc	a5,0x1f
    8000859c:	a6878793          	addi	a5,a5,-1432 # 80027000 <disk+0x2000>
    800085a0:	0107b683          	ld	a3,16(a5)
    800085a4:	0207d703          	lhu	a4,32(a5)
    800085a8:	0026d783          	lhu	a5,2(a3)
    800085ac:	08f70063          	beq	a4,a5,8000862c <virtio_disk_intr+0xd0>
    __sync_synchronize();
    int id = disk.used->ring[disk.used_idx % NUM].id;
    800085b0:	0001d917          	auipc	s2,0x1d
    800085b4:	a5090913          	addi	s2,s2,-1456 # 80025000 <disk>
    800085b8:	0001f497          	auipc	s1,0x1f
    800085bc:	a4848493          	addi	s1,s1,-1464 # 80027000 <disk+0x2000>
    __sync_synchronize();
    800085c0:	0ff0000f          	fence
    int id = disk.used->ring[disk.used_idx % NUM].id;
    800085c4:	0104b703          	ld	a4,16(s1)
    800085c8:	0204d783          	lhu	a5,32(s1)
    800085cc:	0077f793          	andi	a5,a5,7
    800085d0:	00379793          	slli	a5,a5,0x3
    800085d4:	00f707b3          	add	a5,a4,a5
    800085d8:	0047a783          	lw	a5,4(a5)

    if(disk.info[id].status != 0)
    800085dc:	20078713          	addi	a4,a5,512
    800085e0:	00471713          	slli	a4,a4,0x4
    800085e4:	00e90733          	add	a4,s2,a4
    800085e8:	03074703          	lbu	a4,48(a4)
    800085ec:	06071463          	bnez	a4,80008654 <virtio_disk_intr+0xf8>
      panic("virtio_disk_intr status");

    struct buf *b = disk.info[id].b;
    800085f0:	20078793          	addi	a5,a5,512
    800085f4:	00479793          	slli	a5,a5,0x4
    800085f8:	00f907b3          	add	a5,s2,a5
    800085fc:	0287b503          	ld	a0,40(a5)
    b->disk = 0;   // disk is done with buf
    80008600:	00052223          	sw	zero,4(a0)
    wakeup(b);
    80008604:	ffffb097          	auipc	ra,0xffffb
    80008608:	9c8080e7          	jalr	-1592(ra) # 80002fcc <wakeup>

    disk.used_idx += 1;
    8000860c:	0204d783          	lhu	a5,32(s1)
    80008610:	0017879b          	addiw	a5,a5,1
    80008614:	03079793          	slli	a5,a5,0x30
    80008618:	0307d793          	srli	a5,a5,0x30
    8000861c:	02f49023          	sh	a5,32(s1)
  while(disk.used_idx != disk.used->idx){
    80008620:	0104b703          	ld	a4,16(s1)
    80008624:	00275703          	lhu	a4,2(a4)
    80008628:	f8f71ce3          	bne	a4,a5,800085c0 <virtio_disk_intr+0x64>
  }

  release(&disk.vdisk_lock);
    8000862c:	0001f517          	auipc	a0,0x1f
    80008630:	afc50513          	addi	a0,a0,-1284 # 80027128 <disk+0x2128>
    80008634:	ffff9097          	auipc	ra,0xffff9
    80008638:	a90080e7          	jalr	-1392(ra) # 800010c4 <release>
}
    8000863c:	01813083          	ld	ra,24(sp)
    80008640:	01013403          	ld	s0,16(sp)
    80008644:	00813483          	ld	s1,8(sp)
    80008648:	00013903          	ld	s2,0(sp)
    8000864c:	02010113          	addi	sp,sp,32
    80008650:	00008067          	ret
      panic("virtio_disk_intr status");
    80008654:	00002517          	auipc	a0,0x2
    80008658:	1a450513          	addi	a0,a0,420 # 8000a7f8 <syscalls+0x3b0>
    8000865c:	ffff8097          	auipc	ra,0xffff8
    80008660:	074080e7          	jalr	116(ra) # 800006d0 <panic>
	...

0000000080009000 <_trampoline>:
    80009000:	14051573          	csrrw	a0,sscratch,a0
    80009004:	02153423          	sd	ra,40(a0)
    80009008:	02253823          	sd	sp,48(a0)
    8000900c:	02353c23          	sd	gp,56(a0)
    80009010:	04453023          	sd	tp,64(a0)
    80009014:	04553423          	sd	t0,72(a0)
    80009018:	04653823          	sd	t1,80(a0)
    8000901c:	04753c23          	sd	t2,88(a0)
    80009020:	06853023          	sd	s0,96(a0)
    80009024:	06953423          	sd	s1,104(a0)
    80009028:	06b53c23          	sd	a1,120(a0)
    8000902c:	08c53023          	sd	a2,128(a0)
    80009030:	08d53423          	sd	a3,136(a0)
    80009034:	08e53823          	sd	a4,144(a0)
    80009038:	08f53c23          	sd	a5,152(a0)
    8000903c:	0b053023          	sd	a6,160(a0)
    80009040:	0b153423          	sd	a7,168(a0)
    80009044:	0b253823          	sd	s2,176(a0)
    80009048:	0b353c23          	sd	s3,184(a0)
    8000904c:	0d453023          	sd	s4,192(a0)
    80009050:	0d553423          	sd	s5,200(a0)
    80009054:	0d653823          	sd	s6,208(a0)
    80009058:	0d753c23          	sd	s7,216(a0)
    8000905c:	0f853023          	sd	s8,224(a0)
    80009060:	0f953423          	sd	s9,232(a0)
    80009064:	0fa53823          	sd	s10,240(a0)
    80009068:	0fb53c23          	sd	s11,248(a0)
    8000906c:	11c53023          	sd	t3,256(a0)
    80009070:	11d53423          	sd	t4,264(a0)
    80009074:	11e53823          	sd	t5,272(a0)
    80009078:	11f53c23          	sd	t6,280(a0)
    8000907c:	140022f3          	csrr	t0,sscratch
    80009080:	06553823          	sd	t0,112(a0)
    80009084:	00853103          	ld	sp,8(a0)
    80009088:	02053203          	ld	tp,32(a0)
    8000908c:	01053283          	ld	t0,16(a0)
    80009090:	00053303          	ld	t1,0(a0)
    80009094:	18031073          	csrw	satp,t1
    80009098:	12000073          	sfence.vma
    8000909c:	00028067          	jr	t0

00000000800090a0 <userret>:
    800090a0:	18059073          	csrw	satp,a1
    800090a4:	12000073          	sfence.vma
    800090a8:	07053283          	ld	t0,112(a0)
    800090ac:	14029073          	csrw	sscratch,t0
    800090b0:	02853083          	ld	ra,40(a0)
    800090b4:	03053103          	ld	sp,48(a0)
    800090b8:	03853183          	ld	gp,56(a0)
    800090bc:	04053203          	ld	tp,64(a0)
    800090c0:	04853283          	ld	t0,72(a0)
    800090c4:	05053303          	ld	t1,80(a0)
    800090c8:	05853383          	ld	t2,88(a0)
    800090cc:	06053403          	ld	s0,96(a0)
    800090d0:	06853483          	ld	s1,104(a0)
    800090d4:	07853583          	ld	a1,120(a0)
    800090d8:	08053603          	ld	a2,128(a0)
    800090dc:	08853683          	ld	a3,136(a0)
    800090e0:	09053703          	ld	a4,144(a0)
    800090e4:	09853783          	ld	a5,152(a0)
    800090e8:	0a053803          	ld	a6,160(a0)
    800090ec:	0a853883          	ld	a7,168(a0)
    800090f0:	0b053903          	ld	s2,176(a0)
    800090f4:	0b853983          	ld	s3,184(a0)
    800090f8:	0c053a03          	ld	s4,192(a0)
    800090fc:	0c853a83          	ld	s5,200(a0)
    80009100:	0d053b03          	ld	s6,208(a0)
    80009104:	0d853b83          	ld	s7,216(a0)
    80009108:	0e053c03          	ld	s8,224(a0)
    8000910c:	0e853c83          	ld	s9,232(a0)
    80009110:	0f053d03          	ld	s10,240(a0)
    80009114:	0f853d83          	ld	s11,248(a0)
    80009118:	10053e03          	ld	t3,256(a0)
    8000911c:	10853e83          	ld	t4,264(a0)
    80009120:	11053f03          	ld	t5,272(a0)
    80009124:	11853f83          	ld	t6,280(a0)
    80009128:	14051573          	csrrw	a0,sscratch,a0
    8000912c:	10200073          	sret
	...
