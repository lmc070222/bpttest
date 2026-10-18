# axi_master + 最小取指环 设计说明

> 2026-10-06 | soloplan.md 阶段 2 交付物 | 文件：verilog/axi_master.sv、verilog/test_top.sv

## 1. 结构

```
CPU 侧                    axi_master 内部                        AXI4-Lite 侧
rd_req ──▶ [ar_q 地址FIFO] ──▶ AR 通道 (arvalid=队列非空, araddr=队头)
R 通道 ──▶ [rr_q 响应FIFO] ──▶ rd_resp (data/err)
wr_req ──▶ [wq 单队列 addr+data+strb+exit标志] ──▶ AW/W 锁步通道
B 通道 ──▶ [bq_exit 标志队列] ── 退出写 → exit_ack 脉冲
                                ── 普通写 → [br_q 响应FIFO] → wr_resp
```

- 读、写两通路完全对称：请求 FIFO 吸收"接受比发出快"的差值，响应 FIFO 吸收"返回比消费快"的差值。
- AW 与 W 共用一个队列（锁步同拍拉高），从结构上消灭"W 先于 AW"的错拍窗口。

## 2. 防死锁论证（对应握手三铁律）

1. **VALID 稳定性**：`arvalid/awvalid/wvalid` 只由"队列非空"决定；队头 payload 直到握手 fire 才弹出指针，期间 `araddr/awaddr/wdata/wstrb` 稳定不变。
2. **VALID 不组合依赖 READY**：三个 valid 表达式只含 `reset` 与内部计数，不含任何 `*ready` 信号。
3. **响应必能接收**：`rready/bready` 非复位恒 1。安全前提——在飞请求数 ≤ RD/WR_QUEUE_DEPTH(=4) < 从机 16 项队列，故从机不可能拒绝（`arready/awready/wready = !full`），我们的响应 FIFO 也永远放得下（深度 ≥ 在飞上限）。
4. **CPU 侧反压**：`rd_req_ready/wr_req_ready` 只由内部计数决定（< DEPTH），与总线状态无关，CPU 侧不存在组合环。

## 3. 关键时序

- 读：请求 fire（CPU 侧）→ 下一拍 AR fire → 从机服务（握手后下一周期）→ +10 拍（LATENCY）R fire → 下一拍 CPU 可见 rd_resp。总 ≈ 1+1+10+1 拍。
- 写（普通）：wr_req fire → AW/W 同拍 fire → +10 拍 B fire → wr_resp。
- 退出写：识别发生在 wr_req 入队时（`addr==0x80000000 && strb==4'hf` 记入 `wq_exit` 标志，随队列传递到 `bq_exit`）；`exit_ack = bvalid && bready && bq_exit[队头]` 恰好与从机捕获结果同拍。

## 4. 与 iface.md 的一致性

- 端口、参数（RD_QUEUE_DEPTH/WR_QUEUE_DEPTH）与 iface.md v1.0 逐位一致。
- 新增 `DBG` 参数（默认 1）用于 $display 开关；综合时全部调试语句被 `` `ifndef SYNTHESIS `` 剔除（框架 synth 流程带 `-D SYNTHESIS`），无面积影响。

## 5. 验证方法

```sh
cd RISC-V-CPU-2026
make build
make run PROGRAM=testcases/correctness_add_to_100/program.data EXPECTED=0 LOG=run.log
```

- **检查 1（读通路）**：run.log 中 `[fetch] word0..15` 的 data 应与 program.data 前 16 个 @ 段指令字一致；`[axi_master] AR/R fire` 应与之一一对应。
- **检查 2（写+退出）**：末尾出现 `[axi_master] B fire resp=00` 与 `EXIT ACK`，且运行结果 `PASS ... result=0 expected=0`。
- **检查 3（对齐自测）**：`EXPECTED=5050` 运行应 FAIL（result=0），仅用于对照退出值确实被正确捕获。

## 6. 后续计划（阶段 3）

- test_top 退役，换成 fetch_unit（接口按 iface.md §5.1）+ 真正 student_top；axi_master 保持不变。
- 若阶段 7 性能需要，把"响应 FIFO 弹出"升级为乱序 tag 匹配（接口已通过 rd_resp_err 预留）。
