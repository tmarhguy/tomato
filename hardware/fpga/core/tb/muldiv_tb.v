/*
 * Tomato — shift/mul/div testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : muldiv_tb.v
 * Target   : simulation (compile with rtl/shift.v rtl/muldiv.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */
`timescale 1ns/1ps
module muldiv_tb;
    reg  [31:0] a, b;
    reg  [1:0]  mode;
    reg         mulen, isdiv;
    wire [31:0] result, resulthi;
    wire        anz;

    muldiv uut (
        .a(a), .b(b), .mode(mode), .mulen(mulen), .isdiv(isdiv),
        .result(result), .resulthi(resulthi), .anz(anz)
    );

    task check;
        input [31:0] exp_lo, exp_hi;
        input        exp_anz;
        input [255:0] tag;
        begin
            #1;
            if (result !== exp_lo || resulthi !== exp_hi || anz !== exp_anz) begin
                $display("FAIL: %0s lo=%h/%h hi=%h/%h anz=%b/%b",
                         tag, exp_lo, result, exp_hi, resulthi, exp_anz, anz);
                $finish(1);
            end
        end
    endtask

    initial begin
        // Shift
        a = 32'h0000_0003; b = 32'h0000_0004; mode = 2'd0; mulen = 0; isdiv = 0;
        check(32'h0000_0030, 32'h0, 1'b1, "lsl");

        a = 32'h8000_0000; b = 32'd4; mode = 2'd2; mulen = 0; isdiv = 0;
        check(32'hF800_0000, 32'h0, 1'b1, "asr");

        a = 32'h0; b = 32'd1; mode = 2'd0; mulen = 0; isdiv = 0;
        check(32'h0, 32'h0, 1'b0, "anz0");

        // Unsigned mul (mode[0]=1)
        a = 32'd6; b = 32'd7; mode = 2'd1; mulen = 1; isdiv = 0;
        check(32'd42, 32'd0, 1'b1, "mulu");

        a = 32'h1000_0000; b = 32'h10; mode = 2'd1; mulen = 1; isdiv = 0;
        check(32'h0000_0000, 32'h1, 1'b1, "mulhu");

        // Signed mul: (-2) * (-3) = 6; (-2)*3 = -6
        a = 32'hFFFF_FFFE; b = 32'hFFFF_FFFD; mode = 2'd0; mulen = 1; isdiv = 0;
        check(32'd6, 32'd0, 1'b1, "muls");

        a = 32'hFFFF_FFFE; b = 32'd3; mode = 2'd0; mulen = 1; isdiv = 0;
        check(32'hFFFF_FFFA, 32'hFFFF_FFFF, 1'b1, "mulh_neg");

        // Both signednesses share one multiplier, so check the corners where
        // the sign extension is all that separates them.
        a = 32'hFFFF_FFFF; b = 32'hFFFF_FFFF; mode = 2'd1; mulen = 1; isdiv = 0;
        check(32'h0000_0001, 32'hFFFF_FFFE, 1'b1, "mulhu_max");

        a = 32'hFFFF_FFFF; b = 32'hFFFF_FFFF; mode = 2'd0; mulen = 1; isdiv = 0;
        check(32'h0000_0001, 32'h0000_0000, 1'b1, "mulhs_neg1");

        // Unsigned div
        a = 32'd100; b = 32'd7; mode = 2'd1; mulen = 1; isdiv = 1;
        check(32'd14, 32'd2, 1'b1, "divu");

        // The divider works on magnitudes, so every sign pairing has to land
        // where the operators would: quotient signs multiply, remainder
        // follows the dividend.
        a = -32'sd100; b = 32'd7; mode = 2'd0; mulen = 1; isdiv = 1;
        check(-32'sd14, -32'sd2, 1'b1, "divs");

        a = 32'd100; b = -32'sd7; mode = 2'd0; mulen = 1; isdiv = 1;
        check(-32'sd14, 32'sd2, 1'b1, "divs_negb");

        a = -32'sd100; b = -32'sd7; mode = 2'd0; mulen = 1; isdiv = 1;
        check(32'sd14, -32'sd2, 1'b1, "divs_negab");

        // -2^31 / -1 overflows back to itself, same as the operator.
        a = 32'h8000_0000; b = 32'hFFFF_FFFF; mode = 2'd0; mulen = 1; isdiv = 1;
        check(32'h8000_0000, 32'd0, 1'b1, "divs_intmin");

        // Same bits unsigned: 2^31 / (2^32-1) = 0 remainder 2^31 — proves the
        // unsigned path never takes a magnitude.
        a = 32'h8000_0000; b = 32'hFFFF_FFFF; mode = 2'd1; mulen = 1; isdiv = 1;
        check(32'd0, 32'h8000_0000, 1'b1, "divu_intmin");

        // Div0 signed → -1, rem=a
        a = 32'hABCD_0123; b = 32'd0; mode = 2'd0; mulen = 1; isdiv = 1;
        check(32'hFFFF_FFFF, 32'hABCD_0123, 1'b1, "div0s");

        // Div0 unsigned → all1
        a = 32'hABCD_0123; b = 32'd0; mode = 2'd1; mulen = 1; isdiv = 1;
        check(32'hFFFF_FFFF, 32'hABCD_0123, 1'b1, "div0u");

        $display("PASS: muldiv");
        $finish;
    end
endmodule
