#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
awk '/c=1[3-6][0-9]/{print}' cpu_dbg.log | grep -vE '\[fetch\]'
