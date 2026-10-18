# 单人开发 RISC-V CPU：阶段计划与 AI 提示词（soloplan.md）

> 2026-10-06 | 适用：一个人完成 CPU 2026 全部工作（14 周，中期检查第 7 周）
> 配套：`RISC-V-CPU-2026/docs/CPU开发流程.md`（总纲）、`aihelper.md`（提示词方法论）、`RISC-V-CPU-2026/docs/iface.md`（接口契约，单人可简化为个人备忘，但保留接口定义对防返工仍有用）
> 单人三原则：**顺序开发、风险前置、安全网先行**。AI 是你的"队友"：写骨架、写测试、做 code review、出审阅题。

---

## 0. 阶段总览（单人 10 阶段）

| 阶段 | 时间 | 主题 | 验收 | 里程碑 tag |
| --- | --- | --- | --- | --- |
| 0 | 第 1 周 | 环境与学习 | 框架四命令跑通 | — |
| 1 | 第 1–2 周 | 架构设计备忘 | 方案文档定稿 | `d0-design` |
| 2 | 第 1–2 周 | AXI 适配器 + 取指环 | 日志前 16 条指令字正确 | `m0-axi` |
| 3 | 第 2–3 周 | 译码/RF/ALU/乘除 + 自测 | 30 条自检断言全过 | `m1-exec` |
| 4 | 第 3–4 周 | 最小可运行 CPU | **三个基础程序全过（75 分安全网）** | `m2-basic` |
| 5 | 第 4–7 周 | 乱序核心（重命名/发射/ROB） | 乱序性自测 + 基础程序过；**第 7 周中期检查** | `m3-ooo` |
| 6 | 第 7–8 周 | 分支预测 + 正确性收敛 | `make test` 全过（85 分档） | `m4-correct` |
| 7 | 第 8–10 周 | I-cache + D-cache | IPC 明显提升、SRAM 面积入账 | `m5-cache` |
| 8 | 第 10–12 周 | 性能调优（IPC 冲档） | GEOMEAN ≥ 目标档位 | `m6-perf` |
| 9 | 第 12–13 周 | 综合与时序 | 面积/频率达档 | `m7-synth` |
| 10 | 第 13–14 周 | 报告与提交 | **第 14 周周六 23:59 前 OJ 提交** | `m8-submit` |

**单人简化决策**（对比双人方案砍掉的部分，省时间省复杂度）：

| 砍掉 | 替代方案 |
| --- | --- |
| 双人接口契约签字流程 | 个人《设计备忘》，接口写在 iface.md 供自己回查 |
| 顺序流水转发网络 | 阶段 4 全 stall（无转发），正确性优先；乱序阶段用唤醒/选择机制天然解决 |
| RAS 返回栈 | 只做 BTB + 2-bit BHT（IPC 差距小，复杂度差距大） |
| 多 MSHR、组相联 Cache | 先直接映射 + 单 MSHR；阶段 8 视 IPC 缺口再加 |
| mem_if 直通桥独立模块 | OoO 阶段直接调 axi_master 阻塞接口；D-cache 阶段再插 mem_if 薄封装 |

**风险前置顺序**（为什么阶段 2 先做 AXI 再做译码）：接口风险（AXI 死锁/退出协议）> 正确性风险（译码/乘除语义）> 复杂度风险（OoO）> 性能风险（Cache/预测）> 面积时序风险（综合）。

---

## 阶段 0：环境与学习（第 1 周）

**目标**：环境跑通；对平台规则形成条件反射。

- Fork 仓库 → clone → `git submodule update --init --recursive`
- 工具链三选一（AppImage / Docker / config.mk 原生路径）
- 最小 `student_top`（复位后向 `0x80000000` 写 `wstrb=4'hf`、返回 0）列入 `verilog/filelist.f`
- 跑通：`make help` / `make build` / `make run` / `make synth`

**AI 提示词（学习清单，直接可用）**：

```text
请阅读 RISC-V-CPU-2026/docs/axi4-lite.md、docs/sram.md、README-ZH.md 与 scripts/sim.cpp，
输出《平台硬约束清单》，必须包含：复位行为（高电平几拍）、地址空间与对齐、各通道队列深度、
内存延迟模型、程序退出协议（地址/wstrb/返回值/捕获时刻）、握手三条铁律（VALID 稳定性、
无组合环、AW/W 独立）、sram_fakeram 的时序与限制（1RW、读延迟、无复位、容量上限、
filelist 禁令）、指令集边界（实现 vs 免除 vs 不要求）。每条标注出处文件与章节。
这份清单将作为后续所有提示词的"【约束】"来源。
```

---

## 阶段 1：架构设计备忘（第 1–2 周）

**目标**：开工前把方案定死，单人也要写——它是你的"队友记录"与报告素材。

**产出**：`notes/design-备忘.md`，含：流水线框图、模块清单与接口（引用 iface.md）、参数表与默认值、分支恢复方案（checkpoint vs 回放）、访存顺序方案（Store Buffer 结构）、10 周内里程碑。

**AI 提示词（设计讨论，先方案后代码）**：

```text
请先不要写代码。目标：RV32IM 乱序执行 CPU（操作数就绪即乱序发射、ROB 按序提交；
发射宽度/ROB 深度/PRF 大小/保留站深度/Cache 参数必须参数化）。请给出：
1. 流水线框图（文字版）与模块职责、模块间接口信号草案；
2. 重命名恢复方案对比（RAT checkpoint vs ROB 回放）：实现复杂度、恢复延迟、面积；
3. 访存顺序方案（Store Buffer、load 转发规则、store 提交时机）；
4. 单人 10 周实施顺序建议（从最小可运行内核到 OoO 的里程碑划分）。
每个方案附 2-3 句权衡说明（写报告直接用）。输出 Markdown。
```

---

## 阶段 2：AXI 适配器 + 最小取指环（第 1–2 周，风险最高先做）

**目标**：总线通路一次做对；验证 program.data 加载与读时序。

- `axi_master`：读/写双通路、在飞计数反压、退出 Store 识别（`exit_ack`）
- `student_top` 骨架：复位 5 拍处理、端口按框架模板逐位一致
- 最小取指环：复位后从 0 连续发 16 次读，`$display` 打印指令字

**AI 提示词**：

```text
【任务】实现 axi_master 与最小取指环。
【接口】按 RISC-V-CPU-2026/docs/iface.md 的 axi_master 定义（v1.0 草案），
AXI 侧端口与 docs/axi4-lite.md 的 student_top 模板逐位一致。
【约束】1) valid 拉高后保持到握手；valid 不得组合依赖 ready；B 响应必须能接收；
2) 复位高电平有效（启动 5 拍），复位期间全部输出为 0；
3) 在飞请求数用 parameter（默认 4）限制，rd_req_ready/wr_req_ready 只由内部计数决定；
4) AW 与 W 两通道保持同拍拉高（简化，避免"W 先于 AW"的等待窗口）；
5) 识别 0x80000000 + wstrb=4'hf 的退出写，在 bvalid&&bready 当拍置 exit_ack；
6) 关键握手点加可开关 $display。
【附加】写最小取指环：复位后连续读 16 条指令字并打印。
【输出】axi_master.sv + 临时 test_top.sv + 设计说明。
【验证】make build 后 make run PROGRAM=testcases/correctness_add_to_100/program.data
    EXPECTED=5050 LOG=run.log，检查前 16 条指令字与 program.data 一致。
```

---

## 阶段 3：译码 / 寄存器堆 / ALU / 乘除 + 自测（第 2–3 周）

**目标**：四个纯逻辑模块一次做对（后续所有阶段的复用资产）。

- 按 `notes/b-20261006-执行单元规格.md` 的编码表实现：decoder（45 条指令 + illegal）、regfile（x0 硬接线、写穿）、alu（含 eq/lt/ltu）、mdu（乘法单周期、除法迭代 33 拍 + 除零/溢出语义）
- test_top 30 条自检序列（规格文档第 6 节六组），`initial` 断言比对

**AI 提示词**：

```text
【任务】实现 decoder.sv、regfile.sv、alu.sv、mdu.sv。
【接口】严格按 docs/iface.md 与 notes/b-20261006-执行单元规格.md（指令编码表、立即数表、
ALU 编码表、乘除语义表全部已给定，直接照实现）。
【约束】1) decoder 纯组合，B/J 型立即数拼接重点自查；CSR/FENCE/ECALL/EBREAK/未知编码 → illegal=1；
2) regfile 写穿、x0 恒 0；3) alu 移位量取 b[4:0]，附 eq/lt/ltu 输出；
4) mdu：乘法单周期组合（MULH/MULHSU/MULHU 用输入符号扩展区分），除法非恢复式迭代、
除零/溢出按规格文档 4.2 语义表；5) start/busy/valid 握手。
【输出】4 个 .sv + test_top.sv：内置 30 条自检序列（规格文档第 6 节六组），断言全过打印 PASS。
【验证】make build + make run（EXPECTED 占位），观察断言输出全 PASS 后 tag m1-exec。
```

---

## 阶段 4：最小可运行 CPU（第 3–4 周）→ 75 分安全网

**目标**：**三个基础程序全过**。单人策略：不写转发（全 stall）、不写 Cache（直接 AXI）、分支 stall+flush。这个版本要"极简但结构清晰"，它是乱序改造的底稿。

- 取指（PC + axi_master 读）+ 5 级流水（F/D/E/M/W，全 stall）+ LSU（load 阻塞写回；store 走写通路）+ 退出协议
- mdu busy 停流水；load-use 停流水；分支在 E 级解析、flush D/E 级
- 先用 `LATENCY=1` 调通，再 `LATENCY=10` 回归

**AI 提示词**：

```text
【任务】把阶段 2/3 的模块组装成最小可运行 5 级流水 CPU（不做转发、不做 Cache）。
【结构】F：PC+取指（经 axi_master）；D：decoder+regfile 读；E：alu/mdu/分支解析；
M：LSU（load 等 rdata；store 经写通路）；W：写回。
【约束】
1. 数据冒险一律 stall（等待写回完成），禁止转发网络（单人简化决策）；
2. load-use、mdu busy 都必须 stall，stall 条件写成一张表再编码；
3. 分支/跳转在 E 级解析：方向 + 目标地址（rs1+imm 或 PC+imm），flush 掉 D/E 级指令；
4. JAL/JALR 链接地址 = PC+4，用 ALU_ADD 实现；
5. store：SB/SH 由 LSU 按地址低 2 位生成 wstrb；退出 Store（0x80000000, wstrb=4'hf）
   透传并等待 B 握手（exit_ack）后才可停止；
6. 复位 5 拍高电平；PC 复位为 0。
先输出 stall/flush 条件表与流水框图，我确认后再写代码。
【验证】make test Case=correctness_add_to_100 及向量乘、向量加三个用例 LATENCY=1 与
LATENCY=10 双档全 PASS → tag m2-basic（75 分安全网建立）。
```

---

## 阶段 5：乱序核心（第 4–7 周，中期检查）

**目标**：OoO + 按序提交完成，基础程序在乱序核心上通过。**单人按严格子任务顺序推进，每步自测后再进下一步。**

五个子任务（每个配一次 AI 会话）：

**子任务 1：重命名（PRF + RAT + 空闲列表）**

```text
【任务】实现 PRF + RAT + 空闲列表。参数化：PRF 大小、每周期重命名条数。
约束：旧物理寄存器在提交时回收；flush 时 RAT 恢复（方案：<checkpoint/回放>，先与我讨论
选型再实现）；x0 映射到固定物理 0；与 ROB 的 alloc_rob_id 联动。
【验证】test_top：连续重命名+写回+提交+flush 场景断言。
```

**子任务 2：发射队列**

```text
【任务】实现 issue_queue（参数化：IQ_DEPTH/ISSUE_WIDTH/WAKEUP_PORTS）。
唤醒：CDB tag 广播比较；选择：最老 ROB 号优先；flush：清空年轻条目并归还物理寄存器。
说明比较器数量与深度的面积关系（综合时重点监控对象）。
【验证】test_top：就绪乱序发射、唤醒后再发射、flush 归还三组断言。
```

**子任务 3：ROB 与按序提交**

```text
【任务】实现 ROB：按序分配、乱序完成、按序提交，COMMIT_WIDTH 参数化。
条目含 arch/phys 目标寄存器、完成位、异常/分支信息、PC；提交写架构寄存器堆并释放旧
物理寄存器；flush 清除年轻条目。
【验证】test_top：乱序完成顺序提交、头阻塞、flush 复用编号断言。
```

**子任务 4：Store Buffer 与访存顺序**

```text
【任务】实现 Store Buffer：store 提交后才真正写内存；load 转发决策表
（完全重叠/部分重叠/地址未知三种情形，地址未知先保守 stall）；
load 对更老未提交 store 的检查顺序。
【验证】test_top：store→load 重叠（同字/字节/半字）、地址未知 stall 断言。
```

**子任务 5：乱序核心集成 + 分支恢复**

```text
【任务】把重命名/发射队列/ROB/功能单元/CDB 组装成完整 OoO 数据通路，接入最小 CPU 的
取指与 axi_master（LSU 阻塞式直连）。分支错误在 BRU 解析后广播 flush：ROB、发射队列、
取指队列全部清空年轻条目，RAT 恢复（按子任务 1 选型），已发出的 AXI 写请求不可撤回
（设计上保证只有提交后的 store 才发写）。
【验证】1) 乱序性自测：构造"年轻指令先就绪"场景，$display 证明乱序完成；
2) 三个基础程序在 OoO 核心上全 PASS；3) 中期检查演示脚本：能现场解释乱序执行与提交逻辑。
【中期检查前】跑 make test 全量，记录通过率。
```

---

## 阶段 6：分支预测 + 正确性收敛（第 7–8 周）

**目标**：`make test` 全过（85 分档），同时预测器上线。

- BTB（直接映射）+ BHT（2-bit 饱和计数器）；预测错误经阶段 5 的 flush 路径恢复
- 跑通 correctness 全集：失败用调试模板定位（见下）

**AI 提示词（分支预测）**：

```text
【任务】实现 BTB + BHT（表大小参数化，先寄存器数组实现，面积超支再换 sram_fakeram）。
【约束】1) 预测在取指阶段给出；2) 与 ROB 恢复路径配合：执行后更新 BTB/BHT，
注意多条分支在飞时的更新竞态；3) 说明"预测命中但 BHT 状态错误"如何不破坏正确性
（恢复路径兜底）。
【验证】make perf 分支密集基准 IPC 对比阶段 5 提升。
```

**AI 提示词（调试模板，正确性阶段高频使用）**：

```text
make test Case=correctness_xxx FAIL，日志：<粘贴 LOG 与 $display 输出>。
相关模块：<文件路径>。我的怀疑：<可空>。
请：1) 只分析不改码；2) 按可能性排序给出根因假设与日志证据；
3) 给每个假设一个最小验证实验（加一条 $display 或改参数重跑）。
```

**验收**：`make test` 全 PASS，`LATENCY=1/10` 双档绿 → tag `m4-correct`。

---

## 阶段 7：I-cache + D-cache（第 8–10 周）

**目标**：缓存上线，IPC 有明显提升。**顺序：先 I-cache（简单、收益确定）→ 再 D-cache。**

**AI 提示词（I-cache）**：

```text
【任务】实现 I-cache：只读、容量/行大小参数化、直接映射、单 MSHR。
【约束】sram_fakeram 规则（1RW、1 周期读延迟、valid 用寄存器复位、单实例 ≤ 2 MiB、
不进 filelist）；miss 重填期间取指停顿；与分支 flush 并发时的请求丢弃语义要定义清楚。
【验证】make perf 对比阶段 6 基线，记录 IPC 提升。
```

**AI 提示词（D-cache）**：

```text
【任务】实现 D-cache：容量/行大小参数化、直接映射、write-back、单 MSHR。
【接口】核心侧按 iface.md 的 mem_if 端口（先做 v1 直通桥薄封装接入核心，再实现 cache
替换内部逻辑，接口不变）。
【约束】1) tag/data 阵列用 sram_fakeram，数据阵列 WRITE_GRANULARITY=8 支持字节掩码；
2) 单端口 1RW：每阵列每周期一次访问，写明端口分配；3) 读延迟 1 周期，命中两拍出数；
4) valid 寄存器复位；5) dirty 换出经 axi_master 写回；6) 与 Store Buffer 的接口：
store 提交写入路径、load 转发优先级（先查 Store Buffer 再查 cache）。
先输出阵列划分/端口分配表/miss 状态机/面积粗算（0.0419904 μm²/位），再写代码。
【验证】命中/miss/换出/字节写读回/dirty 回写自测；make test 全绿回归；tag m5-cache。
```

---

## 阶段 8：性能调优（第 10–12 周）

**目标**：IPC 几何平均冲档（0.6000 / 0.8450 / 1.0985）。单人全权扫描，**数据必须实测，不允许 AI 编数字**。

**AI 提示词（扫描方案设计）**：

```text
我的基线：<粘贴 make perf 表格与 GEOMEAN、make synth 面积>。
请：1) 分析各基准瓶颈特征（访存密集/分支密集/依赖链）；2) 按性价比给 6 条优化建议；
3) 设计参数扫描矩阵（发射宽度 1/2/4 × ROB 32/64/128 × PRF 48/64/96 × 保留站深度 ×
Cache 容量/相联度 × MSHR 数），给出执行顺序与每轮预计耗时；
4) 给我一张记录表模板（参数 → IPC → 面积 → 频率 → 备注）。
```

**AI 提示词（每轮数据分析，循环使用）**：

```text
本轮扫描数据：<粘贴表格>。请：1) 找各参数敏感度与拐点；2) 结合面积预算
（<9000/18000/36000> μm²）推荐下轮 3 组候选；3) 指出已无收益的参数。只用实测数据。
```

**验收**：确定最终参数组合；`make perf` GEOMEAN 达标 → tag `m6-perf`。

---

## 阶段 9：综合与时序（第 12–13 周）

**目标**：面积 ≤ 档位上限、频率 ≥ 300 MHz（400/500 有加分）。

```text
请分析综合报告：<粘贴 build/synth/diagnose/report.txt 与 timing.rpt 关键段>。
回答：1) 关键路径起止点与瓶颈逻辑（列出延迟最大几级）；2) 面积前三模块及合理性；
3) 3 条可操作优化（按性价比排序）与面积/频率代价预估；
4) 若瓶颈在 SRAM clock-to-q（与 DEPTH/WIDTH 相关），是否值得拆分实例。
```

**流程**：`make synth MODE=diagnose` 定位 → 重构 → `make synth`（opt）→ 用 `CLOCK_PERIOD_NS=2.0/2.5/3.333` 迭代 → 每轮后 `make test` 回归。

**验收**：`Estimated frequency ≥ 300 MHz`、slack 为正、面积入档 → tag `m7-synth`。

---

## 阶段 10：报告与提交（第 13–14 周，DDL 第 14 周周六 23:59）

**AI 提示词（报告起草）**：

```text
【任务】起草实验报告两章：1) 参数敏感度分析；2) 架构探索总结。
数据：<粘贴共享总表（参数→IPC→面积→频率）与你的权衡笔记>。
要求：1) 只用提供的数据，禁止编造；2) 敏感度分析按"参数→趋势→微架构原因"三层组织，
每结论标注数据点；3) 架构探索按"尝试→问题→权衡→选择"叙事。
```

**提交清单**（照 aihelper.md 附录 / README 的 OJ 章节）：
- `student_top` 命名与端口逐位一致；filelist 相对路径齐全；无 sram stub、无 blackboxes.txt；
- `config.mk` 无本机路径；`make`（或 `make code`）能产出 `./code`；
- `make test/perf/synth` 全量复现报告数字；
- 归档与 AI 的对话记录（Code Review 会查）→ tag `m8-submit`。

---

## 附录 A：单人特有的 AI 用法

1. **让 AI 当 code reviewer**（无人互审的替代）：

```text
请 review 我的 <模块> 代码：<粘贴>。维度：1) 握手合规性（对照 docs/axi4-lite.md）；
2) 复位与时序边界；3) 潜在死锁；4) 面积热点；5) 可测试性。逐条列问题与严重度，
先不改代码，我确认后再逐条修。
```

2. **让 AI 出审阅题**（为 Code Review 面试储备）：

```text
假设你是一个会追问细节的审阅者，针对 <模块/设计决策> 列出 8 个最可能被问的问题，
每个附标准答案。我作答后再对照。
```

3. **让 AI 生成自测点**（每个模块交付前）：

```text
针对 <模块> 的接口语义，生成 10 个必须覆盖的自测场景（含边界值），输出成
test_top 的断言清单格式。
```

## 附录 B：单人纪律

- **每阶段至少一个 tag**；改动前 `git stash` 或开分支，保证任何时刻可回滚到上一个绿点。
- **回归优先**：任何"优化"合入前 `make test` 全绿；性能改动必须附 IPC 前后对比。
- **调试顺序**：`LATENCY=1` 隔离总线时序 → 单 `Case=` → 全量；波形是最后手段。
- **每周节奏**：工作日推进当前阶段，周末跑全量回归 + 写笔记（`notes/solo-YYYYMMDD.md`）+ 归档 AI 对话。
- **时间红线**：第 4 周末必须建立 75 分安全网；第 7 周中期检查前 OoO 必须能跑通基础程序；
  第 10 周末 Cache 必须上线（否则性能分无从谈起）；第 12 周末参数扫描必须结束（留 2 周写报告）。
