#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
echo "---- pdst=13 相关："
grep 'pdst=13' cpu_dbg.log | head -8
echo "---- c=115..132 事件："
awk '/c=1[12][0-9]|c=13[0-2]/{print}' cpu_dbg.log | grep -vE '\[fetch\]'
