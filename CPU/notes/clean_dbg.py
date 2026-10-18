#!/usr/bin/env python3
import re, sys

for p in ['verilog/rename.sv', 'verilog/rob.sv', 'verilog/store_buffer.sv']:
    s = open(p).read()
    s = re.sub(r'`ifndef SYNTHESIS.*?`endif', '`ifndef SYNTHESIS\n`endif', s, flags=re.S)
    open(p, 'w').write(s)
    print(f'cleaned {p}')
