#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
grep -E '\[commit\]|\[flush\]' cpu_dbg.log | tail -12
echo "---- ROB 相关（commit 停止点前后）"
awk '/c=3[0-7][0-9]/{print}' cpu_dbg.log | grep -vE '\[fetch\]' | head -40
