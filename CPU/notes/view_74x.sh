#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
awk '/c=74[0-9]|c=75[0-9]|c=76[0-9]|c=77[0-9]/{print}' cpu_dbg.log | grep -vE '\[fetch\]'
