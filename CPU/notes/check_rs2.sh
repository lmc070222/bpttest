#!/bin/bash
# 提取 BR pc=0000005c 的 rs2 序列，找重置点
cd /home/lmc123456/CPU/RISC-V-CPU-2026
grep 'BR pc=0000005c' dbg.log | sed 's/.*rs2=\([0-9a-f]*\).*/\1/' > /tmp/rs2.txt
echo "total: $(wc -l < /tmp/rs2.txt)"
echo "---- 每次递减（重置）位置："
awk 'prev != "" && strtonum("0x"$1) < prev { print "line " NR ": " prev " -> " $1 } { prev=strtonum("0x"$1) }' /tmp/rs2.txt | head -20
echo "---- 前 60 个与后 10 个："
head -60 /tmp/rs2.txt | tr '\n' ' '; echo
tail -10 /tmp/rs2.txt | tr '\n' ' '; echo
echo "---- BR 0x44 出现的行号："
grep -n 'BR pc=00000044' dbg.log
