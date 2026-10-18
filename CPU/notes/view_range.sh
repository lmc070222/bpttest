#!/bin/bash
# 打印 dbg.log 中 c=5800..6000 区间
cd /home/lmc123456/CPU/RISC-V-CPU-2026
awk '/c=5[89][0-9][0-9]/{print} /c=6000/{print}' dbg.log | head -60
