#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
awk '/c=71[0-9]|c=72[0-9]|c=73[0-9]/{print}' cpu_dbg.log | grep -E '\[flush\]|\[disp\]|\[iss-lsu\]|\[cdb\] port=2'
