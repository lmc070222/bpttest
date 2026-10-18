#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
grep -vE '\[fetch\]|\[iss-alu\]|\[iss-bru\]' cpu_dbg.log | tail -20
