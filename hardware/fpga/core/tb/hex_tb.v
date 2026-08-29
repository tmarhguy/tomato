/*
 * Tomato — 7-segment hex display testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : hex_tb.v
 * Target   : simulation (compile with rtl/hex.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */
`timescale 1ns/1ps
module hex_tb;
    reg         clk, reset;
    reg  [31:0] value;
    wire [6:0]  seg;
    wire [7:0]  an;
    wire        dp;

    hex uut (
        .clk(clk), .reset(reset), .value(value),
        .seg(seg), .an(an), .dp(dp)
    );

    always #5 clk = ~clk;

    task tick; begin @(posedge clk); #1; end endtask

    // Force digit select via hierarchical div
    task expect_digit;
        input [2:0] dig;
        input [6:0] exp_font;
        input [255:0] tag;
        begin
            uut.div = {dig, 14'd0};
            tick;
            if (seg !== exp_font || an !== ~(8'b1 << dig) || dp !== 1'b1) begin
                $display("FAIL: %0s dig=%0d seg=%b an=%h", tag, dig, seg, an);
                $finish(1);
            end
        end
    endtask

    initial begin
        clk = 0; reset = 1; value = 32'h0;
        tick; tick;
        reset = 0;
        if (dp !== 1'b1) begin $display("FAIL: dp"); $finish(1); end

        // value = 0x01234567 → nibble dig0=7 font=1111000
        value = 32'h0123_4567;
        expect_digit(3'd0, 7'b1111000, "d0"); // 7
        expect_digit(3'd1, 7'b0000010, "d1"); // 6
        expect_digit(3'd2, 7'b0010010, "d2"); // 5
        expect_digit(3'd3, 7'b0011001, "d3"); // 4
        expect_digit(3'd4, 7'b0110000, "d4"); // 3
        expect_digit(3'd5, 7'b0100100, "d5"); // 2
        expect_digit(3'd6, 7'b1111001, "d6"); // 1
        expect_digit(3'd7, 7'b1000000, "d7"); // 0

        // A..F — value ABCD_EF00:
        // dig7=A dig6=B dig5=C dig4=D dig3=E dig2=F dig1=0 dig0=0
        value = 32'hABCD_EF00;
        expect_digit(3'd3, 7'b0000110, "E");
        expect_digit(3'd7, 7'b0001000, "A");
        expect_digit(3'd5, 7'b1000110, "C");

        $display("PASS: hex");
        $finish;
    end
endmodule
