#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
grep 'ROB-UC' run.log | grep -E 'uc=[0-9]+->[3-9]|uc=[0-9]+->1[0-9]|uc=[0-9]+->2[0-9]' | head -10
