# RV32IM 乱序执行 CPU 架构设计备忘（单人版）

> 2026-10-06 | 阶段 1 产出 | 对应 soloplan.md 阶段 1，tag `d0-design`
> 约定：所有参数可综合配置；接口细节以 `docs/iface.md` 为准，本文给出整体方案与未定案部分的草案。

---

## 1. 流水线框图（文字版）与模块职责

```
[按序前端]                    [乱序区]                                [按序后端]
┌──────────┐  ┌──────────┐  ┌──────────────────────────────┐   ┌──────────────┐
│ F1: PC   │→│ F2: I-cache│→│ 发射队列×4:  ALU IQ / MDU IQ / │   │ 提交 (ROB头) │
│ 选择 +   │  │ + BTB/BHT │  │             LSU IQ / BRU IQ  │   │ → ARF 映射   │
│ 预测     │  │ + 取指缓冲│  │ 唤醒(CDB tag 广播)           │   │ → PRF 释放   │
└──────────┘  └────┬─────┘  │ 选择(最老 ROB 号优先)         │   │ → SB 释放    │
                   ▼        └──────────┬───────────────────┘   └──────────────┘
              ┌──────────────┐        ▼
              │ D/R: 译码 +  │   ┌──────────────────────────┐
              │ 重命名(RAT+  │──▶│ FU: ALU / MDU / LSU(AGU+ │
              │ freelist+ROB)│   │ 访问队列) / BRU(判定)    │
              │ + 分发到 IQ  │   └──────────┬───────────────┘
              └──────────────┘              ▼
                                     CDB 写回 (W 端口, 参数化)
                                     → PRF 写 + IQ 唤醒 + ROB 完成标记
```

**要点**：
- 前端与后端按序、中间乱序——这是课程硬性要求的直接体现（操作数就绪即发射、ROB 按序提交）。
- F2 与 D/R 各占一拍：I-cache 的 sram_fakeram 读延迟 1 拍，天然构成"F1 发地址、F2 取数据"；译码+重命名+分发放一拍（组合深度大，若综合后成为关键路径，拆为 D 与 R 两拍——已在阶段 9 的优化清单里预留）。
- 重定向优先级（PC 选择器）：**BRU 误预测 > 提交级事件 > 顺序取指**；误预测广播 flush 到 IQ/ROB/取指队列。

### 1.1 模块职责与关键参数

| 模块 | 职责 | 关键参数 |
| --- | --- | --- |
| `fetch` | PC 选择、BTB/BHT 预测、I-cache 访问、取指缓冲（FIFO） | FETCH_QUEUE_DEPTH=4 |
| `icache` | 只读 I-cache，miss 经 axi_master 重填 | IC_SIZE=8KiB, 行 32B, 直接映射 |
| `btb` / `bht` | 分支目标与方向预测 | BTB=64 项, BHT=512 项 |
| `decoder` | 译码（45 条指令 + illegal） | 见 iface.md v1.0 |
| `rename` | RAT 查表、PRF 分配（freelist）、ROB 分配、分发到 IQ、checkpoint 管理 | PRF=64, ROB_ID_W=6 |
| `prf` | 物理寄存器堆（写穿多端口） | 读口=2×ISSUE_WIDTH, 写口=WB_PORTS |
| `rob` | 按序分配/完成/提交，flush 管理，旧 PRF 释放 | ROB_DEPTH=64, COMMIT_WIDTH=2 |
| `issue_queue`×4 | 唤醒（tag 广播比较）+ 选择（最老优先）+ flush | IQ_DEPTH=8, WAKEUP_PORTS=2 |
| `alu` / `mdu` / `bru` / `lsu` | 执行单元；LSU 含 AGU 与访存队列 | DIV_MAX_CYCLES=34 |
| `store_buffer` | 提交前暂存 store，load 转发，提交时放行写 | SB_DEPTH=8 |
| `dcache` | 写回式 D-cache + 单 MSHR | DC_SIZE=8KiB, 行 32B, 直接映射 |
| `axi_master` / `mem_if` | AXI4-Lite 适配；mem_if 为 cache 前后不变的统一入口 | RD/WR_QUEUE=4 |

### 1.2 关键接口草案（iface.md 未覆盖部分）

```systemverilog
// CDB：写回总线（W 端口参数化）
output logic [WB_PORTS-1:0]            cdb_valid;
output logic [WB_PORTS-1:0][PRF_W-1:0] cdb_tag;    // 物理寄存器号
output logic [WB_PORTS-1:0][31:0]      cdb_data;

// BRU → 全局：分支解析
output logic        br_resolve_valid;
output logic [ROB_ID_W-1:0] br_rob_id;
output logic        br_mispred;
output logic [31:0] br_target;     // 正确目标 PC

// rename → ROB / IQ / SB 分发
input  dec_info_t   dec;
output logic        alloc_valid;               // 本拍分发（ROB/IQ/SB 同时）
output logic [ROB_ID_W-1:0] alloc_rob_id;
output logic [PRF_W-1:0]    alloc_pdst;        // 目标物理寄存器
output logic [PRF_W-1:0]    alloc_ps1, alloc_ps2;
output logic               alloc_s1_ready, alloc_s2_ready; // 操作数已就绪
output logic [31:0]        alloc_s1_data, alloc_s2_data;   // 就绪时携带数值
// Store Buffer 侧（store 指令专用）
output logic               alloc_is_store;
```

**权衡说明**（报告素材）：CDB 采用"多写回端口 + 每 IQ 全比较唤醒"而非共享总线仲裁，因为端口数 2 时全比较逻辑面积可控、时序简单；WB_PORTS 是面积-性能的首要敏感参数（阶段 8 重点扫描）。

---

## 2. 重命名恢复方案对比（RAT checkpoint vs ROB 回放）

| 维度 | A) RAT checkpoint（每在飞分支一份快照） | B) ROB 回放（walk-back） |
| --- | --- | --- |
| 实现复杂度 | **低**：分支重命名时复制 RAT（32×PRF_W 位）；误预测时整份写回 | **中-高**：ROB 每条目存 `arch_rd + old_pdst`；误预测时需逆序回放恢复；要单拍完成则需每 ROB 条目一套并行更新端口，组合面积大 |
| 恢复延迟 | **1 拍**（直接装载快照） | 串行回放 = 年轻指令数拍（不可接受）；并行化才能 1 拍但代价高 |
| 面积 | 每 checkpoint 32×6=192 flop；支持 N=8 在飞分支 ≈ 1.5k flop | 省快照，但 ROB 条目 +6 位/条；并行恢复逻辑可抵消收益 |
| 其他 | 需管理 checkpoint 分配/释放（随分支 rename/resolve） | 无需管理；对"单拍恢复"的实现细节敏感，易出错 |

**决策：选 A（checkpoint）**。

**权衡说明**（报告素材）：
- 本设计 PRF 仅 64 项（6 位 tag），整份 RAT 快照只要 192 位，checkpoint 的 flop 代价几乎可忽略；而 walk-back 的并行化复杂度对单人项目是不必要的风险。
- checkpoint 数量上限 = 同时在飞未解析分支数（8 个足够：ROB 64 项内分支密度 1/8 是合理假设）；若综合后发现面积超档，可退化为"仅最老未解析分支一份快照 + 更年轻分支不恢复（等最老解析后重建）"，需在阶段 9 评估——此为预留的降级路径。
- 恢复路径与 flush 广播共用同一"清空年轻条目"逻辑，语义上只多一步"RAT 装载"。

---

## 3. 访存顺序方案（Store Buffer / load 转发 / store 提交时机）

### 3.1 Store Buffer（SB）

- store 在**重命名时**分配 SB 条目（携带 ROB 号），条目含：`addr_valid / addr / data_valid / data / wstrb / rob_id / committed`。
- store 的**地址在 LSU 发射时计算**，**数据在发射时从操作数取得**；两者就绪标志独立（`addr_valid`/`data_valid`）。
- **store 真正写内存发生在提交时**：提交宽度内的已提交 store 按序发送 mem_if 写请求（v1 阻塞式直连 axi_master，D-cache 上线后经 dcache）。
- 时序：提交当拍出请求 → mem_if 应答后标记完成；SB 条目复用前必须等写应答（提交宽度与 SB 深度联动反压）。

### 3.2 load 转发规则（决策表）

load 执行（LSU IQ 发射）时，按程序顺序检查所有更老且未提交的 store：

| 更老 store 状态 | 重叠情况 | load 行为 |
| --- | --- | --- |
| 地址未知 | 任意 | **保守 stall**：等待该 store 地址计算完成（重发 load 发射） |
| 地址已知，数据未知 | 与 load 地址重叠 | stall，等数据写回 SB |
| 地址+数据已知 | 不重叠 | 跳过，继续查 dcache |
| 地址+数据已知 | 完全覆盖所需字节 | **直接转发**（从 SB 取数） |
| 地址+数据已知 | 部分覆盖 | 与"更年轻的更老 store"合并后仍不全 → stall 到 store 提交（v1 简化） |

**权衡说明**（报告素材）：
- 地址未知即 stall 是保守顺序模型，正确性零风险、逻辑简单；代价是 store→load 依赖链比理想模型多几个周期。若阶段 8 实测 IPC 受此制约，再引入"load 推测越过未知地址 store + 提交时验证"（复杂度高，作为备选）。
- 部分重叠合并转发在字节粒度上处理繁琐且用例稀少（测试程序多为同地址整数访问），v1 直接 stall 到提交，换取实现确定性。

### 3.3 与 D-cache 的一致性

- load 数据源优先级：**SB 转发 > dcache 命中 > 内存重填**。
- store 提交写 dcache（write-back + write-allocate 或写不分配——**决策：write-allocate 不启用**，store miss 直接写穿到内存，避免读回整行；简化换出路径）。dirty 行换出经 axi_master 写回。
- SB 写穿后 dcache 与内存内容一致，无需额外一致性状态机；I-cache 与 D-cache 分离，无自修改代码支持需求（测试程序不产生）。

---

## 4. 单人 10 周实施顺序（里程碑划分）

| 周次 | 里程碑 | 交付/验收 | tag |
| --- | --- | --- | --- |
| 1 | 环境+地基 | 工具链跑通；axi_master + 取指环验证；decoder/RF/ALU/MDU 自测 30 条断言全过 | m0-axi, m1-exec |
| 2 | 设计冻结 | 本文档评审通过（AI 辅助出审阅题自测）；iface.md 定稿 | d0-design |
| 3 | **最小可运行 CPU** | 5 级 stall 流水（无转发），三个基础程序 `LATENCY=1/10` 双档全过 → **75 分安全网** | m2-basic |
| 4 | 重命名+发射 | PRF/RAT/freelist、IQ（唤醒+选择）单测断言通过 | — |
| 5 | ROB+提交 | ROB 按序提交、SB 与 load 转发单测通过 | — |
| 6 | **OoO 集成** | 乱序性自测（年轻指令先就绪场景）+ 基础程序在 OoO 核心全过；**中期检查** | m3-ooo |
| 7 | 分支预测 | BTB/BHT 上线，误预测恢复全路径验证；correctness 全集收敛 → 85 分档 | m4-correct |
| 8 | Cache | I-cache → D-cache 依次上线，`make test` 回归全绿 | m5-cache |
| 9 | 性能冲档 | 参数扫描（发射宽度/ROB/PRF/IQ/Cache），IPC GEOMEAN 达档 | m6-perf |
| 10 | 综合时序 | diagnose→opt 迭代，面积/频率达档；冻结最终参数 | m7-synth |

**顺序依据**：每个里程碑只新增一个复杂度台阶（总线→单元→流水→乱序→预测→缓存→调优），且每步都有可运行的回归基线；第 3 周的 75 分安全网保证后续任何激进改造都有"可退回的绿点"。

**风险与后备方案**：
- 若第 6 周 OoO 集成受阻：先以"最小发射宽度 1 + 浅 ROB"交付中期检查，正确性优先。
- 若第 8 周 D-cache 引入回归：mem_if 接口保证可一键切回直通桥（接口不变设计的意义所在）。
- 若第 10 周频率不达标：按 iface 预留把 D/R 拆两拍、乘法器改迭代（notes/b-20261006 §4.1 备选方案）。

---

## 5. 参数默认值表（阶段 8 扫描起点）

| 参数 | 默认 | 扫描范围 |
| --- | --- | --- |
| ISSUE_WIDTH（总发射宽度） | 2 | 1 / 2 / 4 |
| ROB_DEPTH | 64 | 32 / 64 / 128 |
| PRF 大小 | 64 | 48 / 64 / 96 |
| IQ_DEPTH（每队列） | 8 | 4 / 8 / 16 |
| WB_PORTS（CDB 端口） | 2 | 2 / 3 |
| COMMIT_WIDTH | 2 | 1 / 2 / 4 |
| ICACHE / DCACHE | 8 KiB 直接映射 | 4/8/16 KiB；直接映射/2 路 |
| BTB / BHT | 64 / 512 项 | 64/128；256/512/1024 |
| SB_DEPTH | 8 | 4 / 8 / 16 |
