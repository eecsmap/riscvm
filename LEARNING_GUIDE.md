# riscvm / rv64rs 学习指南：边写 RISC-V 虚拟机，边学计算机组成原理和 Rust

## 这是什么

这个仓库其实包含**同一个项目的两次实现**：

1. `riscvm/`：Python 实现，91 次提交，从 `dfba7f8 init` 一路写到能跑通真实的
   xv6-riscv 内核、挂载真实文件系统、进入交互式 shell。这条提交历史本身
   就是一条**发现驱动**的学习路径——"跑一个真实程序，缺什么指令/设备就补
   什么"，完全不是设计出来的教学大纲，是真实调试出来的。
2. `rv64rs/`：Rust 重新实现，在 Python 版本已经跑通之后，作者**明知道终点
   长什么样**，为了"加深理解"又按 8 个阶段（`rv64rs/PLAN.md`）把同一条路
   重新走了一遍，最后还做了 5 轮性能优化（`perf P1`..`P5`），把启动到 shell
   的时间从原型阶段的 ~3 秒压到 0.77 秒。

这份指南把两段历史拼在一起，按**同一条技术路线**（寄存器 → 内存 → 指令集
→ 特权态/中断 → MMIO 设备 → 分页 → 磁盘 → 性能优化）重新组织，每一站都会：

- 提出计算机组成原理层面的问题（不是"怎么写代码"，是"为什么要这样设计"）；
- 引用 Python 和 Rust 两边的真实代码片段做对照；
- 指出这一站涉及的 Rust 语言特性，以及它和 Python 对应写法的思维差异；
- 给一个可以动手做的练习和一个可验证的检验点（跑测试/跑 demo，而不是"看起来对"）。

## 前置知识要求

不需要在开始前就精通计算机体系结构或 Rust，但下面这些最好在开始前具备，
否则会在不该卡住的地方卡住：

- **计算机基础**：知道寄存器、内存地址、栈是什么，读过一点 C（能看懂指
  针和结构体即可）。不需要事先了解 RISC-V——指令集本身会在 Stage 1/3 里
  边读代码边学。
- **Python 基础**：能读懂 class、装饰器（`@property`）、`match`/`case`
  就够了，这份指南里的 Python 代码都偏"直白翻译规范"的风格，不depend on
  花哨的语言特性。
- **Rust 基础**：不需要精通，但最好已经看过《Rust 程序设计语言》（The
  Book）前 6 章，对"所有权/借用"、`enum`、`match`、`Option`/`Result`有个
  大致印象。完全没碰过 Rust 也可以硬着头皮开始——每一站的"Rust 语言点"
  会随用随讲——但进度会慢很多，因为所有权和借用检查这类概念不太可能只
  靠只言片语的解释就消化掉。

## 怎么用这份指南

建议的节奏，每一站都一样：

1. **先读 Python，不读 Rust。** Python 版本更啰嗦、更直白，适合先搞懂"这一
   层到底在解决什么问题"，不被 Rust 的类型系统分散注意力。
2. **自己想一遍再看答案。** 每一站会先给原理问题，尽量自己想清楚再往下翻。
3. **合上 `rv64rs/src/*.rs`，自己写一版。** 这是全指南最重要的一条：仓库里
   已经有"标准答案"（`rv64rs`），但如果直接照抄就失去了意义。建议新建一个
   scratch crate（或者直接在 `rv64rs/src/*.rs` 里删掉函数体自己重写），实现
   到能通过对应的 `cargo test` 为止，再去对照 `rv64rs` 的真实实现和它注释
   里解释的设计取舍。
4. **用真实里程碑验收，不用"感觉写完了"。** 每一站都给出具体命令和具体应该
   看到的输出（比如 `a0 == 23416728348467685`），这是这个项目从第一天就坚
   持的原则（见 `rv64rs/PLAN.md` 的"验收标准"一节）。

两条路径都可以走：**路径 A（精读）**——只读代码、答问题、跑仓库里已有的测
试，不动手写 Rust；**路径 B（重写）**——严格按 PLAN.md 的阶段自己重新实现
一遍 rv64rs。路径 B 收获大得多，但时间投入也大得多，可以先用路径 A 走一遍
建立全局理解，再挑几个自己最想吃透的阶段用路径 B 精做。

## 环境准备

```sh
# Python 侧（用 uv 管理依赖/venv，见 pyproject.toml；手动 venv + pip install -e . 也一样能跑）
cd riscvm仓库根目录
uv sync
uv run pytest                       # 跑全部 Python 测试

# Rust 侧
cd rv64rs
cargo build --release
cargo test --release                # 70 个测试，全部从 Python 的 tests/test_*.py 移植
```

先跑一次两边的"地基"验收，确认环境没问题：

```sh
uv run python3 -m riscvm.emulator tests/fib.bin      # Python 版 fib
cd rv64rs && cargo run --release -- fib              # Rust 版 fib，应输出同一个结果
```

两边应该都输出 `a0 = fib(80) = 23416728348467685`（或等价的寄存器值）——这
是贯穿整个项目、Python 和 Rust 两版都用来自证正确性的第一个数字。

---

## 总路线图

| 阶段 | 主题 | Python 参考提交 | Rust 参考提交 | 核心原理 | 里程碑 |
|---|---|---|---|---|---|
| 0 | 骨架：寄存器 + 总线 | `dfba7f8` init ~ `9f6a74e` 引入 matching 逻辑 | `a6d3f16` | 寄存器堆、地址空间仲裁 | `cargo build` + 总线用例通过 |
| 1 | ALU + 控制流 | `e077007`/`a8f4b5e`/`918eab5` fib 系列、`6f7a4b3` add jal、`c1dae7f` add beq | `53e0211` | 指令编码、立即数符号扩展、PC 相对跳转 | `fib.bin`: `a0 == 23416728348467685` |
| 2 | MEM：真实内存总线 | `9b9e3b7` add stack for xv6 kernel | `fa0ad32` | 内存总线、大小端、栈 | 用到栈的程序跑对 |
| 3 | 指令集补完：RV64M + RVC | `266e342` add mul、`a2ad265` RV64M 全套、`2ced32b` 起一串 rvc 提交 | `02a6162` | 压缩指令/代码密度、有符号乘除法语义 | `kernel64gc_nopageflush.bin` 的"找下一条指令"循环跑得动 |
| 4 | 特权态 / CSR / Trap | `1ce59e1` add mret、`515ab76` 特权级+trap+中断、`fa6479f` 修复委托 bug | `088783f` | 特权级、CSR 别名、异常/中断委托 | `test_trap.py` 全部用例通过 |
| 5 | MMIO 设备：CLINT/UART/PLIC | `d4b8a62` 支持内核打印、`f1629f1`/`7220fae` uart、`1856fcd` uart 输入 | `79c92a5` | MMIO、时钟中断、中断控制器优先级 | xv6 打印出 boot 信息 |
| 6 | MMU：Sv39 分页 | `a13f8dc` Sv39 walk | `afb2c90` | 虚拟内存、三级页表、超页 | 内核开分页后继续跑（317 → 10.8M 条指令） |
| 7 | VirtIO 磁盘 + 真文件系统 | `34e6908` 最小 virtio、`baa4069` 真文件系统、`b72e60e` 升级到 v2 协议 | `d23312e` | DMA、描述符环协议 | 跑到 `$` shell，`ls`/`echo` 能用 |
| P1-P5 | 性能优化（只有 Rust 做了这轮） | `0c230b0`/`1c59c16`（Python 侧也做过小优化，规模完全不同） | `156076d`/`71e1ade`/`7c4c394`/`fbb6436`/`344364e` | 数据结构选型、cache locality、TLB | boot-to-shell：2.96s → 0.77s |

---

## Stage 0：骨架——寄存器与总线

**目标**：打通 fetch/decode/execute 主循环和设备总线抽象，先不追求指令完整。

在细看代码之前，先建立一个全局的物理图像——这是 Stage 7 全部搭好之后
（`emulator.py`/`emulator.rs` 里的 `XV6`/`Xv6Emulator`）整机的样子，Stage
0 只会先做出 CPU + Bus + 一块 RAM，但提前看一眼终点有助于理解"总线"到底
是在干什么：

```
                        ┌────────────────────┐
                        │        CPU          │
                        │  regs[0..32] / pc    │
                        │  csrs[0..4096] / mode │
                        └──────────┬───────────┘
                                   │ fetch()/read()/write()（虚拟地址）
                                   ▼
                         mmu::translate()  (Stage 6 才接入，Stage 0 先直通)
                                   │ （物理地址）
                                   ▼
                        ┌────────────────────┐
                        │        Bus          │  RangeManager：按起始地址
                        │  （地址区间 → 设备）  │  排序的区间表 + 二分查找
                        └──────────┬───────────┘
       ┌───────────┬───────────────┼───────────────┬───────────────┐
       ▼           ▼               ▼               ▼               ▼
  0x00001000   0x02000000      0x10000000      0x10001000      0x0C000000   0x80000000...
  Bootloader     CLINT            UART           VirtIOBlk         PLIC         RAM
  (44 字节，     (mtime/          (串口          (磁盘，          (中断        (内核镜像
   跳到内核)     mtimecmp,        控制台，       描述符环         优先级/       + 栈，
                 Stage 5)         Stage 5)       协议，           使能/claim，   Stage 2)
                                                  Stage 7)         Stage 5)
```

Stage 0 只需要 CPU 和 Bus 这两个方块，外加一块最简单的 RAM 挂在总线上；
CLINT/UART/VirtIOBlk/PLIC 是后面几站才会陆续挂上去的设备，`mmu::translate`
是 Stage 6 才会真正做地址转换的地方（Stage 0-5 里它只是把虚拟地址原样传
回去）。把这张图记在脑子里，后面每一站看到"新增一个设备/新增一段地址映
射"，就是往这张图上加一个方块。

### 原理问题

1. CPU 为什么需要"寄存器堆"而不是直接在内存里做运算？寄存器和内存在访问延
   迟/编码方式上有什么本质区别？
2. RISC-V 里 `x0` 永远读出 0、写入被丢弃，这是软件约定还是硬件强制？如果是
   硬件强制，为什么要单独造一个"寄存器"来表示"常数 0"，而不是在译码阶段特
   判？
3. "总线"在这里到底是什么？为什么不能把 RAM、UART、CLINT 都简单地做成一个
   数组下标访问，而要设计一个地址区间查找的结构？

### 读代码：寄存器

Python 把每个寄存器建成一个对象，`x0` 用子类覆盖 setter 实现"写入被忽略"：

```python
# riscvm/register.py:6-46
class Register:
    def __init__(self, value = 0, name='register'):
        self._value = u64(value)
    @property
    def value(self):
        return self._value
    @value.setter
    def value(self, value):
        self._value = u64(value)

class FixedRegister(Register):
    @value.setter
    def value(self, _):
        '''just ignore the new value'''
```

Rust 版把 32 个寄存器压成一个定长数组，写入时判断下标即可，不需要为 `x0`
单独建类型：

```rust
// rv64rs/src/register.rs:8-29
pub struct Registers {
    regs: [u64; 32],
}
impl Registers {
    pub fn write(&mut self, index: usize, value: u64) {
        if index != 0 {
            self.regs[index] = value;
        }
    }
}
```

**对比要点**：Python 里"面向对象"的直觉是给每个概念建一个类；Rust 里如果
一组同类型的东西数量固定、行为一致，`[T; N]` 数组 + 几个自由函数往往比一
个类层次更直接。这不是"Rust 做不到 OO"，而是这里 OO 反而是过度设计——32
个寄存器不需要 32 个对象。

### 读代码：总线与地址查找

Python 用 `dict` 存设备、用 `bisect` 在已排序的起始地址列表里二分查找：

```python
# riscvm/rangemanager.py:43-62
def get_range(self, address, size):
    position = bisect_right(self.starts, address) - 1
    ...
    return (target_start, target_size)
```

```python
# riscvm/bus.py:16-24
def get_device(self, address, size):
    range = self.range_manager.get_range(address, size)
    return (self.devices[range], range)   # 再用 range 元组去 dict 里查一次设备
```

注意 Python 版这里**查了两次**：先在 `RangeManager` 里二分查找出 `range`
元组，再拿这个元组当 key 去 `self.devices` 这个 dict 里查一次设备。

Rust 版的 `RangeManager.add_range`/`get_range` 直接返回**下标**，`Bus` 用
一个和内部排序数组同构的 `Vec` 存设备，做到"一次二分、直接索引"：

```rust
// rv64rs/src/bus.rs:163-189
pub struct Bus {
    range_manager: RangeManager,
    devices: Vec<RefCell<Box<dyn Device>>>,   // 和 range_manager 内部数组同一套下标
}
impl Bus {
    pub fn read(&self, address: u64, size: u8) -> Result<u64, EmuError> {
        let (idx, range) = self.range_manager.get_range(address, size as u64)?;
        self.devices[idx].borrow_mut().read(address - range.start, size)
    }
}
```

**动手想一下**：这个"返回下标而不是返回值本身"的设计，在 `perf P2` 提交
里被专门拿出来当作一次性能优化点（见文末性能优化一节）。Python 版本从来
没有做类似优化——想一想，为什么同一个"二次查找"的问题，在 Python 里几乎
不会被当成性能问题，在 Rust 的高性能场景里却值得专门画一次 profile？

### Rust 语言点

- `trait Device { fn read(...); fn write(...); }` 对应 Python 的"鸭子类
  型"（`bus.py` 从不检查 `device` 是什么类型，只要有 `.read()`/`.write()`
  方法就行）。Rust 需要显式声明这个接口，换来的是编译期检查：忘记实现某
  个方法编译不过，而不是运行到那一行才 `AttributeError`。
- `Box<dyn Device>`：Python 的 list/dict 天然能装"任意类型的对象"，Rust
  的容器默认要求元素类型单一，`Box<dyn Trait>` 是"我不知道具体类型，但保
  证它实现了这个 trait"的运行时多态写法，对应 Python 里那种"只要接口对就
  行"的自由。
- 读一下 `rv64rs/src/bus.rs:14-26` 里 `Device::read` 为什么签名是
  `&mut self` 而不是 `&self`——这是 Rust 强制你现在就想清楚"读寄存器是否
  有副作用"（UART 的 RBR 寄存器读一次就消费一个字节），Python 版本因为没
  有 borrow checker，这个问题要等你真的踩到 bug 才会意识到。

### 动手练习

1. 自己实现一版 `Registers`（或者照抄，重点是读懂 `#[inline(always)]` 和
   `Default` trait 在这里的作用），写一个测试：写 `x0` 之后读出来还是 0。
2. 不看 `rv64rs/src/bus.rs`，自己设计一版 `RangeManager::get_range`，思考
   两个设备地址区间重叠时应该报错还是静默覆盖（提示：看
   `riscvm/rangemanager.py:33-38` 的 `error(...)` 调用）。

### 验收标准

`cargo test`（阶段 0 部分）应该覆盖 `tests/test_bus.py` 对应的场景：未映
射地址访问报错、跨区间访问报错。参考 `rv64rs/src/bus.rs:197-207` 里已有的
`test_invalid_address`。

---

## Stage 1：ALU + 控制流（fib.bin 里程碑）

**目标**：不涉及内存，纯寄存器运算 + 分支跳转，把最小原型正式收编进项目结构。

### 原理问题

1. 一条 32 位 RISC-V 指令里，`opcode`/`rd`/`rs1`/`rs2`/`funct3`/`funct7`
   为什么要切成这些位段、放在这些固定位置？这种"定长指令、固定字段位置"
   的设计对硬件译码有什么好处（对比 x86 变长指令）？
2. I-型立即数只有 12 位，却要塞进 64 位寄存器，为什么要做"符号扩展"而不是
   直接补 0？如果 `ADDI x1, x0, -1` 补 0 而不是符号扩展，会算出什么值？
3. `JAL`/`JALR`/`BEQ` 都是"跳转"，但立即数编码方式（J-型 vs B-型）为什么不
   一样？为什么分支目标是 PC 相对而不是绝对地址？

### 读代码：字段提取与立即数

Python 用一组柯里化的 lambda 从指令字里抠字段，`imm_i`/`imm_b` 等立即数
提取函数直接对着指令编码表写：

```python
# riscvm/rv64i.py:20-38
opcode = partial(section, pos=0, nbits=7)
rd = partial(section, pos=7, nbits=5)
imm_i = lambda x: i(12)(funct7(x) << 5 | rs2(x))
imm_b = lambda x: i(13)(
    section(x, 31, 1) << 12
    | section(x, 7, 1) << 11
    | section(x, 25, 6) << 5
    | section(x, 8, 4) << 1)
```

Rust 版把这些字段提取写成一次性的构造函数，`sext` 单独抽出来做符号扩展：

```rust
// rv64rs/src/decode.rs:26-49
fn sext(value: u32, bits: u32) -> i64 {
    let shift = 32 - bits;
    ((value << shift) as i32 >> shift) as i64
}
impl Instruction {
    pub fn new(w: u32) -> Self {
        let imm_i = sext(w >> 20, 12);
        let imm_b = sext(
            (((w >> 31) & 1) << 12) | (((w >> 7) & 1) << 11)
            | (((w >> 25) & 0x3f) << 5) | (((w >> 8) & 0xf) << 1),
            13,
        );
        ...
    }
}
```

**对比要点**：两边用的位运算逻辑几乎一模一样（Rust 版注释里明确写了"和
`rv64i.py` 的 `imm_i`/`imm_b`/... 完全对照，用它的 doctest 核对过"）。区
别在于 Python 靠"左移再算术右移"（`(value << shift) as i32 >> shift`）这
种技巧完成符号扩展，因为 Python 的整数是任意精度、没有原生的"64 位有符号
数"概念，`i()`/`i8`/`i32` 等辅助函数（见 `riscvm/utils.py`）要自己模拟溢
出和符号位；Rust 直接有 `i32`/`i64` 原生类型和它们之间的 `as` 转换规则，
符号扩展是类型系统自带的语义，不需要自己模拟。**这是贯穿整个项目最重要
的一处语言差异**：Python 版本相当一部分代码在"手工模拟"定长整数运算，
Rust 里这些代码基本消失了，因为语言本身就是定长整数。

### 读代码：译码分发与执行

Python 用 `match`/`case` 对 `Mnemonic` 枚举做分发（`riscvm/rv64i.py:377-417`
的 `actor()` 函数）；Rust 直接 `match` 在裸的 `opcode`/`funct3` 数值上，
不经过一层"先识别出 Mnemonic 枚举再分发"：

```rust
// rv64rs/src/execute.rs:117-139
OPCODE_OP_IMM => {
    let a = cpu.regs.read(instr.rs1);
    let imm = instr.imm_i as u64;
    let out = match instr.funct3 {
        0x0 => a.wrapping_add(imm),                 // ADDI
        0x2 => ((a as i64) < (instr.imm_i)) as u64,  // SLTI
        ...
        _ => return cpu.illegal_instruction(instr),
    };
    cpu.regs.write(instr.rd, out);
    Ok(default_next)
}
```

**动手想一下**：Python 版本先把指令字翻译成一个 `Mnemonic` 枚举（`ADDI`、
`SLTI`……），再用 `match mnemonic` 分发；Rust 版直接在 `opcode`/`funct3`
数值上分发，没有中间的枚举层。这不是必然选择——`rv64rs` 完全可以先做一层
`enum Mnemonic`。想一想两种设计各自的取舍：多一层枚举能获得什么（提示：
反汇编、日志可读性），又要多付出什么（提示：`0c230b0` 这条 Python 侧的性
能修复提交叫"Fix duplicate get_mnemonic() call in actor() — ~30% faster
decode"——这说明了什么）？

### Rust 语言点

- `wrapping_add` 而不是 `+`：debug 模式下 Rust 的整数加法溢出会 panic，
  这是刻意的（帮你在开发期抓出没预料到的溢出），CPU 加法语义就是"该溢出
  就溢出"，所以要显式选择 wrapping 语义。Python 没有这个问题，因为整数是
  任意精度，`a + b` 永远不会"溢出"，代码里反而要专门用 `u64(...)` 手工截
  断到 64 位（参考 `riscvm/utils.py`）。
- `match` 的穷尽性检查：Rust 编译器强制你处理 `_ =>` 分支（或者证明所有
  情况都覆盖了），Python 的 `match`/`case` 没有这个静态保证，写漏一个
  `case` 只会在运行时走到默认分支或者压根不报错。
- `as` 类型转换的读法：`(a as i64) < (instr.imm_i)` 和
  `(a < imm)`（无符号比较）在同一个 `match` 里出现，对应 `SLTI`（有符号）
  和 `SLTIU`（无符号）——这一行代码本身就是"同一个比较指令，两种语义"的
  最好例子，建议对着 RISC-V 手册确认自己理解了为什么 `SLTIU 0` 永远是
  false 当且仅当立即数被当成无符号数看待。

### 动手练习

自己实现 ADD/ADDI/SUB/异或/移位 + 六种分支 + JAL/JALR + LUI/AUIPC，跑通
`tests/fib.bin`（一个纯 ALU + 分支的递归/循环 fib 实现，不触碰内存）。

### 验收标准

```sh
cargo run --release -- fib
# a0 = fib(80) = 23416728348467685 (expected 23416728348467685, match = true)
```

这一个数字和 Python 版 `uv run python3 -m riscvm.emulator tests/fib.bin` 跑出来
的完全一致——这是整个项目"Python 实现是 Rust 实现的语义 ground truth"这
条原则第一次被验证的地方。

---

## Stage 2：MEM——真实内存总线

**目标**：引入 RAM 设备和 LOAD/STORE，程序第一次能真正读写内存、使用栈。

### 原理问题

1. 为什么内存访问要限制在 1/2/4/8 字节这几种尺寸？如果允许任意字节数的读
   写，会给硬件设计带来什么麻烦？
2. "小端序"（little-endian）具体是什么意思？`0xdeadbeef` 写到地址 `0x10`
   之后，`0x10` 这个字节位置存的是 `0xef` 还是 `0xde`？
3. 程序的"栈"在这个模拟器里到底是什么——是不是就是一块被当成栈来用的普通
   RAM？CPU 硬件层面知道"这是栈"吗？

### 读代码

Python 用 `bytearray` 切片配合 `int.from_bytes`/`to_bytes` 做大小端转换：

```python
# riscvm/ram.py:18-30
def read(self, address, size):
    if size in (1, 2, 4, 8):
        return int.from_bytes(self.data[address:address + size], 'little')
def write(self, address, size, value):
    if size in (1, 2, 4, 8):
        self.data[address:address + size] = (value & ((1 << (size * 8)) - 1)).to_bytes(size, 'little')
```

Rust 第一版会很自然地写成 `self.data[a..a+size as usize]`，但 `rv64rs`
里 `size` 虽然只有 4 种取值，切片长度却必须是**编译期已知的字面量**才能
让编译器生成一条 scalar load 指令；否则即便 `size` 运行时永远是 1/2/4/8
之一，编译器也只能按"任意长度"生成代码，也就是调用 `memmove`：

```rust
// rv64rs/src/ram.rs:40-49
fn read(&mut self, address: u64, size: u8) -> Result<u64, EmuError> {
    let a = address as usize;
    match size {
        1 => Ok(self.data[a] as u64),
        2 => Ok(u16::from_le_bytes(self.data[a..a + 2].try_into().unwrap()) as u64),
        4 => Ok(u32::from_le_bytes(self.data[a..a + 4].try_into().unwrap()) as u64),
        8 => Ok(u64::from_le_bytes(self.data[a..a + 8].try_into().unwrap())),
        _ => error(format!("invalid address size {address}")),
    }
}
```

这一处的注释直接写明了性能账：早期版本用 `a..a+size`（`size` 是运行时变
量）编译出真正的 `memmove()` 调用，在整机启动这个 benchmark 里占了
**5-6%** 的采样时间——这是 `perf P3` 修复的问题，先在这里埋个伏笔，后面性
能优化一节会回来细讲。

### Rust 语言点

- `try_into().unwrap()`：`&[u8]` 切片转定长数组 `[u8; N]` 在 Rust 里不是
  免费的类型转换（切片长度是运行时信息，数组长度是编译期信息），需要一
  次可能失败的转换；这里 `unwrap()` 是安全的，因为 `a..a+2` 这种字面量长
  度切片保证长度正好是 2。
- 对比 Python 的 `int.from_bytes(..., 'little')`：Rust 标准库把"从小端字
  节数组构造整数"做成了每个整数类型自带的关联函数 `u16::from_le_bytes`，
  不需要像 Python 一样传一个字符串 `'little'` 当参数。

### 动手练习

给寄存器 `sp`（`x2`）搭一个栈，写一段手工指令序列做 `push`/`pop`（或者用
一个简单的递归函数），验证栈指针增减方向和 LOAD/STORE 的地址计算对得上。

### 验收标准

`cargo test`（对应 `tests/test_mem.py`/`test_bus.py`）+ 一个真正用到栈的
程序跑对，参考 `cargo run --release -- stack-demo`。

---

## Stage 3：指令集补完——RV64M 与压缩指令（RVC）

**目标**：把 `make next` 开发循环会遇到的坑提前填上：乘除法、16 位压缩指令。

### 原理问题

1. RVC 压缩指令的核心动机是什么？文档里提到"50%-60% 的指令可以替换成压
   缩形式，代码体积减少 25%-30%"——这个体积优势在什么场景下比"指令多一
   倍译码逻辑"的复杂度成本更值得？
2. `MUL`/`MULH`/`MULHSU`/`MULHU` 都是"乘法"，但一条 64×64 乘法的结果有
   128 位，硬件只有 64 位寄存器——这四条指令分别在解决什么问题？
3. 为什么"找下一条指令来实现"（`make next`）是一种合理的开发策略？相比
   "照着 ISA 手册把所有指令实现一遍再测试"，它的优劣是什么？

### 读代码

`riscvm/rv64i.py` 里 `Mnemonic` 枚举把 RV32I、RV64I、Zicsr、RV32M、RV64M
一次性全列出来了（`riscvm/rv64i.py:75-160`），但**实现**是一条条按需补
的——这是 git log 里能看到的一长串 `add mul`、`Implement RV64M
multiply/divide/remainder extension` 之类提交的由来：先把指令表列全，再
靠真实内核暴露"这条还没实现"来驱动进度。

RVC 是完全独立的一套解码器，9 种指令格式（`riscvm/rv64c.py:36-`起的
`RVC_Type` 枚举），因为 16 位指令的字段布局和 32 位指令完全不共用位置。

### Rust 语言点

- Rust 版 `rvc.rs`（424 行）单独成模块，不与 `execute.rs`（RV64I 的执行
  逻辑）混在一起，这对应 Python 里 `rv64c.py` 和 `rv64i.py` 是两个独立文
  件的划分——两边在"压缩指令自成一套解码/执行逻辑，只在 fetch 阶段按最低
  两位分流"这一点上的架构决策完全一致（参考 Stage 0 讲过的
  `cpu.py`/`cpu.rs` 里 `data & 0b11` 的分流逻辑）。
- 乘除法要留意 Rust 里 `i64`/`u64` 的 `wrapping_mul`/`checked_div` 之类
  方法，尤其是 `DIV`/`REM` 遇到除以 0 或者 `i64::MIN / -1` 溢出时 RISC-V
  规范定义的行为（不是异常，是定义好的特殊返回值）——这是一个很好的机会
  去读 RISC-V 手册里"除零不触发异常"这条和大多数 CPU 架构（会触发异常）
  不同的设计。

### 动手练习

按 `rv64rs/README.md` 里描述的开发循环，自己走一遍：

```sh
cargo run --release -- xv6-boot ../tests/kernel64gc_nopageflush.bin
```

看它在哪条指令上停下、报什么错，去 `tools/as.py --dis` 或者仓库自带的
`dump64gc.txt`/`ref_dump64gc.txt`（QEMU 的参考反汇编）里核对这条指令该怎
么译码，再实现它。这正是 `CHEATSHEET.md`"dev scenarios"一节描述的原始
开发方式。

### 验收标准

`cargo test`（`tests/isa.rs` 覆盖 M 扩展、`rvc.rs` 内建单测覆盖压缩指
令），以及能用 `kernel64gc_nopageflush.bin` 复现"跑到哪不认识就补哪"的
循环。

---

## Stage 4：特权态 / CSR / Trap

这是全项目公认"坑最多"的一站——`rv64rs/PLAN.md` 原话是"没有这层，ECALL、
系统调用、后面的中断和分页都无从谈起"，且"`trap.py` 整份 158 行都值得直
接对照移植，现成的注释已经把坑点写清楚了"。

### 原理问题

1. 为什么需要三个特权级（M/S/U）而不是只有"内核态/用户态"两级？RISC-V 里
   S 模式存在的意义是什么（提示：想想虚拟化和"OS 内核本身也不完全信任固
   件"这个场景）？
2. `sstatus`/`sie`/`sip` 在真实硬件上根本不是独立的存储，而是 `mstatus`/
   `mie`/`mip` 的一个"位掩码视图"。如果模拟器里 `sstatus` 和 `mstatus`
   各自用一个变量存，写 `mstatus` 之后读 `sstatus` 会看到什么后果？为什
   么 xv6 会同时依赖两者保持一致（提示：`start()` 直接写 `mstatus.MPP`，
   而 `push_off()`/`pop_off()` 操作的是 `sstatus.SIE`）？
3. `medeleg`/`mideleg`"委托"机制是做什么的？如果一个中断被委托给 S 模式
   处理，但触发时 CPU 已经在 M 模式，应该怎么处理（提示：只有*从更低特权
   级陷入*才会走委托路径）？
4. 为什么机器模式独占的中断（软件/定时器/外部，编号 3/7/11）永远不能被
   委托，即使 `mideleg` 里对应位被置 1？

### 读代码：CSR 别名

Python 用一个小 dict 把"别名 CSR 地址"映射到"真实存储地址 + 掩码"：

```python
# riscvm/trap.py:44-64
_ALIASED = {
    CSR.SSTATUS.value: (CSR.MSTATUS.value, SSTATUS_MASK),
    CSR.SIE.value: (CSR.MIE.value, SIE_MASK),
    CSR.SIP.value: (CSR.MIP.value, SIP_MASK),
}
def csr_read(cpu, addr):
    alias = _ALIASED.get(addr)
    if alias:
        base_addr, mask = alias
        return cpu.csrs.get(base_addr, 0) & mask
    return cpu.csrs.get(addr, 0)
```

Rust 版用 `match` 加 `Option` 表达同一件事：

```rust
// rv64rs/src/trap.rs:50-65
fn aliased_target(addr: u32) -> Option<(u32, u64)> {
    match addr {
        csr::SSTATUS => Some((csr::MSTATUS, SSTATUS_MASK)),
        csr::SIE => Some((csr::MIE, SIE_MASK)),
        csr::SIP => Some((csr::MIP, SIP_MASK)),
        _ => None,
    }
}
pub fn csr_read(cpu: &Cpu, addr: u32) -> u64 {
    if let Some((base_addr, mask)) = aliased_target(addr) {
        cpu.csrs.get(base_addr) & mask
    } else {
        cpu.csrs.get(addr)
    }
}
```

**对比要点**：`Option<(u32, u64)>` 和 Python 的 `dict.get(addr)` 返回
`None`/元组是同一个思路，但 `if let Some(...) = ... else ...` 强迫你在
分支里明确处理"有别名"和"没别名"两种情况，少一种情况都编译不过。这是
"用类型系统替代运行时判断"的一个典型例子。

### 读代码：trap 委托

两边 `raise_trap` 的逻辑几乎逐行对应，值得把 Python 和 Rust 两个版本并排
读一遍（`riscvm/trap.py:66-101` vs `rv64rs/src/trap.rs:87-122`），重点看
这几行：

```python
# riscvm/trap.py:73-74
if is_interrupt:
    deleg &= MIDELEG_DELEGATABLE_MASK  # M-mode-only causes (3, 7, 11) can never delegate
delegate = cpu.mode != PrivilegeLevel.M.value and (deleg >> cause) & 1
```

这一行直接回答了原理问题 4：不管 `mideleg` 写了什么，`MIDELEG_DELEGATABLE_MASK`
永远把 bit 3/7/11 强制清零，模拟"硬件把这几位硬接到 0"这件事。

### Rust 语言点

- 注意 `rv64rs/src/csr.rs:1-4` 的注释：CSR 地址和特权级**没有**做成 Rust
  `enum`，而是普通 `pub const u32`/`u8`。这是刻意的设计选择——因为 Python
  这边 `cpu.mode` 就是个裸 int、`cpu.csrs` 就是个裸 dict，做成强类型
  `enum` 反而会让两边代码在结构上不对称，不利于逐行对照。这是一个很好的
  提醒：**Rust 里"能用强类型"不等于"任何时候都该用强类型"**，这里选择
  和 Python 的"松散"程度保持一致，是为了这个特定项目的目标（教学对照）
  服务，不代表这是通用最佳实践。
- `csr_write` 在 Rust 版多了一段 Python 版没有的逻辑（`rv64rs/src/trap.rs:74-82`）：
  写 `satp` 时顺带 `cpu.tlb.flush()`。这是 Stage 6/性能优化阶段才引入的
  TLB 需要的正确性保证，提前在这里留意，后面会再回来讲为什么“加什么新状
  态就要在这里补一次失效”。

### 动手练习

自己实现一个会触发 `ECALL` 的最小程序，手动检查陷入之后 `scause`/`sepc`/
`mode` 是否符合预期，再对照 `medeleg` 设为全 1 和全 0 两种情况下行为的区
别。

### 验收标准

直接把 `tests/test_trap.py`（240 行，覆盖委托、别名、优先级）的用例挪到
Rust 侧跑一遍——`rv64rs/tests/trap.rs` 已经是移植版，可以先自己实现完再
对照。

---

## Stage 5：MMIO 设备——CLINT 定时器、UART 控制台、PLIC 中断控制器

**目标**：让内核第一次能"被打断"、能往外打印字符。

### 原理问题

1. "MMIO"（内存映射 I/O）是什么意思？为什么 CPU 访问 UART 寄存器和访问一
   块普通 RAM，在指令层面是同一条 `LOAD`/`STORE`，区别完全在总线路由？
2. `CLINT` 的 `mtime`/`mtimecmp` 机制是怎么产生"定时器中断"的？为什么它需
   要每条指令都被"tick"一次，而不是像真实硬件那样由独立的时钟晶振驱动？
3. PLIC 的 `priority`/`enable`/`threshold`/`claim` 分别在解决什么问题？
   一个中断源要同时满足哪些条件才会真正被 CPU 感知到？
4. 为什么这个模拟器里"完成中断"（PLIC 的 claim/complete 协议里的
   complete 步骤）是个空操作？

### 读代码：CLINT 的驱动方式

```python
# riscvm/clint.py:28-32
def tick(self, amount=1):
    self.mtime = (self.mtime + amount) & ((1 << 64) - 1)
def pending(self, hart=0):
    return self.mtime >= self.mtimecmp[hart]
```

```python
# riscvm/cpu.py:46-57 （CPU.fetch 的开头）
def fetch(self):
    if self.clint is not None:
        self.clint.tick()
    ...
    check_interrupt(self)
```

**注意调用位置**：`tick()` 是在 `fetch()` 里、每条指令都调用一次，不是靠
真实时间。这个模拟器里"一个时钟周期"约等于"一条指令"，这是软件模拟时间
和真实硬件时间的一个根本性的近似——想一想这个近似在什么场景下会失真（提
示：模拟器跑得越快，同样数量的 guest 指令对应的"墙上时间"越短，如果软件
按真实时间设置超时会怎样）。

### 读代码：PLIC 的中断源建模

```python
# riscvm/plic.py:41-59
def _pending_mask(self):
    mask = 0
    for irq, device in self.devices_by_irq.items():
        if getattr(device, 'interrupt_status', 0) & 1:
            mask |= 1 << irq
    return mask

def _claim_irq(self, context):
    candidates = self._pending_mask() & self.enable.get(context, 0)
    threshold = self.threshold.get(context, 0)
    best_irq, best_priority = 0, threshold
    for irq in range(1, MAX_IRQ):
        if candidates & (1 << irq) and self.priority[irq] > best_priority:
            best_priority = self.priority[irq]
            best_irq = irq
    return best_irq
```

Python 靠 `getattr(device, 'interrupt_status', 0)` 这种"鸭子类型 + 反
射"直接问设备对象要它的中断线状态。Rust 没有反射，`plic.rs` 用注册一个
闭包的方式达到同样效果：

```rust
// rv64rs/src/plic.rs:82-98
pub fn register_irq(&mut self, irq: u32, status: impl Fn() -> u32 + 'static) {
    self.devices_by_irq.push((irq, Box::new(status)));
}
fn pending_mask(&self) -> u32 {
    let mut mask = 0u32;
    for (irq, status) in &self.devices_by_irq {
        if status() & 1 != 0 { mask |= 1 << irq; }
    }
    mask
}
```

调用方（`emulator.rs`）这样注册：

```rust
// rv64rs/src/emulator.rs:113-117
let mut plic = Plic::new(PLIC_SIZE);
let uart_for_plic = uart.clone();
plic.register_irq(UART0_IRQ, move || uart_for_plic.borrow().interrupt_status());
```

**对比要点**：Python 的"鸭子类型"在这里换成了 Rust 的**闭包 + trait
bound**（`impl Fn() -> u32 + 'static`）。效果等价（PLIC 不需要知道
UART/VirtIOBlk 的具体类型），但 Rust 版本把"我需要一个能返回 u32 的东
西"这个约束写进了类型签名，编译期就能保证传进来的闭包签名对得上；Python
版本要等到真的调用 `getattr` 失败才会在运行时暴露类型不匹配。

### Rust 语言点：`Rc<RefCell<T>>` 登场

这一站第一次出现 `Rc<RefCell<Uart>>`，这是整份指南里第一个"绕不开"的所有
权话题：

- Python 里 `XV6.__init__` 把**同一个** `uart` 对象既 `bus.add_device(uart, ...)`
  放上总线，又 `self.cpu.uart = uart` 让 CPU 直接持有——Python 里"共享同
  一个对象"是默认行为，任何一边改了字段，另一边读到的都是新值，因为它们
  本来就是同一块内存。
- Rust 的所有权规则默认**不允许**一份数据同时被两个地方"拥有"（谁负责在
  用完后释放？）。`Rc<T>`（引用计数）解决"多个地方共享同一份数据"的问
  题；但 `Rc<T>` 本身只给不可变共享访问，而 CPU 既要在 `fetch()` 里调用
  `uart.borrow_mut().poll_input()`，又要在总线读写时被设备自己改状态，所
  以还需要 `RefCell<T>` 把"borrow 检查"从编译期挪到运行时（`borrow()`/
  `borrow_mut()` 在冲突时 panic，而不是编译不过）。
- 读一下 `rv64rs/src/bus.rs:28-34` 的 `SharedDevice<T>` 包装类型——它存在
  的唯一目的就是让"同一个 `Rc<RefCell<T>>` 既能塞进 `Bus` 的 `Vec<Box<dyn
  Device>>`，又能被 `Cpu` 单独持有一份"这件事对 `Bus` 来说是透明的。
- **这里可能会问的问题**：为什么不干脆用一个普通的可变引用
  `&'a mut Uart`，靠生命周期标注（lifetime）来让编译器静态检查借用冲
  突，而要用 `Rc<RefCell<T>>` 把检查推迟到运行时？答案是工程上的取舍：
  `Cpu`、`Bus`、`Uart`/`Clint`/`Plic` 之间的引用关系是**互相交织**的
  （`Cpu` 要拿 `Uart`，`Bus` 也要拿同一个 `Uart`，`Plic` 还要拿闭包间接
  引用 `Uart` 的状态），如果都用带生命周期参数的引用去表达，`Cpu`/`Bus`
  这些结构体全部要带上生命周期参数（变成 `Cpu<'a>`、`Bus<'a>`），而且这
  些生命周期参数会一路"传染"到所有用到它们的地方，还很容易在这种"多方
  共享、生命周期长度不完全一致"的场景里被编译器拒绝（借用检查器要求生
  命周期能在编译期证明足够长，但这里到底谁先释放、谁的生命周期该多长，
  在设计阶段并不总是能一次想清楚）。`Rc<RefCell<T>>` 用运行时引用计数
  和运行时借用检查换来了结构体定义的简洁——本质上是"先让代码能工作，把
  借用冲突的检查从编译期挪到运行时"，代价是冲突不再是编译错误，而是运
  行时 panic。这不是"逃避生命周期"，而是在这个共享关系错综复杂的场景
  里，运行时检查的心智成本明显低于把生命周期参数正确标注一遍的成本。

### 动手练习

实现一个最小 UART（只要 TX 寄存器能把字节写到 stdout 就算完成第一步），
让 xv6 打印出 `xv6 kernel is booting`；再接上 CLINT，验证真的能观察到至
少一次定时器中断被处理（比如打印一条 debug 日志，看它是否按预期间隔出
现）。

### 验收标准

`tests/test_uart.py` 对应用例通过；仿照 `test_emu.py::test_xv6_uart_console_input_reaches_the_shell`
的思路写一个注入式测试，验证键盘输入真的能传导到 shell。

---

## Stage 6：MMU——Sv39 分页

**目标**：内核开启分页后，取指和访存都要走地址转换。

### 原理问题

1. 为什么 xv6 大部分地址是"恒等映射"（VA == PA），却还必须开分页？（提
   示：读 `riscvm/mmu.py` 顶部注释提到的"per-process 内核栈和 trampoline
   放在高地址"）
2. Sv39 的三级页表 walk 具体在做什么？39 位虚拟地址被拆成哪几段，分别对
   应哪一级页表的索引？
3. 什么是"超页"（superpage）？为什么走到某一级页表条目发现它已经是叶子
   （设置了 R/W/X 位）就可以提前结束 walk，不用走到最底层？
4. 页表遍历如果三级都走完了还没找到有效的叶子条目，应该怎么处理？

### 读代码

Python 版 `translate()` 是这个模块里最值得逐行对照读的函数
（`riscvm/mmu.py:37-83`，只有 83 行）：

```python
# riscvm/mmu.py:49-65
vpn = [(va >> 12) & 0x1ff, (va >> 21) & 0x1ff, (va >> 30) & 0x1ff]
a = (satp & PPN_MASK) * PAGESIZE
level = LEVELS - 1
while level >= 0:
    pte_addr = a + vpn[level] * PTE_SIZE
    pte = cpu.bus.read(pte_addr, PTE_SIZE)
    if not pte & PTE_V:
        error(f'page fault: invalid PTE ...')
    if pte & (PTE_R | PTE_X):
        break  # leaf
    if pte & PTE_W:
        error(f'page fault: reserved PTE encoding (W without R/X) ...')
    a = ((pte >> 10) & PPN_MASK) * PAGESIZE
    level -= 1
else:
    error(f'page fault: page table walk exhausted ...')
```

**注意这个 Python 特有的写法**：`while ... else`。`else` 分支只在
`while` 循环**正常耗尽条件退出**（而不是被 `break` 跳出）时执行——这里
恰好用来表达"三级都走完了，从来没有 `break` 过，说明找不到叶子"，是
Python 里一个不太常用但很贴切的语法糖。

Rust 没有 `for...else`/`while...else`，`mmu.rs` 用一个哨兵变量表达同一件
事：

```rust
// rv64rs/src/mmu.rs:141-162
let mut level = LEVELS - 1;
let mut pte: u64;
loop {
    if level < 0 {
        return error(format!("page fault: page table walk exhausted ..."));
    }
    let pte_addr = a + vpn[level as usize] * PTE_SIZE;
    pte = cpu.bus.borrow().read(pte_addr, PTE_SIZE as u8)?;
    if pte & PTE_V == 0 { return error(...); }
    if pte & (PTE_R | PTE_X) != 0 { break; }
    if pte & PTE_W != 0 { return error(...); }
    a = ((pte >> 10) & PPN_MASK) * PAGESIZE;
    level -= 1;
}
```

**动手想一下**：为什么 Rust 版本要把"耗尽检查"挪到循环**顶部**（`if
level < 0 { return error }`）而不是像 Python 一样放在循环末尾的 `else`
里？这其实是同一个逻辑的两种表达方式——想清楚它们是否真的等价，还是在边
界条件（比如 `LEVELS == 0`）上有微妙差别。

### Rust 语言点：`Result<T, E>` 和 `?`

这一站是全项目 `Result`/`?` 用得最密集的地方。Python 用 `error(...)` 抛
异常来表达"翻译失败"，调用栈上层用 `try/except InternalException` 兜底
（`riscvm/emulator.py:113-117`）。Rust 没有异常机制，`translate()` 返回
`Result<u64, EmuError>`，调用方用 `?` 把错误直接向上传播（`rv64rs/src/mmu.rs:148`
的 `cpu.bus.borrow().read(pte_addr, PTE_SIZE as u8)?`）——这一行如果
`read` 失败，函数立即返回那个错误，等价于 Python 里异常自动向上抛，但
**没有隐藏的控制流**：`?` 出现在源码里，一眼就能看出这里可能提前返回，
不需要去翻函数签名之外的地方确认"这个调用会不会抛异常"。

### 动手练习

先不看 `mmu.rs`，自己实现三级页表 walk，用 `tests/test_mmu.py`（100 行，
异常路径覆盖得很全）里的用例做参照——包括无效 PTE、权限不符、超页没对齐
这几种异常场景，不要只测"正常翻译成功"这一条路径。

### 验收标准

`tests/test_mmu.py` 全部用例通过；用真实 xv6 内核验证跨过 `kvminithart`
开启分页后不产生非预期缺页（Rust 版这一步把指令数从 317 提升到了 1080
万，这个数量级跳变本身就是"分页打开之后，内核开始真正大规模初始化内存"
的直接证据）。

---

## Stage 7：VirtIO 磁盘 + 真实文件系统

**目标**：让内核挂载 `fs.img`，跑到真正的 shell，执行 `ls`/`echo hello`。

### 原理问题

1. VirtIO 协议里的"描述符环"（descriptor ring）、"available ring"、"used
   ring"分别代表什么？为什么块设备驱动需要三个环而不是一个简单的请求/响
   应队列？
2. 这里的虚拟磁盘"设备"需要反过来读写"内存"——为什么？真实硬件里这对应
   什么机制？
3. 如果 VirtIOBlk 要读写的内存地址，恰好也在 VirtIOBlk 自己被调用的那次
   总线分发路径上，会发生什么问题？

### 读代码：为什么 `Bus` 从"整体一个锁"变成"每个设备槽一个锁"

这是全项目**所有权设计最深的一处**，`rv64rs/README.md` 专门用一段解释：

> `Cpu.bus` 是 `Rc<RefCell<Bus>>`（不是直接拥有一个 `Bus`），因为
> VirtIOBlk 需要通过它注册的同一条总线读写任意的 guest 内存……`Bus` 里
> 每个设备槽各自一个 `RefCell`，而不是整个 struct 外面套一个 `RefCell`，
> 是因为后者会在 VirtIOBlk 的重入访问上 panic。

具体展开：CPU 调用 `bus.read()` 时，要先 `borrow_mut()` 到 VirtIOBlk 那
个槽位去处理一次 `QUEUE_NOTIFY`；处理过程中 VirtIOBlk 自己又要通过
**同一条总线**去读写内存里的描述符表、avail/used ring——如果整个 `Bus`
只用一个 `RefCell` 包起来，这第二次访问会尝试再借用一次同一个
`RefCell`，在运行时直接 panic（"已经被独占借用，不能再借用"）。`rv64rs`
的解法是让 `range_manager` 和 `devices: Vec<RefCell<Box<dyn Device>>>`
的下标同构，每个设备各自持有自己的 `RefCell`（`rv64rs/src/bus.rs:148-166`
的注释把这段来龙去脉写得很清楚，值得完整读一遍）——borrow 冲突只会发生
在"同一个设备槽被重入访问"时，而 VirtIOBlk 重入访问的是**内存设备的槽
位**，不是自己的槽位，所以不会冲突。

Python 完全不会遇到这个问题：`riscvm/bus.py` 里 `self.devices` 就是个普
通 dict，`device.write(...)` 内部想怎么再调用 `bus.read(...)` 都行，
Python 的对象模型没有"借用检查"这个概念，代价是如果真的写出一个无限递归
的重入调用，Python 只会栈溢出，而不会在设计阶段就被 Rust 的借用检查器提
前拦下来强迫你想清楚数据流向。

### 读代码：MMIO 寄存器表

`virtio.py`（255 行）和 `virtio.rs`（282 行）都是一长串寄存器地址常量 +
状态机（feature 协商 → 队列建立 → 处理 `QUEUE_NOTIFY`），这一部分建议直
接对照 `riscvm/virtio.py:26-50` 的寄存器表和 VirtIO 1.1 规范来读，不在这
里重复贴代码——这一站的重点不是"抄一遍协议字段"，而是理解上面那个所有权
设计问题。

### Rust 语言点

- `Rc` 引用计数会形成环：`Bus` 持有 `VirtIOBlk`，`VirtIOBlk` 持有指回
  `Bus` 的 `Rc`，这是一个引用循环，理论上会造成内存永远不被释放。
  `rv64rs/README.md` 明确说明"这里没关系，因为这是一次性跑完就退出的进
  程，没有长期运行、这个泄漏会累积的场景"。这是一个很好的例子说明 Rust
  的内存安全保证（不会有悬垂指针/use-after-free）和"绝对不会泄漏内存"是
  两件不同的事——`Rc` 循环引用是 Rust 里少数几种编译器不会替你挡住的资
  源问题之一。

### 动手练习

不需要从零实现整个 VirtIO 协议（工作量很大且协议细节繁琐），但至少要能
回答："如果我把 `Bus` 改回整体一个 `RefCell`，跑 `xv6-boot` 会在哪一步
panic？"——可以真的改一下代码试一次，观察 panic 信息，再改回来，这比单
纯读注释理解更深。

### 验收标准

```sh
cd rv64rs
cargo run --release -- xv6-time-to-shell
```

看到：

```
init: starting sh
$
[reached shell prompt after 19476480 instructions in 0.771s ...]
```

再手动跑一次交互式的 `cargo run --release -- xv6-boot ...`，敲 `ls`、
`cat README`、`echo hello`，确认它们都对着真实的 `fs.img` 生效。

---

## 性能优化 P1-P5：只有 Rust 版本走的一段路

Python 侧其实也做过两次很小的性能修复（`0c230b0` 消除 `actor()` 里重复
调用 `get_mnemonic()`，声称快 30%；`1c59c16` 用 `int.from_bytes` 合并
fetch 的多次读取），但量级和 Rust 这一轮完全不是一回事——这正是这一节想
讲的核心问题。

### 原理问题

1. `HashMap<u32, u64>` 在 Rust 里默认用 SipHash（专门为抵抗哈希碰撞攻击
   设计），P1 的 profile 显示它在这个 benchmark 里占了 15-17% 的采样时
   间。为什么"防止哈希碰撞攻击"这个安全特性，对一个只会读到自己内部数据
   （CSR 地址永远是程序自己生成的 12 位数）的场景来说是纯粹的浪费？
2. RISC-V 的 CSR 地址空间被定义为固定 12 位（`csr.py` 顶部注释直接引用了
   这条规范），这意味着"用得着的 key 集合"从一开始就是有限且已知的——这
   种情况下，数组和哈希表相比分别在时间复杂度、空间局部性上有什么差异？
3. Python 的 `dict` 是用 C 实现的哈希表，本身已经是这门语言里能拿到的最
   快的关联容器之一了——为什么"把 dict 换成数组"这种优化思路在 Python 里
   几乎不会被想到，而在 Rust 里是第一个被 profile 揪出来的问题？
4. P4 加的软件 TLB 为什么在这个项目里"之前调查过一次，结论是不值得做"，
   后来又推翻了这个结论？前后两次调查的差异到底在哪（提示：看
   `README.md` "On the TLB (P4) specifically" 一段）？

### 读代码

对照 Stage 4 讲过的 `Csrs`：

```rust
// rv64rs/src/csr.rs:30-58
/// This replaced a `HashMap<u32, u64>` after profiling showed it dominating
/// the boot-to-shell benchmark: SipHash ... accounted for ~15-17% of total
/// sampled time
pub struct Csrs(Box<[u64; 4096]>);
impl Csrs {
    pub fn get(&self, addr: u32) -> u64 {
        self.0[(addr & 0xfff) as usize]
    }
}
```

对照 Stage 5 讲过的 `Plic`，同一个模式在 P5 又出现了一次（`enable`/
`threshold` 从 `HashMap<u64,u32>` 换成 `[u32; 64]`，见
`rv64rs/src/plic.rs:36-44` 的注释），说明这不是一次性运气，而是"每条指令
都会摸一次的状态，只要用了哈希表就一定会在 profile 里冒出来"这个规律的
第二次印证。

Stage 2 提过的 `Ram::read`/`write`（P3）、Stage 0 提过的 `Bus` 直接索引
设计（P2）、Stage 6 的软件 TLB（P4）都已经在各自的站里讲过原理，这里只
汇总数字：

| 优化 | 改动 | boot-to-shell（2MB 内核） |
|---|---|---|
| baseline | — | ~2.96-3.09s（~6.3-6.6M instr/s） |
| P1 | CSR：`HashMap` → `[u64; 4096]` | ~1.96-2.06s |
| P2 | Bus 设备查找：二分 → 直接下标 | （profile 已证实，wall-clock 当时噪声较大） |
| P3 | Ram 读写按字面量长度切片，消除 `memmove` | ~1.97-2.04s |
| P4 | mmu.rs 加 256 项软件 TLB | ~1.06-1.08s |
| P5 | Plic `enable`/`threshold`：`HashMap` → `[u32; 64]` | ~0.76-0.78s |

### Rust 语言点：这一节真正想让你学到的东西

不是"数组比哈希表快"这个孤立结论（这是常识），而是：

- **Rust 的性能问题往往集中在数据结构选型和内存布局**，而不是算法复杂
  度本身——这五次优化没有一次改变了"这段代码在做什么"，全部是"同一件事
  换一种存储方式来做"。这和很多人对"Rust 天生快"的误解不同：Rust 只是
  给了你精确控制内存布局的能力和知道该往哪里看的 profiling 工具链（这
  里用的是 Xcode 的 `xctrace`），真正的性能来自你有没有用上这个能力。
- Python 版本"不会做"这类优化，不是因为 Python 程序员不懂，而是因为
  Python 的执行模型（解释器逐字节码分派、一切皆对象带来的间接寻址）本
  身的开销比"dict 查找 vs 数组索引"这几纳秒的差异大了两三个数量级——在
  那个尺度上，这类微优化根本不会浮出水面成为 profile 里的热点，这也是
  为什么两边"perf commit"的数量和深度差这么多：不是 Rust 项目更认真，
  而是 Rust 已经把"解释器开销"这一层大头去掉之后，接下来才轮到"数据结
  构选型"这一层小头。

### 动手练习

用 `cargo run --release --profile profiling`（配合 `rv64rs/Cargo.toml`
里的 `[profile.profiling]`）加系统自带的 profiler，自己找一次热点，而不
是直接抄 P1-P5 的结论——README 里坦率地说"当前 profile 剩下的热点大多是
未解析的内联地址，不是一个清晰的单点"，也就是说这条优化路径本身还没走到
头，可能还有你能自己找到的下一个 P6。

---

## 收尾：交互式终端与精确计时

最后两个提交解决的是"能用"而不是"能跑"的问题：

- `adf4aeb`/`5b72963`：加一个 `xv6-time-to-shell` CLI 模式，从"第一条指令
  执行前"精确计时到"UART 输出里出现 `$ `"为止，并统计"多少条指令是在分页
  关闭状态下跑的"（`kinit()` 在开分页之前要 zero-fill 全部物理内存，这一
  段 TLB 完全帮不上忙）——这是 Stage 6/性能优化两节提到的数字的来源。
- `2dc45a9`：给 `xv6-boot` 接上真正的交互式键盘输入。

### 读代码：非阻塞输入的两种写法

Python 用 `select.select` + 非阻塞文件描述符：

```python
# riscvm/uart.py:269-284（poll_input，节选）
ready, _, _ = select.select([self._input_fd], [], [], 0)
if not ready:
    return
chunk = os.read(self._input_fd, 256)
```

Rust 版按 `rv64rs/README.md` 的描述用了另一种模式：后台开一个专门阻塞读
stdin 的线程，通过 channel 把字节转发给主循环（见 `main.rs` 的
`spawn_stdin_reader()`），这样单线程的指令执行循环永远不会因为等键盘输入
而卡住。

### 原理问题

这是两种解决"不让主循环被 I/O 阻塞"的经典模式——**非阻塞轮询**（Python
这边）vs **专用线程 + 消息传递**（Rust 这边）。想一想：

1. Python 选非阻塞轮询而不是开线程，是不是和 GIL（全局解释器锁）的存在
   有关系？
2. Rust 选线程+channel而不是非阻塞轮询，`std::thread::spawn` 加
   `std::sync::mpsc` 这一套相比"手写一个非阻塞 read"，在正确性上少踩了
   哪些坑（提示：想一想 Python 版本 `poll_input()` 要处理
   `BlockingIOError`/`InterruptedError`/`OSError` 三种异常，Rust 版本的
   后台线程要处理什么）？

### 动手练习

自己实现一遍 `spawn_stdin_reader`，用到 `std::sync::mpsc::channel`、
`std::thread::spawn`，体会一下"所有权转移进线程闭包"（`move ||`）这件事
在这里为什么是必须的。

---

## 附录 A：Python ↔ Rust 速查表（贯穿全项目出现过的对应关系）

| 概念/需求 | Python 写法 | Rust 写法 | 出现在哪一站 |
|---|---|---|---|
| 定长同类对象集合 | 一堆 `Register` 对象 / list | `[T; N]` 数组 | Stage 0 |
| 接口/协议（不关心具体类型） | 鸭子类型（只要有同名方法） | `trait` + `Box<dyn Trait>` | Stage 0、5 |
| 稀疏映射，key 集合无界或很大 | `dict` | `HashMap`（但见下一行） | Stage 5（PLIC 早期版本） |
| 稀疏映射，key 空间小且固定 | `dict`（Python 里没必要换） | 定长数组，直接用 key 当下标 | Stage 4、5（perf P1/P5） |
| "可能没有值" | `dict.get(k)` 返回 `None`，或裸判断 | `Option<T>` | Stage 4 |
| 错误处理 | 抛异常（`error()` 里 `raise`），`try/except` | `Result<T, E>` + `?` | Stage 6 全程 |
| 多个地方共享同一份可变状态 | 默认行为（都是同一个对象引用） | `Rc<RefCell<T>>` | Stage 5、7 |
| 整数运算语义 | 任意精度整数，需要手工 `u64(...)` 截断/`i()` 符号扩展 | 原生定长整数类型 + `wrapping_*`/`as` 转换 | Stage 1 全程 |
| 反射式地查询对象能力 | `getattr(obj, 'attr', default)` | 提前注册闭包 `impl Fn() -> T` | Stage 5 |
| 循环耗尽 vs 提前退出的区分 | `for/while ... else` | 哨兵变量 + 显式检查，或 `loop` + `break` 携带值 | Stage 6 |
| 非阻塞 I/O | `select.select` + 非阻塞 fd | 专用线程 + `mpsc::channel` | 收尾一节 |

## 附录 B：调试与开发工作流备忘

- **"下一条指令在哪"循环**：`make next`（Python）/
  `cargo run --release -- xv6-boot ...`（Rust）跑到不认识的指令就会带着
  完整译码信息报错（操作码/各类立即数编码全部打印出来），照着 RISC-V 手
  册或者 `tools/as.py --dis` 反查该实现什么。
- **和真实硬件核对**：仓库里的 `dump.txt`/`dump64g.txt`/`dump64gc.txt`
  是这个模拟器自己产出的执行轨迹，`ref_dump.txt`/`ref_dump64gc.txt` 是
  QEMU 产出的参考轨迹——怀疑某条指令算错了的时候，两边对比是比"重新读一
  遍手册"更快的定位方式。具体做法：

  ```sh
  diff -u ref_dump64gc.txt dump64gc.txt | less   # 或者用 VSCode/Cursor 的
                                                   # "Compare with..." 文件对比视图
  ```

  两份轨迹一开始必然有大量无害差异（符号名、地址格式），**不要从头逐行
  看**：直接定位到 `diff` 输出的第一处真正分歧——通常是某个 PC 地址上两
  边执行的指令不一样，或者同一条指令执行后某个寄存器的值不一样。这一个
  分歧点几乎总能精确定位到"哪条指令译码错了"或"哪条指令语义算错了"，因
  为在那一点之前两边状态完全一致，之后才会因为这一条指令的错误开始越差
  越远（后续指令的寄存器/内存状态全部建立在错误结果之上）。养成"只看第
  一处分歧、不看后面雪崩式的连锁差异"的习惯，能省下大量误入歧途的调试
  时间。
- **Ctrl-C 现场保存**：两边的 CLI 都支持运行中按 Ctrl-C，打印全部寄存器
  和当前指令再退出，这在追查"卡死在哪"的问题时比加日志更快。
- **单元测试作为唯一的正确性锚点**：`tests/test_*.py` 是这个项目从
  Python 到 Rust 全程唯一被信任的"金标准"——`rv64rs/PLAN.md` 明确写了
  "移植现有 Python 测试用例的期望值，而不是重新设计测试"。这条原则值得
  在自己动手重写每一站时也遵守：先找到对应的 `test_*.py`，把它的输入和
  期望输出原样搬过去，而不是自己重新想一套测试数据。

## 还可以往下走的方向（项目本身尚未做的部分）

- 浮点数（F/D 扩展）完全没实现，两边都没有——如果想挑战更难的部分，这是
  一个现成的、有大量参考资料（RISC-V 手册第 F/D 章）但项目里没有答案可
  抄的方向。
- 指令/数据 Cache 模型：`README.md` 明确说这个没做，原因是 `Ram` 是一个
  `Vec<u8>`，访问本来就是 O(1) 真实开销，加一层 cache 模型不会让它更快，
  只会增加记账开销——但如果目标是**教学用的命中率统计**而不是提速，这仍
  然是一个有意义的练习（`rv64rs/PLAN.md` 最初就是把它列为"阶段 8"的可选
  进阶项）。
