#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
awk '/c=89[6-9][0-9]/{print}' cpu_dbg.log | grep -vE '\[fetch\]' | head -30
