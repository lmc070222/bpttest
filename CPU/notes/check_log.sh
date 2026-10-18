#!/bin/bash
# 检查 dbg.log 中 [cpu] 行的周期号是否单调、是否有重复
cd /home/lmc123456/CPU/RISC-V-CPU-2026
grep '^\[cpu\]' dbg.log | sed 's/^\[cpu\] c=\([0-9]*\).*/\1/' > /tmp/cyc.txt
echo "total [cpu] lines: $(wc -l < /tmp/cyc.txt)"
echo "unique cycles:     $(sort -n /tmp/cyc.txt | uniq | wc -l)"
echo "duplicated cycles (first 10):"
sort -n /tmp/cyc.txt | uniq -d | head -10
echo "---- last 10 cycle numbers:"
tail -10 /tmp/cyc.txt
echo "---- non-monotonic points (first 10):"
awk 'prev != "" && $1 < prev { print "line " NR ": " prev " -> " $1; if (++n==10) exit } { prev=$1 }' /tmp/cyc.txt
