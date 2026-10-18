#!/bin/bash
# 逐个跑失败用例，定位结果错误与超时
cd /home/lmc123456/CPU/RISC-V-CPU-2026
for c in basicopt1 bulgarian expr magic pi qsort queens superloop tak; do
    echo "== correctness_$c"
    make test Case=correctness_$c 2>&1 | grep -E "PASS|FAIL:" | head -1
done
