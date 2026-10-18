#!/bin/bash
# 75 分安全网验收：三基础程序 × LATENCY 1/10 双档
cd /home/lmc123456/CPU/RISC-V-CPU-2026
echo "========== LATENCY=10（默认）=========="
make test Case=correctness_add_to_100 2>&1 | grep -E "PASS|FAIL:" | head -1
make test Case=correctness_array_test1 2>&1 | grep -E "PASS|FAIL:" | head -1
make test Case=correctness_array_test2 2>&1 | grep -E "PASS|FAIL:" | head -1
echo "========== LATENCY=1 =========="
make test Case=correctness_add_to_100 LATENCY=1 2>&1 | grep -E "PASS|FAIL:" | head -1
make test Case=correctness_array_test1 LATENCY=1 2>&1 | grep -E "PASS|FAIL:" | head -1
make test Case=correctness_array_test2 LATENCY=1 2>&1 | grep -E "PASS|FAIL:" | head -1
