#!/bin/bash
cd /home/lmc123456/CPU/RISC-V-CPU-2026
echo "---- jalr 0x60 的派发与重定向："
grep -E 'pc=00000060|pc=0000002c|pc=00000030' cpu_dbg.log | head -10
echo "---- 最后一个 flush target 不是 34 的事件："
grep -E '\[flush\]' cpu_dbg.log | grep -v 'target=00000034' | tail -3
