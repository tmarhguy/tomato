/*
 * Tomato — shift unit testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : shift_tb.v
 * Target   : simulation (compile with rtl/shift.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
`timescale 1ns/1ps
module shift_tb;
    reg  [31:0] A;
    reg  [1:0]  mode;
    reg  [4:0]  B;
    wire [31:0] Out;

    shift uut (.A(A), .mode(mode), .B(B), .Out(Out));

    task check;
        input [31:0] exp;
        input [255:0] tag;
        begin
            #1;
            if (Out !== exp) begin
                $display("FAIL: %0s expected %h found %h (A=%h mode=%0d B=%0d)",
                         tag, exp, Out, A, mode, B);
                $finish(1);
            end
        end
    endtask

    initial begin
        // LSL
        A = 32'h0000_0001; mode = 2'd0; B = 5'd0;  check(32'h0000_0001, "LSL0");
        A = 32'h0000_0001; mode = 2'd0; B = 5'd4;  check(32'h0000_0010, "LSL4");
        A = 32'h0000_0001; mode = 2'd0; B = 5'd31; check(32'h8000_0000, "LSL31");

        // LSR
        A = 32'h8000_0000; mode = 2'd1; B = 5'd0;  check(32'h8000_0000, "LSR0");
        A = 32'h8000_0000; mode = 2'd1; B = 5'd4;  check(32'h0800_0000, "LSR4");
        A = 32'h8000_0000; mode = 2'd1; B = 5'd31; check(32'h0000_0001, "LSR31");

        // ASR
        A = 32'h8000_0000; mode = 2'd2; B = 5'd0;  check(32'h8000_0000, "ASR0");
        A = 32'h8000_0000; mode = 2'd2; B = 5'd4;  check(32'hF800_0000, "ASR4");
        A = 32'h8000_0000; mode = 2'd2; B = 5'd31; check(32'hFFFF_FFFF, "ASR31");
        A = 32'h4000_0000; mode = 2'd2; B = 5'd4;  check(32'h0400_0000, "ASR+");

        // ROR
        A = 32'h1234_5678; mode = 2'd3; B = 5'd0;  check(32'h1234_5678, "ROR0");
        A = 32'h1234_5678; mode = 2'd3; B = 5'd4;
        check(32'h8123_4567, "ROR4");
        A = 32'h0000_0001; mode = 2'd3; B = 5'd1;  check(32'h8000_0000, "ROR1");
        A = 32'h8000_0000; mode = 2'd3; B = 5'd31; check(32'h0000_0001, "ROR31");

        $display("PASS: shift");
        $finish;
    end
endmodule
