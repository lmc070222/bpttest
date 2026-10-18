#!/usr/bin/env python3
import re

s = open('verilog/rename.sv').read()
s = re.sub(r'`ifndef SYNTHESIS.*?`endif', '`ifndef SYNTHESIS\n`endif', s, flags=re.S)
dbg = (
    "`ifndef SYNTHESIS\n"
    "    always @(posedge clk) begin\n"
    "        if (!reset && disp_valid) begin\n"
    '            $display("RN-DBG rs1=%0d rs2=%0d rd=%0d rat1=%0d rat2=%0d ps1c=%0d ps2c=%0d",\n'
    "                     disp_dec.rs1, disp_dec.rs2, disp_dec.rd,\n"
    "                     rat[1], rat[2], ps1_c, ps2_c);\n"
    "        end\n"
    "    end\n"
    "`endif"
)
s = s.replace("`ifndef SYNTHESIS\n`endif", dbg, 1)
open('verilog/rename.sv', 'w').write(s)
print('ok')
