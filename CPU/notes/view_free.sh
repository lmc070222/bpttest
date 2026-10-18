#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
grep -E '\[free\]|\[flush\]' cpu_dbg.log | head -35
