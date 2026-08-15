/*
 * Tomato — stack pointer testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : sp_tb.v
 * Target   : simulation (compile with rtl/sp.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */
`timescale 1ns/1ps
module sp_tb;
    reg         clk, rst, exec;
    reg  [1:0]  sp_op;
    reg  [31:0] load_in;
    wire [23:0] sp_out;

    sp uut (
        .clk(clk), .rst(rst), .exec(exec),
        .sp_op(sp_op), .load_in(load_in), .sp_out(sp_out)
    );

    always #5 clk = ~clk;

    task check;
        input [23:0] exp;
        input [255:0] tag;
        begin
            #1;
            if (sp_out !== exp) begin
                $display("FAIL: %0s expected %h found %h", tag, exp, sp_out);
                $finish(1);
            end
        end
    endtask

    task tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk = 0; rst = 1; exec = 0; sp_op = 2'd0; load_in = 0;
        tick;
        tick;
        rst = 0;
        tick;
        check(24'h3E00, "reset");

        exec = 1; sp_op = 2'd0;
        tick;
        check(24'h3E00, "nop");

        sp_op = 2'd1;
        tick;
        check(24'h3E01, "inc");

        sp_op = 2'd2;
        #1;
        if (sp_out !== 24'h3E00) begin
            $display("FAIL: postdec combo expected 3E00 found %h", sp_out);
            $finish(1);
        end
        tick;
        sp_op = 2'd0;
        check(24'h3E00, "dec_reg");

        sp_op = 2'd3; load_in = 32'h00AB_CDEF;
        tick;
        check(24'hAB_CDEF, "load");

        exec = 0; sp_op = 2'd1;
        tick;
        check(24'hAB_CDEF, "no_exec");

        $display("PASS: sp");
        $finish;
    end
endmodule
