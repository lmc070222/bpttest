#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
# 找 fetch 越过 0x5c 的时刻（循环退出）
grep -n 'disp.*pc=00000060' cpu_dbg.log | head -3
echo "---- 最后一条 disp/commit/cdb/flush："
grep -E '\[disp\]|\[commit\]|\[cdb\]|\[flush\]' cpu_dbg.log | tail -12
