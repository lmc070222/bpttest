#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
awk '/c=49[3-9][0-9]/{print}' cpu_dbg.log | grep -vE '\[fetch\]' | head -30
echo "---- 往后："
awk '/c=5[0-4][0-9][0-9]/{print}' cpu_dbg.log | grep -vE '\[fetch\]' | head -20
