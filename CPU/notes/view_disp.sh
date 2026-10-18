#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
grep -E '\[disp\]|\[flush\]' cpu_dbg.log | head -60
