
kernel/kernel:     file format elf64-littleriscv


Disassembly of section .text:

0000000080000000 <_entry>:
    80000000:	00009117          	auipc	sp,0x9
    80000004:	86013103          	ld	sp,-1952(sp) # 80008860 <_GLOBAL_OFFSET_TABLE_+0x8>
    80000008:	6505                	lui	a0,0x1
    8000000a:	f14025f3          	csrr	a1,mhartid
    8000000e:	0585                	addi	a1,a1,1
    80000010:	02b50533          	mul	a0,a0,a1
    80000014:	912a                	add	sp,sp,a0
    80000016:	076000ef          	jal	ra,8000008c <start>

000000008000001a <spin>:
    8000001a:	a001                	j	8000001a <spin>

000000008000001c <timerinit>:
// which arrive at timervec in kernelvec.S,
// which turns them into software interrupts for
// devintr() in trap.c.
void
timerinit()
{
    8000001c:	1141                	addi	sp,sp,-16
    8000001e:	e422                	sd	s0,8(sp)
    80000020:	0800                	addi	s0,sp,16
// which hart (core) is this?
static inline uint64
r_mhartid()
{
  uint64 x;
  asm volatile("csrr %0, mhartid" : "=r" (x) );
    80000022:	f14027f3          	csrr	a5,mhartid
  // each CPU has a separate source of timer interrupts.
  int id = r_mhartid();
    80000026:	0007859b          	sext.w	a1,a5

  // ask the CLINT for a timer interrupt.
  int interval = 1000000; // cycles; about 1/10th second in qemu.
  *(uint64*)CLINT_MTIMECMP(id) = *(uint64*)CLINT_MTIME + interval;
    8000002a:	0037979b          	slliw	a5,a5,0x3
    8000002e:	02004737          	lui	a4,0x2004
    80000032:	97ba                	add	a5,a5,a4
    80000034:	0200c737          	lui	a4,0x200c
    80000038:	ff873703          	ld	a4,-8(a4) # 200bff8 <_entry-0x7dff4008>
    8000003c:	000f4637          	lui	a2,0xf4
    80000040:	24060613          	addi	a2,a2,576 # f4240 <_entry-0x7ff0bdc0>
    80000044:	9732                	add	a4,a4,a2
    80000046:	e398                	sd	a4,0(a5)

  // prepare information in scratch[] for timervec.
  // scratch[0..2] : space for timervec to save registers.
  // scratch[3] : address of CLINT MTIMECMP register.
  // scratch[4] : desired interval (in cycles) between timer interrupts.
  uint64 *scratch = &timer_scratch[id][0];
    80000048:	00259693          	slli	a3,a1,0x2
    8000004c:	96ae                	add	a3,a3,a1
    8000004e:	068e                	slli	a3,a3,0x3
    80000050:	00009717          	auipc	a4,0x9
    80000054:	ff070713          	addi	a4,a4,-16 # 80009040 <timer_scratch>
    80000058:	9736                	add	a4,a4,a3
  scratch[3] = CLINT_MTIMECMP(id);
    8000005a:	ef1c                	sd	a5,24(a4)
  scratch[4] = interval;
    8000005c:	f310                	sd	a2,32(a4)
}

static inline void 
w_mscratch(uint64 x)
{
  asm volatile("csrw mscratch, %0" : : "r" (x));
    8000005e:	34071073          	csrw	mscratch,a4
  asm volatile("csrw mtvec, %0" : : "r" (x));
    80000062:	00006797          	auipc	a5,0x6
    80000066:	a9e78793          	addi	a5,a5,-1378 # 80005b00 <timervec>
    8000006a:	30579073          	csrw	mtvec,a5
  asm volatile("csrr %0, mstatus" : "=r" (x) );
    8000006e:	300027f3          	csrr	a5,mstatus

  // set the machine-mode trap handler.
  w_mtvec((uint64)timervec);

  // enable machine-mode interrupts.
  w_mstatus(r_mstatus() | MSTATUS_MIE);
    80000072:	0087e793          	ori	a5,a5,8
  asm volatile("csrw mstatus, %0" : : "r" (x));
    80000076:	30079073          	csrw	mstatus,a5
  asm volatile("csrr %0, mie" : "=r" (x) );
    8000007a:	304027f3          	csrr	a5,mie

  // enable machine-mode timer interrupts.
  w_mie(r_mie() | MIE_MTIE);
    8000007e:	0807e793          	ori	a5,a5,128
  asm volatile("csrw mie, %0" : : "r" (x));
    80000082:	30479073          	csrw	mie,a5
}
    80000086:	6422                	ld	s0,8(sp)
    80000088:	0141                	addi	sp,sp,16
    8000008a:	8082                	ret

000000008000008c <start>:
{
    8000008c:	1141                	addi	sp,sp,-16
    8000008e:	e406                	sd	ra,8(sp)
    80000090:	e022                	sd	s0,0(sp)
    80000092:	0800                	addi	s0,sp,16
  asm volatile("csrr %0, mstatus" : "=r" (x) );
    80000094:	300027f3          	csrr	a5,mstatus
  x &= ~MSTATUS_MPP_MASK;
    80000098:	7779                	lui	a4,0xffffe
    8000009a:	7ff70713          	addi	a4,a4,2047 # ffffffffffffe7ff <end+0xffffffff7ffd87ff>
    8000009e:	8ff9                	and	a5,a5,a4
  x |= MSTATUS_MPP_S;
    800000a0:	6705                	lui	a4,0x1
    800000a2:	80070713          	addi	a4,a4,-2048 # 800 <_entry-0x7ffff800>
    800000a6:	8fd9                	or	a5,a5,a4
  asm volatile("csrw mstatus, %0" : : "r" (x));
    800000a8:	30079073          	csrw	mstatus,a5
  asm volatile("csrw mepc, %0" : : "r" (x));
    800000ac:	00001797          	auipc	a5,0x1
    800000b0:	da078793          	addi	a5,a5,-608 # 80000e4c <main>
    800000b4:	34179073          	csrw	mepc,a5
  asm volatile("csrw satp, %0" : : "r" (x));
    800000b8:	4781                	li	a5,0
    800000ba:	18079073          	csrw	satp,a5
  asm volatile("csrw medeleg, %0" : : "r" (x));
    800000be:	67c1                	lui	a5,0x10
    800000c0:	17fd                	addi	a5,a5,-1 # ffff <_entry-0x7fff0001>
    800000c2:	30279073          	csrw	medeleg,a5
  asm volatile("csrw mideleg, %0" : : "r" (x));
    800000c6:	30379073          	csrw	mideleg,a5
  asm volatile("csrr %0, sie" : "=r" (x) );
    800000ca:	104027f3          	csrr	a5,sie
  w_sie(r_sie() | SIE_SEIE | SIE_STIE | SIE_SSIE);
    800000ce:	2227e793          	ori	a5,a5,546
  asm volatile("csrw sie, %0" : : "r" (x));
    800000d2:	10479073          	csrw	sie,a5
  asm volatile("csrw pmpaddr0, %0" : : "r" (x));
    800000d6:	57fd                	li	a5,-1
    800000d8:	83a9                	srli	a5,a5,0xa
    800000da:	3b079073          	csrw	pmpaddr0,a5
  asm volatile("csrw pmpcfg0, %0" : : "r" (x));
    800000de:	47bd                	li	a5,15
    800000e0:	3a079073          	csrw	pmpcfg0,a5
  timerinit();
    800000e4:	00000097          	auipc	ra,0x0
    800000e8:	f38080e7          	jalr	-200(ra) # 8000001c <timerinit>
  asm volatile("csrr %0, mhartid" : "=r" (x) );
    800000ec:	f14027f3          	csrr	a5,mhartid
  w_tp(id);
    800000f0:	2781                	sext.w	a5,a5
}

static inline void 
w_tp(uint64 x)
{
  asm volatile("mv tp, %0" : : "r" (x));
    800000f2:	823e                	mv	tp,a5
  asm volatile("mret");
    800000f4:	30200073          	mret
}
    800000f8:	60a2                	ld	ra,8(sp)
    800000fa:	6402                	ld	s0,0(sp)
    800000fc:	0141                	addi	sp,sp,16
    800000fe:	8082                	ret

0000000080000100 <consolewrite>:
//
// user write()s to the console go here.
//
int
consolewrite(int user_src, uint64 src, int n)
{
    80000100:	715d                	addi	sp,sp,-80
    80000102:	e486                	sd	ra,72(sp)
    80000104:	e0a2                	sd	s0,64(sp)
    80000106:	fc26                	sd	s1,56(sp)
    80000108:	f84a                	sd	s2,48(sp)
    8000010a:	f44e                	sd	s3,40(sp)
    8000010c:	f052                	sd	s4,32(sp)
    8000010e:	ec56                	sd	s5,24(sp)
    80000110:	0880                	addi	s0,sp,80
  int i;

  for(i = 0; i < n; i++){
    80000112:	04c05763          	blez	a2,80000160 <consolewrite+0x60>
    80000116:	8a2a                	mv	s4,a0
    80000118:	84ae                	mv	s1,a1
    8000011a:	89b2                	mv	s3,a2
    8000011c:	4901                	li	s2,0
    char c;
    if(either_copyin(&c, user_src, src+i, 1) == -1)
    8000011e:	5afd                	li	s5,-1
    80000120:	4685                	li	a3,1
    80000122:	8626                	mv	a2,s1
    80000124:	85d2                	mv	a1,s4
    80000126:	fbf40513          	addi	a0,s0,-65
    8000012a:	00002097          	auipc	ra,0x2
    8000012e:	304080e7          	jalr	772(ra) # 8000242e <either_copyin>
    80000132:	01550d63          	beq	a0,s5,8000014c <consolewrite+0x4c>
      break;
    uartputc(c);
    80000136:	fbf44503          	lbu	a0,-65(s0)
    8000013a:	00000097          	auipc	ra,0x0
    8000013e:	77e080e7          	jalr	1918(ra) # 800008b8 <uartputc>
  for(i = 0; i < n; i++){
    80000142:	2905                	addiw	s2,s2,1
    80000144:	0485                	addi	s1,s1,1
    80000146:	fd299de3          	bne	s3,s2,80000120 <consolewrite+0x20>
    8000014a:	894e                	mv	s2,s3
  }

  return i;
}
    8000014c:	854a                	mv	a0,s2
    8000014e:	60a6                	ld	ra,72(sp)
    80000150:	6406                	ld	s0,64(sp)
    80000152:	74e2                	ld	s1,56(sp)
    80000154:	7942                	ld	s2,48(sp)
    80000156:	79a2                	ld	s3,40(sp)
    80000158:	7a02                	ld	s4,32(sp)
    8000015a:	6ae2                	ld	s5,24(sp)
    8000015c:	6161                	addi	sp,sp,80
    8000015e:	8082                	ret
  for(i = 0; i < n; i++){
    80000160:	4901                	li	s2,0
    80000162:	b7ed                	j	8000014c <consolewrite+0x4c>

0000000080000164 <consoleread>:
// user_dist indicates whether dst is a user
// or kernel address.
//
int
consoleread(int user_dst, uint64 dst, int n)
{
    80000164:	7159                	addi	sp,sp,-112
    80000166:	f486                	sd	ra,104(sp)
    80000168:	f0a2                	sd	s0,96(sp)
    8000016a:	eca6                	sd	s1,88(sp)
    8000016c:	e8ca                	sd	s2,80(sp)
    8000016e:	e4ce                	sd	s3,72(sp)
    80000170:	e0d2                	sd	s4,64(sp)
    80000172:	fc56                	sd	s5,56(sp)
    80000174:	f85a                	sd	s6,48(sp)
    80000176:	f45e                	sd	s7,40(sp)
    80000178:	f062                	sd	s8,32(sp)
    8000017a:	ec66                	sd	s9,24(sp)
    8000017c:	e86a                	sd	s10,16(sp)
    8000017e:	1880                	addi	s0,sp,112
    80000180:	8aaa                	mv	s5,a0
    80000182:	8a2e                	mv	s4,a1
    80000184:	89b2                	mv	s3,a2
  uint target;
  int c;
  char cbuf;

  target = n;
    80000186:	00060b1b          	sext.w	s6,a2
  acquire(&cons.lock);
    8000018a:	00011517          	auipc	a0,0x11
    8000018e:	ff650513          	addi	a0,a0,-10 # 80011180 <cons>
    80000192:	00001097          	auipc	ra,0x1
    80000196:	a18080e7          	jalr	-1512(ra) # 80000baa <acquire>
  while(n > 0){
    // wait until interrupt handler has put some
    // input into cons.buffer.
    while(cons.r == cons.w){
    8000019a:	00011497          	auipc	s1,0x11
    8000019e:	fe648493          	addi	s1,s1,-26 # 80011180 <cons>
      if(myproc()->killed){
        release(&cons.lock);
        return -1;
      }
      sleep(&cons.r, &cons.lock);
    800001a2:	00011917          	auipc	s2,0x11
    800001a6:	07690913          	addi	s2,s2,118 # 80011218 <cons+0x98>
    }

    c = cons.buf[cons.r++ % INPUT_BUF];

    if(c == C('D')){  // end-of-file
    800001aa:	4b91                	li	s7,4
      break;
    }

    // copy the input byte to the user-space buffer.
    cbuf = c;
    if(either_copyout(user_dst, dst, &cbuf, 1) == -1)
    800001ac:	5c7d                	li	s8,-1
      break;

    dst++;
    --n;

    if(c == '\n'){
    800001ae:	4ca9                	li	s9,10
  while(n > 0){
    800001b0:	07305863          	blez	s3,80000220 <consoleread+0xbc>
    while(cons.r == cons.w){
    800001b4:	0984a783          	lw	a5,152(s1)
    800001b8:	09c4a703          	lw	a4,156(s1)
    800001bc:	02f71463          	bne	a4,a5,800001e4 <consoleread+0x80>
      if(myproc()->killed){
    800001c0:	00001097          	auipc	ra,0x1
    800001c4:	7b0080e7          	jalr	1968(ra) # 80001970 <myproc>
    800001c8:	551c                	lw	a5,40(a0)
    800001ca:	e7b5                	bnez	a5,80000236 <consoleread+0xd2>
      sleep(&cons.r, &cons.lock);
    800001cc:	85a6                	mv	a1,s1
    800001ce:	854a                	mv	a0,s2
    800001d0:	00002097          	auipc	ra,0x2
    800001d4:	e64080e7          	jalr	-412(ra) # 80002034 <sleep>
    while(cons.r == cons.w){
    800001d8:	0984a783          	lw	a5,152(s1)
    800001dc:	09c4a703          	lw	a4,156(s1)
    800001e0:	fef700e3          	beq	a4,a5,800001c0 <consoleread+0x5c>
    c = cons.buf[cons.r++ % INPUT_BUF];
    800001e4:	0017871b          	addiw	a4,a5,1
    800001e8:	08e4ac23          	sw	a4,152(s1)
    800001ec:	07f7f713          	andi	a4,a5,127
    800001f0:	9726                	add	a4,a4,s1
    800001f2:	01874703          	lbu	a4,24(a4)
    800001f6:	00070d1b          	sext.w	s10,a4
    if(c == C('D')){  // end-of-file
    800001fa:	077d0563          	beq	s10,s7,80000264 <consoleread+0x100>
    cbuf = c;
    800001fe:	f8e40fa3          	sb	a4,-97(s0)
    if(either_copyout(user_dst, dst, &cbuf, 1) == -1)
    80000202:	4685                	li	a3,1
    80000204:	f9f40613          	addi	a2,s0,-97
    80000208:	85d2                	mv	a1,s4
    8000020a:	8556                	mv	a0,s5
    8000020c:	00002097          	auipc	ra,0x2
    80000210:	1cc080e7          	jalr	460(ra) # 800023d8 <either_copyout>
    80000214:	01850663          	beq	a0,s8,80000220 <consoleread+0xbc>
    dst++;
    80000218:	0a05                	addi	s4,s4,1
    --n;
    8000021a:	39fd                	addiw	s3,s3,-1
    if(c == '\n'){
    8000021c:	f99d1ae3          	bne	s10,s9,800001b0 <consoleread+0x4c>
      // a whole line has arrived, return to
      // the user-level read().
      break;
    }
  }
  release(&cons.lock);
    80000220:	00011517          	auipc	a0,0x11
    80000224:	f6050513          	addi	a0,a0,-160 # 80011180 <cons>
    80000228:	00001097          	auipc	ra,0x1
    8000022c:	a36080e7          	jalr	-1482(ra) # 80000c5e <release>

  return target - n;
    80000230:	413b053b          	subw	a0,s6,s3
    80000234:	a811                	j	80000248 <consoleread+0xe4>
        release(&cons.lock);
    80000236:	00011517          	auipc	a0,0x11
    8000023a:	f4a50513          	addi	a0,a0,-182 # 80011180 <cons>
    8000023e:	00001097          	auipc	ra,0x1
    80000242:	a20080e7          	jalr	-1504(ra) # 80000c5e <release>
        return -1;
    80000246:	557d                	li	a0,-1
}
    80000248:	70a6                	ld	ra,104(sp)
    8000024a:	7406                	ld	s0,96(sp)
    8000024c:	64e6                	ld	s1,88(sp)
    8000024e:	6946                	ld	s2,80(sp)
    80000250:	69a6                	ld	s3,72(sp)
    80000252:	6a06                	ld	s4,64(sp)
    80000254:	7ae2                	ld	s5,56(sp)
    80000256:	7b42                	ld	s6,48(sp)
    80000258:	7ba2                	ld	s7,40(sp)
    8000025a:	7c02                	ld	s8,32(sp)
    8000025c:	6ce2                	ld	s9,24(sp)
    8000025e:	6d42                	ld	s10,16(sp)
    80000260:	6165                	addi	sp,sp,112
    80000262:	8082                	ret
      if(n < target){
    80000264:	0009871b          	sext.w	a4,s3
    80000268:	fb677ce3          	bgeu	a4,s6,80000220 <consoleread+0xbc>
        cons.r--;
    8000026c:	00011717          	auipc	a4,0x11
    80000270:	faf72623          	sw	a5,-84(a4) # 80011218 <cons+0x98>
    80000274:	b775                	j	80000220 <consoleread+0xbc>

0000000080000276 <consputc>:
{
    80000276:	1141                	addi	sp,sp,-16
    80000278:	e406                	sd	ra,8(sp)
    8000027a:	e022                	sd	s0,0(sp)
    8000027c:	0800                	addi	s0,sp,16
  if(c == BACKSPACE){
    8000027e:	10000793          	li	a5,256
    80000282:	00f50a63          	beq	a0,a5,80000296 <consputc+0x20>
    uartputc_sync(c);
    80000286:	00000097          	auipc	ra,0x0
    8000028a:	560080e7          	jalr	1376(ra) # 800007e6 <uartputc_sync>
}
    8000028e:	60a2                	ld	ra,8(sp)
    80000290:	6402                	ld	s0,0(sp)
    80000292:	0141                	addi	sp,sp,16
    80000294:	8082                	ret
    uartputc_sync('\b'); uartputc_sync(' '); uartputc_sync('\b');
    80000296:	4521                	li	a0,8
    80000298:	00000097          	auipc	ra,0x0
    8000029c:	54e080e7          	jalr	1358(ra) # 800007e6 <uartputc_sync>
    800002a0:	02000513          	li	a0,32
    800002a4:	00000097          	auipc	ra,0x0
    800002a8:	542080e7          	jalr	1346(ra) # 800007e6 <uartputc_sync>
    800002ac:	4521                	li	a0,8
    800002ae:	00000097          	auipc	ra,0x0
    800002b2:	538080e7          	jalr	1336(ra) # 800007e6 <uartputc_sync>
    800002b6:	bfe1                	j	8000028e <consputc+0x18>

00000000800002b8 <consoleintr>:
// do erase/kill processing, append to cons.buf,
// wake up consoleread() if a whole line has arrived.
//
void
consoleintr(int c)
{
    800002b8:	1101                	addi	sp,sp,-32
    800002ba:	ec06                	sd	ra,24(sp)
    800002bc:	e822                	sd	s0,16(sp)
    800002be:	e426                	sd	s1,8(sp)
    800002c0:	e04a                	sd	s2,0(sp)
    800002c2:	1000                	addi	s0,sp,32
    800002c4:	84aa                	mv	s1,a0
  acquire(&cons.lock);
    800002c6:	00011517          	auipc	a0,0x11
    800002ca:	eba50513          	addi	a0,a0,-326 # 80011180 <cons>
    800002ce:	00001097          	auipc	ra,0x1
    800002d2:	8dc080e7          	jalr	-1828(ra) # 80000baa <acquire>

  switch(c){
    800002d6:	47d5                	li	a5,21
    800002d8:	0af48663          	beq	s1,a5,80000384 <consoleintr+0xcc>
    800002dc:	0297ca63          	blt	a5,s1,80000310 <consoleintr+0x58>
    800002e0:	47a1                	li	a5,8
    800002e2:	0ef48763          	beq	s1,a5,800003d0 <consoleintr+0x118>
    800002e6:	47c1                	li	a5,16
    800002e8:	10f49a63          	bne	s1,a5,800003fc <consoleintr+0x144>
  case C('P'):  // Print process list.
    procdump();
    800002ec:	00002097          	auipc	ra,0x2
    800002f0:	198080e7          	jalr	408(ra) # 80002484 <procdump>
      }
    }
    break;
  }
  
  release(&cons.lock);
    800002f4:	00011517          	auipc	a0,0x11
    800002f8:	e8c50513          	addi	a0,a0,-372 # 80011180 <cons>
    800002fc:	00001097          	auipc	ra,0x1
    80000300:	962080e7          	jalr	-1694(ra) # 80000c5e <release>
}
    80000304:	60e2                	ld	ra,24(sp)
    80000306:	6442                	ld	s0,16(sp)
    80000308:	64a2                	ld	s1,8(sp)
    8000030a:	6902                	ld	s2,0(sp)
    8000030c:	6105                	addi	sp,sp,32
    8000030e:	8082                	ret
  switch(c){
    80000310:	07f00793          	li	a5,127
    80000314:	0af48e63          	beq	s1,a5,800003d0 <consoleintr+0x118>
    if(c != 0 && cons.e-cons.r < INPUT_BUF){
    80000318:	00011717          	auipc	a4,0x11
    8000031c:	e6870713          	addi	a4,a4,-408 # 80011180 <cons>
    80000320:	0a072783          	lw	a5,160(a4)
    80000324:	09872703          	lw	a4,152(a4)
    80000328:	9f99                	subw	a5,a5,a4
    8000032a:	07f00713          	li	a4,127
    8000032e:	fcf763e3          	bltu	a4,a5,800002f4 <consoleintr+0x3c>
      c = (c == '\r') ? '\n' : c;
    80000332:	47b5                	li	a5,13
    80000334:	0cf48763          	beq	s1,a5,80000402 <consoleintr+0x14a>
      consputc(c);
    80000338:	8526                	mv	a0,s1
    8000033a:	00000097          	auipc	ra,0x0
    8000033e:	f3c080e7          	jalr	-196(ra) # 80000276 <consputc>
      cons.buf[cons.e++ % INPUT_BUF] = c;
    80000342:	00011797          	auipc	a5,0x11
    80000346:	e3e78793          	addi	a5,a5,-450 # 80011180 <cons>
    8000034a:	0a07a703          	lw	a4,160(a5)
    8000034e:	0017069b          	addiw	a3,a4,1
    80000352:	0006861b          	sext.w	a2,a3
    80000356:	0ad7a023          	sw	a3,160(a5)
    8000035a:	07f77713          	andi	a4,a4,127
    8000035e:	97ba                	add	a5,a5,a4
    80000360:	00978c23          	sb	s1,24(a5)
      if(c == '\n' || c == C('D') || cons.e == cons.r+INPUT_BUF){
    80000364:	47a9                	li	a5,10
    80000366:	0cf48563          	beq	s1,a5,80000430 <consoleintr+0x178>
    8000036a:	4791                	li	a5,4
    8000036c:	0cf48263          	beq	s1,a5,80000430 <consoleintr+0x178>
    80000370:	00011797          	auipc	a5,0x11
    80000374:	ea87a783          	lw	a5,-344(a5) # 80011218 <cons+0x98>
    80000378:	0807879b          	addiw	a5,a5,128
    8000037c:	f6f61ce3          	bne	a2,a5,800002f4 <consoleintr+0x3c>
      cons.buf[cons.e++ % INPUT_BUF] = c;
    80000380:	863e                	mv	a2,a5
    80000382:	a07d                	j	80000430 <consoleintr+0x178>
    while(cons.e != cons.w &&
    80000384:	00011717          	auipc	a4,0x11
    80000388:	dfc70713          	addi	a4,a4,-516 # 80011180 <cons>
    8000038c:	0a072783          	lw	a5,160(a4)
    80000390:	09c72703          	lw	a4,156(a4)
          cons.buf[(cons.e-1) % INPUT_BUF] != '\n'){
    80000394:	00011497          	auipc	s1,0x11
    80000398:	dec48493          	addi	s1,s1,-532 # 80011180 <cons>
    while(cons.e != cons.w &&
    8000039c:	4929                	li	s2,10
    8000039e:	f4f70be3          	beq	a4,a5,800002f4 <consoleintr+0x3c>
          cons.buf[(cons.e-1) % INPUT_BUF] != '\n'){
    800003a2:	37fd                	addiw	a5,a5,-1
    800003a4:	07f7f713          	andi	a4,a5,127
    800003a8:	9726                	add	a4,a4,s1
    while(cons.e != cons.w &&
    800003aa:	01874703          	lbu	a4,24(a4)
    800003ae:	f52703e3          	beq	a4,s2,800002f4 <consoleintr+0x3c>
      cons.e--;
    800003b2:	0af4a023          	sw	a5,160(s1)
      consputc(BACKSPACE);
    800003b6:	10000513          	li	a0,256
    800003ba:	00000097          	auipc	ra,0x0
    800003be:	ebc080e7          	jalr	-324(ra) # 80000276 <consputc>
    while(cons.e != cons.w &&
    800003c2:	0a04a783          	lw	a5,160(s1)
    800003c6:	09c4a703          	lw	a4,156(s1)
    800003ca:	fcf71ce3          	bne	a4,a5,800003a2 <consoleintr+0xea>
    800003ce:	b71d                	j	800002f4 <consoleintr+0x3c>
    if(cons.e != cons.w){
    800003d0:	00011717          	auipc	a4,0x11
    800003d4:	db070713          	addi	a4,a4,-592 # 80011180 <cons>
    800003d8:	0a072783          	lw	a5,160(a4)
    800003dc:	09c72703          	lw	a4,156(a4)
    800003e0:	f0f70ae3          	beq	a4,a5,800002f4 <consoleintr+0x3c>
      cons.e--;
    800003e4:	37fd                	addiw	a5,a5,-1
    800003e6:	00011717          	auipc	a4,0x11
    800003ea:	e2f72d23          	sw	a5,-454(a4) # 80011220 <cons+0xa0>
      consputc(BACKSPACE);
    800003ee:	10000513          	li	a0,256
    800003f2:	00000097          	auipc	ra,0x0
    800003f6:	e84080e7          	jalr	-380(ra) # 80000276 <consputc>
    800003fa:	bded                	j	800002f4 <consoleintr+0x3c>
    if(c != 0 && cons.e-cons.r < INPUT_BUF){
    800003fc:	ee048ce3          	beqz	s1,800002f4 <consoleintr+0x3c>
    80000400:	bf21                	j	80000318 <consoleintr+0x60>
      consputc(c);
    80000402:	4529                	li	a0,10
    80000404:	00000097          	auipc	ra,0x0
    80000408:	e72080e7          	jalr	-398(ra) # 80000276 <consputc>
      cons.buf[cons.e++ % INPUT_BUF] = c;
    8000040c:	00011797          	auipc	a5,0x11
    80000410:	d7478793          	addi	a5,a5,-652 # 80011180 <cons>
    80000414:	0a07a703          	lw	a4,160(a5)
    80000418:	0017069b          	addiw	a3,a4,1
    8000041c:	0006861b          	sext.w	a2,a3
    80000420:	0ad7a023          	sw	a3,160(a5)
    80000424:	07f77713          	andi	a4,a4,127
    80000428:	97ba                	add	a5,a5,a4
    8000042a:	4729                	li	a4,10
    8000042c:	00e78c23          	sb	a4,24(a5)
        cons.w = cons.e;
    80000430:	00011797          	auipc	a5,0x11
    80000434:	dec7a623          	sw	a2,-532(a5) # 8001121c <cons+0x9c>
        wakeup(&cons.r);
    80000438:	00011517          	auipc	a0,0x11
    8000043c:	de050513          	addi	a0,a0,-544 # 80011218 <cons+0x98>
    80000440:	00002097          	auipc	ra,0x2
    80000444:	d80080e7          	jalr	-640(ra) # 800021c0 <wakeup>
    80000448:	b575                	j	800002f4 <consoleintr+0x3c>

000000008000044a <consoleinit>:

void
consoleinit(void)
{
    8000044a:	1141                	addi	sp,sp,-16
    8000044c:	e406                	sd	ra,8(sp)
    8000044e:	e022                	sd	s0,0(sp)
    80000450:	0800                	addi	s0,sp,16
  initlock(&cons.lock, "cons");
    80000452:	00008597          	auipc	a1,0x8
    80000456:	bbe58593          	addi	a1,a1,-1090 # 80008010 <etext+0x10>
    8000045a:	00011517          	auipc	a0,0x11
    8000045e:	d2650513          	addi	a0,a0,-730 # 80011180 <cons>
    80000462:	00000097          	auipc	ra,0x0
    80000466:	6b8080e7          	jalr	1720(ra) # 80000b1a <initlock>

  uartinit();
    8000046a:	00000097          	auipc	ra,0x0
    8000046e:	32c080e7          	jalr	812(ra) # 80000796 <uartinit>

  // connect read and write system calls
  // to consoleread and consolewrite.
  devsw[CONSOLE].read = consoleread;
    80000472:	00021797          	auipc	a5,0x21
    80000476:	ea678793          	addi	a5,a5,-346 # 80021318 <devsw>
    8000047a:	00000717          	auipc	a4,0x0
    8000047e:	cea70713          	addi	a4,a4,-790 # 80000164 <consoleread>
    80000482:	eb98                	sd	a4,16(a5)
  devsw[CONSOLE].write = consolewrite;
    80000484:	00000717          	auipc	a4,0x0
    80000488:	c7c70713          	addi	a4,a4,-900 # 80000100 <consolewrite>
    8000048c:	ef98                	sd	a4,24(a5)
}
    8000048e:	60a2                	ld	ra,8(sp)
    80000490:	6402                	ld	s0,0(sp)
    80000492:	0141                	addi	sp,sp,16
    80000494:	8082                	ret

0000000080000496 <printint>:

static char digits[] = "0123456789abcdef";

static void
printint(int xx, int base, int sign)
{
    80000496:	7179                	addi	sp,sp,-48
    80000498:	f406                	sd	ra,40(sp)
    8000049a:	f022                	sd	s0,32(sp)
    8000049c:	ec26                	sd	s1,24(sp)
    8000049e:	e84a                	sd	s2,16(sp)
    800004a0:	1800                	addi	s0,sp,48
  char buf[16];
  int i;
  uint x;

  if(sign && (sign = xx < 0))
    800004a2:	c219                	beqz	a2,800004a8 <printint+0x12>
    800004a4:	08054763          	bltz	a0,80000532 <printint+0x9c>
    x = -xx;
  else
    x = xx;
    800004a8:	2501                	sext.w	a0,a0
    800004aa:	4881                	li	a7,0
    800004ac:	fd040693          	addi	a3,s0,-48

  i = 0;
    800004b0:	4701                	li	a4,0
  do {
    buf[i++] = digits[x % base];
    800004b2:	2581                	sext.w	a1,a1
    800004b4:	00008617          	auipc	a2,0x8
    800004b8:	b8c60613          	addi	a2,a2,-1140 # 80008040 <digits>
    800004bc:	883a                	mv	a6,a4
    800004be:	2705                	addiw	a4,a4,1
    800004c0:	02b577bb          	remuw	a5,a0,a1
    800004c4:	1782                	slli	a5,a5,0x20
    800004c6:	9381                	srli	a5,a5,0x20
    800004c8:	97b2                	add	a5,a5,a2
    800004ca:	0007c783          	lbu	a5,0(a5)
    800004ce:	00f68023          	sb	a5,0(a3)
  } while((x /= base) != 0);
    800004d2:	0005079b          	sext.w	a5,a0
    800004d6:	02b5553b          	divuw	a0,a0,a1
    800004da:	0685                	addi	a3,a3,1
    800004dc:	feb7f0e3          	bgeu	a5,a1,800004bc <printint+0x26>

  if(sign)
    800004e0:	00088c63          	beqz	a7,800004f8 <printint+0x62>
    buf[i++] = '-';
    800004e4:	fe070793          	addi	a5,a4,-32
    800004e8:	00878733          	add	a4,a5,s0
    800004ec:	02d00793          	li	a5,45
    800004f0:	fef70823          	sb	a5,-16(a4)
    800004f4:	0028071b          	addiw	a4,a6,2

  while(--i >= 0)
    800004f8:	02e05763          	blez	a4,80000526 <printint+0x90>
    800004fc:	fd040793          	addi	a5,s0,-48
    80000500:	00e784b3          	add	s1,a5,a4
    80000504:	fff78913          	addi	s2,a5,-1
    80000508:	993a                	add	s2,s2,a4
    8000050a:	377d                	addiw	a4,a4,-1
    8000050c:	1702                	slli	a4,a4,0x20
    8000050e:	9301                	srli	a4,a4,0x20
    80000510:	40e90933          	sub	s2,s2,a4
    consputc(buf[i]);
    80000514:	fff4c503          	lbu	a0,-1(s1)
    80000518:	00000097          	auipc	ra,0x0
    8000051c:	d5e080e7          	jalr	-674(ra) # 80000276 <consputc>
  while(--i >= 0)
    80000520:	14fd                	addi	s1,s1,-1
    80000522:	ff2499e3          	bne	s1,s2,80000514 <printint+0x7e>
}
    80000526:	70a2                	ld	ra,40(sp)
    80000528:	7402                	ld	s0,32(sp)
    8000052a:	64e2                	ld	s1,24(sp)
    8000052c:	6942                	ld	s2,16(sp)
    8000052e:	6145                	addi	sp,sp,48
    80000530:	8082                	ret
    x = -xx;
    80000532:	40a0053b          	negw	a0,a0
  if(sign && (sign = xx < 0))
    80000536:	4885                	li	a7,1
    x = -xx;
    80000538:	bf95                	j	800004ac <printint+0x16>

000000008000053a <panic>:
    release(&pr.lock);
}

void
panic(char *s)
{
    8000053a:	1101                	addi	sp,sp,-32
    8000053c:	ec06                	sd	ra,24(sp)
    8000053e:	e822                	sd	s0,16(sp)
    80000540:	e426                	sd	s1,8(sp)
    80000542:	1000                	addi	s0,sp,32
    80000544:	84aa                	mv	s1,a0
  pr.locking = 0;
    80000546:	00011797          	auipc	a5,0x11
    8000054a:	ce07ad23          	sw	zero,-774(a5) # 80011240 <pr+0x18>
  printf("panic: ");
    8000054e:	00008517          	auipc	a0,0x8
    80000552:	aca50513          	addi	a0,a0,-1334 # 80008018 <etext+0x18>
    80000556:	00000097          	auipc	ra,0x0
    8000055a:	02e080e7          	jalr	46(ra) # 80000584 <printf>
  printf(s);
    8000055e:	8526                	mv	a0,s1
    80000560:	00000097          	auipc	ra,0x0
    80000564:	024080e7          	jalr	36(ra) # 80000584 <printf>
  printf("\n");
    80000568:	00008517          	auipc	a0,0x8
    8000056c:	b6050513          	addi	a0,a0,-1184 # 800080c8 <digits+0x88>
    80000570:	00000097          	auipc	ra,0x0
    80000574:	014080e7          	jalr	20(ra) # 80000584 <printf>
  panicked = 1; // freeze uart output from other CPUs
    80000578:	4785                	li	a5,1
    8000057a:	00009717          	auipc	a4,0x9
    8000057e:	a8f72323          	sw	a5,-1402(a4) # 80009000 <panicked>
  for(;;)
    80000582:	a001                	j	80000582 <panic+0x48>

0000000080000584 <printf>:
{
    80000584:	7131                	addi	sp,sp,-192
    80000586:	fc86                	sd	ra,120(sp)
    80000588:	f8a2                	sd	s0,112(sp)
    8000058a:	f4a6                	sd	s1,104(sp)
    8000058c:	f0ca                	sd	s2,96(sp)
    8000058e:	ecce                	sd	s3,88(sp)
    80000590:	e8d2                	sd	s4,80(sp)
    80000592:	e4d6                	sd	s5,72(sp)
    80000594:	e0da                	sd	s6,64(sp)
    80000596:	fc5e                	sd	s7,56(sp)
    80000598:	f862                	sd	s8,48(sp)
    8000059a:	f466                	sd	s9,40(sp)
    8000059c:	f06a                	sd	s10,32(sp)
    8000059e:	ec6e                	sd	s11,24(sp)
    800005a0:	0100                	addi	s0,sp,128
    800005a2:	8a2a                	mv	s4,a0
    800005a4:	e40c                	sd	a1,8(s0)
    800005a6:	e810                	sd	a2,16(s0)
    800005a8:	ec14                	sd	a3,24(s0)
    800005aa:	f018                	sd	a4,32(s0)
    800005ac:	f41c                	sd	a5,40(s0)
    800005ae:	03043823          	sd	a6,48(s0)
    800005b2:	03143c23          	sd	a7,56(s0)
  locking = pr.locking;
    800005b6:	00011d97          	auipc	s11,0x11
    800005ba:	c8adad83          	lw	s11,-886(s11) # 80011240 <pr+0x18>
  if(locking)
    800005be:	020d9b63          	bnez	s11,800005f4 <printf+0x70>
  if (fmt == 0)
    800005c2:	040a0263          	beqz	s4,80000606 <printf+0x82>
  va_start(ap, fmt);
    800005c6:	00840793          	addi	a5,s0,8
    800005ca:	f8f43423          	sd	a5,-120(s0)
  for(i = 0; (c = fmt[i] & 0xff) != 0; i++){
    800005ce:	000a4503          	lbu	a0,0(s4)
    800005d2:	14050f63          	beqz	a0,80000730 <printf+0x1ac>
    800005d6:	4981                	li	s3,0
    if(c != '%'){
    800005d8:	02500a93          	li	s5,37
    switch(c){
    800005dc:	07000b93          	li	s7,112
  consputc('x');
    800005e0:	4d41                	li	s10,16
    consputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    800005e2:	00008b17          	auipc	s6,0x8
    800005e6:	a5eb0b13          	addi	s6,s6,-1442 # 80008040 <digits>
    switch(c){
    800005ea:	07300c93          	li	s9,115
    800005ee:	06400c13          	li	s8,100
    800005f2:	a82d                	j	8000062c <printf+0xa8>
    acquire(&pr.lock);
    800005f4:	00011517          	auipc	a0,0x11
    800005f8:	c3450513          	addi	a0,a0,-972 # 80011228 <pr>
    800005fc:	00000097          	auipc	ra,0x0
    80000600:	5ae080e7          	jalr	1454(ra) # 80000baa <acquire>
    80000604:	bf7d                	j	800005c2 <printf+0x3e>
    panic("null fmt");
    80000606:	00008517          	auipc	a0,0x8
    8000060a:	a2250513          	addi	a0,a0,-1502 # 80008028 <etext+0x28>
    8000060e:	00000097          	auipc	ra,0x0
    80000612:	f2c080e7          	jalr	-212(ra) # 8000053a <panic>
      consputc(c);
    80000616:	00000097          	auipc	ra,0x0
    8000061a:	c60080e7          	jalr	-928(ra) # 80000276 <consputc>
  for(i = 0; (c = fmt[i] & 0xff) != 0; i++){
    8000061e:	2985                	addiw	s3,s3,1
    80000620:	013a07b3          	add	a5,s4,s3
    80000624:	0007c503          	lbu	a0,0(a5)
    80000628:	10050463          	beqz	a0,80000730 <printf+0x1ac>
    if(c != '%'){
    8000062c:	ff5515e3          	bne	a0,s5,80000616 <printf+0x92>
    c = fmt[++i] & 0xff;
    80000630:	2985                	addiw	s3,s3,1
    80000632:	013a07b3          	add	a5,s4,s3
    80000636:	0007c783          	lbu	a5,0(a5)
    8000063a:	0007849b          	sext.w	s1,a5
    if(c == 0)
    8000063e:	cbed                	beqz	a5,80000730 <printf+0x1ac>
    switch(c){
    80000640:	05778a63          	beq	a5,s7,80000694 <printf+0x110>
    80000644:	02fbf663          	bgeu	s7,a5,80000670 <printf+0xec>
    80000648:	09978863          	beq	a5,s9,800006d8 <printf+0x154>
    8000064c:	07800713          	li	a4,120
    80000650:	0ce79563          	bne	a5,a4,8000071a <printf+0x196>
      printint(va_arg(ap, int), 16, 1);
    80000654:	f8843783          	ld	a5,-120(s0)
    80000658:	00878713          	addi	a4,a5,8
    8000065c:	f8e43423          	sd	a4,-120(s0)
    80000660:	4605                	li	a2,1
    80000662:	85ea                	mv	a1,s10
    80000664:	4388                	lw	a0,0(a5)
    80000666:	00000097          	auipc	ra,0x0
    8000066a:	e30080e7          	jalr	-464(ra) # 80000496 <printint>
      break;
    8000066e:	bf45                	j	8000061e <printf+0x9a>
    switch(c){
    80000670:	09578f63          	beq	a5,s5,8000070e <printf+0x18a>
    80000674:	0b879363          	bne	a5,s8,8000071a <printf+0x196>
      printint(va_arg(ap, int), 10, 1);
    80000678:	f8843783          	ld	a5,-120(s0)
    8000067c:	00878713          	addi	a4,a5,8
    80000680:	f8e43423          	sd	a4,-120(s0)
    80000684:	4605                	li	a2,1
    80000686:	45a9                	li	a1,10
    80000688:	4388                	lw	a0,0(a5)
    8000068a:	00000097          	auipc	ra,0x0
    8000068e:	e0c080e7          	jalr	-500(ra) # 80000496 <printint>
      break;
    80000692:	b771                	j	8000061e <printf+0x9a>
      printptr(va_arg(ap, uint64));
    80000694:	f8843783          	ld	a5,-120(s0)
    80000698:	00878713          	addi	a4,a5,8
    8000069c:	f8e43423          	sd	a4,-120(s0)
    800006a0:	0007b903          	ld	s2,0(a5)
  consputc('0');
    800006a4:	03000513          	li	a0,48
    800006a8:	00000097          	auipc	ra,0x0
    800006ac:	bce080e7          	jalr	-1074(ra) # 80000276 <consputc>
  consputc('x');
    800006b0:	07800513          	li	a0,120
    800006b4:	00000097          	auipc	ra,0x0
    800006b8:	bc2080e7          	jalr	-1086(ra) # 80000276 <consputc>
    800006bc:	84ea                	mv	s1,s10
    consputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    800006be:	03c95793          	srli	a5,s2,0x3c
    800006c2:	97da                	add	a5,a5,s6
    800006c4:	0007c503          	lbu	a0,0(a5)
    800006c8:	00000097          	auipc	ra,0x0
    800006cc:	bae080e7          	jalr	-1106(ra) # 80000276 <consputc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
    800006d0:	0912                	slli	s2,s2,0x4
    800006d2:	34fd                	addiw	s1,s1,-1
    800006d4:	f4ed                	bnez	s1,800006be <printf+0x13a>
    800006d6:	b7a1                	j	8000061e <printf+0x9a>
      if((s = va_arg(ap, char*)) == 0)
    800006d8:	f8843783          	ld	a5,-120(s0)
    800006dc:	00878713          	addi	a4,a5,8
    800006e0:	f8e43423          	sd	a4,-120(s0)
    800006e4:	6384                	ld	s1,0(a5)
    800006e6:	cc89                	beqz	s1,80000700 <printf+0x17c>
      for(; *s; s++)
    800006e8:	0004c503          	lbu	a0,0(s1)
    800006ec:	d90d                	beqz	a0,8000061e <printf+0x9a>
        consputc(*s);
    800006ee:	00000097          	auipc	ra,0x0
    800006f2:	b88080e7          	jalr	-1144(ra) # 80000276 <consputc>
      for(; *s; s++)
    800006f6:	0485                	addi	s1,s1,1
    800006f8:	0004c503          	lbu	a0,0(s1)
    800006fc:	f96d                	bnez	a0,800006ee <printf+0x16a>
    800006fe:	b705                	j	8000061e <printf+0x9a>
        s = "(null)";
    80000700:	00008497          	auipc	s1,0x8
    80000704:	92048493          	addi	s1,s1,-1760 # 80008020 <etext+0x20>
      for(; *s; s++)
    80000708:	02800513          	li	a0,40
    8000070c:	b7cd                	j	800006ee <printf+0x16a>
      consputc('%');
    8000070e:	8556                	mv	a0,s5
    80000710:	00000097          	auipc	ra,0x0
    80000714:	b66080e7          	jalr	-1178(ra) # 80000276 <consputc>
      break;
    80000718:	b719                	j	8000061e <printf+0x9a>
      consputc('%');
    8000071a:	8556                	mv	a0,s5
    8000071c:	00000097          	auipc	ra,0x0
    80000720:	b5a080e7          	jalr	-1190(ra) # 80000276 <consputc>
      consputc(c);
    80000724:	8526                	mv	a0,s1
    80000726:	00000097          	auipc	ra,0x0
    8000072a:	b50080e7          	jalr	-1200(ra) # 80000276 <consputc>
      break;
    8000072e:	bdc5                	j	8000061e <printf+0x9a>
  if(locking)
    80000730:	020d9163          	bnez	s11,80000752 <printf+0x1ce>
}
    80000734:	70e6                	ld	ra,120(sp)
    80000736:	7446                	ld	s0,112(sp)
    80000738:	74a6                	ld	s1,104(sp)
    8000073a:	7906                	ld	s2,96(sp)
    8000073c:	69e6                	ld	s3,88(sp)
    8000073e:	6a46                	ld	s4,80(sp)
    80000740:	6aa6                	ld	s5,72(sp)
    80000742:	6b06                	ld	s6,64(sp)
    80000744:	7be2                	ld	s7,56(sp)
    80000746:	7c42                	ld	s8,48(sp)
    80000748:	7ca2                	ld	s9,40(sp)
    8000074a:	7d02                	ld	s10,32(sp)
    8000074c:	6de2                	ld	s11,24(sp)
    8000074e:	6129                	addi	sp,sp,192
    80000750:	8082                	ret
    release(&pr.lock);
    80000752:	00011517          	auipc	a0,0x11
    80000756:	ad650513          	addi	a0,a0,-1322 # 80011228 <pr>
    8000075a:	00000097          	auipc	ra,0x0
    8000075e:	504080e7          	jalr	1284(ra) # 80000c5e <release>
}
    80000762:	bfc9                	j	80000734 <printf+0x1b0>

0000000080000764 <printfinit>:
    ;
}

void
printfinit(void)
{
    80000764:	1101                	addi	sp,sp,-32
    80000766:	ec06                	sd	ra,24(sp)
    80000768:	e822                	sd	s0,16(sp)
    8000076a:	e426                	sd	s1,8(sp)
    8000076c:	1000                	addi	s0,sp,32
  initlock(&pr.lock, "pr");
    8000076e:	00011497          	auipc	s1,0x11
    80000772:	aba48493          	addi	s1,s1,-1350 # 80011228 <pr>
    80000776:	00008597          	auipc	a1,0x8
    8000077a:	8c258593          	addi	a1,a1,-1854 # 80008038 <etext+0x38>
    8000077e:	8526                	mv	a0,s1
    80000780:	00000097          	auipc	ra,0x0
    80000784:	39a080e7          	jalr	922(ra) # 80000b1a <initlock>
  pr.locking = 1;
    80000788:	4785                	li	a5,1
    8000078a:	cc9c                	sw	a5,24(s1)
}
    8000078c:	60e2                	ld	ra,24(sp)
    8000078e:	6442                	ld	s0,16(sp)
    80000790:	64a2                	ld	s1,8(sp)
    80000792:	6105                	addi	sp,sp,32
    80000794:	8082                	ret

0000000080000796 <uartinit>:

void uartstart();

void
uartinit(void)
{
    80000796:	1141                	addi	sp,sp,-16
    80000798:	e406                	sd	ra,8(sp)
    8000079a:	e022                	sd	s0,0(sp)
    8000079c:	0800                	addi	s0,sp,16
  // disable interrupts.
  WriteReg(IER, 0x00);
    8000079e:	100007b7          	lui	a5,0x10000
    800007a2:	000780a3          	sb	zero,1(a5) # 10000001 <_entry-0x6fffffff>

  // special mode to set baud rate.
  WriteReg(LCR, LCR_BAUD_LATCH);
    800007a6:	f8000713          	li	a4,-128
    800007aa:	00e781a3          	sb	a4,3(a5)

  // LSB for baud rate of 38.4K.
  WriteReg(0, 0x03);
    800007ae:	470d                	li	a4,3
    800007b0:	00e78023          	sb	a4,0(a5)

  // MSB for baud rate of 38.4K.
  WriteReg(1, 0x00);
    800007b4:	000780a3          	sb	zero,1(a5)

  // leave set-baud mode,
  // and set word length to 8 bits, no parity.
  WriteReg(LCR, LCR_EIGHT_BITS);
    800007b8:	00e781a3          	sb	a4,3(a5)

  // reset and enable FIFOs.
  WriteReg(FCR, FCR_FIFO_ENABLE | FCR_FIFO_CLEAR);
    800007bc:	469d                	li	a3,7
    800007be:	00d78123          	sb	a3,2(a5)

  // enable transmit and receive interrupts.
  WriteReg(IER, IER_TX_ENABLE | IER_RX_ENABLE);
    800007c2:	00e780a3          	sb	a4,1(a5)

  initlock(&uart_tx_lock, "uart");
    800007c6:	00008597          	auipc	a1,0x8
    800007ca:	89258593          	addi	a1,a1,-1902 # 80008058 <digits+0x18>
    800007ce:	00011517          	auipc	a0,0x11
    800007d2:	a7a50513          	addi	a0,a0,-1414 # 80011248 <uart_tx_lock>
    800007d6:	00000097          	auipc	ra,0x0
    800007da:	344080e7          	jalr	836(ra) # 80000b1a <initlock>
}
    800007de:	60a2                	ld	ra,8(sp)
    800007e0:	6402                	ld	s0,0(sp)
    800007e2:	0141                	addi	sp,sp,16
    800007e4:	8082                	ret

00000000800007e6 <uartputc_sync>:
// use interrupts, for use by kernel printf() and
// to echo characters. it spins waiting for the uart's
// output register to be empty.
void
uartputc_sync(int c)
{
    800007e6:	1101                	addi	sp,sp,-32
    800007e8:	ec06                	sd	ra,24(sp)
    800007ea:	e822                	sd	s0,16(sp)
    800007ec:	e426                	sd	s1,8(sp)
    800007ee:	1000                	addi	s0,sp,32
    800007f0:	84aa                	mv	s1,a0
  push_off();
    800007f2:	00000097          	auipc	ra,0x0
    800007f6:	36c080e7          	jalr	876(ra) # 80000b5e <push_off>

  if(panicked){
    800007fa:	00009797          	auipc	a5,0x9
    800007fe:	8067a783          	lw	a5,-2042(a5) # 80009000 <panicked>
    for(;;)
      ;
  }

  // wait for Transmit Holding Empty to be set in LSR.
  while((ReadReg(LSR) & LSR_TX_IDLE) == 0)
    80000802:	10000737          	lui	a4,0x10000
  if(panicked){
    80000806:	c391                	beqz	a5,8000080a <uartputc_sync+0x24>
    for(;;)
    80000808:	a001                	j	80000808 <uartputc_sync+0x22>
  while((ReadReg(LSR) & LSR_TX_IDLE) == 0)
    8000080a:	00574783          	lbu	a5,5(a4) # 10000005 <_entry-0x6ffffffb>
    8000080e:	0207f793          	andi	a5,a5,32
    80000812:	dfe5                	beqz	a5,8000080a <uartputc_sync+0x24>
    ;
  WriteReg(THR, c);
    80000814:	0ff4f513          	zext.b	a0,s1
    80000818:	100007b7          	lui	a5,0x10000
    8000081c:	00a78023          	sb	a0,0(a5) # 10000000 <_entry-0x70000000>

  pop_off();
    80000820:	00000097          	auipc	ra,0x0
    80000824:	3de080e7          	jalr	990(ra) # 80000bfe <pop_off>
}
    80000828:	60e2                	ld	ra,24(sp)
    8000082a:	6442                	ld	s0,16(sp)
    8000082c:	64a2                	ld	s1,8(sp)
    8000082e:	6105                	addi	sp,sp,32
    80000830:	8082                	ret

0000000080000832 <uartstart>:
// called from both the top- and bottom-half.
void
uartstart()
{
  while(1){
    if(uart_tx_w == uart_tx_r){
    80000832:	00008797          	auipc	a5,0x8
    80000836:	7d67b783          	ld	a5,2006(a5) # 80009008 <uart_tx_r>
    8000083a:	00008717          	auipc	a4,0x8
    8000083e:	7d673703          	ld	a4,2006(a4) # 80009010 <uart_tx_w>
    80000842:	06f70a63          	beq	a4,a5,800008b6 <uartstart+0x84>
{
    80000846:	7139                	addi	sp,sp,-64
    80000848:	fc06                	sd	ra,56(sp)
    8000084a:	f822                	sd	s0,48(sp)
    8000084c:	f426                	sd	s1,40(sp)
    8000084e:	f04a                	sd	s2,32(sp)
    80000850:	ec4e                	sd	s3,24(sp)
    80000852:	e852                	sd	s4,16(sp)
    80000854:	e456                	sd	s5,8(sp)
    80000856:	0080                	addi	s0,sp,64
      // transmit buffer is empty.
      return;
    }
    
    if((ReadReg(LSR) & LSR_TX_IDLE) == 0){
    80000858:	10000937          	lui	s2,0x10000
      // so we cannot give it another byte.
      // it will interrupt when it's ready for a new byte.
      return;
    }
    
    int c = uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE];
    8000085c:	00011a17          	auipc	s4,0x11
    80000860:	9eca0a13          	addi	s4,s4,-1556 # 80011248 <uart_tx_lock>
    uart_tx_r += 1;
    80000864:	00008497          	auipc	s1,0x8
    80000868:	7a448493          	addi	s1,s1,1956 # 80009008 <uart_tx_r>
    if(uart_tx_w == uart_tx_r){
    8000086c:	00008997          	auipc	s3,0x8
    80000870:	7a498993          	addi	s3,s3,1956 # 80009010 <uart_tx_w>
    if((ReadReg(LSR) & LSR_TX_IDLE) == 0){
    80000874:	00594703          	lbu	a4,5(s2) # 10000005 <_entry-0x6ffffffb>
    80000878:	02077713          	andi	a4,a4,32
    8000087c:	c705                	beqz	a4,800008a4 <uartstart+0x72>
    int c = uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE];
    8000087e:	01f7f713          	andi	a4,a5,31
    80000882:	9752                	add	a4,a4,s4
    80000884:	01874a83          	lbu	s5,24(a4)
    uart_tx_r += 1;
    80000888:	0785                	addi	a5,a5,1
    8000088a:	e09c                	sd	a5,0(s1)
    
    // maybe uartputc() is waiting for space in the buffer.
    wakeup(&uart_tx_r);
    8000088c:	8526                	mv	a0,s1
    8000088e:	00002097          	auipc	ra,0x2
    80000892:	932080e7          	jalr	-1742(ra) # 800021c0 <wakeup>
    
    WriteReg(THR, c);
    80000896:	01590023          	sb	s5,0(s2)
    if(uart_tx_w == uart_tx_r){
    8000089a:	609c                	ld	a5,0(s1)
    8000089c:	0009b703          	ld	a4,0(s3)
    800008a0:	fcf71ae3          	bne	a4,a5,80000874 <uartstart+0x42>
  }
}
    800008a4:	70e2                	ld	ra,56(sp)
    800008a6:	7442                	ld	s0,48(sp)
    800008a8:	74a2                	ld	s1,40(sp)
    800008aa:	7902                	ld	s2,32(sp)
    800008ac:	69e2                	ld	s3,24(sp)
    800008ae:	6a42                	ld	s4,16(sp)
    800008b0:	6aa2                	ld	s5,8(sp)
    800008b2:	6121                	addi	sp,sp,64
    800008b4:	8082                	ret
    800008b6:	8082                	ret

00000000800008b8 <uartputc>:
{
    800008b8:	7179                	addi	sp,sp,-48
    800008ba:	f406                	sd	ra,40(sp)
    800008bc:	f022                	sd	s0,32(sp)
    800008be:	ec26                	sd	s1,24(sp)
    800008c0:	e84a                	sd	s2,16(sp)
    800008c2:	e44e                	sd	s3,8(sp)
    800008c4:	e052                	sd	s4,0(sp)
    800008c6:	1800                	addi	s0,sp,48
    800008c8:	8a2a                	mv	s4,a0
  acquire(&uart_tx_lock);
    800008ca:	00011517          	auipc	a0,0x11
    800008ce:	97e50513          	addi	a0,a0,-1666 # 80011248 <uart_tx_lock>
    800008d2:	00000097          	auipc	ra,0x0
    800008d6:	2d8080e7          	jalr	728(ra) # 80000baa <acquire>
  if(panicked){
    800008da:	00008797          	auipc	a5,0x8
    800008de:	7267a783          	lw	a5,1830(a5) # 80009000 <panicked>
    800008e2:	c391                	beqz	a5,800008e6 <uartputc+0x2e>
    for(;;)
    800008e4:	a001                	j	800008e4 <uartputc+0x2c>
    if(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    800008e6:	00008717          	auipc	a4,0x8
    800008ea:	72a73703          	ld	a4,1834(a4) # 80009010 <uart_tx_w>
    800008ee:	00008797          	auipc	a5,0x8
    800008f2:	71a7b783          	ld	a5,1818(a5) # 80009008 <uart_tx_r>
    800008f6:	02078793          	addi	a5,a5,32
    800008fa:	02e79b63          	bne	a5,a4,80000930 <uartputc+0x78>
      sleep(&uart_tx_r, &uart_tx_lock);
    800008fe:	00011997          	auipc	s3,0x11
    80000902:	94a98993          	addi	s3,s3,-1718 # 80011248 <uart_tx_lock>
    80000906:	00008497          	auipc	s1,0x8
    8000090a:	70248493          	addi	s1,s1,1794 # 80009008 <uart_tx_r>
    if(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    8000090e:	00008917          	auipc	s2,0x8
    80000912:	70290913          	addi	s2,s2,1794 # 80009010 <uart_tx_w>
      sleep(&uart_tx_r, &uart_tx_lock);
    80000916:	85ce                	mv	a1,s3
    80000918:	8526                	mv	a0,s1
    8000091a:	00001097          	auipc	ra,0x1
    8000091e:	71a080e7          	jalr	1818(ra) # 80002034 <sleep>
    if(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    80000922:	00093703          	ld	a4,0(s2)
    80000926:	609c                	ld	a5,0(s1)
    80000928:	02078793          	addi	a5,a5,32
    8000092c:	fee785e3          	beq	a5,a4,80000916 <uartputc+0x5e>
      uart_tx_buf[uart_tx_w % UART_TX_BUF_SIZE] = c;
    80000930:	00011497          	auipc	s1,0x11
    80000934:	91848493          	addi	s1,s1,-1768 # 80011248 <uart_tx_lock>
    80000938:	01f77793          	andi	a5,a4,31
    8000093c:	97a6                	add	a5,a5,s1
    8000093e:	01478c23          	sb	s4,24(a5)
      uart_tx_w += 1;
    80000942:	0705                	addi	a4,a4,1
    80000944:	00008797          	auipc	a5,0x8
    80000948:	6ce7b623          	sd	a4,1740(a5) # 80009010 <uart_tx_w>
      uartstart();
    8000094c:	00000097          	auipc	ra,0x0
    80000950:	ee6080e7          	jalr	-282(ra) # 80000832 <uartstart>
      release(&uart_tx_lock);
    80000954:	8526                	mv	a0,s1
    80000956:	00000097          	auipc	ra,0x0
    8000095a:	308080e7          	jalr	776(ra) # 80000c5e <release>
}
    8000095e:	70a2                	ld	ra,40(sp)
    80000960:	7402                	ld	s0,32(sp)
    80000962:	64e2                	ld	s1,24(sp)
    80000964:	6942                	ld	s2,16(sp)
    80000966:	69a2                	ld	s3,8(sp)
    80000968:	6a02                	ld	s4,0(sp)
    8000096a:	6145                	addi	sp,sp,48
    8000096c:	8082                	ret

000000008000096e <uartgetc>:

// read one input character from the UART.
// return -1 if none is waiting.
int
uartgetc(void)
{
    8000096e:	1141                	addi	sp,sp,-16
    80000970:	e422                	sd	s0,8(sp)
    80000972:	0800                	addi	s0,sp,16
  if(ReadReg(LSR) & 0x01){
    80000974:	100007b7          	lui	a5,0x10000
    80000978:	0057c783          	lbu	a5,5(a5) # 10000005 <_entry-0x6ffffffb>
    8000097c:	8b85                	andi	a5,a5,1
    8000097e:	cb81                	beqz	a5,8000098e <uartgetc+0x20>
    // input data is ready.
    return ReadReg(RHR);
    80000980:	100007b7          	lui	a5,0x10000
    80000984:	0007c503          	lbu	a0,0(a5) # 10000000 <_entry-0x70000000>
  } else {
    return -1;
  }
}
    80000988:	6422                	ld	s0,8(sp)
    8000098a:	0141                	addi	sp,sp,16
    8000098c:	8082                	ret
    return -1;
    8000098e:	557d                	li	a0,-1
    80000990:	bfe5                	j	80000988 <uartgetc+0x1a>

0000000080000992 <uartintr>:
// handle a uart interrupt, raised because input has
// arrived, or the uart is ready for more output, or
// both. called from trap.c.
void
uartintr(void)
{
    80000992:	1101                	addi	sp,sp,-32
    80000994:	ec06                	sd	ra,24(sp)
    80000996:	e822                	sd	s0,16(sp)
    80000998:	e426                	sd	s1,8(sp)
    8000099a:	1000                	addi	s0,sp,32
  // read and process incoming characters.
  while(1){
    int c = uartgetc();
    if(c == -1)
    8000099c:	54fd                	li	s1,-1
    8000099e:	a029                	j	800009a8 <uartintr+0x16>
      break;
    consoleintr(c);
    800009a0:	00000097          	auipc	ra,0x0
    800009a4:	918080e7          	jalr	-1768(ra) # 800002b8 <consoleintr>
    int c = uartgetc();
    800009a8:	00000097          	auipc	ra,0x0
    800009ac:	fc6080e7          	jalr	-58(ra) # 8000096e <uartgetc>
    if(c == -1)
    800009b0:	fe9518e3          	bne	a0,s1,800009a0 <uartintr+0xe>
  }

  // send buffered characters.
  acquire(&uart_tx_lock);
    800009b4:	00011497          	auipc	s1,0x11
    800009b8:	89448493          	addi	s1,s1,-1900 # 80011248 <uart_tx_lock>
    800009bc:	8526                	mv	a0,s1
    800009be:	00000097          	auipc	ra,0x0
    800009c2:	1ec080e7          	jalr	492(ra) # 80000baa <acquire>
  uartstart();
    800009c6:	00000097          	auipc	ra,0x0
    800009ca:	e6c080e7          	jalr	-404(ra) # 80000832 <uartstart>
  release(&uart_tx_lock);
    800009ce:	8526                	mv	a0,s1
    800009d0:	00000097          	auipc	ra,0x0
    800009d4:	28e080e7          	jalr	654(ra) # 80000c5e <release>
}
    800009d8:	60e2                	ld	ra,24(sp)
    800009da:	6442                	ld	s0,16(sp)
    800009dc:	64a2                	ld	s1,8(sp)
    800009de:	6105                	addi	sp,sp,32
    800009e0:	8082                	ret

00000000800009e2 <kfree>:
// which normally should have been returned by a
// call to kalloc().  (The exception is when
// initializing the allocator; see kinit above.)
void
kfree(void *pa)
{
    800009e2:	1101                	addi	sp,sp,-32
    800009e4:	ec06                	sd	ra,24(sp)
    800009e6:	e822                	sd	s0,16(sp)
    800009e8:	e426                	sd	s1,8(sp)
    800009ea:	e04a                	sd	s2,0(sp)
    800009ec:	1000                	addi	s0,sp,32
  struct run *r;

  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    800009ee:	03451793          	slli	a5,a0,0x34
    800009f2:	e7a9                	bnez	a5,80000a3c <kfree+0x5a>
    800009f4:	84aa                	mv	s1,a0
    800009f6:	00025797          	auipc	a5,0x25
    800009fa:	60a78793          	addi	a5,a5,1546 # 80026000 <end>
    800009fe:	02f56f63          	bltu	a0,a5,80000a3c <kfree+0x5a>
    80000a02:	47c5                	li	a5,17
    80000a04:	07ee                	slli	a5,a5,0x1b
    80000a06:	02f57b63          	bgeu	a0,a5,80000a3c <kfree+0x5a>
  // Fill with junk to catch dangling refs.
  //memset(pa, 1, PGSIZE);

  r = (struct run*)pa;

  acquire(&kmem.lock);
    80000a0a:	00011917          	auipc	s2,0x11
    80000a0e:	87690913          	addi	s2,s2,-1930 # 80011280 <kmem>
    80000a12:	854a                	mv	a0,s2
    80000a14:	00000097          	auipc	ra,0x0
    80000a18:	196080e7          	jalr	406(ra) # 80000baa <acquire>
  r->next = kmem.freelist;
    80000a1c:	01893783          	ld	a5,24(s2)
    80000a20:	e09c                	sd	a5,0(s1)
  kmem.freelist = r;
    80000a22:	00993c23          	sd	s1,24(s2)
  release(&kmem.lock);
    80000a26:	854a                	mv	a0,s2
    80000a28:	00000097          	auipc	ra,0x0
    80000a2c:	236080e7          	jalr	566(ra) # 80000c5e <release>
}
    80000a30:	60e2                	ld	ra,24(sp)
    80000a32:	6442                	ld	s0,16(sp)
    80000a34:	64a2                	ld	s1,8(sp)
    80000a36:	6902                	ld	s2,0(sp)
    80000a38:	6105                	addi	sp,sp,32
    80000a3a:	8082                	ret
    panic("kfree");
    80000a3c:	00007517          	auipc	a0,0x7
    80000a40:	62450513          	addi	a0,a0,1572 # 80008060 <digits+0x20>
    80000a44:	00000097          	auipc	ra,0x0
    80000a48:	af6080e7          	jalr	-1290(ra) # 8000053a <panic>

0000000080000a4c <freerange>:
{
    80000a4c:	7179                	addi	sp,sp,-48
    80000a4e:	f406                	sd	ra,40(sp)
    80000a50:	f022                	sd	s0,32(sp)
    80000a52:	ec26                	sd	s1,24(sp)
    80000a54:	e84a                	sd	s2,16(sp)
    80000a56:	e44e                	sd	s3,8(sp)
    80000a58:	e052                	sd	s4,0(sp)
    80000a5a:	1800                	addi	s0,sp,48
  p = (char*)PGROUNDUP((uint64)pa_start);
    80000a5c:	6785                	lui	a5,0x1
    80000a5e:	fff78713          	addi	a4,a5,-1 # fff <_entry-0x7ffff001>
    80000a62:	00e504b3          	add	s1,a0,a4
    80000a66:	777d                	lui	a4,0xfffff
    80000a68:	8cf9                	and	s1,s1,a4
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000a6a:	94be                	add	s1,s1,a5
    80000a6c:	0095ee63          	bltu	a1,s1,80000a88 <freerange+0x3c>
    80000a70:	892e                	mv	s2,a1
    kfree(p);
    80000a72:	7a7d                	lui	s4,0xfffff
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000a74:	6985                	lui	s3,0x1
    kfree(p);
    80000a76:	01448533          	add	a0,s1,s4
    80000a7a:	00000097          	auipc	ra,0x0
    80000a7e:	f68080e7          	jalr	-152(ra) # 800009e2 <kfree>
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000a82:	94ce                	add	s1,s1,s3
    80000a84:	fe9979e3          	bgeu	s2,s1,80000a76 <freerange+0x2a>
}
    80000a88:	70a2                	ld	ra,40(sp)
    80000a8a:	7402                	ld	s0,32(sp)
    80000a8c:	64e2                	ld	s1,24(sp)
    80000a8e:	6942                	ld	s2,16(sp)
    80000a90:	69a2                	ld	s3,8(sp)
    80000a92:	6a02                	ld	s4,0(sp)
    80000a94:	6145                	addi	sp,sp,48
    80000a96:	8082                	ret

0000000080000a98 <kinit>:
{
    80000a98:	1141                	addi	sp,sp,-16
    80000a9a:	e406                	sd	ra,8(sp)
    80000a9c:	e022                	sd	s0,0(sp)
    80000a9e:	0800                	addi	s0,sp,16
  initlock(&kmem.lock, "kmem");
    80000aa0:	00007597          	auipc	a1,0x7
    80000aa4:	5c858593          	addi	a1,a1,1480 # 80008068 <digits+0x28>
    80000aa8:	00010517          	auipc	a0,0x10
    80000aac:	7d850513          	addi	a0,a0,2008 # 80011280 <kmem>
    80000ab0:	00000097          	auipc	ra,0x0
    80000ab4:	06a080e7          	jalr	106(ra) # 80000b1a <initlock>
  freerange(end, (void*)PHYSTOP);
    80000ab8:	45c5                	li	a1,17
    80000aba:	05ee                	slli	a1,a1,0x1b
    80000abc:	00025517          	auipc	a0,0x25
    80000ac0:	54450513          	addi	a0,a0,1348 # 80026000 <end>
    80000ac4:	00000097          	auipc	ra,0x0
    80000ac8:	f88080e7          	jalr	-120(ra) # 80000a4c <freerange>
}
    80000acc:	60a2                	ld	ra,8(sp)
    80000ace:	6402                	ld	s0,0(sp)
    80000ad0:	0141                	addi	sp,sp,16
    80000ad2:	8082                	ret

0000000080000ad4 <kalloc>:
// Allocate one 4096-byte page of physical memory.
// Returns a pointer that the kernel can use.
// Returns 0 if the memory cannot be allocated.
void *
kalloc(void)
{
    80000ad4:	1101                	addi	sp,sp,-32
    80000ad6:	ec06                	sd	ra,24(sp)
    80000ad8:	e822                	sd	s0,16(sp)
    80000ada:	e426                	sd	s1,8(sp)
    80000adc:	1000                	addi	s0,sp,32
  struct run *r;

  acquire(&kmem.lock);
    80000ade:	00010497          	auipc	s1,0x10
    80000ae2:	7a248493          	addi	s1,s1,1954 # 80011280 <kmem>
    80000ae6:	8526                	mv	a0,s1
    80000ae8:	00000097          	auipc	ra,0x0
    80000aec:	0c2080e7          	jalr	194(ra) # 80000baa <acquire>
  r = kmem.freelist;
    80000af0:	6c84                	ld	s1,24(s1)
  if(r)
    80000af2:	c491                	beqz	s1,80000afe <kalloc+0x2a>
    kmem.freelist = r->next;
    80000af4:	609c                	ld	a5,0(s1)
    80000af6:	00010717          	auipc	a4,0x10
    80000afa:	7af73123          	sd	a5,1954(a4) # 80011298 <kmem+0x18>
  release(&kmem.lock);
    80000afe:	00010517          	auipc	a0,0x10
    80000b02:	78250513          	addi	a0,a0,1922 # 80011280 <kmem>
    80000b06:	00000097          	auipc	ra,0x0
    80000b0a:	158080e7          	jalr	344(ra) # 80000c5e <release>

  if(r)
    ;//memset((char*)r, 5, PGSIZE); // fill with junk
  return (void*)r;
}
    80000b0e:	8526                	mv	a0,s1
    80000b10:	60e2                	ld	ra,24(sp)
    80000b12:	6442                	ld	s0,16(sp)
    80000b14:	64a2                	ld	s1,8(sp)
    80000b16:	6105                	addi	sp,sp,32
    80000b18:	8082                	ret

0000000080000b1a <initlock>:
#include "proc.h"
#include "defs.h"

void
initlock(struct spinlock *lk, char *name)
{
    80000b1a:	1141                	addi	sp,sp,-16
    80000b1c:	e422                	sd	s0,8(sp)
    80000b1e:	0800                	addi	s0,sp,16
  lk->name = name;
    80000b20:	e50c                	sd	a1,8(a0)
  lk->locked = 0;
    80000b22:	00052023          	sw	zero,0(a0)
  lk->cpu = 0;
    80000b26:	00053823          	sd	zero,16(a0)
}
    80000b2a:	6422                	ld	s0,8(sp)
    80000b2c:	0141                	addi	sp,sp,16
    80000b2e:	8082                	ret

0000000080000b30 <holding>:
// Interrupts must be off.
int
holding(struct spinlock *lk)
{
  int r;
  r = (lk->locked && lk->cpu == mycpu());
    80000b30:	411c                	lw	a5,0(a0)
    80000b32:	e399                	bnez	a5,80000b38 <holding+0x8>
    80000b34:	4501                	li	a0,0
  return r;
}
    80000b36:	8082                	ret
{
    80000b38:	1101                	addi	sp,sp,-32
    80000b3a:	ec06                	sd	ra,24(sp)
    80000b3c:	e822                	sd	s0,16(sp)
    80000b3e:	e426                	sd	s1,8(sp)
    80000b40:	1000                	addi	s0,sp,32
  r = (lk->locked && lk->cpu == mycpu());
    80000b42:	6904                	ld	s1,16(a0)
    80000b44:	00001097          	auipc	ra,0x1
    80000b48:	e10080e7          	jalr	-496(ra) # 80001954 <mycpu>
    80000b4c:	40a48533          	sub	a0,s1,a0
    80000b50:	00153513          	seqz	a0,a0
}
    80000b54:	60e2                	ld	ra,24(sp)
    80000b56:	6442                	ld	s0,16(sp)
    80000b58:	64a2                	ld	s1,8(sp)
    80000b5a:	6105                	addi	sp,sp,32
    80000b5c:	8082                	ret

0000000080000b5e <push_off>:
// it takes two pop_off()s to undo two push_off()s.  Also, if interrupts
// are initially off, then push_off, pop_off leaves them off.

void
push_off(void)
{
    80000b5e:	1101                	addi	sp,sp,-32
    80000b60:	ec06                	sd	ra,24(sp)
    80000b62:	e822                	sd	s0,16(sp)
    80000b64:	e426                	sd	s1,8(sp)
    80000b66:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000b68:	100024f3          	csrr	s1,sstatus
    80000b6c:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    80000b70:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80000b72:	10079073          	csrw	sstatus,a5
  int old = intr_get();

  intr_off();
  if(mycpu()->noff == 0)
    80000b76:	00001097          	auipc	ra,0x1
    80000b7a:	dde080e7          	jalr	-546(ra) # 80001954 <mycpu>
    80000b7e:	5d3c                	lw	a5,120(a0)
    80000b80:	cf89                	beqz	a5,80000b9a <push_off+0x3c>
    mycpu()->intena = old;
  mycpu()->noff += 1;
    80000b82:	00001097          	auipc	ra,0x1
    80000b86:	dd2080e7          	jalr	-558(ra) # 80001954 <mycpu>
    80000b8a:	5d3c                	lw	a5,120(a0)
    80000b8c:	2785                	addiw	a5,a5,1
    80000b8e:	dd3c                	sw	a5,120(a0)
}
    80000b90:	60e2                	ld	ra,24(sp)
    80000b92:	6442                	ld	s0,16(sp)
    80000b94:	64a2                	ld	s1,8(sp)
    80000b96:	6105                	addi	sp,sp,32
    80000b98:	8082                	ret
    mycpu()->intena = old;
    80000b9a:	00001097          	auipc	ra,0x1
    80000b9e:	dba080e7          	jalr	-582(ra) # 80001954 <mycpu>
  return (x & SSTATUS_SIE) != 0;
    80000ba2:	8085                	srli	s1,s1,0x1
    80000ba4:	8885                	andi	s1,s1,1
    80000ba6:	dd64                	sw	s1,124(a0)
    80000ba8:	bfe9                	j	80000b82 <push_off+0x24>

0000000080000baa <acquire>:
{
    80000baa:	1101                	addi	sp,sp,-32
    80000bac:	ec06                	sd	ra,24(sp)
    80000bae:	e822                	sd	s0,16(sp)
    80000bb0:	e426                	sd	s1,8(sp)
    80000bb2:	1000                	addi	s0,sp,32
    80000bb4:	84aa                	mv	s1,a0
  push_off(); // disable interrupts to avoid deadlock.
    80000bb6:	00000097          	auipc	ra,0x0
    80000bba:	fa8080e7          	jalr	-88(ra) # 80000b5e <push_off>
  if(holding(lk))
    80000bbe:	8526                	mv	a0,s1
    80000bc0:	00000097          	auipc	ra,0x0
    80000bc4:	f70080e7          	jalr	-144(ra) # 80000b30 <holding>
  while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
    80000bc8:	4705                	li	a4,1
  if(holding(lk))
    80000bca:	e115                	bnez	a0,80000bee <acquire+0x44>
  while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
    80000bcc:	87ba                	mv	a5,a4
    80000bce:	0cf4a7af          	amoswap.w.aq	a5,a5,(s1)
    80000bd2:	2781                	sext.w	a5,a5
    80000bd4:	ffe5                	bnez	a5,80000bcc <acquire+0x22>
  __sync_synchronize();
    80000bd6:	0ff0000f          	fence
  lk->cpu = mycpu();
    80000bda:	00001097          	auipc	ra,0x1
    80000bde:	d7a080e7          	jalr	-646(ra) # 80001954 <mycpu>
    80000be2:	e888                	sd	a0,16(s1)
}
    80000be4:	60e2                	ld	ra,24(sp)
    80000be6:	6442                	ld	s0,16(sp)
    80000be8:	64a2                	ld	s1,8(sp)
    80000bea:	6105                	addi	sp,sp,32
    80000bec:	8082                	ret
    panic("acquire");
    80000bee:	00007517          	auipc	a0,0x7
    80000bf2:	48250513          	addi	a0,a0,1154 # 80008070 <digits+0x30>
    80000bf6:	00000097          	auipc	ra,0x0
    80000bfa:	944080e7          	jalr	-1724(ra) # 8000053a <panic>

0000000080000bfe <pop_off>:

void
pop_off(void)
{
    80000bfe:	1141                	addi	sp,sp,-16
    80000c00:	e406                	sd	ra,8(sp)
    80000c02:	e022                	sd	s0,0(sp)
    80000c04:	0800                	addi	s0,sp,16
  struct cpu *c = mycpu();
    80000c06:	00001097          	auipc	ra,0x1
    80000c0a:	d4e080e7          	jalr	-690(ra) # 80001954 <mycpu>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000c0e:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80000c12:	8b89                	andi	a5,a5,2
  if(intr_get())
    80000c14:	e78d                	bnez	a5,80000c3e <pop_off+0x40>
    panic("pop_off - interruptible");
  if(c->noff < 1)
    80000c16:	5d3c                	lw	a5,120(a0)
    80000c18:	02f05b63          	blez	a5,80000c4e <pop_off+0x50>
    panic("pop_off");
  c->noff -= 1;
    80000c1c:	37fd                	addiw	a5,a5,-1
    80000c1e:	0007871b          	sext.w	a4,a5
    80000c22:	dd3c                	sw	a5,120(a0)
  if(c->noff == 0 && c->intena)
    80000c24:	eb09                	bnez	a4,80000c36 <pop_off+0x38>
    80000c26:	5d7c                	lw	a5,124(a0)
    80000c28:	c799                	beqz	a5,80000c36 <pop_off+0x38>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000c2a:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80000c2e:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80000c32:	10079073          	csrw	sstatus,a5
    intr_on();
}
    80000c36:	60a2                	ld	ra,8(sp)
    80000c38:	6402                	ld	s0,0(sp)
    80000c3a:	0141                	addi	sp,sp,16
    80000c3c:	8082                	ret
    panic("pop_off - interruptible");
    80000c3e:	00007517          	auipc	a0,0x7
    80000c42:	43a50513          	addi	a0,a0,1082 # 80008078 <digits+0x38>
    80000c46:	00000097          	auipc	ra,0x0
    80000c4a:	8f4080e7          	jalr	-1804(ra) # 8000053a <panic>
    panic("pop_off");
    80000c4e:	00007517          	auipc	a0,0x7
    80000c52:	44250513          	addi	a0,a0,1090 # 80008090 <digits+0x50>
    80000c56:	00000097          	auipc	ra,0x0
    80000c5a:	8e4080e7          	jalr	-1820(ra) # 8000053a <panic>

0000000080000c5e <release>:
{
    80000c5e:	1101                	addi	sp,sp,-32
    80000c60:	ec06                	sd	ra,24(sp)
    80000c62:	e822                	sd	s0,16(sp)
    80000c64:	e426                	sd	s1,8(sp)
    80000c66:	1000                	addi	s0,sp,32
    80000c68:	84aa                	mv	s1,a0
  if(!holding(lk))
    80000c6a:	00000097          	auipc	ra,0x0
    80000c6e:	ec6080e7          	jalr	-314(ra) # 80000b30 <holding>
    80000c72:	c115                	beqz	a0,80000c96 <release+0x38>
  lk->cpu = 0;
    80000c74:	0004b823          	sd	zero,16(s1)
  __sync_synchronize();
    80000c78:	0ff0000f          	fence
  __sync_lock_release(&lk->locked);
    80000c7c:	0f50000f          	fence	iorw,ow
    80000c80:	0804a02f          	amoswap.w	zero,zero,(s1)
  pop_off();
    80000c84:	00000097          	auipc	ra,0x0
    80000c88:	f7a080e7          	jalr	-134(ra) # 80000bfe <pop_off>
}
    80000c8c:	60e2                	ld	ra,24(sp)
    80000c8e:	6442                	ld	s0,16(sp)
    80000c90:	64a2                	ld	s1,8(sp)
    80000c92:	6105                	addi	sp,sp,32
    80000c94:	8082                	ret
    panic("release");
    80000c96:	00007517          	auipc	a0,0x7
    80000c9a:	40250513          	addi	a0,a0,1026 # 80008098 <digits+0x58>
    80000c9e:	00000097          	auipc	ra,0x0
    80000ca2:	89c080e7          	jalr	-1892(ra) # 8000053a <panic>

0000000080000ca6 <memset>:
#include "types.h"

void*
memset(void *dst, int c, uint n)
{
    80000ca6:	1141                	addi	sp,sp,-16
    80000ca8:	e422                	sd	s0,8(sp)
    80000caa:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
    80000cac:	ca19                	beqz	a2,80000cc2 <memset+0x1c>
    80000cae:	87aa                	mv	a5,a0
    80000cb0:	1602                	slli	a2,a2,0x20
    80000cb2:	9201                	srli	a2,a2,0x20
    80000cb4:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
    80000cb8:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
    80000cbc:	0785                	addi	a5,a5,1
    80000cbe:	fee79de3          	bne	a5,a4,80000cb8 <memset+0x12>
  }
  return dst;
}
    80000cc2:	6422                	ld	s0,8(sp)
    80000cc4:	0141                	addi	sp,sp,16
    80000cc6:	8082                	ret

0000000080000cc8 <memcmp>:

int
memcmp(const void *v1, const void *v2, uint n)
{
    80000cc8:	1141                	addi	sp,sp,-16
    80000cca:	e422                	sd	s0,8(sp)
    80000ccc:	0800                	addi	s0,sp,16
  const uchar *s1, *s2;

  s1 = v1;
  s2 = v2;
  while(n-- > 0){
    80000cce:	ca05                	beqz	a2,80000cfe <memcmp+0x36>
    80000cd0:	fff6069b          	addiw	a3,a2,-1
    80000cd4:	1682                	slli	a3,a3,0x20
    80000cd6:	9281                	srli	a3,a3,0x20
    80000cd8:	0685                	addi	a3,a3,1
    80000cda:	96aa                	add	a3,a3,a0
    if(*s1 != *s2)
    80000cdc:	00054783          	lbu	a5,0(a0)
    80000ce0:	0005c703          	lbu	a4,0(a1)
    80000ce4:	00e79863          	bne	a5,a4,80000cf4 <memcmp+0x2c>
      return *s1 - *s2;
    s1++, s2++;
    80000ce8:	0505                	addi	a0,a0,1
    80000cea:	0585                	addi	a1,a1,1
  while(n-- > 0){
    80000cec:	fed518e3          	bne	a0,a3,80000cdc <memcmp+0x14>
  }

  return 0;
    80000cf0:	4501                	li	a0,0
    80000cf2:	a019                	j	80000cf8 <memcmp+0x30>
      return *s1 - *s2;
    80000cf4:	40e7853b          	subw	a0,a5,a4
}
    80000cf8:	6422                	ld	s0,8(sp)
    80000cfa:	0141                	addi	sp,sp,16
    80000cfc:	8082                	ret
  return 0;
    80000cfe:	4501                	li	a0,0
    80000d00:	bfe5                	j	80000cf8 <memcmp+0x30>

0000000080000d02 <memmove>:

void*
memmove(void *dst, const void *src, uint n)
{
    80000d02:	1141                	addi	sp,sp,-16
    80000d04:	e422                	sd	s0,8(sp)
    80000d06:	0800                	addi	s0,sp,16
  const char *s;
  char *d;

  if(n == 0)
    80000d08:	c205                	beqz	a2,80000d28 <memmove+0x26>
    return dst;
  
  s = src;
  d = dst;
  if(s < d && s + n > d){
    80000d0a:	02a5e263          	bltu	a1,a0,80000d2e <memmove+0x2c>
    s += n;
    d += n;
    while(n-- > 0)
      *--d = *--s;
  } else
    while(n-- > 0)
    80000d0e:	1602                	slli	a2,a2,0x20
    80000d10:	9201                	srli	a2,a2,0x20
    80000d12:	00c587b3          	add	a5,a1,a2
{
    80000d16:	872a                	mv	a4,a0
      *d++ = *s++;
    80000d18:	0585                	addi	a1,a1,1
    80000d1a:	0705                	addi	a4,a4,1
    80000d1c:	fff5c683          	lbu	a3,-1(a1)
    80000d20:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
    80000d24:	fef59ae3          	bne	a1,a5,80000d18 <memmove+0x16>

  return dst;
}
    80000d28:	6422                	ld	s0,8(sp)
    80000d2a:	0141                	addi	sp,sp,16
    80000d2c:	8082                	ret
  if(s < d && s + n > d){
    80000d2e:	02061693          	slli	a3,a2,0x20
    80000d32:	9281                	srli	a3,a3,0x20
    80000d34:	00d58733          	add	a4,a1,a3
    80000d38:	fce57be3          	bgeu	a0,a4,80000d0e <memmove+0xc>
    d += n;
    80000d3c:	96aa                	add	a3,a3,a0
    while(n-- > 0)
    80000d3e:	fff6079b          	addiw	a5,a2,-1
    80000d42:	1782                	slli	a5,a5,0x20
    80000d44:	9381                	srli	a5,a5,0x20
    80000d46:	fff7c793          	not	a5,a5
    80000d4a:	97ba                	add	a5,a5,a4
      *--d = *--s;
    80000d4c:	177d                	addi	a4,a4,-1
    80000d4e:	16fd                	addi	a3,a3,-1
    80000d50:	00074603          	lbu	a2,0(a4)
    80000d54:	00c68023          	sb	a2,0(a3)
    while(n-- > 0)
    80000d58:	fee79ae3          	bne	a5,a4,80000d4c <memmove+0x4a>
    80000d5c:	b7f1                	j	80000d28 <memmove+0x26>

0000000080000d5e <memcpy>:

// memcpy exists to placate GCC.  Use memmove.
void*
memcpy(void *dst, const void *src, uint n)
{
    80000d5e:	1141                	addi	sp,sp,-16
    80000d60:	e406                	sd	ra,8(sp)
    80000d62:	e022                	sd	s0,0(sp)
    80000d64:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
    80000d66:	00000097          	auipc	ra,0x0
    80000d6a:	f9c080e7          	jalr	-100(ra) # 80000d02 <memmove>
}
    80000d6e:	60a2                	ld	ra,8(sp)
    80000d70:	6402                	ld	s0,0(sp)
    80000d72:	0141                	addi	sp,sp,16
    80000d74:	8082                	ret

0000000080000d76 <strncmp>:

int
strncmp(const char *p, const char *q, uint n)
{
    80000d76:	1141                	addi	sp,sp,-16
    80000d78:	e422                	sd	s0,8(sp)
    80000d7a:	0800                	addi	s0,sp,16
  while(n > 0 && *p && *p == *q)
    80000d7c:	ce11                	beqz	a2,80000d98 <strncmp+0x22>
    80000d7e:	00054783          	lbu	a5,0(a0)
    80000d82:	cf89                	beqz	a5,80000d9c <strncmp+0x26>
    80000d84:	0005c703          	lbu	a4,0(a1)
    80000d88:	00f71a63          	bne	a4,a5,80000d9c <strncmp+0x26>
    n--, p++, q++;
    80000d8c:	367d                	addiw	a2,a2,-1
    80000d8e:	0505                	addi	a0,a0,1
    80000d90:	0585                	addi	a1,a1,1
  while(n > 0 && *p && *p == *q)
    80000d92:	f675                	bnez	a2,80000d7e <strncmp+0x8>
  if(n == 0)
    return 0;
    80000d94:	4501                	li	a0,0
    80000d96:	a809                	j	80000da8 <strncmp+0x32>
    80000d98:	4501                	li	a0,0
    80000d9a:	a039                	j	80000da8 <strncmp+0x32>
  if(n == 0)
    80000d9c:	ca09                	beqz	a2,80000dae <strncmp+0x38>
  return (uchar)*p - (uchar)*q;
    80000d9e:	00054503          	lbu	a0,0(a0)
    80000da2:	0005c783          	lbu	a5,0(a1)
    80000da6:	9d1d                	subw	a0,a0,a5
}
    80000da8:	6422                	ld	s0,8(sp)
    80000daa:	0141                	addi	sp,sp,16
    80000dac:	8082                	ret
    return 0;
    80000dae:	4501                	li	a0,0
    80000db0:	bfe5                	j	80000da8 <strncmp+0x32>

0000000080000db2 <strncpy>:

char*
strncpy(char *s, const char *t, int n)
{
    80000db2:	1141                	addi	sp,sp,-16
    80000db4:	e422                	sd	s0,8(sp)
    80000db6:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while(n-- > 0 && (*s++ = *t++) != 0)
    80000db8:	872a                	mv	a4,a0
    80000dba:	8832                	mv	a6,a2
    80000dbc:	367d                	addiw	a2,a2,-1
    80000dbe:	01005963          	blez	a6,80000dd0 <strncpy+0x1e>
    80000dc2:	0705                	addi	a4,a4,1
    80000dc4:	0005c783          	lbu	a5,0(a1)
    80000dc8:	fef70fa3          	sb	a5,-1(a4)
    80000dcc:	0585                	addi	a1,a1,1
    80000dce:	f7f5                	bnez	a5,80000dba <strncpy+0x8>
    ;
  while(n-- > 0)
    80000dd0:	86ba                	mv	a3,a4
    80000dd2:	00c05c63          	blez	a2,80000dea <strncpy+0x38>
    *s++ = 0;
    80000dd6:	0685                	addi	a3,a3,1
    80000dd8:	fe068fa3          	sb	zero,-1(a3)
  while(n-- > 0)
    80000ddc:	40d707bb          	subw	a5,a4,a3
    80000de0:	37fd                	addiw	a5,a5,-1
    80000de2:	010787bb          	addw	a5,a5,a6
    80000de6:	fef048e3          	bgtz	a5,80000dd6 <strncpy+0x24>
  return os;
}
    80000dea:	6422                	ld	s0,8(sp)
    80000dec:	0141                	addi	sp,sp,16
    80000dee:	8082                	ret

0000000080000df0 <safestrcpy>:

// Like strncpy but guaranteed to NUL-terminate.
char*
safestrcpy(char *s, const char *t, int n)
{
    80000df0:	1141                	addi	sp,sp,-16
    80000df2:	e422                	sd	s0,8(sp)
    80000df4:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  if(n <= 0)
    80000df6:	02c05363          	blez	a2,80000e1c <safestrcpy+0x2c>
    80000dfa:	fff6069b          	addiw	a3,a2,-1
    80000dfe:	1682                	slli	a3,a3,0x20
    80000e00:	9281                	srli	a3,a3,0x20
    80000e02:	96ae                	add	a3,a3,a1
    80000e04:	87aa                	mv	a5,a0
    return os;
  while(--n > 0 && (*s++ = *t++) != 0)
    80000e06:	00d58963          	beq	a1,a3,80000e18 <safestrcpy+0x28>
    80000e0a:	0585                	addi	a1,a1,1
    80000e0c:	0785                	addi	a5,a5,1
    80000e0e:	fff5c703          	lbu	a4,-1(a1)
    80000e12:	fee78fa3          	sb	a4,-1(a5)
    80000e16:	fb65                	bnez	a4,80000e06 <safestrcpy+0x16>
    ;
  *s = 0;
    80000e18:	00078023          	sb	zero,0(a5)
  return os;
}
    80000e1c:	6422                	ld	s0,8(sp)
    80000e1e:	0141                	addi	sp,sp,16
    80000e20:	8082                	ret

0000000080000e22 <strlen>:

int
strlen(const char *s)
{
    80000e22:	1141                	addi	sp,sp,-16
    80000e24:	e422                	sd	s0,8(sp)
    80000e26:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
    80000e28:	00054783          	lbu	a5,0(a0)
    80000e2c:	cf91                	beqz	a5,80000e48 <strlen+0x26>
    80000e2e:	0505                	addi	a0,a0,1
    80000e30:	87aa                	mv	a5,a0
    80000e32:	4685                	li	a3,1
    80000e34:	9e89                	subw	a3,a3,a0
    80000e36:	00f6853b          	addw	a0,a3,a5
    80000e3a:	0785                	addi	a5,a5,1
    80000e3c:	fff7c703          	lbu	a4,-1(a5)
    80000e40:	fb7d                	bnez	a4,80000e36 <strlen+0x14>
    ;
  return n;
}
    80000e42:	6422                	ld	s0,8(sp)
    80000e44:	0141                	addi	sp,sp,16
    80000e46:	8082                	ret
  for(n = 0; s[n]; n++)
    80000e48:	4501                	li	a0,0
    80000e4a:	bfe5                	j	80000e42 <strlen+0x20>

0000000080000e4c <main>:
volatile static int started = 0;

// start() jumps here in supervisor mode on all CPUs.
void
main()
{
    80000e4c:	1141                	addi	sp,sp,-16
    80000e4e:	e406                	sd	ra,8(sp)
    80000e50:	e022                	sd	s0,0(sp)
    80000e52:	0800                	addi	s0,sp,16
  if(cpuid() == 0){
    80000e54:	00001097          	auipc	ra,0x1
    80000e58:	af0080e7          	jalr	-1296(ra) # 80001944 <cpuid>
    virtio_disk_init(); // emulated hard disk
    userinit();      // first user process
    __sync_synchronize();
    started = 1;
  } else {
    while(started == 0)
    80000e5c:	00008717          	auipc	a4,0x8
    80000e60:	1bc70713          	addi	a4,a4,444 # 80009018 <started>
  if(cpuid() == 0){
    80000e64:	c139                	beqz	a0,80000eaa <main+0x5e>
    while(started == 0)
    80000e66:	431c                	lw	a5,0(a4)
    80000e68:	2781                	sext.w	a5,a5
    80000e6a:	dff5                	beqz	a5,80000e66 <main+0x1a>
      ;
    __sync_synchronize();
    80000e6c:	0ff0000f          	fence
    printf("hart %d starting\n", cpuid());
    80000e70:	00001097          	auipc	ra,0x1
    80000e74:	ad4080e7          	jalr	-1324(ra) # 80001944 <cpuid>
    80000e78:	85aa                	mv	a1,a0
    80000e7a:	00007517          	auipc	a0,0x7
    80000e7e:	23e50513          	addi	a0,a0,574 # 800080b8 <digits+0x78>
    80000e82:	fffff097          	auipc	ra,0xfffff
    80000e86:	702080e7          	jalr	1794(ra) # 80000584 <printf>
    kvminithart();    // turn on paging
    80000e8a:	00000097          	auipc	ra,0x0
    80000e8e:	0d8080e7          	jalr	216(ra) # 80000f62 <kvminithart>
    trapinithart();   // install kernel trap vector
    80000e92:	00001097          	auipc	ra,0x1
    80000e96:	734080e7          	jalr	1844(ra) # 800025c6 <trapinithart>
    plicinithart();   // ask PLIC for device interrupts
    80000e9a:	00005097          	auipc	ra,0x5
    80000e9e:	ca6080e7          	jalr	-858(ra) # 80005b40 <plicinithart>
  }

  scheduler();        
    80000ea2:	00001097          	auipc	ra,0x1
    80000ea6:	fe0080e7          	jalr	-32(ra) # 80001e82 <scheduler>
    consoleinit();
    80000eaa:	fffff097          	auipc	ra,0xfffff
    80000eae:	5a0080e7          	jalr	1440(ra) # 8000044a <consoleinit>
    printfinit();
    80000eb2:	00000097          	auipc	ra,0x0
    80000eb6:	8b2080e7          	jalr	-1870(ra) # 80000764 <printfinit>
    printf("\n");
    80000eba:	00007517          	auipc	a0,0x7
    80000ebe:	20e50513          	addi	a0,a0,526 # 800080c8 <digits+0x88>
    80000ec2:	fffff097          	auipc	ra,0xfffff
    80000ec6:	6c2080e7          	jalr	1730(ra) # 80000584 <printf>
    printf("xv6 kernel is booting\n");
    80000eca:	00007517          	auipc	a0,0x7
    80000ece:	1d650513          	addi	a0,a0,470 # 800080a0 <digits+0x60>
    80000ed2:	fffff097          	auipc	ra,0xfffff
    80000ed6:	6b2080e7          	jalr	1714(ra) # 80000584 <printf>
    printf("\n");
    80000eda:	00007517          	auipc	a0,0x7
    80000ede:	1ee50513          	addi	a0,a0,494 # 800080c8 <digits+0x88>
    80000ee2:	fffff097          	auipc	ra,0xfffff
    80000ee6:	6a2080e7          	jalr	1698(ra) # 80000584 <printf>
    kinit();         // physical page allocator
    80000eea:	00000097          	auipc	ra,0x0
    80000eee:	bae080e7          	jalr	-1106(ra) # 80000a98 <kinit>
    kvminit();       // create kernel page table
    80000ef2:	00000097          	auipc	ra,0x0
    80000ef6:	322080e7          	jalr	802(ra) # 80001214 <kvminit>
    kvminithart();   // turn on paging
    80000efa:	00000097          	auipc	ra,0x0
    80000efe:	068080e7          	jalr	104(ra) # 80000f62 <kvminithart>
    procinit();      // process table
    80000f02:	00001097          	auipc	ra,0x1
    80000f06:	992080e7          	jalr	-1646(ra) # 80001894 <procinit>
    trapinit();      // trap vectors
    80000f0a:	00001097          	auipc	ra,0x1
    80000f0e:	694080e7          	jalr	1684(ra) # 8000259e <trapinit>
    trapinithart();  // install kernel trap vector
    80000f12:	00001097          	auipc	ra,0x1
    80000f16:	6b4080e7          	jalr	1716(ra) # 800025c6 <trapinithart>
    plicinit();      // set up interrupt controller
    80000f1a:	00005097          	auipc	ra,0x5
    80000f1e:	c10080e7          	jalr	-1008(ra) # 80005b2a <plicinit>
    plicinithart();  // ask PLIC for device interrupts
    80000f22:	00005097          	auipc	ra,0x5
    80000f26:	c1e080e7          	jalr	-994(ra) # 80005b40 <plicinithart>
    binit();         // buffer cache
    80000f2a:	00002097          	auipc	ra,0x2
    80000f2e:	dde080e7          	jalr	-546(ra) # 80002d08 <binit>
    iinit();         // inode table
    80000f32:	00002097          	auipc	ra,0x2
    80000f36:	46c080e7          	jalr	1132(ra) # 8000339e <iinit>
    fileinit();      // file table
    80000f3a:	00003097          	auipc	ra,0x3
    80000f3e:	41e080e7          	jalr	1054(ra) # 80004358 <fileinit>
    virtio_disk_init(); // emulated hard disk
    80000f42:	00005097          	auipc	ra,0x5
    80000f46:	d1e080e7          	jalr	-738(ra) # 80005c60 <virtio_disk_init>
    userinit();      // first user process
    80000f4a:	00001097          	auipc	ra,0x1
    80000f4e:	cfe080e7          	jalr	-770(ra) # 80001c48 <userinit>
    __sync_synchronize();
    80000f52:	0ff0000f          	fence
    started = 1;
    80000f56:	4785                	li	a5,1
    80000f58:	00008717          	auipc	a4,0x8
    80000f5c:	0cf72023          	sw	a5,192(a4) # 80009018 <started>
    80000f60:	b789                	j	80000ea2 <main+0x56>

0000000080000f62 <kvminithart>:

// Switch h/w page table register to the kernel's page table,
// and enable paging.
void
kvminithart()
{
    80000f62:	1141                	addi	sp,sp,-16
    80000f64:	e422                	sd	s0,8(sp)
    80000f66:	0800                	addi	s0,sp,16
  w_satp(MAKE_SATP(kernel_pagetable));
    80000f68:	00008797          	auipc	a5,0x8
    80000f6c:	0b87b783          	ld	a5,184(a5) # 80009020 <kernel_pagetable>
    80000f70:	83b1                	srli	a5,a5,0xc
    80000f72:	577d                	li	a4,-1
    80000f74:	177e                	slli	a4,a4,0x3f
    80000f76:	8fd9                	or	a5,a5,a4
  asm volatile("csrw satp, %0" : : "r" (x));
    80000f78:	18079073          	csrw	satp,a5
// flush the TLB.
static inline void
sfence_vma()
{
  // the zero, zero means flush all TLB entries.
  asm volatile("sfence.vma zero, zero");
    80000f7c:	12000073          	sfence.vma
  sfence_vma();
}
    80000f80:	6422                	ld	s0,8(sp)
    80000f82:	0141                	addi	sp,sp,16
    80000f84:	8082                	ret

0000000080000f86 <walk>:
//   21..29 -- 9 bits of level-1 index.
//   12..20 -- 9 bits of level-0 index.
//    0..11 -- 12 bits of byte offset within the page.
pte_t *
walk(pagetable_t pagetable, uint64 va, int alloc)
{
    80000f86:	7139                	addi	sp,sp,-64
    80000f88:	fc06                	sd	ra,56(sp)
    80000f8a:	f822                	sd	s0,48(sp)
    80000f8c:	f426                	sd	s1,40(sp)
    80000f8e:	f04a                	sd	s2,32(sp)
    80000f90:	ec4e                	sd	s3,24(sp)
    80000f92:	e852                	sd	s4,16(sp)
    80000f94:	e456                	sd	s5,8(sp)
    80000f96:	e05a                	sd	s6,0(sp)
    80000f98:	0080                	addi	s0,sp,64
    80000f9a:	84aa                	mv	s1,a0
    80000f9c:	89ae                	mv	s3,a1
    80000f9e:	8ab2                	mv	s5,a2
  if(va >= MAXVA)
    80000fa0:	57fd                	li	a5,-1
    80000fa2:	83e9                	srli	a5,a5,0x1a
    80000fa4:	4a79                	li	s4,30
    panic("walk");

  for(int level = 2; level > 0; level--) {
    80000fa6:	4b31                	li	s6,12
  if(va >= MAXVA)
    80000fa8:	04b7f263          	bgeu	a5,a1,80000fec <walk+0x66>
    panic("walk");
    80000fac:	00007517          	auipc	a0,0x7
    80000fb0:	12450513          	addi	a0,a0,292 # 800080d0 <digits+0x90>
    80000fb4:	fffff097          	auipc	ra,0xfffff
    80000fb8:	586080e7          	jalr	1414(ra) # 8000053a <panic>
    pte_t *pte = &pagetable[PX(level, va)];
    if(*pte & PTE_V) {
      pagetable = (pagetable_t)PTE2PA(*pte);
    } else {
      if(!alloc || (pagetable = (pde_t*)kalloc()) == 0)
    80000fbc:	060a8663          	beqz	s5,80001028 <walk+0xa2>
    80000fc0:	00000097          	auipc	ra,0x0
    80000fc4:	b14080e7          	jalr	-1260(ra) # 80000ad4 <kalloc>
    80000fc8:	84aa                	mv	s1,a0
    80000fca:	c529                	beqz	a0,80001014 <walk+0x8e>
        return 0;
      memset(pagetable, 0, PGSIZE);
    80000fcc:	6605                	lui	a2,0x1
    80000fce:	4581                	li	a1,0
    80000fd0:	00000097          	auipc	ra,0x0
    80000fd4:	cd6080e7          	jalr	-810(ra) # 80000ca6 <memset>
      *pte = PA2PTE(pagetable) | PTE_V;
    80000fd8:	00c4d793          	srli	a5,s1,0xc
    80000fdc:	07aa                	slli	a5,a5,0xa
    80000fde:	0017e793          	ori	a5,a5,1
    80000fe2:	00f93023          	sd	a5,0(s2)
  for(int level = 2; level > 0; level--) {
    80000fe6:	3a5d                	addiw	s4,s4,-9 # ffffffffffffeff7 <end+0xffffffff7ffd8ff7>
    80000fe8:	036a0063          	beq	s4,s6,80001008 <walk+0x82>
    pte_t *pte = &pagetable[PX(level, va)];
    80000fec:	0149d933          	srl	s2,s3,s4
    80000ff0:	1ff97913          	andi	s2,s2,511
    80000ff4:	090e                	slli	s2,s2,0x3
    80000ff6:	9926                	add	s2,s2,s1
    if(*pte & PTE_V) {
    80000ff8:	00093483          	ld	s1,0(s2)
    80000ffc:	0014f793          	andi	a5,s1,1
    80001000:	dfd5                	beqz	a5,80000fbc <walk+0x36>
      pagetable = (pagetable_t)PTE2PA(*pte);
    80001002:	80a9                	srli	s1,s1,0xa
    80001004:	04b2                	slli	s1,s1,0xc
    80001006:	b7c5                	j	80000fe6 <walk+0x60>
    }
  }
  return &pagetable[PX(0, va)];
    80001008:	00c9d513          	srli	a0,s3,0xc
    8000100c:	1ff57513          	andi	a0,a0,511
    80001010:	050e                	slli	a0,a0,0x3
    80001012:	9526                	add	a0,a0,s1
}
    80001014:	70e2                	ld	ra,56(sp)
    80001016:	7442                	ld	s0,48(sp)
    80001018:	74a2                	ld	s1,40(sp)
    8000101a:	7902                	ld	s2,32(sp)
    8000101c:	69e2                	ld	s3,24(sp)
    8000101e:	6a42                	ld	s4,16(sp)
    80001020:	6aa2                	ld	s5,8(sp)
    80001022:	6b02                	ld	s6,0(sp)
    80001024:	6121                	addi	sp,sp,64
    80001026:	8082                	ret
        return 0;
    80001028:	4501                	li	a0,0
    8000102a:	b7ed                	j	80001014 <walk+0x8e>

000000008000102c <walkaddr>:
walkaddr(pagetable_t pagetable, uint64 va)
{
  pte_t *pte;
  uint64 pa;

  if(va >= MAXVA)
    8000102c:	57fd                	li	a5,-1
    8000102e:	83e9                	srli	a5,a5,0x1a
    80001030:	00b7f463          	bgeu	a5,a1,80001038 <walkaddr+0xc>
    return 0;
    80001034:	4501                	li	a0,0
    return 0;
  if((*pte & PTE_U) == 0)
    return 0;
  pa = PTE2PA(*pte);
  return pa;
}
    80001036:	8082                	ret
{
    80001038:	1141                	addi	sp,sp,-16
    8000103a:	e406                	sd	ra,8(sp)
    8000103c:	e022                	sd	s0,0(sp)
    8000103e:	0800                	addi	s0,sp,16
  pte = walk(pagetable, va, 0);
    80001040:	4601                	li	a2,0
    80001042:	00000097          	auipc	ra,0x0
    80001046:	f44080e7          	jalr	-188(ra) # 80000f86 <walk>
  if(pte == 0)
    8000104a:	c105                	beqz	a0,8000106a <walkaddr+0x3e>
  if((*pte & PTE_V) == 0)
    8000104c:	611c                	ld	a5,0(a0)
  if((*pte & PTE_U) == 0)
    8000104e:	0117f693          	andi	a3,a5,17
    80001052:	4745                	li	a4,17
    return 0;
    80001054:	4501                	li	a0,0
  if((*pte & PTE_U) == 0)
    80001056:	00e68663          	beq	a3,a4,80001062 <walkaddr+0x36>
}
    8000105a:	60a2                	ld	ra,8(sp)
    8000105c:	6402                	ld	s0,0(sp)
    8000105e:	0141                	addi	sp,sp,16
    80001060:	8082                	ret
  pa = PTE2PA(*pte);
    80001062:	83a9                	srli	a5,a5,0xa
    80001064:	00c79513          	slli	a0,a5,0xc
  return pa;
    80001068:	bfcd                	j	8000105a <walkaddr+0x2e>
    return 0;
    8000106a:	4501                	li	a0,0
    8000106c:	b7fd                	j	8000105a <walkaddr+0x2e>

000000008000106e <mappages>:
// physical addresses starting at pa. va and size might not
// be page-aligned. Returns 0 on success, -1 if walk() couldn't
// allocate a needed page-table page.
int
mappages(pagetable_t pagetable, uint64 va, uint64 size, uint64 pa, int perm)
{
    8000106e:	715d                	addi	sp,sp,-80
    80001070:	e486                	sd	ra,72(sp)
    80001072:	e0a2                	sd	s0,64(sp)
    80001074:	fc26                	sd	s1,56(sp)
    80001076:	f84a                	sd	s2,48(sp)
    80001078:	f44e                	sd	s3,40(sp)
    8000107a:	f052                	sd	s4,32(sp)
    8000107c:	ec56                	sd	s5,24(sp)
    8000107e:	e85a                	sd	s6,16(sp)
    80001080:	e45e                	sd	s7,8(sp)
    80001082:	0880                	addi	s0,sp,80
  uint64 a, last;
  pte_t *pte;

  if(size == 0)
    80001084:	c639                	beqz	a2,800010d2 <mappages+0x64>
    80001086:	8aaa                	mv	s5,a0
    80001088:	8b3a                	mv	s6,a4
    panic("mappages: size");
  
  a = PGROUNDDOWN(va);
    8000108a:	777d                	lui	a4,0xfffff
    8000108c:	00e5f7b3          	and	a5,a1,a4
  last = PGROUNDDOWN(va + size - 1);
    80001090:	fff58993          	addi	s3,a1,-1
    80001094:	99b2                	add	s3,s3,a2
    80001096:	00e9f9b3          	and	s3,s3,a4
  a = PGROUNDDOWN(va);
    8000109a:	893e                	mv	s2,a5
    8000109c:	40f68a33          	sub	s4,a3,a5
    if(*pte & PTE_V)
      panic("mappages: remap");
    *pte = PA2PTE(pa) | perm | PTE_V;
    if(a == last)
      break;
    a += PGSIZE;
    800010a0:	6b85                	lui	s7,0x1
    800010a2:	012a04b3          	add	s1,s4,s2
    if((pte = walk(pagetable, a, 1)) == 0)
    800010a6:	4605                	li	a2,1
    800010a8:	85ca                	mv	a1,s2
    800010aa:	8556                	mv	a0,s5
    800010ac:	00000097          	auipc	ra,0x0
    800010b0:	eda080e7          	jalr	-294(ra) # 80000f86 <walk>
    800010b4:	cd1d                	beqz	a0,800010f2 <mappages+0x84>
    if(*pte & PTE_V)
    800010b6:	611c                	ld	a5,0(a0)
    800010b8:	8b85                	andi	a5,a5,1
    800010ba:	e785                	bnez	a5,800010e2 <mappages+0x74>
    *pte = PA2PTE(pa) | perm | PTE_V;
    800010bc:	80b1                	srli	s1,s1,0xc
    800010be:	04aa                	slli	s1,s1,0xa
    800010c0:	0164e4b3          	or	s1,s1,s6
    800010c4:	0014e493          	ori	s1,s1,1
    800010c8:	e104                	sd	s1,0(a0)
    if(a == last)
    800010ca:	05390063          	beq	s2,s3,8000110a <mappages+0x9c>
    a += PGSIZE;
    800010ce:	995e                	add	s2,s2,s7
    if((pte = walk(pagetable, a, 1)) == 0)
    800010d0:	bfc9                	j	800010a2 <mappages+0x34>
    panic("mappages: size");
    800010d2:	00007517          	auipc	a0,0x7
    800010d6:	00650513          	addi	a0,a0,6 # 800080d8 <digits+0x98>
    800010da:	fffff097          	auipc	ra,0xfffff
    800010de:	460080e7          	jalr	1120(ra) # 8000053a <panic>
      panic("mappages: remap");
    800010e2:	00007517          	auipc	a0,0x7
    800010e6:	00650513          	addi	a0,a0,6 # 800080e8 <digits+0xa8>
    800010ea:	fffff097          	auipc	ra,0xfffff
    800010ee:	450080e7          	jalr	1104(ra) # 8000053a <panic>
      return -1;
    800010f2:	557d                	li	a0,-1
    pa += PGSIZE;
  }
  return 0;
}
    800010f4:	60a6                	ld	ra,72(sp)
    800010f6:	6406                	ld	s0,64(sp)
    800010f8:	74e2                	ld	s1,56(sp)
    800010fa:	7942                	ld	s2,48(sp)
    800010fc:	79a2                	ld	s3,40(sp)
    800010fe:	7a02                	ld	s4,32(sp)
    80001100:	6ae2                	ld	s5,24(sp)
    80001102:	6b42                	ld	s6,16(sp)
    80001104:	6ba2                	ld	s7,8(sp)
    80001106:	6161                	addi	sp,sp,80
    80001108:	8082                	ret
  return 0;
    8000110a:	4501                	li	a0,0
    8000110c:	b7e5                	j	800010f4 <mappages+0x86>

000000008000110e <kvmmap>:
{
    8000110e:	1141                	addi	sp,sp,-16
    80001110:	e406                	sd	ra,8(sp)
    80001112:	e022                	sd	s0,0(sp)
    80001114:	0800                	addi	s0,sp,16
    80001116:	87b6                	mv	a5,a3
  if(mappages(kpgtbl, va, sz, pa, perm) != 0)
    80001118:	86b2                	mv	a3,a2
    8000111a:	863e                	mv	a2,a5
    8000111c:	00000097          	auipc	ra,0x0
    80001120:	f52080e7          	jalr	-174(ra) # 8000106e <mappages>
    80001124:	e509                	bnez	a0,8000112e <kvmmap+0x20>
}
    80001126:	60a2                	ld	ra,8(sp)
    80001128:	6402                	ld	s0,0(sp)
    8000112a:	0141                	addi	sp,sp,16
    8000112c:	8082                	ret
    panic("kvmmap");
    8000112e:	00007517          	auipc	a0,0x7
    80001132:	fca50513          	addi	a0,a0,-54 # 800080f8 <digits+0xb8>
    80001136:	fffff097          	auipc	ra,0xfffff
    8000113a:	404080e7          	jalr	1028(ra) # 8000053a <panic>

000000008000113e <kvmmake>:
{
    8000113e:	1101                	addi	sp,sp,-32
    80001140:	ec06                	sd	ra,24(sp)
    80001142:	e822                	sd	s0,16(sp)
    80001144:	e426                	sd	s1,8(sp)
    80001146:	e04a                	sd	s2,0(sp)
    80001148:	1000                	addi	s0,sp,32
  kpgtbl = (pagetable_t) kalloc();
    8000114a:	00000097          	auipc	ra,0x0
    8000114e:	98a080e7          	jalr	-1654(ra) # 80000ad4 <kalloc>
    80001152:	84aa                	mv	s1,a0
  memset(kpgtbl, 0, PGSIZE);
    80001154:	6605                	lui	a2,0x1
    80001156:	4581                	li	a1,0
    80001158:	00000097          	auipc	ra,0x0
    8000115c:	b4e080e7          	jalr	-1202(ra) # 80000ca6 <memset>
  kvmmap(kpgtbl, UART0, UART0, PGSIZE, PTE_R | PTE_W);
    80001160:	4719                	li	a4,6
    80001162:	6685                	lui	a3,0x1
    80001164:	10000637          	lui	a2,0x10000
    80001168:	100005b7          	lui	a1,0x10000
    8000116c:	8526                	mv	a0,s1
    8000116e:	00000097          	auipc	ra,0x0
    80001172:	fa0080e7          	jalr	-96(ra) # 8000110e <kvmmap>
  kvmmap(kpgtbl, VIRTIO0, VIRTIO0, PGSIZE, PTE_R | PTE_W);
    80001176:	4719                	li	a4,6
    80001178:	6685                	lui	a3,0x1
    8000117a:	10001637          	lui	a2,0x10001
    8000117e:	100015b7          	lui	a1,0x10001
    80001182:	8526                	mv	a0,s1
    80001184:	00000097          	auipc	ra,0x0
    80001188:	f8a080e7          	jalr	-118(ra) # 8000110e <kvmmap>
  kvmmap(kpgtbl, PLIC, PLIC, 0x400000, PTE_R | PTE_W);
    8000118c:	4719                	li	a4,6
    8000118e:	004006b7          	lui	a3,0x400
    80001192:	0c000637          	lui	a2,0xc000
    80001196:	0c0005b7          	lui	a1,0xc000
    8000119a:	8526                	mv	a0,s1
    8000119c:	00000097          	auipc	ra,0x0
    800011a0:	f72080e7          	jalr	-142(ra) # 8000110e <kvmmap>
  kvmmap(kpgtbl, KERNBASE, KERNBASE, (uint64)etext-KERNBASE, PTE_R | PTE_X);
    800011a4:	00007917          	auipc	s2,0x7
    800011a8:	e5c90913          	addi	s2,s2,-420 # 80008000 <etext>
    800011ac:	4729                	li	a4,10
    800011ae:	80007697          	auipc	a3,0x80007
    800011b2:	e5268693          	addi	a3,a3,-430 # 8000 <_entry-0x7fff8000>
    800011b6:	4605                	li	a2,1
    800011b8:	067e                	slli	a2,a2,0x1f
    800011ba:	85b2                	mv	a1,a2
    800011bc:	8526                	mv	a0,s1
    800011be:	00000097          	auipc	ra,0x0
    800011c2:	f50080e7          	jalr	-176(ra) # 8000110e <kvmmap>
  kvmmap(kpgtbl, (uint64)etext, (uint64)etext, PHYSTOP-(uint64)etext, PTE_R | PTE_W);
    800011c6:	4719                	li	a4,6
    800011c8:	46c5                	li	a3,17
    800011ca:	06ee                	slli	a3,a3,0x1b
    800011cc:	412686b3          	sub	a3,a3,s2
    800011d0:	864a                	mv	a2,s2
    800011d2:	85ca                	mv	a1,s2
    800011d4:	8526                	mv	a0,s1
    800011d6:	00000097          	auipc	ra,0x0
    800011da:	f38080e7          	jalr	-200(ra) # 8000110e <kvmmap>
  kvmmap(kpgtbl, TRAMPOLINE, (uint64)trampoline, PGSIZE, PTE_R | PTE_X);
    800011de:	4729                	li	a4,10
    800011e0:	6685                	lui	a3,0x1
    800011e2:	00006617          	auipc	a2,0x6
    800011e6:	e1e60613          	addi	a2,a2,-482 # 80007000 <_trampoline>
    800011ea:	040005b7          	lui	a1,0x4000
    800011ee:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    800011f0:	05b2                	slli	a1,a1,0xc
    800011f2:	8526                	mv	a0,s1
    800011f4:	00000097          	auipc	ra,0x0
    800011f8:	f1a080e7          	jalr	-230(ra) # 8000110e <kvmmap>
  proc_mapstacks(kpgtbl);
    800011fc:	8526                	mv	a0,s1
    800011fe:	00000097          	auipc	ra,0x0
    80001202:	600080e7          	jalr	1536(ra) # 800017fe <proc_mapstacks>
}
    80001206:	8526                	mv	a0,s1
    80001208:	60e2                	ld	ra,24(sp)
    8000120a:	6442                	ld	s0,16(sp)
    8000120c:	64a2                	ld	s1,8(sp)
    8000120e:	6902                	ld	s2,0(sp)
    80001210:	6105                	addi	sp,sp,32
    80001212:	8082                	ret

0000000080001214 <kvminit>:
{
    80001214:	1141                	addi	sp,sp,-16
    80001216:	e406                	sd	ra,8(sp)
    80001218:	e022                	sd	s0,0(sp)
    8000121a:	0800                	addi	s0,sp,16
  kernel_pagetable = kvmmake();
    8000121c:	00000097          	auipc	ra,0x0
    80001220:	f22080e7          	jalr	-222(ra) # 8000113e <kvmmake>
    80001224:	00008797          	auipc	a5,0x8
    80001228:	dea7be23          	sd	a0,-516(a5) # 80009020 <kernel_pagetable>
}
    8000122c:	60a2                	ld	ra,8(sp)
    8000122e:	6402                	ld	s0,0(sp)
    80001230:	0141                	addi	sp,sp,16
    80001232:	8082                	ret

0000000080001234 <uvmunmap>:
// Remove npages of mappings starting from va. va must be
// page-aligned. The mappings must exist.
// Optionally free the physical memory.
void
uvmunmap(pagetable_t pagetable, uint64 va, uint64 npages, int do_free)
{
    80001234:	715d                	addi	sp,sp,-80
    80001236:	e486                	sd	ra,72(sp)
    80001238:	e0a2                	sd	s0,64(sp)
    8000123a:	fc26                	sd	s1,56(sp)
    8000123c:	f84a                	sd	s2,48(sp)
    8000123e:	f44e                	sd	s3,40(sp)
    80001240:	f052                	sd	s4,32(sp)
    80001242:	ec56                	sd	s5,24(sp)
    80001244:	e85a                	sd	s6,16(sp)
    80001246:	e45e                	sd	s7,8(sp)
    80001248:	0880                	addi	s0,sp,80
  uint64 a;
  pte_t *pte;

  if((va % PGSIZE) != 0)
    8000124a:	03459793          	slli	a5,a1,0x34
    8000124e:	e795                	bnez	a5,8000127a <uvmunmap+0x46>
    80001250:	8a2a                	mv	s4,a0
    80001252:	892e                	mv	s2,a1
    80001254:	8ab6                	mv	s5,a3
    panic("uvmunmap: not aligned");

  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    80001256:	0632                	slli	a2,a2,0xc
    80001258:	00b609b3          	add	s3,a2,a1
    if((pte = walk(pagetable, a, 0)) == 0)
      panic("uvmunmap: walk");
    if((*pte & PTE_V) == 0)
      panic("uvmunmap: not mapped");
    if(PTE_FLAGS(*pte) == PTE_V)
    8000125c:	4b85                	li	s7,1
  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    8000125e:	6b05                	lui	s6,0x1
    80001260:	0735e263          	bltu	a1,s3,800012c4 <uvmunmap+0x90>
      uint64 pa = PTE2PA(*pte);
      kfree((void*)pa);
    }
    *pte = 0;
  }
}
    80001264:	60a6                	ld	ra,72(sp)
    80001266:	6406                	ld	s0,64(sp)
    80001268:	74e2                	ld	s1,56(sp)
    8000126a:	7942                	ld	s2,48(sp)
    8000126c:	79a2                	ld	s3,40(sp)
    8000126e:	7a02                	ld	s4,32(sp)
    80001270:	6ae2                	ld	s5,24(sp)
    80001272:	6b42                	ld	s6,16(sp)
    80001274:	6ba2                	ld	s7,8(sp)
    80001276:	6161                	addi	sp,sp,80
    80001278:	8082                	ret
    panic("uvmunmap: not aligned");
    8000127a:	00007517          	auipc	a0,0x7
    8000127e:	e8650513          	addi	a0,a0,-378 # 80008100 <digits+0xc0>
    80001282:	fffff097          	auipc	ra,0xfffff
    80001286:	2b8080e7          	jalr	696(ra) # 8000053a <panic>
      panic("uvmunmap: walk");
    8000128a:	00007517          	auipc	a0,0x7
    8000128e:	e8e50513          	addi	a0,a0,-370 # 80008118 <digits+0xd8>
    80001292:	fffff097          	auipc	ra,0xfffff
    80001296:	2a8080e7          	jalr	680(ra) # 8000053a <panic>
      panic("uvmunmap: not mapped");
    8000129a:	00007517          	auipc	a0,0x7
    8000129e:	e8e50513          	addi	a0,a0,-370 # 80008128 <digits+0xe8>
    800012a2:	fffff097          	auipc	ra,0xfffff
    800012a6:	298080e7          	jalr	664(ra) # 8000053a <panic>
      panic("uvmunmap: not a leaf");
    800012aa:	00007517          	auipc	a0,0x7
    800012ae:	e9650513          	addi	a0,a0,-362 # 80008140 <digits+0x100>
    800012b2:	fffff097          	auipc	ra,0xfffff
    800012b6:	288080e7          	jalr	648(ra) # 8000053a <panic>
    *pte = 0;
    800012ba:	0004b023          	sd	zero,0(s1)
  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    800012be:	995a                	add	s2,s2,s6
    800012c0:	fb3972e3          	bgeu	s2,s3,80001264 <uvmunmap+0x30>
    if((pte = walk(pagetable, a, 0)) == 0)
    800012c4:	4601                	li	a2,0
    800012c6:	85ca                	mv	a1,s2
    800012c8:	8552                	mv	a0,s4
    800012ca:	00000097          	auipc	ra,0x0
    800012ce:	cbc080e7          	jalr	-836(ra) # 80000f86 <walk>
    800012d2:	84aa                	mv	s1,a0
    800012d4:	d95d                	beqz	a0,8000128a <uvmunmap+0x56>
    if((*pte & PTE_V) == 0)
    800012d6:	6108                	ld	a0,0(a0)
    800012d8:	00157793          	andi	a5,a0,1
    800012dc:	dfdd                	beqz	a5,8000129a <uvmunmap+0x66>
    if(PTE_FLAGS(*pte) == PTE_V)
    800012de:	3ff57793          	andi	a5,a0,1023
    800012e2:	fd7784e3          	beq	a5,s7,800012aa <uvmunmap+0x76>
    if(do_free){
    800012e6:	fc0a8ae3          	beqz	s5,800012ba <uvmunmap+0x86>
      uint64 pa = PTE2PA(*pte);
    800012ea:	8129                	srli	a0,a0,0xa
      kfree((void*)pa);
    800012ec:	0532                	slli	a0,a0,0xc
    800012ee:	fffff097          	auipc	ra,0xfffff
    800012f2:	6f4080e7          	jalr	1780(ra) # 800009e2 <kfree>
    800012f6:	b7d1                	j	800012ba <uvmunmap+0x86>

00000000800012f8 <uvmcreate>:

// create an empty user page table.
// returns 0 if out of memory.
pagetable_t
uvmcreate()
{
    800012f8:	1101                	addi	sp,sp,-32
    800012fa:	ec06                	sd	ra,24(sp)
    800012fc:	e822                	sd	s0,16(sp)
    800012fe:	e426                	sd	s1,8(sp)
    80001300:	1000                	addi	s0,sp,32
  pagetable_t pagetable;
  pagetable = (pagetable_t) kalloc();
    80001302:	fffff097          	auipc	ra,0xfffff
    80001306:	7d2080e7          	jalr	2002(ra) # 80000ad4 <kalloc>
    8000130a:	84aa                	mv	s1,a0
  if(pagetable == 0)
    8000130c:	c519                	beqz	a0,8000131a <uvmcreate+0x22>
    return 0;
  memset(pagetable, 0, PGSIZE);
    8000130e:	6605                	lui	a2,0x1
    80001310:	4581                	li	a1,0
    80001312:	00000097          	auipc	ra,0x0
    80001316:	994080e7          	jalr	-1644(ra) # 80000ca6 <memset>
  return pagetable;
}
    8000131a:	8526                	mv	a0,s1
    8000131c:	60e2                	ld	ra,24(sp)
    8000131e:	6442                	ld	s0,16(sp)
    80001320:	64a2                	ld	s1,8(sp)
    80001322:	6105                	addi	sp,sp,32
    80001324:	8082                	ret

0000000080001326 <uvminit>:
// Load the user initcode into address 0 of pagetable,
// for the very first process.
// sz must be less than a page.
void
uvminit(pagetable_t pagetable, uchar *src, uint sz)
{
    80001326:	7179                	addi	sp,sp,-48
    80001328:	f406                	sd	ra,40(sp)
    8000132a:	f022                	sd	s0,32(sp)
    8000132c:	ec26                	sd	s1,24(sp)
    8000132e:	e84a                	sd	s2,16(sp)
    80001330:	e44e                	sd	s3,8(sp)
    80001332:	e052                	sd	s4,0(sp)
    80001334:	1800                	addi	s0,sp,48
  char *mem;

  if(sz >= PGSIZE)
    80001336:	6785                	lui	a5,0x1
    80001338:	04f67863          	bgeu	a2,a5,80001388 <uvminit+0x62>
    8000133c:	8a2a                	mv	s4,a0
    8000133e:	89ae                	mv	s3,a1
    80001340:	84b2                	mv	s1,a2
    panic("inituvm: more than a page");
  mem = kalloc();
    80001342:	fffff097          	auipc	ra,0xfffff
    80001346:	792080e7          	jalr	1938(ra) # 80000ad4 <kalloc>
    8000134a:	892a                	mv	s2,a0
  memset(mem, 0, PGSIZE);
    8000134c:	6605                	lui	a2,0x1
    8000134e:	4581                	li	a1,0
    80001350:	00000097          	auipc	ra,0x0
    80001354:	956080e7          	jalr	-1706(ra) # 80000ca6 <memset>
  mappages(pagetable, 0, PGSIZE, (uint64)mem, PTE_W|PTE_R|PTE_X|PTE_U);
    80001358:	4779                	li	a4,30
    8000135a:	86ca                	mv	a3,s2
    8000135c:	6605                	lui	a2,0x1
    8000135e:	4581                	li	a1,0
    80001360:	8552                	mv	a0,s4
    80001362:	00000097          	auipc	ra,0x0
    80001366:	d0c080e7          	jalr	-756(ra) # 8000106e <mappages>
  memmove(mem, src, sz);
    8000136a:	8626                	mv	a2,s1
    8000136c:	85ce                	mv	a1,s3
    8000136e:	854a                	mv	a0,s2
    80001370:	00000097          	auipc	ra,0x0
    80001374:	992080e7          	jalr	-1646(ra) # 80000d02 <memmove>
}
    80001378:	70a2                	ld	ra,40(sp)
    8000137a:	7402                	ld	s0,32(sp)
    8000137c:	64e2                	ld	s1,24(sp)
    8000137e:	6942                	ld	s2,16(sp)
    80001380:	69a2                	ld	s3,8(sp)
    80001382:	6a02                	ld	s4,0(sp)
    80001384:	6145                	addi	sp,sp,48
    80001386:	8082                	ret
    panic("inituvm: more than a page");
    80001388:	00007517          	auipc	a0,0x7
    8000138c:	dd050513          	addi	a0,a0,-560 # 80008158 <digits+0x118>
    80001390:	fffff097          	auipc	ra,0xfffff
    80001394:	1aa080e7          	jalr	426(ra) # 8000053a <panic>

0000000080001398 <uvmdealloc>:
// newsz.  oldsz and newsz need not be page-aligned, nor does newsz
// need to be less than oldsz.  oldsz can be larger than the actual
// process size.  Returns the new process size.
uint64
uvmdealloc(pagetable_t pagetable, uint64 oldsz, uint64 newsz)
{
    80001398:	1101                	addi	sp,sp,-32
    8000139a:	ec06                	sd	ra,24(sp)
    8000139c:	e822                	sd	s0,16(sp)
    8000139e:	e426                	sd	s1,8(sp)
    800013a0:	1000                	addi	s0,sp,32
  if(newsz >= oldsz)
    return oldsz;
    800013a2:	84ae                	mv	s1,a1
  if(newsz >= oldsz)
    800013a4:	00b67d63          	bgeu	a2,a1,800013be <uvmdealloc+0x26>
    800013a8:	84b2                	mv	s1,a2

  if(PGROUNDUP(newsz) < PGROUNDUP(oldsz)){
    800013aa:	6785                	lui	a5,0x1
    800013ac:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    800013ae:	00f60733          	add	a4,a2,a5
    800013b2:	76fd                	lui	a3,0xfffff
    800013b4:	8f75                	and	a4,a4,a3
    800013b6:	97ae                	add	a5,a5,a1
    800013b8:	8ff5                	and	a5,a5,a3
    800013ba:	00f76863          	bltu	a4,a5,800013ca <uvmdealloc+0x32>
    int npages = (PGROUNDUP(oldsz) - PGROUNDUP(newsz)) / PGSIZE;
    uvmunmap(pagetable, PGROUNDUP(newsz), npages, 1);
  }

  return newsz;
}
    800013be:	8526                	mv	a0,s1
    800013c0:	60e2                	ld	ra,24(sp)
    800013c2:	6442                	ld	s0,16(sp)
    800013c4:	64a2                	ld	s1,8(sp)
    800013c6:	6105                	addi	sp,sp,32
    800013c8:	8082                	ret
    int npages = (PGROUNDUP(oldsz) - PGROUNDUP(newsz)) / PGSIZE;
    800013ca:	8f99                	sub	a5,a5,a4
    800013cc:	83b1                	srli	a5,a5,0xc
    uvmunmap(pagetable, PGROUNDUP(newsz), npages, 1);
    800013ce:	4685                	li	a3,1
    800013d0:	0007861b          	sext.w	a2,a5
    800013d4:	85ba                	mv	a1,a4
    800013d6:	00000097          	auipc	ra,0x0
    800013da:	e5e080e7          	jalr	-418(ra) # 80001234 <uvmunmap>
    800013de:	b7c5                	j	800013be <uvmdealloc+0x26>

00000000800013e0 <uvmalloc>:
  if(newsz < oldsz)
    800013e0:	0ab66163          	bltu	a2,a1,80001482 <uvmalloc+0xa2>
{
    800013e4:	7139                	addi	sp,sp,-64
    800013e6:	fc06                	sd	ra,56(sp)
    800013e8:	f822                	sd	s0,48(sp)
    800013ea:	f426                	sd	s1,40(sp)
    800013ec:	f04a                	sd	s2,32(sp)
    800013ee:	ec4e                	sd	s3,24(sp)
    800013f0:	e852                	sd	s4,16(sp)
    800013f2:	e456                	sd	s5,8(sp)
    800013f4:	0080                	addi	s0,sp,64
    800013f6:	8aaa                	mv	s5,a0
    800013f8:	8a32                	mv	s4,a2
  oldsz = PGROUNDUP(oldsz);
    800013fa:	6785                	lui	a5,0x1
    800013fc:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    800013fe:	95be                	add	a1,a1,a5
    80001400:	77fd                	lui	a5,0xfffff
    80001402:	00f5f9b3          	and	s3,a1,a5
  for(a = oldsz; a < newsz; a += PGSIZE){
    80001406:	08c9f063          	bgeu	s3,a2,80001486 <uvmalloc+0xa6>
    8000140a:	894e                	mv	s2,s3
    mem = kalloc();
    8000140c:	fffff097          	auipc	ra,0xfffff
    80001410:	6c8080e7          	jalr	1736(ra) # 80000ad4 <kalloc>
    80001414:	84aa                	mv	s1,a0
    if(mem == 0){
    80001416:	c51d                	beqz	a0,80001444 <uvmalloc+0x64>
    memset(mem, 0, PGSIZE);
    80001418:	6605                	lui	a2,0x1
    8000141a:	4581                	li	a1,0
    8000141c:	00000097          	auipc	ra,0x0
    80001420:	88a080e7          	jalr	-1910(ra) # 80000ca6 <memset>
    if(mappages(pagetable, a, PGSIZE, (uint64)mem, PTE_W|PTE_X|PTE_R|PTE_U) != 0){
    80001424:	4779                	li	a4,30
    80001426:	86a6                	mv	a3,s1
    80001428:	6605                	lui	a2,0x1
    8000142a:	85ca                	mv	a1,s2
    8000142c:	8556                	mv	a0,s5
    8000142e:	00000097          	auipc	ra,0x0
    80001432:	c40080e7          	jalr	-960(ra) # 8000106e <mappages>
    80001436:	e905                	bnez	a0,80001466 <uvmalloc+0x86>
  for(a = oldsz; a < newsz; a += PGSIZE){
    80001438:	6785                	lui	a5,0x1
    8000143a:	993e                	add	s2,s2,a5
    8000143c:	fd4968e3          	bltu	s2,s4,8000140c <uvmalloc+0x2c>
  return newsz;
    80001440:	8552                	mv	a0,s4
    80001442:	a809                	j	80001454 <uvmalloc+0x74>
      uvmdealloc(pagetable, a, oldsz);
    80001444:	864e                	mv	a2,s3
    80001446:	85ca                	mv	a1,s2
    80001448:	8556                	mv	a0,s5
    8000144a:	00000097          	auipc	ra,0x0
    8000144e:	f4e080e7          	jalr	-178(ra) # 80001398 <uvmdealloc>
      return 0;
    80001452:	4501                	li	a0,0
}
    80001454:	70e2                	ld	ra,56(sp)
    80001456:	7442                	ld	s0,48(sp)
    80001458:	74a2                	ld	s1,40(sp)
    8000145a:	7902                	ld	s2,32(sp)
    8000145c:	69e2                	ld	s3,24(sp)
    8000145e:	6a42                	ld	s4,16(sp)
    80001460:	6aa2                	ld	s5,8(sp)
    80001462:	6121                	addi	sp,sp,64
    80001464:	8082                	ret
      kfree(mem);
    80001466:	8526                	mv	a0,s1
    80001468:	fffff097          	auipc	ra,0xfffff
    8000146c:	57a080e7          	jalr	1402(ra) # 800009e2 <kfree>
      uvmdealloc(pagetable, a, oldsz);
    80001470:	864e                	mv	a2,s3
    80001472:	85ca                	mv	a1,s2
    80001474:	8556                	mv	a0,s5
    80001476:	00000097          	auipc	ra,0x0
    8000147a:	f22080e7          	jalr	-222(ra) # 80001398 <uvmdealloc>
      return 0;
    8000147e:	4501                	li	a0,0
    80001480:	bfd1                	j	80001454 <uvmalloc+0x74>
    return oldsz;
    80001482:	852e                	mv	a0,a1
}
    80001484:	8082                	ret
  return newsz;
    80001486:	8532                	mv	a0,a2
    80001488:	b7f1                	j	80001454 <uvmalloc+0x74>

000000008000148a <freewalk>:

// Recursively free page-table pages.
// All leaf mappings must already have been removed.
void
freewalk(pagetable_t pagetable)
{
    8000148a:	7179                	addi	sp,sp,-48
    8000148c:	f406                	sd	ra,40(sp)
    8000148e:	f022                	sd	s0,32(sp)
    80001490:	ec26                	sd	s1,24(sp)
    80001492:	e84a                	sd	s2,16(sp)
    80001494:	e44e                	sd	s3,8(sp)
    80001496:	e052                	sd	s4,0(sp)
    80001498:	1800                	addi	s0,sp,48
    8000149a:	8a2a                	mv	s4,a0
  // there are 2^9 = 512 PTEs in a page table.
  for(int i = 0; i < 512; i++){
    8000149c:	84aa                	mv	s1,a0
    8000149e:	6905                	lui	s2,0x1
    800014a0:	992a                	add	s2,s2,a0
    pte_t pte = pagetable[i];
    if((pte & PTE_V) && (pte & (PTE_R|PTE_W|PTE_X)) == 0){
    800014a2:	4985                	li	s3,1
    800014a4:	a829                	j	800014be <freewalk+0x34>
      // this PTE points to a lower-level page table.
      uint64 child = PTE2PA(pte);
    800014a6:	83a9                	srli	a5,a5,0xa
      freewalk((pagetable_t)child);
    800014a8:	00c79513          	slli	a0,a5,0xc
    800014ac:	00000097          	auipc	ra,0x0
    800014b0:	fde080e7          	jalr	-34(ra) # 8000148a <freewalk>
      pagetable[i] = 0;
    800014b4:	0004b023          	sd	zero,0(s1)
  for(int i = 0; i < 512; i++){
    800014b8:	04a1                	addi	s1,s1,8
    800014ba:	03248163          	beq	s1,s2,800014dc <freewalk+0x52>
    pte_t pte = pagetable[i];
    800014be:	609c                	ld	a5,0(s1)
    if((pte & PTE_V) && (pte & (PTE_R|PTE_W|PTE_X)) == 0){
    800014c0:	00f7f713          	andi	a4,a5,15
    800014c4:	ff3701e3          	beq	a4,s3,800014a6 <freewalk+0x1c>
    } else if(pte & PTE_V){
    800014c8:	8b85                	andi	a5,a5,1
    800014ca:	d7fd                	beqz	a5,800014b8 <freewalk+0x2e>
      panic("freewalk: leaf");
    800014cc:	00007517          	auipc	a0,0x7
    800014d0:	cac50513          	addi	a0,a0,-852 # 80008178 <digits+0x138>
    800014d4:	fffff097          	auipc	ra,0xfffff
    800014d8:	066080e7          	jalr	102(ra) # 8000053a <panic>
    }
  }
  kfree((void*)pagetable);
    800014dc:	8552                	mv	a0,s4
    800014de:	fffff097          	auipc	ra,0xfffff
    800014e2:	504080e7          	jalr	1284(ra) # 800009e2 <kfree>
}
    800014e6:	70a2                	ld	ra,40(sp)
    800014e8:	7402                	ld	s0,32(sp)
    800014ea:	64e2                	ld	s1,24(sp)
    800014ec:	6942                	ld	s2,16(sp)
    800014ee:	69a2                	ld	s3,8(sp)
    800014f0:	6a02                	ld	s4,0(sp)
    800014f2:	6145                	addi	sp,sp,48
    800014f4:	8082                	ret

00000000800014f6 <uvmfree>:

// Free user memory pages,
// then free page-table pages.
void
uvmfree(pagetable_t pagetable, uint64 sz)
{
    800014f6:	1101                	addi	sp,sp,-32
    800014f8:	ec06                	sd	ra,24(sp)
    800014fa:	e822                	sd	s0,16(sp)
    800014fc:	e426                	sd	s1,8(sp)
    800014fe:	1000                	addi	s0,sp,32
    80001500:	84aa                	mv	s1,a0
  if(sz > 0)
    80001502:	e999                	bnez	a1,80001518 <uvmfree+0x22>
    uvmunmap(pagetable, 0, PGROUNDUP(sz)/PGSIZE, 1);
  freewalk(pagetable);
    80001504:	8526                	mv	a0,s1
    80001506:	00000097          	auipc	ra,0x0
    8000150a:	f84080e7          	jalr	-124(ra) # 8000148a <freewalk>
}
    8000150e:	60e2                	ld	ra,24(sp)
    80001510:	6442                	ld	s0,16(sp)
    80001512:	64a2                	ld	s1,8(sp)
    80001514:	6105                	addi	sp,sp,32
    80001516:	8082                	ret
    uvmunmap(pagetable, 0, PGROUNDUP(sz)/PGSIZE, 1);
    80001518:	6785                	lui	a5,0x1
    8000151a:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    8000151c:	95be                	add	a1,a1,a5
    8000151e:	4685                	li	a3,1
    80001520:	00c5d613          	srli	a2,a1,0xc
    80001524:	4581                	li	a1,0
    80001526:	00000097          	auipc	ra,0x0
    8000152a:	d0e080e7          	jalr	-754(ra) # 80001234 <uvmunmap>
    8000152e:	bfd9                	j	80001504 <uvmfree+0xe>

0000000080001530 <uvmcopy>:
  pte_t *pte;
  uint64 pa, i;
  uint flags;
  char *mem;

  for(i = 0; i < sz; i += PGSIZE){
    80001530:	c679                	beqz	a2,800015fe <uvmcopy+0xce>
{
    80001532:	715d                	addi	sp,sp,-80
    80001534:	e486                	sd	ra,72(sp)
    80001536:	e0a2                	sd	s0,64(sp)
    80001538:	fc26                	sd	s1,56(sp)
    8000153a:	f84a                	sd	s2,48(sp)
    8000153c:	f44e                	sd	s3,40(sp)
    8000153e:	f052                	sd	s4,32(sp)
    80001540:	ec56                	sd	s5,24(sp)
    80001542:	e85a                	sd	s6,16(sp)
    80001544:	e45e                	sd	s7,8(sp)
    80001546:	0880                	addi	s0,sp,80
    80001548:	8b2a                	mv	s6,a0
    8000154a:	8aae                	mv	s5,a1
    8000154c:	8a32                	mv	s4,a2
  for(i = 0; i < sz; i += PGSIZE){
    8000154e:	4981                	li	s3,0
    if((pte = walk(old, i, 0)) == 0)
    80001550:	4601                	li	a2,0
    80001552:	85ce                	mv	a1,s3
    80001554:	855a                	mv	a0,s6
    80001556:	00000097          	auipc	ra,0x0
    8000155a:	a30080e7          	jalr	-1488(ra) # 80000f86 <walk>
    8000155e:	c531                	beqz	a0,800015aa <uvmcopy+0x7a>
      panic("uvmcopy: pte should exist");
    if((*pte & PTE_V) == 0)
    80001560:	6118                	ld	a4,0(a0)
    80001562:	00177793          	andi	a5,a4,1
    80001566:	cbb1                	beqz	a5,800015ba <uvmcopy+0x8a>
      panic("uvmcopy: page not present");
    pa = PTE2PA(*pte);
    80001568:	00a75593          	srli	a1,a4,0xa
    8000156c:	00c59b93          	slli	s7,a1,0xc
    flags = PTE_FLAGS(*pte);
    80001570:	3ff77493          	andi	s1,a4,1023
    if((mem = kalloc()) == 0)
    80001574:	fffff097          	auipc	ra,0xfffff
    80001578:	560080e7          	jalr	1376(ra) # 80000ad4 <kalloc>
    8000157c:	892a                	mv	s2,a0
    8000157e:	c939                	beqz	a0,800015d4 <uvmcopy+0xa4>
      goto err;
    memmove(mem, (char*)pa, PGSIZE);
    80001580:	6605                	lui	a2,0x1
    80001582:	85de                	mv	a1,s7
    80001584:	fffff097          	auipc	ra,0xfffff
    80001588:	77e080e7          	jalr	1918(ra) # 80000d02 <memmove>
    if(mappages(new, i, PGSIZE, (uint64)mem, flags) != 0){
    8000158c:	8726                	mv	a4,s1
    8000158e:	86ca                	mv	a3,s2
    80001590:	6605                	lui	a2,0x1
    80001592:	85ce                	mv	a1,s3
    80001594:	8556                	mv	a0,s5
    80001596:	00000097          	auipc	ra,0x0
    8000159a:	ad8080e7          	jalr	-1320(ra) # 8000106e <mappages>
    8000159e:	e515                	bnez	a0,800015ca <uvmcopy+0x9a>
  for(i = 0; i < sz; i += PGSIZE){
    800015a0:	6785                	lui	a5,0x1
    800015a2:	99be                	add	s3,s3,a5
    800015a4:	fb49e6e3          	bltu	s3,s4,80001550 <uvmcopy+0x20>
    800015a8:	a081                	j	800015e8 <uvmcopy+0xb8>
      panic("uvmcopy: pte should exist");
    800015aa:	00007517          	auipc	a0,0x7
    800015ae:	bde50513          	addi	a0,a0,-1058 # 80008188 <digits+0x148>
    800015b2:	fffff097          	auipc	ra,0xfffff
    800015b6:	f88080e7          	jalr	-120(ra) # 8000053a <panic>
      panic("uvmcopy: page not present");
    800015ba:	00007517          	auipc	a0,0x7
    800015be:	bee50513          	addi	a0,a0,-1042 # 800081a8 <digits+0x168>
    800015c2:	fffff097          	auipc	ra,0xfffff
    800015c6:	f78080e7          	jalr	-136(ra) # 8000053a <panic>
      kfree(mem);
    800015ca:	854a                	mv	a0,s2
    800015cc:	fffff097          	auipc	ra,0xfffff
    800015d0:	416080e7          	jalr	1046(ra) # 800009e2 <kfree>
    }
  }
  return 0;

 err:
  uvmunmap(new, 0, i / PGSIZE, 1);
    800015d4:	4685                	li	a3,1
    800015d6:	00c9d613          	srli	a2,s3,0xc
    800015da:	4581                	li	a1,0
    800015dc:	8556                	mv	a0,s5
    800015de:	00000097          	auipc	ra,0x0
    800015e2:	c56080e7          	jalr	-938(ra) # 80001234 <uvmunmap>
  return -1;
    800015e6:	557d                	li	a0,-1
}
    800015e8:	60a6                	ld	ra,72(sp)
    800015ea:	6406                	ld	s0,64(sp)
    800015ec:	74e2                	ld	s1,56(sp)
    800015ee:	7942                	ld	s2,48(sp)
    800015f0:	79a2                	ld	s3,40(sp)
    800015f2:	7a02                	ld	s4,32(sp)
    800015f4:	6ae2                	ld	s5,24(sp)
    800015f6:	6b42                	ld	s6,16(sp)
    800015f8:	6ba2                	ld	s7,8(sp)
    800015fa:	6161                	addi	sp,sp,80
    800015fc:	8082                	ret
  return 0;
    800015fe:	4501                	li	a0,0
}
    80001600:	8082                	ret

0000000080001602 <uvmclear>:

// mark a PTE invalid for user access.
// used by exec for the user stack guard page.
void
uvmclear(pagetable_t pagetable, uint64 va)
{
    80001602:	1141                	addi	sp,sp,-16
    80001604:	e406                	sd	ra,8(sp)
    80001606:	e022                	sd	s0,0(sp)
    80001608:	0800                	addi	s0,sp,16
  pte_t *pte;
  
  pte = walk(pagetable, va, 0);
    8000160a:	4601                	li	a2,0
    8000160c:	00000097          	auipc	ra,0x0
    80001610:	97a080e7          	jalr	-1670(ra) # 80000f86 <walk>
  if(pte == 0)
    80001614:	c901                	beqz	a0,80001624 <uvmclear+0x22>
    panic("uvmclear");
  *pte &= ~PTE_U;
    80001616:	611c                	ld	a5,0(a0)
    80001618:	9bbd                	andi	a5,a5,-17
    8000161a:	e11c                	sd	a5,0(a0)
}
    8000161c:	60a2                	ld	ra,8(sp)
    8000161e:	6402                	ld	s0,0(sp)
    80001620:	0141                	addi	sp,sp,16
    80001622:	8082                	ret
    panic("uvmclear");
    80001624:	00007517          	auipc	a0,0x7
    80001628:	ba450513          	addi	a0,a0,-1116 # 800081c8 <digits+0x188>
    8000162c:	fffff097          	auipc	ra,0xfffff
    80001630:	f0e080e7          	jalr	-242(ra) # 8000053a <panic>

0000000080001634 <copyout>:
int
copyout(pagetable_t pagetable, uint64 dstva, char *src, uint64 len)
{
  uint64 n, va0, pa0;

  while(len > 0){
    80001634:	c6bd                	beqz	a3,800016a2 <copyout+0x6e>
{
    80001636:	715d                	addi	sp,sp,-80
    80001638:	e486                	sd	ra,72(sp)
    8000163a:	e0a2                	sd	s0,64(sp)
    8000163c:	fc26                	sd	s1,56(sp)
    8000163e:	f84a                	sd	s2,48(sp)
    80001640:	f44e                	sd	s3,40(sp)
    80001642:	f052                	sd	s4,32(sp)
    80001644:	ec56                	sd	s5,24(sp)
    80001646:	e85a                	sd	s6,16(sp)
    80001648:	e45e                	sd	s7,8(sp)
    8000164a:	e062                	sd	s8,0(sp)
    8000164c:	0880                	addi	s0,sp,80
    8000164e:	8b2a                	mv	s6,a0
    80001650:	8c2e                	mv	s8,a1
    80001652:	8a32                	mv	s4,a2
    80001654:	89b6                	mv	s3,a3
    va0 = PGROUNDDOWN(dstva);
    80001656:	7bfd                	lui	s7,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if(pa0 == 0)
      return -1;
    n = PGSIZE - (dstva - va0);
    80001658:	6a85                	lui	s5,0x1
    8000165a:	a015                	j	8000167e <copyout+0x4a>
    if(n > len)
      n = len;
    memmove((void *)(pa0 + (dstva - va0)), src, n);
    8000165c:	9562                	add	a0,a0,s8
    8000165e:	0004861b          	sext.w	a2,s1
    80001662:	85d2                	mv	a1,s4
    80001664:	41250533          	sub	a0,a0,s2
    80001668:	fffff097          	auipc	ra,0xfffff
    8000166c:	69a080e7          	jalr	1690(ra) # 80000d02 <memmove>

    len -= n;
    80001670:	409989b3          	sub	s3,s3,s1
    src += n;
    80001674:	9a26                	add	s4,s4,s1
    dstva = va0 + PGSIZE;
    80001676:	01590c33          	add	s8,s2,s5
  while(len > 0){
    8000167a:	02098263          	beqz	s3,8000169e <copyout+0x6a>
    va0 = PGROUNDDOWN(dstva);
    8000167e:	017c7933          	and	s2,s8,s7
    pa0 = walkaddr(pagetable, va0);
    80001682:	85ca                	mv	a1,s2
    80001684:	855a                	mv	a0,s6
    80001686:	00000097          	auipc	ra,0x0
    8000168a:	9a6080e7          	jalr	-1626(ra) # 8000102c <walkaddr>
    if(pa0 == 0)
    8000168e:	cd01                	beqz	a0,800016a6 <copyout+0x72>
    n = PGSIZE - (dstva - va0);
    80001690:	418904b3          	sub	s1,s2,s8
    80001694:	94d6                	add	s1,s1,s5
    80001696:	fc99f3e3          	bgeu	s3,s1,8000165c <copyout+0x28>
    8000169a:	84ce                	mv	s1,s3
    8000169c:	b7c1                	j	8000165c <copyout+0x28>
  }
  return 0;
    8000169e:	4501                	li	a0,0
    800016a0:	a021                	j	800016a8 <copyout+0x74>
    800016a2:	4501                	li	a0,0
}
    800016a4:	8082                	ret
      return -1;
    800016a6:	557d                	li	a0,-1
}
    800016a8:	60a6                	ld	ra,72(sp)
    800016aa:	6406                	ld	s0,64(sp)
    800016ac:	74e2                	ld	s1,56(sp)
    800016ae:	7942                	ld	s2,48(sp)
    800016b0:	79a2                	ld	s3,40(sp)
    800016b2:	7a02                	ld	s4,32(sp)
    800016b4:	6ae2                	ld	s5,24(sp)
    800016b6:	6b42                	ld	s6,16(sp)
    800016b8:	6ba2                	ld	s7,8(sp)
    800016ba:	6c02                	ld	s8,0(sp)
    800016bc:	6161                	addi	sp,sp,80
    800016be:	8082                	ret

00000000800016c0 <copyin>:
int
copyin(pagetable_t pagetable, char *dst, uint64 srcva, uint64 len)
{
  uint64 n, va0, pa0;

  while(len > 0){
    800016c0:	caa5                	beqz	a3,80001730 <copyin+0x70>
{
    800016c2:	715d                	addi	sp,sp,-80
    800016c4:	e486                	sd	ra,72(sp)
    800016c6:	e0a2                	sd	s0,64(sp)
    800016c8:	fc26                	sd	s1,56(sp)
    800016ca:	f84a                	sd	s2,48(sp)
    800016cc:	f44e                	sd	s3,40(sp)
    800016ce:	f052                	sd	s4,32(sp)
    800016d0:	ec56                	sd	s5,24(sp)
    800016d2:	e85a                	sd	s6,16(sp)
    800016d4:	e45e                	sd	s7,8(sp)
    800016d6:	e062                	sd	s8,0(sp)
    800016d8:	0880                	addi	s0,sp,80
    800016da:	8b2a                	mv	s6,a0
    800016dc:	8a2e                	mv	s4,a1
    800016de:	8c32                	mv	s8,a2
    800016e0:	89b6                	mv	s3,a3
    va0 = PGROUNDDOWN(srcva);
    800016e2:	7bfd                	lui	s7,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if(pa0 == 0)
      return -1;
    n = PGSIZE - (srcva - va0);
    800016e4:	6a85                	lui	s5,0x1
    800016e6:	a01d                	j	8000170c <copyin+0x4c>
    if(n > len)
      n = len;
    memmove(dst, (void *)(pa0 + (srcva - va0)), n);
    800016e8:	018505b3          	add	a1,a0,s8
    800016ec:	0004861b          	sext.w	a2,s1
    800016f0:	412585b3          	sub	a1,a1,s2
    800016f4:	8552                	mv	a0,s4
    800016f6:	fffff097          	auipc	ra,0xfffff
    800016fa:	60c080e7          	jalr	1548(ra) # 80000d02 <memmove>

    len -= n;
    800016fe:	409989b3          	sub	s3,s3,s1
    dst += n;
    80001702:	9a26                	add	s4,s4,s1
    srcva = va0 + PGSIZE;
    80001704:	01590c33          	add	s8,s2,s5
  while(len > 0){
    80001708:	02098263          	beqz	s3,8000172c <copyin+0x6c>
    va0 = PGROUNDDOWN(srcva);
    8000170c:	017c7933          	and	s2,s8,s7
    pa0 = walkaddr(pagetable, va0);
    80001710:	85ca                	mv	a1,s2
    80001712:	855a                	mv	a0,s6
    80001714:	00000097          	auipc	ra,0x0
    80001718:	918080e7          	jalr	-1768(ra) # 8000102c <walkaddr>
    if(pa0 == 0)
    8000171c:	cd01                	beqz	a0,80001734 <copyin+0x74>
    n = PGSIZE - (srcva - va0);
    8000171e:	418904b3          	sub	s1,s2,s8
    80001722:	94d6                	add	s1,s1,s5
    80001724:	fc99f2e3          	bgeu	s3,s1,800016e8 <copyin+0x28>
    80001728:	84ce                	mv	s1,s3
    8000172a:	bf7d                	j	800016e8 <copyin+0x28>
  }
  return 0;
    8000172c:	4501                	li	a0,0
    8000172e:	a021                	j	80001736 <copyin+0x76>
    80001730:	4501                	li	a0,0
}
    80001732:	8082                	ret
      return -1;
    80001734:	557d                	li	a0,-1
}
    80001736:	60a6                	ld	ra,72(sp)
    80001738:	6406                	ld	s0,64(sp)
    8000173a:	74e2                	ld	s1,56(sp)
    8000173c:	7942                	ld	s2,48(sp)
    8000173e:	79a2                	ld	s3,40(sp)
    80001740:	7a02                	ld	s4,32(sp)
    80001742:	6ae2                	ld	s5,24(sp)
    80001744:	6b42                	ld	s6,16(sp)
    80001746:	6ba2                	ld	s7,8(sp)
    80001748:	6c02                	ld	s8,0(sp)
    8000174a:	6161                	addi	sp,sp,80
    8000174c:	8082                	ret

000000008000174e <copyinstr>:
copyinstr(pagetable_t pagetable, char *dst, uint64 srcva, uint64 max)
{
  uint64 n, va0, pa0;
  int got_null = 0;

  while(got_null == 0 && max > 0){
    8000174e:	c2dd                	beqz	a3,800017f4 <copyinstr+0xa6>
{
    80001750:	715d                	addi	sp,sp,-80
    80001752:	e486                	sd	ra,72(sp)
    80001754:	e0a2                	sd	s0,64(sp)
    80001756:	fc26                	sd	s1,56(sp)
    80001758:	f84a                	sd	s2,48(sp)
    8000175a:	f44e                	sd	s3,40(sp)
    8000175c:	f052                	sd	s4,32(sp)
    8000175e:	ec56                	sd	s5,24(sp)
    80001760:	e85a                	sd	s6,16(sp)
    80001762:	e45e                	sd	s7,8(sp)
    80001764:	0880                	addi	s0,sp,80
    80001766:	8a2a                	mv	s4,a0
    80001768:	8b2e                	mv	s6,a1
    8000176a:	8bb2                	mv	s7,a2
    8000176c:	84b6                	mv	s1,a3
    va0 = PGROUNDDOWN(srcva);
    8000176e:	7afd                	lui	s5,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if(pa0 == 0)
      return -1;
    n = PGSIZE - (srcva - va0);
    80001770:	6985                	lui	s3,0x1
    80001772:	a02d                	j	8000179c <copyinstr+0x4e>
      n = max;

    char *p = (char *) (pa0 + (srcva - va0));
    while(n > 0){
      if(*p == '\0'){
        *dst = '\0';
    80001774:	00078023          	sb	zero,0(a5) # 1000 <_entry-0x7ffff000>
    80001778:	4785                	li	a5,1
      dst++;
    }

    srcva = va0 + PGSIZE;
  }
  if(got_null){
    8000177a:	37fd                	addiw	a5,a5,-1
    8000177c:	0007851b          	sext.w	a0,a5
    return 0;
  } else {
    return -1;
  }
}
    80001780:	60a6                	ld	ra,72(sp)
    80001782:	6406                	ld	s0,64(sp)
    80001784:	74e2                	ld	s1,56(sp)
    80001786:	7942                	ld	s2,48(sp)
    80001788:	79a2                	ld	s3,40(sp)
    8000178a:	7a02                	ld	s4,32(sp)
    8000178c:	6ae2                	ld	s5,24(sp)
    8000178e:	6b42                	ld	s6,16(sp)
    80001790:	6ba2                	ld	s7,8(sp)
    80001792:	6161                	addi	sp,sp,80
    80001794:	8082                	ret
    srcva = va0 + PGSIZE;
    80001796:	01390bb3          	add	s7,s2,s3
  while(got_null == 0 && max > 0){
    8000179a:	c8a9                	beqz	s1,800017ec <copyinstr+0x9e>
    va0 = PGROUNDDOWN(srcva);
    8000179c:	015bf933          	and	s2,s7,s5
    pa0 = walkaddr(pagetable, va0);
    800017a0:	85ca                	mv	a1,s2
    800017a2:	8552                	mv	a0,s4
    800017a4:	00000097          	auipc	ra,0x0
    800017a8:	888080e7          	jalr	-1912(ra) # 8000102c <walkaddr>
    if(pa0 == 0)
    800017ac:	c131                	beqz	a0,800017f0 <copyinstr+0xa2>
    n = PGSIZE - (srcva - va0);
    800017ae:	417906b3          	sub	a3,s2,s7
    800017b2:	96ce                	add	a3,a3,s3
    800017b4:	00d4f363          	bgeu	s1,a3,800017ba <copyinstr+0x6c>
    800017b8:	86a6                	mv	a3,s1
    char *p = (char *) (pa0 + (srcva - va0));
    800017ba:	955e                	add	a0,a0,s7
    800017bc:	41250533          	sub	a0,a0,s2
    while(n > 0){
    800017c0:	daf9                	beqz	a3,80001796 <copyinstr+0x48>
    800017c2:	87da                	mv	a5,s6
      if(*p == '\0'){
    800017c4:	41650633          	sub	a2,a0,s6
    800017c8:	fff48593          	addi	a1,s1,-1
    800017cc:	95da                	add	a1,a1,s6
    while(n > 0){
    800017ce:	96da                	add	a3,a3,s6
      if(*p == '\0'){
    800017d0:	00f60733          	add	a4,a2,a5
    800017d4:	00074703          	lbu	a4,0(a4) # fffffffffffff000 <end+0xffffffff7ffd9000>
    800017d8:	df51                	beqz	a4,80001774 <copyinstr+0x26>
        *dst = *p;
    800017da:	00e78023          	sb	a4,0(a5)
      --max;
    800017de:	40f584b3          	sub	s1,a1,a5
      dst++;
    800017e2:	0785                	addi	a5,a5,1
    while(n > 0){
    800017e4:	fed796e3          	bne	a5,a3,800017d0 <copyinstr+0x82>
      dst++;
    800017e8:	8b3e                	mv	s6,a5
    800017ea:	b775                	j	80001796 <copyinstr+0x48>
    800017ec:	4781                	li	a5,0
    800017ee:	b771                	j	8000177a <copyinstr+0x2c>
      return -1;
    800017f0:	557d                	li	a0,-1
    800017f2:	b779                	j	80001780 <copyinstr+0x32>
  int got_null = 0;
    800017f4:	4781                	li	a5,0
  if(got_null){
    800017f6:	37fd                	addiw	a5,a5,-1
    800017f8:	0007851b          	sext.w	a0,a5
}
    800017fc:	8082                	ret

00000000800017fe <proc_mapstacks>:

// Allocate a page for each process's kernel stack.
// Map it high in memory, followed by an invalid
// guard page.
void
proc_mapstacks(pagetable_t kpgtbl) {
    800017fe:	7139                	addi	sp,sp,-64
    80001800:	fc06                	sd	ra,56(sp)
    80001802:	f822                	sd	s0,48(sp)
    80001804:	f426                	sd	s1,40(sp)
    80001806:	f04a                	sd	s2,32(sp)
    80001808:	ec4e                	sd	s3,24(sp)
    8000180a:	e852                	sd	s4,16(sp)
    8000180c:	e456                	sd	s5,8(sp)
    8000180e:	e05a                	sd	s6,0(sp)
    80001810:	0080                	addi	s0,sp,64
    80001812:	89aa                	mv	s3,a0
  struct proc *p;
  
  for(p = proc; p < &proc[NPROC]; p++) {
    80001814:	00010497          	auipc	s1,0x10
    80001818:	ebc48493          	addi	s1,s1,-324 # 800116d0 <proc>
    char *pa = kalloc();
    if(pa == 0)
      panic("kalloc");
    uint64 va = KSTACK((int) (p - proc));
    8000181c:	8b26                	mv	s6,s1
    8000181e:	00006a97          	auipc	s5,0x6
    80001822:	7e2a8a93          	addi	s5,s5,2018 # 80008000 <etext>
    80001826:	04000937          	lui	s2,0x4000
    8000182a:	197d                	addi	s2,s2,-1 # 3ffffff <_entry-0x7c000001>
    8000182c:	0932                	slli	s2,s2,0xc
  for(p = proc; p < &proc[NPROC]; p++) {
    8000182e:	00016a17          	auipc	s4,0x16
    80001832:	8a2a0a13          	addi	s4,s4,-1886 # 800170d0 <tickslock>
    char *pa = kalloc();
    80001836:	fffff097          	auipc	ra,0xfffff
    8000183a:	29e080e7          	jalr	670(ra) # 80000ad4 <kalloc>
    8000183e:	862a                	mv	a2,a0
    if(pa == 0)
    80001840:	c131                	beqz	a0,80001884 <proc_mapstacks+0x86>
    uint64 va = KSTACK((int) (p - proc));
    80001842:	416485b3          	sub	a1,s1,s6
    80001846:	858d                	srai	a1,a1,0x3
    80001848:	000ab783          	ld	a5,0(s5)
    8000184c:	02f585b3          	mul	a1,a1,a5
    80001850:	2585                	addiw	a1,a1,1
    80001852:	00d5959b          	slliw	a1,a1,0xd
    kvmmap(kpgtbl, va, (uint64)pa, PGSIZE, PTE_R | PTE_W);
    80001856:	4719                	li	a4,6
    80001858:	6685                	lui	a3,0x1
    8000185a:	40b905b3          	sub	a1,s2,a1
    8000185e:	854e                	mv	a0,s3
    80001860:	00000097          	auipc	ra,0x0
    80001864:	8ae080e7          	jalr	-1874(ra) # 8000110e <kvmmap>
  for(p = proc; p < &proc[NPROC]; p++) {
    80001868:	16848493          	addi	s1,s1,360
    8000186c:	fd4495e3          	bne	s1,s4,80001836 <proc_mapstacks+0x38>
  }
}
    80001870:	70e2                	ld	ra,56(sp)
    80001872:	7442                	ld	s0,48(sp)
    80001874:	74a2                	ld	s1,40(sp)
    80001876:	7902                	ld	s2,32(sp)
    80001878:	69e2                	ld	s3,24(sp)
    8000187a:	6a42                	ld	s4,16(sp)
    8000187c:	6aa2                	ld	s5,8(sp)
    8000187e:	6b02                	ld	s6,0(sp)
    80001880:	6121                	addi	sp,sp,64
    80001882:	8082                	ret
      panic("kalloc");
    80001884:	00007517          	auipc	a0,0x7
    80001888:	95450513          	addi	a0,a0,-1708 # 800081d8 <digits+0x198>
    8000188c:	fffff097          	auipc	ra,0xfffff
    80001890:	cae080e7          	jalr	-850(ra) # 8000053a <panic>

0000000080001894 <procinit>:

// initialize the proc table at boot time.
void
procinit(void)
{
    80001894:	7139                	addi	sp,sp,-64
    80001896:	fc06                	sd	ra,56(sp)
    80001898:	f822                	sd	s0,48(sp)
    8000189a:	f426                	sd	s1,40(sp)
    8000189c:	f04a                	sd	s2,32(sp)
    8000189e:	ec4e                	sd	s3,24(sp)
    800018a0:	e852                	sd	s4,16(sp)
    800018a2:	e456                	sd	s5,8(sp)
    800018a4:	e05a                	sd	s6,0(sp)
    800018a6:	0080                	addi	s0,sp,64
  struct proc *p;
  
  initlock(&pid_lock, "nextpid");
    800018a8:	00007597          	auipc	a1,0x7
    800018ac:	93858593          	addi	a1,a1,-1736 # 800081e0 <digits+0x1a0>
    800018b0:	00010517          	auipc	a0,0x10
    800018b4:	9f050513          	addi	a0,a0,-1552 # 800112a0 <pid_lock>
    800018b8:	fffff097          	auipc	ra,0xfffff
    800018bc:	262080e7          	jalr	610(ra) # 80000b1a <initlock>
  initlock(&wait_lock, "wait_lock");
    800018c0:	00007597          	auipc	a1,0x7
    800018c4:	92858593          	addi	a1,a1,-1752 # 800081e8 <digits+0x1a8>
    800018c8:	00010517          	auipc	a0,0x10
    800018cc:	9f050513          	addi	a0,a0,-1552 # 800112b8 <wait_lock>
    800018d0:	fffff097          	auipc	ra,0xfffff
    800018d4:	24a080e7          	jalr	586(ra) # 80000b1a <initlock>
  for(p = proc; p < &proc[NPROC]; p++) {
    800018d8:	00010497          	auipc	s1,0x10
    800018dc:	df848493          	addi	s1,s1,-520 # 800116d0 <proc>
      initlock(&p->lock, "proc");
    800018e0:	00007b17          	auipc	s6,0x7
    800018e4:	918b0b13          	addi	s6,s6,-1768 # 800081f8 <digits+0x1b8>
      p->kstack = KSTACK((int) (p - proc));
    800018e8:	8aa6                	mv	s5,s1
    800018ea:	00006a17          	auipc	s4,0x6
    800018ee:	716a0a13          	addi	s4,s4,1814 # 80008000 <etext>
    800018f2:	04000937          	lui	s2,0x4000
    800018f6:	197d                	addi	s2,s2,-1 # 3ffffff <_entry-0x7c000001>
    800018f8:	0932                	slli	s2,s2,0xc
  for(p = proc; p < &proc[NPROC]; p++) {
    800018fa:	00015997          	auipc	s3,0x15
    800018fe:	7d698993          	addi	s3,s3,2006 # 800170d0 <tickslock>
      initlock(&p->lock, "proc");
    80001902:	85da                	mv	a1,s6
    80001904:	8526                	mv	a0,s1
    80001906:	fffff097          	auipc	ra,0xfffff
    8000190a:	214080e7          	jalr	532(ra) # 80000b1a <initlock>
      p->kstack = KSTACK((int) (p - proc));
    8000190e:	415487b3          	sub	a5,s1,s5
    80001912:	878d                	srai	a5,a5,0x3
    80001914:	000a3703          	ld	a4,0(s4)
    80001918:	02e787b3          	mul	a5,a5,a4
    8000191c:	2785                	addiw	a5,a5,1
    8000191e:	00d7979b          	slliw	a5,a5,0xd
    80001922:	40f907b3          	sub	a5,s2,a5
    80001926:	e0bc                	sd	a5,64(s1)
  for(p = proc; p < &proc[NPROC]; p++) {
    80001928:	16848493          	addi	s1,s1,360
    8000192c:	fd349be3          	bne	s1,s3,80001902 <procinit+0x6e>
  }
}
    80001930:	70e2                	ld	ra,56(sp)
    80001932:	7442                	ld	s0,48(sp)
    80001934:	74a2                	ld	s1,40(sp)
    80001936:	7902                	ld	s2,32(sp)
    80001938:	69e2                	ld	s3,24(sp)
    8000193a:	6a42                	ld	s4,16(sp)
    8000193c:	6aa2                	ld	s5,8(sp)
    8000193e:	6b02                	ld	s6,0(sp)
    80001940:	6121                	addi	sp,sp,64
    80001942:	8082                	ret

0000000080001944 <cpuid>:
// Must be called with interrupts disabled,
// to prevent race with process being moved
// to a different CPU.
int
cpuid()
{
    80001944:	1141                	addi	sp,sp,-16
    80001946:	e422                	sd	s0,8(sp)
    80001948:	0800                	addi	s0,sp,16
  asm volatile("mv %0, tp" : "=r" (x) );
    8000194a:	8512                	mv	a0,tp
  int id = r_tp();
  return id;
}
    8000194c:	2501                	sext.w	a0,a0
    8000194e:	6422                	ld	s0,8(sp)
    80001950:	0141                	addi	sp,sp,16
    80001952:	8082                	ret

0000000080001954 <mycpu>:

// Return this CPU's cpu struct.
// Interrupts must be disabled.
struct cpu*
mycpu(void) {
    80001954:	1141                	addi	sp,sp,-16
    80001956:	e422                	sd	s0,8(sp)
    80001958:	0800                	addi	s0,sp,16
    8000195a:	8792                	mv	a5,tp
  int id = cpuid();
  struct cpu *c = &cpus[id];
    8000195c:	2781                	sext.w	a5,a5
    8000195e:	079e                	slli	a5,a5,0x7
  return c;
}
    80001960:	00010517          	auipc	a0,0x10
    80001964:	97050513          	addi	a0,a0,-1680 # 800112d0 <cpus>
    80001968:	953e                	add	a0,a0,a5
    8000196a:	6422                	ld	s0,8(sp)
    8000196c:	0141                	addi	sp,sp,16
    8000196e:	8082                	ret

0000000080001970 <myproc>:

// Return the current struct proc *, or zero if none.
struct proc*
myproc(void) {
    80001970:	1101                	addi	sp,sp,-32
    80001972:	ec06                	sd	ra,24(sp)
    80001974:	e822                	sd	s0,16(sp)
    80001976:	e426                	sd	s1,8(sp)
    80001978:	1000                	addi	s0,sp,32
  push_off();
    8000197a:	fffff097          	auipc	ra,0xfffff
    8000197e:	1e4080e7          	jalr	484(ra) # 80000b5e <push_off>
    80001982:	8792                	mv	a5,tp
  struct cpu *c = mycpu();
  struct proc *p = c->proc;
    80001984:	2781                	sext.w	a5,a5
    80001986:	079e                	slli	a5,a5,0x7
    80001988:	00010717          	auipc	a4,0x10
    8000198c:	91870713          	addi	a4,a4,-1768 # 800112a0 <pid_lock>
    80001990:	97ba                	add	a5,a5,a4
    80001992:	7b84                	ld	s1,48(a5)
  pop_off();
    80001994:	fffff097          	auipc	ra,0xfffff
    80001998:	26a080e7          	jalr	618(ra) # 80000bfe <pop_off>
  return p;
}
    8000199c:	8526                	mv	a0,s1
    8000199e:	60e2                	ld	ra,24(sp)
    800019a0:	6442                	ld	s0,16(sp)
    800019a2:	64a2                	ld	s1,8(sp)
    800019a4:	6105                	addi	sp,sp,32
    800019a6:	8082                	ret

00000000800019a8 <forkret>:

// A fork child's very first scheduling by scheduler()
// will swtch to forkret.
void
forkret(void)
{
    800019a8:	1141                	addi	sp,sp,-16
    800019aa:	e406                	sd	ra,8(sp)
    800019ac:	e022                	sd	s0,0(sp)
    800019ae:	0800                	addi	s0,sp,16
  static int first = 1;

  // Still holding p->lock from scheduler.
  release(&myproc()->lock);
    800019b0:	00000097          	auipc	ra,0x0
    800019b4:	fc0080e7          	jalr	-64(ra) # 80001970 <myproc>
    800019b8:	fffff097          	auipc	ra,0xfffff
    800019bc:	2a6080e7          	jalr	678(ra) # 80000c5e <release>

  if (first) {
    800019c0:	00007797          	auipc	a5,0x7
    800019c4:	e507a783          	lw	a5,-432(a5) # 80008810 <first.1>
    800019c8:	eb89                	bnez	a5,800019da <forkret+0x32>
    // be run from main().
    first = 0;
    fsinit(ROOTDEV);
  }

  usertrapret();
    800019ca:	00001097          	auipc	ra,0x1
    800019ce:	c14080e7          	jalr	-1004(ra) # 800025de <usertrapret>
}
    800019d2:	60a2                	ld	ra,8(sp)
    800019d4:	6402                	ld	s0,0(sp)
    800019d6:	0141                	addi	sp,sp,16
    800019d8:	8082                	ret
    first = 0;
    800019da:	00007797          	auipc	a5,0x7
    800019de:	e207ab23          	sw	zero,-458(a5) # 80008810 <first.1>
    fsinit(ROOTDEV);
    800019e2:	4505                	li	a0,1
    800019e4:	00002097          	auipc	ra,0x2
    800019e8:	93a080e7          	jalr	-1734(ra) # 8000331e <fsinit>
    800019ec:	bff9                	j	800019ca <forkret+0x22>

00000000800019ee <allocpid>:
allocpid() {
    800019ee:	1101                	addi	sp,sp,-32
    800019f0:	ec06                	sd	ra,24(sp)
    800019f2:	e822                	sd	s0,16(sp)
    800019f4:	e426                	sd	s1,8(sp)
    800019f6:	e04a                	sd	s2,0(sp)
    800019f8:	1000                	addi	s0,sp,32
  acquire(&pid_lock);
    800019fa:	00010917          	auipc	s2,0x10
    800019fe:	8a690913          	addi	s2,s2,-1882 # 800112a0 <pid_lock>
    80001a02:	854a                	mv	a0,s2
    80001a04:	fffff097          	auipc	ra,0xfffff
    80001a08:	1a6080e7          	jalr	422(ra) # 80000baa <acquire>
  pid = nextpid;
    80001a0c:	00007797          	auipc	a5,0x7
    80001a10:	e0878793          	addi	a5,a5,-504 # 80008814 <nextpid>
    80001a14:	4384                	lw	s1,0(a5)
  nextpid = nextpid + 1;
    80001a16:	0014871b          	addiw	a4,s1,1
    80001a1a:	c398                	sw	a4,0(a5)
  release(&pid_lock);
    80001a1c:	854a                	mv	a0,s2
    80001a1e:	fffff097          	auipc	ra,0xfffff
    80001a22:	240080e7          	jalr	576(ra) # 80000c5e <release>
}
    80001a26:	8526                	mv	a0,s1
    80001a28:	60e2                	ld	ra,24(sp)
    80001a2a:	6442                	ld	s0,16(sp)
    80001a2c:	64a2                	ld	s1,8(sp)
    80001a2e:	6902                	ld	s2,0(sp)
    80001a30:	6105                	addi	sp,sp,32
    80001a32:	8082                	ret

0000000080001a34 <proc_pagetable>:
{
    80001a34:	1101                	addi	sp,sp,-32
    80001a36:	ec06                	sd	ra,24(sp)
    80001a38:	e822                	sd	s0,16(sp)
    80001a3a:	e426                	sd	s1,8(sp)
    80001a3c:	e04a                	sd	s2,0(sp)
    80001a3e:	1000                	addi	s0,sp,32
    80001a40:	892a                	mv	s2,a0
  pagetable = uvmcreate();
    80001a42:	00000097          	auipc	ra,0x0
    80001a46:	8b6080e7          	jalr	-1866(ra) # 800012f8 <uvmcreate>
    80001a4a:	84aa                	mv	s1,a0
  if(pagetable == 0)
    80001a4c:	c121                	beqz	a0,80001a8c <proc_pagetable+0x58>
  if(mappages(pagetable, TRAMPOLINE, PGSIZE,
    80001a4e:	4729                	li	a4,10
    80001a50:	00005697          	auipc	a3,0x5
    80001a54:	5b068693          	addi	a3,a3,1456 # 80007000 <_trampoline>
    80001a58:	6605                	lui	a2,0x1
    80001a5a:	040005b7          	lui	a1,0x4000
    80001a5e:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    80001a60:	05b2                	slli	a1,a1,0xc
    80001a62:	fffff097          	auipc	ra,0xfffff
    80001a66:	60c080e7          	jalr	1548(ra) # 8000106e <mappages>
    80001a6a:	02054863          	bltz	a0,80001a9a <proc_pagetable+0x66>
  if(mappages(pagetable, TRAPFRAME, PGSIZE,
    80001a6e:	4719                	li	a4,6
    80001a70:	05893683          	ld	a3,88(s2)
    80001a74:	6605                	lui	a2,0x1
    80001a76:	020005b7          	lui	a1,0x2000
    80001a7a:	15fd                	addi	a1,a1,-1 # 1ffffff <_entry-0x7e000001>
    80001a7c:	05b6                	slli	a1,a1,0xd
    80001a7e:	8526                	mv	a0,s1
    80001a80:	fffff097          	auipc	ra,0xfffff
    80001a84:	5ee080e7          	jalr	1518(ra) # 8000106e <mappages>
    80001a88:	02054163          	bltz	a0,80001aaa <proc_pagetable+0x76>
}
    80001a8c:	8526                	mv	a0,s1
    80001a8e:	60e2                	ld	ra,24(sp)
    80001a90:	6442                	ld	s0,16(sp)
    80001a92:	64a2                	ld	s1,8(sp)
    80001a94:	6902                	ld	s2,0(sp)
    80001a96:	6105                	addi	sp,sp,32
    80001a98:	8082                	ret
    uvmfree(pagetable, 0);
    80001a9a:	4581                	li	a1,0
    80001a9c:	8526                	mv	a0,s1
    80001a9e:	00000097          	auipc	ra,0x0
    80001aa2:	a58080e7          	jalr	-1448(ra) # 800014f6 <uvmfree>
    return 0;
    80001aa6:	4481                	li	s1,0
    80001aa8:	b7d5                	j	80001a8c <proc_pagetable+0x58>
    uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    80001aaa:	4681                	li	a3,0
    80001aac:	4605                	li	a2,1
    80001aae:	040005b7          	lui	a1,0x4000
    80001ab2:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    80001ab4:	05b2                	slli	a1,a1,0xc
    80001ab6:	8526                	mv	a0,s1
    80001ab8:	fffff097          	auipc	ra,0xfffff
    80001abc:	77c080e7          	jalr	1916(ra) # 80001234 <uvmunmap>
    uvmfree(pagetable, 0);
    80001ac0:	4581                	li	a1,0
    80001ac2:	8526                	mv	a0,s1
    80001ac4:	00000097          	auipc	ra,0x0
    80001ac8:	a32080e7          	jalr	-1486(ra) # 800014f6 <uvmfree>
    return 0;
    80001acc:	4481                	li	s1,0
    80001ace:	bf7d                	j	80001a8c <proc_pagetable+0x58>

0000000080001ad0 <proc_freepagetable>:
{
    80001ad0:	1101                	addi	sp,sp,-32
    80001ad2:	ec06                	sd	ra,24(sp)
    80001ad4:	e822                	sd	s0,16(sp)
    80001ad6:	e426                	sd	s1,8(sp)
    80001ad8:	e04a                	sd	s2,0(sp)
    80001ada:	1000                	addi	s0,sp,32
    80001adc:	84aa                	mv	s1,a0
    80001ade:	892e                	mv	s2,a1
  uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    80001ae0:	4681                	li	a3,0
    80001ae2:	4605                	li	a2,1
    80001ae4:	040005b7          	lui	a1,0x4000
    80001ae8:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    80001aea:	05b2                	slli	a1,a1,0xc
    80001aec:	fffff097          	auipc	ra,0xfffff
    80001af0:	748080e7          	jalr	1864(ra) # 80001234 <uvmunmap>
  uvmunmap(pagetable, TRAPFRAME, 1, 0);
    80001af4:	4681                	li	a3,0
    80001af6:	4605                	li	a2,1
    80001af8:	020005b7          	lui	a1,0x2000
    80001afc:	15fd                	addi	a1,a1,-1 # 1ffffff <_entry-0x7e000001>
    80001afe:	05b6                	slli	a1,a1,0xd
    80001b00:	8526                	mv	a0,s1
    80001b02:	fffff097          	auipc	ra,0xfffff
    80001b06:	732080e7          	jalr	1842(ra) # 80001234 <uvmunmap>
  uvmfree(pagetable, sz);
    80001b0a:	85ca                	mv	a1,s2
    80001b0c:	8526                	mv	a0,s1
    80001b0e:	00000097          	auipc	ra,0x0
    80001b12:	9e8080e7          	jalr	-1560(ra) # 800014f6 <uvmfree>
}
    80001b16:	60e2                	ld	ra,24(sp)
    80001b18:	6442                	ld	s0,16(sp)
    80001b1a:	64a2                	ld	s1,8(sp)
    80001b1c:	6902                	ld	s2,0(sp)
    80001b1e:	6105                	addi	sp,sp,32
    80001b20:	8082                	ret

0000000080001b22 <freeproc>:
{
    80001b22:	1101                	addi	sp,sp,-32
    80001b24:	ec06                	sd	ra,24(sp)
    80001b26:	e822                	sd	s0,16(sp)
    80001b28:	e426                	sd	s1,8(sp)
    80001b2a:	1000                	addi	s0,sp,32
    80001b2c:	84aa                	mv	s1,a0
  if(p->trapframe)
    80001b2e:	6d28                	ld	a0,88(a0)
    80001b30:	c509                	beqz	a0,80001b3a <freeproc+0x18>
    kfree((void*)p->trapframe);
    80001b32:	fffff097          	auipc	ra,0xfffff
    80001b36:	eb0080e7          	jalr	-336(ra) # 800009e2 <kfree>
  p->trapframe = 0;
    80001b3a:	0404bc23          	sd	zero,88(s1)
  if(p->pagetable)
    80001b3e:	68a8                	ld	a0,80(s1)
    80001b40:	c511                	beqz	a0,80001b4c <freeproc+0x2a>
    proc_freepagetable(p->pagetable, p->sz);
    80001b42:	64ac                	ld	a1,72(s1)
    80001b44:	00000097          	auipc	ra,0x0
    80001b48:	f8c080e7          	jalr	-116(ra) # 80001ad0 <proc_freepagetable>
  p->pagetable = 0;
    80001b4c:	0404b823          	sd	zero,80(s1)
  p->sz = 0;
    80001b50:	0404b423          	sd	zero,72(s1)
  p->pid = 0;
    80001b54:	0204a823          	sw	zero,48(s1)
  p->parent = 0;
    80001b58:	0204bc23          	sd	zero,56(s1)
  p->name[0] = 0;
    80001b5c:	14048c23          	sb	zero,344(s1)
  p->chan = 0;
    80001b60:	0204b023          	sd	zero,32(s1)
  p->killed = 0;
    80001b64:	0204a423          	sw	zero,40(s1)
  p->xstate = 0;
    80001b68:	0204a623          	sw	zero,44(s1)
  p->state = UNUSED;
    80001b6c:	0004ac23          	sw	zero,24(s1)
}
    80001b70:	60e2                	ld	ra,24(sp)
    80001b72:	6442                	ld	s0,16(sp)
    80001b74:	64a2                	ld	s1,8(sp)
    80001b76:	6105                	addi	sp,sp,32
    80001b78:	8082                	ret

0000000080001b7a <allocproc>:
{
    80001b7a:	1101                	addi	sp,sp,-32
    80001b7c:	ec06                	sd	ra,24(sp)
    80001b7e:	e822                	sd	s0,16(sp)
    80001b80:	e426                	sd	s1,8(sp)
    80001b82:	e04a                	sd	s2,0(sp)
    80001b84:	1000                	addi	s0,sp,32
  for(p = proc; p < &proc[NPROC]; p++) {
    80001b86:	00010497          	auipc	s1,0x10
    80001b8a:	b4a48493          	addi	s1,s1,-1206 # 800116d0 <proc>
    80001b8e:	00015917          	auipc	s2,0x15
    80001b92:	54290913          	addi	s2,s2,1346 # 800170d0 <tickslock>
    acquire(&p->lock);
    80001b96:	8526                	mv	a0,s1
    80001b98:	fffff097          	auipc	ra,0xfffff
    80001b9c:	012080e7          	jalr	18(ra) # 80000baa <acquire>
    if(p->state == UNUSED) {
    80001ba0:	4c9c                	lw	a5,24(s1)
    80001ba2:	cf81                	beqz	a5,80001bba <allocproc+0x40>
      release(&p->lock);
    80001ba4:	8526                	mv	a0,s1
    80001ba6:	fffff097          	auipc	ra,0xfffff
    80001baa:	0b8080e7          	jalr	184(ra) # 80000c5e <release>
  for(p = proc; p < &proc[NPROC]; p++) {
    80001bae:	16848493          	addi	s1,s1,360
    80001bb2:	ff2492e3          	bne	s1,s2,80001b96 <allocproc+0x1c>
  return 0;
    80001bb6:	4481                	li	s1,0
    80001bb8:	a889                	j	80001c0a <allocproc+0x90>
  p->pid = allocpid();
    80001bba:	00000097          	auipc	ra,0x0
    80001bbe:	e34080e7          	jalr	-460(ra) # 800019ee <allocpid>
    80001bc2:	d888                	sw	a0,48(s1)
  p->state = USED;
    80001bc4:	4785                	li	a5,1
    80001bc6:	cc9c                	sw	a5,24(s1)
  if((p->trapframe = (struct trapframe *)kalloc()) == 0){
    80001bc8:	fffff097          	auipc	ra,0xfffff
    80001bcc:	f0c080e7          	jalr	-244(ra) # 80000ad4 <kalloc>
    80001bd0:	892a                	mv	s2,a0
    80001bd2:	eca8                	sd	a0,88(s1)
    80001bd4:	c131                	beqz	a0,80001c18 <allocproc+0x9e>
  p->pagetable = proc_pagetable(p);
    80001bd6:	8526                	mv	a0,s1
    80001bd8:	00000097          	auipc	ra,0x0
    80001bdc:	e5c080e7          	jalr	-420(ra) # 80001a34 <proc_pagetable>
    80001be0:	892a                	mv	s2,a0
    80001be2:	e8a8                	sd	a0,80(s1)
  if(p->pagetable == 0){
    80001be4:	c531                	beqz	a0,80001c30 <allocproc+0xb6>
  memset(&p->context, 0, sizeof(p->context));
    80001be6:	07000613          	li	a2,112
    80001bea:	4581                	li	a1,0
    80001bec:	06048513          	addi	a0,s1,96
    80001bf0:	fffff097          	auipc	ra,0xfffff
    80001bf4:	0b6080e7          	jalr	182(ra) # 80000ca6 <memset>
  p->context.ra = (uint64)forkret;
    80001bf8:	00000797          	auipc	a5,0x0
    80001bfc:	db078793          	addi	a5,a5,-592 # 800019a8 <forkret>
    80001c00:	f0bc                	sd	a5,96(s1)
  p->context.sp = p->kstack + PGSIZE;
    80001c02:	60bc                	ld	a5,64(s1)
    80001c04:	6705                	lui	a4,0x1
    80001c06:	97ba                	add	a5,a5,a4
    80001c08:	f4bc                	sd	a5,104(s1)
}
    80001c0a:	8526                	mv	a0,s1
    80001c0c:	60e2                	ld	ra,24(sp)
    80001c0e:	6442                	ld	s0,16(sp)
    80001c10:	64a2                	ld	s1,8(sp)
    80001c12:	6902                	ld	s2,0(sp)
    80001c14:	6105                	addi	sp,sp,32
    80001c16:	8082                	ret
    freeproc(p);
    80001c18:	8526                	mv	a0,s1
    80001c1a:	00000097          	auipc	ra,0x0
    80001c1e:	f08080e7          	jalr	-248(ra) # 80001b22 <freeproc>
    release(&p->lock);
    80001c22:	8526                	mv	a0,s1
    80001c24:	fffff097          	auipc	ra,0xfffff
    80001c28:	03a080e7          	jalr	58(ra) # 80000c5e <release>
    return 0;
    80001c2c:	84ca                	mv	s1,s2
    80001c2e:	bff1                	j	80001c0a <allocproc+0x90>
    freeproc(p);
    80001c30:	8526                	mv	a0,s1
    80001c32:	00000097          	auipc	ra,0x0
    80001c36:	ef0080e7          	jalr	-272(ra) # 80001b22 <freeproc>
    release(&p->lock);
    80001c3a:	8526                	mv	a0,s1
    80001c3c:	fffff097          	auipc	ra,0xfffff
    80001c40:	022080e7          	jalr	34(ra) # 80000c5e <release>
    return 0;
    80001c44:	84ca                	mv	s1,s2
    80001c46:	b7d1                	j	80001c0a <allocproc+0x90>

0000000080001c48 <userinit>:
{
    80001c48:	1101                	addi	sp,sp,-32
    80001c4a:	ec06                	sd	ra,24(sp)
    80001c4c:	e822                	sd	s0,16(sp)
    80001c4e:	e426                	sd	s1,8(sp)
    80001c50:	1000                	addi	s0,sp,32
  p = allocproc();
    80001c52:	00000097          	auipc	ra,0x0
    80001c56:	f28080e7          	jalr	-216(ra) # 80001b7a <allocproc>
    80001c5a:	84aa                	mv	s1,a0
  initproc = p;
    80001c5c:	00007797          	auipc	a5,0x7
    80001c60:	3ca7b623          	sd	a0,972(a5) # 80009028 <initproc>
  uvminit(p->pagetable, initcode, sizeof(initcode));
    80001c64:	03400613          	li	a2,52
    80001c68:	00007597          	auipc	a1,0x7
    80001c6c:	bb858593          	addi	a1,a1,-1096 # 80008820 <initcode>
    80001c70:	6928                	ld	a0,80(a0)
    80001c72:	fffff097          	auipc	ra,0xfffff
    80001c76:	6b4080e7          	jalr	1716(ra) # 80001326 <uvminit>
  p->sz = PGSIZE;
    80001c7a:	6785                	lui	a5,0x1
    80001c7c:	e4bc                	sd	a5,72(s1)
  p->trapframe->epc = 0;      // user program counter
    80001c7e:	6cb8                	ld	a4,88(s1)
    80001c80:	00073c23          	sd	zero,24(a4) # 1018 <_entry-0x7fffefe8>
  p->trapframe->sp = PGSIZE;  // user stack pointer
    80001c84:	6cb8                	ld	a4,88(s1)
    80001c86:	fb1c                	sd	a5,48(a4)
  safestrcpy(p->name, "initcode", sizeof(p->name));
    80001c88:	4641                	li	a2,16
    80001c8a:	00006597          	auipc	a1,0x6
    80001c8e:	57658593          	addi	a1,a1,1398 # 80008200 <digits+0x1c0>
    80001c92:	15848513          	addi	a0,s1,344
    80001c96:	fffff097          	auipc	ra,0xfffff
    80001c9a:	15a080e7          	jalr	346(ra) # 80000df0 <safestrcpy>
  p->cwd = namei("/");
    80001c9e:	00006517          	auipc	a0,0x6
    80001ca2:	57250513          	addi	a0,a0,1394 # 80008210 <digits+0x1d0>
    80001ca6:	00002097          	auipc	ra,0x2
    80001caa:	0ae080e7          	jalr	174(ra) # 80003d54 <namei>
    80001cae:	14a4b823          	sd	a0,336(s1)
  p->state = RUNNABLE;
    80001cb2:	478d                	li	a5,3
    80001cb4:	cc9c                	sw	a5,24(s1)
  release(&p->lock);
    80001cb6:	8526                	mv	a0,s1
    80001cb8:	fffff097          	auipc	ra,0xfffff
    80001cbc:	fa6080e7          	jalr	-90(ra) # 80000c5e <release>
}
    80001cc0:	60e2                	ld	ra,24(sp)
    80001cc2:	6442                	ld	s0,16(sp)
    80001cc4:	64a2                	ld	s1,8(sp)
    80001cc6:	6105                	addi	sp,sp,32
    80001cc8:	8082                	ret

0000000080001cca <growproc>:
{
    80001cca:	1101                	addi	sp,sp,-32
    80001ccc:	ec06                	sd	ra,24(sp)
    80001cce:	e822                	sd	s0,16(sp)
    80001cd0:	e426                	sd	s1,8(sp)
    80001cd2:	e04a                	sd	s2,0(sp)
    80001cd4:	1000                	addi	s0,sp,32
    80001cd6:	84aa                	mv	s1,a0
  struct proc *p = myproc();
    80001cd8:	00000097          	auipc	ra,0x0
    80001cdc:	c98080e7          	jalr	-872(ra) # 80001970 <myproc>
    80001ce0:	892a                	mv	s2,a0
  sz = p->sz;
    80001ce2:	652c                	ld	a1,72(a0)
    80001ce4:	0005879b          	sext.w	a5,a1
  if(n > 0){
    80001ce8:	00904f63          	bgtz	s1,80001d06 <growproc+0x3c>
  } else if(n < 0){
    80001cec:	0204cd63          	bltz	s1,80001d26 <growproc+0x5c>
  p->sz = sz;
    80001cf0:	1782                	slli	a5,a5,0x20
    80001cf2:	9381                	srli	a5,a5,0x20
    80001cf4:	04f93423          	sd	a5,72(s2)
  return 0;
    80001cf8:	4501                	li	a0,0
}
    80001cfa:	60e2                	ld	ra,24(sp)
    80001cfc:	6442                	ld	s0,16(sp)
    80001cfe:	64a2                	ld	s1,8(sp)
    80001d00:	6902                	ld	s2,0(sp)
    80001d02:	6105                	addi	sp,sp,32
    80001d04:	8082                	ret
    if((sz = uvmalloc(p->pagetable, sz, sz + n)) == 0) {
    80001d06:	00f4863b          	addw	a2,s1,a5
    80001d0a:	1602                	slli	a2,a2,0x20
    80001d0c:	9201                	srli	a2,a2,0x20
    80001d0e:	1582                	slli	a1,a1,0x20
    80001d10:	9181                	srli	a1,a1,0x20
    80001d12:	6928                	ld	a0,80(a0)
    80001d14:	fffff097          	auipc	ra,0xfffff
    80001d18:	6cc080e7          	jalr	1740(ra) # 800013e0 <uvmalloc>
    80001d1c:	0005079b          	sext.w	a5,a0
    80001d20:	fbe1                	bnez	a5,80001cf0 <growproc+0x26>
      return -1;
    80001d22:	557d                	li	a0,-1
    80001d24:	bfd9                	j	80001cfa <growproc+0x30>
    sz = uvmdealloc(p->pagetable, sz, sz + n);
    80001d26:	00f4863b          	addw	a2,s1,a5
    80001d2a:	1602                	slli	a2,a2,0x20
    80001d2c:	9201                	srli	a2,a2,0x20
    80001d2e:	1582                	slli	a1,a1,0x20
    80001d30:	9181                	srli	a1,a1,0x20
    80001d32:	6928                	ld	a0,80(a0)
    80001d34:	fffff097          	auipc	ra,0xfffff
    80001d38:	664080e7          	jalr	1636(ra) # 80001398 <uvmdealloc>
    80001d3c:	0005079b          	sext.w	a5,a0
    80001d40:	bf45                	j	80001cf0 <growproc+0x26>

0000000080001d42 <fork>:
{
    80001d42:	7139                	addi	sp,sp,-64
    80001d44:	fc06                	sd	ra,56(sp)
    80001d46:	f822                	sd	s0,48(sp)
    80001d48:	f426                	sd	s1,40(sp)
    80001d4a:	f04a                	sd	s2,32(sp)
    80001d4c:	ec4e                	sd	s3,24(sp)
    80001d4e:	e852                	sd	s4,16(sp)
    80001d50:	e456                	sd	s5,8(sp)
    80001d52:	0080                	addi	s0,sp,64
  struct proc *p = myproc();
    80001d54:	00000097          	auipc	ra,0x0
    80001d58:	c1c080e7          	jalr	-996(ra) # 80001970 <myproc>
    80001d5c:	8aaa                	mv	s5,a0
  if((np = allocproc()) == 0){
    80001d5e:	00000097          	auipc	ra,0x0
    80001d62:	e1c080e7          	jalr	-484(ra) # 80001b7a <allocproc>
    80001d66:	10050c63          	beqz	a0,80001e7e <fork+0x13c>
    80001d6a:	8a2a                	mv	s4,a0
  if(uvmcopy(p->pagetable, np->pagetable, p->sz) < 0){
    80001d6c:	048ab603          	ld	a2,72(s5)
    80001d70:	692c                	ld	a1,80(a0)
    80001d72:	050ab503          	ld	a0,80(s5)
    80001d76:	fffff097          	auipc	ra,0xfffff
    80001d7a:	7ba080e7          	jalr	1978(ra) # 80001530 <uvmcopy>
    80001d7e:	04054863          	bltz	a0,80001dce <fork+0x8c>
  np->sz = p->sz;
    80001d82:	048ab783          	ld	a5,72(s5)
    80001d86:	04fa3423          	sd	a5,72(s4)
  *(np->trapframe) = *(p->trapframe);
    80001d8a:	058ab683          	ld	a3,88(s5)
    80001d8e:	87b6                	mv	a5,a3
    80001d90:	058a3703          	ld	a4,88(s4)
    80001d94:	12068693          	addi	a3,a3,288
    80001d98:	0007b803          	ld	a6,0(a5) # 1000 <_entry-0x7ffff000>
    80001d9c:	6788                	ld	a0,8(a5)
    80001d9e:	6b8c                	ld	a1,16(a5)
    80001da0:	6f90                	ld	a2,24(a5)
    80001da2:	01073023          	sd	a6,0(a4)
    80001da6:	e708                	sd	a0,8(a4)
    80001da8:	eb0c                	sd	a1,16(a4)
    80001daa:	ef10                	sd	a2,24(a4)
    80001dac:	02078793          	addi	a5,a5,32
    80001db0:	02070713          	addi	a4,a4,32
    80001db4:	fed792e3          	bne	a5,a3,80001d98 <fork+0x56>
  np->trapframe->a0 = 0;
    80001db8:	058a3783          	ld	a5,88(s4)
    80001dbc:	0607b823          	sd	zero,112(a5)
  for(i = 0; i < NOFILE; i++)
    80001dc0:	0d0a8493          	addi	s1,s5,208
    80001dc4:	0d0a0913          	addi	s2,s4,208
    80001dc8:	150a8993          	addi	s3,s5,336
    80001dcc:	a00d                	j	80001dee <fork+0xac>
    freeproc(np);
    80001dce:	8552                	mv	a0,s4
    80001dd0:	00000097          	auipc	ra,0x0
    80001dd4:	d52080e7          	jalr	-686(ra) # 80001b22 <freeproc>
    release(&np->lock);
    80001dd8:	8552                	mv	a0,s4
    80001dda:	fffff097          	auipc	ra,0xfffff
    80001dde:	e84080e7          	jalr	-380(ra) # 80000c5e <release>
    return -1;
    80001de2:	597d                	li	s2,-1
    80001de4:	a059                	j	80001e6a <fork+0x128>
  for(i = 0; i < NOFILE; i++)
    80001de6:	04a1                	addi	s1,s1,8
    80001de8:	0921                	addi	s2,s2,8
    80001dea:	01348b63          	beq	s1,s3,80001e00 <fork+0xbe>
    if(p->ofile[i])
    80001dee:	6088                	ld	a0,0(s1)
    80001df0:	d97d                	beqz	a0,80001de6 <fork+0xa4>
      np->ofile[i] = filedup(p->ofile[i]);
    80001df2:	00002097          	auipc	ra,0x2
    80001df6:	5f8080e7          	jalr	1528(ra) # 800043ea <filedup>
    80001dfa:	00a93023          	sd	a0,0(s2)
    80001dfe:	b7e5                	j	80001de6 <fork+0xa4>
  np->cwd = idup(p->cwd);
    80001e00:	150ab503          	ld	a0,336(s5)
    80001e04:	00001097          	auipc	ra,0x1
    80001e08:	756080e7          	jalr	1878(ra) # 8000355a <idup>
    80001e0c:	14aa3823          	sd	a0,336(s4)
  safestrcpy(np->name, p->name, sizeof(p->name));
    80001e10:	4641                	li	a2,16
    80001e12:	158a8593          	addi	a1,s5,344
    80001e16:	158a0513          	addi	a0,s4,344
    80001e1a:	fffff097          	auipc	ra,0xfffff
    80001e1e:	fd6080e7          	jalr	-42(ra) # 80000df0 <safestrcpy>
  pid = np->pid;
    80001e22:	030a2903          	lw	s2,48(s4)
  release(&np->lock);
    80001e26:	8552                	mv	a0,s4
    80001e28:	fffff097          	auipc	ra,0xfffff
    80001e2c:	e36080e7          	jalr	-458(ra) # 80000c5e <release>
  acquire(&wait_lock);
    80001e30:	0000f497          	auipc	s1,0xf
    80001e34:	48848493          	addi	s1,s1,1160 # 800112b8 <wait_lock>
    80001e38:	8526                	mv	a0,s1
    80001e3a:	fffff097          	auipc	ra,0xfffff
    80001e3e:	d70080e7          	jalr	-656(ra) # 80000baa <acquire>
  np->parent = p;
    80001e42:	035a3c23          	sd	s5,56(s4)
  release(&wait_lock);
    80001e46:	8526                	mv	a0,s1
    80001e48:	fffff097          	auipc	ra,0xfffff
    80001e4c:	e16080e7          	jalr	-490(ra) # 80000c5e <release>
  acquire(&np->lock);
    80001e50:	8552                	mv	a0,s4
    80001e52:	fffff097          	auipc	ra,0xfffff
    80001e56:	d58080e7          	jalr	-680(ra) # 80000baa <acquire>
  np->state = RUNNABLE;
    80001e5a:	478d                	li	a5,3
    80001e5c:	00fa2c23          	sw	a5,24(s4)
  release(&np->lock);
    80001e60:	8552                	mv	a0,s4
    80001e62:	fffff097          	auipc	ra,0xfffff
    80001e66:	dfc080e7          	jalr	-516(ra) # 80000c5e <release>
}
    80001e6a:	854a                	mv	a0,s2
    80001e6c:	70e2                	ld	ra,56(sp)
    80001e6e:	7442                	ld	s0,48(sp)
    80001e70:	74a2                	ld	s1,40(sp)
    80001e72:	7902                	ld	s2,32(sp)
    80001e74:	69e2                	ld	s3,24(sp)
    80001e76:	6a42                	ld	s4,16(sp)
    80001e78:	6aa2                	ld	s5,8(sp)
    80001e7a:	6121                	addi	sp,sp,64
    80001e7c:	8082                	ret
    return -1;
    80001e7e:	597d                	li	s2,-1
    80001e80:	b7ed                	j	80001e6a <fork+0x128>

0000000080001e82 <scheduler>:
{
    80001e82:	7139                	addi	sp,sp,-64
    80001e84:	fc06                	sd	ra,56(sp)
    80001e86:	f822                	sd	s0,48(sp)
    80001e88:	f426                	sd	s1,40(sp)
    80001e8a:	f04a                	sd	s2,32(sp)
    80001e8c:	ec4e                	sd	s3,24(sp)
    80001e8e:	e852                	sd	s4,16(sp)
    80001e90:	e456                	sd	s5,8(sp)
    80001e92:	e05a                	sd	s6,0(sp)
    80001e94:	0080                	addi	s0,sp,64
    80001e96:	8792                	mv	a5,tp
  int id = r_tp();
    80001e98:	2781                	sext.w	a5,a5
  c->proc = 0;
    80001e9a:	00779a93          	slli	s5,a5,0x7
    80001e9e:	0000f717          	auipc	a4,0xf
    80001ea2:	40270713          	addi	a4,a4,1026 # 800112a0 <pid_lock>
    80001ea6:	9756                	add	a4,a4,s5
    80001ea8:	02073823          	sd	zero,48(a4)
        swtch(&c->context, &p->context);
    80001eac:	0000f717          	auipc	a4,0xf
    80001eb0:	42c70713          	addi	a4,a4,1068 # 800112d8 <cpus+0x8>
    80001eb4:	9aba                	add	s5,s5,a4
      if(p->state == RUNNABLE) {
    80001eb6:	498d                	li	s3,3
        p->state = RUNNING;
    80001eb8:	4b11                	li	s6,4
        c->proc = p;
    80001eba:	079e                	slli	a5,a5,0x7
    80001ebc:	0000fa17          	auipc	s4,0xf
    80001ec0:	3e4a0a13          	addi	s4,s4,996 # 800112a0 <pid_lock>
    80001ec4:	9a3e                	add	s4,s4,a5
    for(p = proc; p < &proc[NPROC]; p++) {
    80001ec6:	00015917          	auipc	s2,0x15
    80001eca:	20a90913          	addi	s2,s2,522 # 800170d0 <tickslock>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80001ece:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80001ed2:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80001ed6:	10079073          	csrw	sstatus,a5
    80001eda:	0000f497          	auipc	s1,0xf
    80001ede:	7f648493          	addi	s1,s1,2038 # 800116d0 <proc>
    80001ee2:	a811                	j	80001ef6 <scheduler+0x74>
      release(&p->lock);
    80001ee4:	8526                	mv	a0,s1
    80001ee6:	fffff097          	auipc	ra,0xfffff
    80001eea:	d78080e7          	jalr	-648(ra) # 80000c5e <release>
    for(p = proc; p < &proc[NPROC]; p++) {
    80001eee:	16848493          	addi	s1,s1,360
    80001ef2:	fd248ee3          	beq	s1,s2,80001ece <scheduler+0x4c>
      acquire(&p->lock);
    80001ef6:	8526                	mv	a0,s1
    80001ef8:	fffff097          	auipc	ra,0xfffff
    80001efc:	cb2080e7          	jalr	-846(ra) # 80000baa <acquire>
      if(p->state == RUNNABLE) {
    80001f00:	4c9c                	lw	a5,24(s1)
    80001f02:	ff3791e3          	bne	a5,s3,80001ee4 <scheduler+0x62>
        p->state = RUNNING;
    80001f06:	0164ac23          	sw	s6,24(s1)
        c->proc = p;
    80001f0a:	029a3823          	sd	s1,48(s4)
        swtch(&c->context, &p->context);
    80001f0e:	06048593          	addi	a1,s1,96
    80001f12:	8556                	mv	a0,s5
    80001f14:	00000097          	auipc	ra,0x0
    80001f18:	620080e7          	jalr	1568(ra) # 80002534 <swtch>
        c->proc = 0;
    80001f1c:	020a3823          	sd	zero,48(s4)
    80001f20:	b7d1                	j	80001ee4 <scheduler+0x62>

0000000080001f22 <sched>:
{
    80001f22:	7179                	addi	sp,sp,-48
    80001f24:	f406                	sd	ra,40(sp)
    80001f26:	f022                	sd	s0,32(sp)
    80001f28:	ec26                	sd	s1,24(sp)
    80001f2a:	e84a                	sd	s2,16(sp)
    80001f2c:	e44e                	sd	s3,8(sp)
    80001f2e:	1800                	addi	s0,sp,48
  struct proc *p = myproc();
    80001f30:	00000097          	auipc	ra,0x0
    80001f34:	a40080e7          	jalr	-1472(ra) # 80001970 <myproc>
    80001f38:	84aa                	mv	s1,a0
  if(!holding(&p->lock))
    80001f3a:	fffff097          	auipc	ra,0xfffff
    80001f3e:	bf6080e7          	jalr	-1034(ra) # 80000b30 <holding>
    80001f42:	c93d                	beqz	a0,80001fb8 <sched+0x96>
  asm volatile("mv %0, tp" : "=r" (x) );
    80001f44:	8792                	mv	a5,tp
  if(mycpu()->noff != 1)
    80001f46:	2781                	sext.w	a5,a5
    80001f48:	079e                	slli	a5,a5,0x7
    80001f4a:	0000f717          	auipc	a4,0xf
    80001f4e:	35670713          	addi	a4,a4,854 # 800112a0 <pid_lock>
    80001f52:	97ba                	add	a5,a5,a4
    80001f54:	0a87a703          	lw	a4,168(a5)
    80001f58:	4785                	li	a5,1
    80001f5a:	06f71763          	bne	a4,a5,80001fc8 <sched+0xa6>
  if(p->state == RUNNING)
    80001f5e:	4c98                	lw	a4,24(s1)
    80001f60:	4791                	li	a5,4
    80001f62:	06f70b63          	beq	a4,a5,80001fd8 <sched+0xb6>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80001f66:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80001f6a:	8b89                	andi	a5,a5,2
  if(intr_get())
    80001f6c:	efb5                	bnez	a5,80001fe8 <sched+0xc6>
  asm volatile("mv %0, tp" : "=r" (x) );
    80001f6e:	8792                	mv	a5,tp
  intena = mycpu()->intena;
    80001f70:	0000f917          	auipc	s2,0xf
    80001f74:	33090913          	addi	s2,s2,816 # 800112a0 <pid_lock>
    80001f78:	2781                	sext.w	a5,a5
    80001f7a:	079e                	slli	a5,a5,0x7
    80001f7c:	97ca                	add	a5,a5,s2
    80001f7e:	0ac7a983          	lw	s3,172(a5)
    80001f82:	8792                	mv	a5,tp
  swtch(&p->context, &mycpu()->context);
    80001f84:	2781                	sext.w	a5,a5
    80001f86:	079e                	slli	a5,a5,0x7
    80001f88:	0000f597          	auipc	a1,0xf
    80001f8c:	35058593          	addi	a1,a1,848 # 800112d8 <cpus+0x8>
    80001f90:	95be                	add	a1,a1,a5
    80001f92:	06048513          	addi	a0,s1,96
    80001f96:	00000097          	auipc	ra,0x0
    80001f9a:	59e080e7          	jalr	1438(ra) # 80002534 <swtch>
    80001f9e:	8792                	mv	a5,tp
  mycpu()->intena = intena;
    80001fa0:	2781                	sext.w	a5,a5
    80001fa2:	079e                	slli	a5,a5,0x7
    80001fa4:	993e                	add	s2,s2,a5
    80001fa6:	0b392623          	sw	s3,172(s2)
}
    80001faa:	70a2                	ld	ra,40(sp)
    80001fac:	7402                	ld	s0,32(sp)
    80001fae:	64e2                	ld	s1,24(sp)
    80001fb0:	6942                	ld	s2,16(sp)
    80001fb2:	69a2                	ld	s3,8(sp)
    80001fb4:	6145                	addi	sp,sp,48
    80001fb6:	8082                	ret
    panic("sched p->lock");
    80001fb8:	00006517          	auipc	a0,0x6
    80001fbc:	26050513          	addi	a0,a0,608 # 80008218 <digits+0x1d8>
    80001fc0:	ffffe097          	auipc	ra,0xffffe
    80001fc4:	57a080e7          	jalr	1402(ra) # 8000053a <panic>
    panic("sched locks");
    80001fc8:	00006517          	auipc	a0,0x6
    80001fcc:	26050513          	addi	a0,a0,608 # 80008228 <digits+0x1e8>
    80001fd0:	ffffe097          	auipc	ra,0xffffe
    80001fd4:	56a080e7          	jalr	1386(ra) # 8000053a <panic>
    panic("sched running");
    80001fd8:	00006517          	auipc	a0,0x6
    80001fdc:	26050513          	addi	a0,a0,608 # 80008238 <digits+0x1f8>
    80001fe0:	ffffe097          	auipc	ra,0xffffe
    80001fe4:	55a080e7          	jalr	1370(ra) # 8000053a <panic>
    panic("sched interruptible");
    80001fe8:	00006517          	auipc	a0,0x6
    80001fec:	26050513          	addi	a0,a0,608 # 80008248 <digits+0x208>
    80001ff0:	ffffe097          	auipc	ra,0xffffe
    80001ff4:	54a080e7          	jalr	1354(ra) # 8000053a <panic>

0000000080001ff8 <yield>:
{
    80001ff8:	1101                	addi	sp,sp,-32
    80001ffa:	ec06                	sd	ra,24(sp)
    80001ffc:	e822                	sd	s0,16(sp)
    80001ffe:	e426                	sd	s1,8(sp)
    80002000:	1000                	addi	s0,sp,32
  struct proc *p = myproc();
    80002002:	00000097          	auipc	ra,0x0
    80002006:	96e080e7          	jalr	-1682(ra) # 80001970 <myproc>
    8000200a:	84aa                	mv	s1,a0
  acquire(&p->lock);
    8000200c:	fffff097          	auipc	ra,0xfffff
    80002010:	b9e080e7          	jalr	-1122(ra) # 80000baa <acquire>
  p->state = RUNNABLE;
    80002014:	478d                	li	a5,3
    80002016:	cc9c                	sw	a5,24(s1)
  sched();
    80002018:	00000097          	auipc	ra,0x0
    8000201c:	f0a080e7          	jalr	-246(ra) # 80001f22 <sched>
  release(&p->lock);
    80002020:	8526                	mv	a0,s1
    80002022:	fffff097          	auipc	ra,0xfffff
    80002026:	c3c080e7          	jalr	-964(ra) # 80000c5e <release>
}
    8000202a:	60e2                	ld	ra,24(sp)
    8000202c:	6442                	ld	s0,16(sp)
    8000202e:	64a2                	ld	s1,8(sp)
    80002030:	6105                	addi	sp,sp,32
    80002032:	8082                	ret

0000000080002034 <sleep>:

// Atomically release lock and sleep on chan.
// Reacquires lock when awakened.
void
sleep(void *chan, struct spinlock *lk)
{
    80002034:	7179                	addi	sp,sp,-48
    80002036:	f406                	sd	ra,40(sp)
    80002038:	f022                	sd	s0,32(sp)
    8000203a:	ec26                	sd	s1,24(sp)
    8000203c:	e84a                	sd	s2,16(sp)
    8000203e:	e44e                	sd	s3,8(sp)
    80002040:	1800                	addi	s0,sp,48
    80002042:	89aa                	mv	s3,a0
    80002044:	892e                	mv	s2,a1
  struct proc *p = myproc();
    80002046:	00000097          	auipc	ra,0x0
    8000204a:	92a080e7          	jalr	-1750(ra) # 80001970 <myproc>
    8000204e:	84aa                	mv	s1,a0
  // Once we hold p->lock, we can be
  // guaranteed that we won't miss any wakeup
  // (wakeup locks p->lock),
  // so it's okay to release lk.

  acquire(&p->lock);  //DOC: sleeplock1
    80002050:	fffff097          	auipc	ra,0xfffff
    80002054:	b5a080e7          	jalr	-1190(ra) # 80000baa <acquire>
  release(lk);
    80002058:	854a                	mv	a0,s2
    8000205a:	fffff097          	auipc	ra,0xfffff
    8000205e:	c04080e7          	jalr	-1020(ra) # 80000c5e <release>

  // Go to sleep.
  p->chan = chan;
    80002062:	0334b023          	sd	s3,32(s1)
  p->state = SLEEPING;
    80002066:	4789                	li	a5,2
    80002068:	cc9c                	sw	a5,24(s1)

  sched();
    8000206a:	00000097          	auipc	ra,0x0
    8000206e:	eb8080e7          	jalr	-328(ra) # 80001f22 <sched>

  // Tidy up.
  p->chan = 0;
    80002072:	0204b023          	sd	zero,32(s1)

  // Reacquire original lock.
  release(&p->lock);
    80002076:	8526                	mv	a0,s1
    80002078:	fffff097          	auipc	ra,0xfffff
    8000207c:	be6080e7          	jalr	-1050(ra) # 80000c5e <release>
  acquire(lk);
    80002080:	854a                	mv	a0,s2
    80002082:	fffff097          	auipc	ra,0xfffff
    80002086:	b28080e7          	jalr	-1240(ra) # 80000baa <acquire>
}
    8000208a:	70a2                	ld	ra,40(sp)
    8000208c:	7402                	ld	s0,32(sp)
    8000208e:	64e2                	ld	s1,24(sp)
    80002090:	6942                	ld	s2,16(sp)
    80002092:	69a2                	ld	s3,8(sp)
    80002094:	6145                	addi	sp,sp,48
    80002096:	8082                	ret

0000000080002098 <wait>:
{
    80002098:	715d                	addi	sp,sp,-80
    8000209a:	e486                	sd	ra,72(sp)
    8000209c:	e0a2                	sd	s0,64(sp)
    8000209e:	fc26                	sd	s1,56(sp)
    800020a0:	f84a                	sd	s2,48(sp)
    800020a2:	f44e                	sd	s3,40(sp)
    800020a4:	f052                	sd	s4,32(sp)
    800020a6:	ec56                	sd	s5,24(sp)
    800020a8:	e85a                	sd	s6,16(sp)
    800020aa:	e45e                	sd	s7,8(sp)
    800020ac:	e062                	sd	s8,0(sp)
    800020ae:	0880                	addi	s0,sp,80
    800020b0:	8b2a                	mv	s6,a0
  struct proc *p = myproc();
    800020b2:	00000097          	auipc	ra,0x0
    800020b6:	8be080e7          	jalr	-1858(ra) # 80001970 <myproc>
    800020ba:	892a                	mv	s2,a0
  acquire(&wait_lock);
    800020bc:	0000f517          	auipc	a0,0xf
    800020c0:	1fc50513          	addi	a0,a0,508 # 800112b8 <wait_lock>
    800020c4:	fffff097          	auipc	ra,0xfffff
    800020c8:	ae6080e7          	jalr	-1306(ra) # 80000baa <acquire>
    havekids = 0;
    800020cc:	4b81                	li	s7,0
        if(np->state == ZOMBIE){
    800020ce:	4a15                	li	s4,5
        havekids = 1;
    800020d0:	4a85                	li	s5,1
    for(np = proc; np < &proc[NPROC]; np++){
    800020d2:	00015997          	auipc	s3,0x15
    800020d6:	ffe98993          	addi	s3,s3,-2 # 800170d0 <tickslock>
    sleep(p, &wait_lock);  //DOC: wait-sleep
    800020da:	0000fc17          	auipc	s8,0xf
    800020de:	1dec0c13          	addi	s8,s8,478 # 800112b8 <wait_lock>
    havekids = 0;
    800020e2:	875e                	mv	a4,s7
    for(np = proc; np < &proc[NPROC]; np++){
    800020e4:	0000f497          	auipc	s1,0xf
    800020e8:	5ec48493          	addi	s1,s1,1516 # 800116d0 <proc>
    800020ec:	a0bd                	j	8000215a <wait+0xc2>
          pid = np->pid;
    800020ee:	0304a983          	lw	s3,48(s1)
          if(addr != 0 && copyout(p->pagetable, addr, (char *)&np->xstate,
    800020f2:	000b0e63          	beqz	s6,8000210e <wait+0x76>
    800020f6:	4691                	li	a3,4
    800020f8:	02c48613          	addi	a2,s1,44
    800020fc:	85da                	mv	a1,s6
    800020fe:	05093503          	ld	a0,80(s2)
    80002102:	fffff097          	auipc	ra,0xfffff
    80002106:	532080e7          	jalr	1330(ra) # 80001634 <copyout>
    8000210a:	02054563          	bltz	a0,80002134 <wait+0x9c>
          freeproc(np);
    8000210e:	8526                	mv	a0,s1
    80002110:	00000097          	auipc	ra,0x0
    80002114:	a12080e7          	jalr	-1518(ra) # 80001b22 <freeproc>
          release(&np->lock);
    80002118:	8526                	mv	a0,s1
    8000211a:	fffff097          	auipc	ra,0xfffff
    8000211e:	b44080e7          	jalr	-1212(ra) # 80000c5e <release>
          release(&wait_lock);
    80002122:	0000f517          	auipc	a0,0xf
    80002126:	19650513          	addi	a0,a0,406 # 800112b8 <wait_lock>
    8000212a:	fffff097          	auipc	ra,0xfffff
    8000212e:	b34080e7          	jalr	-1228(ra) # 80000c5e <release>
          return pid;
    80002132:	a09d                	j	80002198 <wait+0x100>
            release(&np->lock);
    80002134:	8526                	mv	a0,s1
    80002136:	fffff097          	auipc	ra,0xfffff
    8000213a:	b28080e7          	jalr	-1240(ra) # 80000c5e <release>
            release(&wait_lock);
    8000213e:	0000f517          	auipc	a0,0xf
    80002142:	17a50513          	addi	a0,a0,378 # 800112b8 <wait_lock>
    80002146:	fffff097          	auipc	ra,0xfffff
    8000214a:	b18080e7          	jalr	-1256(ra) # 80000c5e <release>
            return -1;
    8000214e:	59fd                	li	s3,-1
    80002150:	a0a1                	j	80002198 <wait+0x100>
    for(np = proc; np < &proc[NPROC]; np++){
    80002152:	16848493          	addi	s1,s1,360
    80002156:	03348463          	beq	s1,s3,8000217e <wait+0xe6>
      if(np->parent == p){
    8000215a:	7c9c                	ld	a5,56(s1)
    8000215c:	ff279be3          	bne	a5,s2,80002152 <wait+0xba>
        acquire(&np->lock);
    80002160:	8526                	mv	a0,s1
    80002162:	fffff097          	auipc	ra,0xfffff
    80002166:	a48080e7          	jalr	-1464(ra) # 80000baa <acquire>
        if(np->state == ZOMBIE){
    8000216a:	4c9c                	lw	a5,24(s1)
    8000216c:	f94781e3          	beq	a5,s4,800020ee <wait+0x56>
        release(&np->lock);
    80002170:	8526                	mv	a0,s1
    80002172:	fffff097          	auipc	ra,0xfffff
    80002176:	aec080e7          	jalr	-1300(ra) # 80000c5e <release>
        havekids = 1;
    8000217a:	8756                	mv	a4,s5
    8000217c:	bfd9                	j	80002152 <wait+0xba>
    if(!havekids || p->killed){
    8000217e:	c701                	beqz	a4,80002186 <wait+0xee>
    80002180:	02892783          	lw	a5,40(s2)
    80002184:	c79d                	beqz	a5,800021b2 <wait+0x11a>
      release(&wait_lock);
    80002186:	0000f517          	auipc	a0,0xf
    8000218a:	13250513          	addi	a0,a0,306 # 800112b8 <wait_lock>
    8000218e:	fffff097          	auipc	ra,0xfffff
    80002192:	ad0080e7          	jalr	-1328(ra) # 80000c5e <release>
      return -1;
    80002196:	59fd                	li	s3,-1
}
    80002198:	854e                	mv	a0,s3
    8000219a:	60a6                	ld	ra,72(sp)
    8000219c:	6406                	ld	s0,64(sp)
    8000219e:	74e2                	ld	s1,56(sp)
    800021a0:	7942                	ld	s2,48(sp)
    800021a2:	79a2                	ld	s3,40(sp)
    800021a4:	7a02                	ld	s4,32(sp)
    800021a6:	6ae2                	ld	s5,24(sp)
    800021a8:	6b42                	ld	s6,16(sp)
    800021aa:	6ba2                	ld	s7,8(sp)
    800021ac:	6c02                	ld	s8,0(sp)
    800021ae:	6161                	addi	sp,sp,80
    800021b0:	8082                	ret
    sleep(p, &wait_lock);  //DOC: wait-sleep
    800021b2:	85e2                	mv	a1,s8
    800021b4:	854a                	mv	a0,s2
    800021b6:	00000097          	auipc	ra,0x0
    800021ba:	e7e080e7          	jalr	-386(ra) # 80002034 <sleep>
    havekids = 0;
    800021be:	b715                	j	800020e2 <wait+0x4a>

00000000800021c0 <wakeup>:

// Wake up all processes sleeping on chan.
// Must be called without any p->lock.
void
wakeup(void *chan)
{
    800021c0:	7139                	addi	sp,sp,-64
    800021c2:	fc06                	sd	ra,56(sp)
    800021c4:	f822                	sd	s0,48(sp)
    800021c6:	f426                	sd	s1,40(sp)
    800021c8:	f04a                	sd	s2,32(sp)
    800021ca:	ec4e                	sd	s3,24(sp)
    800021cc:	e852                	sd	s4,16(sp)
    800021ce:	e456                	sd	s5,8(sp)
    800021d0:	0080                	addi	s0,sp,64
    800021d2:	8a2a                	mv	s4,a0
  struct proc *p;

  for(p = proc; p < &proc[NPROC]; p++) {
    800021d4:	0000f497          	auipc	s1,0xf
    800021d8:	4fc48493          	addi	s1,s1,1276 # 800116d0 <proc>
    if(p != myproc()){
      acquire(&p->lock);
      if(p->state == SLEEPING && p->chan == chan) {
    800021dc:	4989                	li	s3,2
        p->state = RUNNABLE;
    800021de:	4a8d                	li	s5,3
  for(p = proc; p < &proc[NPROC]; p++) {
    800021e0:	00015917          	auipc	s2,0x15
    800021e4:	ef090913          	addi	s2,s2,-272 # 800170d0 <tickslock>
    800021e8:	a811                	j	800021fc <wakeup+0x3c>
      }
      release(&p->lock);
    800021ea:	8526                	mv	a0,s1
    800021ec:	fffff097          	auipc	ra,0xfffff
    800021f0:	a72080e7          	jalr	-1422(ra) # 80000c5e <release>
  for(p = proc; p < &proc[NPROC]; p++) {
    800021f4:	16848493          	addi	s1,s1,360
    800021f8:	03248663          	beq	s1,s2,80002224 <wakeup+0x64>
    if(p != myproc()){
    800021fc:	fffff097          	auipc	ra,0xfffff
    80002200:	774080e7          	jalr	1908(ra) # 80001970 <myproc>
    80002204:	fea488e3          	beq	s1,a0,800021f4 <wakeup+0x34>
      acquire(&p->lock);
    80002208:	8526                	mv	a0,s1
    8000220a:	fffff097          	auipc	ra,0xfffff
    8000220e:	9a0080e7          	jalr	-1632(ra) # 80000baa <acquire>
      if(p->state == SLEEPING && p->chan == chan) {
    80002212:	4c9c                	lw	a5,24(s1)
    80002214:	fd379be3          	bne	a5,s3,800021ea <wakeup+0x2a>
    80002218:	709c                	ld	a5,32(s1)
    8000221a:	fd4798e3          	bne	a5,s4,800021ea <wakeup+0x2a>
        p->state = RUNNABLE;
    8000221e:	0154ac23          	sw	s5,24(s1)
    80002222:	b7e1                	j	800021ea <wakeup+0x2a>
    }
  }
}
    80002224:	70e2                	ld	ra,56(sp)
    80002226:	7442                	ld	s0,48(sp)
    80002228:	74a2                	ld	s1,40(sp)
    8000222a:	7902                	ld	s2,32(sp)
    8000222c:	69e2                	ld	s3,24(sp)
    8000222e:	6a42                	ld	s4,16(sp)
    80002230:	6aa2                	ld	s5,8(sp)
    80002232:	6121                	addi	sp,sp,64
    80002234:	8082                	ret

0000000080002236 <reparent>:
{
    80002236:	7179                	addi	sp,sp,-48
    80002238:	f406                	sd	ra,40(sp)
    8000223a:	f022                	sd	s0,32(sp)
    8000223c:	ec26                	sd	s1,24(sp)
    8000223e:	e84a                	sd	s2,16(sp)
    80002240:	e44e                	sd	s3,8(sp)
    80002242:	e052                	sd	s4,0(sp)
    80002244:	1800                	addi	s0,sp,48
    80002246:	892a                	mv	s2,a0
  for(pp = proc; pp < &proc[NPROC]; pp++){
    80002248:	0000f497          	auipc	s1,0xf
    8000224c:	48848493          	addi	s1,s1,1160 # 800116d0 <proc>
      pp->parent = initproc;
    80002250:	00007a17          	auipc	s4,0x7
    80002254:	dd8a0a13          	addi	s4,s4,-552 # 80009028 <initproc>
  for(pp = proc; pp < &proc[NPROC]; pp++){
    80002258:	00015997          	auipc	s3,0x15
    8000225c:	e7898993          	addi	s3,s3,-392 # 800170d0 <tickslock>
    80002260:	a029                	j	8000226a <reparent+0x34>
    80002262:	16848493          	addi	s1,s1,360
    80002266:	01348d63          	beq	s1,s3,80002280 <reparent+0x4a>
    if(pp->parent == p){
    8000226a:	7c9c                	ld	a5,56(s1)
    8000226c:	ff279be3          	bne	a5,s2,80002262 <reparent+0x2c>
      pp->parent = initproc;
    80002270:	000a3503          	ld	a0,0(s4)
    80002274:	fc88                	sd	a0,56(s1)
      wakeup(initproc);
    80002276:	00000097          	auipc	ra,0x0
    8000227a:	f4a080e7          	jalr	-182(ra) # 800021c0 <wakeup>
    8000227e:	b7d5                	j	80002262 <reparent+0x2c>
}
    80002280:	70a2                	ld	ra,40(sp)
    80002282:	7402                	ld	s0,32(sp)
    80002284:	64e2                	ld	s1,24(sp)
    80002286:	6942                	ld	s2,16(sp)
    80002288:	69a2                	ld	s3,8(sp)
    8000228a:	6a02                	ld	s4,0(sp)
    8000228c:	6145                	addi	sp,sp,48
    8000228e:	8082                	ret

0000000080002290 <exit>:
{
    80002290:	7179                	addi	sp,sp,-48
    80002292:	f406                	sd	ra,40(sp)
    80002294:	f022                	sd	s0,32(sp)
    80002296:	ec26                	sd	s1,24(sp)
    80002298:	e84a                	sd	s2,16(sp)
    8000229a:	e44e                	sd	s3,8(sp)
    8000229c:	e052                	sd	s4,0(sp)
    8000229e:	1800                	addi	s0,sp,48
    800022a0:	8a2a                	mv	s4,a0
  struct proc *p = myproc();
    800022a2:	fffff097          	auipc	ra,0xfffff
    800022a6:	6ce080e7          	jalr	1742(ra) # 80001970 <myproc>
    800022aa:	89aa                	mv	s3,a0
  if(p == initproc)
    800022ac:	00007797          	auipc	a5,0x7
    800022b0:	d7c7b783          	ld	a5,-644(a5) # 80009028 <initproc>
    800022b4:	0d050493          	addi	s1,a0,208
    800022b8:	15050913          	addi	s2,a0,336
    800022bc:	02a79363          	bne	a5,a0,800022e2 <exit+0x52>
    panic("init exiting");
    800022c0:	00006517          	auipc	a0,0x6
    800022c4:	fa050513          	addi	a0,a0,-96 # 80008260 <digits+0x220>
    800022c8:	ffffe097          	auipc	ra,0xffffe
    800022cc:	272080e7          	jalr	626(ra) # 8000053a <panic>
      fileclose(f);
    800022d0:	00002097          	auipc	ra,0x2
    800022d4:	16c080e7          	jalr	364(ra) # 8000443c <fileclose>
      p->ofile[fd] = 0;
    800022d8:	0004b023          	sd	zero,0(s1)
  for(int fd = 0; fd < NOFILE; fd++){
    800022dc:	04a1                	addi	s1,s1,8
    800022de:	01248563          	beq	s1,s2,800022e8 <exit+0x58>
    if(p->ofile[fd]){
    800022e2:	6088                	ld	a0,0(s1)
    800022e4:	f575                	bnez	a0,800022d0 <exit+0x40>
    800022e6:	bfdd                	j	800022dc <exit+0x4c>
  begin_op();
    800022e8:	00002097          	auipc	ra,0x2
    800022ec:	c8c080e7          	jalr	-884(ra) # 80003f74 <begin_op>
  iput(p->cwd);
    800022f0:	1509b503          	ld	a0,336(s3)
    800022f4:	00001097          	auipc	ra,0x1
    800022f8:	45e080e7          	jalr	1118(ra) # 80003752 <iput>
  end_op();
    800022fc:	00002097          	auipc	ra,0x2
    80002300:	cf6080e7          	jalr	-778(ra) # 80003ff2 <end_op>
  p->cwd = 0;
    80002304:	1409b823          	sd	zero,336(s3)
  acquire(&wait_lock);
    80002308:	0000f497          	auipc	s1,0xf
    8000230c:	fb048493          	addi	s1,s1,-80 # 800112b8 <wait_lock>
    80002310:	8526                	mv	a0,s1
    80002312:	fffff097          	auipc	ra,0xfffff
    80002316:	898080e7          	jalr	-1896(ra) # 80000baa <acquire>
  reparent(p);
    8000231a:	854e                	mv	a0,s3
    8000231c:	00000097          	auipc	ra,0x0
    80002320:	f1a080e7          	jalr	-230(ra) # 80002236 <reparent>
  wakeup(p->parent);
    80002324:	0389b503          	ld	a0,56(s3)
    80002328:	00000097          	auipc	ra,0x0
    8000232c:	e98080e7          	jalr	-360(ra) # 800021c0 <wakeup>
  acquire(&p->lock);
    80002330:	854e                	mv	a0,s3
    80002332:	fffff097          	auipc	ra,0xfffff
    80002336:	878080e7          	jalr	-1928(ra) # 80000baa <acquire>
  p->xstate = status;
    8000233a:	0349a623          	sw	s4,44(s3)
  p->state = ZOMBIE;
    8000233e:	4795                	li	a5,5
    80002340:	00f9ac23          	sw	a5,24(s3)
  release(&wait_lock);
    80002344:	8526                	mv	a0,s1
    80002346:	fffff097          	auipc	ra,0xfffff
    8000234a:	918080e7          	jalr	-1768(ra) # 80000c5e <release>
  sched();
    8000234e:	00000097          	auipc	ra,0x0
    80002352:	bd4080e7          	jalr	-1068(ra) # 80001f22 <sched>
  panic("zombie exit");
    80002356:	00006517          	auipc	a0,0x6
    8000235a:	f1a50513          	addi	a0,a0,-230 # 80008270 <digits+0x230>
    8000235e:	ffffe097          	auipc	ra,0xffffe
    80002362:	1dc080e7          	jalr	476(ra) # 8000053a <panic>

0000000080002366 <kill>:
// Kill the process with the given pid.
// The victim won't exit until it tries to return
// to user space (see usertrap() in trap.c).
int
kill(int pid)
{
    80002366:	7179                	addi	sp,sp,-48
    80002368:	f406                	sd	ra,40(sp)
    8000236a:	f022                	sd	s0,32(sp)
    8000236c:	ec26                	sd	s1,24(sp)
    8000236e:	e84a                	sd	s2,16(sp)
    80002370:	e44e                	sd	s3,8(sp)
    80002372:	1800                	addi	s0,sp,48
    80002374:	892a                	mv	s2,a0
  struct proc *p;

  for(p = proc; p < &proc[NPROC]; p++){
    80002376:	0000f497          	auipc	s1,0xf
    8000237a:	35a48493          	addi	s1,s1,858 # 800116d0 <proc>
    8000237e:	00015997          	auipc	s3,0x15
    80002382:	d5298993          	addi	s3,s3,-686 # 800170d0 <tickslock>
    acquire(&p->lock);
    80002386:	8526                	mv	a0,s1
    80002388:	fffff097          	auipc	ra,0xfffff
    8000238c:	822080e7          	jalr	-2014(ra) # 80000baa <acquire>
    if(p->pid == pid){
    80002390:	589c                	lw	a5,48(s1)
    80002392:	01278d63          	beq	a5,s2,800023ac <kill+0x46>
        p->state = RUNNABLE;
      }
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
    80002396:	8526                	mv	a0,s1
    80002398:	fffff097          	auipc	ra,0xfffff
    8000239c:	8c6080e7          	jalr	-1850(ra) # 80000c5e <release>
  for(p = proc; p < &proc[NPROC]; p++){
    800023a0:	16848493          	addi	s1,s1,360
    800023a4:	ff3491e3          	bne	s1,s3,80002386 <kill+0x20>
  }
  return -1;
    800023a8:	557d                	li	a0,-1
    800023aa:	a829                	j	800023c4 <kill+0x5e>
      p->killed = 1;
    800023ac:	4785                	li	a5,1
    800023ae:	d49c                	sw	a5,40(s1)
      if(p->state == SLEEPING){
    800023b0:	4c98                	lw	a4,24(s1)
    800023b2:	4789                	li	a5,2
    800023b4:	00f70f63          	beq	a4,a5,800023d2 <kill+0x6c>
      release(&p->lock);
    800023b8:	8526                	mv	a0,s1
    800023ba:	fffff097          	auipc	ra,0xfffff
    800023be:	8a4080e7          	jalr	-1884(ra) # 80000c5e <release>
      return 0;
    800023c2:	4501                	li	a0,0
}
    800023c4:	70a2                	ld	ra,40(sp)
    800023c6:	7402                	ld	s0,32(sp)
    800023c8:	64e2                	ld	s1,24(sp)
    800023ca:	6942                	ld	s2,16(sp)
    800023cc:	69a2                	ld	s3,8(sp)
    800023ce:	6145                	addi	sp,sp,48
    800023d0:	8082                	ret
        p->state = RUNNABLE;
    800023d2:	478d                	li	a5,3
    800023d4:	cc9c                	sw	a5,24(s1)
    800023d6:	b7cd                	j	800023b8 <kill+0x52>

00000000800023d8 <either_copyout>:
// Copy to either a user address, or kernel address,
// depending on usr_dst.
// Returns 0 on success, -1 on error.
int
either_copyout(int user_dst, uint64 dst, void *src, uint64 len)
{
    800023d8:	7179                	addi	sp,sp,-48
    800023da:	f406                	sd	ra,40(sp)
    800023dc:	f022                	sd	s0,32(sp)
    800023de:	ec26                	sd	s1,24(sp)
    800023e0:	e84a                	sd	s2,16(sp)
    800023e2:	e44e                	sd	s3,8(sp)
    800023e4:	e052                	sd	s4,0(sp)
    800023e6:	1800                	addi	s0,sp,48
    800023e8:	84aa                	mv	s1,a0
    800023ea:	892e                	mv	s2,a1
    800023ec:	89b2                	mv	s3,a2
    800023ee:	8a36                	mv	s4,a3
  struct proc *p = myproc();
    800023f0:	fffff097          	auipc	ra,0xfffff
    800023f4:	580080e7          	jalr	1408(ra) # 80001970 <myproc>
  if(user_dst){
    800023f8:	c08d                	beqz	s1,8000241a <either_copyout+0x42>
    return copyout(p->pagetable, dst, src, len);
    800023fa:	86d2                	mv	a3,s4
    800023fc:	864e                	mv	a2,s3
    800023fe:	85ca                	mv	a1,s2
    80002400:	6928                	ld	a0,80(a0)
    80002402:	fffff097          	auipc	ra,0xfffff
    80002406:	232080e7          	jalr	562(ra) # 80001634 <copyout>
  } else {
    memmove((char *)dst, src, len);
    return 0;
  }
}
    8000240a:	70a2                	ld	ra,40(sp)
    8000240c:	7402                	ld	s0,32(sp)
    8000240e:	64e2                	ld	s1,24(sp)
    80002410:	6942                	ld	s2,16(sp)
    80002412:	69a2                	ld	s3,8(sp)
    80002414:	6a02                	ld	s4,0(sp)
    80002416:	6145                	addi	sp,sp,48
    80002418:	8082                	ret
    memmove((char *)dst, src, len);
    8000241a:	000a061b          	sext.w	a2,s4
    8000241e:	85ce                	mv	a1,s3
    80002420:	854a                	mv	a0,s2
    80002422:	fffff097          	auipc	ra,0xfffff
    80002426:	8e0080e7          	jalr	-1824(ra) # 80000d02 <memmove>
    return 0;
    8000242a:	8526                	mv	a0,s1
    8000242c:	bff9                	j	8000240a <either_copyout+0x32>

000000008000242e <either_copyin>:
// Copy from either a user address, or kernel address,
// depending on usr_src.
// Returns 0 on success, -1 on error.
int
either_copyin(void *dst, int user_src, uint64 src, uint64 len)
{
    8000242e:	7179                	addi	sp,sp,-48
    80002430:	f406                	sd	ra,40(sp)
    80002432:	f022                	sd	s0,32(sp)
    80002434:	ec26                	sd	s1,24(sp)
    80002436:	e84a                	sd	s2,16(sp)
    80002438:	e44e                	sd	s3,8(sp)
    8000243a:	e052                	sd	s4,0(sp)
    8000243c:	1800                	addi	s0,sp,48
    8000243e:	892a                	mv	s2,a0
    80002440:	84ae                	mv	s1,a1
    80002442:	89b2                	mv	s3,a2
    80002444:	8a36                	mv	s4,a3
  struct proc *p = myproc();
    80002446:	fffff097          	auipc	ra,0xfffff
    8000244a:	52a080e7          	jalr	1322(ra) # 80001970 <myproc>
  if(user_src){
    8000244e:	c08d                	beqz	s1,80002470 <either_copyin+0x42>
    return copyin(p->pagetable, dst, src, len);
    80002450:	86d2                	mv	a3,s4
    80002452:	864e                	mv	a2,s3
    80002454:	85ca                	mv	a1,s2
    80002456:	6928                	ld	a0,80(a0)
    80002458:	fffff097          	auipc	ra,0xfffff
    8000245c:	268080e7          	jalr	616(ra) # 800016c0 <copyin>
  } else {
    memmove(dst, (char*)src, len);
    return 0;
  }
}
    80002460:	70a2                	ld	ra,40(sp)
    80002462:	7402                	ld	s0,32(sp)
    80002464:	64e2                	ld	s1,24(sp)
    80002466:	6942                	ld	s2,16(sp)
    80002468:	69a2                	ld	s3,8(sp)
    8000246a:	6a02                	ld	s4,0(sp)
    8000246c:	6145                	addi	sp,sp,48
    8000246e:	8082                	ret
    memmove(dst, (char*)src, len);
    80002470:	000a061b          	sext.w	a2,s4
    80002474:	85ce                	mv	a1,s3
    80002476:	854a                	mv	a0,s2
    80002478:	fffff097          	auipc	ra,0xfffff
    8000247c:	88a080e7          	jalr	-1910(ra) # 80000d02 <memmove>
    return 0;
    80002480:	8526                	mv	a0,s1
    80002482:	bff9                	j	80002460 <either_copyin+0x32>

0000000080002484 <procdump>:
// Print a process listing to console.  For debugging.
// Runs when user types ^P on console.
// No lock to avoid wedging a stuck machine further.
void
procdump(void)
{
    80002484:	715d                	addi	sp,sp,-80
    80002486:	e486                	sd	ra,72(sp)
    80002488:	e0a2                	sd	s0,64(sp)
    8000248a:	fc26                	sd	s1,56(sp)
    8000248c:	f84a                	sd	s2,48(sp)
    8000248e:	f44e                	sd	s3,40(sp)
    80002490:	f052                	sd	s4,32(sp)
    80002492:	ec56                	sd	s5,24(sp)
    80002494:	e85a                	sd	s6,16(sp)
    80002496:	e45e                	sd	s7,8(sp)
    80002498:	0880                	addi	s0,sp,80
  [ZOMBIE]    "zombie"
  };
  struct proc *p;
  char *state;

  printf("\n");
    8000249a:	00006517          	auipc	a0,0x6
    8000249e:	c2e50513          	addi	a0,a0,-978 # 800080c8 <digits+0x88>
    800024a2:	ffffe097          	auipc	ra,0xffffe
    800024a6:	0e2080e7          	jalr	226(ra) # 80000584 <printf>
  for(p = proc; p < &proc[NPROC]; p++){
    800024aa:	0000f497          	auipc	s1,0xf
    800024ae:	37e48493          	addi	s1,s1,894 # 80011828 <proc+0x158>
    800024b2:	00015917          	auipc	s2,0x15
    800024b6:	d7690913          	addi	s2,s2,-650 # 80017228 <bcache+0x140>
    if(p->state == UNUSED)
      continue;
    if(p->state >= 0 && p->state < NELEM(states) && states[p->state])
    800024ba:	4b15                	li	s6,5
      state = states[p->state];
    else
      state = "???";
    800024bc:	00006997          	auipc	s3,0x6
    800024c0:	dc498993          	addi	s3,s3,-572 # 80008280 <digits+0x240>
    printf("%d %s %s", p->pid, state, p->name);
    800024c4:	00006a97          	auipc	s5,0x6
    800024c8:	dc4a8a93          	addi	s5,s5,-572 # 80008288 <digits+0x248>
    printf("\n");
    800024cc:	00006a17          	auipc	s4,0x6
    800024d0:	bfca0a13          	addi	s4,s4,-1028 # 800080c8 <digits+0x88>
    if(p->state >= 0 && p->state < NELEM(states) && states[p->state])
    800024d4:	00006b97          	auipc	s7,0x6
    800024d8:	decb8b93          	addi	s7,s7,-532 # 800082c0 <states.0>
    800024dc:	a00d                	j	800024fe <procdump+0x7a>
    printf("%d %s %s", p->pid, state, p->name);
    800024de:	ed86a583          	lw	a1,-296(a3)
    800024e2:	8556                	mv	a0,s5
    800024e4:	ffffe097          	auipc	ra,0xffffe
    800024e8:	0a0080e7          	jalr	160(ra) # 80000584 <printf>
    printf("\n");
    800024ec:	8552                	mv	a0,s4
    800024ee:	ffffe097          	auipc	ra,0xffffe
    800024f2:	096080e7          	jalr	150(ra) # 80000584 <printf>
  for(p = proc; p < &proc[NPROC]; p++){
    800024f6:	16848493          	addi	s1,s1,360
    800024fa:	03248263          	beq	s1,s2,8000251e <procdump+0x9a>
    if(p->state == UNUSED)
    800024fe:	86a6                	mv	a3,s1
    80002500:	ec04a783          	lw	a5,-320(s1)
    80002504:	dbed                	beqz	a5,800024f6 <procdump+0x72>
      state = "???";
    80002506:	864e                	mv	a2,s3
    if(p->state >= 0 && p->state < NELEM(states) && states[p->state])
    80002508:	fcfb6be3          	bltu	s6,a5,800024de <procdump+0x5a>
    8000250c:	02079713          	slli	a4,a5,0x20
    80002510:	01d75793          	srli	a5,a4,0x1d
    80002514:	97de                	add	a5,a5,s7
    80002516:	6390                	ld	a2,0(a5)
    80002518:	f279                	bnez	a2,800024de <procdump+0x5a>
      state = "???";
    8000251a:	864e                	mv	a2,s3
    8000251c:	b7c9                	j	800024de <procdump+0x5a>
  }
}
    8000251e:	60a6                	ld	ra,72(sp)
    80002520:	6406                	ld	s0,64(sp)
    80002522:	74e2                	ld	s1,56(sp)
    80002524:	7942                	ld	s2,48(sp)
    80002526:	79a2                	ld	s3,40(sp)
    80002528:	7a02                	ld	s4,32(sp)
    8000252a:	6ae2                	ld	s5,24(sp)
    8000252c:	6b42                	ld	s6,16(sp)
    8000252e:	6ba2                	ld	s7,8(sp)
    80002530:	6161                	addi	sp,sp,80
    80002532:	8082                	ret

0000000080002534 <swtch>:
    80002534:	00153023          	sd	ra,0(a0)
    80002538:	00253423          	sd	sp,8(a0)
    8000253c:	e900                	sd	s0,16(a0)
    8000253e:	ed04                	sd	s1,24(a0)
    80002540:	03253023          	sd	s2,32(a0)
    80002544:	03353423          	sd	s3,40(a0)
    80002548:	03453823          	sd	s4,48(a0)
    8000254c:	03553c23          	sd	s5,56(a0)
    80002550:	05653023          	sd	s6,64(a0)
    80002554:	05753423          	sd	s7,72(a0)
    80002558:	05853823          	sd	s8,80(a0)
    8000255c:	05953c23          	sd	s9,88(a0)
    80002560:	07a53023          	sd	s10,96(a0)
    80002564:	07b53423          	sd	s11,104(a0)
    80002568:	0005b083          	ld	ra,0(a1)
    8000256c:	0085b103          	ld	sp,8(a1)
    80002570:	6980                	ld	s0,16(a1)
    80002572:	6d84                	ld	s1,24(a1)
    80002574:	0205b903          	ld	s2,32(a1)
    80002578:	0285b983          	ld	s3,40(a1)
    8000257c:	0305ba03          	ld	s4,48(a1)
    80002580:	0385ba83          	ld	s5,56(a1)
    80002584:	0405bb03          	ld	s6,64(a1)
    80002588:	0485bb83          	ld	s7,72(a1)
    8000258c:	0505bc03          	ld	s8,80(a1)
    80002590:	0585bc83          	ld	s9,88(a1)
    80002594:	0605bd03          	ld	s10,96(a1)
    80002598:	0685bd83          	ld	s11,104(a1)
    8000259c:	8082                	ret

000000008000259e <trapinit>:

extern int devintr();

void
trapinit(void)
{
    8000259e:	1141                	addi	sp,sp,-16
    800025a0:	e406                	sd	ra,8(sp)
    800025a2:	e022                	sd	s0,0(sp)
    800025a4:	0800                	addi	s0,sp,16
  initlock(&tickslock, "time");
    800025a6:	00006597          	auipc	a1,0x6
    800025aa:	d4a58593          	addi	a1,a1,-694 # 800082f0 <states.0+0x30>
    800025ae:	00015517          	auipc	a0,0x15
    800025b2:	b2250513          	addi	a0,a0,-1246 # 800170d0 <tickslock>
    800025b6:	ffffe097          	auipc	ra,0xffffe
    800025ba:	564080e7          	jalr	1380(ra) # 80000b1a <initlock>
}
    800025be:	60a2                	ld	ra,8(sp)
    800025c0:	6402                	ld	s0,0(sp)
    800025c2:	0141                	addi	sp,sp,16
    800025c4:	8082                	ret

00000000800025c6 <trapinithart>:

// set up to take exceptions and traps while in the kernel.
void
trapinithart(void)
{
    800025c6:	1141                	addi	sp,sp,-16
    800025c8:	e422                	sd	s0,8(sp)
    800025ca:	0800                	addi	s0,sp,16
  asm volatile("csrw stvec, %0" : : "r" (x));
    800025cc:	00003797          	auipc	a5,0x3
    800025d0:	4a478793          	addi	a5,a5,1188 # 80005a70 <kernelvec>
    800025d4:	10579073          	csrw	stvec,a5
  w_stvec((uint64)kernelvec);
}
    800025d8:	6422                	ld	s0,8(sp)
    800025da:	0141                	addi	sp,sp,16
    800025dc:	8082                	ret

00000000800025de <usertrapret>:
//
// return to user space
//
void
usertrapret(void)
{
    800025de:	1141                	addi	sp,sp,-16
    800025e0:	e406                	sd	ra,8(sp)
    800025e2:	e022                	sd	s0,0(sp)
    800025e4:	0800                	addi	s0,sp,16
  struct proc *p = myproc();
    800025e6:	fffff097          	auipc	ra,0xfffff
    800025ea:	38a080e7          	jalr	906(ra) # 80001970 <myproc>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    800025ee:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    800025f2:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    800025f4:	10079073          	csrw	sstatus,a5
  // kerneltrap() to usertrap(), so turn off interrupts until
  // we're back in user space, where usertrap() is correct.
  intr_off();

  // send syscalls, interrupts, and exceptions to trampoline.S
  w_stvec(TRAMPOLINE + (uservec - trampoline));
    800025f8:	00005697          	auipc	a3,0x5
    800025fc:	a0868693          	addi	a3,a3,-1528 # 80007000 <_trampoline>
    80002600:	00005717          	auipc	a4,0x5
    80002604:	a0070713          	addi	a4,a4,-1536 # 80007000 <_trampoline>
    80002608:	8f15                	sub	a4,a4,a3
    8000260a:	040007b7          	lui	a5,0x4000
    8000260e:	17fd                	addi	a5,a5,-1 # 3ffffff <_entry-0x7c000001>
    80002610:	07b2                	slli	a5,a5,0xc
    80002612:	973e                	add	a4,a4,a5
  asm volatile("csrw stvec, %0" : : "r" (x));
    80002614:	10571073          	csrw	stvec,a4

  // set up trapframe values that uservec will need when
  // the process next re-enters the kernel.
  p->trapframe->kernel_satp = r_satp();         // kernel page table
    80002618:	6d38                	ld	a4,88(a0)
  asm volatile("csrr %0, satp" : "=r" (x) );
    8000261a:	18002673          	csrr	a2,satp
    8000261e:	e310                	sd	a2,0(a4)
  p->trapframe->kernel_sp = p->kstack + PGSIZE; // process's kernel stack
    80002620:	6d30                	ld	a2,88(a0)
    80002622:	6138                	ld	a4,64(a0)
    80002624:	6585                	lui	a1,0x1
    80002626:	972e                	add	a4,a4,a1
    80002628:	e618                	sd	a4,8(a2)
  p->trapframe->kernel_trap = (uint64)usertrap;
    8000262a:	6d38                	ld	a4,88(a0)
    8000262c:	00000617          	auipc	a2,0x0
    80002630:	13860613          	addi	a2,a2,312 # 80002764 <usertrap>
    80002634:	eb10                	sd	a2,16(a4)
  p->trapframe->kernel_hartid = r_tp();         // hartid for cpuid()
    80002636:	6d38                	ld	a4,88(a0)
  asm volatile("mv %0, tp" : "=r" (x) );
    80002638:	8612                	mv	a2,tp
    8000263a:	f310                	sd	a2,32(a4)
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    8000263c:	10002773          	csrr	a4,sstatus
  // set up the registers that trampoline.S's sret will use
  // to get to user space.
  
  // set S Previous Privilege mode to User.
  unsigned long x = r_sstatus();
  x &= ~SSTATUS_SPP; // clear SPP to 0 for user mode
    80002640:	eff77713          	andi	a4,a4,-257
  x |= SSTATUS_SPIE; // enable interrupts in user mode
    80002644:	02076713          	ori	a4,a4,32
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002648:	10071073          	csrw	sstatus,a4
  w_sstatus(x);

  // set S Exception Program Counter to the saved user pc.
  w_sepc(p->trapframe->epc);
    8000264c:	6d38                	ld	a4,88(a0)
  asm volatile("csrw sepc, %0" : : "r" (x));
    8000264e:	6f18                	ld	a4,24(a4)
    80002650:	14171073          	csrw	sepc,a4

  // tell trampoline.S the user page table to switch to.
  uint64 satp = MAKE_SATP(p->pagetable);
    80002654:	692c                	ld	a1,80(a0)
    80002656:	81b1                	srli	a1,a1,0xc

  // jump to trampoline.S at the top of memory, which 
  // switches to the user page table, restores user registers,
  // and switches to user mode with sret.
  uint64 fn = TRAMPOLINE + (userret - trampoline);
    80002658:	00005717          	auipc	a4,0x5
    8000265c:	a3870713          	addi	a4,a4,-1480 # 80007090 <userret>
    80002660:	8f15                	sub	a4,a4,a3
    80002662:	97ba                	add	a5,a5,a4
  ((void (*)(uint64,uint64))fn)(TRAPFRAME, satp);
    80002664:	577d                	li	a4,-1
    80002666:	177e                	slli	a4,a4,0x3f
    80002668:	8dd9                	or	a1,a1,a4
    8000266a:	02000537          	lui	a0,0x2000
    8000266e:	157d                	addi	a0,a0,-1 # 1ffffff <_entry-0x7e000001>
    80002670:	0536                	slli	a0,a0,0xd
    80002672:	9782                	jalr	a5
}
    80002674:	60a2                	ld	ra,8(sp)
    80002676:	6402                	ld	s0,0(sp)
    80002678:	0141                	addi	sp,sp,16
    8000267a:	8082                	ret

000000008000267c <clockintr>:
  w_sstatus(sstatus);
}

void
clockintr()
{
    8000267c:	1101                	addi	sp,sp,-32
    8000267e:	ec06                	sd	ra,24(sp)
    80002680:	e822                	sd	s0,16(sp)
    80002682:	e426                	sd	s1,8(sp)
    80002684:	1000                	addi	s0,sp,32
  acquire(&tickslock);
    80002686:	00015497          	auipc	s1,0x15
    8000268a:	a4a48493          	addi	s1,s1,-1462 # 800170d0 <tickslock>
    8000268e:	8526                	mv	a0,s1
    80002690:	ffffe097          	auipc	ra,0xffffe
    80002694:	51a080e7          	jalr	1306(ra) # 80000baa <acquire>
  ticks++;
    80002698:	00007517          	auipc	a0,0x7
    8000269c:	99850513          	addi	a0,a0,-1640 # 80009030 <ticks>
    800026a0:	411c                	lw	a5,0(a0)
    800026a2:	2785                	addiw	a5,a5,1
    800026a4:	c11c                	sw	a5,0(a0)
  wakeup(&ticks);
    800026a6:	00000097          	auipc	ra,0x0
    800026aa:	b1a080e7          	jalr	-1254(ra) # 800021c0 <wakeup>
  release(&tickslock);
    800026ae:	8526                	mv	a0,s1
    800026b0:	ffffe097          	auipc	ra,0xffffe
    800026b4:	5ae080e7          	jalr	1454(ra) # 80000c5e <release>
}
    800026b8:	60e2                	ld	ra,24(sp)
    800026ba:	6442                	ld	s0,16(sp)
    800026bc:	64a2                	ld	s1,8(sp)
    800026be:	6105                	addi	sp,sp,32
    800026c0:	8082                	ret

00000000800026c2 <devintr>:
// returns 2 if timer interrupt,
// 1 if other device,
// 0 if not recognized.
int
devintr()
{
    800026c2:	1101                	addi	sp,sp,-32
    800026c4:	ec06                	sd	ra,24(sp)
    800026c6:	e822                	sd	s0,16(sp)
    800026c8:	e426                	sd	s1,8(sp)
    800026ca:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, scause" : "=r" (x) );
    800026cc:	14202773          	csrr	a4,scause
  uint64 scause = r_scause();

  if((scause & 0x8000000000000000L) &&
    800026d0:	00074d63          	bltz	a4,800026ea <devintr+0x28>
    // now allowed to interrupt again.
    if(irq)
      plic_complete(irq);

    return 1;
  } else if(scause == 0x8000000000000001L){
    800026d4:	57fd                	li	a5,-1
    800026d6:	17fe                	slli	a5,a5,0x3f
    800026d8:	0785                	addi	a5,a5,1
    // the SSIP bit in sip.
    w_sip(r_sip() & ~2);

    return 2;
  } else {
    return 0;
    800026da:	4501                	li	a0,0
  } else if(scause == 0x8000000000000001L){
    800026dc:	06f70363          	beq	a4,a5,80002742 <devintr+0x80>
  }
}
    800026e0:	60e2                	ld	ra,24(sp)
    800026e2:	6442                	ld	s0,16(sp)
    800026e4:	64a2                	ld	s1,8(sp)
    800026e6:	6105                	addi	sp,sp,32
    800026e8:	8082                	ret
     (scause & 0xff) == 9){
    800026ea:	0ff77793          	zext.b	a5,a4
  if((scause & 0x8000000000000000L) &&
    800026ee:	46a5                	li	a3,9
    800026f0:	fed792e3          	bne	a5,a3,800026d4 <devintr+0x12>
    int irq = plic_claim();
    800026f4:	00003097          	auipc	ra,0x3
    800026f8:	484080e7          	jalr	1156(ra) # 80005b78 <plic_claim>
    800026fc:	84aa                	mv	s1,a0
    if(irq == UART0_IRQ){
    800026fe:	47a9                	li	a5,10
    80002700:	02f50763          	beq	a0,a5,8000272e <devintr+0x6c>
    } else if(irq == VIRTIO0_IRQ){
    80002704:	4785                	li	a5,1
    80002706:	02f50963          	beq	a0,a5,80002738 <devintr+0x76>
    return 1;
    8000270a:	4505                	li	a0,1
    } else if(irq){
    8000270c:	d8f1                	beqz	s1,800026e0 <devintr+0x1e>
      printf("unexpected interrupt irq=%d\n", irq);
    8000270e:	85a6                	mv	a1,s1
    80002710:	00006517          	auipc	a0,0x6
    80002714:	be850513          	addi	a0,a0,-1048 # 800082f8 <states.0+0x38>
    80002718:	ffffe097          	auipc	ra,0xffffe
    8000271c:	e6c080e7          	jalr	-404(ra) # 80000584 <printf>
      plic_complete(irq);
    80002720:	8526                	mv	a0,s1
    80002722:	00003097          	auipc	ra,0x3
    80002726:	47a080e7          	jalr	1146(ra) # 80005b9c <plic_complete>
    return 1;
    8000272a:	4505                	li	a0,1
    8000272c:	bf55                	j	800026e0 <devintr+0x1e>
      uartintr();
    8000272e:	ffffe097          	auipc	ra,0xffffe
    80002732:	264080e7          	jalr	612(ra) # 80000992 <uartintr>
    80002736:	b7ed                	j	80002720 <devintr+0x5e>
      virtio_disk_intr();
    80002738:	00004097          	auipc	ra,0x4
    8000273c:	8f0080e7          	jalr	-1808(ra) # 80006028 <virtio_disk_intr>
    80002740:	b7c5                	j	80002720 <devintr+0x5e>
    if(cpuid() == 0){
    80002742:	fffff097          	auipc	ra,0xfffff
    80002746:	202080e7          	jalr	514(ra) # 80001944 <cpuid>
    8000274a:	c901                	beqz	a0,8000275a <devintr+0x98>
  asm volatile("csrr %0, sip" : "=r" (x) );
    8000274c:	144027f3          	csrr	a5,sip
    w_sip(r_sip() & ~2);
    80002750:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sip, %0" : : "r" (x));
    80002752:	14479073          	csrw	sip,a5
    return 2;
    80002756:	4509                	li	a0,2
    80002758:	b761                	j	800026e0 <devintr+0x1e>
      clockintr();
    8000275a:	00000097          	auipc	ra,0x0
    8000275e:	f22080e7          	jalr	-222(ra) # 8000267c <clockintr>
    80002762:	b7ed                	j	8000274c <devintr+0x8a>

0000000080002764 <usertrap>:
{
    80002764:	1101                	addi	sp,sp,-32
    80002766:	ec06                	sd	ra,24(sp)
    80002768:	e822                	sd	s0,16(sp)
    8000276a:	e426                	sd	s1,8(sp)
    8000276c:	e04a                	sd	s2,0(sp)
    8000276e:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002770:	100027f3          	csrr	a5,sstatus
  if((r_sstatus() & SSTATUS_SPP) != 0)
    80002774:	1007f793          	andi	a5,a5,256
    80002778:	e3ad                	bnez	a5,800027da <usertrap+0x76>
  asm volatile("csrw stvec, %0" : : "r" (x));
    8000277a:	00003797          	auipc	a5,0x3
    8000277e:	2f678793          	addi	a5,a5,758 # 80005a70 <kernelvec>
    80002782:	10579073          	csrw	stvec,a5
  struct proc *p = myproc();
    80002786:	fffff097          	auipc	ra,0xfffff
    8000278a:	1ea080e7          	jalr	490(ra) # 80001970 <myproc>
    8000278e:	84aa                	mv	s1,a0
  p->trapframe->epc = r_sepc();
    80002790:	6d3c                	ld	a5,88(a0)
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002792:	14102773          	csrr	a4,sepc
    80002796:	ef98                	sd	a4,24(a5)
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002798:	14202773          	csrr	a4,scause
  if(r_scause() == 8){
    8000279c:	47a1                	li	a5,8
    8000279e:	04f71c63          	bne	a4,a5,800027f6 <usertrap+0x92>
    if(p->killed)
    800027a2:	551c                	lw	a5,40(a0)
    800027a4:	e3b9                	bnez	a5,800027ea <usertrap+0x86>
    p->trapframe->epc += 4;
    800027a6:	6cb8                	ld	a4,88(s1)
    800027a8:	6f1c                	ld	a5,24(a4)
    800027aa:	0791                	addi	a5,a5,4
    800027ac:	ef1c                	sd	a5,24(a4)
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    800027ae:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    800027b2:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    800027b6:	10079073          	csrw	sstatus,a5
    syscall();
    800027ba:	00000097          	auipc	ra,0x0
    800027be:	2e0080e7          	jalr	736(ra) # 80002a9a <syscall>
  if(p->killed)
    800027c2:	549c                	lw	a5,40(s1)
    800027c4:	ebc1                	bnez	a5,80002854 <usertrap+0xf0>
  usertrapret();
    800027c6:	00000097          	auipc	ra,0x0
    800027ca:	e18080e7          	jalr	-488(ra) # 800025de <usertrapret>
}
    800027ce:	60e2                	ld	ra,24(sp)
    800027d0:	6442                	ld	s0,16(sp)
    800027d2:	64a2                	ld	s1,8(sp)
    800027d4:	6902                	ld	s2,0(sp)
    800027d6:	6105                	addi	sp,sp,32
    800027d8:	8082                	ret
    panic("usertrap: not from user mode");
    800027da:	00006517          	auipc	a0,0x6
    800027de:	b3e50513          	addi	a0,a0,-1218 # 80008318 <states.0+0x58>
    800027e2:	ffffe097          	auipc	ra,0xffffe
    800027e6:	d58080e7          	jalr	-680(ra) # 8000053a <panic>
      exit(-1);
    800027ea:	557d                	li	a0,-1
    800027ec:	00000097          	auipc	ra,0x0
    800027f0:	aa4080e7          	jalr	-1372(ra) # 80002290 <exit>
    800027f4:	bf4d                	j	800027a6 <usertrap+0x42>
  } else if((which_dev = devintr()) != 0){
    800027f6:	00000097          	auipc	ra,0x0
    800027fa:	ecc080e7          	jalr	-308(ra) # 800026c2 <devintr>
    800027fe:	892a                	mv	s2,a0
    80002800:	c501                	beqz	a0,80002808 <usertrap+0xa4>
  if(p->killed)
    80002802:	549c                	lw	a5,40(s1)
    80002804:	c3a1                	beqz	a5,80002844 <usertrap+0xe0>
    80002806:	a815                	j	8000283a <usertrap+0xd6>
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002808:	142025f3          	csrr	a1,scause
    printf("usertrap(): unexpected scause %p pid=%d\n", r_scause(), p->pid);
    8000280c:	5890                	lw	a2,48(s1)
    8000280e:	00006517          	auipc	a0,0x6
    80002812:	b2a50513          	addi	a0,a0,-1238 # 80008338 <states.0+0x78>
    80002816:	ffffe097          	auipc	ra,0xffffe
    8000281a:	d6e080e7          	jalr	-658(ra) # 80000584 <printf>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    8000281e:	141025f3          	csrr	a1,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    80002822:	14302673          	csrr	a2,stval
    printf("            sepc=%p stval=%p\n", r_sepc(), r_stval());
    80002826:	00006517          	auipc	a0,0x6
    8000282a:	b4250513          	addi	a0,a0,-1214 # 80008368 <states.0+0xa8>
    8000282e:	ffffe097          	auipc	ra,0xffffe
    80002832:	d56080e7          	jalr	-682(ra) # 80000584 <printf>
    p->killed = 1;
    80002836:	4785                	li	a5,1
    80002838:	d49c                	sw	a5,40(s1)
    exit(-1);
    8000283a:	557d                	li	a0,-1
    8000283c:	00000097          	auipc	ra,0x0
    80002840:	a54080e7          	jalr	-1452(ra) # 80002290 <exit>
  if(which_dev == 2)
    80002844:	4789                	li	a5,2
    80002846:	f8f910e3          	bne	s2,a5,800027c6 <usertrap+0x62>
    yield();
    8000284a:	fffff097          	auipc	ra,0xfffff
    8000284e:	7ae080e7          	jalr	1966(ra) # 80001ff8 <yield>
    80002852:	bf95                	j	800027c6 <usertrap+0x62>
  int which_dev = 0;
    80002854:	4901                	li	s2,0
    80002856:	b7d5                	j	8000283a <usertrap+0xd6>

0000000080002858 <kerneltrap>:
{
    80002858:	7179                	addi	sp,sp,-48
    8000285a:	f406                	sd	ra,40(sp)
    8000285c:	f022                	sd	s0,32(sp)
    8000285e:	ec26                	sd	s1,24(sp)
    80002860:	e84a                	sd	s2,16(sp)
    80002862:	e44e                	sd	s3,8(sp)
    80002864:	1800                	addi	s0,sp,48
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002866:	14102973          	csrr	s2,sepc
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    8000286a:	100024f3          	csrr	s1,sstatus
  asm volatile("csrr %0, scause" : "=r" (x) );
    8000286e:	142029f3          	csrr	s3,scause
  if((sstatus & SSTATUS_SPP) == 0)
    80002872:	1004f793          	andi	a5,s1,256
    80002876:	cb85                	beqz	a5,800028a6 <kerneltrap+0x4e>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002878:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    8000287c:	8b89                	andi	a5,a5,2
  if(intr_get() != 0)
    8000287e:	ef85                	bnez	a5,800028b6 <kerneltrap+0x5e>
  if((which_dev = devintr()) == 0){
    80002880:	00000097          	auipc	ra,0x0
    80002884:	e42080e7          	jalr	-446(ra) # 800026c2 <devintr>
    80002888:	cd1d                	beqz	a0,800028c6 <kerneltrap+0x6e>
  if(which_dev == 2 && myproc() != 0 && myproc()->state == RUNNING)
    8000288a:	4789                	li	a5,2
    8000288c:	06f50a63          	beq	a0,a5,80002900 <kerneltrap+0xa8>
  asm volatile("csrw sepc, %0" : : "r" (x));
    80002890:	14191073          	csrw	sepc,s2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002894:	10049073          	csrw	sstatus,s1
}
    80002898:	70a2                	ld	ra,40(sp)
    8000289a:	7402                	ld	s0,32(sp)
    8000289c:	64e2                	ld	s1,24(sp)
    8000289e:	6942                	ld	s2,16(sp)
    800028a0:	69a2                	ld	s3,8(sp)
    800028a2:	6145                	addi	sp,sp,48
    800028a4:	8082                	ret
    panic("kerneltrap: not from supervisor mode");
    800028a6:	00006517          	auipc	a0,0x6
    800028aa:	ae250513          	addi	a0,a0,-1310 # 80008388 <states.0+0xc8>
    800028ae:	ffffe097          	auipc	ra,0xffffe
    800028b2:	c8c080e7          	jalr	-884(ra) # 8000053a <panic>
    panic("kerneltrap: interrupts enabled");
    800028b6:	00006517          	auipc	a0,0x6
    800028ba:	afa50513          	addi	a0,a0,-1286 # 800083b0 <states.0+0xf0>
    800028be:	ffffe097          	auipc	ra,0xffffe
    800028c2:	c7c080e7          	jalr	-900(ra) # 8000053a <panic>
    printf("scause %p\n", scause);
    800028c6:	85ce                	mv	a1,s3
    800028c8:	00006517          	auipc	a0,0x6
    800028cc:	b0850513          	addi	a0,a0,-1272 # 800083d0 <states.0+0x110>
    800028d0:	ffffe097          	auipc	ra,0xffffe
    800028d4:	cb4080e7          	jalr	-844(ra) # 80000584 <printf>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    800028d8:	141025f3          	csrr	a1,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    800028dc:	14302673          	csrr	a2,stval
    printf("sepc=%p stval=%p\n", r_sepc(), r_stval());
    800028e0:	00006517          	auipc	a0,0x6
    800028e4:	b0050513          	addi	a0,a0,-1280 # 800083e0 <states.0+0x120>
    800028e8:	ffffe097          	auipc	ra,0xffffe
    800028ec:	c9c080e7          	jalr	-868(ra) # 80000584 <printf>
    panic("kerneltrap");
    800028f0:	00006517          	auipc	a0,0x6
    800028f4:	b0850513          	addi	a0,a0,-1272 # 800083f8 <states.0+0x138>
    800028f8:	ffffe097          	auipc	ra,0xffffe
    800028fc:	c42080e7          	jalr	-958(ra) # 8000053a <panic>
  if(which_dev == 2 && myproc() != 0 && myproc()->state == RUNNING)
    80002900:	fffff097          	auipc	ra,0xfffff
    80002904:	070080e7          	jalr	112(ra) # 80001970 <myproc>
    80002908:	d541                	beqz	a0,80002890 <kerneltrap+0x38>
    8000290a:	fffff097          	auipc	ra,0xfffff
    8000290e:	066080e7          	jalr	102(ra) # 80001970 <myproc>
    80002912:	4d18                	lw	a4,24(a0)
    80002914:	4791                	li	a5,4
    80002916:	f6f71de3          	bne	a4,a5,80002890 <kerneltrap+0x38>
    yield();
    8000291a:	fffff097          	auipc	ra,0xfffff
    8000291e:	6de080e7          	jalr	1758(ra) # 80001ff8 <yield>
    80002922:	b7bd                	j	80002890 <kerneltrap+0x38>

0000000080002924 <argraw>:
  return strlen(buf);
}

static uint64
argraw(int n)
{
    80002924:	1101                	addi	sp,sp,-32
    80002926:	ec06                	sd	ra,24(sp)
    80002928:	e822                	sd	s0,16(sp)
    8000292a:	e426                	sd	s1,8(sp)
    8000292c:	1000                	addi	s0,sp,32
    8000292e:	84aa                	mv	s1,a0
  struct proc *p = myproc();
    80002930:	fffff097          	auipc	ra,0xfffff
    80002934:	040080e7          	jalr	64(ra) # 80001970 <myproc>
  switch (n) {
    80002938:	4795                	li	a5,5
    8000293a:	0497e163          	bltu	a5,s1,8000297c <argraw+0x58>
    8000293e:	048a                	slli	s1,s1,0x2
    80002940:	00006717          	auipc	a4,0x6
    80002944:	af070713          	addi	a4,a4,-1296 # 80008430 <states.0+0x170>
    80002948:	94ba                	add	s1,s1,a4
    8000294a:	409c                	lw	a5,0(s1)
    8000294c:	97ba                	add	a5,a5,a4
    8000294e:	8782                	jr	a5
  case 0:
    return p->trapframe->a0;
    80002950:	6d3c                	ld	a5,88(a0)
    80002952:	7ba8                	ld	a0,112(a5)
  case 5:
    return p->trapframe->a5;
  }
  panic("argraw");
  return -1;
}
    80002954:	60e2                	ld	ra,24(sp)
    80002956:	6442                	ld	s0,16(sp)
    80002958:	64a2                	ld	s1,8(sp)
    8000295a:	6105                	addi	sp,sp,32
    8000295c:	8082                	ret
    return p->trapframe->a1;
    8000295e:	6d3c                	ld	a5,88(a0)
    80002960:	7fa8                	ld	a0,120(a5)
    80002962:	bfcd                	j	80002954 <argraw+0x30>
    return p->trapframe->a2;
    80002964:	6d3c                	ld	a5,88(a0)
    80002966:	63c8                	ld	a0,128(a5)
    80002968:	b7f5                	j	80002954 <argraw+0x30>
    return p->trapframe->a3;
    8000296a:	6d3c                	ld	a5,88(a0)
    8000296c:	67c8                	ld	a0,136(a5)
    8000296e:	b7dd                	j	80002954 <argraw+0x30>
    return p->trapframe->a4;
    80002970:	6d3c                	ld	a5,88(a0)
    80002972:	6bc8                	ld	a0,144(a5)
    80002974:	b7c5                	j	80002954 <argraw+0x30>
    return p->trapframe->a5;
    80002976:	6d3c                	ld	a5,88(a0)
    80002978:	6fc8                	ld	a0,152(a5)
    8000297a:	bfe9                	j	80002954 <argraw+0x30>
  panic("argraw");
    8000297c:	00006517          	auipc	a0,0x6
    80002980:	a8c50513          	addi	a0,a0,-1396 # 80008408 <states.0+0x148>
    80002984:	ffffe097          	auipc	ra,0xffffe
    80002988:	bb6080e7          	jalr	-1098(ra) # 8000053a <panic>

000000008000298c <fetchaddr>:
{
    8000298c:	1101                	addi	sp,sp,-32
    8000298e:	ec06                	sd	ra,24(sp)
    80002990:	e822                	sd	s0,16(sp)
    80002992:	e426                	sd	s1,8(sp)
    80002994:	e04a                	sd	s2,0(sp)
    80002996:	1000                	addi	s0,sp,32
    80002998:	84aa                	mv	s1,a0
    8000299a:	892e                	mv	s2,a1
  struct proc *p = myproc();
    8000299c:	fffff097          	auipc	ra,0xfffff
    800029a0:	fd4080e7          	jalr	-44(ra) # 80001970 <myproc>
  if(addr >= p->sz || addr+sizeof(uint64) > p->sz)
    800029a4:	653c                	ld	a5,72(a0)
    800029a6:	02f4f863          	bgeu	s1,a5,800029d6 <fetchaddr+0x4a>
    800029aa:	00848713          	addi	a4,s1,8
    800029ae:	02e7e663          	bltu	a5,a4,800029da <fetchaddr+0x4e>
  if(copyin(p->pagetable, (char *)ip, addr, sizeof(*ip)) != 0)
    800029b2:	46a1                	li	a3,8
    800029b4:	8626                	mv	a2,s1
    800029b6:	85ca                	mv	a1,s2
    800029b8:	6928                	ld	a0,80(a0)
    800029ba:	fffff097          	auipc	ra,0xfffff
    800029be:	d06080e7          	jalr	-762(ra) # 800016c0 <copyin>
    800029c2:	00a03533          	snez	a0,a0
    800029c6:	40a00533          	neg	a0,a0
}
    800029ca:	60e2                	ld	ra,24(sp)
    800029cc:	6442                	ld	s0,16(sp)
    800029ce:	64a2                	ld	s1,8(sp)
    800029d0:	6902                	ld	s2,0(sp)
    800029d2:	6105                	addi	sp,sp,32
    800029d4:	8082                	ret
    return -1;
    800029d6:	557d                	li	a0,-1
    800029d8:	bfcd                	j	800029ca <fetchaddr+0x3e>
    800029da:	557d                	li	a0,-1
    800029dc:	b7fd                	j	800029ca <fetchaddr+0x3e>

00000000800029de <fetchstr>:
{
    800029de:	7179                	addi	sp,sp,-48
    800029e0:	f406                	sd	ra,40(sp)
    800029e2:	f022                	sd	s0,32(sp)
    800029e4:	ec26                	sd	s1,24(sp)
    800029e6:	e84a                	sd	s2,16(sp)
    800029e8:	e44e                	sd	s3,8(sp)
    800029ea:	1800                	addi	s0,sp,48
    800029ec:	892a                	mv	s2,a0
    800029ee:	84ae                	mv	s1,a1
    800029f0:	89b2                	mv	s3,a2
  struct proc *p = myproc();
    800029f2:	fffff097          	auipc	ra,0xfffff
    800029f6:	f7e080e7          	jalr	-130(ra) # 80001970 <myproc>
  int err = copyinstr(p->pagetable, buf, addr, max);
    800029fa:	86ce                	mv	a3,s3
    800029fc:	864a                	mv	a2,s2
    800029fe:	85a6                	mv	a1,s1
    80002a00:	6928                	ld	a0,80(a0)
    80002a02:	fffff097          	auipc	ra,0xfffff
    80002a06:	d4c080e7          	jalr	-692(ra) # 8000174e <copyinstr>
  if(err < 0)
    80002a0a:	00054763          	bltz	a0,80002a18 <fetchstr+0x3a>
  return strlen(buf);
    80002a0e:	8526                	mv	a0,s1
    80002a10:	ffffe097          	auipc	ra,0xffffe
    80002a14:	412080e7          	jalr	1042(ra) # 80000e22 <strlen>
}
    80002a18:	70a2                	ld	ra,40(sp)
    80002a1a:	7402                	ld	s0,32(sp)
    80002a1c:	64e2                	ld	s1,24(sp)
    80002a1e:	6942                	ld	s2,16(sp)
    80002a20:	69a2                	ld	s3,8(sp)
    80002a22:	6145                	addi	sp,sp,48
    80002a24:	8082                	ret

0000000080002a26 <argint>:

// Fetch the nth 32-bit system call argument.
int
argint(int n, int *ip)
{
    80002a26:	1101                	addi	sp,sp,-32
    80002a28:	ec06                	sd	ra,24(sp)
    80002a2a:	e822                	sd	s0,16(sp)
    80002a2c:	e426                	sd	s1,8(sp)
    80002a2e:	1000                	addi	s0,sp,32
    80002a30:	84ae                	mv	s1,a1
  *ip = argraw(n);
    80002a32:	00000097          	auipc	ra,0x0
    80002a36:	ef2080e7          	jalr	-270(ra) # 80002924 <argraw>
    80002a3a:	c088                	sw	a0,0(s1)
  return 0;
}
    80002a3c:	4501                	li	a0,0
    80002a3e:	60e2                	ld	ra,24(sp)
    80002a40:	6442                	ld	s0,16(sp)
    80002a42:	64a2                	ld	s1,8(sp)
    80002a44:	6105                	addi	sp,sp,32
    80002a46:	8082                	ret

0000000080002a48 <argaddr>:
// Retrieve an argument as a pointer.
// Doesn't check for legality, since
// copyin/copyout will do that.
int
argaddr(int n, uint64 *ip)
{
    80002a48:	1101                	addi	sp,sp,-32
    80002a4a:	ec06                	sd	ra,24(sp)
    80002a4c:	e822                	sd	s0,16(sp)
    80002a4e:	e426                	sd	s1,8(sp)
    80002a50:	1000                	addi	s0,sp,32
    80002a52:	84ae                	mv	s1,a1
  *ip = argraw(n);
    80002a54:	00000097          	auipc	ra,0x0
    80002a58:	ed0080e7          	jalr	-304(ra) # 80002924 <argraw>
    80002a5c:	e088                	sd	a0,0(s1)
  return 0;
}
    80002a5e:	4501                	li	a0,0
    80002a60:	60e2                	ld	ra,24(sp)
    80002a62:	6442                	ld	s0,16(sp)
    80002a64:	64a2                	ld	s1,8(sp)
    80002a66:	6105                	addi	sp,sp,32
    80002a68:	8082                	ret

0000000080002a6a <argstr>:
// Fetch the nth word-sized system call argument as a null-terminated string.
// Copies into buf, at most max.
// Returns string length if OK (including nul), -1 if error.
int
argstr(int n, char *buf, int max)
{
    80002a6a:	1101                	addi	sp,sp,-32
    80002a6c:	ec06                	sd	ra,24(sp)
    80002a6e:	e822                	sd	s0,16(sp)
    80002a70:	e426                	sd	s1,8(sp)
    80002a72:	e04a                	sd	s2,0(sp)
    80002a74:	1000                	addi	s0,sp,32
    80002a76:	84ae                	mv	s1,a1
    80002a78:	8932                	mv	s2,a2
  *ip = argraw(n);
    80002a7a:	00000097          	auipc	ra,0x0
    80002a7e:	eaa080e7          	jalr	-342(ra) # 80002924 <argraw>
  uint64 addr;
  if(argaddr(n, &addr) < 0)
    return -1;
  return fetchstr(addr, buf, max);
    80002a82:	864a                	mv	a2,s2
    80002a84:	85a6                	mv	a1,s1
    80002a86:	00000097          	auipc	ra,0x0
    80002a8a:	f58080e7          	jalr	-168(ra) # 800029de <fetchstr>
}
    80002a8e:	60e2                	ld	ra,24(sp)
    80002a90:	6442                	ld	s0,16(sp)
    80002a92:	64a2                	ld	s1,8(sp)
    80002a94:	6902                	ld	s2,0(sp)
    80002a96:	6105                	addi	sp,sp,32
    80002a98:	8082                	ret

0000000080002a9a <syscall>:
[SYS_close]   sys_close,
};

void
syscall(void)
{
    80002a9a:	1101                	addi	sp,sp,-32
    80002a9c:	ec06                	sd	ra,24(sp)
    80002a9e:	e822                	sd	s0,16(sp)
    80002aa0:	e426                	sd	s1,8(sp)
    80002aa2:	e04a                	sd	s2,0(sp)
    80002aa4:	1000                	addi	s0,sp,32
  int num;
  struct proc *p = myproc();
    80002aa6:	fffff097          	auipc	ra,0xfffff
    80002aaa:	eca080e7          	jalr	-310(ra) # 80001970 <myproc>
    80002aae:	84aa                	mv	s1,a0

  num = p->trapframe->a7;
    80002ab0:	05853903          	ld	s2,88(a0)
    80002ab4:	0a893783          	ld	a5,168(s2)
    80002ab8:	0007869b          	sext.w	a3,a5
  if(num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    80002abc:	37fd                	addiw	a5,a5,-1
    80002abe:	4751                	li	a4,20
    80002ac0:	00f76f63          	bltu	a4,a5,80002ade <syscall+0x44>
    80002ac4:	00369713          	slli	a4,a3,0x3
    80002ac8:	00006797          	auipc	a5,0x6
    80002acc:	98078793          	addi	a5,a5,-1664 # 80008448 <syscalls>
    80002ad0:	97ba                	add	a5,a5,a4
    80002ad2:	639c                	ld	a5,0(a5)
    80002ad4:	c789                	beqz	a5,80002ade <syscall+0x44>
    p->trapframe->a0 = syscalls[num]();
    80002ad6:	9782                	jalr	a5
    80002ad8:	06a93823          	sd	a0,112(s2)
    80002adc:	a839                	j	80002afa <syscall+0x60>
  } else {
    printf("%d %s: unknown sys call %d\n",
    80002ade:	15848613          	addi	a2,s1,344
    80002ae2:	588c                	lw	a1,48(s1)
    80002ae4:	00006517          	auipc	a0,0x6
    80002ae8:	92c50513          	addi	a0,a0,-1748 # 80008410 <states.0+0x150>
    80002aec:	ffffe097          	auipc	ra,0xffffe
    80002af0:	a98080e7          	jalr	-1384(ra) # 80000584 <printf>
            p->pid, p->name, num);
    p->trapframe->a0 = -1;
    80002af4:	6cbc                	ld	a5,88(s1)
    80002af6:	577d                	li	a4,-1
    80002af8:	fbb8                	sd	a4,112(a5)
  }
}
    80002afa:	60e2                	ld	ra,24(sp)
    80002afc:	6442                	ld	s0,16(sp)
    80002afe:	64a2                	ld	s1,8(sp)
    80002b00:	6902                	ld	s2,0(sp)
    80002b02:	6105                	addi	sp,sp,32
    80002b04:	8082                	ret

0000000080002b06 <sys_exit>:
#include "spinlock.h"
#include "proc.h"

uint64
sys_exit(void)
{
    80002b06:	1101                	addi	sp,sp,-32
    80002b08:	ec06                	sd	ra,24(sp)
    80002b0a:	e822                	sd	s0,16(sp)
    80002b0c:	1000                	addi	s0,sp,32
  int n;
  if(argint(0, &n) < 0)
    80002b0e:	fec40593          	addi	a1,s0,-20
    80002b12:	4501                	li	a0,0
    80002b14:	00000097          	auipc	ra,0x0
    80002b18:	f12080e7          	jalr	-238(ra) # 80002a26 <argint>
    return -1;
    80002b1c:	57fd                	li	a5,-1
  if(argint(0, &n) < 0)
    80002b1e:	00054963          	bltz	a0,80002b30 <sys_exit+0x2a>
  exit(n);
    80002b22:	fec42503          	lw	a0,-20(s0)
    80002b26:	fffff097          	auipc	ra,0xfffff
    80002b2a:	76a080e7          	jalr	1898(ra) # 80002290 <exit>
  return 0;  // not reached
    80002b2e:	4781                	li	a5,0
}
    80002b30:	853e                	mv	a0,a5
    80002b32:	60e2                	ld	ra,24(sp)
    80002b34:	6442                	ld	s0,16(sp)
    80002b36:	6105                	addi	sp,sp,32
    80002b38:	8082                	ret

0000000080002b3a <sys_getpid>:

uint64
sys_getpid(void)
{
    80002b3a:	1141                	addi	sp,sp,-16
    80002b3c:	e406                	sd	ra,8(sp)
    80002b3e:	e022                	sd	s0,0(sp)
    80002b40:	0800                	addi	s0,sp,16
  return myproc()->pid;
    80002b42:	fffff097          	auipc	ra,0xfffff
    80002b46:	e2e080e7          	jalr	-466(ra) # 80001970 <myproc>
}
    80002b4a:	5908                	lw	a0,48(a0)
    80002b4c:	60a2                	ld	ra,8(sp)
    80002b4e:	6402                	ld	s0,0(sp)
    80002b50:	0141                	addi	sp,sp,16
    80002b52:	8082                	ret

0000000080002b54 <sys_fork>:

uint64
sys_fork(void)
{
    80002b54:	1141                	addi	sp,sp,-16
    80002b56:	e406                	sd	ra,8(sp)
    80002b58:	e022                	sd	s0,0(sp)
    80002b5a:	0800                	addi	s0,sp,16
  return fork();
    80002b5c:	fffff097          	auipc	ra,0xfffff
    80002b60:	1e6080e7          	jalr	486(ra) # 80001d42 <fork>
}
    80002b64:	60a2                	ld	ra,8(sp)
    80002b66:	6402                	ld	s0,0(sp)
    80002b68:	0141                	addi	sp,sp,16
    80002b6a:	8082                	ret

0000000080002b6c <sys_wait>:

uint64
sys_wait(void)
{
    80002b6c:	1101                	addi	sp,sp,-32
    80002b6e:	ec06                	sd	ra,24(sp)
    80002b70:	e822                	sd	s0,16(sp)
    80002b72:	1000                	addi	s0,sp,32
  uint64 p;
  if(argaddr(0, &p) < 0)
    80002b74:	fe840593          	addi	a1,s0,-24
    80002b78:	4501                	li	a0,0
    80002b7a:	00000097          	auipc	ra,0x0
    80002b7e:	ece080e7          	jalr	-306(ra) # 80002a48 <argaddr>
    80002b82:	87aa                	mv	a5,a0
    return -1;
    80002b84:	557d                	li	a0,-1
  if(argaddr(0, &p) < 0)
    80002b86:	0007c863          	bltz	a5,80002b96 <sys_wait+0x2a>
  return wait(p);
    80002b8a:	fe843503          	ld	a0,-24(s0)
    80002b8e:	fffff097          	auipc	ra,0xfffff
    80002b92:	50a080e7          	jalr	1290(ra) # 80002098 <wait>
}
    80002b96:	60e2                	ld	ra,24(sp)
    80002b98:	6442                	ld	s0,16(sp)
    80002b9a:	6105                	addi	sp,sp,32
    80002b9c:	8082                	ret

0000000080002b9e <sys_sbrk>:

uint64
sys_sbrk(void)
{
    80002b9e:	7179                	addi	sp,sp,-48
    80002ba0:	f406                	sd	ra,40(sp)
    80002ba2:	f022                	sd	s0,32(sp)
    80002ba4:	ec26                	sd	s1,24(sp)
    80002ba6:	1800                	addi	s0,sp,48
  int addr;
  int n;

  if(argint(0, &n) < 0)
    80002ba8:	fdc40593          	addi	a1,s0,-36
    80002bac:	4501                	li	a0,0
    80002bae:	00000097          	auipc	ra,0x0
    80002bb2:	e78080e7          	jalr	-392(ra) # 80002a26 <argint>
    80002bb6:	87aa                	mv	a5,a0
    return -1;
    80002bb8:	557d                	li	a0,-1
  if(argint(0, &n) < 0)
    80002bba:	0207c063          	bltz	a5,80002bda <sys_sbrk+0x3c>
  addr = myproc()->sz;
    80002bbe:	fffff097          	auipc	ra,0xfffff
    80002bc2:	db2080e7          	jalr	-590(ra) # 80001970 <myproc>
    80002bc6:	4524                	lw	s1,72(a0)
  if(growproc(n) < 0)
    80002bc8:	fdc42503          	lw	a0,-36(s0)
    80002bcc:	fffff097          	auipc	ra,0xfffff
    80002bd0:	0fe080e7          	jalr	254(ra) # 80001cca <growproc>
    80002bd4:	00054863          	bltz	a0,80002be4 <sys_sbrk+0x46>
    return -1;
  return addr;
    80002bd8:	8526                	mv	a0,s1
}
    80002bda:	70a2                	ld	ra,40(sp)
    80002bdc:	7402                	ld	s0,32(sp)
    80002bde:	64e2                	ld	s1,24(sp)
    80002be0:	6145                	addi	sp,sp,48
    80002be2:	8082                	ret
    return -1;
    80002be4:	557d                	li	a0,-1
    80002be6:	bfd5                	j	80002bda <sys_sbrk+0x3c>

0000000080002be8 <sys_sleep>:

uint64
sys_sleep(void)
{
    80002be8:	7139                	addi	sp,sp,-64
    80002bea:	fc06                	sd	ra,56(sp)
    80002bec:	f822                	sd	s0,48(sp)
    80002bee:	f426                	sd	s1,40(sp)
    80002bf0:	f04a                	sd	s2,32(sp)
    80002bf2:	ec4e                	sd	s3,24(sp)
    80002bf4:	0080                	addi	s0,sp,64
  int n;
  uint ticks0;

  if(argint(0, &n) < 0)
    80002bf6:	fcc40593          	addi	a1,s0,-52
    80002bfa:	4501                	li	a0,0
    80002bfc:	00000097          	auipc	ra,0x0
    80002c00:	e2a080e7          	jalr	-470(ra) # 80002a26 <argint>
    return -1;
    80002c04:	57fd                	li	a5,-1
  if(argint(0, &n) < 0)
    80002c06:	06054563          	bltz	a0,80002c70 <sys_sleep+0x88>
  acquire(&tickslock);
    80002c0a:	00014517          	auipc	a0,0x14
    80002c0e:	4c650513          	addi	a0,a0,1222 # 800170d0 <tickslock>
    80002c12:	ffffe097          	auipc	ra,0xffffe
    80002c16:	f98080e7          	jalr	-104(ra) # 80000baa <acquire>
  ticks0 = ticks;
    80002c1a:	00006917          	auipc	s2,0x6
    80002c1e:	41692903          	lw	s2,1046(s2) # 80009030 <ticks>
  while(ticks - ticks0 < n){
    80002c22:	fcc42783          	lw	a5,-52(s0)
    80002c26:	cf85                	beqz	a5,80002c5e <sys_sleep+0x76>
    if(myproc()->killed){
      release(&tickslock);
      return -1;
    }
    sleep(&ticks, &tickslock);
    80002c28:	00014997          	auipc	s3,0x14
    80002c2c:	4a898993          	addi	s3,s3,1192 # 800170d0 <tickslock>
    80002c30:	00006497          	auipc	s1,0x6
    80002c34:	40048493          	addi	s1,s1,1024 # 80009030 <ticks>
    if(myproc()->killed){
    80002c38:	fffff097          	auipc	ra,0xfffff
    80002c3c:	d38080e7          	jalr	-712(ra) # 80001970 <myproc>
    80002c40:	551c                	lw	a5,40(a0)
    80002c42:	ef9d                	bnez	a5,80002c80 <sys_sleep+0x98>
    sleep(&ticks, &tickslock);
    80002c44:	85ce                	mv	a1,s3
    80002c46:	8526                	mv	a0,s1
    80002c48:	fffff097          	auipc	ra,0xfffff
    80002c4c:	3ec080e7          	jalr	1004(ra) # 80002034 <sleep>
  while(ticks - ticks0 < n){
    80002c50:	409c                	lw	a5,0(s1)
    80002c52:	412787bb          	subw	a5,a5,s2
    80002c56:	fcc42703          	lw	a4,-52(s0)
    80002c5a:	fce7efe3          	bltu	a5,a4,80002c38 <sys_sleep+0x50>
  }
  release(&tickslock);
    80002c5e:	00014517          	auipc	a0,0x14
    80002c62:	47250513          	addi	a0,a0,1138 # 800170d0 <tickslock>
    80002c66:	ffffe097          	auipc	ra,0xffffe
    80002c6a:	ff8080e7          	jalr	-8(ra) # 80000c5e <release>
  return 0;
    80002c6e:	4781                	li	a5,0
}
    80002c70:	853e                	mv	a0,a5
    80002c72:	70e2                	ld	ra,56(sp)
    80002c74:	7442                	ld	s0,48(sp)
    80002c76:	74a2                	ld	s1,40(sp)
    80002c78:	7902                	ld	s2,32(sp)
    80002c7a:	69e2                	ld	s3,24(sp)
    80002c7c:	6121                	addi	sp,sp,64
    80002c7e:	8082                	ret
      release(&tickslock);
    80002c80:	00014517          	auipc	a0,0x14
    80002c84:	45050513          	addi	a0,a0,1104 # 800170d0 <tickslock>
    80002c88:	ffffe097          	auipc	ra,0xffffe
    80002c8c:	fd6080e7          	jalr	-42(ra) # 80000c5e <release>
      return -1;
    80002c90:	57fd                	li	a5,-1
    80002c92:	bff9                	j	80002c70 <sys_sleep+0x88>

0000000080002c94 <sys_kill>:

uint64
sys_kill(void)
{
    80002c94:	1101                	addi	sp,sp,-32
    80002c96:	ec06                	sd	ra,24(sp)
    80002c98:	e822                	sd	s0,16(sp)
    80002c9a:	1000                	addi	s0,sp,32
  int pid;

  if(argint(0, &pid) < 0)
    80002c9c:	fec40593          	addi	a1,s0,-20
    80002ca0:	4501                	li	a0,0
    80002ca2:	00000097          	auipc	ra,0x0
    80002ca6:	d84080e7          	jalr	-636(ra) # 80002a26 <argint>
    80002caa:	87aa                	mv	a5,a0
    return -1;
    80002cac:	557d                	li	a0,-1
  if(argint(0, &pid) < 0)
    80002cae:	0007c863          	bltz	a5,80002cbe <sys_kill+0x2a>
  return kill(pid);
    80002cb2:	fec42503          	lw	a0,-20(s0)
    80002cb6:	fffff097          	auipc	ra,0xfffff
    80002cba:	6b0080e7          	jalr	1712(ra) # 80002366 <kill>
}
    80002cbe:	60e2                	ld	ra,24(sp)
    80002cc0:	6442                	ld	s0,16(sp)
    80002cc2:	6105                	addi	sp,sp,32
    80002cc4:	8082                	ret

0000000080002cc6 <sys_uptime>:

// return how many clock tick interrupts have occurred
// since start.
uint64
sys_uptime(void)
{
    80002cc6:	1101                	addi	sp,sp,-32
    80002cc8:	ec06                	sd	ra,24(sp)
    80002cca:	e822                	sd	s0,16(sp)
    80002ccc:	e426                	sd	s1,8(sp)
    80002cce:	1000                	addi	s0,sp,32
  uint xticks;

  acquire(&tickslock);
    80002cd0:	00014517          	auipc	a0,0x14
    80002cd4:	40050513          	addi	a0,a0,1024 # 800170d0 <tickslock>
    80002cd8:	ffffe097          	auipc	ra,0xffffe
    80002cdc:	ed2080e7          	jalr	-302(ra) # 80000baa <acquire>
  xticks = ticks;
    80002ce0:	00006497          	auipc	s1,0x6
    80002ce4:	3504a483          	lw	s1,848(s1) # 80009030 <ticks>
  release(&tickslock);
    80002ce8:	00014517          	auipc	a0,0x14
    80002cec:	3e850513          	addi	a0,a0,1000 # 800170d0 <tickslock>
    80002cf0:	ffffe097          	auipc	ra,0xffffe
    80002cf4:	f6e080e7          	jalr	-146(ra) # 80000c5e <release>
  return xticks;
}
    80002cf8:	02049513          	slli	a0,s1,0x20
    80002cfc:	9101                	srli	a0,a0,0x20
    80002cfe:	60e2                	ld	ra,24(sp)
    80002d00:	6442                	ld	s0,16(sp)
    80002d02:	64a2                	ld	s1,8(sp)
    80002d04:	6105                	addi	sp,sp,32
    80002d06:	8082                	ret

0000000080002d08 <binit>:
  struct buf head;
} bcache;

void
binit(void)
{
    80002d08:	7179                	addi	sp,sp,-48
    80002d0a:	f406                	sd	ra,40(sp)
    80002d0c:	f022                	sd	s0,32(sp)
    80002d0e:	ec26                	sd	s1,24(sp)
    80002d10:	e84a                	sd	s2,16(sp)
    80002d12:	e44e                	sd	s3,8(sp)
    80002d14:	e052                	sd	s4,0(sp)
    80002d16:	1800                	addi	s0,sp,48
  struct buf *b;

  initlock(&bcache.lock, "bcache");
    80002d18:	00005597          	auipc	a1,0x5
    80002d1c:	7e058593          	addi	a1,a1,2016 # 800084f8 <syscalls+0xb0>
    80002d20:	00014517          	auipc	a0,0x14
    80002d24:	3c850513          	addi	a0,a0,968 # 800170e8 <bcache>
    80002d28:	ffffe097          	auipc	ra,0xffffe
    80002d2c:	df2080e7          	jalr	-526(ra) # 80000b1a <initlock>

  // Create linked list of buffers
  bcache.head.prev = &bcache.head;
    80002d30:	0001c797          	auipc	a5,0x1c
    80002d34:	3b878793          	addi	a5,a5,952 # 8001f0e8 <bcache+0x8000>
    80002d38:	0001c717          	auipc	a4,0x1c
    80002d3c:	61870713          	addi	a4,a4,1560 # 8001f350 <bcache+0x8268>
    80002d40:	2ae7b823          	sd	a4,688(a5)
  bcache.head.next = &bcache.head;
    80002d44:	2ae7bc23          	sd	a4,696(a5)
  for(b = bcache.buf; b < bcache.buf+NBUF; b++){
    80002d48:	00014497          	auipc	s1,0x14
    80002d4c:	3b848493          	addi	s1,s1,952 # 80017100 <bcache+0x18>
    b->next = bcache.head.next;
    80002d50:	893e                	mv	s2,a5
    b->prev = &bcache.head;
    80002d52:	89ba                	mv	s3,a4
    initsleeplock(&b->lock, "buffer");
    80002d54:	00005a17          	auipc	s4,0x5
    80002d58:	7aca0a13          	addi	s4,s4,1964 # 80008500 <syscalls+0xb8>
    b->next = bcache.head.next;
    80002d5c:	2b893783          	ld	a5,696(s2)
    80002d60:	e8bc                	sd	a5,80(s1)
    b->prev = &bcache.head;
    80002d62:	0534b423          	sd	s3,72(s1)
    initsleeplock(&b->lock, "buffer");
    80002d66:	85d2                	mv	a1,s4
    80002d68:	01048513          	addi	a0,s1,16
    80002d6c:	00001097          	auipc	ra,0x1
    80002d70:	4c2080e7          	jalr	1218(ra) # 8000422e <initsleeplock>
    bcache.head.next->prev = b;
    80002d74:	2b893783          	ld	a5,696(s2)
    80002d78:	e7a4                	sd	s1,72(a5)
    bcache.head.next = b;
    80002d7a:	2a993c23          	sd	s1,696(s2)
  for(b = bcache.buf; b < bcache.buf+NBUF; b++){
    80002d7e:	45848493          	addi	s1,s1,1112
    80002d82:	fd349de3          	bne	s1,s3,80002d5c <binit+0x54>
  }
}
    80002d86:	70a2                	ld	ra,40(sp)
    80002d88:	7402                	ld	s0,32(sp)
    80002d8a:	64e2                	ld	s1,24(sp)
    80002d8c:	6942                	ld	s2,16(sp)
    80002d8e:	69a2                	ld	s3,8(sp)
    80002d90:	6a02                	ld	s4,0(sp)
    80002d92:	6145                	addi	sp,sp,48
    80002d94:	8082                	ret

0000000080002d96 <bread>:
}

// Return a locked buf with the contents of the indicated block.
struct buf*
bread(uint dev, uint blockno)
{
    80002d96:	7179                	addi	sp,sp,-48
    80002d98:	f406                	sd	ra,40(sp)
    80002d9a:	f022                	sd	s0,32(sp)
    80002d9c:	ec26                	sd	s1,24(sp)
    80002d9e:	e84a                	sd	s2,16(sp)
    80002da0:	e44e                	sd	s3,8(sp)
    80002da2:	1800                	addi	s0,sp,48
    80002da4:	892a                	mv	s2,a0
    80002da6:	89ae                	mv	s3,a1
  acquire(&bcache.lock);
    80002da8:	00014517          	auipc	a0,0x14
    80002dac:	34050513          	addi	a0,a0,832 # 800170e8 <bcache>
    80002db0:	ffffe097          	auipc	ra,0xffffe
    80002db4:	dfa080e7          	jalr	-518(ra) # 80000baa <acquire>
  for(b = bcache.head.next; b != &bcache.head; b = b->next){
    80002db8:	0001c497          	auipc	s1,0x1c
    80002dbc:	5e84b483          	ld	s1,1512(s1) # 8001f3a0 <bcache+0x82b8>
    80002dc0:	0001c797          	auipc	a5,0x1c
    80002dc4:	59078793          	addi	a5,a5,1424 # 8001f350 <bcache+0x8268>
    80002dc8:	02f48f63          	beq	s1,a5,80002e06 <bread+0x70>
    80002dcc:	873e                	mv	a4,a5
    80002dce:	a021                	j	80002dd6 <bread+0x40>
    80002dd0:	68a4                	ld	s1,80(s1)
    80002dd2:	02e48a63          	beq	s1,a4,80002e06 <bread+0x70>
    if(b->dev == dev && b->blockno == blockno){
    80002dd6:	449c                	lw	a5,8(s1)
    80002dd8:	ff279ce3          	bne	a5,s2,80002dd0 <bread+0x3a>
    80002ddc:	44dc                	lw	a5,12(s1)
    80002dde:	ff3799e3          	bne	a5,s3,80002dd0 <bread+0x3a>
      b->refcnt++;
    80002de2:	40bc                	lw	a5,64(s1)
    80002de4:	2785                	addiw	a5,a5,1
    80002de6:	c0bc                	sw	a5,64(s1)
      release(&bcache.lock);
    80002de8:	00014517          	auipc	a0,0x14
    80002dec:	30050513          	addi	a0,a0,768 # 800170e8 <bcache>
    80002df0:	ffffe097          	auipc	ra,0xffffe
    80002df4:	e6e080e7          	jalr	-402(ra) # 80000c5e <release>
      acquiresleep(&b->lock);
    80002df8:	01048513          	addi	a0,s1,16
    80002dfc:	00001097          	auipc	ra,0x1
    80002e00:	46c080e7          	jalr	1132(ra) # 80004268 <acquiresleep>
      return b;
    80002e04:	a8b9                	j	80002e62 <bread+0xcc>
  for(b = bcache.head.prev; b != &bcache.head; b = b->prev){
    80002e06:	0001c497          	auipc	s1,0x1c
    80002e0a:	5924b483          	ld	s1,1426(s1) # 8001f398 <bcache+0x82b0>
    80002e0e:	0001c797          	auipc	a5,0x1c
    80002e12:	54278793          	addi	a5,a5,1346 # 8001f350 <bcache+0x8268>
    80002e16:	00f48863          	beq	s1,a5,80002e26 <bread+0x90>
    80002e1a:	873e                	mv	a4,a5
    if(b->refcnt == 0) {
    80002e1c:	40bc                	lw	a5,64(s1)
    80002e1e:	cf81                	beqz	a5,80002e36 <bread+0xa0>
  for(b = bcache.head.prev; b != &bcache.head; b = b->prev){
    80002e20:	64a4                	ld	s1,72(s1)
    80002e22:	fee49de3          	bne	s1,a4,80002e1c <bread+0x86>
  panic("bget: no buffers");
    80002e26:	00005517          	auipc	a0,0x5
    80002e2a:	6e250513          	addi	a0,a0,1762 # 80008508 <syscalls+0xc0>
    80002e2e:	ffffd097          	auipc	ra,0xffffd
    80002e32:	70c080e7          	jalr	1804(ra) # 8000053a <panic>
      b->dev = dev;
    80002e36:	0124a423          	sw	s2,8(s1)
      b->blockno = blockno;
    80002e3a:	0134a623          	sw	s3,12(s1)
      b->valid = 0;
    80002e3e:	0004a023          	sw	zero,0(s1)
      b->refcnt = 1;
    80002e42:	4785                	li	a5,1
    80002e44:	c0bc                	sw	a5,64(s1)
      release(&bcache.lock);
    80002e46:	00014517          	auipc	a0,0x14
    80002e4a:	2a250513          	addi	a0,a0,674 # 800170e8 <bcache>
    80002e4e:	ffffe097          	auipc	ra,0xffffe
    80002e52:	e10080e7          	jalr	-496(ra) # 80000c5e <release>
      acquiresleep(&b->lock);
    80002e56:	01048513          	addi	a0,s1,16
    80002e5a:	00001097          	auipc	ra,0x1
    80002e5e:	40e080e7          	jalr	1038(ra) # 80004268 <acquiresleep>
  struct buf *b;

  b = bget(dev, blockno);
  if(!b->valid) {
    80002e62:	409c                	lw	a5,0(s1)
    80002e64:	cb89                	beqz	a5,80002e76 <bread+0xe0>
    virtio_disk_rw(b, 0);
    b->valid = 1;
  }
  return b;
}
    80002e66:	8526                	mv	a0,s1
    80002e68:	70a2                	ld	ra,40(sp)
    80002e6a:	7402                	ld	s0,32(sp)
    80002e6c:	64e2                	ld	s1,24(sp)
    80002e6e:	6942                	ld	s2,16(sp)
    80002e70:	69a2                	ld	s3,8(sp)
    80002e72:	6145                	addi	sp,sp,48
    80002e74:	8082                	ret
    virtio_disk_rw(b, 0);
    80002e76:	4581                	li	a1,0
    80002e78:	8526                	mv	a0,s1
    80002e7a:	00003097          	auipc	ra,0x3
    80002e7e:	f28080e7          	jalr	-216(ra) # 80005da2 <virtio_disk_rw>
    b->valid = 1;
    80002e82:	4785                	li	a5,1
    80002e84:	c09c                	sw	a5,0(s1)
  return b;
    80002e86:	b7c5                	j	80002e66 <bread+0xd0>

0000000080002e88 <bwrite>:

// Write b's contents to disk.  Must be locked.
void
bwrite(struct buf *b)
{
    80002e88:	1101                	addi	sp,sp,-32
    80002e8a:	ec06                	sd	ra,24(sp)
    80002e8c:	e822                	sd	s0,16(sp)
    80002e8e:	e426                	sd	s1,8(sp)
    80002e90:	1000                	addi	s0,sp,32
    80002e92:	84aa                	mv	s1,a0
  if(!holdingsleep(&b->lock))
    80002e94:	0541                	addi	a0,a0,16
    80002e96:	00001097          	auipc	ra,0x1
    80002e9a:	46c080e7          	jalr	1132(ra) # 80004302 <holdingsleep>
    80002e9e:	cd01                	beqz	a0,80002eb6 <bwrite+0x2e>
    panic("bwrite");
  virtio_disk_rw(b, 1);
    80002ea0:	4585                	li	a1,1
    80002ea2:	8526                	mv	a0,s1
    80002ea4:	00003097          	auipc	ra,0x3
    80002ea8:	efe080e7          	jalr	-258(ra) # 80005da2 <virtio_disk_rw>
}
    80002eac:	60e2                	ld	ra,24(sp)
    80002eae:	6442                	ld	s0,16(sp)
    80002eb0:	64a2                	ld	s1,8(sp)
    80002eb2:	6105                	addi	sp,sp,32
    80002eb4:	8082                	ret
    panic("bwrite");
    80002eb6:	00005517          	auipc	a0,0x5
    80002eba:	66a50513          	addi	a0,a0,1642 # 80008520 <syscalls+0xd8>
    80002ebe:	ffffd097          	auipc	ra,0xffffd
    80002ec2:	67c080e7          	jalr	1660(ra) # 8000053a <panic>

0000000080002ec6 <brelse>:

// Release a locked buffer.
// Move to the head of the most-recently-used list.
void
brelse(struct buf *b)
{
    80002ec6:	1101                	addi	sp,sp,-32
    80002ec8:	ec06                	sd	ra,24(sp)
    80002eca:	e822                	sd	s0,16(sp)
    80002ecc:	e426                	sd	s1,8(sp)
    80002ece:	e04a                	sd	s2,0(sp)
    80002ed0:	1000                	addi	s0,sp,32
    80002ed2:	84aa                	mv	s1,a0
  if(!holdingsleep(&b->lock))
    80002ed4:	01050913          	addi	s2,a0,16
    80002ed8:	854a                	mv	a0,s2
    80002eda:	00001097          	auipc	ra,0x1
    80002ede:	428080e7          	jalr	1064(ra) # 80004302 <holdingsleep>
    80002ee2:	c92d                	beqz	a0,80002f54 <brelse+0x8e>
    panic("brelse");

  releasesleep(&b->lock);
    80002ee4:	854a                	mv	a0,s2
    80002ee6:	00001097          	auipc	ra,0x1
    80002eea:	3d8080e7          	jalr	984(ra) # 800042be <releasesleep>

  acquire(&bcache.lock);
    80002eee:	00014517          	auipc	a0,0x14
    80002ef2:	1fa50513          	addi	a0,a0,506 # 800170e8 <bcache>
    80002ef6:	ffffe097          	auipc	ra,0xffffe
    80002efa:	cb4080e7          	jalr	-844(ra) # 80000baa <acquire>
  b->refcnt--;
    80002efe:	40bc                	lw	a5,64(s1)
    80002f00:	37fd                	addiw	a5,a5,-1
    80002f02:	0007871b          	sext.w	a4,a5
    80002f06:	c0bc                	sw	a5,64(s1)
  if (b->refcnt == 0) {
    80002f08:	eb05                	bnez	a4,80002f38 <brelse+0x72>
    // no one is waiting for it.
    b->next->prev = b->prev;
    80002f0a:	68bc                	ld	a5,80(s1)
    80002f0c:	64b8                	ld	a4,72(s1)
    80002f0e:	e7b8                	sd	a4,72(a5)
    b->prev->next = b->next;
    80002f10:	64bc                	ld	a5,72(s1)
    80002f12:	68b8                	ld	a4,80(s1)
    80002f14:	ebb8                	sd	a4,80(a5)
    b->next = bcache.head.next;
    80002f16:	0001c797          	auipc	a5,0x1c
    80002f1a:	1d278793          	addi	a5,a5,466 # 8001f0e8 <bcache+0x8000>
    80002f1e:	2b87b703          	ld	a4,696(a5)
    80002f22:	e8b8                	sd	a4,80(s1)
    b->prev = &bcache.head;
    80002f24:	0001c717          	auipc	a4,0x1c
    80002f28:	42c70713          	addi	a4,a4,1068 # 8001f350 <bcache+0x8268>
    80002f2c:	e4b8                	sd	a4,72(s1)
    bcache.head.next->prev = b;
    80002f2e:	2b87b703          	ld	a4,696(a5)
    80002f32:	e724                	sd	s1,72(a4)
    bcache.head.next = b;
    80002f34:	2a97bc23          	sd	s1,696(a5)
  }
  
  release(&bcache.lock);
    80002f38:	00014517          	auipc	a0,0x14
    80002f3c:	1b050513          	addi	a0,a0,432 # 800170e8 <bcache>
    80002f40:	ffffe097          	auipc	ra,0xffffe
    80002f44:	d1e080e7          	jalr	-738(ra) # 80000c5e <release>
}
    80002f48:	60e2                	ld	ra,24(sp)
    80002f4a:	6442                	ld	s0,16(sp)
    80002f4c:	64a2                	ld	s1,8(sp)
    80002f4e:	6902                	ld	s2,0(sp)
    80002f50:	6105                	addi	sp,sp,32
    80002f52:	8082                	ret
    panic("brelse");
    80002f54:	00005517          	auipc	a0,0x5
    80002f58:	5d450513          	addi	a0,a0,1492 # 80008528 <syscalls+0xe0>
    80002f5c:	ffffd097          	auipc	ra,0xffffd
    80002f60:	5de080e7          	jalr	1502(ra) # 8000053a <panic>

0000000080002f64 <bpin>:

void
bpin(struct buf *b) {
    80002f64:	1101                	addi	sp,sp,-32
    80002f66:	ec06                	sd	ra,24(sp)
    80002f68:	e822                	sd	s0,16(sp)
    80002f6a:	e426                	sd	s1,8(sp)
    80002f6c:	1000                	addi	s0,sp,32
    80002f6e:	84aa                	mv	s1,a0
  acquire(&bcache.lock);
    80002f70:	00014517          	auipc	a0,0x14
    80002f74:	17850513          	addi	a0,a0,376 # 800170e8 <bcache>
    80002f78:	ffffe097          	auipc	ra,0xffffe
    80002f7c:	c32080e7          	jalr	-974(ra) # 80000baa <acquire>
  b->refcnt++;
    80002f80:	40bc                	lw	a5,64(s1)
    80002f82:	2785                	addiw	a5,a5,1
    80002f84:	c0bc                	sw	a5,64(s1)
  release(&bcache.lock);
    80002f86:	00014517          	auipc	a0,0x14
    80002f8a:	16250513          	addi	a0,a0,354 # 800170e8 <bcache>
    80002f8e:	ffffe097          	auipc	ra,0xffffe
    80002f92:	cd0080e7          	jalr	-816(ra) # 80000c5e <release>
}
    80002f96:	60e2                	ld	ra,24(sp)
    80002f98:	6442                	ld	s0,16(sp)
    80002f9a:	64a2                	ld	s1,8(sp)
    80002f9c:	6105                	addi	sp,sp,32
    80002f9e:	8082                	ret

0000000080002fa0 <bunpin>:

void
bunpin(struct buf *b) {
    80002fa0:	1101                	addi	sp,sp,-32
    80002fa2:	ec06                	sd	ra,24(sp)
    80002fa4:	e822                	sd	s0,16(sp)
    80002fa6:	e426                	sd	s1,8(sp)
    80002fa8:	1000                	addi	s0,sp,32
    80002faa:	84aa                	mv	s1,a0
  acquire(&bcache.lock);
    80002fac:	00014517          	auipc	a0,0x14
    80002fb0:	13c50513          	addi	a0,a0,316 # 800170e8 <bcache>
    80002fb4:	ffffe097          	auipc	ra,0xffffe
    80002fb8:	bf6080e7          	jalr	-1034(ra) # 80000baa <acquire>
  b->refcnt--;
    80002fbc:	40bc                	lw	a5,64(s1)
    80002fbe:	37fd                	addiw	a5,a5,-1
    80002fc0:	c0bc                	sw	a5,64(s1)
  release(&bcache.lock);
    80002fc2:	00014517          	auipc	a0,0x14
    80002fc6:	12650513          	addi	a0,a0,294 # 800170e8 <bcache>
    80002fca:	ffffe097          	auipc	ra,0xffffe
    80002fce:	c94080e7          	jalr	-876(ra) # 80000c5e <release>
}
    80002fd2:	60e2                	ld	ra,24(sp)
    80002fd4:	6442                	ld	s0,16(sp)
    80002fd6:	64a2                	ld	s1,8(sp)
    80002fd8:	6105                	addi	sp,sp,32
    80002fda:	8082                	ret

0000000080002fdc <bfree>:
}

// Free a disk block.
static void
bfree(int dev, uint b)
{
    80002fdc:	1101                	addi	sp,sp,-32
    80002fde:	ec06                	sd	ra,24(sp)
    80002fe0:	e822                	sd	s0,16(sp)
    80002fe2:	e426                	sd	s1,8(sp)
    80002fe4:	e04a                	sd	s2,0(sp)
    80002fe6:	1000                	addi	s0,sp,32
    80002fe8:	84ae                	mv	s1,a1
  struct buf *bp;
  int bi, m;

  bp = bread(dev, BBLOCK(b, sb));
    80002fea:	00d5d59b          	srliw	a1,a1,0xd
    80002fee:	0001c797          	auipc	a5,0x1c
    80002ff2:	7d67a783          	lw	a5,2006(a5) # 8001f7c4 <sb+0x1c>
    80002ff6:	9dbd                	addw	a1,a1,a5
    80002ff8:	00000097          	auipc	ra,0x0
    80002ffc:	d9e080e7          	jalr	-610(ra) # 80002d96 <bread>
  bi = b % BPB;
  m = 1 << (bi % 8);
    80003000:	0074f713          	andi	a4,s1,7
    80003004:	4785                	li	a5,1
    80003006:	00e797bb          	sllw	a5,a5,a4
  if((bp->data[bi/8] & m) == 0)
    8000300a:	14ce                	slli	s1,s1,0x33
    8000300c:	90d9                	srli	s1,s1,0x36
    8000300e:	00950733          	add	a4,a0,s1
    80003012:	05874703          	lbu	a4,88(a4)
    80003016:	00e7f6b3          	and	a3,a5,a4
    8000301a:	c69d                	beqz	a3,80003048 <bfree+0x6c>
    8000301c:	892a                	mv	s2,a0
    panic("freeing free block");
  bp->data[bi/8] &= ~m;
    8000301e:	94aa                	add	s1,s1,a0
    80003020:	fff7c793          	not	a5,a5
    80003024:	8f7d                	and	a4,a4,a5
    80003026:	04e48c23          	sb	a4,88(s1)
  log_write(bp);
    8000302a:	00001097          	auipc	ra,0x1
    8000302e:	120080e7          	jalr	288(ra) # 8000414a <log_write>
  brelse(bp);
    80003032:	854a                	mv	a0,s2
    80003034:	00000097          	auipc	ra,0x0
    80003038:	e92080e7          	jalr	-366(ra) # 80002ec6 <brelse>
}
    8000303c:	60e2                	ld	ra,24(sp)
    8000303e:	6442                	ld	s0,16(sp)
    80003040:	64a2                	ld	s1,8(sp)
    80003042:	6902                	ld	s2,0(sp)
    80003044:	6105                	addi	sp,sp,32
    80003046:	8082                	ret
    panic("freeing free block");
    80003048:	00005517          	auipc	a0,0x5
    8000304c:	4e850513          	addi	a0,a0,1256 # 80008530 <syscalls+0xe8>
    80003050:	ffffd097          	auipc	ra,0xffffd
    80003054:	4ea080e7          	jalr	1258(ra) # 8000053a <panic>

0000000080003058 <balloc>:
{
    80003058:	711d                	addi	sp,sp,-96
    8000305a:	ec86                	sd	ra,88(sp)
    8000305c:	e8a2                	sd	s0,80(sp)
    8000305e:	e4a6                	sd	s1,72(sp)
    80003060:	e0ca                	sd	s2,64(sp)
    80003062:	fc4e                	sd	s3,56(sp)
    80003064:	f852                	sd	s4,48(sp)
    80003066:	f456                	sd	s5,40(sp)
    80003068:	f05a                	sd	s6,32(sp)
    8000306a:	ec5e                	sd	s7,24(sp)
    8000306c:	e862                	sd	s8,16(sp)
    8000306e:	e466                	sd	s9,8(sp)
    80003070:	1080                	addi	s0,sp,96
  for(b = 0; b < sb.size; b += BPB){
    80003072:	0001c797          	auipc	a5,0x1c
    80003076:	73a7a783          	lw	a5,1850(a5) # 8001f7ac <sb+0x4>
    8000307a:	cbc1                	beqz	a5,8000310a <balloc+0xb2>
    8000307c:	8baa                	mv	s7,a0
    8000307e:	4a81                	li	s5,0
    bp = bread(dev, BBLOCK(b, sb));
    80003080:	0001cb17          	auipc	s6,0x1c
    80003084:	728b0b13          	addi	s6,s6,1832 # 8001f7a8 <sb>
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    80003088:	4c01                	li	s8,0
      m = 1 << (bi % 8);
    8000308a:	4985                	li	s3,1
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    8000308c:	6a09                	lui	s4,0x2
  for(b = 0; b < sb.size; b += BPB){
    8000308e:	6c89                	lui	s9,0x2
    80003090:	a831                	j	800030ac <balloc+0x54>
    brelse(bp);
    80003092:	854a                	mv	a0,s2
    80003094:	00000097          	auipc	ra,0x0
    80003098:	e32080e7          	jalr	-462(ra) # 80002ec6 <brelse>
  for(b = 0; b < sb.size; b += BPB){
    8000309c:	015c87bb          	addw	a5,s9,s5
    800030a0:	00078a9b          	sext.w	s5,a5
    800030a4:	004b2703          	lw	a4,4(s6)
    800030a8:	06eaf163          	bgeu	s5,a4,8000310a <balloc+0xb2>
    bp = bread(dev, BBLOCK(b, sb));
    800030ac:	41fad79b          	sraiw	a5,s5,0x1f
    800030b0:	0137d79b          	srliw	a5,a5,0x13
    800030b4:	015787bb          	addw	a5,a5,s5
    800030b8:	40d7d79b          	sraiw	a5,a5,0xd
    800030bc:	01cb2583          	lw	a1,28(s6)
    800030c0:	9dbd                	addw	a1,a1,a5
    800030c2:	855e                	mv	a0,s7
    800030c4:	00000097          	auipc	ra,0x0
    800030c8:	cd2080e7          	jalr	-814(ra) # 80002d96 <bread>
    800030cc:	892a                	mv	s2,a0
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    800030ce:	004b2503          	lw	a0,4(s6)
    800030d2:	000a849b          	sext.w	s1,s5
    800030d6:	8762                	mv	a4,s8
    800030d8:	faa4fde3          	bgeu	s1,a0,80003092 <balloc+0x3a>
      m = 1 << (bi % 8);
    800030dc:	00777693          	andi	a3,a4,7
    800030e0:	00d996bb          	sllw	a3,s3,a3
      if((bp->data[bi/8] & m) == 0){  // Is block free?
    800030e4:	41f7579b          	sraiw	a5,a4,0x1f
    800030e8:	01d7d79b          	srliw	a5,a5,0x1d
    800030ec:	9fb9                	addw	a5,a5,a4
    800030ee:	4037d79b          	sraiw	a5,a5,0x3
    800030f2:	00f90633          	add	a2,s2,a5
    800030f6:	05864603          	lbu	a2,88(a2)
    800030fa:	00c6f5b3          	and	a1,a3,a2
    800030fe:	cd91                	beqz	a1,8000311a <balloc+0xc2>
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    80003100:	2705                	addiw	a4,a4,1
    80003102:	2485                	addiw	s1,s1,1
    80003104:	fd471ae3          	bne	a4,s4,800030d8 <balloc+0x80>
    80003108:	b769                	j	80003092 <balloc+0x3a>
  panic("balloc: out of blocks");
    8000310a:	00005517          	auipc	a0,0x5
    8000310e:	43e50513          	addi	a0,a0,1086 # 80008548 <syscalls+0x100>
    80003112:	ffffd097          	auipc	ra,0xffffd
    80003116:	428080e7          	jalr	1064(ra) # 8000053a <panic>
        bp->data[bi/8] |= m;  // Mark block in use.
    8000311a:	97ca                	add	a5,a5,s2
    8000311c:	8e55                	or	a2,a2,a3
    8000311e:	04c78c23          	sb	a2,88(a5)
        log_write(bp);
    80003122:	854a                	mv	a0,s2
    80003124:	00001097          	auipc	ra,0x1
    80003128:	026080e7          	jalr	38(ra) # 8000414a <log_write>
        brelse(bp);
    8000312c:	854a                	mv	a0,s2
    8000312e:	00000097          	auipc	ra,0x0
    80003132:	d98080e7          	jalr	-616(ra) # 80002ec6 <brelse>
  bp = bread(dev, bno);
    80003136:	85a6                	mv	a1,s1
    80003138:	855e                	mv	a0,s7
    8000313a:	00000097          	auipc	ra,0x0
    8000313e:	c5c080e7          	jalr	-932(ra) # 80002d96 <bread>
    80003142:	892a                	mv	s2,a0
  memset(bp->data, 0, BSIZE);
    80003144:	40000613          	li	a2,1024
    80003148:	4581                	li	a1,0
    8000314a:	05850513          	addi	a0,a0,88
    8000314e:	ffffe097          	auipc	ra,0xffffe
    80003152:	b58080e7          	jalr	-1192(ra) # 80000ca6 <memset>
  log_write(bp);
    80003156:	854a                	mv	a0,s2
    80003158:	00001097          	auipc	ra,0x1
    8000315c:	ff2080e7          	jalr	-14(ra) # 8000414a <log_write>
  brelse(bp);
    80003160:	854a                	mv	a0,s2
    80003162:	00000097          	auipc	ra,0x0
    80003166:	d64080e7          	jalr	-668(ra) # 80002ec6 <brelse>
}
    8000316a:	8526                	mv	a0,s1
    8000316c:	60e6                	ld	ra,88(sp)
    8000316e:	6446                	ld	s0,80(sp)
    80003170:	64a6                	ld	s1,72(sp)
    80003172:	6906                	ld	s2,64(sp)
    80003174:	79e2                	ld	s3,56(sp)
    80003176:	7a42                	ld	s4,48(sp)
    80003178:	7aa2                	ld	s5,40(sp)
    8000317a:	7b02                	ld	s6,32(sp)
    8000317c:	6be2                	ld	s7,24(sp)
    8000317e:	6c42                	ld	s8,16(sp)
    80003180:	6ca2                	ld	s9,8(sp)
    80003182:	6125                	addi	sp,sp,96
    80003184:	8082                	ret

0000000080003186 <bmap>:

// Return the disk block address of the nth block in inode ip.
// If there is no such block, bmap allocates one.
static uint
bmap(struct inode *ip, uint bn)
{
    80003186:	7179                	addi	sp,sp,-48
    80003188:	f406                	sd	ra,40(sp)
    8000318a:	f022                	sd	s0,32(sp)
    8000318c:	ec26                	sd	s1,24(sp)
    8000318e:	e84a                	sd	s2,16(sp)
    80003190:	e44e                	sd	s3,8(sp)
    80003192:	e052                	sd	s4,0(sp)
    80003194:	1800                	addi	s0,sp,48
    80003196:	892a                	mv	s2,a0
  uint addr, *a;
  struct buf *bp;

  if(bn < NDIRECT){
    80003198:	47ad                	li	a5,11
    8000319a:	04b7fe63          	bgeu	a5,a1,800031f6 <bmap+0x70>
    if((addr = ip->addrs[bn]) == 0)
      ip->addrs[bn] = addr = balloc(ip->dev);
    return addr;
  }
  bn -= NDIRECT;
    8000319e:	ff45849b          	addiw	s1,a1,-12
    800031a2:	0004871b          	sext.w	a4,s1

  if(bn < NINDIRECT){
    800031a6:	0ff00793          	li	a5,255
    800031aa:	0ae7e463          	bltu	a5,a4,80003252 <bmap+0xcc>
    // Load indirect block, allocating if necessary.
    if((addr = ip->addrs[NDIRECT]) == 0)
    800031ae:	08052583          	lw	a1,128(a0)
    800031b2:	c5b5                	beqz	a1,8000321e <bmap+0x98>
      ip->addrs[NDIRECT] = addr = balloc(ip->dev);
    bp = bread(ip->dev, addr);
    800031b4:	00092503          	lw	a0,0(s2)
    800031b8:	00000097          	auipc	ra,0x0
    800031bc:	bde080e7          	jalr	-1058(ra) # 80002d96 <bread>
    800031c0:	8a2a                	mv	s4,a0
    a = (uint*)bp->data;
    800031c2:	05850793          	addi	a5,a0,88
    if((addr = a[bn]) == 0){
    800031c6:	02049713          	slli	a4,s1,0x20
    800031ca:	01e75593          	srli	a1,a4,0x1e
    800031ce:	00b784b3          	add	s1,a5,a1
    800031d2:	0004a983          	lw	s3,0(s1)
    800031d6:	04098e63          	beqz	s3,80003232 <bmap+0xac>
      a[bn] = addr = balloc(ip->dev);
      log_write(bp);
    }
    brelse(bp);
    800031da:	8552                	mv	a0,s4
    800031dc:	00000097          	auipc	ra,0x0
    800031e0:	cea080e7          	jalr	-790(ra) # 80002ec6 <brelse>
    return addr;
  }

  panic("bmap: out of range");
}
    800031e4:	854e                	mv	a0,s3
    800031e6:	70a2                	ld	ra,40(sp)
    800031e8:	7402                	ld	s0,32(sp)
    800031ea:	64e2                	ld	s1,24(sp)
    800031ec:	6942                	ld	s2,16(sp)
    800031ee:	69a2                	ld	s3,8(sp)
    800031f0:	6a02                	ld	s4,0(sp)
    800031f2:	6145                	addi	sp,sp,48
    800031f4:	8082                	ret
    if((addr = ip->addrs[bn]) == 0)
    800031f6:	02059793          	slli	a5,a1,0x20
    800031fa:	01e7d593          	srli	a1,a5,0x1e
    800031fe:	00b504b3          	add	s1,a0,a1
    80003202:	0504a983          	lw	s3,80(s1)
    80003206:	fc099fe3          	bnez	s3,800031e4 <bmap+0x5e>
      ip->addrs[bn] = addr = balloc(ip->dev);
    8000320a:	4108                	lw	a0,0(a0)
    8000320c:	00000097          	auipc	ra,0x0
    80003210:	e4c080e7          	jalr	-436(ra) # 80003058 <balloc>
    80003214:	0005099b          	sext.w	s3,a0
    80003218:	0534a823          	sw	s3,80(s1)
    8000321c:	b7e1                	j	800031e4 <bmap+0x5e>
      ip->addrs[NDIRECT] = addr = balloc(ip->dev);
    8000321e:	4108                	lw	a0,0(a0)
    80003220:	00000097          	auipc	ra,0x0
    80003224:	e38080e7          	jalr	-456(ra) # 80003058 <balloc>
    80003228:	0005059b          	sext.w	a1,a0
    8000322c:	08b92023          	sw	a1,128(s2)
    80003230:	b751                	j	800031b4 <bmap+0x2e>
      a[bn] = addr = balloc(ip->dev);
    80003232:	00092503          	lw	a0,0(s2)
    80003236:	00000097          	auipc	ra,0x0
    8000323a:	e22080e7          	jalr	-478(ra) # 80003058 <balloc>
    8000323e:	0005099b          	sext.w	s3,a0
    80003242:	0134a023          	sw	s3,0(s1)
      log_write(bp);
    80003246:	8552                	mv	a0,s4
    80003248:	00001097          	auipc	ra,0x1
    8000324c:	f02080e7          	jalr	-254(ra) # 8000414a <log_write>
    80003250:	b769                	j	800031da <bmap+0x54>
  panic("bmap: out of range");
    80003252:	00005517          	auipc	a0,0x5
    80003256:	30e50513          	addi	a0,a0,782 # 80008560 <syscalls+0x118>
    8000325a:	ffffd097          	auipc	ra,0xffffd
    8000325e:	2e0080e7          	jalr	736(ra) # 8000053a <panic>

0000000080003262 <iget>:
{
    80003262:	7179                	addi	sp,sp,-48
    80003264:	f406                	sd	ra,40(sp)
    80003266:	f022                	sd	s0,32(sp)
    80003268:	ec26                	sd	s1,24(sp)
    8000326a:	e84a                	sd	s2,16(sp)
    8000326c:	e44e                	sd	s3,8(sp)
    8000326e:	e052                	sd	s4,0(sp)
    80003270:	1800                	addi	s0,sp,48
    80003272:	89aa                	mv	s3,a0
    80003274:	8a2e                	mv	s4,a1
  acquire(&itable.lock);
    80003276:	0001c517          	auipc	a0,0x1c
    8000327a:	55250513          	addi	a0,a0,1362 # 8001f7c8 <itable>
    8000327e:	ffffe097          	auipc	ra,0xffffe
    80003282:	92c080e7          	jalr	-1748(ra) # 80000baa <acquire>
  empty = 0;
    80003286:	4901                	li	s2,0
  for(ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++){
    80003288:	0001c497          	auipc	s1,0x1c
    8000328c:	55848493          	addi	s1,s1,1368 # 8001f7e0 <itable+0x18>
    80003290:	0001e697          	auipc	a3,0x1e
    80003294:	fe068693          	addi	a3,a3,-32 # 80021270 <log>
    80003298:	a039                	j	800032a6 <iget+0x44>
    if(empty == 0 && ip->ref == 0)    // Remember empty slot.
    8000329a:	02090b63          	beqz	s2,800032d0 <iget+0x6e>
  for(ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++){
    8000329e:	08848493          	addi	s1,s1,136
    800032a2:	02d48a63          	beq	s1,a3,800032d6 <iget+0x74>
    if(ip->ref > 0 && ip->dev == dev && ip->inum == inum){
    800032a6:	449c                	lw	a5,8(s1)
    800032a8:	fef059e3          	blez	a5,8000329a <iget+0x38>
    800032ac:	4098                	lw	a4,0(s1)
    800032ae:	ff3716e3          	bne	a4,s3,8000329a <iget+0x38>
    800032b2:	40d8                	lw	a4,4(s1)
    800032b4:	ff4713e3          	bne	a4,s4,8000329a <iget+0x38>
      ip->ref++;
    800032b8:	2785                	addiw	a5,a5,1
    800032ba:	c49c                	sw	a5,8(s1)
      release(&itable.lock);
    800032bc:	0001c517          	auipc	a0,0x1c
    800032c0:	50c50513          	addi	a0,a0,1292 # 8001f7c8 <itable>
    800032c4:	ffffe097          	auipc	ra,0xffffe
    800032c8:	99a080e7          	jalr	-1638(ra) # 80000c5e <release>
      return ip;
    800032cc:	8926                	mv	s2,s1
    800032ce:	a03d                	j	800032fc <iget+0x9a>
    if(empty == 0 && ip->ref == 0)    // Remember empty slot.
    800032d0:	f7f9                	bnez	a5,8000329e <iget+0x3c>
    800032d2:	8926                	mv	s2,s1
    800032d4:	b7e9                	j	8000329e <iget+0x3c>
  if(empty == 0)
    800032d6:	02090c63          	beqz	s2,8000330e <iget+0xac>
  ip->dev = dev;
    800032da:	01392023          	sw	s3,0(s2)
  ip->inum = inum;
    800032de:	01492223          	sw	s4,4(s2)
  ip->ref = 1;
    800032e2:	4785                	li	a5,1
    800032e4:	00f92423          	sw	a5,8(s2)
  ip->valid = 0;
    800032e8:	04092023          	sw	zero,64(s2)
  release(&itable.lock);
    800032ec:	0001c517          	auipc	a0,0x1c
    800032f0:	4dc50513          	addi	a0,a0,1244 # 8001f7c8 <itable>
    800032f4:	ffffe097          	auipc	ra,0xffffe
    800032f8:	96a080e7          	jalr	-1686(ra) # 80000c5e <release>
}
    800032fc:	854a                	mv	a0,s2
    800032fe:	70a2                	ld	ra,40(sp)
    80003300:	7402                	ld	s0,32(sp)
    80003302:	64e2                	ld	s1,24(sp)
    80003304:	6942                	ld	s2,16(sp)
    80003306:	69a2                	ld	s3,8(sp)
    80003308:	6a02                	ld	s4,0(sp)
    8000330a:	6145                	addi	sp,sp,48
    8000330c:	8082                	ret
    panic("iget: no inodes");
    8000330e:	00005517          	auipc	a0,0x5
    80003312:	26a50513          	addi	a0,a0,618 # 80008578 <syscalls+0x130>
    80003316:	ffffd097          	auipc	ra,0xffffd
    8000331a:	224080e7          	jalr	548(ra) # 8000053a <panic>

000000008000331e <fsinit>:
fsinit(int dev) {
    8000331e:	7179                	addi	sp,sp,-48
    80003320:	f406                	sd	ra,40(sp)
    80003322:	f022                	sd	s0,32(sp)
    80003324:	ec26                	sd	s1,24(sp)
    80003326:	e84a                	sd	s2,16(sp)
    80003328:	e44e                	sd	s3,8(sp)
    8000332a:	1800                	addi	s0,sp,48
    8000332c:	892a                	mv	s2,a0
  bp = bread(dev, 1);
    8000332e:	4585                	li	a1,1
    80003330:	00000097          	auipc	ra,0x0
    80003334:	a66080e7          	jalr	-1434(ra) # 80002d96 <bread>
    80003338:	84aa                	mv	s1,a0
  memmove(sb, bp->data, sizeof(*sb));
    8000333a:	0001c997          	auipc	s3,0x1c
    8000333e:	46e98993          	addi	s3,s3,1134 # 8001f7a8 <sb>
    80003342:	02000613          	li	a2,32
    80003346:	05850593          	addi	a1,a0,88
    8000334a:	854e                	mv	a0,s3
    8000334c:	ffffe097          	auipc	ra,0xffffe
    80003350:	9b6080e7          	jalr	-1610(ra) # 80000d02 <memmove>
  brelse(bp);
    80003354:	8526                	mv	a0,s1
    80003356:	00000097          	auipc	ra,0x0
    8000335a:	b70080e7          	jalr	-1168(ra) # 80002ec6 <brelse>
  if(sb.magic != FSMAGIC)
    8000335e:	0009a703          	lw	a4,0(s3)
    80003362:	102037b7          	lui	a5,0x10203
    80003366:	04078793          	addi	a5,a5,64 # 10203040 <_entry-0x6fdfcfc0>
    8000336a:	02f71263          	bne	a4,a5,8000338e <fsinit+0x70>
  initlog(dev, &sb);
    8000336e:	0001c597          	auipc	a1,0x1c
    80003372:	43a58593          	addi	a1,a1,1082 # 8001f7a8 <sb>
    80003376:	854a                	mv	a0,s2
    80003378:	00001097          	auipc	ra,0x1
    8000337c:	b56080e7          	jalr	-1194(ra) # 80003ece <initlog>
}
    80003380:	70a2                	ld	ra,40(sp)
    80003382:	7402                	ld	s0,32(sp)
    80003384:	64e2                	ld	s1,24(sp)
    80003386:	6942                	ld	s2,16(sp)
    80003388:	69a2                	ld	s3,8(sp)
    8000338a:	6145                	addi	sp,sp,48
    8000338c:	8082                	ret
    panic("invalid file system");
    8000338e:	00005517          	auipc	a0,0x5
    80003392:	1fa50513          	addi	a0,a0,506 # 80008588 <syscalls+0x140>
    80003396:	ffffd097          	auipc	ra,0xffffd
    8000339a:	1a4080e7          	jalr	420(ra) # 8000053a <panic>

000000008000339e <iinit>:
{
    8000339e:	7179                	addi	sp,sp,-48
    800033a0:	f406                	sd	ra,40(sp)
    800033a2:	f022                	sd	s0,32(sp)
    800033a4:	ec26                	sd	s1,24(sp)
    800033a6:	e84a                	sd	s2,16(sp)
    800033a8:	e44e                	sd	s3,8(sp)
    800033aa:	1800                	addi	s0,sp,48
  initlock(&itable.lock, "itable");
    800033ac:	00005597          	auipc	a1,0x5
    800033b0:	1f458593          	addi	a1,a1,500 # 800085a0 <syscalls+0x158>
    800033b4:	0001c517          	auipc	a0,0x1c
    800033b8:	41450513          	addi	a0,a0,1044 # 8001f7c8 <itable>
    800033bc:	ffffd097          	auipc	ra,0xffffd
    800033c0:	75e080e7          	jalr	1886(ra) # 80000b1a <initlock>
  for(i = 0; i < NINODE; i++) {
    800033c4:	0001c497          	auipc	s1,0x1c
    800033c8:	42c48493          	addi	s1,s1,1068 # 8001f7f0 <itable+0x28>
    800033cc:	0001e997          	auipc	s3,0x1e
    800033d0:	eb498993          	addi	s3,s3,-332 # 80021280 <log+0x10>
    initsleeplock(&itable.inode[i].lock, "inode");
    800033d4:	00005917          	auipc	s2,0x5
    800033d8:	1d490913          	addi	s2,s2,468 # 800085a8 <syscalls+0x160>
    800033dc:	85ca                	mv	a1,s2
    800033de:	8526                	mv	a0,s1
    800033e0:	00001097          	auipc	ra,0x1
    800033e4:	e4e080e7          	jalr	-434(ra) # 8000422e <initsleeplock>
  for(i = 0; i < NINODE; i++) {
    800033e8:	08848493          	addi	s1,s1,136
    800033ec:	ff3498e3          	bne	s1,s3,800033dc <iinit+0x3e>
}
    800033f0:	70a2                	ld	ra,40(sp)
    800033f2:	7402                	ld	s0,32(sp)
    800033f4:	64e2                	ld	s1,24(sp)
    800033f6:	6942                	ld	s2,16(sp)
    800033f8:	69a2                	ld	s3,8(sp)
    800033fa:	6145                	addi	sp,sp,48
    800033fc:	8082                	ret

00000000800033fe <ialloc>:
{
    800033fe:	715d                	addi	sp,sp,-80
    80003400:	e486                	sd	ra,72(sp)
    80003402:	e0a2                	sd	s0,64(sp)
    80003404:	fc26                	sd	s1,56(sp)
    80003406:	f84a                	sd	s2,48(sp)
    80003408:	f44e                	sd	s3,40(sp)
    8000340a:	f052                	sd	s4,32(sp)
    8000340c:	ec56                	sd	s5,24(sp)
    8000340e:	e85a                	sd	s6,16(sp)
    80003410:	e45e                	sd	s7,8(sp)
    80003412:	0880                	addi	s0,sp,80
  for(inum = 1; inum < sb.ninodes; inum++){
    80003414:	0001c717          	auipc	a4,0x1c
    80003418:	3a072703          	lw	a4,928(a4) # 8001f7b4 <sb+0xc>
    8000341c:	4785                	li	a5,1
    8000341e:	04e7fa63          	bgeu	a5,a4,80003472 <ialloc+0x74>
    80003422:	8aaa                	mv	s5,a0
    80003424:	8bae                	mv	s7,a1
    80003426:	4485                	li	s1,1
    bp = bread(dev, IBLOCK(inum, sb));
    80003428:	0001ca17          	auipc	s4,0x1c
    8000342c:	380a0a13          	addi	s4,s4,896 # 8001f7a8 <sb>
    80003430:	00048b1b          	sext.w	s6,s1
    80003434:	0044d593          	srli	a1,s1,0x4
    80003438:	018a2783          	lw	a5,24(s4)
    8000343c:	9dbd                	addw	a1,a1,a5
    8000343e:	8556                	mv	a0,s5
    80003440:	00000097          	auipc	ra,0x0
    80003444:	956080e7          	jalr	-1706(ra) # 80002d96 <bread>
    80003448:	892a                	mv	s2,a0
    dip = (struct dinode*)bp->data + inum%IPB;
    8000344a:	05850993          	addi	s3,a0,88
    8000344e:	00f4f793          	andi	a5,s1,15
    80003452:	079a                	slli	a5,a5,0x6
    80003454:	99be                	add	s3,s3,a5
    if(dip->type == 0){  // a free inode
    80003456:	00099783          	lh	a5,0(s3)
    8000345a:	c785                	beqz	a5,80003482 <ialloc+0x84>
    brelse(bp);
    8000345c:	00000097          	auipc	ra,0x0
    80003460:	a6a080e7          	jalr	-1430(ra) # 80002ec6 <brelse>
  for(inum = 1; inum < sb.ninodes; inum++){
    80003464:	0485                	addi	s1,s1,1
    80003466:	00ca2703          	lw	a4,12(s4)
    8000346a:	0004879b          	sext.w	a5,s1
    8000346e:	fce7e1e3          	bltu	a5,a4,80003430 <ialloc+0x32>
  panic("ialloc: no inodes");
    80003472:	00005517          	auipc	a0,0x5
    80003476:	13e50513          	addi	a0,a0,318 # 800085b0 <syscalls+0x168>
    8000347a:	ffffd097          	auipc	ra,0xffffd
    8000347e:	0c0080e7          	jalr	192(ra) # 8000053a <panic>
      memset(dip, 0, sizeof(*dip));
    80003482:	04000613          	li	a2,64
    80003486:	4581                	li	a1,0
    80003488:	854e                	mv	a0,s3
    8000348a:	ffffe097          	auipc	ra,0xffffe
    8000348e:	81c080e7          	jalr	-2020(ra) # 80000ca6 <memset>
      dip->type = type;
    80003492:	01799023          	sh	s7,0(s3)
      log_write(bp);   // mark it allocated on the disk
    80003496:	854a                	mv	a0,s2
    80003498:	00001097          	auipc	ra,0x1
    8000349c:	cb2080e7          	jalr	-846(ra) # 8000414a <log_write>
      brelse(bp);
    800034a0:	854a                	mv	a0,s2
    800034a2:	00000097          	auipc	ra,0x0
    800034a6:	a24080e7          	jalr	-1500(ra) # 80002ec6 <brelse>
      return iget(dev, inum);
    800034aa:	85da                	mv	a1,s6
    800034ac:	8556                	mv	a0,s5
    800034ae:	00000097          	auipc	ra,0x0
    800034b2:	db4080e7          	jalr	-588(ra) # 80003262 <iget>
}
    800034b6:	60a6                	ld	ra,72(sp)
    800034b8:	6406                	ld	s0,64(sp)
    800034ba:	74e2                	ld	s1,56(sp)
    800034bc:	7942                	ld	s2,48(sp)
    800034be:	79a2                	ld	s3,40(sp)
    800034c0:	7a02                	ld	s4,32(sp)
    800034c2:	6ae2                	ld	s5,24(sp)
    800034c4:	6b42                	ld	s6,16(sp)
    800034c6:	6ba2                	ld	s7,8(sp)
    800034c8:	6161                	addi	sp,sp,80
    800034ca:	8082                	ret

00000000800034cc <iupdate>:
{
    800034cc:	1101                	addi	sp,sp,-32
    800034ce:	ec06                	sd	ra,24(sp)
    800034d0:	e822                	sd	s0,16(sp)
    800034d2:	e426                	sd	s1,8(sp)
    800034d4:	e04a                	sd	s2,0(sp)
    800034d6:	1000                	addi	s0,sp,32
    800034d8:	84aa                	mv	s1,a0
  bp = bread(ip->dev, IBLOCK(ip->inum, sb));
    800034da:	415c                	lw	a5,4(a0)
    800034dc:	0047d79b          	srliw	a5,a5,0x4
    800034e0:	0001c597          	auipc	a1,0x1c
    800034e4:	2e05a583          	lw	a1,736(a1) # 8001f7c0 <sb+0x18>
    800034e8:	9dbd                	addw	a1,a1,a5
    800034ea:	4108                	lw	a0,0(a0)
    800034ec:	00000097          	auipc	ra,0x0
    800034f0:	8aa080e7          	jalr	-1878(ra) # 80002d96 <bread>
    800034f4:	892a                	mv	s2,a0
  dip = (struct dinode*)bp->data + ip->inum%IPB;
    800034f6:	05850793          	addi	a5,a0,88
    800034fa:	40d8                	lw	a4,4(s1)
    800034fc:	8b3d                	andi	a4,a4,15
    800034fe:	071a                	slli	a4,a4,0x6
    80003500:	97ba                	add	a5,a5,a4
  dip->type = ip->type;
    80003502:	04449703          	lh	a4,68(s1)
    80003506:	00e79023          	sh	a4,0(a5)
  dip->major = ip->major;
    8000350a:	04649703          	lh	a4,70(s1)
    8000350e:	00e79123          	sh	a4,2(a5)
  dip->minor = ip->minor;
    80003512:	04849703          	lh	a4,72(s1)
    80003516:	00e79223          	sh	a4,4(a5)
  dip->nlink = ip->nlink;
    8000351a:	04a49703          	lh	a4,74(s1)
    8000351e:	00e79323          	sh	a4,6(a5)
  dip->size = ip->size;
    80003522:	44f8                	lw	a4,76(s1)
    80003524:	c798                	sw	a4,8(a5)
  memmove(dip->addrs, ip->addrs, sizeof(ip->addrs));
    80003526:	03400613          	li	a2,52
    8000352a:	05048593          	addi	a1,s1,80
    8000352e:	00c78513          	addi	a0,a5,12
    80003532:	ffffd097          	auipc	ra,0xffffd
    80003536:	7d0080e7          	jalr	2000(ra) # 80000d02 <memmove>
  log_write(bp);
    8000353a:	854a                	mv	a0,s2
    8000353c:	00001097          	auipc	ra,0x1
    80003540:	c0e080e7          	jalr	-1010(ra) # 8000414a <log_write>
  brelse(bp);
    80003544:	854a                	mv	a0,s2
    80003546:	00000097          	auipc	ra,0x0
    8000354a:	980080e7          	jalr	-1664(ra) # 80002ec6 <brelse>
}
    8000354e:	60e2                	ld	ra,24(sp)
    80003550:	6442                	ld	s0,16(sp)
    80003552:	64a2                	ld	s1,8(sp)
    80003554:	6902                	ld	s2,0(sp)
    80003556:	6105                	addi	sp,sp,32
    80003558:	8082                	ret

000000008000355a <idup>:
{
    8000355a:	1101                	addi	sp,sp,-32
    8000355c:	ec06                	sd	ra,24(sp)
    8000355e:	e822                	sd	s0,16(sp)
    80003560:	e426                	sd	s1,8(sp)
    80003562:	1000                	addi	s0,sp,32
    80003564:	84aa                	mv	s1,a0
  acquire(&itable.lock);
    80003566:	0001c517          	auipc	a0,0x1c
    8000356a:	26250513          	addi	a0,a0,610 # 8001f7c8 <itable>
    8000356e:	ffffd097          	auipc	ra,0xffffd
    80003572:	63c080e7          	jalr	1596(ra) # 80000baa <acquire>
  ip->ref++;
    80003576:	449c                	lw	a5,8(s1)
    80003578:	2785                	addiw	a5,a5,1
    8000357a:	c49c                	sw	a5,8(s1)
  release(&itable.lock);
    8000357c:	0001c517          	auipc	a0,0x1c
    80003580:	24c50513          	addi	a0,a0,588 # 8001f7c8 <itable>
    80003584:	ffffd097          	auipc	ra,0xffffd
    80003588:	6da080e7          	jalr	1754(ra) # 80000c5e <release>
}
    8000358c:	8526                	mv	a0,s1
    8000358e:	60e2                	ld	ra,24(sp)
    80003590:	6442                	ld	s0,16(sp)
    80003592:	64a2                	ld	s1,8(sp)
    80003594:	6105                	addi	sp,sp,32
    80003596:	8082                	ret

0000000080003598 <ilock>:
{
    80003598:	1101                	addi	sp,sp,-32
    8000359a:	ec06                	sd	ra,24(sp)
    8000359c:	e822                	sd	s0,16(sp)
    8000359e:	e426                	sd	s1,8(sp)
    800035a0:	e04a                	sd	s2,0(sp)
    800035a2:	1000                	addi	s0,sp,32
  if(ip == 0 || ip->ref < 1)
    800035a4:	c115                	beqz	a0,800035c8 <ilock+0x30>
    800035a6:	84aa                	mv	s1,a0
    800035a8:	451c                	lw	a5,8(a0)
    800035aa:	00f05f63          	blez	a5,800035c8 <ilock+0x30>
  acquiresleep(&ip->lock);
    800035ae:	0541                	addi	a0,a0,16
    800035b0:	00001097          	auipc	ra,0x1
    800035b4:	cb8080e7          	jalr	-840(ra) # 80004268 <acquiresleep>
  if(ip->valid == 0){
    800035b8:	40bc                	lw	a5,64(s1)
    800035ba:	cf99                	beqz	a5,800035d8 <ilock+0x40>
}
    800035bc:	60e2                	ld	ra,24(sp)
    800035be:	6442                	ld	s0,16(sp)
    800035c0:	64a2                	ld	s1,8(sp)
    800035c2:	6902                	ld	s2,0(sp)
    800035c4:	6105                	addi	sp,sp,32
    800035c6:	8082                	ret
    panic("ilock");
    800035c8:	00005517          	auipc	a0,0x5
    800035cc:	00050513          	mv	a0,a0
    800035d0:	ffffd097          	auipc	ra,0xffffd
    800035d4:	f6a080e7          	jalr	-150(ra) # 8000053a <panic>
    bp = bread(ip->dev, IBLOCK(ip->inum, sb));
    800035d8:	40dc                	lw	a5,4(s1)
    800035da:	0047d79b          	srliw	a5,a5,0x4
    800035de:	0001c597          	auipc	a1,0x1c
    800035e2:	1e25a583          	lw	a1,482(a1) # 8001f7c0 <sb+0x18>
    800035e6:	9dbd                	addw	a1,a1,a5
    800035e8:	4088                	lw	a0,0(s1)
    800035ea:	fffff097          	auipc	ra,0xfffff
    800035ee:	7ac080e7          	jalr	1964(ra) # 80002d96 <bread>
    800035f2:	892a                	mv	s2,a0
    dip = (struct dinode*)bp->data + ip->inum%IPB;
    800035f4:	05850593          	addi	a1,a0,88 # 80008620 <syscalls+0x1d8>
    800035f8:	40dc                	lw	a5,4(s1)
    800035fa:	8bbd                	andi	a5,a5,15
    800035fc:	079a                	slli	a5,a5,0x6
    800035fe:	95be                	add	a1,a1,a5
    ip->type = dip->type;
    80003600:	00059783          	lh	a5,0(a1)
    80003604:	04f49223          	sh	a5,68(s1)
    ip->major = dip->major;
    80003608:	00259783          	lh	a5,2(a1)
    8000360c:	04f49323          	sh	a5,70(s1)
    ip->minor = dip->minor;
    80003610:	00459783          	lh	a5,4(a1)
    80003614:	04f49423          	sh	a5,72(s1)
    ip->nlink = dip->nlink;
    80003618:	00659783          	lh	a5,6(a1)
    8000361c:	04f49523          	sh	a5,74(s1)
    ip->size = dip->size;
    80003620:	459c                	lw	a5,8(a1)
    80003622:	c4fc                	sw	a5,76(s1)
    memmove(ip->addrs, dip->addrs, sizeof(ip->addrs));
    80003624:	03400613          	li	a2,52
    80003628:	05b1                	addi	a1,a1,12
    8000362a:	05048513          	addi	a0,s1,80
    8000362e:	ffffd097          	auipc	ra,0xffffd
    80003632:	6d4080e7          	jalr	1748(ra) # 80000d02 <memmove>
    brelse(bp);
    80003636:	854a                	mv	a0,s2
    80003638:	00000097          	auipc	ra,0x0
    8000363c:	88e080e7          	jalr	-1906(ra) # 80002ec6 <brelse>
    ip->valid = 1;
    80003640:	4785                	li	a5,1
    80003642:	c0bc                	sw	a5,64(s1)
    if(ip->type == 0)
    80003644:	04449783          	lh	a5,68(s1)
    80003648:	fbb5                	bnez	a5,800035bc <ilock+0x24>
      panic("ilock: no type");
    8000364a:	00005517          	auipc	a0,0x5
    8000364e:	f8650513          	addi	a0,a0,-122 # 800085d0 <syscalls+0x188>
    80003652:	ffffd097          	auipc	ra,0xffffd
    80003656:	ee8080e7          	jalr	-280(ra) # 8000053a <panic>

000000008000365a <iunlock>:
{
    8000365a:	1101                	addi	sp,sp,-32
    8000365c:	ec06                	sd	ra,24(sp)
    8000365e:	e822                	sd	s0,16(sp)
    80003660:	e426                	sd	s1,8(sp)
    80003662:	e04a                	sd	s2,0(sp)
    80003664:	1000                	addi	s0,sp,32
  if(ip == 0 || !holdingsleep(&ip->lock) || ip->ref < 1)
    80003666:	c905                	beqz	a0,80003696 <iunlock+0x3c>
    80003668:	84aa                	mv	s1,a0
    8000366a:	01050913          	addi	s2,a0,16
    8000366e:	854a                	mv	a0,s2
    80003670:	00001097          	auipc	ra,0x1
    80003674:	c92080e7          	jalr	-878(ra) # 80004302 <holdingsleep>
    80003678:	cd19                	beqz	a0,80003696 <iunlock+0x3c>
    8000367a:	449c                	lw	a5,8(s1)
    8000367c:	00f05d63          	blez	a5,80003696 <iunlock+0x3c>
  releasesleep(&ip->lock);
    80003680:	854a                	mv	a0,s2
    80003682:	00001097          	auipc	ra,0x1
    80003686:	c3c080e7          	jalr	-964(ra) # 800042be <releasesleep>
}
    8000368a:	60e2                	ld	ra,24(sp)
    8000368c:	6442                	ld	s0,16(sp)
    8000368e:	64a2                	ld	s1,8(sp)
    80003690:	6902                	ld	s2,0(sp)
    80003692:	6105                	addi	sp,sp,32
    80003694:	8082                	ret
    panic("iunlock");
    80003696:	00005517          	auipc	a0,0x5
    8000369a:	f4a50513          	addi	a0,a0,-182 # 800085e0 <syscalls+0x198>
    8000369e:	ffffd097          	auipc	ra,0xffffd
    800036a2:	e9c080e7          	jalr	-356(ra) # 8000053a <panic>

00000000800036a6 <itrunc>:

// Truncate inode (discard contents).
// Caller must hold ip->lock.
void
itrunc(struct inode *ip)
{
    800036a6:	7179                	addi	sp,sp,-48
    800036a8:	f406                	sd	ra,40(sp)
    800036aa:	f022                	sd	s0,32(sp)
    800036ac:	ec26                	sd	s1,24(sp)
    800036ae:	e84a                	sd	s2,16(sp)
    800036b0:	e44e                	sd	s3,8(sp)
    800036b2:	e052                	sd	s4,0(sp)
    800036b4:	1800                	addi	s0,sp,48
    800036b6:	89aa                	mv	s3,a0
  int i, j;
  struct buf *bp;
  uint *a;

  for(i = 0; i < NDIRECT; i++){
    800036b8:	05050493          	addi	s1,a0,80
    800036bc:	08050913          	addi	s2,a0,128
    800036c0:	a021                	j	800036c8 <itrunc+0x22>
    800036c2:	0491                	addi	s1,s1,4
    800036c4:	01248d63          	beq	s1,s2,800036de <itrunc+0x38>
    if(ip->addrs[i]){
    800036c8:	408c                	lw	a1,0(s1)
    800036ca:	dde5                	beqz	a1,800036c2 <itrunc+0x1c>
      bfree(ip->dev, ip->addrs[i]);
    800036cc:	0009a503          	lw	a0,0(s3)
    800036d0:	00000097          	auipc	ra,0x0
    800036d4:	90c080e7          	jalr	-1780(ra) # 80002fdc <bfree>
      ip->addrs[i] = 0;
    800036d8:	0004a023          	sw	zero,0(s1)
    800036dc:	b7dd                	j	800036c2 <itrunc+0x1c>
    }
  }

  if(ip->addrs[NDIRECT]){
    800036de:	0809a583          	lw	a1,128(s3)
    800036e2:	e185                	bnez	a1,80003702 <itrunc+0x5c>
    brelse(bp);
    bfree(ip->dev, ip->addrs[NDIRECT]);
    ip->addrs[NDIRECT] = 0;
  }

  ip->size = 0;
    800036e4:	0409a623          	sw	zero,76(s3)
  iupdate(ip);
    800036e8:	854e                	mv	a0,s3
    800036ea:	00000097          	auipc	ra,0x0
    800036ee:	de2080e7          	jalr	-542(ra) # 800034cc <iupdate>
}
    800036f2:	70a2                	ld	ra,40(sp)
    800036f4:	7402                	ld	s0,32(sp)
    800036f6:	64e2                	ld	s1,24(sp)
    800036f8:	6942                	ld	s2,16(sp)
    800036fa:	69a2                	ld	s3,8(sp)
    800036fc:	6a02                	ld	s4,0(sp)
    800036fe:	6145                	addi	sp,sp,48
    80003700:	8082                	ret
    bp = bread(ip->dev, ip->addrs[NDIRECT]);
    80003702:	0009a503          	lw	a0,0(s3)
    80003706:	fffff097          	auipc	ra,0xfffff
    8000370a:	690080e7          	jalr	1680(ra) # 80002d96 <bread>
    8000370e:	8a2a                	mv	s4,a0
    for(j = 0; j < NINDIRECT; j++){
    80003710:	05850493          	addi	s1,a0,88
    80003714:	45850913          	addi	s2,a0,1112
    80003718:	a021                	j	80003720 <itrunc+0x7a>
    8000371a:	0491                	addi	s1,s1,4
    8000371c:	01248b63          	beq	s1,s2,80003732 <itrunc+0x8c>
      if(a[j])
    80003720:	408c                	lw	a1,0(s1)
    80003722:	dde5                	beqz	a1,8000371a <itrunc+0x74>
        bfree(ip->dev, a[j]);
    80003724:	0009a503          	lw	a0,0(s3)
    80003728:	00000097          	auipc	ra,0x0
    8000372c:	8b4080e7          	jalr	-1868(ra) # 80002fdc <bfree>
    80003730:	b7ed                	j	8000371a <itrunc+0x74>
    brelse(bp);
    80003732:	8552                	mv	a0,s4
    80003734:	fffff097          	auipc	ra,0xfffff
    80003738:	792080e7          	jalr	1938(ra) # 80002ec6 <brelse>
    bfree(ip->dev, ip->addrs[NDIRECT]);
    8000373c:	0809a583          	lw	a1,128(s3)
    80003740:	0009a503          	lw	a0,0(s3)
    80003744:	00000097          	auipc	ra,0x0
    80003748:	898080e7          	jalr	-1896(ra) # 80002fdc <bfree>
    ip->addrs[NDIRECT] = 0;
    8000374c:	0809a023          	sw	zero,128(s3)
    80003750:	bf51                	j	800036e4 <itrunc+0x3e>

0000000080003752 <iput>:
{
    80003752:	1101                	addi	sp,sp,-32
    80003754:	ec06                	sd	ra,24(sp)
    80003756:	e822                	sd	s0,16(sp)
    80003758:	e426                	sd	s1,8(sp)
    8000375a:	e04a                	sd	s2,0(sp)
    8000375c:	1000                	addi	s0,sp,32
    8000375e:	84aa                	mv	s1,a0
  acquire(&itable.lock);
    80003760:	0001c517          	auipc	a0,0x1c
    80003764:	06850513          	addi	a0,a0,104 # 8001f7c8 <itable>
    80003768:	ffffd097          	auipc	ra,0xffffd
    8000376c:	442080e7          	jalr	1090(ra) # 80000baa <acquire>
  if(ip->ref == 1 && ip->valid && ip->nlink == 0){
    80003770:	4498                	lw	a4,8(s1)
    80003772:	4785                	li	a5,1
    80003774:	02f70363          	beq	a4,a5,8000379a <iput+0x48>
  ip->ref--;
    80003778:	449c                	lw	a5,8(s1)
    8000377a:	37fd                	addiw	a5,a5,-1
    8000377c:	c49c                	sw	a5,8(s1)
  release(&itable.lock);
    8000377e:	0001c517          	auipc	a0,0x1c
    80003782:	04a50513          	addi	a0,a0,74 # 8001f7c8 <itable>
    80003786:	ffffd097          	auipc	ra,0xffffd
    8000378a:	4d8080e7          	jalr	1240(ra) # 80000c5e <release>
}
    8000378e:	60e2                	ld	ra,24(sp)
    80003790:	6442                	ld	s0,16(sp)
    80003792:	64a2                	ld	s1,8(sp)
    80003794:	6902                	ld	s2,0(sp)
    80003796:	6105                	addi	sp,sp,32
    80003798:	8082                	ret
  if(ip->ref == 1 && ip->valid && ip->nlink == 0){
    8000379a:	40bc                	lw	a5,64(s1)
    8000379c:	dff1                	beqz	a5,80003778 <iput+0x26>
    8000379e:	04a49783          	lh	a5,74(s1)
    800037a2:	fbf9                	bnez	a5,80003778 <iput+0x26>
    acquiresleep(&ip->lock);
    800037a4:	01048913          	addi	s2,s1,16
    800037a8:	854a                	mv	a0,s2
    800037aa:	00001097          	auipc	ra,0x1
    800037ae:	abe080e7          	jalr	-1346(ra) # 80004268 <acquiresleep>
    release(&itable.lock);
    800037b2:	0001c517          	auipc	a0,0x1c
    800037b6:	01650513          	addi	a0,a0,22 # 8001f7c8 <itable>
    800037ba:	ffffd097          	auipc	ra,0xffffd
    800037be:	4a4080e7          	jalr	1188(ra) # 80000c5e <release>
    itrunc(ip);
    800037c2:	8526                	mv	a0,s1
    800037c4:	00000097          	auipc	ra,0x0
    800037c8:	ee2080e7          	jalr	-286(ra) # 800036a6 <itrunc>
    ip->type = 0;
    800037cc:	04049223          	sh	zero,68(s1)
    iupdate(ip);
    800037d0:	8526                	mv	a0,s1
    800037d2:	00000097          	auipc	ra,0x0
    800037d6:	cfa080e7          	jalr	-774(ra) # 800034cc <iupdate>
    ip->valid = 0;
    800037da:	0404a023          	sw	zero,64(s1)
    releasesleep(&ip->lock);
    800037de:	854a                	mv	a0,s2
    800037e0:	00001097          	auipc	ra,0x1
    800037e4:	ade080e7          	jalr	-1314(ra) # 800042be <releasesleep>
    acquire(&itable.lock);
    800037e8:	0001c517          	auipc	a0,0x1c
    800037ec:	fe050513          	addi	a0,a0,-32 # 8001f7c8 <itable>
    800037f0:	ffffd097          	auipc	ra,0xffffd
    800037f4:	3ba080e7          	jalr	954(ra) # 80000baa <acquire>
    800037f8:	b741                	j	80003778 <iput+0x26>

00000000800037fa <iunlockput>:
{
    800037fa:	1101                	addi	sp,sp,-32
    800037fc:	ec06                	sd	ra,24(sp)
    800037fe:	e822                	sd	s0,16(sp)
    80003800:	e426                	sd	s1,8(sp)
    80003802:	1000                	addi	s0,sp,32
    80003804:	84aa                	mv	s1,a0
  iunlock(ip);
    80003806:	00000097          	auipc	ra,0x0
    8000380a:	e54080e7          	jalr	-428(ra) # 8000365a <iunlock>
  iput(ip);
    8000380e:	8526                	mv	a0,s1
    80003810:	00000097          	auipc	ra,0x0
    80003814:	f42080e7          	jalr	-190(ra) # 80003752 <iput>
}
    80003818:	60e2                	ld	ra,24(sp)
    8000381a:	6442                	ld	s0,16(sp)
    8000381c:	64a2                	ld	s1,8(sp)
    8000381e:	6105                	addi	sp,sp,32
    80003820:	8082                	ret

0000000080003822 <stati>:

// Copy stat information from inode.
// Caller must hold ip->lock.
void
stati(struct inode *ip, struct stat *st)
{
    80003822:	1141                	addi	sp,sp,-16
    80003824:	e422                	sd	s0,8(sp)
    80003826:	0800                	addi	s0,sp,16
  st->dev = ip->dev;
    80003828:	411c                	lw	a5,0(a0)
    8000382a:	c19c                	sw	a5,0(a1)
  st->ino = ip->inum;
    8000382c:	415c                	lw	a5,4(a0)
    8000382e:	c1dc                	sw	a5,4(a1)
  st->type = ip->type;
    80003830:	04451783          	lh	a5,68(a0)
    80003834:	00f59423          	sh	a5,8(a1)
  st->nlink = ip->nlink;
    80003838:	04a51783          	lh	a5,74(a0)
    8000383c:	00f59523          	sh	a5,10(a1)
  st->size = ip->size;
    80003840:	04c56783          	lwu	a5,76(a0)
    80003844:	e99c                	sd	a5,16(a1)
}
    80003846:	6422                	ld	s0,8(sp)
    80003848:	0141                	addi	sp,sp,16
    8000384a:	8082                	ret

000000008000384c <readi>:
readi(struct inode *ip, int user_dst, uint64 dst, uint off, uint n)
{
  uint tot, m;
  struct buf *bp;

  if(off > ip->size || off + n < off)
    8000384c:	457c                	lw	a5,76(a0)
    8000384e:	0ed7e963          	bltu	a5,a3,80003940 <readi+0xf4>
{
    80003852:	7159                	addi	sp,sp,-112
    80003854:	f486                	sd	ra,104(sp)
    80003856:	f0a2                	sd	s0,96(sp)
    80003858:	eca6                	sd	s1,88(sp)
    8000385a:	e8ca                	sd	s2,80(sp)
    8000385c:	e4ce                	sd	s3,72(sp)
    8000385e:	e0d2                	sd	s4,64(sp)
    80003860:	fc56                	sd	s5,56(sp)
    80003862:	f85a                	sd	s6,48(sp)
    80003864:	f45e                	sd	s7,40(sp)
    80003866:	f062                	sd	s8,32(sp)
    80003868:	ec66                	sd	s9,24(sp)
    8000386a:	e86a                	sd	s10,16(sp)
    8000386c:	e46e                	sd	s11,8(sp)
    8000386e:	1880                	addi	s0,sp,112
    80003870:	8baa                	mv	s7,a0
    80003872:	8c2e                	mv	s8,a1
    80003874:	8ab2                	mv	s5,a2
    80003876:	84b6                	mv	s1,a3
    80003878:	8b3a                	mv	s6,a4
  if(off > ip->size || off + n < off)
    8000387a:	9f35                	addw	a4,a4,a3
    return 0;
    8000387c:	4501                	li	a0,0
  if(off > ip->size || off + n < off)
    8000387e:	0ad76063          	bltu	a4,a3,8000391e <readi+0xd2>
  if(off + n > ip->size)
    80003882:	00e7f463          	bgeu	a5,a4,8000388a <readi+0x3e>
    n = ip->size - off;
    80003886:	40d78b3b          	subw	s6,a5,a3

  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    8000388a:	0a0b0963          	beqz	s6,8000393c <readi+0xf0>
    8000388e:	4981                	li	s3,0
    bp = bread(ip->dev, bmap(ip, off/BSIZE));
    m = min(n - tot, BSIZE - off%BSIZE);
    80003890:	40000d13          	li	s10,1024
    if(either_copyout(user_dst, dst, bp->data + (off % BSIZE), m) == -1) {
    80003894:	5cfd                	li	s9,-1
    80003896:	a82d                	j	800038d0 <readi+0x84>
    80003898:	020a1d93          	slli	s11,s4,0x20
    8000389c:	020ddd93          	srli	s11,s11,0x20
    800038a0:	05890613          	addi	a2,s2,88
    800038a4:	86ee                	mv	a3,s11
    800038a6:	963a                	add	a2,a2,a4
    800038a8:	85d6                	mv	a1,s5
    800038aa:	8562                	mv	a0,s8
    800038ac:	fffff097          	auipc	ra,0xfffff
    800038b0:	b2c080e7          	jalr	-1236(ra) # 800023d8 <either_copyout>
    800038b4:	05950d63          	beq	a0,s9,8000390e <readi+0xc2>
      brelse(bp);
      tot = -1;
      break;
    }
    brelse(bp);
    800038b8:	854a                	mv	a0,s2
    800038ba:	fffff097          	auipc	ra,0xfffff
    800038be:	60c080e7          	jalr	1548(ra) # 80002ec6 <brelse>
  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    800038c2:	013a09bb          	addw	s3,s4,s3
    800038c6:	009a04bb          	addw	s1,s4,s1
    800038ca:	9aee                	add	s5,s5,s11
    800038cc:	0569f763          	bgeu	s3,s6,8000391a <readi+0xce>
    bp = bread(ip->dev, bmap(ip, off/BSIZE));
    800038d0:	000ba903          	lw	s2,0(s7)
    800038d4:	00a4d59b          	srliw	a1,s1,0xa
    800038d8:	855e                	mv	a0,s7
    800038da:	00000097          	auipc	ra,0x0
    800038de:	8ac080e7          	jalr	-1876(ra) # 80003186 <bmap>
    800038e2:	0005059b          	sext.w	a1,a0
    800038e6:	854a                	mv	a0,s2
    800038e8:	fffff097          	auipc	ra,0xfffff
    800038ec:	4ae080e7          	jalr	1198(ra) # 80002d96 <bread>
    800038f0:	892a                	mv	s2,a0
    m = min(n - tot, BSIZE - off%BSIZE);
    800038f2:	3ff4f713          	andi	a4,s1,1023
    800038f6:	40ed07bb          	subw	a5,s10,a4
    800038fa:	413b06bb          	subw	a3,s6,s3
    800038fe:	8a3e                	mv	s4,a5
    80003900:	2781                	sext.w	a5,a5
    80003902:	0006861b          	sext.w	a2,a3
    80003906:	f8f679e3          	bgeu	a2,a5,80003898 <readi+0x4c>
    8000390a:	8a36                	mv	s4,a3
    8000390c:	b771                	j	80003898 <readi+0x4c>
      brelse(bp);
    8000390e:	854a                	mv	a0,s2
    80003910:	fffff097          	auipc	ra,0xfffff
    80003914:	5b6080e7          	jalr	1462(ra) # 80002ec6 <brelse>
      tot = -1;
    80003918:	59fd                	li	s3,-1
  }
  return tot;
    8000391a:	0009851b          	sext.w	a0,s3
}
    8000391e:	70a6                	ld	ra,104(sp)
    80003920:	7406                	ld	s0,96(sp)
    80003922:	64e6                	ld	s1,88(sp)
    80003924:	6946                	ld	s2,80(sp)
    80003926:	69a6                	ld	s3,72(sp)
    80003928:	6a06                	ld	s4,64(sp)
    8000392a:	7ae2                	ld	s5,56(sp)
    8000392c:	7b42                	ld	s6,48(sp)
    8000392e:	7ba2                	ld	s7,40(sp)
    80003930:	7c02                	ld	s8,32(sp)
    80003932:	6ce2                	ld	s9,24(sp)
    80003934:	6d42                	ld	s10,16(sp)
    80003936:	6da2                	ld	s11,8(sp)
    80003938:	6165                	addi	sp,sp,112
    8000393a:	8082                	ret
  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    8000393c:	89da                	mv	s3,s6
    8000393e:	bff1                	j	8000391a <readi+0xce>
    return 0;
    80003940:	4501                	li	a0,0
}
    80003942:	8082                	ret

0000000080003944 <writei>:
writei(struct inode *ip, int user_src, uint64 src, uint off, uint n)
{
  uint tot, m;
  struct buf *bp;

  if(off > ip->size || off + n < off)
    80003944:	457c                	lw	a5,76(a0)
    80003946:	10d7e863          	bltu	a5,a3,80003a56 <writei+0x112>
{
    8000394a:	7159                	addi	sp,sp,-112
    8000394c:	f486                	sd	ra,104(sp)
    8000394e:	f0a2                	sd	s0,96(sp)
    80003950:	eca6                	sd	s1,88(sp)
    80003952:	e8ca                	sd	s2,80(sp)
    80003954:	e4ce                	sd	s3,72(sp)
    80003956:	e0d2                	sd	s4,64(sp)
    80003958:	fc56                	sd	s5,56(sp)
    8000395a:	f85a                	sd	s6,48(sp)
    8000395c:	f45e                	sd	s7,40(sp)
    8000395e:	f062                	sd	s8,32(sp)
    80003960:	ec66                	sd	s9,24(sp)
    80003962:	e86a                	sd	s10,16(sp)
    80003964:	e46e                	sd	s11,8(sp)
    80003966:	1880                	addi	s0,sp,112
    80003968:	8b2a                	mv	s6,a0
    8000396a:	8c2e                	mv	s8,a1
    8000396c:	8ab2                	mv	s5,a2
    8000396e:	8936                	mv	s2,a3
    80003970:	8bba                	mv	s7,a4
  if(off > ip->size || off + n < off)
    80003972:	00e687bb          	addw	a5,a3,a4
    80003976:	0ed7e263          	bltu	a5,a3,80003a5a <writei+0x116>
    return -1;
  if(off + n > MAXFILE*BSIZE)
    8000397a:	00043737          	lui	a4,0x43
    8000397e:	0ef76063          	bltu	a4,a5,80003a5e <writei+0x11a>
    return -1;

  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    80003982:	0c0b8863          	beqz	s7,80003a52 <writei+0x10e>
    80003986:	4a01                	li	s4,0
    bp = bread(ip->dev, bmap(ip, off/BSIZE));
    m = min(n - tot, BSIZE - off%BSIZE);
    80003988:	40000d13          	li	s10,1024
    if(either_copyin(bp->data + (off % BSIZE), user_src, src, m) == -1) {
    8000398c:	5cfd                	li	s9,-1
    8000398e:	a091                	j	800039d2 <writei+0x8e>
    80003990:	02099d93          	slli	s11,s3,0x20
    80003994:	020ddd93          	srli	s11,s11,0x20
    80003998:	05848513          	addi	a0,s1,88
    8000399c:	86ee                	mv	a3,s11
    8000399e:	8656                	mv	a2,s5
    800039a0:	85e2                	mv	a1,s8
    800039a2:	953a                	add	a0,a0,a4
    800039a4:	fffff097          	auipc	ra,0xfffff
    800039a8:	a8a080e7          	jalr	-1398(ra) # 8000242e <either_copyin>
    800039ac:	07950263          	beq	a0,s9,80003a10 <writei+0xcc>
      brelse(bp);
      break;
    }
    log_write(bp);
    800039b0:	8526                	mv	a0,s1
    800039b2:	00000097          	auipc	ra,0x0
    800039b6:	798080e7          	jalr	1944(ra) # 8000414a <log_write>
    brelse(bp);
    800039ba:	8526                	mv	a0,s1
    800039bc:	fffff097          	auipc	ra,0xfffff
    800039c0:	50a080e7          	jalr	1290(ra) # 80002ec6 <brelse>
  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    800039c4:	01498a3b          	addw	s4,s3,s4
    800039c8:	0129893b          	addw	s2,s3,s2
    800039cc:	9aee                	add	s5,s5,s11
    800039ce:	057a7663          	bgeu	s4,s7,80003a1a <writei+0xd6>
    bp = bread(ip->dev, bmap(ip, off/BSIZE));
    800039d2:	000b2483          	lw	s1,0(s6)
    800039d6:	00a9559b          	srliw	a1,s2,0xa
    800039da:	855a                	mv	a0,s6
    800039dc:	fffff097          	auipc	ra,0xfffff
    800039e0:	7aa080e7          	jalr	1962(ra) # 80003186 <bmap>
    800039e4:	0005059b          	sext.w	a1,a0
    800039e8:	8526                	mv	a0,s1
    800039ea:	fffff097          	auipc	ra,0xfffff
    800039ee:	3ac080e7          	jalr	940(ra) # 80002d96 <bread>
    800039f2:	84aa                	mv	s1,a0
    m = min(n - tot, BSIZE - off%BSIZE);
    800039f4:	3ff97713          	andi	a4,s2,1023
    800039f8:	40ed07bb          	subw	a5,s10,a4
    800039fc:	414b86bb          	subw	a3,s7,s4
    80003a00:	89be                	mv	s3,a5
    80003a02:	2781                	sext.w	a5,a5
    80003a04:	0006861b          	sext.w	a2,a3
    80003a08:	f8f674e3          	bgeu	a2,a5,80003990 <writei+0x4c>
    80003a0c:	89b6                	mv	s3,a3
    80003a0e:	b749                	j	80003990 <writei+0x4c>
      brelse(bp);
    80003a10:	8526                	mv	a0,s1
    80003a12:	fffff097          	auipc	ra,0xfffff
    80003a16:	4b4080e7          	jalr	1204(ra) # 80002ec6 <brelse>
  }

  if(off > ip->size)
    80003a1a:	04cb2783          	lw	a5,76(s6)
    80003a1e:	0127f463          	bgeu	a5,s2,80003a26 <writei+0xe2>
    ip->size = off;
    80003a22:	052b2623          	sw	s2,76(s6)

  // write the i-node back to disk even if the size didn't change
  // because the loop above might have called bmap() and added a new
  // block to ip->addrs[].
  iupdate(ip);
    80003a26:	855a                	mv	a0,s6
    80003a28:	00000097          	auipc	ra,0x0
    80003a2c:	aa4080e7          	jalr	-1372(ra) # 800034cc <iupdate>

  return tot;
    80003a30:	000a051b          	sext.w	a0,s4
}
    80003a34:	70a6                	ld	ra,104(sp)
    80003a36:	7406                	ld	s0,96(sp)
    80003a38:	64e6                	ld	s1,88(sp)
    80003a3a:	6946                	ld	s2,80(sp)
    80003a3c:	69a6                	ld	s3,72(sp)
    80003a3e:	6a06                	ld	s4,64(sp)
    80003a40:	7ae2                	ld	s5,56(sp)
    80003a42:	7b42                	ld	s6,48(sp)
    80003a44:	7ba2                	ld	s7,40(sp)
    80003a46:	7c02                	ld	s8,32(sp)
    80003a48:	6ce2                	ld	s9,24(sp)
    80003a4a:	6d42                	ld	s10,16(sp)
    80003a4c:	6da2                	ld	s11,8(sp)
    80003a4e:	6165                	addi	sp,sp,112
    80003a50:	8082                	ret
  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    80003a52:	8a5e                	mv	s4,s7
    80003a54:	bfc9                	j	80003a26 <writei+0xe2>
    return -1;
    80003a56:	557d                	li	a0,-1
}
    80003a58:	8082                	ret
    return -1;
    80003a5a:	557d                	li	a0,-1
    80003a5c:	bfe1                	j	80003a34 <writei+0xf0>
    return -1;
    80003a5e:	557d                	li	a0,-1
    80003a60:	bfd1                	j	80003a34 <writei+0xf0>

0000000080003a62 <namecmp>:

// Directories

int
namecmp(const char *s, const char *t)
{
    80003a62:	1141                	addi	sp,sp,-16
    80003a64:	e406                	sd	ra,8(sp)
    80003a66:	e022                	sd	s0,0(sp)
    80003a68:	0800                	addi	s0,sp,16
  return strncmp(s, t, DIRSIZ);
    80003a6a:	4639                	li	a2,14
    80003a6c:	ffffd097          	auipc	ra,0xffffd
    80003a70:	30a080e7          	jalr	778(ra) # 80000d76 <strncmp>
}
    80003a74:	60a2                	ld	ra,8(sp)
    80003a76:	6402                	ld	s0,0(sp)
    80003a78:	0141                	addi	sp,sp,16
    80003a7a:	8082                	ret

0000000080003a7c <dirlookup>:

// Look for a directory entry in a directory.
// If found, set *poff to byte offset of entry.
struct inode*
dirlookup(struct inode *dp, char *name, uint *poff)
{
    80003a7c:	7139                	addi	sp,sp,-64
    80003a7e:	fc06                	sd	ra,56(sp)
    80003a80:	f822                	sd	s0,48(sp)
    80003a82:	f426                	sd	s1,40(sp)
    80003a84:	f04a                	sd	s2,32(sp)
    80003a86:	ec4e                	sd	s3,24(sp)
    80003a88:	e852                	sd	s4,16(sp)
    80003a8a:	0080                	addi	s0,sp,64
  uint off, inum;
  struct dirent de;

  if(dp->type != T_DIR)
    80003a8c:	04451703          	lh	a4,68(a0)
    80003a90:	4785                	li	a5,1
    80003a92:	00f71a63          	bne	a4,a5,80003aa6 <dirlookup+0x2a>
    80003a96:	892a                	mv	s2,a0
    80003a98:	89ae                	mv	s3,a1
    80003a9a:	8a32                	mv	s4,a2
    panic("dirlookup not DIR");

  for(off = 0; off < dp->size; off += sizeof(de)){
    80003a9c:	457c                	lw	a5,76(a0)
    80003a9e:	4481                	li	s1,0
      inum = de.inum;
      return iget(dp->dev, inum);
    }
  }

  return 0;
    80003aa0:	4501                	li	a0,0
  for(off = 0; off < dp->size; off += sizeof(de)){
    80003aa2:	e79d                	bnez	a5,80003ad0 <dirlookup+0x54>
    80003aa4:	a8a5                	j	80003b1c <dirlookup+0xa0>
    panic("dirlookup not DIR");
    80003aa6:	00005517          	auipc	a0,0x5
    80003aaa:	b4250513          	addi	a0,a0,-1214 # 800085e8 <syscalls+0x1a0>
    80003aae:	ffffd097          	auipc	ra,0xffffd
    80003ab2:	a8c080e7          	jalr	-1396(ra) # 8000053a <panic>
      panic("dirlookup read");
    80003ab6:	00005517          	auipc	a0,0x5
    80003aba:	b4a50513          	addi	a0,a0,-1206 # 80008600 <syscalls+0x1b8>
    80003abe:	ffffd097          	auipc	ra,0xffffd
    80003ac2:	a7c080e7          	jalr	-1412(ra) # 8000053a <panic>
  for(off = 0; off < dp->size; off += sizeof(de)){
    80003ac6:	24c1                	addiw	s1,s1,16
    80003ac8:	04c92783          	lw	a5,76(s2)
    80003acc:	04f4f763          	bgeu	s1,a5,80003b1a <dirlookup+0x9e>
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80003ad0:	4741                	li	a4,16
    80003ad2:	86a6                	mv	a3,s1
    80003ad4:	fc040613          	addi	a2,s0,-64
    80003ad8:	4581                	li	a1,0
    80003ada:	854a                	mv	a0,s2
    80003adc:	00000097          	auipc	ra,0x0
    80003ae0:	d70080e7          	jalr	-656(ra) # 8000384c <readi>
    80003ae4:	47c1                	li	a5,16
    80003ae6:	fcf518e3          	bne	a0,a5,80003ab6 <dirlookup+0x3a>
    if(de.inum == 0)
    80003aea:	fc045783          	lhu	a5,-64(s0)
    80003aee:	dfe1                	beqz	a5,80003ac6 <dirlookup+0x4a>
    if(namecmp(name, de.name) == 0){
    80003af0:	fc240593          	addi	a1,s0,-62
    80003af4:	854e                	mv	a0,s3
    80003af6:	00000097          	auipc	ra,0x0
    80003afa:	f6c080e7          	jalr	-148(ra) # 80003a62 <namecmp>
    80003afe:	f561                	bnez	a0,80003ac6 <dirlookup+0x4a>
      if(poff)
    80003b00:	000a0463          	beqz	s4,80003b08 <dirlookup+0x8c>
        *poff = off;
    80003b04:	009a2023          	sw	s1,0(s4)
      return iget(dp->dev, inum);
    80003b08:	fc045583          	lhu	a1,-64(s0)
    80003b0c:	00092503          	lw	a0,0(s2)
    80003b10:	fffff097          	auipc	ra,0xfffff
    80003b14:	752080e7          	jalr	1874(ra) # 80003262 <iget>
    80003b18:	a011                	j	80003b1c <dirlookup+0xa0>
  return 0;
    80003b1a:	4501                	li	a0,0
}
    80003b1c:	70e2                	ld	ra,56(sp)
    80003b1e:	7442                	ld	s0,48(sp)
    80003b20:	74a2                	ld	s1,40(sp)
    80003b22:	7902                	ld	s2,32(sp)
    80003b24:	69e2                	ld	s3,24(sp)
    80003b26:	6a42                	ld	s4,16(sp)
    80003b28:	6121                	addi	sp,sp,64
    80003b2a:	8082                	ret

0000000080003b2c <namex>:
// If parent != 0, return the inode for the parent and copy the final
// path element into name, which must have room for DIRSIZ bytes.
// Must be called inside a transaction since it calls iput().
static struct inode*
namex(char *path, int nameiparent, char *name)
{
    80003b2c:	711d                	addi	sp,sp,-96
    80003b2e:	ec86                	sd	ra,88(sp)
    80003b30:	e8a2                	sd	s0,80(sp)
    80003b32:	e4a6                	sd	s1,72(sp)
    80003b34:	e0ca                	sd	s2,64(sp)
    80003b36:	fc4e                	sd	s3,56(sp)
    80003b38:	f852                	sd	s4,48(sp)
    80003b3a:	f456                	sd	s5,40(sp)
    80003b3c:	f05a                	sd	s6,32(sp)
    80003b3e:	ec5e                	sd	s7,24(sp)
    80003b40:	e862                	sd	s8,16(sp)
    80003b42:	e466                	sd	s9,8(sp)
    80003b44:	e06a                	sd	s10,0(sp)
    80003b46:	1080                	addi	s0,sp,96
    80003b48:	84aa                	mv	s1,a0
    80003b4a:	8b2e                	mv	s6,a1
    80003b4c:	8ab2                	mv	s5,a2
  struct inode *ip, *next;

  if(*path == '/')
    80003b4e:	00054703          	lbu	a4,0(a0)
    80003b52:	02f00793          	li	a5,47
    80003b56:	02f70363          	beq	a4,a5,80003b7c <namex+0x50>
    ip = iget(ROOTDEV, ROOTINO);
  else
    ip = idup(myproc()->cwd);
    80003b5a:	ffffe097          	auipc	ra,0xffffe
    80003b5e:	e16080e7          	jalr	-490(ra) # 80001970 <myproc>
    80003b62:	15053503          	ld	a0,336(a0)
    80003b66:	00000097          	auipc	ra,0x0
    80003b6a:	9f4080e7          	jalr	-1548(ra) # 8000355a <idup>
    80003b6e:	8a2a                	mv	s4,a0
  while(*path == '/')
    80003b70:	02f00913          	li	s2,47
  if(len >= DIRSIZ)
    80003b74:	4cb5                	li	s9,13
  len = path - s;
    80003b76:	4b81                	li	s7,0

  while((path = skipelem(path, name)) != 0){
    ilock(ip);
    if(ip->type != T_DIR){
    80003b78:	4c05                	li	s8,1
    80003b7a:	a87d                	j	80003c38 <namex+0x10c>
    ip = iget(ROOTDEV, ROOTINO);
    80003b7c:	4585                	li	a1,1
    80003b7e:	4505                	li	a0,1
    80003b80:	fffff097          	auipc	ra,0xfffff
    80003b84:	6e2080e7          	jalr	1762(ra) # 80003262 <iget>
    80003b88:	8a2a                	mv	s4,a0
    80003b8a:	b7dd                	j	80003b70 <namex+0x44>
      iunlockput(ip);
    80003b8c:	8552                	mv	a0,s4
    80003b8e:	00000097          	auipc	ra,0x0
    80003b92:	c6c080e7          	jalr	-916(ra) # 800037fa <iunlockput>
      return 0;
    80003b96:	4a01                	li	s4,0
  if(nameiparent){
    iput(ip);
    return 0;
  }
  return ip;
}
    80003b98:	8552                	mv	a0,s4
    80003b9a:	60e6                	ld	ra,88(sp)
    80003b9c:	6446                	ld	s0,80(sp)
    80003b9e:	64a6                	ld	s1,72(sp)
    80003ba0:	6906                	ld	s2,64(sp)
    80003ba2:	79e2                	ld	s3,56(sp)
    80003ba4:	7a42                	ld	s4,48(sp)
    80003ba6:	7aa2                	ld	s5,40(sp)
    80003ba8:	7b02                	ld	s6,32(sp)
    80003baa:	6be2                	ld	s7,24(sp)
    80003bac:	6c42                	ld	s8,16(sp)
    80003bae:	6ca2                	ld	s9,8(sp)
    80003bb0:	6d02                	ld	s10,0(sp)
    80003bb2:	6125                	addi	sp,sp,96
    80003bb4:	8082                	ret
      iunlock(ip);
    80003bb6:	8552                	mv	a0,s4
    80003bb8:	00000097          	auipc	ra,0x0
    80003bbc:	aa2080e7          	jalr	-1374(ra) # 8000365a <iunlock>
      return ip;
    80003bc0:	bfe1                	j	80003b98 <namex+0x6c>
      iunlockput(ip);
    80003bc2:	8552                	mv	a0,s4
    80003bc4:	00000097          	auipc	ra,0x0
    80003bc8:	c36080e7          	jalr	-970(ra) # 800037fa <iunlockput>
      return 0;
    80003bcc:	8a4e                	mv	s4,s3
    80003bce:	b7e9                	j	80003b98 <namex+0x6c>
  len = path - s;
    80003bd0:	40998633          	sub	a2,s3,s1
    80003bd4:	00060d1b          	sext.w	s10,a2
  if(len >= DIRSIZ)
    80003bd8:	09acd863          	bge	s9,s10,80003c68 <namex+0x13c>
    memmove(name, s, DIRSIZ);
    80003bdc:	4639                	li	a2,14
    80003bde:	85a6                	mv	a1,s1
    80003be0:	8556                	mv	a0,s5
    80003be2:	ffffd097          	auipc	ra,0xffffd
    80003be6:	120080e7          	jalr	288(ra) # 80000d02 <memmove>
    80003bea:	84ce                	mv	s1,s3
  while(*path == '/')
    80003bec:	0004c783          	lbu	a5,0(s1)
    80003bf0:	01279763          	bne	a5,s2,80003bfe <namex+0xd2>
    path++;
    80003bf4:	0485                	addi	s1,s1,1
  while(*path == '/')
    80003bf6:	0004c783          	lbu	a5,0(s1)
    80003bfa:	ff278de3          	beq	a5,s2,80003bf4 <namex+0xc8>
    ilock(ip);
    80003bfe:	8552                	mv	a0,s4
    80003c00:	00000097          	auipc	ra,0x0
    80003c04:	998080e7          	jalr	-1640(ra) # 80003598 <ilock>
    if(ip->type != T_DIR){
    80003c08:	044a1783          	lh	a5,68(s4)
    80003c0c:	f98790e3          	bne	a5,s8,80003b8c <namex+0x60>
    if(nameiparent && *path == '\0'){
    80003c10:	000b0563          	beqz	s6,80003c1a <namex+0xee>
    80003c14:	0004c783          	lbu	a5,0(s1)
    80003c18:	dfd9                	beqz	a5,80003bb6 <namex+0x8a>
    if((next = dirlookup(ip, name, 0)) == 0){
    80003c1a:	865e                	mv	a2,s7
    80003c1c:	85d6                	mv	a1,s5
    80003c1e:	8552                	mv	a0,s4
    80003c20:	00000097          	auipc	ra,0x0
    80003c24:	e5c080e7          	jalr	-420(ra) # 80003a7c <dirlookup>
    80003c28:	89aa                	mv	s3,a0
    80003c2a:	dd41                	beqz	a0,80003bc2 <namex+0x96>
    iunlockput(ip);
    80003c2c:	8552                	mv	a0,s4
    80003c2e:	00000097          	auipc	ra,0x0
    80003c32:	bcc080e7          	jalr	-1076(ra) # 800037fa <iunlockput>
    ip = next;
    80003c36:	8a4e                	mv	s4,s3
  while(*path == '/')
    80003c38:	0004c783          	lbu	a5,0(s1)
    80003c3c:	01279763          	bne	a5,s2,80003c4a <namex+0x11e>
    path++;
    80003c40:	0485                	addi	s1,s1,1
  while(*path == '/')
    80003c42:	0004c783          	lbu	a5,0(s1)
    80003c46:	ff278de3          	beq	a5,s2,80003c40 <namex+0x114>
  if(*path == 0)
    80003c4a:	cb9d                	beqz	a5,80003c80 <namex+0x154>
  while(*path != '/' && *path != 0)
    80003c4c:	0004c783          	lbu	a5,0(s1)
    80003c50:	89a6                	mv	s3,s1
  len = path - s;
    80003c52:	8d5e                	mv	s10,s7
    80003c54:	865e                	mv	a2,s7
  while(*path != '/' && *path != 0)
    80003c56:	01278963          	beq	a5,s2,80003c68 <namex+0x13c>
    80003c5a:	dbbd                	beqz	a5,80003bd0 <namex+0xa4>
    path++;
    80003c5c:	0985                	addi	s3,s3,1
  while(*path != '/' && *path != 0)
    80003c5e:	0009c783          	lbu	a5,0(s3)
    80003c62:	ff279ce3          	bne	a5,s2,80003c5a <namex+0x12e>
    80003c66:	b7ad                	j	80003bd0 <namex+0xa4>
    memmove(name, s, len);
    80003c68:	2601                	sext.w	a2,a2
    80003c6a:	85a6                	mv	a1,s1
    80003c6c:	8556                	mv	a0,s5
    80003c6e:	ffffd097          	auipc	ra,0xffffd
    80003c72:	094080e7          	jalr	148(ra) # 80000d02 <memmove>
    name[len] = 0;
    80003c76:	9d56                	add	s10,s10,s5
    80003c78:	000d0023          	sb	zero,0(s10)
    80003c7c:	84ce                	mv	s1,s3
    80003c7e:	b7bd                	j	80003bec <namex+0xc0>
  if(nameiparent){
    80003c80:	f00b0ce3          	beqz	s6,80003b98 <namex+0x6c>
    iput(ip);
    80003c84:	8552                	mv	a0,s4
    80003c86:	00000097          	auipc	ra,0x0
    80003c8a:	acc080e7          	jalr	-1332(ra) # 80003752 <iput>
    return 0;
    80003c8e:	4a01                	li	s4,0
    80003c90:	b721                	j	80003b98 <namex+0x6c>

0000000080003c92 <dirlink>:
{
    80003c92:	7139                	addi	sp,sp,-64
    80003c94:	fc06                	sd	ra,56(sp)
    80003c96:	f822                	sd	s0,48(sp)
    80003c98:	f426                	sd	s1,40(sp)
    80003c9a:	f04a                	sd	s2,32(sp)
    80003c9c:	ec4e                	sd	s3,24(sp)
    80003c9e:	e852                	sd	s4,16(sp)
    80003ca0:	0080                	addi	s0,sp,64
    80003ca2:	892a                	mv	s2,a0
    80003ca4:	8a2e                	mv	s4,a1
    80003ca6:	89b2                	mv	s3,a2
  if((ip = dirlookup(dp, name, 0)) != 0){
    80003ca8:	4601                	li	a2,0
    80003caa:	00000097          	auipc	ra,0x0
    80003cae:	dd2080e7          	jalr	-558(ra) # 80003a7c <dirlookup>
    80003cb2:	e93d                	bnez	a0,80003d28 <dirlink+0x96>
  for(off = 0; off < dp->size; off += sizeof(de)){
    80003cb4:	04c92483          	lw	s1,76(s2)
    80003cb8:	c49d                	beqz	s1,80003ce6 <dirlink+0x54>
    80003cba:	4481                	li	s1,0
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80003cbc:	4741                	li	a4,16
    80003cbe:	86a6                	mv	a3,s1
    80003cc0:	fc040613          	addi	a2,s0,-64
    80003cc4:	4581                	li	a1,0
    80003cc6:	854a                	mv	a0,s2
    80003cc8:	00000097          	auipc	ra,0x0
    80003ccc:	b84080e7          	jalr	-1148(ra) # 8000384c <readi>
    80003cd0:	47c1                	li	a5,16
    80003cd2:	06f51163          	bne	a0,a5,80003d34 <dirlink+0xa2>
    if(de.inum == 0)
    80003cd6:	fc045783          	lhu	a5,-64(s0)
    80003cda:	c791                	beqz	a5,80003ce6 <dirlink+0x54>
  for(off = 0; off < dp->size; off += sizeof(de)){
    80003cdc:	24c1                	addiw	s1,s1,16
    80003cde:	04c92783          	lw	a5,76(s2)
    80003ce2:	fcf4ede3          	bltu	s1,a5,80003cbc <dirlink+0x2a>
  strncpy(de.name, name, DIRSIZ);
    80003ce6:	4639                	li	a2,14
    80003ce8:	85d2                	mv	a1,s4
    80003cea:	fc240513          	addi	a0,s0,-62
    80003cee:	ffffd097          	auipc	ra,0xffffd
    80003cf2:	0c4080e7          	jalr	196(ra) # 80000db2 <strncpy>
  de.inum = inum;
    80003cf6:	fd341023          	sh	s3,-64(s0)
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80003cfa:	4741                	li	a4,16
    80003cfc:	86a6                	mv	a3,s1
    80003cfe:	fc040613          	addi	a2,s0,-64
    80003d02:	4581                	li	a1,0
    80003d04:	854a                	mv	a0,s2
    80003d06:	00000097          	auipc	ra,0x0
    80003d0a:	c3e080e7          	jalr	-962(ra) # 80003944 <writei>
    80003d0e:	872a                	mv	a4,a0
    80003d10:	47c1                	li	a5,16
  return 0;
    80003d12:	4501                	li	a0,0
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80003d14:	02f71863          	bne	a4,a5,80003d44 <dirlink+0xb2>
}
    80003d18:	70e2                	ld	ra,56(sp)
    80003d1a:	7442                	ld	s0,48(sp)
    80003d1c:	74a2                	ld	s1,40(sp)
    80003d1e:	7902                	ld	s2,32(sp)
    80003d20:	69e2                	ld	s3,24(sp)
    80003d22:	6a42                	ld	s4,16(sp)
    80003d24:	6121                	addi	sp,sp,64
    80003d26:	8082                	ret
    iput(ip);
    80003d28:	00000097          	auipc	ra,0x0
    80003d2c:	a2a080e7          	jalr	-1494(ra) # 80003752 <iput>
    return -1;
    80003d30:	557d                	li	a0,-1
    80003d32:	b7dd                	j	80003d18 <dirlink+0x86>
      panic("dirlink read");
    80003d34:	00005517          	auipc	a0,0x5
    80003d38:	8dc50513          	addi	a0,a0,-1828 # 80008610 <syscalls+0x1c8>
    80003d3c:	ffffc097          	auipc	ra,0xffffc
    80003d40:	7fe080e7          	jalr	2046(ra) # 8000053a <panic>
    panic("dirlink");
    80003d44:	00005517          	auipc	a0,0x5
    80003d48:	9dc50513          	addi	a0,a0,-1572 # 80008720 <syscalls+0x2d8>
    80003d4c:	ffffc097          	auipc	ra,0xffffc
    80003d50:	7ee080e7          	jalr	2030(ra) # 8000053a <panic>

0000000080003d54 <namei>:

struct inode*
namei(char *path)
{
    80003d54:	1101                	addi	sp,sp,-32
    80003d56:	ec06                	sd	ra,24(sp)
    80003d58:	e822                	sd	s0,16(sp)
    80003d5a:	1000                	addi	s0,sp,32
  char name[DIRSIZ];
  return namex(path, 0, name);
    80003d5c:	fe040613          	addi	a2,s0,-32
    80003d60:	4581                	li	a1,0
    80003d62:	00000097          	auipc	ra,0x0
    80003d66:	dca080e7          	jalr	-566(ra) # 80003b2c <namex>
}
    80003d6a:	60e2                	ld	ra,24(sp)
    80003d6c:	6442                	ld	s0,16(sp)
    80003d6e:	6105                	addi	sp,sp,32
    80003d70:	8082                	ret

0000000080003d72 <nameiparent>:

struct inode*
nameiparent(char *path, char *name)
{
    80003d72:	1141                	addi	sp,sp,-16
    80003d74:	e406                	sd	ra,8(sp)
    80003d76:	e022                	sd	s0,0(sp)
    80003d78:	0800                	addi	s0,sp,16
    80003d7a:	862e                	mv	a2,a1
  return namex(path, 1, name);
    80003d7c:	4585                	li	a1,1
    80003d7e:	00000097          	auipc	ra,0x0
    80003d82:	dae080e7          	jalr	-594(ra) # 80003b2c <namex>
}
    80003d86:	60a2                	ld	ra,8(sp)
    80003d88:	6402                	ld	s0,0(sp)
    80003d8a:	0141                	addi	sp,sp,16
    80003d8c:	8082                	ret

0000000080003d8e <write_head>:
// Write in-memory log header to disk.
// This is the true point at which the
// current transaction commits.
static void
write_head(void)
{
    80003d8e:	1101                	addi	sp,sp,-32
    80003d90:	ec06                	sd	ra,24(sp)
    80003d92:	e822                	sd	s0,16(sp)
    80003d94:	e426                	sd	s1,8(sp)
    80003d96:	e04a                	sd	s2,0(sp)
    80003d98:	1000                	addi	s0,sp,32
  struct buf *buf = bread(log.dev, log.start);
    80003d9a:	0001d917          	auipc	s2,0x1d
    80003d9e:	4d690913          	addi	s2,s2,1238 # 80021270 <log>
    80003da2:	01892583          	lw	a1,24(s2)
    80003da6:	02892503          	lw	a0,40(s2)
    80003daa:	fffff097          	auipc	ra,0xfffff
    80003dae:	fec080e7          	jalr	-20(ra) # 80002d96 <bread>
    80003db2:	84aa                	mv	s1,a0
  struct logheader *hb = (struct logheader *) (buf->data);
  int i;
  hb->n = log.lh.n;
    80003db4:	02c92683          	lw	a3,44(s2)
    80003db8:	cd34                	sw	a3,88(a0)
  for (i = 0; i < log.lh.n; i++) {
    80003dba:	02d05863          	blez	a3,80003dea <write_head+0x5c>
    80003dbe:	0001d797          	auipc	a5,0x1d
    80003dc2:	4e278793          	addi	a5,a5,1250 # 800212a0 <log+0x30>
    80003dc6:	05c50713          	addi	a4,a0,92
    80003dca:	36fd                	addiw	a3,a3,-1
    80003dcc:	02069613          	slli	a2,a3,0x20
    80003dd0:	01e65693          	srli	a3,a2,0x1e
    80003dd4:	0001d617          	auipc	a2,0x1d
    80003dd8:	4d060613          	addi	a2,a2,1232 # 800212a4 <log+0x34>
    80003ddc:	96b2                	add	a3,a3,a2
    hb->block[i] = log.lh.block[i];
    80003dde:	4390                	lw	a2,0(a5)
    80003de0:	c310                	sw	a2,0(a4)
  for (i = 0; i < log.lh.n; i++) {
    80003de2:	0791                	addi	a5,a5,4
    80003de4:	0711                	addi	a4,a4,4 # 43004 <_entry-0x7ffbcffc>
    80003de6:	fed79ce3          	bne	a5,a3,80003dde <write_head+0x50>
  }
  bwrite(buf);
    80003dea:	8526                	mv	a0,s1
    80003dec:	fffff097          	auipc	ra,0xfffff
    80003df0:	09c080e7          	jalr	156(ra) # 80002e88 <bwrite>
  brelse(buf);
    80003df4:	8526                	mv	a0,s1
    80003df6:	fffff097          	auipc	ra,0xfffff
    80003dfa:	0d0080e7          	jalr	208(ra) # 80002ec6 <brelse>
}
    80003dfe:	60e2                	ld	ra,24(sp)
    80003e00:	6442                	ld	s0,16(sp)
    80003e02:	64a2                	ld	s1,8(sp)
    80003e04:	6902                	ld	s2,0(sp)
    80003e06:	6105                	addi	sp,sp,32
    80003e08:	8082                	ret

0000000080003e0a <install_trans>:
  for (tail = 0; tail < log.lh.n; tail++) {
    80003e0a:	0001d797          	auipc	a5,0x1d
    80003e0e:	4927a783          	lw	a5,1170(a5) # 8002129c <log+0x2c>
    80003e12:	0af05d63          	blez	a5,80003ecc <install_trans+0xc2>
{
    80003e16:	7139                	addi	sp,sp,-64
    80003e18:	fc06                	sd	ra,56(sp)
    80003e1a:	f822                	sd	s0,48(sp)
    80003e1c:	f426                	sd	s1,40(sp)
    80003e1e:	f04a                	sd	s2,32(sp)
    80003e20:	ec4e                	sd	s3,24(sp)
    80003e22:	e852                	sd	s4,16(sp)
    80003e24:	e456                	sd	s5,8(sp)
    80003e26:	e05a                	sd	s6,0(sp)
    80003e28:	0080                	addi	s0,sp,64
    80003e2a:	8b2a                	mv	s6,a0
    80003e2c:	0001da97          	auipc	s5,0x1d
    80003e30:	474a8a93          	addi	s5,s5,1140 # 800212a0 <log+0x30>
  for (tail = 0; tail < log.lh.n; tail++) {
    80003e34:	4a01                	li	s4,0
    struct buf *lbuf = bread(log.dev, log.start+tail+1); // read log block
    80003e36:	0001d997          	auipc	s3,0x1d
    80003e3a:	43a98993          	addi	s3,s3,1082 # 80021270 <log>
    80003e3e:	a00d                	j	80003e60 <install_trans+0x56>
    brelse(lbuf);
    80003e40:	854a                	mv	a0,s2
    80003e42:	fffff097          	auipc	ra,0xfffff
    80003e46:	084080e7          	jalr	132(ra) # 80002ec6 <brelse>
    brelse(dbuf);
    80003e4a:	8526                	mv	a0,s1
    80003e4c:	fffff097          	auipc	ra,0xfffff
    80003e50:	07a080e7          	jalr	122(ra) # 80002ec6 <brelse>
  for (tail = 0; tail < log.lh.n; tail++) {
    80003e54:	2a05                	addiw	s4,s4,1
    80003e56:	0a91                	addi	s5,s5,4
    80003e58:	02c9a783          	lw	a5,44(s3)
    80003e5c:	04fa5e63          	bge	s4,a5,80003eb8 <install_trans+0xae>
    struct buf *lbuf = bread(log.dev, log.start+tail+1); // read log block
    80003e60:	0189a583          	lw	a1,24(s3)
    80003e64:	014585bb          	addw	a1,a1,s4
    80003e68:	2585                	addiw	a1,a1,1
    80003e6a:	0289a503          	lw	a0,40(s3)
    80003e6e:	fffff097          	auipc	ra,0xfffff
    80003e72:	f28080e7          	jalr	-216(ra) # 80002d96 <bread>
    80003e76:	892a                	mv	s2,a0
    struct buf *dbuf = bread(log.dev, log.lh.block[tail]); // read dst
    80003e78:	000aa583          	lw	a1,0(s5)
    80003e7c:	0289a503          	lw	a0,40(s3)
    80003e80:	fffff097          	auipc	ra,0xfffff
    80003e84:	f16080e7          	jalr	-234(ra) # 80002d96 <bread>
    80003e88:	84aa                	mv	s1,a0
    memmove(dbuf->data, lbuf->data, BSIZE);  // copy block to dst
    80003e8a:	40000613          	li	a2,1024
    80003e8e:	05890593          	addi	a1,s2,88
    80003e92:	05850513          	addi	a0,a0,88
    80003e96:	ffffd097          	auipc	ra,0xffffd
    80003e9a:	e6c080e7          	jalr	-404(ra) # 80000d02 <memmove>
    bwrite(dbuf);  // write dst to disk
    80003e9e:	8526                	mv	a0,s1
    80003ea0:	fffff097          	auipc	ra,0xfffff
    80003ea4:	fe8080e7          	jalr	-24(ra) # 80002e88 <bwrite>
    if(recovering == 0)
    80003ea8:	f80b1ce3          	bnez	s6,80003e40 <install_trans+0x36>
      bunpin(dbuf);
    80003eac:	8526                	mv	a0,s1
    80003eae:	fffff097          	auipc	ra,0xfffff
    80003eb2:	0f2080e7          	jalr	242(ra) # 80002fa0 <bunpin>
    80003eb6:	b769                	j	80003e40 <install_trans+0x36>
}
    80003eb8:	70e2                	ld	ra,56(sp)
    80003eba:	7442                	ld	s0,48(sp)
    80003ebc:	74a2                	ld	s1,40(sp)
    80003ebe:	7902                	ld	s2,32(sp)
    80003ec0:	69e2                	ld	s3,24(sp)
    80003ec2:	6a42                	ld	s4,16(sp)
    80003ec4:	6aa2                	ld	s5,8(sp)
    80003ec6:	6b02                	ld	s6,0(sp)
    80003ec8:	6121                	addi	sp,sp,64
    80003eca:	8082                	ret
    80003ecc:	8082                	ret

0000000080003ece <initlog>:
{
    80003ece:	7179                	addi	sp,sp,-48
    80003ed0:	f406                	sd	ra,40(sp)
    80003ed2:	f022                	sd	s0,32(sp)
    80003ed4:	ec26                	sd	s1,24(sp)
    80003ed6:	e84a                	sd	s2,16(sp)
    80003ed8:	e44e                	sd	s3,8(sp)
    80003eda:	1800                	addi	s0,sp,48
    80003edc:	892a                	mv	s2,a0
    80003ede:	89ae                	mv	s3,a1
  initlock(&log.lock, "log");
    80003ee0:	0001d497          	auipc	s1,0x1d
    80003ee4:	39048493          	addi	s1,s1,912 # 80021270 <log>
    80003ee8:	00004597          	auipc	a1,0x4
    80003eec:	73858593          	addi	a1,a1,1848 # 80008620 <syscalls+0x1d8>
    80003ef0:	8526                	mv	a0,s1
    80003ef2:	ffffd097          	auipc	ra,0xffffd
    80003ef6:	c28080e7          	jalr	-984(ra) # 80000b1a <initlock>
  log.start = sb->logstart;
    80003efa:	0149a583          	lw	a1,20(s3)
    80003efe:	cc8c                	sw	a1,24(s1)
  log.size = sb->nlog;
    80003f00:	0109a783          	lw	a5,16(s3)
    80003f04:	ccdc                	sw	a5,28(s1)
  log.dev = dev;
    80003f06:	0324a423          	sw	s2,40(s1)
  struct buf *buf = bread(log.dev, log.start);
    80003f0a:	854a                	mv	a0,s2
    80003f0c:	fffff097          	auipc	ra,0xfffff
    80003f10:	e8a080e7          	jalr	-374(ra) # 80002d96 <bread>
  log.lh.n = lh->n;
    80003f14:	4d34                	lw	a3,88(a0)
    80003f16:	d4d4                	sw	a3,44(s1)
  for (i = 0; i < log.lh.n; i++) {
    80003f18:	02d05663          	blez	a3,80003f44 <initlog+0x76>
    80003f1c:	05c50793          	addi	a5,a0,92
    80003f20:	0001d717          	auipc	a4,0x1d
    80003f24:	38070713          	addi	a4,a4,896 # 800212a0 <log+0x30>
    80003f28:	36fd                	addiw	a3,a3,-1
    80003f2a:	02069613          	slli	a2,a3,0x20
    80003f2e:	01e65693          	srli	a3,a2,0x1e
    80003f32:	06050613          	addi	a2,a0,96
    80003f36:	96b2                	add	a3,a3,a2
    log.lh.block[i] = lh->block[i];
    80003f38:	4390                	lw	a2,0(a5)
    80003f3a:	c310                	sw	a2,0(a4)
  for (i = 0; i < log.lh.n; i++) {
    80003f3c:	0791                	addi	a5,a5,4
    80003f3e:	0711                	addi	a4,a4,4
    80003f40:	fed79ce3          	bne	a5,a3,80003f38 <initlog+0x6a>
  brelse(buf);
    80003f44:	fffff097          	auipc	ra,0xfffff
    80003f48:	f82080e7          	jalr	-126(ra) # 80002ec6 <brelse>

static void
recover_from_log(void)
{
  read_head();
  install_trans(1); // if committed, copy from log to disk
    80003f4c:	4505                	li	a0,1
    80003f4e:	00000097          	auipc	ra,0x0
    80003f52:	ebc080e7          	jalr	-324(ra) # 80003e0a <install_trans>
  log.lh.n = 0;
    80003f56:	0001d797          	auipc	a5,0x1d
    80003f5a:	3407a323          	sw	zero,838(a5) # 8002129c <log+0x2c>
  write_head(); // clear the log
    80003f5e:	00000097          	auipc	ra,0x0
    80003f62:	e30080e7          	jalr	-464(ra) # 80003d8e <write_head>
}
    80003f66:	70a2                	ld	ra,40(sp)
    80003f68:	7402                	ld	s0,32(sp)
    80003f6a:	64e2                	ld	s1,24(sp)
    80003f6c:	6942                	ld	s2,16(sp)
    80003f6e:	69a2                	ld	s3,8(sp)
    80003f70:	6145                	addi	sp,sp,48
    80003f72:	8082                	ret

0000000080003f74 <begin_op>:
}

// called at the start of each FS system call.
void
begin_op(void)
{
    80003f74:	1101                	addi	sp,sp,-32
    80003f76:	ec06                	sd	ra,24(sp)
    80003f78:	e822                	sd	s0,16(sp)
    80003f7a:	e426                	sd	s1,8(sp)
    80003f7c:	e04a                	sd	s2,0(sp)
    80003f7e:	1000                	addi	s0,sp,32
  acquire(&log.lock);
    80003f80:	0001d517          	auipc	a0,0x1d
    80003f84:	2f050513          	addi	a0,a0,752 # 80021270 <log>
    80003f88:	ffffd097          	auipc	ra,0xffffd
    80003f8c:	c22080e7          	jalr	-990(ra) # 80000baa <acquire>
  while(1){
    if(log.committing){
    80003f90:	0001d497          	auipc	s1,0x1d
    80003f94:	2e048493          	addi	s1,s1,736 # 80021270 <log>
      sleep(&log, &log.lock);
    } else if(log.lh.n + (log.outstanding+1)*MAXOPBLOCKS > LOGSIZE){
    80003f98:	4979                	li	s2,30
    80003f9a:	a039                	j	80003fa8 <begin_op+0x34>
      sleep(&log, &log.lock);
    80003f9c:	85a6                	mv	a1,s1
    80003f9e:	8526                	mv	a0,s1
    80003fa0:	ffffe097          	auipc	ra,0xffffe
    80003fa4:	094080e7          	jalr	148(ra) # 80002034 <sleep>
    if(log.committing){
    80003fa8:	50dc                	lw	a5,36(s1)
    80003faa:	fbed                	bnez	a5,80003f9c <begin_op+0x28>
    } else if(log.lh.n + (log.outstanding+1)*MAXOPBLOCKS > LOGSIZE){
    80003fac:	5098                	lw	a4,32(s1)
    80003fae:	2705                	addiw	a4,a4,1
    80003fb0:	0007069b          	sext.w	a3,a4
    80003fb4:	0027179b          	slliw	a5,a4,0x2
    80003fb8:	9fb9                	addw	a5,a5,a4
    80003fba:	0017979b          	slliw	a5,a5,0x1
    80003fbe:	54d8                	lw	a4,44(s1)
    80003fc0:	9fb9                	addw	a5,a5,a4
    80003fc2:	00f95963          	bge	s2,a5,80003fd4 <begin_op+0x60>
      // this op might exhaust log space; wait for commit.
      sleep(&log, &log.lock);
    80003fc6:	85a6                	mv	a1,s1
    80003fc8:	8526                	mv	a0,s1
    80003fca:	ffffe097          	auipc	ra,0xffffe
    80003fce:	06a080e7          	jalr	106(ra) # 80002034 <sleep>
    80003fd2:	bfd9                	j	80003fa8 <begin_op+0x34>
    } else {
      log.outstanding += 1;
    80003fd4:	0001d517          	auipc	a0,0x1d
    80003fd8:	29c50513          	addi	a0,a0,668 # 80021270 <log>
    80003fdc:	d114                	sw	a3,32(a0)
      release(&log.lock);
    80003fde:	ffffd097          	auipc	ra,0xffffd
    80003fe2:	c80080e7          	jalr	-896(ra) # 80000c5e <release>
      break;
    }
  }
}
    80003fe6:	60e2                	ld	ra,24(sp)
    80003fe8:	6442                	ld	s0,16(sp)
    80003fea:	64a2                	ld	s1,8(sp)
    80003fec:	6902                	ld	s2,0(sp)
    80003fee:	6105                	addi	sp,sp,32
    80003ff0:	8082                	ret

0000000080003ff2 <end_op>:

// called at the end of each FS system call.
// commits if this was the last outstanding operation.
void
end_op(void)
{
    80003ff2:	7139                	addi	sp,sp,-64
    80003ff4:	fc06                	sd	ra,56(sp)
    80003ff6:	f822                	sd	s0,48(sp)
    80003ff8:	f426                	sd	s1,40(sp)
    80003ffa:	f04a                	sd	s2,32(sp)
    80003ffc:	ec4e                	sd	s3,24(sp)
    80003ffe:	e852                	sd	s4,16(sp)
    80004000:	e456                	sd	s5,8(sp)
    80004002:	0080                	addi	s0,sp,64
  int do_commit = 0;

  acquire(&log.lock);
    80004004:	0001d497          	auipc	s1,0x1d
    80004008:	26c48493          	addi	s1,s1,620 # 80021270 <log>
    8000400c:	8526                	mv	a0,s1
    8000400e:	ffffd097          	auipc	ra,0xffffd
    80004012:	b9c080e7          	jalr	-1124(ra) # 80000baa <acquire>
  log.outstanding -= 1;
    80004016:	509c                	lw	a5,32(s1)
    80004018:	37fd                	addiw	a5,a5,-1
    8000401a:	0007891b          	sext.w	s2,a5
    8000401e:	d09c                	sw	a5,32(s1)
  if(log.committing)
    80004020:	50dc                	lw	a5,36(s1)
    80004022:	e7b9                	bnez	a5,80004070 <end_op+0x7e>
    panic("log.committing");
  if(log.outstanding == 0){
    80004024:	04091e63          	bnez	s2,80004080 <end_op+0x8e>
    do_commit = 1;
    log.committing = 1;
    80004028:	0001d497          	auipc	s1,0x1d
    8000402c:	24848493          	addi	s1,s1,584 # 80021270 <log>
    80004030:	4785                	li	a5,1
    80004032:	d0dc                	sw	a5,36(s1)
    // begin_op() may be waiting for log space,
    // and decrementing log.outstanding has decreased
    // the amount of reserved space.
    wakeup(&log);
  }
  release(&log.lock);
    80004034:	8526                	mv	a0,s1
    80004036:	ffffd097          	auipc	ra,0xffffd
    8000403a:	c28080e7          	jalr	-984(ra) # 80000c5e <release>
}

static void
commit()
{
  if (log.lh.n > 0) {
    8000403e:	54dc                	lw	a5,44(s1)
    80004040:	06f04763          	bgtz	a5,800040ae <end_op+0xbc>
    acquire(&log.lock);
    80004044:	0001d497          	auipc	s1,0x1d
    80004048:	22c48493          	addi	s1,s1,556 # 80021270 <log>
    8000404c:	8526                	mv	a0,s1
    8000404e:	ffffd097          	auipc	ra,0xffffd
    80004052:	b5c080e7          	jalr	-1188(ra) # 80000baa <acquire>
    log.committing = 0;
    80004056:	0204a223          	sw	zero,36(s1)
    wakeup(&log);
    8000405a:	8526                	mv	a0,s1
    8000405c:	ffffe097          	auipc	ra,0xffffe
    80004060:	164080e7          	jalr	356(ra) # 800021c0 <wakeup>
    release(&log.lock);
    80004064:	8526                	mv	a0,s1
    80004066:	ffffd097          	auipc	ra,0xffffd
    8000406a:	bf8080e7          	jalr	-1032(ra) # 80000c5e <release>
}
    8000406e:	a03d                	j	8000409c <end_op+0xaa>
    panic("log.committing");
    80004070:	00004517          	auipc	a0,0x4
    80004074:	5b850513          	addi	a0,a0,1464 # 80008628 <syscalls+0x1e0>
    80004078:	ffffc097          	auipc	ra,0xffffc
    8000407c:	4c2080e7          	jalr	1218(ra) # 8000053a <panic>
    wakeup(&log);
    80004080:	0001d497          	auipc	s1,0x1d
    80004084:	1f048493          	addi	s1,s1,496 # 80021270 <log>
    80004088:	8526                	mv	a0,s1
    8000408a:	ffffe097          	auipc	ra,0xffffe
    8000408e:	136080e7          	jalr	310(ra) # 800021c0 <wakeup>
  release(&log.lock);
    80004092:	8526                	mv	a0,s1
    80004094:	ffffd097          	auipc	ra,0xffffd
    80004098:	bca080e7          	jalr	-1078(ra) # 80000c5e <release>
}
    8000409c:	70e2                	ld	ra,56(sp)
    8000409e:	7442                	ld	s0,48(sp)
    800040a0:	74a2                	ld	s1,40(sp)
    800040a2:	7902                	ld	s2,32(sp)
    800040a4:	69e2                	ld	s3,24(sp)
    800040a6:	6a42                	ld	s4,16(sp)
    800040a8:	6aa2                	ld	s5,8(sp)
    800040aa:	6121                	addi	sp,sp,64
    800040ac:	8082                	ret
  for (tail = 0; tail < log.lh.n; tail++) {
    800040ae:	0001da97          	auipc	s5,0x1d
    800040b2:	1f2a8a93          	addi	s5,s5,498 # 800212a0 <log+0x30>
    struct buf *to = bread(log.dev, log.start+tail+1); // log block
    800040b6:	0001da17          	auipc	s4,0x1d
    800040ba:	1baa0a13          	addi	s4,s4,442 # 80021270 <log>
    800040be:	018a2583          	lw	a1,24(s4)
    800040c2:	012585bb          	addw	a1,a1,s2
    800040c6:	2585                	addiw	a1,a1,1
    800040c8:	028a2503          	lw	a0,40(s4)
    800040cc:	fffff097          	auipc	ra,0xfffff
    800040d0:	cca080e7          	jalr	-822(ra) # 80002d96 <bread>
    800040d4:	84aa                	mv	s1,a0
    struct buf *from = bread(log.dev, log.lh.block[tail]); // cache block
    800040d6:	000aa583          	lw	a1,0(s5)
    800040da:	028a2503          	lw	a0,40(s4)
    800040de:	fffff097          	auipc	ra,0xfffff
    800040e2:	cb8080e7          	jalr	-840(ra) # 80002d96 <bread>
    800040e6:	89aa                	mv	s3,a0
    memmove(to->data, from->data, BSIZE);
    800040e8:	40000613          	li	a2,1024
    800040ec:	05850593          	addi	a1,a0,88
    800040f0:	05848513          	addi	a0,s1,88
    800040f4:	ffffd097          	auipc	ra,0xffffd
    800040f8:	c0e080e7          	jalr	-1010(ra) # 80000d02 <memmove>
    bwrite(to);  // write the log
    800040fc:	8526                	mv	a0,s1
    800040fe:	fffff097          	auipc	ra,0xfffff
    80004102:	d8a080e7          	jalr	-630(ra) # 80002e88 <bwrite>
    brelse(from);
    80004106:	854e                	mv	a0,s3
    80004108:	fffff097          	auipc	ra,0xfffff
    8000410c:	dbe080e7          	jalr	-578(ra) # 80002ec6 <brelse>
    brelse(to);
    80004110:	8526                	mv	a0,s1
    80004112:	fffff097          	auipc	ra,0xfffff
    80004116:	db4080e7          	jalr	-588(ra) # 80002ec6 <brelse>
  for (tail = 0; tail < log.lh.n; tail++) {
    8000411a:	2905                	addiw	s2,s2,1
    8000411c:	0a91                	addi	s5,s5,4
    8000411e:	02ca2783          	lw	a5,44(s4)
    80004122:	f8f94ee3          	blt	s2,a5,800040be <end_op+0xcc>
    write_log();     // Write modified blocks from cache to log
    write_head();    // Write header to disk -- the real commit
    80004126:	00000097          	auipc	ra,0x0
    8000412a:	c68080e7          	jalr	-920(ra) # 80003d8e <write_head>
    install_trans(0); // Now install writes to home locations
    8000412e:	4501                	li	a0,0
    80004130:	00000097          	auipc	ra,0x0
    80004134:	cda080e7          	jalr	-806(ra) # 80003e0a <install_trans>
    log.lh.n = 0;
    80004138:	0001d797          	auipc	a5,0x1d
    8000413c:	1607a223          	sw	zero,356(a5) # 8002129c <log+0x2c>
    write_head();    // Erase the transaction from the log
    80004140:	00000097          	auipc	ra,0x0
    80004144:	c4e080e7          	jalr	-946(ra) # 80003d8e <write_head>
    80004148:	bdf5                	j	80004044 <end_op+0x52>

000000008000414a <log_write>:
//   modify bp->data[]
//   log_write(bp)
//   brelse(bp)
void
log_write(struct buf *b)
{
    8000414a:	1101                	addi	sp,sp,-32
    8000414c:	ec06                	sd	ra,24(sp)
    8000414e:	e822                	sd	s0,16(sp)
    80004150:	e426                	sd	s1,8(sp)
    80004152:	e04a                	sd	s2,0(sp)
    80004154:	1000                	addi	s0,sp,32
    80004156:	84aa                	mv	s1,a0
  int i;

  acquire(&log.lock);
    80004158:	0001d917          	auipc	s2,0x1d
    8000415c:	11890913          	addi	s2,s2,280 # 80021270 <log>
    80004160:	854a                	mv	a0,s2
    80004162:	ffffd097          	auipc	ra,0xffffd
    80004166:	a48080e7          	jalr	-1464(ra) # 80000baa <acquire>
  if (log.lh.n >= LOGSIZE || log.lh.n >= log.size - 1)
    8000416a:	02c92603          	lw	a2,44(s2)
    8000416e:	47f5                	li	a5,29
    80004170:	06c7c563          	blt	a5,a2,800041da <log_write+0x90>
    80004174:	0001d797          	auipc	a5,0x1d
    80004178:	1187a783          	lw	a5,280(a5) # 8002128c <log+0x1c>
    8000417c:	37fd                	addiw	a5,a5,-1
    8000417e:	04f65e63          	bge	a2,a5,800041da <log_write+0x90>
    panic("too big a transaction");
  if (log.outstanding < 1)
    80004182:	0001d797          	auipc	a5,0x1d
    80004186:	10e7a783          	lw	a5,270(a5) # 80021290 <log+0x20>
    8000418a:	06f05063          	blez	a5,800041ea <log_write+0xa0>
    panic("log_write outside of trans");

  for (i = 0; i < log.lh.n; i++) {
    8000418e:	4781                	li	a5,0
    80004190:	06c05563          	blez	a2,800041fa <log_write+0xb0>
    if (log.lh.block[i] == b->blockno)   // log absorption
    80004194:	44cc                	lw	a1,12(s1)
    80004196:	0001d717          	auipc	a4,0x1d
    8000419a:	10a70713          	addi	a4,a4,266 # 800212a0 <log+0x30>
  for (i = 0; i < log.lh.n; i++) {
    8000419e:	4781                	li	a5,0
    if (log.lh.block[i] == b->blockno)   // log absorption
    800041a0:	4314                	lw	a3,0(a4)
    800041a2:	04b68c63          	beq	a3,a1,800041fa <log_write+0xb0>
  for (i = 0; i < log.lh.n; i++) {
    800041a6:	2785                	addiw	a5,a5,1
    800041a8:	0711                	addi	a4,a4,4
    800041aa:	fef61be3          	bne	a2,a5,800041a0 <log_write+0x56>
      break;
  }
  log.lh.block[i] = b->blockno;
    800041ae:	0621                	addi	a2,a2,8
    800041b0:	060a                	slli	a2,a2,0x2
    800041b2:	0001d797          	auipc	a5,0x1d
    800041b6:	0be78793          	addi	a5,a5,190 # 80021270 <log>
    800041ba:	97b2                	add	a5,a5,a2
    800041bc:	44d8                	lw	a4,12(s1)
    800041be:	cb98                	sw	a4,16(a5)
  if (i == log.lh.n) {  // Add new block to log?
    bpin(b);
    800041c0:	8526                	mv	a0,s1
    800041c2:	fffff097          	auipc	ra,0xfffff
    800041c6:	da2080e7          	jalr	-606(ra) # 80002f64 <bpin>
    log.lh.n++;
    800041ca:	0001d717          	auipc	a4,0x1d
    800041ce:	0a670713          	addi	a4,a4,166 # 80021270 <log>
    800041d2:	575c                	lw	a5,44(a4)
    800041d4:	2785                	addiw	a5,a5,1
    800041d6:	d75c                	sw	a5,44(a4)
    800041d8:	a82d                	j	80004212 <log_write+0xc8>
    panic("too big a transaction");
    800041da:	00004517          	auipc	a0,0x4
    800041de:	45e50513          	addi	a0,a0,1118 # 80008638 <syscalls+0x1f0>
    800041e2:	ffffc097          	auipc	ra,0xffffc
    800041e6:	358080e7          	jalr	856(ra) # 8000053a <panic>
    panic("log_write outside of trans");
    800041ea:	00004517          	auipc	a0,0x4
    800041ee:	46650513          	addi	a0,a0,1126 # 80008650 <syscalls+0x208>
    800041f2:	ffffc097          	auipc	ra,0xffffc
    800041f6:	348080e7          	jalr	840(ra) # 8000053a <panic>
  log.lh.block[i] = b->blockno;
    800041fa:	00878693          	addi	a3,a5,8
    800041fe:	068a                	slli	a3,a3,0x2
    80004200:	0001d717          	auipc	a4,0x1d
    80004204:	07070713          	addi	a4,a4,112 # 80021270 <log>
    80004208:	9736                	add	a4,a4,a3
    8000420a:	44d4                	lw	a3,12(s1)
    8000420c:	cb14                	sw	a3,16(a4)
  if (i == log.lh.n) {  // Add new block to log?
    8000420e:	faf609e3          	beq	a2,a5,800041c0 <log_write+0x76>
  }
  release(&log.lock);
    80004212:	0001d517          	auipc	a0,0x1d
    80004216:	05e50513          	addi	a0,a0,94 # 80021270 <log>
    8000421a:	ffffd097          	auipc	ra,0xffffd
    8000421e:	a44080e7          	jalr	-1468(ra) # 80000c5e <release>
}
    80004222:	60e2                	ld	ra,24(sp)
    80004224:	6442                	ld	s0,16(sp)
    80004226:	64a2                	ld	s1,8(sp)
    80004228:	6902                	ld	s2,0(sp)
    8000422a:	6105                	addi	sp,sp,32
    8000422c:	8082                	ret

000000008000422e <initsleeplock>:
#include "proc.h"
#include "sleeplock.h"

void
initsleeplock(struct sleeplock *lk, char *name)
{
    8000422e:	1101                	addi	sp,sp,-32
    80004230:	ec06                	sd	ra,24(sp)
    80004232:	e822                	sd	s0,16(sp)
    80004234:	e426                	sd	s1,8(sp)
    80004236:	e04a                	sd	s2,0(sp)
    80004238:	1000                	addi	s0,sp,32
    8000423a:	84aa                	mv	s1,a0
    8000423c:	892e                	mv	s2,a1
  initlock(&lk->lk, "sleep lock");
    8000423e:	00004597          	auipc	a1,0x4
    80004242:	43258593          	addi	a1,a1,1074 # 80008670 <syscalls+0x228>
    80004246:	0521                	addi	a0,a0,8
    80004248:	ffffd097          	auipc	ra,0xffffd
    8000424c:	8d2080e7          	jalr	-1838(ra) # 80000b1a <initlock>
  lk->name = name;
    80004250:	0324b023          	sd	s2,32(s1)
  lk->locked = 0;
    80004254:	0004a023          	sw	zero,0(s1)
  lk->pid = 0;
    80004258:	0204a423          	sw	zero,40(s1)
}
    8000425c:	60e2                	ld	ra,24(sp)
    8000425e:	6442                	ld	s0,16(sp)
    80004260:	64a2                	ld	s1,8(sp)
    80004262:	6902                	ld	s2,0(sp)
    80004264:	6105                	addi	sp,sp,32
    80004266:	8082                	ret

0000000080004268 <acquiresleep>:

void
acquiresleep(struct sleeplock *lk)
{
    80004268:	1101                	addi	sp,sp,-32
    8000426a:	ec06                	sd	ra,24(sp)
    8000426c:	e822                	sd	s0,16(sp)
    8000426e:	e426                	sd	s1,8(sp)
    80004270:	e04a                	sd	s2,0(sp)
    80004272:	1000                	addi	s0,sp,32
    80004274:	84aa                	mv	s1,a0
  acquire(&lk->lk);
    80004276:	00850913          	addi	s2,a0,8
    8000427a:	854a                	mv	a0,s2
    8000427c:	ffffd097          	auipc	ra,0xffffd
    80004280:	92e080e7          	jalr	-1746(ra) # 80000baa <acquire>
  while (lk->locked) {
    80004284:	409c                	lw	a5,0(s1)
    80004286:	cb89                	beqz	a5,80004298 <acquiresleep+0x30>
    sleep(lk, &lk->lk);
    80004288:	85ca                	mv	a1,s2
    8000428a:	8526                	mv	a0,s1
    8000428c:	ffffe097          	auipc	ra,0xffffe
    80004290:	da8080e7          	jalr	-600(ra) # 80002034 <sleep>
  while (lk->locked) {
    80004294:	409c                	lw	a5,0(s1)
    80004296:	fbed                	bnez	a5,80004288 <acquiresleep+0x20>
  }
  lk->locked = 1;
    80004298:	4785                	li	a5,1
    8000429a:	c09c                	sw	a5,0(s1)
  lk->pid = myproc()->pid;
    8000429c:	ffffd097          	auipc	ra,0xffffd
    800042a0:	6d4080e7          	jalr	1748(ra) # 80001970 <myproc>
    800042a4:	591c                	lw	a5,48(a0)
    800042a6:	d49c                	sw	a5,40(s1)
  release(&lk->lk);
    800042a8:	854a                	mv	a0,s2
    800042aa:	ffffd097          	auipc	ra,0xffffd
    800042ae:	9b4080e7          	jalr	-1612(ra) # 80000c5e <release>
}
    800042b2:	60e2                	ld	ra,24(sp)
    800042b4:	6442                	ld	s0,16(sp)
    800042b6:	64a2                	ld	s1,8(sp)
    800042b8:	6902                	ld	s2,0(sp)
    800042ba:	6105                	addi	sp,sp,32
    800042bc:	8082                	ret

00000000800042be <releasesleep>:

void
releasesleep(struct sleeplock *lk)
{
    800042be:	1101                	addi	sp,sp,-32
    800042c0:	ec06                	sd	ra,24(sp)
    800042c2:	e822                	sd	s0,16(sp)
    800042c4:	e426                	sd	s1,8(sp)
    800042c6:	e04a                	sd	s2,0(sp)
    800042c8:	1000                	addi	s0,sp,32
    800042ca:	84aa                	mv	s1,a0
  acquire(&lk->lk);
    800042cc:	00850913          	addi	s2,a0,8
    800042d0:	854a                	mv	a0,s2
    800042d2:	ffffd097          	auipc	ra,0xffffd
    800042d6:	8d8080e7          	jalr	-1832(ra) # 80000baa <acquire>
  lk->locked = 0;
    800042da:	0004a023          	sw	zero,0(s1)
  lk->pid = 0;
    800042de:	0204a423          	sw	zero,40(s1)
  wakeup(lk);
    800042e2:	8526                	mv	a0,s1
    800042e4:	ffffe097          	auipc	ra,0xffffe
    800042e8:	edc080e7          	jalr	-292(ra) # 800021c0 <wakeup>
  release(&lk->lk);
    800042ec:	854a                	mv	a0,s2
    800042ee:	ffffd097          	auipc	ra,0xffffd
    800042f2:	970080e7          	jalr	-1680(ra) # 80000c5e <release>
}
    800042f6:	60e2                	ld	ra,24(sp)
    800042f8:	6442                	ld	s0,16(sp)
    800042fa:	64a2                	ld	s1,8(sp)
    800042fc:	6902                	ld	s2,0(sp)
    800042fe:	6105                	addi	sp,sp,32
    80004300:	8082                	ret

0000000080004302 <holdingsleep>:

int
holdingsleep(struct sleeplock *lk)
{
    80004302:	7179                	addi	sp,sp,-48
    80004304:	f406                	sd	ra,40(sp)
    80004306:	f022                	sd	s0,32(sp)
    80004308:	ec26                	sd	s1,24(sp)
    8000430a:	e84a                	sd	s2,16(sp)
    8000430c:	e44e                	sd	s3,8(sp)
    8000430e:	1800                	addi	s0,sp,48
    80004310:	84aa                	mv	s1,a0
  int r;
  
  acquire(&lk->lk);
    80004312:	00850913          	addi	s2,a0,8
    80004316:	854a                	mv	a0,s2
    80004318:	ffffd097          	auipc	ra,0xffffd
    8000431c:	892080e7          	jalr	-1902(ra) # 80000baa <acquire>
  r = lk->locked && (lk->pid == myproc()->pid);
    80004320:	409c                	lw	a5,0(s1)
    80004322:	ef99                	bnez	a5,80004340 <holdingsleep+0x3e>
    80004324:	4481                	li	s1,0
  release(&lk->lk);
    80004326:	854a                	mv	a0,s2
    80004328:	ffffd097          	auipc	ra,0xffffd
    8000432c:	936080e7          	jalr	-1738(ra) # 80000c5e <release>
  return r;
}
    80004330:	8526                	mv	a0,s1
    80004332:	70a2                	ld	ra,40(sp)
    80004334:	7402                	ld	s0,32(sp)
    80004336:	64e2                	ld	s1,24(sp)
    80004338:	6942                	ld	s2,16(sp)
    8000433a:	69a2                	ld	s3,8(sp)
    8000433c:	6145                	addi	sp,sp,48
    8000433e:	8082                	ret
  r = lk->locked && (lk->pid == myproc()->pid);
    80004340:	0284a983          	lw	s3,40(s1)
    80004344:	ffffd097          	auipc	ra,0xffffd
    80004348:	62c080e7          	jalr	1580(ra) # 80001970 <myproc>
    8000434c:	5904                	lw	s1,48(a0)
    8000434e:	413484b3          	sub	s1,s1,s3
    80004352:	0014b493          	seqz	s1,s1
    80004356:	bfc1                	j	80004326 <holdingsleep+0x24>

0000000080004358 <fileinit>:
  struct file file[NFILE];
} ftable;

void
fileinit(void)
{
    80004358:	1141                	addi	sp,sp,-16
    8000435a:	e406                	sd	ra,8(sp)
    8000435c:	e022                	sd	s0,0(sp)
    8000435e:	0800                	addi	s0,sp,16
  initlock(&ftable.lock, "ftable");
    80004360:	00004597          	auipc	a1,0x4
    80004364:	32058593          	addi	a1,a1,800 # 80008680 <syscalls+0x238>
    80004368:	0001d517          	auipc	a0,0x1d
    8000436c:	05050513          	addi	a0,a0,80 # 800213b8 <ftable>
    80004370:	ffffc097          	auipc	ra,0xffffc
    80004374:	7aa080e7          	jalr	1962(ra) # 80000b1a <initlock>
}
    80004378:	60a2                	ld	ra,8(sp)
    8000437a:	6402                	ld	s0,0(sp)
    8000437c:	0141                	addi	sp,sp,16
    8000437e:	8082                	ret

0000000080004380 <filealloc>:

// Allocate a file structure.
struct file*
filealloc(void)
{
    80004380:	1101                	addi	sp,sp,-32
    80004382:	ec06                	sd	ra,24(sp)
    80004384:	e822                	sd	s0,16(sp)
    80004386:	e426                	sd	s1,8(sp)
    80004388:	1000                	addi	s0,sp,32
  struct file *f;

  acquire(&ftable.lock);
    8000438a:	0001d517          	auipc	a0,0x1d
    8000438e:	02e50513          	addi	a0,a0,46 # 800213b8 <ftable>
    80004392:	ffffd097          	auipc	ra,0xffffd
    80004396:	818080e7          	jalr	-2024(ra) # 80000baa <acquire>
  for(f = ftable.file; f < ftable.file + NFILE; f++){
    8000439a:	0001d497          	auipc	s1,0x1d
    8000439e:	03648493          	addi	s1,s1,54 # 800213d0 <ftable+0x18>
    800043a2:	0001e717          	auipc	a4,0x1e
    800043a6:	fce70713          	addi	a4,a4,-50 # 80022370 <ftable+0xfb8>
    if(f->ref == 0){
    800043aa:	40dc                	lw	a5,4(s1)
    800043ac:	cf99                	beqz	a5,800043ca <filealloc+0x4a>
  for(f = ftable.file; f < ftable.file + NFILE; f++){
    800043ae:	02848493          	addi	s1,s1,40
    800043b2:	fee49ce3          	bne	s1,a4,800043aa <filealloc+0x2a>
      f->ref = 1;
      release(&ftable.lock);
      return f;
    }
  }
  release(&ftable.lock);
    800043b6:	0001d517          	auipc	a0,0x1d
    800043ba:	00250513          	addi	a0,a0,2 # 800213b8 <ftable>
    800043be:	ffffd097          	auipc	ra,0xffffd
    800043c2:	8a0080e7          	jalr	-1888(ra) # 80000c5e <release>
  return 0;
    800043c6:	4481                	li	s1,0
    800043c8:	a819                	j	800043de <filealloc+0x5e>
      f->ref = 1;
    800043ca:	4785                	li	a5,1
    800043cc:	c0dc                	sw	a5,4(s1)
      release(&ftable.lock);
    800043ce:	0001d517          	auipc	a0,0x1d
    800043d2:	fea50513          	addi	a0,a0,-22 # 800213b8 <ftable>
    800043d6:	ffffd097          	auipc	ra,0xffffd
    800043da:	888080e7          	jalr	-1912(ra) # 80000c5e <release>
}
    800043de:	8526                	mv	a0,s1
    800043e0:	60e2                	ld	ra,24(sp)
    800043e2:	6442                	ld	s0,16(sp)
    800043e4:	64a2                	ld	s1,8(sp)
    800043e6:	6105                	addi	sp,sp,32
    800043e8:	8082                	ret

00000000800043ea <filedup>:

// Increment ref count for file f.
struct file*
filedup(struct file *f)
{
    800043ea:	1101                	addi	sp,sp,-32
    800043ec:	ec06                	sd	ra,24(sp)
    800043ee:	e822                	sd	s0,16(sp)
    800043f0:	e426                	sd	s1,8(sp)
    800043f2:	1000                	addi	s0,sp,32
    800043f4:	84aa                	mv	s1,a0
  acquire(&ftable.lock);
    800043f6:	0001d517          	auipc	a0,0x1d
    800043fa:	fc250513          	addi	a0,a0,-62 # 800213b8 <ftable>
    800043fe:	ffffc097          	auipc	ra,0xffffc
    80004402:	7ac080e7          	jalr	1964(ra) # 80000baa <acquire>
  if(f->ref < 1)
    80004406:	40dc                	lw	a5,4(s1)
    80004408:	02f05263          	blez	a5,8000442c <filedup+0x42>
    panic("filedup");
  f->ref++;
    8000440c:	2785                	addiw	a5,a5,1
    8000440e:	c0dc                	sw	a5,4(s1)
  release(&ftable.lock);
    80004410:	0001d517          	auipc	a0,0x1d
    80004414:	fa850513          	addi	a0,a0,-88 # 800213b8 <ftable>
    80004418:	ffffd097          	auipc	ra,0xffffd
    8000441c:	846080e7          	jalr	-1978(ra) # 80000c5e <release>
  return f;
}
    80004420:	8526                	mv	a0,s1
    80004422:	60e2                	ld	ra,24(sp)
    80004424:	6442                	ld	s0,16(sp)
    80004426:	64a2                	ld	s1,8(sp)
    80004428:	6105                	addi	sp,sp,32
    8000442a:	8082                	ret
    panic("filedup");
    8000442c:	00004517          	auipc	a0,0x4
    80004430:	25c50513          	addi	a0,a0,604 # 80008688 <syscalls+0x240>
    80004434:	ffffc097          	auipc	ra,0xffffc
    80004438:	106080e7          	jalr	262(ra) # 8000053a <panic>

000000008000443c <fileclose>:

// Close file f.  (Decrement ref count, close when reaches 0.)
void
fileclose(struct file *f)
{
    8000443c:	7139                	addi	sp,sp,-64
    8000443e:	fc06                	sd	ra,56(sp)
    80004440:	f822                	sd	s0,48(sp)
    80004442:	f426                	sd	s1,40(sp)
    80004444:	f04a                	sd	s2,32(sp)
    80004446:	ec4e                	sd	s3,24(sp)
    80004448:	e852                	sd	s4,16(sp)
    8000444a:	e456                	sd	s5,8(sp)
    8000444c:	0080                	addi	s0,sp,64
    8000444e:	84aa                	mv	s1,a0
  struct file ff;

  acquire(&ftable.lock);
    80004450:	0001d517          	auipc	a0,0x1d
    80004454:	f6850513          	addi	a0,a0,-152 # 800213b8 <ftable>
    80004458:	ffffc097          	auipc	ra,0xffffc
    8000445c:	752080e7          	jalr	1874(ra) # 80000baa <acquire>
  if(f->ref < 1)
    80004460:	40dc                	lw	a5,4(s1)
    80004462:	06f05163          	blez	a5,800044c4 <fileclose+0x88>
    panic("fileclose");
  if(--f->ref > 0){
    80004466:	37fd                	addiw	a5,a5,-1
    80004468:	0007871b          	sext.w	a4,a5
    8000446c:	c0dc                	sw	a5,4(s1)
    8000446e:	06e04363          	bgtz	a4,800044d4 <fileclose+0x98>
    release(&ftable.lock);
    return;
  }
  ff = *f;
    80004472:	0004a903          	lw	s2,0(s1)
    80004476:	0094ca83          	lbu	s5,9(s1)
    8000447a:	0104ba03          	ld	s4,16(s1)
    8000447e:	0184b983          	ld	s3,24(s1)
  f->ref = 0;
    80004482:	0004a223          	sw	zero,4(s1)
  f->type = FD_NONE;
    80004486:	0004a023          	sw	zero,0(s1)
  release(&ftable.lock);
    8000448a:	0001d517          	auipc	a0,0x1d
    8000448e:	f2e50513          	addi	a0,a0,-210 # 800213b8 <ftable>
    80004492:	ffffc097          	auipc	ra,0xffffc
    80004496:	7cc080e7          	jalr	1996(ra) # 80000c5e <release>

  if(ff.type == FD_PIPE){
    8000449a:	4785                	li	a5,1
    8000449c:	04f90d63          	beq	s2,a5,800044f6 <fileclose+0xba>
    pipeclose(ff.pipe, ff.writable);
  } else if(ff.type == FD_INODE || ff.type == FD_DEVICE){
    800044a0:	3979                	addiw	s2,s2,-2
    800044a2:	4785                	li	a5,1
    800044a4:	0527e063          	bltu	a5,s2,800044e4 <fileclose+0xa8>
    begin_op();
    800044a8:	00000097          	auipc	ra,0x0
    800044ac:	acc080e7          	jalr	-1332(ra) # 80003f74 <begin_op>
    iput(ff.ip);
    800044b0:	854e                	mv	a0,s3
    800044b2:	fffff097          	auipc	ra,0xfffff
    800044b6:	2a0080e7          	jalr	672(ra) # 80003752 <iput>
    end_op();
    800044ba:	00000097          	auipc	ra,0x0
    800044be:	b38080e7          	jalr	-1224(ra) # 80003ff2 <end_op>
    800044c2:	a00d                	j	800044e4 <fileclose+0xa8>
    panic("fileclose");
    800044c4:	00004517          	auipc	a0,0x4
    800044c8:	1cc50513          	addi	a0,a0,460 # 80008690 <syscalls+0x248>
    800044cc:	ffffc097          	auipc	ra,0xffffc
    800044d0:	06e080e7          	jalr	110(ra) # 8000053a <panic>
    release(&ftable.lock);
    800044d4:	0001d517          	auipc	a0,0x1d
    800044d8:	ee450513          	addi	a0,a0,-284 # 800213b8 <ftable>
    800044dc:	ffffc097          	auipc	ra,0xffffc
    800044e0:	782080e7          	jalr	1922(ra) # 80000c5e <release>
  }
}
    800044e4:	70e2                	ld	ra,56(sp)
    800044e6:	7442                	ld	s0,48(sp)
    800044e8:	74a2                	ld	s1,40(sp)
    800044ea:	7902                	ld	s2,32(sp)
    800044ec:	69e2                	ld	s3,24(sp)
    800044ee:	6a42                	ld	s4,16(sp)
    800044f0:	6aa2                	ld	s5,8(sp)
    800044f2:	6121                	addi	sp,sp,64
    800044f4:	8082                	ret
    pipeclose(ff.pipe, ff.writable);
    800044f6:	85d6                	mv	a1,s5
    800044f8:	8552                	mv	a0,s4
    800044fa:	00000097          	auipc	ra,0x0
    800044fe:	34c080e7          	jalr	844(ra) # 80004846 <pipeclose>
    80004502:	b7cd                	j	800044e4 <fileclose+0xa8>

0000000080004504 <filestat>:

// Get metadata about file f.
// addr is a user virtual address, pointing to a struct stat.
int
filestat(struct file *f, uint64 addr)
{
    80004504:	715d                	addi	sp,sp,-80
    80004506:	e486                	sd	ra,72(sp)
    80004508:	e0a2                	sd	s0,64(sp)
    8000450a:	fc26                	sd	s1,56(sp)
    8000450c:	f84a                	sd	s2,48(sp)
    8000450e:	f44e                	sd	s3,40(sp)
    80004510:	0880                	addi	s0,sp,80
    80004512:	84aa                	mv	s1,a0
    80004514:	89ae                	mv	s3,a1
  struct proc *p = myproc();
    80004516:	ffffd097          	auipc	ra,0xffffd
    8000451a:	45a080e7          	jalr	1114(ra) # 80001970 <myproc>
  struct stat st;
  
  if(f->type == FD_INODE || f->type == FD_DEVICE){
    8000451e:	409c                	lw	a5,0(s1)
    80004520:	37f9                	addiw	a5,a5,-2
    80004522:	4705                	li	a4,1
    80004524:	04f76763          	bltu	a4,a5,80004572 <filestat+0x6e>
    80004528:	892a                	mv	s2,a0
    ilock(f->ip);
    8000452a:	6c88                	ld	a0,24(s1)
    8000452c:	fffff097          	auipc	ra,0xfffff
    80004530:	06c080e7          	jalr	108(ra) # 80003598 <ilock>
    stati(f->ip, &st);
    80004534:	fb840593          	addi	a1,s0,-72
    80004538:	6c88                	ld	a0,24(s1)
    8000453a:	fffff097          	auipc	ra,0xfffff
    8000453e:	2e8080e7          	jalr	744(ra) # 80003822 <stati>
    iunlock(f->ip);
    80004542:	6c88                	ld	a0,24(s1)
    80004544:	fffff097          	auipc	ra,0xfffff
    80004548:	116080e7          	jalr	278(ra) # 8000365a <iunlock>
    if(copyout(p->pagetable, addr, (char *)&st, sizeof(st)) < 0)
    8000454c:	46e1                	li	a3,24
    8000454e:	fb840613          	addi	a2,s0,-72
    80004552:	85ce                	mv	a1,s3
    80004554:	05093503          	ld	a0,80(s2)
    80004558:	ffffd097          	auipc	ra,0xffffd
    8000455c:	0dc080e7          	jalr	220(ra) # 80001634 <copyout>
    80004560:	41f5551b          	sraiw	a0,a0,0x1f
      return -1;
    return 0;
  }
  return -1;
}
    80004564:	60a6                	ld	ra,72(sp)
    80004566:	6406                	ld	s0,64(sp)
    80004568:	74e2                	ld	s1,56(sp)
    8000456a:	7942                	ld	s2,48(sp)
    8000456c:	79a2                	ld	s3,40(sp)
    8000456e:	6161                	addi	sp,sp,80
    80004570:	8082                	ret
  return -1;
    80004572:	557d                	li	a0,-1
    80004574:	bfc5                	j	80004564 <filestat+0x60>

0000000080004576 <fileread>:

// Read from file f.
// addr is a user virtual address.
int
fileread(struct file *f, uint64 addr, int n)
{
    80004576:	7179                	addi	sp,sp,-48
    80004578:	f406                	sd	ra,40(sp)
    8000457a:	f022                	sd	s0,32(sp)
    8000457c:	ec26                	sd	s1,24(sp)
    8000457e:	e84a                	sd	s2,16(sp)
    80004580:	e44e                	sd	s3,8(sp)
    80004582:	1800                	addi	s0,sp,48
  int r = 0;

  if(f->readable == 0)
    80004584:	00854783          	lbu	a5,8(a0)
    80004588:	c3d5                	beqz	a5,8000462c <fileread+0xb6>
    8000458a:	84aa                	mv	s1,a0
    8000458c:	89ae                	mv	s3,a1
    8000458e:	8932                	mv	s2,a2
    return -1;

  if(f->type == FD_PIPE){
    80004590:	411c                	lw	a5,0(a0)
    80004592:	4705                	li	a4,1
    80004594:	04e78963          	beq	a5,a4,800045e6 <fileread+0x70>
    r = piperead(f->pipe, addr, n);
  } else if(f->type == FD_DEVICE){
    80004598:	470d                	li	a4,3
    8000459a:	04e78d63          	beq	a5,a4,800045f4 <fileread+0x7e>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
      return -1;
    r = devsw[f->major].read(1, addr, n);
  } else if(f->type == FD_INODE){
    8000459e:	4709                	li	a4,2
    800045a0:	06e79e63          	bne	a5,a4,8000461c <fileread+0xa6>
    ilock(f->ip);
    800045a4:	6d08                	ld	a0,24(a0)
    800045a6:	fffff097          	auipc	ra,0xfffff
    800045aa:	ff2080e7          	jalr	-14(ra) # 80003598 <ilock>
    if((r = readi(f->ip, 1, addr, f->off, n)) > 0)
    800045ae:	874a                	mv	a4,s2
    800045b0:	5094                	lw	a3,32(s1)
    800045b2:	864e                	mv	a2,s3
    800045b4:	4585                	li	a1,1
    800045b6:	6c88                	ld	a0,24(s1)
    800045b8:	fffff097          	auipc	ra,0xfffff
    800045bc:	294080e7          	jalr	660(ra) # 8000384c <readi>
    800045c0:	892a                	mv	s2,a0
    800045c2:	00a05563          	blez	a0,800045cc <fileread+0x56>
      f->off += r;
    800045c6:	509c                	lw	a5,32(s1)
    800045c8:	9fa9                	addw	a5,a5,a0
    800045ca:	d09c                	sw	a5,32(s1)
    iunlock(f->ip);
    800045cc:	6c88                	ld	a0,24(s1)
    800045ce:	fffff097          	auipc	ra,0xfffff
    800045d2:	08c080e7          	jalr	140(ra) # 8000365a <iunlock>
  } else {
    panic("fileread");
  }

  return r;
}
    800045d6:	854a                	mv	a0,s2
    800045d8:	70a2                	ld	ra,40(sp)
    800045da:	7402                	ld	s0,32(sp)
    800045dc:	64e2                	ld	s1,24(sp)
    800045de:	6942                	ld	s2,16(sp)
    800045e0:	69a2                	ld	s3,8(sp)
    800045e2:	6145                	addi	sp,sp,48
    800045e4:	8082                	ret
    r = piperead(f->pipe, addr, n);
    800045e6:	6908                	ld	a0,16(a0)
    800045e8:	00000097          	auipc	ra,0x0
    800045ec:	3c0080e7          	jalr	960(ra) # 800049a8 <piperead>
    800045f0:	892a                	mv	s2,a0
    800045f2:	b7d5                	j	800045d6 <fileread+0x60>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
    800045f4:	02451783          	lh	a5,36(a0)
    800045f8:	03079693          	slli	a3,a5,0x30
    800045fc:	92c1                	srli	a3,a3,0x30
    800045fe:	4725                	li	a4,9
    80004600:	02d76863          	bltu	a4,a3,80004630 <fileread+0xba>
    80004604:	0792                	slli	a5,a5,0x4
    80004606:	0001d717          	auipc	a4,0x1d
    8000460a:	d1270713          	addi	a4,a4,-750 # 80021318 <devsw>
    8000460e:	97ba                	add	a5,a5,a4
    80004610:	639c                	ld	a5,0(a5)
    80004612:	c38d                	beqz	a5,80004634 <fileread+0xbe>
    r = devsw[f->major].read(1, addr, n);
    80004614:	4505                	li	a0,1
    80004616:	9782                	jalr	a5
    80004618:	892a                	mv	s2,a0
    8000461a:	bf75                	j	800045d6 <fileread+0x60>
    panic("fileread");
    8000461c:	00004517          	auipc	a0,0x4
    80004620:	08450513          	addi	a0,a0,132 # 800086a0 <syscalls+0x258>
    80004624:	ffffc097          	auipc	ra,0xffffc
    80004628:	f16080e7          	jalr	-234(ra) # 8000053a <panic>
    return -1;
    8000462c:	597d                	li	s2,-1
    8000462e:	b765                	j	800045d6 <fileread+0x60>
      return -1;
    80004630:	597d                	li	s2,-1
    80004632:	b755                	j	800045d6 <fileread+0x60>
    80004634:	597d                	li	s2,-1
    80004636:	b745                	j	800045d6 <fileread+0x60>

0000000080004638 <filewrite>:

// Write to file f.
// addr is a user virtual address.
int
filewrite(struct file *f, uint64 addr, int n)
{
    80004638:	715d                	addi	sp,sp,-80
    8000463a:	e486                	sd	ra,72(sp)
    8000463c:	e0a2                	sd	s0,64(sp)
    8000463e:	fc26                	sd	s1,56(sp)
    80004640:	f84a                	sd	s2,48(sp)
    80004642:	f44e                	sd	s3,40(sp)
    80004644:	f052                	sd	s4,32(sp)
    80004646:	ec56                	sd	s5,24(sp)
    80004648:	e85a                	sd	s6,16(sp)
    8000464a:	e45e                	sd	s7,8(sp)
    8000464c:	e062                	sd	s8,0(sp)
    8000464e:	0880                	addi	s0,sp,80
  int r, ret = 0;

  if(f->writable == 0)
    80004650:	00954783          	lbu	a5,9(a0)
    80004654:	10078663          	beqz	a5,80004760 <filewrite+0x128>
    80004658:	892a                	mv	s2,a0
    8000465a:	8b2e                	mv	s6,a1
    8000465c:	8a32                	mv	s4,a2
    return -1;

  if(f->type == FD_PIPE){
    8000465e:	411c                	lw	a5,0(a0)
    80004660:	4705                	li	a4,1
    80004662:	02e78263          	beq	a5,a4,80004686 <filewrite+0x4e>
    ret = pipewrite(f->pipe, addr, n);
  } else if(f->type == FD_DEVICE){
    80004666:	470d                	li	a4,3
    80004668:	02e78663          	beq	a5,a4,80004694 <filewrite+0x5c>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
      return -1;
    ret = devsw[f->major].write(1, addr, n);
  } else if(f->type == FD_INODE){
    8000466c:	4709                	li	a4,2
    8000466e:	0ee79163          	bne	a5,a4,80004750 <filewrite+0x118>
    // and 2 blocks of slop for non-aligned writes.
    // this really belongs lower down, since writei()
    // might be writing a device like the console.
    int max = ((MAXOPBLOCKS-1-1-2) / 2) * BSIZE;
    int i = 0;
    while(i < n){
    80004672:	0ac05d63          	blez	a2,8000472c <filewrite+0xf4>
    int i = 0;
    80004676:	4981                	li	s3,0
    80004678:	6b85                	lui	s7,0x1
    8000467a:	c00b8b93          	addi	s7,s7,-1024 # c00 <_entry-0x7ffff400>
    8000467e:	6c05                	lui	s8,0x1
    80004680:	c00c0c1b          	addiw	s8,s8,-1024 # c00 <_entry-0x7ffff400>
    80004684:	a861                	j	8000471c <filewrite+0xe4>
    ret = pipewrite(f->pipe, addr, n);
    80004686:	6908                	ld	a0,16(a0)
    80004688:	00000097          	auipc	ra,0x0
    8000468c:	22e080e7          	jalr	558(ra) # 800048b6 <pipewrite>
    80004690:	8a2a                	mv	s4,a0
    80004692:	a045                	j	80004732 <filewrite+0xfa>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
    80004694:	02451783          	lh	a5,36(a0)
    80004698:	03079693          	slli	a3,a5,0x30
    8000469c:	92c1                	srli	a3,a3,0x30
    8000469e:	4725                	li	a4,9
    800046a0:	0cd76263          	bltu	a4,a3,80004764 <filewrite+0x12c>
    800046a4:	0792                	slli	a5,a5,0x4
    800046a6:	0001d717          	auipc	a4,0x1d
    800046aa:	c7270713          	addi	a4,a4,-910 # 80021318 <devsw>
    800046ae:	97ba                	add	a5,a5,a4
    800046b0:	679c                	ld	a5,8(a5)
    800046b2:	cbdd                	beqz	a5,80004768 <filewrite+0x130>
    ret = devsw[f->major].write(1, addr, n);
    800046b4:	4505                	li	a0,1
    800046b6:	9782                	jalr	a5
    800046b8:	8a2a                	mv	s4,a0
    800046ba:	a8a5                	j	80004732 <filewrite+0xfa>
    800046bc:	00048a9b          	sext.w	s5,s1
      int n1 = n - i;
      if(n1 > max)
        n1 = max;

      begin_op();
    800046c0:	00000097          	auipc	ra,0x0
    800046c4:	8b4080e7          	jalr	-1868(ra) # 80003f74 <begin_op>
      ilock(f->ip);
    800046c8:	01893503          	ld	a0,24(s2)
    800046cc:	fffff097          	auipc	ra,0xfffff
    800046d0:	ecc080e7          	jalr	-308(ra) # 80003598 <ilock>
      if ((r = writei(f->ip, 1, addr + i, f->off, n1)) > 0)
    800046d4:	8756                	mv	a4,s5
    800046d6:	02092683          	lw	a3,32(s2)
    800046da:	01698633          	add	a2,s3,s6
    800046de:	4585                	li	a1,1
    800046e0:	01893503          	ld	a0,24(s2)
    800046e4:	fffff097          	auipc	ra,0xfffff
    800046e8:	260080e7          	jalr	608(ra) # 80003944 <writei>
    800046ec:	84aa                	mv	s1,a0
    800046ee:	00a05763          	blez	a0,800046fc <filewrite+0xc4>
        f->off += r;
    800046f2:	02092783          	lw	a5,32(s2)
    800046f6:	9fa9                	addw	a5,a5,a0
    800046f8:	02f92023          	sw	a5,32(s2)
      iunlock(f->ip);
    800046fc:	01893503          	ld	a0,24(s2)
    80004700:	fffff097          	auipc	ra,0xfffff
    80004704:	f5a080e7          	jalr	-166(ra) # 8000365a <iunlock>
      end_op();
    80004708:	00000097          	auipc	ra,0x0
    8000470c:	8ea080e7          	jalr	-1814(ra) # 80003ff2 <end_op>

      if(r != n1){
    80004710:	009a9f63          	bne	s5,s1,8000472e <filewrite+0xf6>
        // error from writei
        break;
      }
      i += r;
    80004714:	013489bb          	addw	s3,s1,s3
    while(i < n){
    80004718:	0149db63          	bge	s3,s4,8000472e <filewrite+0xf6>
      int n1 = n - i;
    8000471c:	413a04bb          	subw	s1,s4,s3
    80004720:	0004879b          	sext.w	a5,s1
    80004724:	f8fbdce3          	bge	s7,a5,800046bc <filewrite+0x84>
    80004728:	84e2                	mv	s1,s8
    8000472a:	bf49                	j	800046bc <filewrite+0x84>
    int i = 0;
    8000472c:	4981                	li	s3,0
    }
    ret = (i == n ? n : -1);
    8000472e:	013a1f63          	bne	s4,s3,8000474c <filewrite+0x114>
  } else {
    panic("filewrite");
  }

  return ret;
}
    80004732:	8552                	mv	a0,s4
    80004734:	60a6                	ld	ra,72(sp)
    80004736:	6406                	ld	s0,64(sp)
    80004738:	74e2                	ld	s1,56(sp)
    8000473a:	7942                	ld	s2,48(sp)
    8000473c:	79a2                	ld	s3,40(sp)
    8000473e:	7a02                	ld	s4,32(sp)
    80004740:	6ae2                	ld	s5,24(sp)
    80004742:	6b42                	ld	s6,16(sp)
    80004744:	6ba2                	ld	s7,8(sp)
    80004746:	6c02                	ld	s8,0(sp)
    80004748:	6161                	addi	sp,sp,80
    8000474a:	8082                	ret
    ret = (i == n ? n : -1);
    8000474c:	5a7d                	li	s4,-1
    8000474e:	b7d5                	j	80004732 <filewrite+0xfa>
    panic("filewrite");
    80004750:	00004517          	auipc	a0,0x4
    80004754:	f6050513          	addi	a0,a0,-160 # 800086b0 <syscalls+0x268>
    80004758:	ffffc097          	auipc	ra,0xffffc
    8000475c:	de2080e7          	jalr	-542(ra) # 8000053a <panic>
    return -1;
    80004760:	5a7d                	li	s4,-1
    80004762:	bfc1                	j	80004732 <filewrite+0xfa>
      return -1;
    80004764:	5a7d                	li	s4,-1
    80004766:	b7f1                	j	80004732 <filewrite+0xfa>
    80004768:	5a7d                	li	s4,-1
    8000476a:	b7e1                	j	80004732 <filewrite+0xfa>

000000008000476c <pipealloc>:
  int writeopen;  // write fd is still open
};

int
pipealloc(struct file **f0, struct file **f1)
{
    8000476c:	7179                	addi	sp,sp,-48
    8000476e:	f406                	sd	ra,40(sp)
    80004770:	f022                	sd	s0,32(sp)
    80004772:	ec26                	sd	s1,24(sp)
    80004774:	e84a                	sd	s2,16(sp)
    80004776:	e44e                	sd	s3,8(sp)
    80004778:	e052                	sd	s4,0(sp)
    8000477a:	1800                	addi	s0,sp,48
    8000477c:	84aa                	mv	s1,a0
    8000477e:	8a2e                	mv	s4,a1
  struct pipe *pi;

  pi = 0;
  *f0 = *f1 = 0;
    80004780:	0005b023          	sd	zero,0(a1)
    80004784:	00053023          	sd	zero,0(a0)
  if((*f0 = filealloc()) == 0 || (*f1 = filealloc()) == 0)
    80004788:	00000097          	auipc	ra,0x0
    8000478c:	bf8080e7          	jalr	-1032(ra) # 80004380 <filealloc>
    80004790:	e088                	sd	a0,0(s1)
    80004792:	c551                	beqz	a0,8000481e <pipealloc+0xb2>
    80004794:	00000097          	auipc	ra,0x0
    80004798:	bec080e7          	jalr	-1044(ra) # 80004380 <filealloc>
    8000479c:	00aa3023          	sd	a0,0(s4)
    800047a0:	c92d                	beqz	a0,80004812 <pipealloc+0xa6>
    goto bad;
  if((pi = (struct pipe*)kalloc()) == 0)
    800047a2:	ffffc097          	auipc	ra,0xffffc
    800047a6:	332080e7          	jalr	818(ra) # 80000ad4 <kalloc>
    800047aa:	892a                	mv	s2,a0
    800047ac:	c125                	beqz	a0,8000480c <pipealloc+0xa0>
    goto bad;
  pi->readopen = 1;
    800047ae:	4985                	li	s3,1
    800047b0:	23352023          	sw	s3,544(a0)
  pi->writeopen = 1;
    800047b4:	23352223          	sw	s3,548(a0)
  pi->nwrite = 0;
    800047b8:	20052e23          	sw	zero,540(a0)
  pi->nread = 0;
    800047bc:	20052c23          	sw	zero,536(a0)
  initlock(&pi->lock, "pipe");
    800047c0:	00004597          	auipc	a1,0x4
    800047c4:	f0058593          	addi	a1,a1,-256 # 800086c0 <syscalls+0x278>
    800047c8:	ffffc097          	auipc	ra,0xffffc
    800047cc:	352080e7          	jalr	850(ra) # 80000b1a <initlock>
  (*f0)->type = FD_PIPE;
    800047d0:	609c                	ld	a5,0(s1)
    800047d2:	0137a023          	sw	s3,0(a5)
  (*f0)->readable = 1;
    800047d6:	609c                	ld	a5,0(s1)
    800047d8:	01378423          	sb	s3,8(a5)
  (*f0)->writable = 0;
    800047dc:	609c                	ld	a5,0(s1)
    800047de:	000784a3          	sb	zero,9(a5)
  (*f0)->pipe = pi;
    800047e2:	609c                	ld	a5,0(s1)
    800047e4:	0127b823          	sd	s2,16(a5)
  (*f1)->type = FD_PIPE;
    800047e8:	000a3783          	ld	a5,0(s4)
    800047ec:	0137a023          	sw	s3,0(a5)
  (*f1)->readable = 0;
    800047f0:	000a3783          	ld	a5,0(s4)
    800047f4:	00078423          	sb	zero,8(a5)
  (*f1)->writable = 1;
    800047f8:	000a3783          	ld	a5,0(s4)
    800047fc:	013784a3          	sb	s3,9(a5)
  (*f1)->pipe = pi;
    80004800:	000a3783          	ld	a5,0(s4)
    80004804:	0127b823          	sd	s2,16(a5)
  return 0;
    80004808:	4501                	li	a0,0
    8000480a:	a025                	j	80004832 <pipealloc+0xc6>

 bad:
  if(pi)
    kfree((char*)pi);
  if(*f0)
    8000480c:	6088                	ld	a0,0(s1)
    8000480e:	e501                	bnez	a0,80004816 <pipealloc+0xaa>
    80004810:	a039                	j	8000481e <pipealloc+0xb2>
    80004812:	6088                	ld	a0,0(s1)
    80004814:	c51d                	beqz	a0,80004842 <pipealloc+0xd6>
    fileclose(*f0);
    80004816:	00000097          	auipc	ra,0x0
    8000481a:	c26080e7          	jalr	-986(ra) # 8000443c <fileclose>
  if(*f1)
    8000481e:	000a3783          	ld	a5,0(s4)
    fileclose(*f1);
  return -1;
    80004822:	557d                	li	a0,-1
  if(*f1)
    80004824:	c799                	beqz	a5,80004832 <pipealloc+0xc6>
    fileclose(*f1);
    80004826:	853e                	mv	a0,a5
    80004828:	00000097          	auipc	ra,0x0
    8000482c:	c14080e7          	jalr	-1004(ra) # 8000443c <fileclose>
  return -1;
    80004830:	557d                	li	a0,-1
}
    80004832:	70a2                	ld	ra,40(sp)
    80004834:	7402                	ld	s0,32(sp)
    80004836:	64e2                	ld	s1,24(sp)
    80004838:	6942                	ld	s2,16(sp)
    8000483a:	69a2                	ld	s3,8(sp)
    8000483c:	6a02                	ld	s4,0(sp)
    8000483e:	6145                	addi	sp,sp,48
    80004840:	8082                	ret
  return -1;
    80004842:	557d                	li	a0,-1
    80004844:	b7fd                	j	80004832 <pipealloc+0xc6>

0000000080004846 <pipeclose>:

void
pipeclose(struct pipe *pi, int writable)
{
    80004846:	1101                	addi	sp,sp,-32
    80004848:	ec06                	sd	ra,24(sp)
    8000484a:	e822                	sd	s0,16(sp)
    8000484c:	e426                	sd	s1,8(sp)
    8000484e:	e04a                	sd	s2,0(sp)
    80004850:	1000                	addi	s0,sp,32
    80004852:	84aa                	mv	s1,a0
    80004854:	892e                	mv	s2,a1
  acquire(&pi->lock);
    80004856:	ffffc097          	auipc	ra,0xffffc
    8000485a:	354080e7          	jalr	852(ra) # 80000baa <acquire>
  if(writable){
    8000485e:	02090d63          	beqz	s2,80004898 <pipeclose+0x52>
    pi->writeopen = 0;
    80004862:	2204a223          	sw	zero,548(s1)
    wakeup(&pi->nread);
    80004866:	21848513          	addi	a0,s1,536
    8000486a:	ffffe097          	auipc	ra,0xffffe
    8000486e:	956080e7          	jalr	-1706(ra) # 800021c0 <wakeup>
  } else {
    pi->readopen = 0;
    wakeup(&pi->nwrite);
  }
  if(pi->readopen == 0 && pi->writeopen == 0){
    80004872:	2204b783          	ld	a5,544(s1)
    80004876:	eb95                	bnez	a5,800048aa <pipeclose+0x64>
    release(&pi->lock);
    80004878:	8526                	mv	a0,s1
    8000487a:	ffffc097          	auipc	ra,0xffffc
    8000487e:	3e4080e7          	jalr	996(ra) # 80000c5e <release>
    kfree((char*)pi);
    80004882:	8526                	mv	a0,s1
    80004884:	ffffc097          	auipc	ra,0xffffc
    80004888:	15e080e7          	jalr	350(ra) # 800009e2 <kfree>
  } else
    release(&pi->lock);
}
    8000488c:	60e2                	ld	ra,24(sp)
    8000488e:	6442                	ld	s0,16(sp)
    80004890:	64a2                	ld	s1,8(sp)
    80004892:	6902                	ld	s2,0(sp)
    80004894:	6105                	addi	sp,sp,32
    80004896:	8082                	ret
    pi->readopen = 0;
    80004898:	2204a023          	sw	zero,544(s1)
    wakeup(&pi->nwrite);
    8000489c:	21c48513          	addi	a0,s1,540
    800048a0:	ffffe097          	auipc	ra,0xffffe
    800048a4:	920080e7          	jalr	-1760(ra) # 800021c0 <wakeup>
    800048a8:	b7e9                	j	80004872 <pipeclose+0x2c>
    release(&pi->lock);
    800048aa:	8526                	mv	a0,s1
    800048ac:	ffffc097          	auipc	ra,0xffffc
    800048b0:	3b2080e7          	jalr	946(ra) # 80000c5e <release>
}
    800048b4:	bfe1                	j	8000488c <pipeclose+0x46>

00000000800048b6 <pipewrite>:

int
pipewrite(struct pipe *pi, uint64 addr, int n)
{
    800048b6:	711d                	addi	sp,sp,-96
    800048b8:	ec86                	sd	ra,88(sp)
    800048ba:	e8a2                	sd	s0,80(sp)
    800048bc:	e4a6                	sd	s1,72(sp)
    800048be:	e0ca                	sd	s2,64(sp)
    800048c0:	fc4e                	sd	s3,56(sp)
    800048c2:	f852                	sd	s4,48(sp)
    800048c4:	f456                	sd	s5,40(sp)
    800048c6:	f05a                	sd	s6,32(sp)
    800048c8:	ec5e                	sd	s7,24(sp)
    800048ca:	e862                	sd	s8,16(sp)
    800048cc:	1080                	addi	s0,sp,96
    800048ce:	84aa                	mv	s1,a0
    800048d0:	8aae                	mv	s5,a1
    800048d2:	8a32                	mv	s4,a2
  int i = 0;
  struct proc *pr = myproc();
    800048d4:	ffffd097          	auipc	ra,0xffffd
    800048d8:	09c080e7          	jalr	156(ra) # 80001970 <myproc>
    800048dc:	89aa                	mv	s3,a0

  acquire(&pi->lock);
    800048de:	8526                	mv	a0,s1
    800048e0:	ffffc097          	auipc	ra,0xffffc
    800048e4:	2ca080e7          	jalr	714(ra) # 80000baa <acquire>
  while(i < n){
    800048e8:	0b405363          	blez	s4,8000498e <pipewrite+0xd8>
  int i = 0;
    800048ec:	4901                	li	s2,0
    if(pi->nwrite == pi->nread + PIPESIZE){ //DOC: pipewrite-full
      wakeup(&pi->nread);
      sleep(&pi->nwrite, &pi->lock);
    } else {
      char ch;
      if(copyin(pr->pagetable, &ch, addr + i, 1) == -1)
    800048ee:	5b7d                	li	s6,-1
      wakeup(&pi->nread);
    800048f0:	21848c13          	addi	s8,s1,536
      sleep(&pi->nwrite, &pi->lock);
    800048f4:	21c48b93          	addi	s7,s1,540
    800048f8:	a089                	j	8000493a <pipewrite+0x84>
      release(&pi->lock);
    800048fa:	8526                	mv	a0,s1
    800048fc:	ffffc097          	auipc	ra,0xffffc
    80004900:	362080e7          	jalr	866(ra) # 80000c5e <release>
      return -1;
    80004904:	597d                	li	s2,-1
  }
  wakeup(&pi->nread);
  release(&pi->lock);

  return i;
}
    80004906:	854a                	mv	a0,s2
    80004908:	60e6                	ld	ra,88(sp)
    8000490a:	6446                	ld	s0,80(sp)
    8000490c:	64a6                	ld	s1,72(sp)
    8000490e:	6906                	ld	s2,64(sp)
    80004910:	79e2                	ld	s3,56(sp)
    80004912:	7a42                	ld	s4,48(sp)
    80004914:	7aa2                	ld	s5,40(sp)
    80004916:	7b02                	ld	s6,32(sp)
    80004918:	6be2                	ld	s7,24(sp)
    8000491a:	6c42                	ld	s8,16(sp)
    8000491c:	6125                	addi	sp,sp,96
    8000491e:	8082                	ret
      wakeup(&pi->nread);
    80004920:	8562                	mv	a0,s8
    80004922:	ffffe097          	auipc	ra,0xffffe
    80004926:	89e080e7          	jalr	-1890(ra) # 800021c0 <wakeup>
      sleep(&pi->nwrite, &pi->lock);
    8000492a:	85a6                	mv	a1,s1
    8000492c:	855e                	mv	a0,s7
    8000492e:	ffffd097          	auipc	ra,0xffffd
    80004932:	706080e7          	jalr	1798(ra) # 80002034 <sleep>
  while(i < n){
    80004936:	05495d63          	bge	s2,s4,80004990 <pipewrite+0xda>
    if(pi->readopen == 0 || pr->killed){
    8000493a:	2204a783          	lw	a5,544(s1)
    8000493e:	dfd5                	beqz	a5,800048fa <pipewrite+0x44>
    80004940:	0289a783          	lw	a5,40(s3)
    80004944:	fbdd                	bnez	a5,800048fa <pipewrite+0x44>
    if(pi->nwrite == pi->nread + PIPESIZE){ //DOC: pipewrite-full
    80004946:	2184a783          	lw	a5,536(s1)
    8000494a:	21c4a703          	lw	a4,540(s1)
    8000494e:	2007879b          	addiw	a5,a5,512
    80004952:	fcf707e3          	beq	a4,a5,80004920 <pipewrite+0x6a>
      if(copyin(pr->pagetable, &ch, addr + i, 1) == -1)
    80004956:	4685                	li	a3,1
    80004958:	01590633          	add	a2,s2,s5
    8000495c:	faf40593          	addi	a1,s0,-81
    80004960:	0509b503          	ld	a0,80(s3)
    80004964:	ffffd097          	auipc	ra,0xffffd
    80004968:	d5c080e7          	jalr	-676(ra) # 800016c0 <copyin>
    8000496c:	03650263          	beq	a0,s6,80004990 <pipewrite+0xda>
      pi->data[pi->nwrite++ % PIPESIZE] = ch;
    80004970:	21c4a783          	lw	a5,540(s1)
    80004974:	0017871b          	addiw	a4,a5,1
    80004978:	20e4ae23          	sw	a4,540(s1)
    8000497c:	1ff7f793          	andi	a5,a5,511
    80004980:	97a6                	add	a5,a5,s1
    80004982:	faf44703          	lbu	a4,-81(s0)
    80004986:	00e78c23          	sb	a4,24(a5)
      i++;
    8000498a:	2905                	addiw	s2,s2,1
    8000498c:	b76d                	j	80004936 <pipewrite+0x80>
  int i = 0;
    8000498e:	4901                	li	s2,0
  wakeup(&pi->nread);
    80004990:	21848513          	addi	a0,s1,536
    80004994:	ffffe097          	auipc	ra,0xffffe
    80004998:	82c080e7          	jalr	-2004(ra) # 800021c0 <wakeup>
  release(&pi->lock);
    8000499c:	8526                	mv	a0,s1
    8000499e:	ffffc097          	auipc	ra,0xffffc
    800049a2:	2c0080e7          	jalr	704(ra) # 80000c5e <release>
  return i;
    800049a6:	b785                	j	80004906 <pipewrite+0x50>

00000000800049a8 <piperead>:

int
piperead(struct pipe *pi, uint64 addr, int n)
{
    800049a8:	715d                	addi	sp,sp,-80
    800049aa:	e486                	sd	ra,72(sp)
    800049ac:	e0a2                	sd	s0,64(sp)
    800049ae:	fc26                	sd	s1,56(sp)
    800049b0:	f84a                	sd	s2,48(sp)
    800049b2:	f44e                	sd	s3,40(sp)
    800049b4:	f052                	sd	s4,32(sp)
    800049b6:	ec56                	sd	s5,24(sp)
    800049b8:	e85a                	sd	s6,16(sp)
    800049ba:	0880                	addi	s0,sp,80
    800049bc:	84aa                	mv	s1,a0
    800049be:	892e                	mv	s2,a1
    800049c0:	8ab2                	mv	s5,a2
  int i;
  struct proc *pr = myproc();
    800049c2:	ffffd097          	auipc	ra,0xffffd
    800049c6:	fae080e7          	jalr	-82(ra) # 80001970 <myproc>
    800049ca:	8a2a                	mv	s4,a0
  char ch;

  acquire(&pi->lock);
    800049cc:	8526                	mv	a0,s1
    800049ce:	ffffc097          	auipc	ra,0xffffc
    800049d2:	1dc080e7          	jalr	476(ra) # 80000baa <acquire>
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    800049d6:	2184a703          	lw	a4,536(s1)
    800049da:	21c4a783          	lw	a5,540(s1)
    if(pr->killed){
      release(&pi->lock);
      return -1;
    }
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
    800049de:	21848993          	addi	s3,s1,536
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    800049e2:	02f71463          	bne	a4,a5,80004a0a <piperead+0x62>
    800049e6:	2244a783          	lw	a5,548(s1)
    800049ea:	c385                	beqz	a5,80004a0a <piperead+0x62>
    if(pr->killed){
    800049ec:	028a2783          	lw	a5,40(s4)
    800049f0:	ebc9                	bnez	a5,80004a82 <piperead+0xda>
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
    800049f2:	85a6                	mv	a1,s1
    800049f4:	854e                	mv	a0,s3
    800049f6:	ffffd097          	auipc	ra,0xffffd
    800049fa:	63e080e7          	jalr	1598(ra) # 80002034 <sleep>
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    800049fe:	2184a703          	lw	a4,536(s1)
    80004a02:	21c4a783          	lw	a5,540(s1)
    80004a06:	fef700e3          	beq	a4,a5,800049e6 <piperead+0x3e>
  }
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    80004a0a:	4981                	li	s3,0
    if(pi->nread == pi->nwrite)
      break;
    ch = pi->data[pi->nread++ % PIPESIZE];
    if(copyout(pr->pagetable, addr + i, &ch, 1) == -1)
    80004a0c:	5b7d                	li	s6,-1
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    80004a0e:	05505463          	blez	s5,80004a56 <piperead+0xae>
    if(pi->nread == pi->nwrite)
    80004a12:	2184a783          	lw	a5,536(s1)
    80004a16:	21c4a703          	lw	a4,540(s1)
    80004a1a:	02f70e63          	beq	a4,a5,80004a56 <piperead+0xae>
    ch = pi->data[pi->nread++ % PIPESIZE];
    80004a1e:	0017871b          	addiw	a4,a5,1
    80004a22:	20e4ac23          	sw	a4,536(s1)
    80004a26:	1ff7f793          	andi	a5,a5,511
    80004a2a:	97a6                	add	a5,a5,s1
    80004a2c:	0187c783          	lbu	a5,24(a5)
    80004a30:	faf40fa3          	sb	a5,-65(s0)
    if(copyout(pr->pagetable, addr + i, &ch, 1) == -1)
    80004a34:	4685                	li	a3,1
    80004a36:	fbf40613          	addi	a2,s0,-65
    80004a3a:	85ca                	mv	a1,s2
    80004a3c:	050a3503          	ld	a0,80(s4)
    80004a40:	ffffd097          	auipc	ra,0xffffd
    80004a44:	bf4080e7          	jalr	-1036(ra) # 80001634 <copyout>
    80004a48:	01650763          	beq	a0,s6,80004a56 <piperead+0xae>
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    80004a4c:	2985                	addiw	s3,s3,1
    80004a4e:	0905                	addi	s2,s2,1
    80004a50:	fd3a91e3          	bne	s5,s3,80004a12 <piperead+0x6a>
    80004a54:	89d6                	mv	s3,s5
      break;
  }
  wakeup(&pi->nwrite);  //DOC: piperead-wakeup
    80004a56:	21c48513          	addi	a0,s1,540
    80004a5a:	ffffd097          	auipc	ra,0xffffd
    80004a5e:	766080e7          	jalr	1894(ra) # 800021c0 <wakeup>
  release(&pi->lock);
    80004a62:	8526                	mv	a0,s1
    80004a64:	ffffc097          	auipc	ra,0xffffc
    80004a68:	1fa080e7          	jalr	506(ra) # 80000c5e <release>
  return i;
}
    80004a6c:	854e                	mv	a0,s3
    80004a6e:	60a6                	ld	ra,72(sp)
    80004a70:	6406                	ld	s0,64(sp)
    80004a72:	74e2                	ld	s1,56(sp)
    80004a74:	7942                	ld	s2,48(sp)
    80004a76:	79a2                	ld	s3,40(sp)
    80004a78:	7a02                	ld	s4,32(sp)
    80004a7a:	6ae2                	ld	s5,24(sp)
    80004a7c:	6b42                	ld	s6,16(sp)
    80004a7e:	6161                	addi	sp,sp,80
    80004a80:	8082                	ret
      release(&pi->lock);
    80004a82:	8526                	mv	a0,s1
    80004a84:	ffffc097          	auipc	ra,0xffffc
    80004a88:	1da080e7          	jalr	474(ra) # 80000c5e <release>
      return -1;
    80004a8c:	59fd                	li	s3,-1
    80004a8e:	bff9                	j	80004a6c <piperead+0xc4>

0000000080004a90 <exec>:

static int loadseg(pde_t *pgdir, uint64 addr, struct inode *ip, uint offset, uint sz);

int
exec(char *path, char **argv)
{
    80004a90:	de010113          	addi	sp,sp,-544
    80004a94:	20113c23          	sd	ra,536(sp)
    80004a98:	20813823          	sd	s0,528(sp)
    80004a9c:	20913423          	sd	s1,520(sp)
    80004aa0:	21213023          	sd	s2,512(sp)
    80004aa4:	ffce                	sd	s3,504(sp)
    80004aa6:	fbd2                	sd	s4,496(sp)
    80004aa8:	f7d6                	sd	s5,488(sp)
    80004aaa:	f3da                	sd	s6,480(sp)
    80004aac:	efde                	sd	s7,472(sp)
    80004aae:	ebe2                	sd	s8,464(sp)
    80004ab0:	e7e6                	sd	s9,456(sp)
    80004ab2:	e3ea                	sd	s10,448(sp)
    80004ab4:	ff6e                	sd	s11,440(sp)
    80004ab6:	1400                	addi	s0,sp,544
    80004ab8:	892a                	mv	s2,a0
    80004aba:	dea43423          	sd	a0,-536(s0)
    80004abe:	deb43823          	sd	a1,-528(s0)
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
  struct elfhdr elf;
  struct inode *ip;
  struct proghdr ph;
  pagetable_t pagetable = 0, oldpagetable;
  struct proc *p = myproc();
    80004ac2:	ffffd097          	auipc	ra,0xffffd
    80004ac6:	eae080e7          	jalr	-338(ra) # 80001970 <myproc>
    80004aca:	84aa                	mv	s1,a0

  begin_op();
    80004acc:	fffff097          	auipc	ra,0xfffff
    80004ad0:	4a8080e7          	jalr	1192(ra) # 80003f74 <begin_op>

  if((ip = namei(path)) == 0){
    80004ad4:	854a                	mv	a0,s2
    80004ad6:	fffff097          	auipc	ra,0xfffff
    80004ada:	27e080e7          	jalr	638(ra) # 80003d54 <namei>
    80004ade:	c93d                	beqz	a0,80004b54 <exec+0xc4>
    80004ae0:	8aaa                	mv	s5,a0
    end_op();
    return -1;
  }
  ilock(ip);
    80004ae2:	fffff097          	auipc	ra,0xfffff
    80004ae6:	ab6080e7          	jalr	-1354(ra) # 80003598 <ilock>

  // Check ELF header
  if(readi(ip, 0, (uint64)&elf, 0, sizeof(elf)) != sizeof(elf))
    80004aea:	04000713          	li	a4,64
    80004aee:	4681                	li	a3,0
    80004af0:	e5040613          	addi	a2,s0,-432
    80004af4:	4581                	li	a1,0
    80004af6:	8556                	mv	a0,s5
    80004af8:	fffff097          	auipc	ra,0xfffff
    80004afc:	d54080e7          	jalr	-684(ra) # 8000384c <readi>
    80004b00:	04000793          	li	a5,64
    80004b04:	00f51a63          	bne	a0,a5,80004b18 <exec+0x88>
    goto bad;
  if(elf.magic != ELF_MAGIC)
    80004b08:	e5042703          	lw	a4,-432(s0)
    80004b0c:	464c47b7          	lui	a5,0x464c4
    80004b10:	57f78793          	addi	a5,a5,1407 # 464c457f <_entry-0x39b3ba81>
    80004b14:	04f70663          	beq	a4,a5,80004b60 <exec+0xd0>

 bad:
  if(pagetable)
    proc_freepagetable(pagetable, sz);
  if(ip){
    iunlockput(ip);
    80004b18:	8556                	mv	a0,s5
    80004b1a:	fffff097          	auipc	ra,0xfffff
    80004b1e:	ce0080e7          	jalr	-800(ra) # 800037fa <iunlockput>
    end_op();
    80004b22:	fffff097          	auipc	ra,0xfffff
    80004b26:	4d0080e7          	jalr	1232(ra) # 80003ff2 <end_op>
  }
  return -1;
    80004b2a:	557d                	li	a0,-1
}
    80004b2c:	21813083          	ld	ra,536(sp)
    80004b30:	21013403          	ld	s0,528(sp)
    80004b34:	20813483          	ld	s1,520(sp)
    80004b38:	20013903          	ld	s2,512(sp)
    80004b3c:	79fe                	ld	s3,504(sp)
    80004b3e:	7a5e                	ld	s4,496(sp)
    80004b40:	7abe                	ld	s5,488(sp)
    80004b42:	7b1e                	ld	s6,480(sp)
    80004b44:	6bfe                	ld	s7,472(sp)
    80004b46:	6c5e                	ld	s8,464(sp)
    80004b48:	6cbe                	ld	s9,456(sp)
    80004b4a:	6d1e                	ld	s10,448(sp)
    80004b4c:	7dfa                	ld	s11,440(sp)
    80004b4e:	22010113          	addi	sp,sp,544
    80004b52:	8082                	ret
    end_op();
    80004b54:	fffff097          	auipc	ra,0xfffff
    80004b58:	49e080e7          	jalr	1182(ra) # 80003ff2 <end_op>
    return -1;
    80004b5c:	557d                	li	a0,-1
    80004b5e:	b7f9                	j	80004b2c <exec+0x9c>
  if((pagetable = proc_pagetable(p)) == 0)
    80004b60:	8526                	mv	a0,s1
    80004b62:	ffffd097          	auipc	ra,0xffffd
    80004b66:	ed2080e7          	jalr	-302(ra) # 80001a34 <proc_pagetable>
    80004b6a:	8b2a                	mv	s6,a0
    80004b6c:	d555                	beqz	a0,80004b18 <exec+0x88>
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    80004b6e:	e7042783          	lw	a5,-400(s0)
    80004b72:	e8845703          	lhu	a4,-376(s0)
    80004b76:	c735                	beqz	a4,80004be2 <exec+0x152>
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
    80004b78:	4481                	li	s1,0
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    80004b7a:	e0043423          	sd	zero,-504(s0)
    if((ph.vaddr % PGSIZE) != 0)
    80004b7e:	6a05                	lui	s4,0x1
    80004b80:	fffa0713          	addi	a4,s4,-1 # fff <_entry-0x7ffff001>
    80004b84:	dee43023          	sd	a4,-544(s0)
loadseg(pagetable_t pagetable, uint64 va, struct inode *ip, uint offset, uint sz)
{
  uint i, n;
  uint64 pa;

  for(i = 0; i < sz; i += PGSIZE){
    80004b88:	6d85                	lui	s11,0x1
    80004b8a:	7d7d                	lui	s10,0xfffff
    80004b8c:	ac1d                	j	80004dc2 <exec+0x332>
    pa = walkaddr(pagetable, va + i);
    if(pa == 0)
      panic("loadseg: address should exist");
    80004b8e:	00004517          	auipc	a0,0x4
    80004b92:	b3a50513          	addi	a0,a0,-1222 # 800086c8 <syscalls+0x280>
    80004b96:	ffffc097          	auipc	ra,0xffffc
    80004b9a:	9a4080e7          	jalr	-1628(ra) # 8000053a <panic>
    if(sz - i < PGSIZE)
      n = sz - i;
    else
      n = PGSIZE;
    if(readi(ip, 0, (uint64)pa, offset+i, n) != n)
    80004b9e:	874a                	mv	a4,s2
    80004ba0:	009c86bb          	addw	a3,s9,s1
    80004ba4:	4581                	li	a1,0
    80004ba6:	8556                	mv	a0,s5
    80004ba8:	fffff097          	auipc	ra,0xfffff
    80004bac:	ca4080e7          	jalr	-860(ra) # 8000384c <readi>
    80004bb0:	2501                	sext.w	a0,a0
    80004bb2:	1aa91863          	bne	s2,a0,80004d62 <exec+0x2d2>
  for(i = 0; i < sz; i += PGSIZE){
    80004bb6:	009d84bb          	addw	s1,s11,s1
    80004bba:	013d09bb          	addw	s3,s10,s3
    80004bbe:	1f74f263          	bgeu	s1,s7,80004da2 <exec+0x312>
    pa = walkaddr(pagetable, va + i);
    80004bc2:	02049593          	slli	a1,s1,0x20
    80004bc6:	9181                	srli	a1,a1,0x20
    80004bc8:	95e2                	add	a1,a1,s8
    80004bca:	855a                	mv	a0,s6
    80004bcc:	ffffc097          	auipc	ra,0xffffc
    80004bd0:	460080e7          	jalr	1120(ra) # 8000102c <walkaddr>
    80004bd4:	862a                	mv	a2,a0
    if(pa == 0)
    80004bd6:	dd45                	beqz	a0,80004b8e <exec+0xfe>
      n = PGSIZE;
    80004bd8:	8952                	mv	s2,s4
    if(sz - i < PGSIZE)
    80004bda:	fd49f2e3          	bgeu	s3,s4,80004b9e <exec+0x10e>
      n = sz - i;
    80004bde:	894e                	mv	s2,s3
    80004be0:	bf7d                	j	80004b9e <exec+0x10e>
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
    80004be2:	4481                	li	s1,0
  iunlockput(ip);
    80004be4:	8556                	mv	a0,s5
    80004be6:	fffff097          	auipc	ra,0xfffff
    80004bea:	c14080e7          	jalr	-1004(ra) # 800037fa <iunlockput>
  end_op();
    80004bee:	fffff097          	auipc	ra,0xfffff
    80004bf2:	404080e7          	jalr	1028(ra) # 80003ff2 <end_op>
  p = myproc();
    80004bf6:	ffffd097          	auipc	ra,0xffffd
    80004bfa:	d7a080e7          	jalr	-646(ra) # 80001970 <myproc>
    80004bfe:	8baa                	mv	s7,a0
  uint64 oldsz = p->sz;
    80004c00:	04853d03          	ld	s10,72(a0)
  sz = PGROUNDUP(sz);
    80004c04:	6785                	lui	a5,0x1
    80004c06:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    80004c08:	97a6                	add	a5,a5,s1
    80004c0a:	777d                	lui	a4,0xfffff
    80004c0c:	8ff9                	and	a5,a5,a4
    80004c0e:	def43c23          	sd	a5,-520(s0)
  if((sz1 = uvmalloc(pagetable, sz, sz + 2*PGSIZE)) == 0)
    80004c12:	6609                	lui	a2,0x2
    80004c14:	963e                	add	a2,a2,a5
    80004c16:	85be                	mv	a1,a5
    80004c18:	855a                	mv	a0,s6
    80004c1a:	ffffc097          	auipc	ra,0xffffc
    80004c1e:	7c6080e7          	jalr	1990(ra) # 800013e0 <uvmalloc>
    80004c22:	8c2a                	mv	s8,a0
  ip = 0;
    80004c24:	4a81                	li	s5,0
  if((sz1 = uvmalloc(pagetable, sz, sz + 2*PGSIZE)) == 0)
    80004c26:	12050e63          	beqz	a0,80004d62 <exec+0x2d2>
  uvmclear(pagetable, sz-2*PGSIZE);
    80004c2a:	75f9                	lui	a1,0xffffe
    80004c2c:	95aa                	add	a1,a1,a0
    80004c2e:	855a                	mv	a0,s6
    80004c30:	ffffd097          	auipc	ra,0xffffd
    80004c34:	9d2080e7          	jalr	-1582(ra) # 80001602 <uvmclear>
  stackbase = sp - PGSIZE;
    80004c38:	7afd                	lui	s5,0xfffff
    80004c3a:	9ae2                	add	s5,s5,s8
  for(argc = 0; argv[argc]; argc++) {
    80004c3c:	df043783          	ld	a5,-528(s0)
    80004c40:	6388                	ld	a0,0(a5)
    80004c42:	c925                	beqz	a0,80004cb2 <exec+0x222>
    80004c44:	e9040993          	addi	s3,s0,-368
    80004c48:	f9040c93          	addi	s9,s0,-112
  sp = sz;
    80004c4c:	8962                	mv	s2,s8
  for(argc = 0; argv[argc]; argc++) {
    80004c4e:	4481                	li	s1,0
    sp -= strlen(argv[argc]) + 1;
    80004c50:	ffffc097          	auipc	ra,0xffffc
    80004c54:	1d2080e7          	jalr	466(ra) # 80000e22 <strlen>
    80004c58:	0015079b          	addiw	a5,a0,1
    80004c5c:	40f907b3          	sub	a5,s2,a5
    sp -= sp % 16; // riscv sp must be 16-byte aligned
    80004c60:	ff07f913          	andi	s2,a5,-16
    if(sp < stackbase)
    80004c64:	13596363          	bltu	s2,s5,80004d8a <exec+0x2fa>
    if(copyout(pagetable, sp, argv[argc], strlen(argv[argc]) + 1) < 0)
    80004c68:	df043d83          	ld	s11,-528(s0)
    80004c6c:	000dba03          	ld	s4,0(s11) # 1000 <_entry-0x7ffff000>
    80004c70:	8552                	mv	a0,s4
    80004c72:	ffffc097          	auipc	ra,0xffffc
    80004c76:	1b0080e7          	jalr	432(ra) # 80000e22 <strlen>
    80004c7a:	0015069b          	addiw	a3,a0,1
    80004c7e:	8652                	mv	a2,s4
    80004c80:	85ca                	mv	a1,s2
    80004c82:	855a                	mv	a0,s6
    80004c84:	ffffd097          	auipc	ra,0xffffd
    80004c88:	9b0080e7          	jalr	-1616(ra) # 80001634 <copyout>
    80004c8c:	10054363          	bltz	a0,80004d92 <exec+0x302>
    ustack[argc] = sp;
    80004c90:	0129b023          	sd	s2,0(s3)
  for(argc = 0; argv[argc]; argc++) {
    80004c94:	0485                	addi	s1,s1,1
    80004c96:	008d8793          	addi	a5,s11,8
    80004c9a:	def43823          	sd	a5,-528(s0)
    80004c9e:	008db503          	ld	a0,8(s11)
    80004ca2:	c911                	beqz	a0,80004cb6 <exec+0x226>
    if(argc >= MAXARG)
    80004ca4:	09a1                	addi	s3,s3,8
    80004ca6:	fb3c95e3          	bne	s9,s3,80004c50 <exec+0x1c0>
  sz = sz1;
    80004caa:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    80004cae:	4a81                	li	s5,0
    80004cb0:	a84d                	j	80004d62 <exec+0x2d2>
  sp = sz;
    80004cb2:	8962                	mv	s2,s8
  for(argc = 0; argv[argc]; argc++) {
    80004cb4:	4481                	li	s1,0
  ustack[argc] = 0;
    80004cb6:	00349793          	slli	a5,s1,0x3
    80004cba:	f9078793          	addi	a5,a5,-112
    80004cbe:	97a2                	add	a5,a5,s0
    80004cc0:	f007b023          	sd	zero,-256(a5)
  sp -= (argc+1) * sizeof(uint64);
    80004cc4:	00148693          	addi	a3,s1,1
    80004cc8:	068e                	slli	a3,a3,0x3
    80004cca:	40d90933          	sub	s2,s2,a3
  sp -= sp % 16;
    80004cce:	ff097913          	andi	s2,s2,-16
  if(sp < stackbase)
    80004cd2:	01597663          	bgeu	s2,s5,80004cde <exec+0x24e>
  sz = sz1;
    80004cd6:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    80004cda:	4a81                	li	s5,0
    80004cdc:	a059                	j	80004d62 <exec+0x2d2>
  if(copyout(pagetable, sp, (char *)ustack, (argc+1)*sizeof(uint64)) < 0)
    80004cde:	e9040613          	addi	a2,s0,-368
    80004ce2:	85ca                	mv	a1,s2
    80004ce4:	855a                	mv	a0,s6
    80004ce6:	ffffd097          	auipc	ra,0xffffd
    80004cea:	94e080e7          	jalr	-1714(ra) # 80001634 <copyout>
    80004cee:	0a054663          	bltz	a0,80004d9a <exec+0x30a>
  p->trapframe->a1 = sp;
    80004cf2:	058bb783          	ld	a5,88(s7)
    80004cf6:	0727bc23          	sd	s2,120(a5)
  for(last=s=path; *s; s++)
    80004cfa:	de843783          	ld	a5,-536(s0)
    80004cfe:	0007c703          	lbu	a4,0(a5)
    80004d02:	cf11                	beqz	a4,80004d1e <exec+0x28e>
    80004d04:	0785                	addi	a5,a5,1
    if(*s == '/')
    80004d06:	02f00693          	li	a3,47
    80004d0a:	a039                	j	80004d18 <exec+0x288>
      last = s+1;
    80004d0c:	def43423          	sd	a5,-536(s0)
  for(last=s=path; *s; s++)
    80004d10:	0785                	addi	a5,a5,1
    80004d12:	fff7c703          	lbu	a4,-1(a5)
    80004d16:	c701                	beqz	a4,80004d1e <exec+0x28e>
    if(*s == '/')
    80004d18:	fed71ce3          	bne	a4,a3,80004d10 <exec+0x280>
    80004d1c:	bfc5                	j	80004d0c <exec+0x27c>
  safestrcpy(p->name, last, sizeof(p->name));
    80004d1e:	4641                	li	a2,16
    80004d20:	de843583          	ld	a1,-536(s0)
    80004d24:	158b8513          	addi	a0,s7,344
    80004d28:	ffffc097          	auipc	ra,0xffffc
    80004d2c:	0c8080e7          	jalr	200(ra) # 80000df0 <safestrcpy>
  oldpagetable = p->pagetable;
    80004d30:	050bb503          	ld	a0,80(s7)
  p->pagetable = pagetable;
    80004d34:	056bb823          	sd	s6,80(s7)
  p->sz = sz;
    80004d38:	058bb423          	sd	s8,72(s7)
  p->trapframe->epc = elf.entry;  // initial program counter = main
    80004d3c:	058bb783          	ld	a5,88(s7)
    80004d40:	e6843703          	ld	a4,-408(s0)
    80004d44:	ef98                	sd	a4,24(a5)
  p->trapframe->sp = sp; // initial stack pointer
    80004d46:	058bb783          	ld	a5,88(s7)
    80004d4a:	0327b823          	sd	s2,48(a5)
  proc_freepagetable(oldpagetable, oldsz);
    80004d4e:	85ea                	mv	a1,s10
    80004d50:	ffffd097          	auipc	ra,0xffffd
    80004d54:	d80080e7          	jalr	-640(ra) # 80001ad0 <proc_freepagetable>
  return argc; // this ends up in a0, the first argument to main(argc, argv)
    80004d58:	0004851b          	sext.w	a0,s1
    80004d5c:	bbc1                	j	80004b2c <exec+0x9c>
    80004d5e:	de943c23          	sd	s1,-520(s0)
    proc_freepagetable(pagetable, sz);
    80004d62:	df843583          	ld	a1,-520(s0)
    80004d66:	855a                	mv	a0,s6
    80004d68:	ffffd097          	auipc	ra,0xffffd
    80004d6c:	d68080e7          	jalr	-664(ra) # 80001ad0 <proc_freepagetable>
  if(ip){
    80004d70:	da0a94e3          	bnez	s5,80004b18 <exec+0x88>
  return -1;
    80004d74:	557d                	li	a0,-1
    80004d76:	bb5d                	j	80004b2c <exec+0x9c>
    80004d78:	de943c23          	sd	s1,-520(s0)
    80004d7c:	b7dd                	j	80004d62 <exec+0x2d2>
    80004d7e:	de943c23          	sd	s1,-520(s0)
    80004d82:	b7c5                	j	80004d62 <exec+0x2d2>
    80004d84:	de943c23          	sd	s1,-520(s0)
    80004d88:	bfe9                	j	80004d62 <exec+0x2d2>
  sz = sz1;
    80004d8a:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    80004d8e:	4a81                	li	s5,0
    80004d90:	bfc9                	j	80004d62 <exec+0x2d2>
  sz = sz1;
    80004d92:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    80004d96:	4a81                	li	s5,0
    80004d98:	b7e9                	j	80004d62 <exec+0x2d2>
  sz = sz1;
    80004d9a:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    80004d9e:	4a81                	li	s5,0
    80004da0:	b7c9                	j	80004d62 <exec+0x2d2>
    if((sz1 = uvmalloc(pagetable, sz, ph.vaddr + ph.memsz)) == 0)
    80004da2:	df843483          	ld	s1,-520(s0)
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    80004da6:	e0843783          	ld	a5,-504(s0)
    80004daa:	0017869b          	addiw	a3,a5,1
    80004dae:	e0d43423          	sd	a3,-504(s0)
    80004db2:	e0043783          	ld	a5,-512(s0)
    80004db6:	0387879b          	addiw	a5,a5,56
    80004dba:	e8845703          	lhu	a4,-376(s0)
    80004dbe:	e2e6d3e3          	bge	a3,a4,80004be4 <exec+0x154>
    if(readi(ip, 0, (uint64)&ph, off, sizeof(ph)) != sizeof(ph))
    80004dc2:	2781                	sext.w	a5,a5
    80004dc4:	e0f43023          	sd	a5,-512(s0)
    80004dc8:	03800713          	li	a4,56
    80004dcc:	86be                	mv	a3,a5
    80004dce:	e1840613          	addi	a2,s0,-488
    80004dd2:	4581                	li	a1,0
    80004dd4:	8556                	mv	a0,s5
    80004dd6:	fffff097          	auipc	ra,0xfffff
    80004dda:	a76080e7          	jalr	-1418(ra) # 8000384c <readi>
    80004dde:	03800793          	li	a5,56
    80004de2:	f6f51ee3          	bne	a0,a5,80004d5e <exec+0x2ce>
    if(ph.type != ELF_PROG_LOAD)
    80004de6:	e1842783          	lw	a5,-488(s0)
    80004dea:	4705                	li	a4,1
    80004dec:	fae79de3          	bne	a5,a4,80004da6 <exec+0x316>
    if(ph.memsz < ph.filesz)
    80004df0:	e4043603          	ld	a2,-448(s0)
    80004df4:	e3843783          	ld	a5,-456(s0)
    80004df8:	f8f660e3          	bltu	a2,a5,80004d78 <exec+0x2e8>
    if(ph.vaddr + ph.memsz < ph.vaddr)
    80004dfc:	e2843783          	ld	a5,-472(s0)
    80004e00:	963e                	add	a2,a2,a5
    80004e02:	f6f66ee3          	bltu	a2,a5,80004d7e <exec+0x2ee>
    if((sz1 = uvmalloc(pagetable, sz, ph.vaddr + ph.memsz)) == 0)
    80004e06:	85a6                	mv	a1,s1
    80004e08:	855a                	mv	a0,s6
    80004e0a:	ffffc097          	auipc	ra,0xffffc
    80004e0e:	5d6080e7          	jalr	1494(ra) # 800013e0 <uvmalloc>
    80004e12:	dea43c23          	sd	a0,-520(s0)
    80004e16:	d53d                	beqz	a0,80004d84 <exec+0x2f4>
    if((ph.vaddr % PGSIZE) != 0)
    80004e18:	e2843c03          	ld	s8,-472(s0)
    80004e1c:	de043783          	ld	a5,-544(s0)
    80004e20:	00fc77b3          	and	a5,s8,a5
    80004e24:	ff9d                	bnez	a5,80004d62 <exec+0x2d2>
    if(loadseg(pagetable, ph.vaddr, ip, ph.off, ph.filesz) < 0)
    80004e26:	e2042c83          	lw	s9,-480(s0)
    80004e2a:	e3842b83          	lw	s7,-456(s0)
  for(i = 0; i < sz; i += PGSIZE){
    80004e2e:	f60b8ae3          	beqz	s7,80004da2 <exec+0x312>
    80004e32:	89de                	mv	s3,s7
    80004e34:	4481                	li	s1,0
    80004e36:	b371                	j	80004bc2 <exec+0x132>

0000000080004e38 <argfd>:

// Fetch the nth word-sized system call argument as a file descriptor
// and return both the descriptor and the corresponding struct file.
static int
argfd(int n, int *pfd, struct file **pf)
{
    80004e38:	7179                	addi	sp,sp,-48
    80004e3a:	f406                	sd	ra,40(sp)
    80004e3c:	f022                	sd	s0,32(sp)
    80004e3e:	ec26                	sd	s1,24(sp)
    80004e40:	e84a                	sd	s2,16(sp)
    80004e42:	1800                	addi	s0,sp,48
    80004e44:	892e                	mv	s2,a1
    80004e46:	84b2                	mv	s1,a2
  int fd;
  struct file *f;

  if(argint(n, &fd) < 0)
    80004e48:	fdc40593          	addi	a1,s0,-36
    80004e4c:	ffffe097          	auipc	ra,0xffffe
    80004e50:	bda080e7          	jalr	-1062(ra) # 80002a26 <argint>
    80004e54:	04054063          	bltz	a0,80004e94 <argfd+0x5c>
    return -1;
  if(fd < 0 || fd >= NOFILE || (f=myproc()->ofile[fd]) == 0)
    80004e58:	fdc42703          	lw	a4,-36(s0)
    80004e5c:	47bd                	li	a5,15
    80004e5e:	02e7ed63          	bltu	a5,a4,80004e98 <argfd+0x60>
    80004e62:	ffffd097          	auipc	ra,0xffffd
    80004e66:	b0e080e7          	jalr	-1266(ra) # 80001970 <myproc>
    80004e6a:	fdc42703          	lw	a4,-36(s0)
    80004e6e:	01a70793          	addi	a5,a4,26 # fffffffffffff01a <end+0xffffffff7ffd901a>
    80004e72:	078e                	slli	a5,a5,0x3
    80004e74:	953e                	add	a0,a0,a5
    80004e76:	611c                	ld	a5,0(a0)
    80004e78:	c395                	beqz	a5,80004e9c <argfd+0x64>
    return -1;
  if(pfd)
    80004e7a:	00090463          	beqz	s2,80004e82 <argfd+0x4a>
    *pfd = fd;
    80004e7e:	00e92023          	sw	a4,0(s2)
  if(pf)
    *pf = f;
  return 0;
    80004e82:	4501                	li	a0,0
  if(pf)
    80004e84:	c091                	beqz	s1,80004e88 <argfd+0x50>
    *pf = f;
    80004e86:	e09c                	sd	a5,0(s1)
}
    80004e88:	70a2                	ld	ra,40(sp)
    80004e8a:	7402                	ld	s0,32(sp)
    80004e8c:	64e2                	ld	s1,24(sp)
    80004e8e:	6942                	ld	s2,16(sp)
    80004e90:	6145                	addi	sp,sp,48
    80004e92:	8082                	ret
    return -1;
    80004e94:	557d                	li	a0,-1
    80004e96:	bfcd                	j	80004e88 <argfd+0x50>
    return -1;
    80004e98:	557d                	li	a0,-1
    80004e9a:	b7fd                	j	80004e88 <argfd+0x50>
    80004e9c:	557d                	li	a0,-1
    80004e9e:	b7ed                	j	80004e88 <argfd+0x50>

0000000080004ea0 <fdalloc>:

// Allocate a file descriptor for the given file.
// Takes over file reference from caller on success.
static int
fdalloc(struct file *f)
{
    80004ea0:	1101                	addi	sp,sp,-32
    80004ea2:	ec06                	sd	ra,24(sp)
    80004ea4:	e822                	sd	s0,16(sp)
    80004ea6:	e426                	sd	s1,8(sp)
    80004ea8:	1000                	addi	s0,sp,32
    80004eaa:	84aa                	mv	s1,a0
  int fd;
  struct proc *p = myproc();
    80004eac:	ffffd097          	auipc	ra,0xffffd
    80004eb0:	ac4080e7          	jalr	-1340(ra) # 80001970 <myproc>
    80004eb4:	862a                	mv	a2,a0

  for(fd = 0; fd < NOFILE; fd++){
    80004eb6:	0d050793          	addi	a5,a0,208
    80004eba:	4501                	li	a0,0
    80004ebc:	46c1                	li	a3,16
    if(p->ofile[fd] == 0){
    80004ebe:	6398                	ld	a4,0(a5)
    80004ec0:	cb19                	beqz	a4,80004ed6 <fdalloc+0x36>
  for(fd = 0; fd < NOFILE; fd++){
    80004ec2:	2505                	addiw	a0,a0,1
    80004ec4:	07a1                	addi	a5,a5,8
    80004ec6:	fed51ce3          	bne	a0,a3,80004ebe <fdalloc+0x1e>
      p->ofile[fd] = f;
      return fd;
    }
  }
  return -1;
    80004eca:	557d                	li	a0,-1
}
    80004ecc:	60e2                	ld	ra,24(sp)
    80004ece:	6442                	ld	s0,16(sp)
    80004ed0:	64a2                	ld	s1,8(sp)
    80004ed2:	6105                	addi	sp,sp,32
    80004ed4:	8082                	ret
      p->ofile[fd] = f;
    80004ed6:	01a50793          	addi	a5,a0,26
    80004eda:	078e                	slli	a5,a5,0x3
    80004edc:	963e                	add	a2,a2,a5
    80004ede:	e204                	sd	s1,0(a2)
      return fd;
    80004ee0:	b7f5                	j	80004ecc <fdalloc+0x2c>

0000000080004ee2 <create>:
  return -1;
}

static struct inode*
create(char *path, short type, short major, short minor)
{
    80004ee2:	715d                	addi	sp,sp,-80
    80004ee4:	e486                	sd	ra,72(sp)
    80004ee6:	e0a2                	sd	s0,64(sp)
    80004ee8:	fc26                	sd	s1,56(sp)
    80004eea:	f84a                	sd	s2,48(sp)
    80004eec:	f44e                	sd	s3,40(sp)
    80004eee:	f052                	sd	s4,32(sp)
    80004ef0:	ec56                	sd	s5,24(sp)
    80004ef2:	0880                	addi	s0,sp,80
    80004ef4:	89ae                	mv	s3,a1
    80004ef6:	8ab2                	mv	s5,a2
    80004ef8:	8a36                	mv	s4,a3
  struct inode *ip, *dp;
  char name[DIRSIZ];

  if((dp = nameiparent(path, name)) == 0)
    80004efa:	fb040593          	addi	a1,s0,-80
    80004efe:	fffff097          	auipc	ra,0xfffff
    80004f02:	e74080e7          	jalr	-396(ra) # 80003d72 <nameiparent>
    80004f06:	892a                	mv	s2,a0
    80004f08:	12050e63          	beqz	a0,80005044 <create+0x162>
    return 0;

  ilock(dp);
    80004f0c:	ffffe097          	auipc	ra,0xffffe
    80004f10:	68c080e7          	jalr	1676(ra) # 80003598 <ilock>

  if((ip = dirlookup(dp, name, 0)) != 0){
    80004f14:	4601                	li	a2,0
    80004f16:	fb040593          	addi	a1,s0,-80
    80004f1a:	854a                	mv	a0,s2
    80004f1c:	fffff097          	auipc	ra,0xfffff
    80004f20:	b60080e7          	jalr	-1184(ra) # 80003a7c <dirlookup>
    80004f24:	84aa                	mv	s1,a0
    80004f26:	c921                	beqz	a0,80004f76 <create+0x94>
    iunlockput(dp);
    80004f28:	854a                	mv	a0,s2
    80004f2a:	fffff097          	auipc	ra,0xfffff
    80004f2e:	8d0080e7          	jalr	-1840(ra) # 800037fa <iunlockput>
    ilock(ip);
    80004f32:	8526                	mv	a0,s1
    80004f34:	ffffe097          	auipc	ra,0xffffe
    80004f38:	664080e7          	jalr	1636(ra) # 80003598 <ilock>
    if(type == T_FILE && (ip->type == T_FILE || ip->type == T_DEVICE))
    80004f3c:	2981                	sext.w	s3,s3
    80004f3e:	4789                	li	a5,2
    80004f40:	02f99463          	bne	s3,a5,80004f68 <create+0x86>
    80004f44:	0444d783          	lhu	a5,68(s1)
    80004f48:	37f9                	addiw	a5,a5,-2
    80004f4a:	17c2                	slli	a5,a5,0x30
    80004f4c:	93c1                	srli	a5,a5,0x30
    80004f4e:	4705                	li	a4,1
    80004f50:	00f76c63          	bltu	a4,a5,80004f68 <create+0x86>
    panic("create: dirlink");

  iunlockput(dp);

  return ip;
}
    80004f54:	8526                	mv	a0,s1
    80004f56:	60a6                	ld	ra,72(sp)
    80004f58:	6406                	ld	s0,64(sp)
    80004f5a:	74e2                	ld	s1,56(sp)
    80004f5c:	7942                	ld	s2,48(sp)
    80004f5e:	79a2                	ld	s3,40(sp)
    80004f60:	7a02                	ld	s4,32(sp)
    80004f62:	6ae2                	ld	s5,24(sp)
    80004f64:	6161                	addi	sp,sp,80
    80004f66:	8082                	ret
    iunlockput(ip);
    80004f68:	8526                	mv	a0,s1
    80004f6a:	fffff097          	auipc	ra,0xfffff
    80004f6e:	890080e7          	jalr	-1904(ra) # 800037fa <iunlockput>
    return 0;
    80004f72:	4481                	li	s1,0
    80004f74:	b7c5                	j	80004f54 <create+0x72>
  if((ip = ialloc(dp->dev, type)) == 0)
    80004f76:	85ce                	mv	a1,s3
    80004f78:	00092503          	lw	a0,0(s2)
    80004f7c:	ffffe097          	auipc	ra,0xffffe
    80004f80:	482080e7          	jalr	1154(ra) # 800033fe <ialloc>
    80004f84:	84aa                	mv	s1,a0
    80004f86:	c521                	beqz	a0,80004fce <create+0xec>
  ilock(ip);
    80004f88:	ffffe097          	auipc	ra,0xffffe
    80004f8c:	610080e7          	jalr	1552(ra) # 80003598 <ilock>
  ip->major = major;
    80004f90:	05549323          	sh	s5,70(s1)
  ip->minor = minor;
    80004f94:	05449423          	sh	s4,72(s1)
  ip->nlink = 1;
    80004f98:	4a05                	li	s4,1
    80004f9a:	05449523          	sh	s4,74(s1)
  iupdate(ip);
    80004f9e:	8526                	mv	a0,s1
    80004fa0:	ffffe097          	auipc	ra,0xffffe
    80004fa4:	52c080e7          	jalr	1324(ra) # 800034cc <iupdate>
  if(type == T_DIR){  // Create . and .. entries.
    80004fa8:	2981                	sext.w	s3,s3
    80004faa:	03498a63          	beq	s3,s4,80004fde <create+0xfc>
  if(dirlink(dp, name, ip->inum) < 0)
    80004fae:	40d0                	lw	a2,4(s1)
    80004fb0:	fb040593          	addi	a1,s0,-80
    80004fb4:	854a                	mv	a0,s2
    80004fb6:	fffff097          	auipc	ra,0xfffff
    80004fba:	cdc080e7          	jalr	-804(ra) # 80003c92 <dirlink>
    80004fbe:	06054b63          	bltz	a0,80005034 <create+0x152>
  iunlockput(dp);
    80004fc2:	854a                	mv	a0,s2
    80004fc4:	fffff097          	auipc	ra,0xfffff
    80004fc8:	836080e7          	jalr	-1994(ra) # 800037fa <iunlockput>
  return ip;
    80004fcc:	b761                	j	80004f54 <create+0x72>
    panic("create: ialloc");
    80004fce:	00003517          	auipc	a0,0x3
    80004fd2:	71a50513          	addi	a0,a0,1818 # 800086e8 <syscalls+0x2a0>
    80004fd6:	ffffb097          	auipc	ra,0xffffb
    80004fda:	564080e7          	jalr	1380(ra) # 8000053a <panic>
    dp->nlink++;  // for ".."
    80004fde:	04a95783          	lhu	a5,74(s2)
    80004fe2:	2785                	addiw	a5,a5,1
    80004fe4:	04f91523          	sh	a5,74(s2)
    iupdate(dp);
    80004fe8:	854a                	mv	a0,s2
    80004fea:	ffffe097          	auipc	ra,0xffffe
    80004fee:	4e2080e7          	jalr	1250(ra) # 800034cc <iupdate>
    if(dirlink(ip, ".", ip->inum) < 0 || dirlink(ip, "..", dp->inum) < 0)
    80004ff2:	40d0                	lw	a2,4(s1)
    80004ff4:	00003597          	auipc	a1,0x3
    80004ff8:	70458593          	addi	a1,a1,1796 # 800086f8 <syscalls+0x2b0>
    80004ffc:	8526                	mv	a0,s1
    80004ffe:	fffff097          	auipc	ra,0xfffff
    80005002:	c94080e7          	jalr	-876(ra) # 80003c92 <dirlink>
    80005006:	00054f63          	bltz	a0,80005024 <create+0x142>
    8000500a:	00492603          	lw	a2,4(s2)
    8000500e:	00003597          	auipc	a1,0x3
    80005012:	6f258593          	addi	a1,a1,1778 # 80008700 <syscalls+0x2b8>
    80005016:	8526                	mv	a0,s1
    80005018:	fffff097          	auipc	ra,0xfffff
    8000501c:	c7a080e7          	jalr	-902(ra) # 80003c92 <dirlink>
    80005020:	f80557e3          	bgez	a0,80004fae <create+0xcc>
      panic("create dots");
    80005024:	00003517          	auipc	a0,0x3
    80005028:	6e450513          	addi	a0,a0,1764 # 80008708 <syscalls+0x2c0>
    8000502c:	ffffb097          	auipc	ra,0xffffb
    80005030:	50e080e7          	jalr	1294(ra) # 8000053a <panic>
    panic("create: dirlink");
    80005034:	00003517          	auipc	a0,0x3
    80005038:	6e450513          	addi	a0,a0,1764 # 80008718 <syscalls+0x2d0>
    8000503c:	ffffb097          	auipc	ra,0xffffb
    80005040:	4fe080e7          	jalr	1278(ra) # 8000053a <panic>
    return 0;
    80005044:	84aa                	mv	s1,a0
    80005046:	b739                	j	80004f54 <create+0x72>

0000000080005048 <sys_dup>:
{
    80005048:	7179                	addi	sp,sp,-48
    8000504a:	f406                	sd	ra,40(sp)
    8000504c:	f022                	sd	s0,32(sp)
    8000504e:	ec26                	sd	s1,24(sp)
    80005050:	e84a                	sd	s2,16(sp)
    80005052:	1800                	addi	s0,sp,48
  if(argfd(0, 0, &f) < 0)
    80005054:	fd840613          	addi	a2,s0,-40
    80005058:	4581                	li	a1,0
    8000505a:	4501                	li	a0,0
    8000505c:	00000097          	auipc	ra,0x0
    80005060:	ddc080e7          	jalr	-548(ra) # 80004e38 <argfd>
    return -1;
    80005064:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0)
    80005066:	02054363          	bltz	a0,8000508c <sys_dup+0x44>
  if((fd=fdalloc(f)) < 0)
    8000506a:	fd843903          	ld	s2,-40(s0)
    8000506e:	854a                	mv	a0,s2
    80005070:	00000097          	auipc	ra,0x0
    80005074:	e30080e7          	jalr	-464(ra) # 80004ea0 <fdalloc>
    80005078:	84aa                	mv	s1,a0
    return -1;
    8000507a:	57fd                	li	a5,-1
  if((fd=fdalloc(f)) < 0)
    8000507c:	00054863          	bltz	a0,8000508c <sys_dup+0x44>
  filedup(f);
    80005080:	854a                	mv	a0,s2
    80005082:	fffff097          	auipc	ra,0xfffff
    80005086:	368080e7          	jalr	872(ra) # 800043ea <filedup>
  return fd;
    8000508a:	87a6                	mv	a5,s1
}
    8000508c:	853e                	mv	a0,a5
    8000508e:	70a2                	ld	ra,40(sp)
    80005090:	7402                	ld	s0,32(sp)
    80005092:	64e2                	ld	s1,24(sp)
    80005094:	6942                	ld	s2,16(sp)
    80005096:	6145                	addi	sp,sp,48
    80005098:	8082                	ret

000000008000509a <sys_read>:
{
    8000509a:	7179                	addi	sp,sp,-48
    8000509c:	f406                	sd	ra,40(sp)
    8000509e:	f022                	sd	s0,32(sp)
    800050a0:	1800                	addi	s0,sp,48
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    800050a2:	fe840613          	addi	a2,s0,-24
    800050a6:	4581                	li	a1,0
    800050a8:	4501                	li	a0,0
    800050aa:	00000097          	auipc	ra,0x0
    800050ae:	d8e080e7          	jalr	-626(ra) # 80004e38 <argfd>
    return -1;
    800050b2:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    800050b4:	04054163          	bltz	a0,800050f6 <sys_read+0x5c>
    800050b8:	fe440593          	addi	a1,s0,-28
    800050bc:	4509                	li	a0,2
    800050be:	ffffe097          	auipc	ra,0xffffe
    800050c2:	968080e7          	jalr	-1688(ra) # 80002a26 <argint>
    return -1;
    800050c6:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    800050c8:	02054763          	bltz	a0,800050f6 <sys_read+0x5c>
    800050cc:	fd840593          	addi	a1,s0,-40
    800050d0:	4505                	li	a0,1
    800050d2:	ffffe097          	auipc	ra,0xffffe
    800050d6:	976080e7          	jalr	-1674(ra) # 80002a48 <argaddr>
    return -1;
    800050da:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    800050dc:	00054d63          	bltz	a0,800050f6 <sys_read+0x5c>
  return fileread(f, p, n);
    800050e0:	fe442603          	lw	a2,-28(s0)
    800050e4:	fd843583          	ld	a1,-40(s0)
    800050e8:	fe843503          	ld	a0,-24(s0)
    800050ec:	fffff097          	auipc	ra,0xfffff
    800050f0:	48a080e7          	jalr	1162(ra) # 80004576 <fileread>
    800050f4:	87aa                	mv	a5,a0
}
    800050f6:	853e                	mv	a0,a5
    800050f8:	70a2                	ld	ra,40(sp)
    800050fa:	7402                	ld	s0,32(sp)
    800050fc:	6145                	addi	sp,sp,48
    800050fe:	8082                	ret

0000000080005100 <sys_write>:
{
    80005100:	7179                	addi	sp,sp,-48
    80005102:	f406                	sd	ra,40(sp)
    80005104:	f022                	sd	s0,32(sp)
    80005106:	1800                	addi	s0,sp,48
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    80005108:	fe840613          	addi	a2,s0,-24
    8000510c:	4581                	li	a1,0
    8000510e:	4501                	li	a0,0
    80005110:	00000097          	auipc	ra,0x0
    80005114:	d28080e7          	jalr	-728(ra) # 80004e38 <argfd>
    return -1;
    80005118:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    8000511a:	04054163          	bltz	a0,8000515c <sys_write+0x5c>
    8000511e:	fe440593          	addi	a1,s0,-28
    80005122:	4509                	li	a0,2
    80005124:	ffffe097          	auipc	ra,0xffffe
    80005128:	902080e7          	jalr	-1790(ra) # 80002a26 <argint>
    return -1;
    8000512c:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    8000512e:	02054763          	bltz	a0,8000515c <sys_write+0x5c>
    80005132:	fd840593          	addi	a1,s0,-40
    80005136:	4505                	li	a0,1
    80005138:	ffffe097          	auipc	ra,0xffffe
    8000513c:	910080e7          	jalr	-1776(ra) # 80002a48 <argaddr>
    return -1;
    80005140:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argint(2, &n) < 0 || argaddr(1, &p) < 0)
    80005142:	00054d63          	bltz	a0,8000515c <sys_write+0x5c>
  return filewrite(f, p, n);
    80005146:	fe442603          	lw	a2,-28(s0)
    8000514a:	fd843583          	ld	a1,-40(s0)
    8000514e:	fe843503          	ld	a0,-24(s0)
    80005152:	fffff097          	auipc	ra,0xfffff
    80005156:	4e6080e7          	jalr	1254(ra) # 80004638 <filewrite>
    8000515a:	87aa                	mv	a5,a0
}
    8000515c:	853e                	mv	a0,a5
    8000515e:	70a2                	ld	ra,40(sp)
    80005160:	7402                	ld	s0,32(sp)
    80005162:	6145                	addi	sp,sp,48
    80005164:	8082                	ret

0000000080005166 <sys_close>:
{
    80005166:	1101                	addi	sp,sp,-32
    80005168:	ec06                	sd	ra,24(sp)
    8000516a:	e822                	sd	s0,16(sp)
    8000516c:	1000                	addi	s0,sp,32
  if(argfd(0, &fd, &f) < 0)
    8000516e:	fe040613          	addi	a2,s0,-32
    80005172:	fec40593          	addi	a1,s0,-20
    80005176:	4501                	li	a0,0
    80005178:	00000097          	auipc	ra,0x0
    8000517c:	cc0080e7          	jalr	-832(ra) # 80004e38 <argfd>
    return -1;
    80005180:	57fd                	li	a5,-1
  if(argfd(0, &fd, &f) < 0)
    80005182:	02054463          	bltz	a0,800051aa <sys_close+0x44>
  myproc()->ofile[fd] = 0;
    80005186:	ffffc097          	auipc	ra,0xffffc
    8000518a:	7ea080e7          	jalr	2026(ra) # 80001970 <myproc>
    8000518e:	fec42783          	lw	a5,-20(s0)
    80005192:	07e9                	addi	a5,a5,26
    80005194:	078e                	slli	a5,a5,0x3
    80005196:	953e                	add	a0,a0,a5
    80005198:	00053023          	sd	zero,0(a0)
  fileclose(f);
    8000519c:	fe043503          	ld	a0,-32(s0)
    800051a0:	fffff097          	auipc	ra,0xfffff
    800051a4:	29c080e7          	jalr	668(ra) # 8000443c <fileclose>
  return 0;
    800051a8:	4781                	li	a5,0
}
    800051aa:	853e                	mv	a0,a5
    800051ac:	60e2                	ld	ra,24(sp)
    800051ae:	6442                	ld	s0,16(sp)
    800051b0:	6105                	addi	sp,sp,32
    800051b2:	8082                	ret

00000000800051b4 <sys_fstat>:
{
    800051b4:	1101                	addi	sp,sp,-32
    800051b6:	ec06                	sd	ra,24(sp)
    800051b8:	e822                	sd	s0,16(sp)
    800051ba:	1000                	addi	s0,sp,32
  if(argfd(0, 0, &f) < 0 || argaddr(1, &st) < 0)
    800051bc:	fe840613          	addi	a2,s0,-24
    800051c0:	4581                	li	a1,0
    800051c2:	4501                	li	a0,0
    800051c4:	00000097          	auipc	ra,0x0
    800051c8:	c74080e7          	jalr	-908(ra) # 80004e38 <argfd>
    return -1;
    800051cc:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argaddr(1, &st) < 0)
    800051ce:	02054563          	bltz	a0,800051f8 <sys_fstat+0x44>
    800051d2:	fe040593          	addi	a1,s0,-32
    800051d6:	4505                	li	a0,1
    800051d8:	ffffe097          	auipc	ra,0xffffe
    800051dc:	870080e7          	jalr	-1936(ra) # 80002a48 <argaddr>
    return -1;
    800051e0:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0 || argaddr(1, &st) < 0)
    800051e2:	00054b63          	bltz	a0,800051f8 <sys_fstat+0x44>
  return filestat(f, st);
    800051e6:	fe043583          	ld	a1,-32(s0)
    800051ea:	fe843503          	ld	a0,-24(s0)
    800051ee:	fffff097          	auipc	ra,0xfffff
    800051f2:	316080e7          	jalr	790(ra) # 80004504 <filestat>
    800051f6:	87aa                	mv	a5,a0
}
    800051f8:	853e                	mv	a0,a5
    800051fa:	60e2                	ld	ra,24(sp)
    800051fc:	6442                	ld	s0,16(sp)
    800051fe:	6105                	addi	sp,sp,32
    80005200:	8082                	ret

0000000080005202 <sys_link>:
{
    80005202:	7169                	addi	sp,sp,-304
    80005204:	f606                	sd	ra,296(sp)
    80005206:	f222                	sd	s0,288(sp)
    80005208:	ee26                	sd	s1,280(sp)
    8000520a:	ea4a                	sd	s2,272(sp)
    8000520c:	1a00                	addi	s0,sp,304
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    8000520e:	08000613          	li	a2,128
    80005212:	ed040593          	addi	a1,s0,-304
    80005216:	4501                	li	a0,0
    80005218:	ffffe097          	auipc	ra,0xffffe
    8000521c:	852080e7          	jalr	-1966(ra) # 80002a6a <argstr>
    return -1;
    80005220:	57fd                	li	a5,-1
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    80005222:	10054e63          	bltz	a0,8000533e <sys_link+0x13c>
    80005226:	08000613          	li	a2,128
    8000522a:	f5040593          	addi	a1,s0,-176
    8000522e:	4505                	li	a0,1
    80005230:	ffffe097          	auipc	ra,0xffffe
    80005234:	83a080e7          	jalr	-1990(ra) # 80002a6a <argstr>
    return -1;
    80005238:	57fd                	li	a5,-1
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    8000523a:	10054263          	bltz	a0,8000533e <sys_link+0x13c>
  begin_op();
    8000523e:	fffff097          	auipc	ra,0xfffff
    80005242:	d36080e7          	jalr	-714(ra) # 80003f74 <begin_op>
  if((ip = namei(old)) == 0){
    80005246:	ed040513          	addi	a0,s0,-304
    8000524a:	fffff097          	auipc	ra,0xfffff
    8000524e:	b0a080e7          	jalr	-1270(ra) # 80003d54 <namei>
    80005252:	84aa                	mv	s1,a0
    80005254:	c551                	beqz	a0,800052e0 <sys_link+0xde>
  ilock(ip);
    80005256:	ffffe097          	auipc	ra,0xffffe
    8000525a:	342080e7          	jalr	834(ra) # 80003598 <ilock>
  if(ip->type == T_DIR){
    8000525e:	04449703          	lh	a4,68(s1)
    80005262:	4785                	li	a5,1
    80005264:	08f70463          	beq	a4,a5,800052ec <sys_link+0xea>
  ip->nlink++;
    80005268:	04a4d783          	lhu	a5,74(s1)
    8000526c:	2785                	addiw	a5,a5,1
    8000526e:	04f49523          	sh	a5,74(s1)
  iupdate(ip);
    80005272:	8526                	mv	a0,s1
    80005274:	ffffe097          	auipc	ra,0xffffe
    80005278:	258080e7          	jalr	600(ra) # 800034cc <iupdate>
  iunlock(ip);
    8000527c:	8526                	mv	a0,s1
    8000527e:	ffffe097          	auipc	ra,0xffffe
    80005282:	3dc080e7          	jalr	988(ra) # 8000365a <iunlock>
  if((dp = nameiparent(new, name)) == 0)
    80005286:	fd040593          	addi	a1,s0,-48
    8000528a:	f5040513          	addi	a0,s0,-176
    8000528e:	fffff097          	auipc	ra,0xfffff
    80005292:	ae4080e7          	jalr	-1308(ra) # 80003d72 <nameiparent>
    80005296:	892a                	mv	s2,a0
    80005298:	c935                	beqz	a0,8000530c <sys_link+0x10a>
  ilock(dp);
    8000529a:	ffffe097          	auipc	ra,0xffffe
    8000529e:	2fe080e7          	jalr	766(ra) # 80003598 <ilock>
  if(dp->dev != ip->dev || dirlink(dp, name, ip->inum) < 0){
    800052a2:	00092703          	lw	a4,0(s2)
    800052a6:	409c                	lw	a5,0(s1)
    800052a8:	04f71d63          	bne	a4,a5,80005302 <sys_link+0x100>
    800052ac:	40d0                	lw	a2,4(s1)
    800052ae:	fd040593          	addi	a1,s0,-48
    800052b2:	854a                	mv	a0,s2
    800052b4:	fffff097          	auipc	ra,0xfffff
    800052b8:	9de080e7          	jalr	-1570(ra) # 80003c92 <dirlink>
    800052bc:	04054363          	bltz	a0,80005302 <sys_link+0x100>
  iunlockput(dp);
    800052c0:	854a                	mv	a0,s2
    800052c2:	ffffe097          	auipc	ra,0xffffe
    800052c6:	538080e7          	jalr	1336(ra) # 800037fa <iunlockput>
  iput(ip);
    800052ca:	8526                	mv	a0,s1
    800052cc:	ffffe097          	auipc	ra,0xffffe
    800052d0:	486080e7          	jalr	1158(ra) # 80003752 <iput>
  end_op();
    800052d4:	fffff097          	auipc	ra,0xfffff
    800052d8:	d1e080e7          	jalr	-738(ra) # 80003ff2 <end_op>
  return 0;
    800052dc:	4781                	li	a5,0
    800052de:	a085                	j	8000533e <sys_link+0x13c>
    end_op();
    800052e0:	fffff097          	auipc	ra,0xfffff
    800052e4:	d12080e7          	jalr	-750(ra) # 80003ff2 <end_op>
    return -1;
    800052e8:	57fd                	li	a5,-1
    800052ea:	a891                	j	8000533e <sys_link+0x13c>
    iunlockput(ip);
    800052ec:	8526                	mv	a0,s1
    800052ee:	ffffe097          	auipc	ra,0xffffe
    800052f2:	50c080e7          	jalr	1292(ra) # 800037fa <iunlockput>
    end_op();
    800052f6:	fffff097          	auipc	ra,0xfffff
    800052fa:	cfc080e7          	jalr	-772(ra) # 80003ff2 <end_op>
    return -1;
    800052fe:	57fd                	li	a5,-1
    80005300:	a83d                	j	8000533e <sys_link+0x13c>
    iunlockput(dp);
    80005302:	854a                	mv	a0,s2
    80005304:	ffffe097          	auipc	ra,0xffffe
    80005308:	4f6080e7          	jalr	1270(ra) # 800037fa <iunlockput>
  ilock(ip);
    8000530c:	8526                	mv	a0,s1
    8000530e:	ffffe097          	auipc	ra,0xffffe
    80005312:	28a080e7          	jalr	650(ra) # 80003598 <ilock>
  ip->nlink--;
    80005316:	04a4d783          	lhu	a5,74(s1)
    8000531a:	37fd                	addiw	a5,a5,-1
    8000531c:	04f49523          	sh	a5,74(s1)
  iupdate(ip);
    80005320:	8526                	mv	a0,s1
    80005322:	ffffe097          	auipc	ra,0xffffe
    80005326:	1aa080e7          	jalr	426(ra) # 800034cc <iupdate>
  iunlockput(ip);
    8000532a:	8526                	mv	a0,s1
    8000532c:	ffffe097          	auipc	ra,0xffffe
    80005330:	4ce080e7          	jalr	1230(ra) # 800037fa <iunlockput>
  end_op();
    80005334:	fffff097          	auipc	ra,0xfffff
    80005338:	cbe080e7          	jalr	-834(ra) # 80003ff2 <end_op>
  return -1;
    8000533c:	57fd                	li	a5,-1
}
    8000533e:	853e                	mv	a0,a5
    80005340:	70b2                	ld	ra,296(sp)
    80005342:	7412                	ld	s0,288(sp)
    80005344:	64f2                	ld	s1,280(sp)
    80005346:	6952                	ld	s2,272(sp)
    80005348:	6155                	addi	sp,sp,304
    8000534a:	8082                	ret

000000008000534c <sys_unlink>:
{
    8000534c:	7151                	addi	sp,sp,-240
    8000534e:	f586                	sd	ra,232(sp)
    80005350:	f1a2                	sd	s0,224(sp)
    80005352:	eda6                	sd	s1,216(sp)
    80005354:	e9ca                	sd	s2,208(sp)
    80005356:	e5ce                	sd	s3,200(sp)
    80005358:	1980                	addi	s0,sp,240
  if(argstr(0, path, MAXPATH) < 0)
    8000535a:	08000613          	li	a2,128
    8000535e:	f3040593          	addi	a1,s0,-208
    80005362:	4501                	li	a0,0
    80005364:	ffffd097          	auipc	ra,0xffffd
    80005368:	706080e7          	jalr	1798(ra) # 80002a6a <argstr>
    8000536c:	18054163          	bltz	a0,800054ee <sys_unlink+0x1a2>
  begin_op();
    80005370:	fffff097          	auipc	ra,0xfffff
    80005374:	c04080e7          	jalr	-1020(ra) # 80003f74 <begin_op>
  if((dp = nameiparent(path, name)) == 0){
    80005378:	fb040593          	addi	a1,s0,-80
    8000537c:	f3040513          	addi	a0,s0,-208
    80005380:	fffff097          	auipc	ra,0xfffff
    80005384:	9f2080e7          	jalr	-1550(ra) # 80003d72 <nameiparent>
    80005388:	84aa                	mv	s1,a0
    8000538a:	c979                	beqz	a0,80005460 <sys_unlink+0x114>
  ilock(dp);
    8000538c:	ffffe097          	auipc	ra,0xffffe
    80005390:	20c080e7          	jalr	524(ra) # 80003598 <ilock>
  if(namecmp(name, ".") == 0 || namecmp(name, "..") == 0)
    80005394:	00003597          	auipc	a1,0x3
    80005398:	36458593          	addi	a1,a1,868 # 800086f8 <syscalls+0x2b0>
    8000539c:	fb040513          	addi	a0,s0,-80
    800053a0:	ffffe097          	auipc	ra,0xffffe
    800053a4:	6c2080e7          	jalr	1730(ra) # 80003a62 <namecmp>
    800053a8:	14050a63          	beqz	a0,800054fc <sys_unlink+0x1b0>
    800053ac:	00003597          	auipc	a1,0x3
    800053b0:	35458593          	addi	a1,a1,852 # 80008700 <syscalls+0x2b8>
    800053b4:	fb040513          	addi	a0,s0,-80
    800053b8:	ffffe097          	auipc	ra,0xffffe
    800053bc:	6aa080e7          	jalr	1706(ra) # 80003a62 <namecmp>
    800053c0:	12050e63          	beqz	a0,800054fc <sys_unlink+0x1b0>
  if((ip = dirlookup(dp, name, &off)) == 0)
    800053c4:	f2c40613          	addi	a2,s0,-212
    800053c8:	fb040593          	addi	a1,s0,-80
    800053cc:	8526                	mv	a0,s1
    800053ce:	ffffe097          	auipc	ra,0xffffe
    800053d2:	6ae080e7          	jalr	1710(ra) # 80003a7c <dirlookup>
    800053d6:	892a                	mv	s2,a0
    800053d8:	12050263          	beqz	a0,800054fc <sys_unlink+0x1b0>
  ilock(ip);
    800053dc:	ffffe097          	auipc	ra,0xffffe
    800053e0:	1bc080e7          	jalr	444(ra) # 80003598 <ilock>
  if(ip->nlink < 1)
    800053e4:	04a91783          	lh	a5,74(s2)
    800053e8:	08f05263          	blez	a5,8000546c <sys_unlink+0x120>
  if(ip->type == T_DIR && !isdirempty(ip)){
    800053ec:	04491703          	lh	a4,68(s2)
    800053f0:	4785                	li	a5,1
    800053f2:	08f70563          	beq	a4,a5,8000547c <sys_unlink+0x130>
  memset(&de, 0, sizeof(de));
    800053f6:	4641                	li	a2,16
    800053f8:	4581                	li	a1,0
    800053fa:	fc040513          	addi	a0,s0,-64
    800053fe:	ffffc097          	auipc	ra,0xffffc
    80005402:	8a8080e7          	jalr	-1880(ra) # 80000ca6 <memset>
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80005406:	4741                	li	a4,16
    80005408:	f2c42683          	lw	a3,-212(s0)
    8000540c:	fc040613          	addi	a2,s0,-64
    80005410:	4581                	li	a1,0
    80005412:	8526                	mv	a0,s1
    80005414:	ffffe097          	auipc	ra,0xffffe
    80005418:	530080e7          	jalr	1328(ra) # 80003944 <writei>
    8000541c:	47c1                	li	a5,16
    8000541e:	0af51563          	bne	a0,a5,800054c8 <sys_unlink+0x17c>
  if(ip->type == T_DIR){
    80005422:	04491703          	lh	a4,68(s2)
    80005426:	4785                	li	a5,1
    80005428:	0af70863          	beq	a4,a5,800054d8 <sys_unlink+0x18c>
  iunlockput(dp);
    8000542c:	8526                	mv	a0,s1
    8000542e:	ffffe097          	auipc	ra,0xffffe
    80005432:	3cc080e7          	jalr	972(ra) # 800037fa <iunlockput>
  ip->nlink--;
    80005436:	04a95783          	lhu	a5,74(s2)
    8000543a:	37fd                	addiw	a5,a5,-1
    8000543c:	04f91523          	sh	a5,74(s2)
  iupdate(ip);
    80005440:	854a                	mv	a0,s2
    80005442:	ffffe097          	auipc	ra,0xffffe
    80005446:	08a080e7          	jalr	138(ra) # 800034cc <iupdate>
  iunlockput(ip);
    8000544a:	854a                	mv	a0,s2
    8000544c:	ffffe097          	auipc	ra,0xffffe
    80005450:	3ae080e7          	jalr	942(ra) # 800037fa <iunlockput>
  end_op();
    80005454:	fffff097          	auipc	ra,0xfffff
    80005458:	b9e080e7          	jalr	-1122(ra) # 80003ff2 <end_op>
  return 0;
    8000545c:	4501                	li	a0,0
    8000545e:	a84d                	j	80005510 <sys_unlink+0x1c4>
    end_op();
    80005460:	fffff097          	auipc	ra,0xfffff
    80005464:	b92080e7          	jalr	-1134(ra) # 80003ff2 <end_op>
    return -1;
    80005468:	557d                	li	a0,-1
    8000546a:	a05d                	j	80005510 <sys_unlink+0x1c4>
    panic("unlink: nlink < 1");
    8000546c:	00003517          	auipc	a0,0x3
    80005470:	2bc50513          	addi	a0,a0,700 # 80008728 <syscalls+0x2e0>
    80005474:	ffffb097          	auipc	ra,0xffffb
    80005478:	0c6080e7          	jalr	198(ra) # 8000053a <panic>
  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    8000547c:	04c92703          	lw	a4,76(s2)
    80005480:	02000793          	li	a5,32
    80005484:	f6e7f9e3          	bgeu	a5,a4,800053f6 <sys_unlink+0xaa>
    80005488:	02000993          	li	s3,32
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    8000548c:	4741                	li	a4,16
    8000548e:	86ce                	mv	a3,s3
    80005490:	f1840613          	addi	a2,s0,-232
    80005494:	4581                	li	a1,0
    80005496:	854a                	mv	a0,s2
    80005498:	ffffe097          	auipc	ra,0xffffe
    8000549c:	3b4080e7          	jalr	948(ra) # 8000384c <readi>
    800054a0:	47c1                	li	a5,16
    800054a2:	00f51b63          	bne	a0,a5,800054b8 <sys_unlink+0x16c>
    if(de.inum != 0)
    800054a6:	f1845783          	lhu	a5,-232(s0)
    800054aa:	e7a1                	bnez	a5,800054f2 <sys_unlink+0x1a6>
  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    800054ac:	29c1                	addiw	s3,s3,16
    800054ae:	04c92783          	lw	a5,76(s2)
    800054b2:	fcf9ede3          	bltu	s3,a5,8000548c <sys_unlink+0x140>
    800054b6:	b781                	j	800053f6 <sys_unlink+0xaa>
      panic("isdirempty: readi");
    800054b8:	00003517          	auipc	a0,0x3
    800054bc:	28850513          	addi	a0,a0,648 # 80008740 <syscalls+0x2f8>
    800054c0:	ffffb097          	auipc	ra,0xffffb
    800054c4:	07a080e7          	jalr	122(ra) # 8000053a <panic>
    panic("unlink: writei");
    800054c8:	00003517          	auipc	a0,0x3
    800054cc:	29050513          	addi	a0,a0,656 # 80008758 <syscalls+0x310>
    800054d0:	ffffb097          	auipc	ra,0xffffb
    800054d4:	06a080e7          	jalr	106(ra) # 8000053a <panic>
    dp->nlink--;
    800054d8:	04a4d783          	lhu	a5,74(s1)
    800054dc:	37fd                	addiw	a5,a5,-1
    800054de:	04f49523          	sh	a5,74(s1)
    iupdate(dp);
    800054e2:	8526                	mv	a0,s1
    800054e4:	ffffe097          	auipc	ra,0xffffe
    800054e8:	fe8080e7          	jalr	-24(ra) # 800034cc <iupdate>
    800054ec:	b781                	j	8000542c <sys_unlink+0xe0>
    return -1;
    800054ee:	557d                	li	a0,-1
    800054f0:	a005                	j	80005510 <sys_unlink+0x1c4>
    iunlockput(ip);
    800054f2:	854a                	mv	a0,s2
    800054f4:	ffffe097          	auipc	ra,0xffffe
    800054f8:	306080e7          	jalr	774(ra) # 800037fa <iunlockput>
  iunlockput(dp);
    800054fc:	8526                	mv	a0,s1
    800054fe:	ffffe097          	auipc	ra,0xffffe
    80005502:	2fc080e7          	jalr	764(ra) # 800037fa <iunlockput>
  end_op();
    80005506:	fffff097          	auipc	ra,0xfffff
    8000550a:	aec080e7          	jalr	-1300(ra) # 80003ff2 <end_op>
  return -1;
    8000550e:	557d                	li	a0,-1
}
    80005510:	70ae                	ld	ra,232(sp)
    80005512:	740e                	ld	s0,224(sp)
    80005514:	64ee                	ld	s1,216(sp)
    80005516:	694e                	ld	s2,208(sp)
    80005518:	69ae                	ld	s3,200(sp)
    8000551a:	616d                	addi	sp,sp,240
    8000551c:	8082                	ret

000000008000551e <sys_open>:

uint64
sys_open(void)
{
    8000551e:	7131                	addi	sp,sp,-192
    80005520:	fd06                	sd	ra,184(sp)
    80005522:	f922                	sd	s0,176(sp)
    80005524:	f526                	sd	s1,168(sp)
    80005526:	f14a                	sd	s2,160(sp)
    80005528:	ed4e                	sd	s3,152(sp)
    8000552a:	0180                	addi	s0,sp,192
  int fd, omode;
  struct file *f;
  struct inode *ip;
  int n;

  if((n = argstr(0, path, MAXPATH)) < 0 || argint(1, &omode) < 0)
    8000552c:	08000613          	li	a2,128
    80005530:	f5040593          	addi	a1,s0,-176
    80005534:	4501                	li	a0,0
    80005536:	ffffd097          	auipc	ra,0xffffd
    8000553a:	534080e7          	jalr	1332(ra) # 80002a6a <argstr>
    return -1;
    8000553e:	54fd                	li	s1,-1
  if((n = argstr(0, path, MAXPATH)) < 0 || argint(1, &omode) < 0)
    80005540:	0c054163          	bltz	a0,80005602 <sys_open+0xe4>
    80005544:	f4c40593          	addi	a1,s0,-180
    80005548:	4505                	li	a0,1
    8000554a:	ffffd097          	auipc	ra,0xffffd
    8000554e:	4dc080e7          	jalr	1244(ra) # 80002a26 <argint>
    80005552:	0a054863          	bltz	a0,80005602 <sys_open+0xe4>

  begin_op();
    80005556:	fffff097          	auipc	ra,0xfffff
    8000555a:	a1e080e7          	jalr	-1506(ra) # 80003f74 <begin_op>

  if(omode & O_CREATE){
    8000555e:	f4c42783          	lw	a5,-180(s0)
    80005562:	2007f793          	andi	a5,a5,512
    80005566:	cbdd                	beqz	a5,8000561c <sys_open+0xfe>
    ip = create(path, T_FILE, 0, 0);
    80005568:	4681                	li	a3,0
    8000556a:	4601                	li	a2,0
    8000556c:	4589                	li	a1,2
    8000556e:	f5040513          	addi	a0,s0,-176
    80005572:	00000097          	auipc	ra,0x0
    80005576:	970080e7          	jalr	-1680(ra) # 80004ee2 <create>
    8000557a:	892a                	mv	s2,a0
    if(ip == 0){
    8000557c:	c959                	beqz	a0,80005612 <sys_open+0xf4>
      end_op();
      return -1;
    }
  }

  if(ip->type == T_DEVICE && (ip->major < 0 || ip->major >= NDEV)){
    8000557e:	04491703          	lh	a4,68(s2)
    80005582:	478d                	li	a5,3
    80005584:	00f71763          	bne	a4,a5,80005592 <sys_open+0x74>
    80005588:	04695703          	lhu	a4,70(s2)
    8000558c:	47a5                	li	a5,9
    8000558e:	0ce7ec63          	bltu	a5,a4,80005666 <sys_open+0x148>
    iunlockput(ip);
    end_op();
    return -1;
  }

  if((f = filealloc()) == 0 || (fd = fdalloc(f)) < 0){
    80005592:	fffff097          	auipc	ra,0xfffff
    80005596:	dee080e7          	jalr	-530(ra) # 80004380 <filealloc>
    8000559a:	89aa                	mv	s3,a0
    8000559c:	10050263          	beqz	a0,800056a0 <sys_open+0x182>
    800055a0:	00000097          	auipc	ra,0x0
    800055a4:	900080e7          	jalr	-1792(ra) # 80004ea0 <fdalloc>
    800055a8:	84aa                	mv	s1,a0
    800055aa:	0e054663          	bltz	a0,80005696 <sys_open+0x178>
    iunlockput(ip);
    end_op();
    return -1;
  }

  if(ip->type == T_DEVICE){
    800055ae:	04491703          	lh	a4,68(s2)
    800055b2:	478d                	li	a5,3
    800055b4:	0cf70463          	beq	a4,a5,8000567c <sys_open+0x15e>
    f->type = FD_DEVICE;
    f->major = ip->major;
  } else {
    f->type = FD_INODE;
    800055b8:	4789                	li	a5,2
    800055ba:	00f9a023          	sw	a5,0(s3)
    f->off = 0;
    800055be:	0209a023          	sw	zero,32(s3)
  }
  f->ip = ip;
    800055c2:	0129bc23          	sd	s2,24(s3)
  f->readable = !(omode & O_WRONLY);
    800055c6:	f4c42783          	lw	a5,-180(s0)
    800055ca:	0017c713          	xori	a4,a5,1
    800055ce:	8b05                	andi	a4,a4,1
    800055d0:	00e98423          	sb	a4,8(s3)
  f->writable = (omode & O_WRONLY) || (omode & O_RDWR);
    800055d4:	0037f713          	andi	a4,a5,3
    800055d8:	00e03733          	snez	a4,a4
    800055dc:	00e984a3          	sb	a4,9(s3)

  if((omode & O_TRUNC) && ip->type == T_FILE){
    800055e0:	4007f793          	andi	a5,a5,1024
    800055e4:	c791                	beqz	a5,800055f0 <sys_open+0xd2>
    800055e6:	04491703          	lh	a4,68(s2)
    800055ea:	4789                	li	a5,2
    800055ec:	08f70f63          	beq	a4,a5,8000568a <sys_open+0x16c>
    itrunc(ip);
  }

  iunlock(ip);
    800055f0:	854a                	mv	a0,s2
    800055f2:	ffffe097          	auipc	ra,0xffffe
    800055f6:	068080e7          	jalr	104(ra) # 8000365a <iunlock>
  end_op();
    800055fa:	fffff097          	auipc	ra,0xfffff
    800055fe:	9f8080e7          	jalr	-1544(ra) # 80003ff2 <end_op>

  return fd;
}
    80005602:	8526                	mv	a0,s1
    80005604:	70ea                	ld	ra,184(sp)
    80005606:	744a                	ld	s0,176(sp)
    80005608:	74aa                	ld	s1,168(sp)
    8000560a:	790a                	ld	s2,160(sp)
    8000560c:	69ea                	ld	s3,152(sp)
    8000560e:	6129                	addi	sp,sp,192
    80005610:	8082                	ret
      end_op();
    80005612:	fffff097          	auipc	ra,0xfffff
    80005616:	9e0080e7          	jalr	-1568(ra) # 80003ff2 <end_op>
      return -1;
    8000561a:	b7e5                	j	80005602 <sys_open+0xe4>
    if((ip = namei(path)) == 0){
    8000561c:	f5040513          	addi	a0,s0,-176
    80005620:	ffffe097          	auipc	ra,0xffffe
    80005624:	734080e7          	jalr	1844(ra) # 80003d54 <namei>
    80005628:	892a                	mv	s2,a0
    8000562a:	c905                	beqz	a0,8000565a <sys_open+0x13c>
    ilock(ip);
    8000562c:	ffffe097          	auipc	ra,0xffffe
    80005630:	f6c080e7          	jalr	-148(ra) # 80003598 <ilock>
    if(ip->type == T_DIR && omode != O_RDONLY){
    80005634:	04491703          	lh	a4,68(s2)
    80005638:	4785                	li	a5,1
    8000563a:	f4f712e3          	bne	a4,a5,8000557e <sys_open+0x60>
    8000563e:	f4c42783          	lw	a5,-180(s0)
    80005642:	dba1                	beqz	a5,80005592 <sys_open+0x74>
      iunlockput(ip);
    80005644:	854a                	mv	a0,s2
    80005646:	ffffe097          	auipc	ra,0xffffe
    8000564a:	1b4080e7          	jalr	436(ra) # 800037fa <iunlockput>
      end_op();
    8000564e:	fffff097          	auipc	ra,0xfffff
    80005652:	9a4080e7          	jalr	-1628(ra) # 80003ff2 <end_op>
      return -1;
    80005656:	54fd                	li	s1,-1
    80005658:	b76d                	j	80005602 <sys_open+0xe4>
      end_op();
    8000565a:	fffff097          	auipc	ra,0xfffff
    8000565e:	998080e7          	jalr	-1640(ra) # 80003ff2 <end_op>
      return -1;
    80005662:	54fd                	li	s1,-1
    80005664:	bf79                	j	80005602 <sys_open+0xe4>
    iunlockput(ip);
    80005666:	854a                	mv	a0,s2
    80005668:	ffffe097          	auipc	ra,0xffffe
    8000566c:	192080e7          	jalr	402(ra) # 800037fa <iunlockput>
    end_op();
    80005670:	fffff097          	auipc	ra,0xfffff
    80005674:	982080e7          	jalr	-1662(ra) # 80003ff2 <end_op>
    return -1;
    80005678:	54fd                	li	s1,-1
    8000567a:	b761                	j	80005602 <sys_open+0xe4>
    f->type = FD_DEVICE;
    8000567c:	00f9a023          	sw	a5,0(s3)
    f->major = ip->major;
    80005680:	04691783          	lh	a5,70(s2)
    80005684:	02f99223          	sh	a5,36(s3)
    80005688:	bf2d                	j	800055c2 <sys_open+0xa4>
    itrunc(ip);
    8000568a:	854a                	mv	a0,s2
    8000568c:	ffffe097          	auipc	ra,0xffffe
    80005690:	01a080e7          	jalr	26(ra) # 800036a6 <itrunc>
    80005694:	bfb1                	j	800055f0 <sys_open+0xd2>
      fileclose(f);
    80005696:	854e                	mv	a0,s3
    80005698:	fffff097          	auipc	ra,0xfffff
    8000569c:	da4080e7          	jalr	-604(ra) # 8000443c <fileclose>
    iunlockput(ip);
    800056a0:	854a                	mv	a0,s2
    800056a2:	ffffe097          	auipc	ra,0xffffe
    800056a6:	158080e7          	jalr	344(ra) # 800037fa <iunlockput>
    end_op();
    800056aa:	fffff097          	auipc	ra,0xfffff
    800056ae:	948080e7          	jalr	-1720(ra) # 80003ff2 <end_op>
    return -1;
    800056b2:	54fd                	li	s1,-1
    800056b4:	b7b9                	j	80005602 <sys_open+0xe4>

00000000800056b6 <sys_mkdir>:

uint64
sys_mkdir(void)
{
    800056b6:	7175                	addi	sp,sp,-144
    800056b8:	e506                	sd	ra,136(sp)
    800056ba:	e122                	sd	s0,128(sp)
    800056bc:	0900                	addi	s0,sp,144
  char path[MAXPATH];
  struct inode *ip;

  begin_op();
    800056be:	fffff097          	auipc	ra,0xfffff
    800056c2:	8b6080e7          	jalr	-1866(ra) # 80003f74 <begin_op>
  if(argstr(0, path, MAXPATH) < 0 || (ip = create(path, T_DIR, 0, 0)) == 0){
    800056c6:	08000613          	li	a2,128
    800056ca:	f7040593          	addi	a1,s0,-144
    800056ce:	4501                	li	a0,0
    800056d0:	ffffd097          	auipc	ra,0xffffd
    800056d4:	39a080e7          	jalr	922(ra) # 80002a6a <argstr>
    800056d8:	02054963          	bltz	a0,8000570a <sys_mkdir+0x54>
    800056dc:	4681                	li	a3,0
    800056de:	4601                	li	a2,0
    800056e0:	4585                	li	a1,1
    800056e2:	f7040513          	addi	a0,s0,-144
    800056e6:	fffff097          	auipc	ra,0xfffff
    800056ea:	7fc080e7          	jalr	2044(ra) # 80004ee2 <create>
    800056ee:	cd11                	beqz	a0,8000570a <sys_mkdir+0x54>
    end_op();
    return -1;
  }
  iunlockput(ip);
    800056f0:	ffffe097          	auipc	ra,0xffffe
    800056f4:	10a080e7          	jalr	266(ra) # 800037fa <iunlockput>
  end_op();
    800056f8:	fffff097          	auipc	ra,0xfffff
    800056fc:	8fa080e7          	jalr	-1798(ra) # 80003ff2 <end_op>
  return 0;
    80005700:	4501                	li	a0,0
}
    80005702:	60aa                	ld	ra,136(sp)
    80005704:	640a                	ld	s0,128(sp)
    80005706:	6149                	addi	sp,sp,144
    80005708:	8082                	ret
    end_op();
    8000570a:	fffff097          	auipc	ra,0xfffff
    8000570e:	8e8080e7          	jalr	-1816(ra) # 80003ff2 <end_op>
    return -1;
    80005712:	557d                	li	a0,-1
    80005714:	b7fd                	j	80005702 <sys_mkdir+0x4c>

0000000080005716 <sys_mknod>:

uint64
sys_mknod(void)
{
    80005716:	7135                	addi	sp,sp,-160
    80005718:	ed06                	sd	ra,152(sp)
    8000571a:	e922                	sd	s0,144(sp)
    8000571c:	1100                	addi	s0,sp,160
  struct inode *ip;
  char path[MAXPATH];
  int major, minor;

  begin_op();
    8000571e:	fffff097          	auipc	ra,0xfffff
    80005722:	856080e7          	jalr	-1962(ra) # 80003f74 <begin_op>
  if((argstr(0, path, MAXPATH)) < 0 ||
    80005726:	08000613          	li	a2,128
    8000572a:	f7040593          	addi	a1,s0,-144
    8000572e:	4501                	li	a0,0
    80005730:	ffffd097          	auipc	ra,0xffffd
    80005734:	33a080e7          	jalr	826(ra) # 80002a6a <argstr>
    80005738:	04054a63          	bltz	a0,8000578c <sys_mknod+0x76>
     argint(1, &major) < 0 ||
    8000573c:	f6c40593          	addi	a1,s0,-148
    80005740:	4505                	li	a0,1
    80005742:	ffffd097          	auipc	ra,0xffffd
    80005746:	2e4080e7          	jalr	740(ra) # 80002a26 <argint>
  if((argstr(0, path, MAXPATH)) < 0 ||
    8000574a:	04054163          	bltz	a0,8000578c <sys_mknod+0x76>
     argint(2, &minor) < 0 ||
    8000574e:	f6840593          	addi	a1,s0,-152
    80005752:	4509                	li	a0,2
    80005754:	ffffd097          	auipc	ra,0xffffd
    80005758:	2d2080e7          	jalr	722(ra) # 80002a26 <argint>
     argint(1, &major) < 0 ||
    8000575c:	02054863          	bltz	a0,8000578c <sys_mknod+0x76>
     (ip = create(path, T_DEVICE, major, minor)) == 0){
    80005760:	f6841683          	lh	a3,-152(s0)
    80005764:	f6c41603          	lh	a2,-148(s0)
    80005768:	458d                	li	a1,3
    8000576a:	f7040513          	addi	a0,s0,-144
    8000576e:	fffff097          	auipc	ra,0xfffff
    80005772:	774080e7          	jalr	1908(ra) # 80004ee2 <create>
     argint(2, &minor) < 0 ||
    80005776:	c919                	beqz	a0,8000578c <sys_mknod+0x76>
    end_op();
    return -1;
  }
  iunlockput(ip);
    80005778:	ffffe097          	auipc	ra,0xffffe
    8000577c:	082080e7          	jalr	130(ra) # 800037fa <iunlockput>
  end_op();
    80005780:	fffff097          	auipc	ra,0xfffff
    80005784:	872080e7          	jalr	-1934(ra) # 80003ff2 <end_op>
  return 0;
    80005788:	4501                	li	a0,0
    8000578a:	a031                	j	80005796 <sys_mknod+0x80>
    end_op();
    8000578c:	fffff097          	auipc	ra,0xfffff
    80005790:	866080e7          	jalr	-1946(ra) # 80003ff2 <end_op>
    return -1;
    80005794:	557d                	li	a0,-1
}
    80005796:	60ea                	ld	ra,152(sp)
    80005798:	644a                	ld	s0,144(sp)
    8000579a:	610d                	addi	sp,sp,160
    8000579c:	8082                	ret

000000008000579e <sys_chdir>:

uint64
sys_chdir(void)
{
    8000579e:	7135                	addi	sp,sp,-160
    800057a0:	ed06                	sd	ra,152(sp)
    800057a2:	e922                	sd	s0,144(sp)
    800057a4:	e526                	sd	s1,136(sp)
    800057a6:	e14a                	sd	s2,128(sp)
    800057a8:	1100                	addi	s0,sp,160
  char path[MAXPATH];
  struct inode *ip;
  struct proc *p = myproc();
    800057aa:	ffffc097          	auipc	ra,0xffffc
    800057ae:	1c6080e7          	jalr	454(ra) # 80001970 <myproc>
    800057b2:	892a                	mv	s2,a0
  
  begin_op();
    800057b4:	ffffe097          	auipc	ra,0xffffe
    800057b8:	7c0080e7          	jalr	1984(ra) # 80003f74 <begin_op>
  if(argstr(0, path, MAXPATH) < 0 || (ip = namei(path)) == 0){
    800057bc:	08000613          	li	a2,128
    800057c0:	f6040593          	addi	a1,s0,-160
    800057c4:	4501                	li	a0,0
    800057c6:	ffffd097          	auipc	ra,0xffffd
    800057ca:	2a4080e7          	jalr	676(ra) # 80002a6a <argstr>
    800057ce:	04054b63          	bltz	a0,80005824 <sys_chdir+0x86>
    800057d2:	f6040513          	addi	a0,s0,-160
    800057d6:	ffffe097          	auipc	ra,0xffffe
    800057da:	57e080e7          	jalr	1406(ra) # 80003d54 <namei>
    800057de:	84aa                	mv	s1,a0
    800057e0:	c131                	beqz	a0,80005824 <sys_chdir+0x86>
    end_op();
    return -1;
  }
  ilock(ip);
    800057e2:	ffffe097          	auipc	ra,0xffffe
    800057e6:	db6080e7          	jalr	-586(ra) # 80003598 <ilock>
  if(ip->type != T_DIR){
    800057ea:	04449703          	lh	a4,68(s1)
    800057ee:	4785                	li	a5,1
    800057f0:	04f71063          	bne	a4,a5,80005830 <sys_chdir+0x92>
    iunlockput(ip);
    end_op();
    return -1;
  }
  iunlock(ip);
    800057f4:	8526                	mv	a0,s1
    800057f6:	ffffe097          	auipc	ra,0xffffe
    800057fa:	e64080e7          	jalr	-412(ra) # 8000365a <iunlock>
  iput(p->cwd);
    800057fe:	15093503          	ld	a0,336(s2)
    80005802:	ffffe097          	auipc	ra,0xffffe
    80005806:	f50080e7          	jalr	-176(ra) # 80003752 <iput>
  end_op();
    8000580a:	ffffe097          	auipc	ra,0xffffe
    8000580e:	7e8080e7          	jalr	2024(ra) # 80003ff2 <end_op>
  p->cwd = ip;
    80005812:	14993823          	sd	s1,336(s2)
  return 0;
    80005816:	4501                	li	a0,0
}
    80005818:	60ea                	ld	ra,152(sp)
    8000581a:	644a                	ld	s0,144(sp)
    8000581c:	64aa                	ld	s1,136(sp)
    8000581e:	690a                	ld	s2,128(sp)
    80005820:	610d                	addi	sp,sp,160
    80005822:	8082                	ret
    end_op();
    80005824:	ffffe097          	auipc	ra,0xffffe
    80005828:	7ce080e7          	jalr	1998(ra) # 80003ff2 <end_op>
    return -1;
    8000582c:	557d                	li	a0,-1
    8000582e:	b7ed                	j	80005818 <sys_chdir+0x7a>
    iunlockput(ip);
    80005830:	8526                	mv	a0,s1
    80005832:	ffffe097          	auipc	ra,0xffffe
    80005836:	fc8080e7          	jalr	-56(ra) # 800037fa <iunlockput>
    end_op();
    8000583a:	ffffe097          	auipc	ra,0xffffe
    8000583e:	7b8080e7          	jalr	1976(ra) # 80003ff2 <end_op>
    return -1;
    80005842:	557d                	li	a0,-1
    80005844:	bfd1                	j	80005818 <sys_chdir+0x7a>

0000000080005846 <sys_exec>:

uint64
sys_exec(void)
{
    80005846:	7145                	addi	sp,sp,-464
    80005848:	e786                	sd	ra,456(sp)
    8000584a:	e3a2                	sd	s0,448(sp)
    8000584c:	ff26                	sd	s1,440(sp)
    8000584e:	fb4a                	sd	s2,432(sp)
    80005850:	f74e                	sd	s3,424(sp)
    80005852:	f352                	sd	s4,416(sp)
    80005854:	ef56                	sd	s5,408(sp)
    80005856:	0b80                	addi	s0,sp,464
  char path[MAXPATH], *argv[MAXARG];
  int i;
  uint64 uargv, uarg;

  if(argstr(0, path, MAXPATH) < 0 || argaddr(1, &uargv) < 0){
    80005858:	08000613          	li	a2,128
    8000585c:	f4040593          	addi	a1,s0,-192
    80005860:	4501                	li	a0,0
    80005862:	ffffd097          	auipc	ra,0xffffd
    80005866:	208080e7          	jalr	520(ra) # 80002a6a <argstr>
    return -1;
    8000586a:	597d                	li	s2,-1
  if(argstr(0, path, MAXPATH) < 0 || argaddr(1, &uargv) < 0){
    8000586c:	0c054b63          	bltz	a0,80005942 <sys_exec+0xfc>
    80005870:	e3840593          	addi	a1,s0,-456
    80005874:	4505                	li	a0,1
    80005876:	ffffd097          	auipc	ra,0xffffd
    8000587a:	1d2080e7          	jalr	466(ra) # 80002a48 <argaddr>
    8000587e:	0c054263          	bltz	a0,80005942 <sys_exec+0xfc>
  }
  memset(argv, 0, sizeof(argv));
    80005882:	10000613          	li	a2,256
    80005886:	4581                	li	a1,0
    80005888:	e4040513          	addi	a0,s0,-448
    8000588c:	ffffb097          	auipc	ra,0xffffb
    80005890:	41a080e7          	jalr	1050(ra) # 80000ca6 <memset>
  for(i=0;; i++){
    if(i >= NELEM(argv)){
    80005894:	e4040493          	addi	s1,s0,-448
  memset(argv, 0, sizeof(argv));
    80005898:	89a6                	mv	s3,s1
    8000589a:	4901                	li	s2,0
    if(i >= NELEM(argv)){
    8000589c:	02000a13          	li	s4,32
    800058a0:	00090a9b          	sext.w	s5,s2
      goto bad;
    }
    if(fetchaddr(uargv+sizeof(uint64)*i, (uint64*)&uarg) < 0){
    800058a4:	00391513          	slli	a0,s2,0x3
    800058a8:	e3040593          	addi	a1,s0,-464
    800058ac:	e3843783          	ld	a5,-456(s0)
    800058b0:	953e                	add	a0,a0,a5
    800058b2:	ffffd097          	auipc	ra,0xffffd
    800058b6:	0da080e7          	jalr	218(ra) # 8000298c <fetchaddr>
    800058ba:	02054a63          	bltz	a0,800058ee <sys_exec+0xa8>
      goto bad;
    }
    if(uarg == 0){
    800058be:	e3043783          	ld	a5,-464(s0)
    800058c2:	c3b9                	beqz	a5,80005908 <sys_exec+0xc2>
      argv[i] = 0;
      break;
    }
    argv[i] = kalloc();
    800058c4:	ffffb097          	auipc	ra,0xffffb
    800058c8:	210080e7          	jalr	528(ra) # 80000ad4 <kalloc>
    800058cc:	85aa                	mv	a1,a0
    800058ce:	00a9b023          	sd	a0,0(s3)
    if(argv[i] == 0)
    800058d2:	cd11                	beqz	a0,800058ee <sys_exec+0xa8>
      goto bad;
    if(fetchstr(uarg, argv[i], PGSIZE) < 0)
    800058d4:	6605                	lui	a2,0x1
    800058d6:	e3043503          	ld	a0,-464(s0)
    800058da:	ffffd097          	auipc	ra,0xffffd
    800058de:	104080e7          	jalr	260(ra) # 800029de <fetchstr>
    800058e2:	00054663          	bltz	a0,800058ee <sys_exec+0xa8>
    if(i >= NELEM(argv)){
    800058e6:	0905                	addi	s2,s2,1
    800058e8:	09a1                	addi	s3,s3,8
    800058ea:	fb491be3          	bne	s2,s4,800058a0 <sys_exec+0x5a>
    kfree(argv[i]);

  return ret;

 bad:
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    800058ee:	f4040913          	addi	s2,s0,-192
    800058f2:	6088                	ld	a0,0(s1)
    800058f4:	c531                	beqz	a0,80005940 <sys_exec+0xfa>
    kfree(argv[i]);
    800058f6:	ffffb097          	auipc	ra,0xffffb
    800058fa:	0ec080e7          	jalr	236(ra) # 800009e2 <kfree>
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    800058fe:	04a1                	addi	s1,s1,8
    80005900:	ff2499e3          	bne	s1,s2,800058f2 <sys_exec+0xac>
  return -1;
    80005904:	597d                	li	s2,-1
    80005906:	a835                	j	80005942 <sys_exec+0xfc>
      argv[i] = 0;
    80005908:	0a8e                	slli	s5,s5,0x3
    8000590a:	fc0a8793          	addi	a5,s5,-64 # ffffffffffffefc0 <end+0xffffffff7ffd8fc0>
    8000590e:	00878ab3          	add	s5,a5,s0
    80005912:	e80ab023          	sd	zero,-384(s5)
  int ret = exec(path, argv);
    80005916:	e4040593          	addi	a1,s0,-448
    8000591a:	f4040513          	addi	a0,s0,-192
    8000591e:	fffff097          	auipc	ra,0xfffff
    80005922:	172080e7          	jalr	370(ra) # 80004a90 <exec>
    80005926:	892a                	mv	s2,a0
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80005928:	f4040993          	addi	s3,s0,-192
    8000592c:	6088                	ld	a0,0(s1)
    8000592e:	c911                	beqz	a0,80005942 <sys_exec+0xfc>
    kfree(argv[i]);
    80005930:	ffffb097          	auipc	ra,0xffffb
    80005934:	0b2080e7          	jalr	178(ra) # 800009e2 <kfree>
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80005938:	04a1                	addi	s1,s1,8
    8000593a:	ff3499e3          	bne	s1,s3,8000592c <sys_exec+0xe6>
    8000593e:	a011                	j	80005942 <sys_exec+0xfc>
  return -1;
    80005940:	597d                	li	s2,-1
}
    80005942:	854a                	mv	a0,s2
    80005944:	60be                	ld	ra,456(sp)
    80005946:	641e                	ld	s0,448(sp)
    80005948:	74fa                	ld	s1,440(sp)
    8000594a:	795a                	ld	s2,432(sp)
    8000594c:	79ba                	ld	s3,424(sp)
    8000594e:	7a1a                	ld	s4,416(sp)
    80005950:	6afa                	ld	s5,408(sp)
    80005952:	6179                	addi	sp,sp,464
    80005954:	8082                	ret

0000000080005956 <sys_pipe>:

uint64
sys_pipe(void)
{
    80005956:	7139                	addi	sp,sp,-64
    80005958:	fc06                	sd	ra,56(sp)
    8000595a:	f822                	sd	s0,48(sp)
    8000595c:	f426                	sd	s1,40(sp)
    8000595e:	0080                	addi	s0,sp,64
  uint64 fdarray; // user pointer to array of two integers
  struct file *rf, *wf;
  int fd0, fd1;
  struct proc *p = myproc();
    80005960:	ffffc097          	auipc	ra,0xffffc
    80005964:	010080e7          	jalr	16(ra) # 80001970 <myproc>
    80005968:	84aa                	mv	s1,a0

  if(argaddr(0, &fdarray) < 0)
    8000596a:	fd840593          	addi	a1,s0,-40
    8000596e:	4501                	li	a0,0
    80005970:	ffffd097          	auipc	ra,0xffffd
    80005974:	0d8080e7          	jalr	216(ra) # 80002a48 <argaddr>
    return -1;
    80005978:	57fd                	li	a5,-1
  if(argaddr(0, &fdarray) < 0)
    8000597a:	0e054063          	bltz	a0,80005a5a <sys_pipe+0x104>
  if(pipealloc(&rf, &wf) < 0)
    8000597e:	fc840593          	addi	a1,s0,-56
    80005982:	fd040513          	addi	a0,s0,-48
    80005986:	fffff097          	auipc	ra,0xfffff
    8000598a:	de6080e7          	jalr	-538(ra) # 8000476c <pipealloc>
    return -1;
    8000598e:	57fd                	li	a5,-1
  if(pipealloc(&rf, &wf) < 0)
    80005990:	0c054563          	bltz	a0,80005a5a <sys_pipe+0x104>
  fd0 = -1;
    80005994:	fcf42223          	sw	a5,-60(s0)
  if((fd0 = fdalloc(rf)) < 0 || (fd1 = fdalloc(wf)) < 0){
    80005998:	fd043503          	ld	a0,-48(s0)
    8000599c:	fffff097          	auipc	ra,0xfffff
    800059a0:	504080e7          	jalr	1284(ra) # 80004ea0 <fdalloc>
    800059a4:	fca42223          	sw	a0,-60(s0)
    800059a8:	08054c63          	bltz	a0,80005a40 <sys_pipe+0xea>
    800059ac:	fc843503          	ld	a0,-56(s0)
    800059b0:	fffff097          	auipc	ra,0xfffff
    800059b4:	4f0080e7          	jalr	1264(ra) # 80004ea0 <fdalloc>
    800059b8:	fca42023          	sw	a0,-64(s0)
    800059bc:	06054963          	bltz	a0,80005a2e <sys_pipe+0xd8>
      p->ofile[fd0] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  if(copyout(p->pagetable, fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
    800059c0:	4691                	li	a3,4
    800059c2:	fc440613          	addi	a2,s0,-60
    800059c6:	fd843583          	ld	a1,-40(s0)
    800059ca:	68a8                	ld	a0,80(s1)
    800059cc:	ffffc097          	auipc	ra,0xffffc
    800059d0:	c68080e7          	jalr	-920(ra) # 80001634 <copyout>
    800059d4:	02054063          	bltz	a0,800059f4 <sys_pipe+0x9e>
     copyout(p->pagetable, fdarray+sizeof(fd0), (char *)&fd1, sizeof(fd1)) < 0){
    800059d8:	4691                	li	a3,4
    800059da:	fc040613          	addi	a2,s0,-64
    800059de:	fd843583          	ld	a1,-40(s0)
    800059e2:	0591                	addi	a1,a1,4
    800059e4:	68a8                	ld	a0,80(s1)
    800059e6:	ffffc097          	auipc	ra,0xffffc
    800059ea:	c4e080e7          	jalr	-946(ra) # 80001634 <copyout>
    p->ofile[fd1] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  return 0;
    800059ee:	4781                	li	a5,0
  if(copyout(p->pagetable, fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
    800059f0:	06055563          	bgez	a0,80005a5a <sys_pipe+0x104>
    p->ofile[fd0] = 0;
    800059f4:	fc442783          	lw	a5,-60(s0)
    800059f8:	07e9                	addi	a5,a5,26
    800059fa:	078e                	slli	a5,a5,0x3
    800059fc:	97a6                	add	a5,a5,s1
    800059fe:	0007b023          	sd	zero,0(a5)
    p->ofile[fd1] = 0;
    80005a02:	fc042783          	lw	a5,-64(s0)
    80005a06:	07e9                	addi	a5,a5,26
    80005a08:	078e                	slli	a5,a5,0x3
    80005a0a:	00f48533          	add	a0,s1,a5
    80005a0e:	00053023          	sd	zero,0(a0)
    fileclose(rf);
    80005a12:	fd043503          	ld	a0,-48(s0)
    80005a16:	fffff097          	auipc	ra,0xfffff
    80005a1a:	a26080e7          	jalr	-1498(ra) # 8000443c <fileclose>
    fileclose(wf);
    80005a1e:	fc843503          	ld	a0,-56(s0)
    80005a22:	fffff097          	auipc	ra,0xfffff
    80005a26:	a1a080e7          	jalr	-1510(ra) # 8000443c <fileclose>
    return -1;
    80005a2a:	57fd                	li	a5,-1
    80005a2c:	a03d                	j	80005a5a <sys_pipe+0x104>
    if(fd0 >= 0)
    80005a2e:	fc442783          	lw	a5,-60(s0)
    80005a32:	0007c763          	bltz	a5,80005a40 <sys_pipe+0xea>
      p->ofile[fd0] = 0;
    80005a36:	07e9                	addi	a5,a5,26
    80005a38:	078e                	slli	a5,a5,0x3
    80005a3a:	97a6                	add	a5,a5,s1
    80005a3c:	0007b023          	sd	zero,0(a5)
    fileclose(rf);
    80005a40:	fd043503          	ld	a0,-48(s0)
    80005a44:	fffff097          	auipc	ra,0xfffff
    80005a48:	9f8080e7          	jalr	-1544(ra) # 8000443c <fileclose>
    fileclose(wf);
    80005a4c:	fc843503          	ld	a0,-56(s0)
    80005a50:	fffff097          	auipc	ra,0xfffff
    80005a54:	9ec080e7          	jalr	-1556(ra) # 8000443c <fileclose>
    return -1;
    80005a58:	57fd                	li	a5,-1
}
    80005a5a:	853e                	mv	a0,a5
    80005a5c:	70e2                	ld	ra,56(sp)
    80005a5e:	7442                	ld	s0,48(sp)
    80005a60:	74a2                	ld	s1,40(sp)
    80005a62:	6121                	addi	sp,sp,64
    80005a64:	8082                	ret
	...

0000000080005a70 <kernelvec>:
    80005a70:	7111                	addi	sp,sp,-256
    80005a72:	e006                	sd	ra,0(sp)
    80005a74:	e40a                	sd	sp,8(sp)
    80005a76:	e80e                	sd	gp,16(sp)
    80005a78:	ec12                	sd	tp,24(sp)
    80005a7a:	f016                	sd	t0,32(sp)
    80005a7c:	f41a                	sd	t1,40(sp)
    80005a7e:	f81e                	sd	t2,48(sp)
    80005a80:	fc22                	sd	s0,56(sp)
    80005a82:	e0a6                	sd	s1,64(sp)
    80005a84:	e4aa                	sd	a0,72(sp)
    80005a86:	e8ae                	sd	a1,80(sp)
    80005a88:	ecb2                	sd	a2,88(sp)
    80005a8a:	f0b6                	sd	a3,96(sp)
    80005a8c:	f4ba                	sd	a4,104(sp)
    80005a8e:	f8be                	sd	a5,112(sp)
    80005a90:	fcc2                	sd	a6,120(sp)
    80005a92:	e146                	sd	a7,128(sp)
    80005a94:	e54a                	sd	s2,136(sp)
    80005a96:	e94e                	sd	s3,144(sp)
    80005a98:	ed52                	sd	s4,152(sp)
    80005a9a:	f156                	sd	s5,160(sp)
    80005a9c:	f55a                	sd	s6,168(sp)
    80005a9e:	f95e                	sd	s7,176(sp)
    80005aa0:	fd62                	sd	s8,184(sp)
    80005aa2:	e1e6                	sd	s9,192(sp)
    80005aa4:	e5ea                	sd	s10,200(sp)
    80005aa6:	e9ee                	sd	s11,208(sp)
    80005aa8:	edf2                	sd	t3,216(sp)
    80005aaa:	f1f6                	sd	t4,224(sp)
    80005aac:	f5fa                	sd	t5,232(sp)
    80005aae:	f9fe                	sd	t6,240(sp)
    80005ab0:	da9fc0ef          	jal	ra,80002858 <kerneltrap>
    80005ab4:	6082                	ld	ra,0(sp)
    80005ab6:	6122                	ld	sp,8(sp)
    80005ab8:	61c2                	ld	gp,16(sp)
    80005aba:	7282                	ld	t0,32(sp)
    80005abc:	7322                	ld	t1,40(sp)
    80005abe:	73c2                	ld	t2,48(sp)
    80005ac0:	7462                	ld	s0,56(sp)
    80005ac2:	6486                	ld	s1,64(sp)
    80005ac4:	6526                	ld	a0,72(sp)
    80005ac6:	65c6                	ld	a1,80(sp)
    80005ac8:	6666                	ld	a2,88(sp)
    80005aca:	7686                	ld	a3,96(sp)
    80005acc:	7726                	ld	a4,104(sp)
    80005ace:	77c6                	ld	a5,112(sp)
    80005ad0:	7866                	ld	a6,120(sp)
    80005ad2:	688a                	ld	a7,128(sp)
    80005ad4:	692a                	ld	s2,136(sp)
    80005ad6:	69ca                	ld	s3,144(sp)
    80005ad8:	6a6a                	ld	s4,152(sp)
    80005ada:	7a8a                	ld	s5,160(sp)
    80005adc:	7b2a                	ld	s6,168(sp)
    80005ade:	7bca                	ld	s7,176(sp)
    80005ae0:	7c6a                	ld	s8,184(sp)
    80005ae2:	6c8e                	ld	s9,192(sp)
    80005ae4:	6d2e                	ld	s10,200(sp)
    80005ae6:	6dce                	ld	s11,208(sp)
    80005ae8:	6e6e                	ld	t3,216(sp)
    80005aea:	7e8e                	ld	t4,224(sp)
    80005aec:	7f2e                	ld	t5,232(sp)
    80005aee:	7fce                	ld	t6,240(sp)
    80005af0:	6111                	addi	sp,sp,256
    80005af2:	10200073          	sret
    80005af6:	00000013          	nop
    80005afa:	00000013          	nop
    80005afe:	0001                	nop

0000000080005b00 <timervec>:
    80005b00:	34051573          	csrrw	a0,mscratch,a0
    80005b04:	e10c                	sd	a1,0(a0)
    80005b06:	e510                	sd	a2,8(a0)
    80005b08:	e914                	sd	a3,16(a0)
    80005b0a:	6d0c                	ld	a1,24(a0)
    80005b0c:	7110                	ld	a2,32(a0)
    80005b0e:	6194                	ld	a3,0(a1)
    80005b10:	96b2                	add	a3,a3,a2
    80005b12:	e194                	sd	a3,0(a1)
    80005b14:	4589                	li	a1,2
    80005b16:	14459073          	csrw	sip,a1
    80005b1a:	6914                	ld	a3,16(a0)
    80005b1c:	6510                	ld	a2,8(a0)
    80005b1e:	610c                	ld	a1,0(a0)
    80005b20:	34051573          	csrrw	a0,mscratch,a0
    80005b24:	30200073          	mret
	...

0000000080005b2a <plicinit>:
// the riscv Platform Level Interrupt Controller (PLIC).
//

void
plicinit(void)
{
    80005b2a:	1141                	addi	sp,sp,-16
    80005b2c:	e422                	sd	s0,8(sp)
    80005b2e:	0800                	addi	s0,sp,16
  // set desired IRQ priorities non-zero (otherwise disabled).
  *(uint32*)(PLIC + UART0_IRQ*4) = 1;
    80005b30:	0c0007b7          	lui	a5,0xc000
    80005b34:	4705                	li	a4,1
    80005b36:	d798                	sw	a4,40(a5)
  *(uint32*)(PLIC + VIRTIO0_IRQ*4) = 1;
    80005b38:	c3d8                	sw	a4,4(a5)
}
    80005b3a:	6422                	ld	s0,8(sp)
    80005b3c:	0141                	addi	sp,sp,16
    80005b3e:	8082                	ret

0000000080005b40 <plicinithart>:

void
plicinithart(void)
{
    80005b40:	1141                	addi	sp,sp,-16
    80005b42:	e406                	sd	ra,8(sp)
    80005b44:	e022                	sd	s0,0(sp)
    80005b46:	0800                	addi	s0,sp,16
  int hart = cpuid();
    80005b48:	ffffc097          	auipc	ra,0xffffc
    80005b4c:	dfc080e7          	jalr	-516(ra) # 80001944 <cpuid>
  
  // set uart's enable bit for this hart's S-mode. 
  *(uint32*)PLIC_SENABLE(hart)= (1 << UART0_IRQ) | (1 << VIRTIO0_IRQ);
    80005b50:	0085171b          	slliw	a4,a0,0x8
    80005b54:	0c0027b7          	lui	a5,0xc002
    80005b58:	97ba                	add	a5,a5,a4
    80005b5a:	40200713          	li	a4,1026
    80005b5e:	08e7a023          	sw	a4,128(a5) # c002080 <_entry-0x73ffdf80>

  // set this hart's S-mode priority threshold to 0.
  *(uint32*)PLIC_SPRIORITY(hart) = 0;
    80005b62:	00d5151b          	slliw	a0,a0,0xd
    80005b66:	0c2017b7          	lui	a5,0xc201
    80005b6a:	97aa                	add	a5,a5,a0
    80005b6c:	0007a023          	sw	zero,0(a5) # c201000 <_entry-0x73dff000>
}
    80005b70:	60a2                	ld	ra,8(sp)
    80005b72:	6402                	ld	s0,0(sp)
    80005b74:	0141                	addi	sp,sp,16
    80005b76:	8082                	ret

0000000080005b78 <plic_claim>:

// ask the PLIC what interrupt we should serve.
int
plic_claim(void)
{
    80005b78:	1141                	addi	sp,sp,-16
    80005b7a:	e406                	sd	ra,8(sp)
    80005b7c:	e022                	sd	s0,0(sp)
    80005b7e:	0800                	addi	s0,sp,16
  int hart = cpuid();
    80005b80:	ffffc097          	auipc	ra,0xffffc
    80005b84:	dc4080e7          	jalr	-572(ra) # 80001944 <cpuid>
  int irq = *(uint32*)PLIC_SCLAIM(hart);
    80005b88:	00d5151b          	slliw	a0,a0,0xd
    80005b8c:	0c2017b7          	lui	a5,0xc201
    80005b90:	97aa                	add	a5,a5,a0
  return irq;
}
    80005b92:	43c8                	lw	a0,4(a5)
    80005b94:	60a2                	ld	ra,8(sp)
    80005b96:	6402                	ld	s0,0(sp)
    80005b98:	0141                	addi	sp,sp,16
    80005b9a:	8082                	ret

0000000080005b9c <plic_complete>:

// tell the PLIC we've served this IRQ.
void
plic_complete(int irq)
{
    80005b9c:	1101                	addi	sp,sp,-32
    80005b9e:	ec06                	sd	ra,24(sp)
    80005ba0:	e822                	sd	s0,16(sp)
    80005ba2:	e426                	sd	s1,8(sp)
    80005ba4:	1000                	addi	s0,sp,32
    80005ba6:	84aa                	mv	s1,a0
  int hart = cpuid();
    80005ba8:	ffffc097          	auipc	ra,0xffffc
    80005bac:	d9c080e7          	jalr	-612(ra) # 80001944 <cpuid>
  *(uint32*)PLIC_SCLAIM(hart) = irq;
    80005bb0:	00d5151b          	slliw	a0,a0,0xd
    80005bb4:	0c2017b7          	lui	a5,0xc201
    80005bb8:	97aa                	add	a5,a5,a0
    80005bba:	c3c4                	sw	s1,4(a5)
}
    80005bbc:	60e2                	ld	ra,24(sp)
    80005bbe:	6442                	ld	s0,16(sp)
    80005bc0:	64a2                	ld	s1,8(sp)
    80005bc2:	6105                	addi	sp,sp,32
    80005bc4:	8082                	ret

0000000080005bc6 <free_desc>:
}

// mark a descriptor as free.
static void
free_desc(int i)
{
    80005bc6:	1141                	addi	sp,sp,-16
    80005bc8:	e406                	sd	ra,8(sp)
    80005bca:	e022                	sd	s0,0(sp)
    80005bcc:	0800                	addi	s0,sp,16
  if(i >= NUM)
    80005bce:	479d                	li	a5,7
    80005bd0:	06a7c863          	blt	a5,a0,80005c40 <free_desc+0x7a>
    panic("free_desc 1");
  if(disk.free[i])
    80005bd4:	0001d717          	auipc	a4,0x1d
    80005bd8:	42c70713          	addi	a4,a4,1068 # 80023000 <disk>
    80005bdc:	972a                	add	a4,a4,a0
    80005bde:	6789                	lui	a5,0x2
    80005be0:	97ba                	add	a5,a5,a4
    80005be2:	0187c783          	lbu	a5,24(a5) # 2018 <_entry-0x7fffdfe8>
    80005be6:	e7ad                	bnez	a5,80005c50 <free_desc+0x8a>
    panic("free_desc 2");
  disk.desc[i].addr = 0;
    80005be8:	00451793          	slli	a5,a0,0x4
    80005bec:	0001f717          	auipc	a4,0x1f
    80005bf0:	41470713          	addi	a4,a4,1044 # 80025000 <disk+0x2000>
    80005bf4:	6314                	ld	a3,0(a4)
    80005bf6:	96be                	add	a3,a3,a5
    80005bf8:	0006b023          	sd	zero,0(a3)
  disk.desc[i].len = 0;
    80005bfc:	6314                	ld	a3,0(a4)
    80005bfe:	96be                	add	a3,a3,a5
    80005c00:	0006a423          	sw	zero,8(a3)
  disk.desc[i].flags = 0;
    80005c04:	6314                	ld	a3,0(a4)
    80005c06:	96be                	add	a3,a3,a5
    80005c08:	00069623          	sh	zero,12(a3)
  disk.desc[i].next = 0;
    80005c0c:	6318                	ld	a4,0(a4)
    80005c0e:	97ba                	add	a5,a5,a4
    80005c10:	00079723          	sh	zero,14(a5)
  disk.free[i] = 1;
    80005c14:	0001d717          	auipc	a4,0x1d
    80005c18:	3ec70713          	addi	a4,a4,1004 # 80023000 <disk>
    80005c1c:	972a                	add	a4,a4,a0
    80005c1e:	6789                	lui	a5,0x2
    80005c20:	97ba                	add	a5,a5,a4
    80005c22:	4705                	li	a4,1
    80005c24:	00e78c23          	sb	a4,24(a5) # 2018 <_entry-0x7fffdfe8>
  wakeup(&disk.free[0]);
    80005c28:	0001f517          	auipc	a0,0x1f
    80005c2c:	3f050513          	addi	a0,a0,1008 # 80025018 <disk+0x2018>
    80005c30:	ffffc097          	auipc	ra,0xffffc
    80005c34:	590080e7          	jalr	1424(ra) # 800021c0 <wakeup>
}
    80005c38:	60a2                	ld	ra,8(sp)
    80005c3a:	6402                	ld	s0,0(sp)
    80005c3c:	0141                	addi	sp,sp,16
    80005c3e:	8082                	ret
    panic("free_desc 1");
    80005c40:	00003517          	auipc	a0,0x3
    80005c44:	b2850513          	addi	a0,a0,-1240 # 80008768 <syscalls+0x320>
    80005c48:	ffffb097          	auipc	ra,0xffffb
    80005c4c:	8f2080e7          	jalr	-1806(ra) # 8000053a <panic>
    panic("free_desc 2");
    80005c50:	00003517          	auipc	a0,0x3
    80005c54:	b2850513          	addi	a0,a0,-1240 # 80008778 <syscalls+0x330>
    80005c58:	ffffb097          	auipc	ra,0xffffb
    80005c5c:	8e2080e7          	jalr	-1822(ra) # 8000053a <panic>

0000000080005c60 <virtio_disk_init>:
{
    80005c60:	1101                	addi	sp,sp,-32
    80005c62:	ec06                	sd	ra,24(sp)
    80005c64:	e822                	sd	s0,16(sp)
    80005c66:	e426                	sd	s1,8(sp)
    80005c68:	1000                	addi	s0,sp,32
  initlock(&disk.vdisk_lock, "virtio_disk");
    80005c6a:	00003597          	auipc	a1,0x3
    80005c6e:	b1e58593          	addi	a1,a1,-1250 # 80008788 <syscalls+0x340>
    80005c72:	0001f517          	auipc	a0,0x1f
    80005c76:	4b650513          	addi	a0,a0,1206 # 80025128 <disk+0x2128>
    80005c7a:	ffffb097          	auipc	ra,0xffffb
    80005c7e:	ea0080e7          	jalr	-352(ra) # 80000b1a <initlock>
  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
    80005c82:	100017b7          	lui	a5,0x10001
    80005c86:	4398                	lw	a4,0(a5)
    80005c88:	2701                	sext.w	a4,a4
    80005c8a:	747277b7          	lui	a5,0x74727
    80005c8e:	97678793          	addi	a5,a5,-1674 # 74726976 <_entry-0xb8d968a>
    80005c92:	0ef71063          	bne	a4,a5,80005d72 <virtio_disk_init+0x112>
     *R(VIRTIO_MMIO_VERSION) != 1 ||
    80005c96:	100017b7          	lui	a5,0x10001
    80005c9a:	43dc                	lw	a5,4(a5)
    80005c9c:	2781                	sext.w	a5,a5
  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
    80005c9e:	4705                	li	a4,1
    80005ca0:	0ce79963          	bne	a5,a4,80005d72 <virtio_disk_init+0x112>
     *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
    80005ca4:	100017b7          	lui	a5,0x10001
    80005ca8:	479c                	lw	a5,8(a5)
    80005caa:	2781                	sext.w	a5,a5
     *R(VIRTIO_MMIO_VERSION) != 1 ||
    80005cac:	4709                	li	a4,2
    80005cae:	0ce79263          	bne	a5,a4,80005d72 <virtio_disk_init+0x112>
     *R(VIRTIO_MMIO_VENDOR_ID) != 0x554d4551){
    80005cb2:	100017b7          	lui	a5,0x10001
    80005cb6:	47d8                	lw	a4,12(a5)
    80005cb8:	2701                	sext.w	a4,a4
     *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
    80005cba:	554d47b7          	lui	a5,0x554d4
    80005cbe:	55178793          	addi	a5,a5,1361 # 554d4551 <_entry-0x2ab2baaf>
    80005cc2:	0af71863          	bne	a4,a5,80005d72 <virtio_disk_init+0x112>
  *R(VIRTIO_MMIO_STATUS) = status;
    80005cc6:	100017b7          	lui	a5,0x10001
    80005cca:	4705                	li	a4,1
    80005ccc:	dbb8                	sw	a4,112(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    80005cce:	470d                	li	a4,3
    80005cd0:	dbb8                	sw	a4,112(a5)
  uint64 features = *R(VIRTIO_MMIO_DEVICE_FEATURES);
    80005cd2:	4b98                	lw	a4,16(a5)
  *R(VIRTIO_MMIO_DRIVER_FEATURES) = features;
    80005cd4:	c7ffe6b7          	lui	a3,0xc7ffe
    80005cd8:	75f68693          	addi	a3,a3,1887 # ffffffffc7ffe75f <end+0xffffffff47fd875f>
    80005cdc:	8f75                	and	a4,a4,a3
    80005cde:	d398                	sw	a4,32(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    80005ce0:	472d                	li	a4,11
    80005ce2:	dbb8                	sw	a4,112(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    80005ce4:	473d                	li	a4,15
    80005ce6:	dbb8                	sw	a4,112(a5)
  *R(VIRTIO_MMIO_GUEST_PAGE_SIZE) = PGSIZE;
    80005ce8:	6705                	lui	a4,0x1
    80005cea:	d798                	sw	a4,40(a5)
  *R(VIRTIO_MMIO_QUEUE_SEL) = 0;
    80005cec:	0207a823          	sw	zero,48(a5) # 10001030 <_entry-0x6fffefd0>
  uint32 max = *R(VIRTIO_MMIO_QUEUE_NUM_MAX);
    80005cf0:	5bdc                	lw	a5,52(a5)
    80005cf2:	2781                	sext.w	a5,a5
  if(max == 0)
    80005cf4:	c7d9                	beqz	a5,80005d82 <virtio_disk_init+0x122>
  if(max < NUM)
    80005cf6:	471d                	li	a4,7
    80005cf8:	08f77d63          	bgeu	a4,a5,80005d92 <virtio_disk_init+0x132>
  *R(VIRTIO_MMIO_QUEUE_NUM) = NUM;
    80005cfc:	100014b7          	lui	s1,0x10001
    80005d00:	47a1                	li	a5,8
    80005d02:	dc9c                	sw	a5,56(s1)
  memset(disk.pages, 0, sizeof(disk.pages));
    80005d04:	6609                	lui	a2,0x2
    80005d06:	4581                	li	a1,0
    80005d08:	0001d517          	auipc	a0,0x1d
    80005d0c:	2f850513          	addi	a0,a0,760 # 80023000 <disk>
    80005d10:	ffffb097          	auipc	ra,0xffffb
    80005d14:	f96080e7          	jalr	-106(ra) # 80000ca6 <memset>
  *R(VIRTIO_MMIO_QUEUE_PFN) = ((uint64)disk.pages) >> PGSHIFT;
    80005d18:	0001d717          	auipc	a4,0x1d
    80005d1c:	2e870713          	addi	a4,a4,744 # 80023000 <disk>
    80005d20:	00c75793          	srli	a5,a4,0xc
    80005d24:	2781                	sext.w	a5,a5
    80005d26:	c0bc                	sw	a5,64(s1)
  disk.desc = (struct virtq_desc *) disk.pages;
    80005d28:	0001f797          	auipc	a5,0x1f
    80005d2c:	2d878793          	addi	a5,a5,728 # 80025000 <disk+0x2000>
    80005d30:	e398                	sd	a4,0(a5)
  disk.avail = (struct virtq_avail *)(disk.pages + NUM*sizeof(struct virtq_desc));
    80005d32:	0001d717          	auipc	a4,0x1d
    80005d36:	34e70713          	addi	a4,a4,846 # 80023080 <disk+0x80>
    80005d3a:	e798                	sd	a4,8(a5)
  disk.used = (struct virtq_used *) (disk.pages + PGSIZE);
    80005d3c:	0001e717          	auipc	a4,0x1e
    80005d40:	2c470713          	addi	a4,a4,708 # 80024000 <disk+0x1000>
    80005d44:	eb98                	sd	a4,16(a5)
    disk.free[i] = 1;
    80005d46:	4705                	li	a4,1
    80005d48:	00e78c23          	sb	a4,24(a5)
    80005d4c:	00e78ca3          	sb	a4,25(a5)
    80005d50:	00e78d23          	sb	a4,26(a5)
    80005d54:	00e78da3          	sb	a4,27(a5)
    80005d58:	00e78e23          	sb	a4,28(a5)
    80005d5c:	00e78ea3          	sb	a4,29(a5)
    80005d60:	00e78f23          	sb	a4,30(a5)
    80005d64:	00e78fa3          	sb	a4,31(a5)
}
    80005d68:	60e2                	ld	ra,24(sp)
    80005d6a:	6442                	ld	s0,16(sp)
    80005d6c:	64a2                	ld	s1,8(sp)
    80005d6e:	6105                	addi	sp,sp,32
    80005d70:	8082                	ret
    panic("could not find virtio disk");
    80005d72:	00003517          	auipc	a0,0x3
    80005d76:	a2650513          	addi	a0,a0,-1498 # 80008798 <syscalls+0x350>
    80005d7a:	ffffa097          	auipc	ra,0xffffa
    80005d7e:	7c0080e7          	jalr	1984(ra) # 8000053a <panic>
    panic("virtio disk has no queue 0");
    80005d82:	00003517          	auipc	a0,0x3
    80005d86:	a3650513          	addi	a0,a0,-1482 # 800087b8 <syscalls+0x370>
    80005d8a:	ffffa097          	auipc	ra,0xffffa
    80005d8e:	7b0080e7          	jalr	1968(ra) # 8000053a <panic>
    panic("virtio disk max queue too short");
    80005d92:	00003517          	auipc	a0,0x3
    80005d96:	a4650513          	addi	a0,a0,-1466 # 800087d8 <syscalls+0x390>
    80005d9a:	ffffa097          	auipc	ra,0xffffa
    80005d9e:	7a0080e7          	jalr	1952(ra) # 8000053a <panic>

0000000080005da2 <virtio_disk_rw>:
  return 0;
}

void
virtio_disk_rw(struct buf *b, int write)
{
    80005da2:	7119                	addi	sp,sp,-128
    80005da4:	fc86                	sd	ra,120(sp)
    80005da6:	f8a2                	sd	s0,112(sp)
    80005da8:	f4a6                	sd	s1,104(sp)
    80005daa:	f0ca                	sd	s2,96(sp)
    80005dac:	ecce                	sd	s3,88(sp)
    80005dae:	e8d2                	sd	s4,80(sp)
    80005db0:	e4d6                	sd	s5,72(sp)
    80005db2:	e0da                	sd	s6,64(sp)
    80005db4:	fc5e                	sd	s7,56(sp)
    80005db6:	f862                	sd	s8,48(sp)
    80005db8:	f466                	sd	s9,40(sp)
    80005dba:	f06a                	sd	s10,32(sp)
    80005dbc:	ec6e                	sd	s11,24(sp)
    80005dbe:	0100                	addi	s0,sp,128
    80005dc0:	8aaa                	mv	s5,a0
    80005dc2:	8d2e                	mv	s10,a1
  uint64 sector = b->blockno * (BSIZE / 512);
    80005dc4:	00c52c83          	lw	s9,12(a0)
    80005dc8:	001c9c9b          	slliw	s9,s9,0x1
    80005dcc:	1c82                	slli	s9,s9,0x20
    80005dce:	020cdc93          	srli	s9,s9,0x20

  acquire(&disk.vdisk_lock);
    80005dd2:	0001f517          	auipc	a0,0x1f
    80005dd6:	35650513          	addi	a0,a0,854 # 80025128 <disk+0x2128>
    80005dda:	ffffb097          	auipc	ra,0xffffb
    80005dde:	dd0080e7          	jalr	-560(ra) # 80000baa <acquire>
  for(int i = 0; i < 3; i++){
    80005de2:	4981                	li	s3,0
  for(int i = 0; i < NUM; i++){
    80005de4:	44a1                	li	s1,8
      disk.free[i] = 0;
    80005de6:	0001dc17          	auipc	s8,0x1d
    80005dea:	21ac0c13          	addi	s8,s8,538 # 80023000 <disk>
    80005dee:	6b89                	lui	s7,0x2
  for(int i = 0; i < 3; i++){
    80005df0:	4b0d                	li	s6,3
    80005df2:	a0ad                	j	80005e5c <virtio_disk_rw+0xba>
      disk.free[i] = 0;
    80005df4:	00fc0733          	add	a4,s8,a5
    80005df8:	975e                	add	a4,a4,s7
    80005dfa:	00070c23          	sb	zero,24(a4)
    idx[i] = alloc_desc();
    80005dfe:	c19c                	sw	a5,0(a1)
    if(idx[i] < 0){
    80005e00:	0207c563          	bltz	a5,80005e2a <virtio_disk_rw+0x88>
  for(int i = 0; i < 3; i++){
    80005e04:	2905                	addiw	s2,s2,1
    80005e06:	0611                	addi	a2,a2,4 # 2004 <_entry-0x7fffdffc>
    80005e08:	19690c63          	beq	s2,s6,80005fa0 <virtio_disk_rw+0x1fe>
    idx[i] = alloc_desc();
    80005e0c:	85b2                	mv	a1,a2
  for(int i = 0; i < NUM; i++){
    80005e0e:	0001f717          	auipc	a4,0x1f
    80005e12:	20a70713          	addi	a4,a4,522 # 80025018 <disk+0x2018>
    80005e16:	87ce                	mv	a5,s3
    if(disk.free[i]){
    80005e18:	00074683          	lbu	a3,0(a4)
    80005e1c:	fee1                	bnez	a3,80005df4 <virtio_disk_rw+0x52>
  for(int i = 0; i < NUM; i++){
    80005e1e:	2785                	addiw	a5,a5,1
    80005e20:	0705                	addi	a4,a4,1
    80005e22:	fe979be3          	bne	a5,s1,80005e18 <virtio_disk_rw+0x76>
    idx[i] = alloc_desc();
    80005e26:	57fd                	li	a5,-1
    80005e28:	c19c                	sw	a5,0(a1)
      for(int j = 0; j < i; j++)
    80005e2a:	01205d63          	blez	s2,80005e44 <virtio_disk_rw+0xa2>
    80005e2e:	8dce                	mv	s11,s3
        free_desc(idx[j]);
    80005e30:	000a2503          	lw	a0,0(s4)
    80005e34:	00000097          	auipc	ra,0x0
    80005e38:	d92080e7          	jalr	-622(ra) # 80005bc6 <free_desc>
      for(int j = 0; j < i; j++)
    80005e3c:	2d85                	addiw	s11,s11,1
    80005e3e:	0a11                	addi	s4,s4,4
    80005e40:	ff2d98e3          	bne	s11,s2,80005e30 <virtio_disk_rw+0x8e>
  int idx[3];
  while(1){
    if(alloc3_desc(idx) == 0) {
      break;
    }
    sleep(&disk.free[0], &disk.vdisk_lock);
    80005e44:	0001f597          	auipc	a1,0x1f
    80005e48:	2e458593          	addi	a1,a1,740 # 80025128 <disk+0x2128>
    80005e4c:	0001f517          	auipc	a0,0x1f
    80005e50:	1cc50513          	addi	a0,a0,460 # 80025018 <disk+0x2018>
    80005e54:	ffffc097          	auipc	ra,0xffffc
    80005e58:	1e0080e7          	jalr	480(ra) # 80002034 <sleep>
  for(int i = 0; i < 3; i++){
    80005e5c:	f8040a13          	addi	s4,s0,-128
{
    80005e60:	8652                	mv	a2,s4
  for(int i = 0; i < 3; i++){
    80005e62:	894e                	mv	s2,s3
    80005e64:	b765                	j	80005e0c <virtio_disk_rw+0x6a>
  disk.desc[idx[0]].next = idx[1];

  disk.desc[idx[1]].addr = (uint64) b->data;
  disk.desc[idx[1]].len = BSIZE;
  if(write)
    disk.desc[idx[1]].flags = 0; // device reads b->data
    80005e66:	0001f697          	auipc	a3,0x1f
    80005e6a:	19a6b683          	ld	a3,410(a3) # 80025000 <disk+0x2000>
    80005e6e:	96ba                	add	a3,a3,a4
    80005e70:	00069623          	sh	zero,12(a3)
  else
    disk.desc[idx[1]].flags = VRING_DESC_F_WRITE; // device writes b->data
  disk.desc[idx[1]].flags |= VRING_DESC_F_NEXT;
    80005e74:	0001d817          	auipc	a6,0x1d
    80005e78:	18c80813          	addi	a6,a6,396 # 80023000 <disk>
    80005e7c:	0001f697          	auipc	a3,0x1f
    80005e80:	18468693          	addi	a3,a3,388 # 80025000 <disk+0x2000>
    80005e84:	6290                	ld	a2,0(a3)
    80005e86:	963a                	add	a2,a2,a4
    80005e88:	00c65583          	lhu	a1,12(a2)
    80005e8c:	0015e593          	ori	a1,a1,1
    80005e90:	00b61623          	sh	a1,12(a2)
  disk.desc[idx[1]].next = idx[2];
    80005e94:	f8842603          	lw	a2,-120(s0)
    80005e98:	628c                	ld	a1,0(a3)
    80005e9a:	972e                	add	a4,a4,a1
    80005e9c:	00c71723          	sh	a2,14(a4)

  disk.info[idx[0]].status = 0xff; // device writes 0 on success
    80005ea0:	20050593          	addi	a1,a0,512
    80005ea4:	0592                	slli	a1,a1,0x4
    80005ea6:	95c2                	add	a1,a1,a6
    80005ea8:	577d                	li	a4,-1
    80005eaa:	02e58823          	sb	a4,48(a1)
  disk.desc[idx[2]].addr = (uint64) &disk.info[idx[0]].status;
    80005eae:	00461713          	slli	a4,a2,0x4
    80005eb2:	6290                	ld	a2,0(a3)
    80005eb4:	963a                	add	a2,a2,a4
    80005eb6:	03078793          	addi	a5,a5,48
    80005eba:	97c2                	add	a5,a5,a6
    80005ebc:	e21c                	sd	a5,0(a2)
  disk.desc[idx[2]].len = 1;
    80005ebe:	629c                	ld	a5,0(a3)
    80005ec0:	97ba                	add	a5,a5,a4
    80005ec2:	4605                	li	a2,1
    80005ec4:	c790                	sw	a2,8(a5)
  disk.desc[idx[2]].flags = VRING_DESC_F_WRITE; // device writes the status
    80005ec6:	629c                	ld	a5,0(a3)
    80005ec8:	97ba                	add	a5,a5,a4
    80005eca:	4809                	li	a6,2
    80005ecc:	01079623          	sh	a6,12(a5)
  disk.desc[idx[2]].next = 0;
    80005ed0:	629c                	ld	a5,0(a3)
    80005ed2:	97ba                	add	a5,a5,a4
    80005ed4:	00079723          	sh	zero,14(a5)

  // record struct buf for virtio_disk_intr().
  b->disk = 1;
    80005ed8:	00caa223          	sw	a2,4(s5)
  disk.info[idx[0]].b = b;
    80005edc:	0355b423          	sd	s5,40(a1)

  // tell the device the first index in our chain of descriptors.
  disk.avail->ring[disk.avail->idx % NUM] = idx[0];
    80005ee0:	6698                	ld	a4,8(a3)
    80005ee2:	00275783          	lhu	a5,2(a4)
    80005ee6:	8b9d                	andi	a5,a5,7
    80005ee8:	0786                	slli	a5,a5,0x1
    80005eea:	973e                	add	a4,a4,a5
    80005eec:	00a71223          	sh	a0,4(a4)

  __sync_synchronize();
    80005ef0:	0ff0000f          	fence

  // tell the device another avail ring entry is available.
  disk.avail->idx += 1; // not % NUM ...
    80005ef4:	6698                	ld	a4,8(a3)
    80005ef6:	00275783          	lhu	a5,2(a4)
    80005efa:	2785                	addiw	a5,a5,1
    80005efc:	00f71123          	sh	a5,2(a4)

  __sync_synchronize();
    80005f00:	0ff0000f          	fence

  *R(VIRTIO_MMIO_QUEUE_NOTIFY) = 0; // value is queue number
    80005f04:	100017b7          	lui	a5,0x10001
    80005f08:	0407a823          	sw	zero,80(a5) # 10001050 <_entry-0x6fffefb0>

  // Wait for virtio_disk_intr() to say request has finished.
  while(b->disk == 1) {
    80005f0c:	004aa783          	lw	a5,4(s5)
    80005f10:	02c79163          	bne	a5,a2,80005f32 <virtio_disk_rw+0x190>
    sleep(b, &disk.vdisk_lock);
    80005f14:	0001f917          	auipc	s2,0x1f
    80005f18:	21490913          	addi	s2,s2,532 # 80025128 <disk+0x2128>
  while(b->disk == 1) {
    80005f1c:	4485                	li	s1,1
    sleep(b, &disk.vdisk_lock);
    80005f1e:	85ca                	mv	a1,s2
    80005f20:	8556                	mv	a0,s5
    80005f22:	ffffc097          	auipc	ra,0xffffc
    80005f26:	112080e7          	jalr	274(ra) # 80002034 <sleep>
  while(b->disk == 1) {
    80005f2a:	004aa783          	lw	a5,4(s5)
    80005f2e:	fe9788e3          	beq	a5,s1,80005f1e <virtio_disk_rw+0x17c>
  }

  disk.info[idx[0]].b = 0;
    80005f32:	f8042903          	lw	s2,-128(s0)
    80005f36:	20090713          	addi	a4,s2,512
    80005f3a:	0712                	slli	a4,a4,0x4
    80005f3c:	0001d797          	auipc	a5,0x1d
    80005f40:	0c478793          	addi	a5,a5,196 # 80023000 <disk>
    80005f44:	97ba                	add	a5,a5,a4
    80005f46:	0207b423          	sd	zero,40(a5)
    int flag = disk.desc[i].flags;
    80005f4a:	0001f997          	auipc	s3,0x1f
    80005f4e:	0b698993          	addi	s3,s3,182 # 80025000 <disk+0x2000>
    80005f52:	00491713          	slli	a4,s2,0x4
    80005f56:	0009b783          	ld	a5,0(s3)
    80005f5a:	97ba                	add	a5,a5,a4
    80005f5c:	00c7d483          	lhu	s1,12(a5)
    int nxt = disk.desc[i].next;
    80005f60:	854a                	mv	a0,s2
    80005f62:	00e7d903          	lhu	s2,14(a5)
    free_desc(i);
    80005f66:	00000097          	auipc	ra,0x0
    80005f6a:	c60080e7          	jalr	-928(ra) # 80005bc6 <free_desc>
    if(flag & VRING_DESC_F_NEXT)
    80005f6e:	8885                	andi	s1,s1,1
    80005f70:	f0ed                	bnez	s1,80005f52 <virtio_disk_rw+0x1b0>
  free_chain(idx[0]);

  release(&disk.vdisk_lock);
    80005f72:	0001f517          	auipc	a0,0x1f
    80005f76:	1b650513          	addi	a0,a0,438 # 80025128 <disk+0x2128>
    80005f7a:	ffffb097          	auipc	ra,0xffffb
    80005f7e:	ce4080e7          	jalr	-796(ra) # 80000c5e <release>
}
    80005f82:	70e6                	ld	ra,120(sp)
    80005f84:	7446                	ld	s0,112(sp)
    80005f86:	74a6                	ld	s1,104(sp)
    80005f88:	7906                	ld	s2,96(sp)
    80005f8a:	69e6                	ld	s3,88(sp)
    80005f8c:	6a46                	ld	s4,80(sp)
    80005f8e:	6aa6                	ld	s5,72(sp)
    80005f90:	6b06                	ld	s6,64(sp)
    80005f92:	7be2                	ld	s7,56(sp)
    80005f94:	7c42                	ld	s8,48(sp)
    80005f96:	7ca2                	ld	s9,40(sp)
    80005f98:	7d02                	ld	s10,32(sp)
    80005f9a:	6de2                	ld	s11,24(sp)
    80005f9c:	6109                	addi	sp,sp,128
    80005f9e:	8082                	ret
  struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    80005fa0:	f8042503          	lw	a0,-128(s0)
    80005fa4:	20050793          	addi	a5,a0,512
    80005fa8:	0792                	slli	a5,a5,0x4
  if(write)
    80005faa:	0001d817          	auipc	a6,0x1d
    80005fae:	05680813          	addi	a6,a6,86 # 80023000 <disk>
    80005fb2:	00f80733          	add	a4,a6,a5
    80005fb6:	01a036b3          	snez	a3,s10
    80005fba:	0ad72423          	sw	a3,168(a4)
  buf0->reserved = 0;
    80005fbe:	0a072623          	sw	zero,172(a4)
  buf0->sector = sector;
    80005fc2:	0b973823          	sd	s9,176(a4)
  disk.desc[idx[0]].addr = (uint64) buf0;
    80005fc6:	7679                	lui	a2,0xffffe
    80005fc8:	963e                	add	a2,a2,a5
    80005fca:	0001f697          	auipc	a3,0x1f
    80005fce:	03668693          	addi	a3,a3,54 # 80025000 <disk+0x2000>
    80005fd2:	6298                	ld	a4,0(a3)
    80005fd4:	9732                	add	a4,a4,a2
  struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    80005fd6:	0a878593          	addi	a1,a5,168
    80005fda:	95c2                	add	a1,a1,a6
  disk.desc[idx[0]].addr = (uint64) buf0;
    80005fdc:	e30c                	sd	a1,0(a4)
  disk.desc[idx[0]].len = sizeof(struct virtio_blk_req);
    80005fde:	6298                	ld	a4,0(a3)
    80005fe0:	9732                	add	a4,a4,a2
    80005fe2:	45c1                	li	a1,16
    80005fe4:	c70c                	sw	a1,8(a4)
  disk.desc[idx[0]].flags = VRING_DESC_F_NEXT;
    80005fe6:	6298                	ld	a4,0(a3)
    80005fe8:	9732                	add	a4,a4,a2
    80005fea:	4585                	li	a1,1
    80005fec:	00b71623          	sh	a1,12(a4)
  disk.desc[idx[0]].next = idx[1];
    80005ff0:	f8442703          	lw	a4,-124(s0)
    80005ff4:	628c                	ld	a1,0(a3)
    80005ff6:	962e                	add	a2,a2,a1
    80005ff8:	00e61723          	sh	a4,14(a2) # ffffffffffffe00e <end+0xffffffff7ffd800e>
  disk.desc[idx[1]].addr = (uint64) b->data;
    80005ffc:	0712                	slli	a4,a4,0x4
    80005ffe:	6290                	ld	a2,0(a3)
    80006000:	963a                	add	a2,a2,a4
    80006002:	058a8593          	addi	a1,s5,88
    80006006:	e20c                	sd	a1,0(a2)
  disk.desc[idx[1]].len = BSIZE;
    80006008:	6294                	ld	a3,0(a3)
    8000600a:	96ba                	add	a3,a3,a4
    8000600c:	40000613          	li	a2,1024
    80006010:	c690                	sw	a2,8(a3)
  if(write)
    80006012:	e40d1ae3          	bnez	s10,80005e66 <virtio_disk_rw+0xc4>
    disk.desc[idx[1]].flags = VRING_DESC_F_WRITE; // device writes b->data
    80006016:	0001f697          	auipc	a3,0x1f
    8000601a:	fea6b683          	ld	a3,-22(a3) # 80025000 <disk+0x2000>
    8000601e:	96ba                	add	a3,a3,a4
    80006020:	4609                	li	a2,2
    80006022:	00c69623          	sh	a2,12(a3)
    80006026:	b5b9                	j	80005e74 <virtio_disk_rw+0xd2>

0000000080006028 <virtio_disk_intr>:

void
virtio_disk_intr()
{
    80006028:	1101                	addi	sp,sp,-32
    8000602a:	ec06                	sd	ra,24(sp)
    8000602c:	e822                	sd	s0,16(sp)
    8000602e:	e426                	sd	s1,8(sp)
    80006030:	e04a                	sd	s2,0(sp)
    80006032:	1000                	addi	s0,sp,32
  acquire(&disk.vdisk_lock);
    80006034:	0001f517          	auipc	a0,0x1f
    80006038:	0f450513          	addi	a0,a0,244 # 80025128 <disk+0x2128>
    8000603c:	ffffb097          	auipc	ra,0xffffb
    80006040:	b6e080e7          	jalr	-1170(ra) # 80000baa <acquire>
  // we've seen this interrupt, which the following line does.
  // this may race with the device writing new entries to
  // the "used" ring, in which case we may process the new
  // completion entries in this interrupt, and have nothing to do
  // in the next interrupt, which is harmless.
  *R(VIRTIO_MMIO_INTERRUPT_ACK) = *R(VIRTIO_MMIO_INTERRUPT_STATUS) & 0x3;
    80006044:	10001737          	lui	a4,0x10001
    80006048:	533c                	lw	a5,96(a4)
    8000604a:	8b8d                	andi	a5,a5,3
    8000604c:	d37c                	sw	a5,100(a4)

  __sync_synchronize();
    8000604e:	0ff0000f          	fence

  // the device increments disk.used->idx when it
  // adds an entry to the used ring.

  while(disk.used_idx != disk.used->idx){
    80006052:	0001f797          	auipc	a5,0x1f
    80006056:	fae78793          	addi	a5,a5,-82 # 80025000 <disk+0x2000>
    8000605a:	6b94                	ld	a3,16(a5)
    8000605c:	0207d703          	lhu	a4,32(a5)
    80006060:	0026d783          	lhu	a5,2(a3)
    80006064:	06f70163          	beq	a4,a5,800060c6 <virtio_disk_intr+0x9e>
    __sync_synchronize();
    int id = disk.used->ring[disk.used_idx % NUM].id;
    80006068:	0001d917          	auipc	s2,0x1d
    8000606c:	f9890913          	addi	s2,s2,-104 # 80023000 <disk>
    80006070:	0001f497          	auipc	s1,0x1f
    80006074:	f9048493          	addi	s1,s1,-112 # 80025000 <disk+0x2000>
    __sync_synchronize();
    80006078:	0ff0000f          	fence
    int id = disk.used->ring[disk.used_idx % NUM].id;
    8000607c:	6898                	ld	a4,16(s1)
    8000607e:	0204d783          	lhu	a5,32(s1)
    80006082:	8b9d                	andi	a5,a5,7
    80006084:	078e                	slli	a5,a5,0x3
    80006086:	97ba                	add	a5,a5,a4
    80006088:	43dc                	lw	a5,4(a5)

    if(disk.info[id].status != 0)
    8000608a:	20078713          	addi	a4,a5,512
    8000608e:	0712                	slli	a4,a4,0x4
    80006090:	974a                	add	a4,a4,s2
    80006092:	03074703          	lbu	a4,48(a4) # 10001030 <_entry-0x6fffefd0>
    80006096:	e731                	bnez	a4,800060e2 <virtio_disk_intr+0xba>
      panic("virtio_disk_intr status");

    struct buf *b = disk.info[id].b;
    80006098:	20078793          	addi	a5,a5,512
    8000609c:	0792                	slli	a5,a5,0x4
    8000609e:	97ca                	add	a5,a5,s2
    800060a0:	7788                	ld	a0,40(a5)
    b->disk = 0;   // disk is done with buf
    800060a2:	00052223          	sw	zero,4(a0)
    wakeup(b);
    800060a6:	ffffc097          	auipc	ra,0xffffc
    800060aa:	11a080e7          	jalr	282(ra) # 800021c0 <wakeup>

    disk.used_idx += 1;
    800060ae:	0204d783          	lhu	a5,32(s1)
    800060b2:	2785                	addiw	a5,a5,1
    800060b4:	17c2                	slli	a5,a5,0x30
    800060b6:	93c1                	srli	a5,a5,0x30
    800060b8:	02f49023          	sh	a5,32(s1)
  while(disk.used_idx != disk.used->idx){
    800060bc:	6898                	ld	a4,16(s1)
    800060be:	00275703          	lhu	a4,2(a4)
    800060c2:	faf71be3          	bne	a4,a5,80006078 <virtio_disk_intr+0x50>
  }

  release(&disk.vdisk_lock);
    800060c6:	0001f517          	auipc	a0,0x1f
    800060ca:	06250513          	addi	a0,a0,98 # 80025128 <disk+0x2128>
    800060ce:	ffffb097          	auipc	ra,0xffffb
    800060d2:	b90080e7          	jalr	-1136(ra) # 80000c5e <release>
}
    800060d6:	60e2                	ld	ra,24(sp)
    800060d8:	6442                	ld	s0,16(sp)
    800060da:	64a2                	ld	s1,8(sp)
    800060dc:	6902                	ld	s2,0(sp)
    800060de:	6105                	addi	sp,sp,32
    800060e0:	8082                	ret
      panic("virtio_disk_intr status");
    800060e2:	00002517          	auipc	a0,0x2
    800060e6:	71650513          	addi	a0,a0,1814 # 800087f8 <syscalls+0x3b0>
    800060ea:	ffffa097          	auipc	ra,0xffffa
    800060ee:	450080e7          	jalr	1104(ra) # 8000053a <panic>
	...

0000000080007000 <_trampoline>:
    80007000:	14051573          	csrrw	a0,sscratch,a0
    80007004:	02153423          	sd	ra,40(a0)
    80007008:	02253823          	sd	sp,48(a0)
    8000700c:	02353c23          	sd	gp,56(a0)
    80007010:	04453023          	sd	tp,64(a0)
    80007014:	04553423          	sd	t0,72(a0)
    80007018:	04653823          	sd	t1,80(a0)
    8000701c:	04753c23          	sd	t2,88(a0)
    80007020:	f120                	sd	s0,96(a0)
    80007022:	f524                	sd	s1,104(a0)
    80007024:	fd2c                	sd	a1,120(a0)
    80007026:	e150                	sd	a2,128(a0)
    80007028:	e554                	sd	a3,136(a0)
    8000702a:	e958                	sd	a4,144(a0)
    8000702c:	ed5c                	sd	a5,152(a0)
    8000702e:	0b053023          	sd	a6,160(a0)
    80007032:	0b153423          	sd	a7,168(a0)
    80007036:	0b253823          	sd	s2,176(a0)
    8000703a:	0b353c23          	sd	s3,184(a0)
    8000703e:	0d453023          	sd	s4,192(a0)
    80007042:	0d553423          	sd	s5,200(a0)
    80007046:	0d653823          	sd	s6,208(a0)
    8000704a:	0d753c23          	sd	s7,216(a0)
    8000704e:	0f853023          	sd	s8,224(a0)
    80007052:	0f953423          	sd	s9,232(a0)
    80007056:	0fa53823          	sd	s10,240(a0)
    8000705a:	0fb53c23          	sd	s11,248(a0)
    8000705e:	11c53023          	sd	t3,256(a0)
    80007062:	11d53423          	sd	t4,264(a0)
    80007066:	11e53823          	sd	t5,272(a0)
    8000706a:	11f53c23          	sd	t6,280(a0)
    8000706e:	140022f3          	csrr	t0,sscratch
    80007072:	06553823          	sd	t0,112(a0)
    80007076:	00853103          	ld	sp,8(a0)
    8000707a:	02053203          	ld	tp,32(a0)
    8000707e:	01053283          	ld	t0,16(a0)
    80007082:	00053303          	ld	t1,0(a0)
    80007086:	18031073          	csrw	satp,t1
    8000708a:	12000073          	sfence.vma
    8000708e:	8282                	jr	t0

0000000080007090 <userret>:
    80007090:	18059073          	csrw	satp,a1
    80007094:	12000073          	sfence.vma
    80007098:	07053283          	ld	t0,112(a0)
    8000709c:	14029073          	csrw	sscratch,t0
    800070a0:	02853083          	ld	ra,40(a0)
    800070a4:	03053103          	ld	sp,48(a0)
    800070a8:	03853183          	ld	gp,56(a0)
    800070ac:	04053203          	ld	tp,64(a0)
    800070b0:	04853283          	ld	t0,72(a0)
    800070b4:	05053303          	ld	t1,80(a0)
    800070b8:	05853383          	ld	t2,88(a0)
    800070bc:	7120                	ld	s0,96(a0)
    800070be:	7524                	ld	s1,104(a0)
    800070c0:	7d2c                	ld	a1,120(a0)
    800070c2:	6150                	ld	a2,128(a0)
    800070c4:	6554                	ld	a3,136(a0)
    800070c6:	6958                	ld	a4,144(a0)
    800070c8:	6d5c                	ld	a5,152(a0)
    800070ca:	0a053803          	ld	a6,160(a0)
    800070ce:	0a853883          	ld	a7,168(a0)
    800070d2:	0b053903          	ld	s2,176(a0)
    800070d6:	0b853983          	ld	s3,184(a0)
    800070da:	0c053a03          	ld	s4,192(a0)
    800070de:	0c853a83          	ld	s5,200(a0)
    800070e2:	0d053b03          	ld	s6,208(a0)
    800070e6:	0d853b83          	ld	s7,216(a0)
    800070ea:	0e053c03          	ld	s8,224(a0)
    800070ee:	0e853c83          	ld	s9,232(a0)
    800070f2:	0f053d03          	ld	s10,240(a0)
    800070f6:	0f853d83          	ld	s11,248(a0)
    800070fa:	10053e03          	ld	t3,256(a0)
    800070fe:	10853e83          	ld	t4,264(a0)
    80007102:	11053f03          	ld	t5,272(a0)
    80007106:	11853f83          	ld	t6,280(a0)
    8000710a:	14051573          	csrrw	a0,sscratch,a0
    8000710e:	10200073          	sret
	...
