#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
grep -E '\[disp\]|\[commit\]|\[flush\]|\[cdb\]' cpu_dbg.log | tail -20
