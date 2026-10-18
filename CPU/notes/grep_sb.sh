#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
grep -n 'alloc_valid\|alloc_rob_id\|fd_store\|sb_alloc' verilog/student_top.sv | head -14
