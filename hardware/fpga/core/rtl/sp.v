/*
 * Tomato — stack pointer
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : sp.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * 24-bit word addresses (matches PC / dmem index).
 * sp_op: 0=nop, 1=+1, 2=-1, 3=ALU load. Reset = 0x3E00 (top of 16K dmem).
 */
module sp (
    input         clk,
    input         rst,
    input         exec,
    input  [1:0]  sp_op,
    input  [31:0] load_in,
    output [23:0] sp_out
);
    reg  [23:0] sp;
    wire        inc     = (sp_op == 2'd1);
    wire        dec     = (sp_op == 2'd2);
    wire        load    = (sp_op == 2'd3);
    // +1 or -1; nop/load do not consume the sum.
    wire [23:0] sp_next = sp + {{23{dec}}, 1'b1};
    wire        do_op   = exec & (inc | dec | load);

    always @(posedge clk) begin
        if (rst)
            sp <= 24'h3E00;
        else if (do_op) begin
            if (load) sp <= load_in[23:0];
            else      sp <= sp_next;
        end
    end

    // op==2: present post-dec on bus
    assign sp_out = dec ? sp_next : sp;
endmodule
