#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
grep -n 'pc=00000030' cpu_dbg.log | head -4
echo "---- 退出 store 派发后的相关事件："
grep -E 'rob=4 ' cpu_dbg.log | grep -E '\[iss-lsu\]|\[cdb\]|\[commit\]' | tail -6
