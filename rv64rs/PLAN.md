# Rust 版 riscvm:分阶段实现计划

## Context（为什么做这件事）

`riscvm`（Python 实现）的提交历史本身就是一条清晰的教学路径：从最早的 ALU 指令（`d95e555 add andi`）、控制流（`c1dae7f add beq`、`6f7a4b3 add jal`），到引入真实内存总线支撑 xv6 内核栈（`9b9e3b7 add stack for xv6 kernel`），到特权态与陷阱（`1ce59e1 add mret`、当前分支的 `515ab76 Implement privilege-mode tracking, traps, and interrupts`），到 MMIO 设备（UART、CLINT、PLIC），到分页 MMU（`a13f8dc Implement Sv39 page-table translation`），再到磁盘（`34e6908`/`b72e60e VirtIO`）——每一步都是"跑一个真实内核 / 真实程序，缺什么补什么"驱动出来的。

在 Python/PyPy 上验证过 `tests/fib.bin` 的可行性后（做出一个能正确跑通 fib.bin 的最小 Rust 原型，语义验证通过：`a0=23416728348467685` 与 Python 测试期望值完全一致），我们希望把这条已经被验证过的教学路径，在 Rust 里**重新走一遍、分阶段实现**，而不是一次性照搬全部代码。目的不是"抄一遍 Python"，而是通过分阶段重建，加深对每一层实现细节（ALU → MEM → 特权态/Trap → MMIO → MMU → disk，甚至 TLB/Cache）的理解。

## 总体设计

**新增一个 Rust crate**：仓库根目录下新建 `rv64rs/`（与 Python 的 `riscvm/` 包并列，不替换它——Python 版本继续作为语义 ground truth）。模块划分尽量与 Python 包一一对应，方便对照阅读：

```
rv64rs/
  Cargo.toml
  src/
    main.rs        # CLI 入口，对应 riscvm/__main__.py + emulator.py 的 argparse 部分
    register.rs     # 对应 register.py
    bus.rs          # 对应 bus.py + rangemanager.py（trait Device { read/write }）
    ram.rs          # 对应 ram.py
    cpu.rs          # 对应 cpu.py（fetch/decode/execute 主循环）
    decode.rs       # 对应 rv64i.py 的指令解码部分
    execute.rs       # 对应 rv64i.py 的指令执行部分（阶段推进中逐步长大）
    rvc.rs          # 对应 rv64c.py（压缩指令，阶段 3）
    csr.rs          # 对应 csr.py（阶段 4）
    trap.rs         # 对应 trap.py（阶段 4）
    mmu.rs          # 对应 mmu.py（阶段 6）
    clint.rs        # 对应 clint.py（阶段 5）
    plic.rs         # 对应 plic.py（阶段 5）
    uart.rs         # 对应 uart.py（阶段 5）
    virtio.rs        # 对应 virtio.py（阶段 7）
    emulator.rs      # 对应 emulator.py 的 Emulator/XV6 组装逻辑
  tests/
    isa.rs, mem.rs, trap.rs, mmu.rs, uart.rs, virtio.rs   # 对应 tests/test_*.py
```

**贯穿所有阶段的验证策略**（这是最关键的部分,能保证每一步都不是"看起来对"）：
1. **移植现有 Python 测试用例的期望值**，而不是重新设计测试。`tests/test_isa.py`、`test_mem.py`、`test_trap.py`（240 行,已经覆盖特权态/CSR/中断的绝大多数场景）、`test_mmu.py`（100 行,Sv39 walk 的正确/异常场景都有）、`test_uart.py`、`test_virtio.py`（139 行,VirtIO 描述符环的场景都有）——这些已经是现成的、跑过真实内核验证过的规格说明,原封不动地把输入和期望输出搬到 Rust 的 `#[test]` 里即可。
2. **有条件时用运行中的 Python 引擎做交叉验证**：同一份输入（指令流/寄存器初值）分别喂给 Python 和 Rust,对比结束时的寄存器/内存/UART 输出,尤其适合 trap、MMU 这种状态多、手工编排期望值容易出错的阶段。
3. **每个阶段都有一个可运行、可演示的里程碑**（见下表"交付物"列),不是抽象的"实现了某个模块"。

## 分阶段目标

| 阶段 | 目标 | 覆盖范围 | 参考的 Python 文件 | 交付物（可演示的里程碑） | 验证方式 |
|---|---|---|---|---|---|
| **0. 骨架** | 打通 fetch/decode/execute 主循环和设备总线抽象,先不追求指令完整 | `Register`（x0 硬编码为 0）、`Bus` trait + `RangeManager`、`Cpu` 结构体骨架 | `register.py`、`bus.py`、`rangemanager.py`、`cpu.py` | `cargo build` 通过,一个空转的 fetch 循环 | 移植 `test_bus.py`（range 查找/读写）的用例 |
| **1. ALU + 控制流**（纯寄存器运算,无内存访问） | 把最小原型正式收编进项目结构 | OP-IMM/OP 全部整数运算、LUI/AUIPC、六种分支、JAL/JALR | `rv64i.py` 对应段落 | **`tests/fib.bin` 端到端跑通**,`a0 == 23416728348467685` | 移植 `test_isa.py` 里 ALU 相关用例 + `test_emu.py::test_fib` |
| **2. MEM**（真实内存总线） | 引入 RAM 设备和 LOAD/STORE,程序第一次能真正读写内存/使用栈 | `RAM` 设备、LB/LH/LW/LD/LBU/LHU/LWU、SB/SH/SW/SD、栈区布局 | `ram.py`、`bus.py`、`emulator.py` 里 `Emulator.__init__` 的栈搭建 | 一个用到栈的小程序（递归函数或手写的 push/pop 序列）跑对 | 移植 `test_mem.py` + `test_bus.py` |
| **3. 指令集补完**（RV64M + 压缩指令 RVC） | 把 `make next` 会遇到的坑提前填上：乘除法、16 位压缩指令 | MUL/DIV/REM 系列、RVC 的常见子集（C.ADDI/C.LI/C.J/... 视目标内核实际用到的来定） | `rv64i.py` 的 M 扩展部分、`rv64c.py` | 用 `tests/kernel64gc_nopageflush.bin` 复现 Python 项目当年的开发循环："跑到哪条指令不认识,就补哪条" | 移植 `test_isa.py`（M 扩展部分）+ `test_rvc.py`；用仓库里已有的 `dump.txt`/`dump64gc.txt` 参考轨迹核对译码 |
| **4. 特权态 / CSR / Trap** | 没有这层,ECALL、系统调用、后面的中断和分页都无从谈起 | 特权级 M/S/U、CSR 读写（含 sstatus/sie/sip 对 mstatus/mie/mip 的别名机制）、CSRRW 系列、ECALL/MRET/SRET、`raise_trap`（含 medeleg/mideleg 委托逻辑） | `csr.py`、`trap.py`（整份 158 行都值得直接对照移植,现成的注释已经把坑点写清楚了） | 一个触发 ECALL 的小程序,能正确落到 S 模式陷阱向量,`scause`/`sepc` 值对得上 | 直接移植 `test_trap.py` 的全部用例（这是现成度最高的一份测试,240 行覆盖了委托、别名、优先级） |
| **5. MMIO 设备**（CLINT 定时器 + UART 控制台 + PLIC 中断控制器） | 让内核第一次能"被打断"、能往外打印字符 | CLINT 的 tick 驱动 mtime/mtimecmp、UART 最小 TX/RX 子集（不必一次搬完 uart.py 全部 451 行,先满足 xv6 控制台需要的寄存器）、PLIC 的 priority/enable/claim | `clint.py`（47 行,很小）、`plic.py`（94 行）、`uart.py`（先做子集）、`trap.py::check_interrupt` | 屏幕上打出 `xv6 kernel is booting`,并且能观察到至少一次定时器中断被正确处理（进程被抢占） | 移植 `test_uart.py`；仿照 `test_emu.py::test_xv6_uart_console_input_reaches_the_shell` 写注入式测试 |
| **6. MMU**（Sv39 分页） | 内核开启分页后,取指和访存都要走地址转换 | 三级页表 walk、`SFENCE.VMA`、页表异常（invalid PTE / 权限不符 / misaligned superpage） | `mmu.py`（83 行,结构清楚,直接可对照翻译） | 内核跨过 `kvminithart` 开启分页后继续正常执行,不产生非预期缺页 | 直接移植 `test_mmu.py` 全部用例（100 行,已覆盖异常路径） |
| **7. 磁盘**（VirtIO block device + 真实文件系统镜像） | 让内核能挂载 `fs.img`,跑用户态程序 | VirtIO MMIO v2:描述符环、avail/used ring、块读写 | `virtio.py`（255 行） | 完整跑到 `$` shell 提示符,能交互执行 `ls`、`echo hello` | 移植 `test_virtio.py`；端到端注入 `ls\n`/`echo hello\n` 到 UART,核对输出 |
| **8. TLB / Cache（可选进阶）** | 功能正确性阶段 6 已经完成,这一步纯粹是为了理解内存层级的性能特征 | 在 `translate()` 前加一层 TLB（命中/缺失/`SFENCE.VMA` 触发的失效）,可选再加一层指令/数据 Cache 模型（命中率、可选的延迟建模） | 无对应 Python 实现——这是全新设计,不是移植 | 跑一次完整 boot,打印 TLB/Cache 命中率统计;如果做了延迟建模,能观察到访存模式对时间的影响 | 针对 TLB/Cache 结构本身写单元测试（命中/缺失/替换逻辑),不需要黄金参考,因为这是新增能力 |

## 执行方式

- **严格按阶段推进,一次只做一个阶段**：每个阶段完成 + 对应测试通过 + 里程碑演示成功后,再进入下一阶段。不要跨阶段并行开发,这样才能保证"通过实现过程加深理解"这个目标不被绕过。
- 阶段 4（特权态/Trap）是阶段 5（MMIO 中断）和阶段 6（MMU 用到的 satp CSR）共同的前置依赖,所以顺序上必须排在两者之前——这是按依赖关系排的工程顺序,不是严格复刻当年 Python 提交的时间顺序。
- 阶段 3（RVC 压缩指令)是否必须在阶段 2 之后立刻做,取决于目标内核二进制是否用到压缩指令（`tests/fib.bin` 目前看到的全是 4 字节指令,还不确定 `xv6-kernel-fs-small.bin` 是否需要 C 扩展）——这个问题留到执行阶段 3 之前用 `tests/kernel64gc_nopageflush.bin` 实测确认,计划里不预设答案。

## 每阶段独立 commit 的约定

- 每完成一个阶段就单独提交一次,commit message 里包含：该阶段新增/修改了哪些文件、`cargo test` 的通过数量、以及milestone 的实际运行输出（不是"预期应该"，是真的跑出来的结果）。
- 每个阶段对应的 commit 在该提交点上应当能独立 `cargo build` + `cargo test` 通过（不依赖后续阶段还未写的模块）。

## 验收标准（每阶段共同要求）

- 该阶段移植的测试全部 `cargo test` 通过。
- 该阶段的"交付物"里程碑能实际运行给用户看（不是"理论上应该能跑"）。
- 不跳过前一阶段的验证就开始写下一阶段的代码。
