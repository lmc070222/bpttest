#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
echo "---- 最后 15 条非 fetch 事件："
grep -vE '\[fetch\]' cpu_dbg.log | tail -15
echo "---- 最后的 flush/commit："
grep -E '\[flush\]|\[commit\]|\[cdb\]' cpu_dbg.log | tail -8
