#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
grep 'disp.*pc=00000060' cpu_dbg.log | tail -3
grep '\[iss-bru\]' cpu_dbg.log | tail -3
