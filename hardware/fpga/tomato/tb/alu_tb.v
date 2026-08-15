/*
 * Tomato — dual-LUT ALU testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : alu_tb.v
 * Target   : simulation (compile with rtl/alu.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * Dual-LUT plane: out = lutA(A,B,C) + lutB(A,B,C) + cin.
 * Pass-A = 0xAA, pass-B = 0xCC. Rommap logic opcodes used with lutB=0.
 */
`timescale 1ns/1ps
module alu_tb;
    reg  [7:0]  lutA, lutB;
    reg  [31:0] A, B, C;
    reg  [2:0]  csel;
    reg         flag_we, clk;
    wire [31:0] out;
    wire [7:0]  csr;

    alu uut (
        .lutA(lutA), .lutB(lutB), .A(A), .B(B), .C(C),
        .csel(csel), .flag_we(flag_we), .clk(clk), .out(out), .csr(csr)
    );

    always #5 clk = ~clk;

    task tick; begin @(posedge clk); #1; end endtask

    task check_out;
        input [31:0] exp;
        input [255:0] tag;
        begin
            #1;
            if (out !== exp) begin
                $display("FAIL: %0s expected %h found %h", tag, exp, out);
                $finish(1);
            end
        end
    endtask

    initial begin
        clk = 0; flag_we = 0; csel = 0; C = 0;
        lutA = 0; lutB = 0; A = 0; B = 0;
        tick;

        // ADD: A + B
        lutA = 8'hAA; lutB = 8'hCC; csel = 3'd0;
        A = 32'h0000_0010; B = 32'h0000_0020; C = 0;
        check_out(32'h0000_0030, "add");

        // Carry across byte boundary
        A = 32'h0000_00FF; B = 32'h0000_0001;
        check_out(32'h0000_0100, "carry8");

        A = 32'h00FF_FFFF; B = 32'h0000_0001;
        check_out(32'h0100_0000, "carry24");

        // cin=1 via csel
        csel = 3'd1; A = 32'd5; B = 32'd3;
        check_out(32'd9, "cin1");
        csel = 3'd0;

        // AND via dual-LUT lutA=0x88, lutB=0
        lutA = 8'h88; lutB = 8'h00;
        A = 32'hF0F0_F0F0; B = 32'hFF00_FF00; C = 0;
        check_out(32'hF000_F000, "and");

        // OR 0xEE
        lutA = 8'hEE; lutB = 8'h00;
        check_out(32'hFFF0_FFF0, "or");

        // XOR 0x66
        lutA = 8'h66; lutB = 8'h00;
        A = 32'hAAAA_AAAA; B = 32'h5555_5555;
        check_out(32'hFFFF_FFFF, "xor");

        // Flags: ADD zero
        lutA = 8'hAA; lutB = 8'hCC;
        A = 32'h1; B = 32'hFFFF_FFFF; // sum 0
        flag_we = 1; tick; flag_we = 0;
        if (csr[0] !== 1'b1 || csr[1] !== 1'b0) begin
            $display("FAIL: Z flag csr=%h", csr);
            $finish(1);
        end

        // Negative
        A = 32'h7FFF_FFFF; B = 32'h1;
        flag_we = 1; tick; flag_we = 0;
        if (csr[2] !== 1'b1) begin
            $display("FAIL: N flag csr=%h", csr);
            $finish(1);
        end

        // flag_we gate — force a zero result without latch
        A = 0; B = 0;
        flag_we = 0; tick;
        if (csr[2] !== 1'b1) begin
            $display("FAIL: flag_we gated csr=%h", csr);
            $finish(1);
        end

        // csel feeds prior C flag as cin
        A = 32'd1; B = 32'd1;
        flag_we = 1; tick; // N still from previous? sum=2, update flags
        // set C by large add
        A = 32'hFFFF_FFFF; B = 32'h1; csel = 0;
        flag_we = 1; tick; // C should set
        if (csr[3] !== 1'b1) begin
            $display("FAIL: C flag csr=%h", csr);
            $finish(1);
        end
        csel = 3'd4; // cin = C
        A = 32'd0; B = 32'd0;
        check_out(32'd1, "csel_C");

        $display("PASS: alu");
        $finish;
    end
endmodule
