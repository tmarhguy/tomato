/*
 * Tomato — counter → 7-seg via latched writeback
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : counter_tb.v
 * Target   : simulation (cwd = hardware/fpga/tomato)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * Counts r1 from 0 → 10, HALT. Display latches last reg WB (=10).
 * Checks digit0 7-seg font for nibble 0xA.
 */
`timescale 1ns/1ps
module counter_tb;
    reg clk = 0;
    reg reset = 1;
    reg  [7:0] kb_data = 8'h00;
    reg        kb_ready = 1'b0;
    wire [7:0] io_out;
    wire [6:0] seg;
    wire [7:0] an;
    wire       dp;
    wire       vga_hs, vga_vs;
    wire [3:0] vga_r, vga_g, vga_b;

    always #5 clk = ~clk;

    main uut (
        .clk(clk), .reset(reset),
        .kb_data(kb_data), .kb_ready(kb_ready), .io_out(io_out),
        .seg(seg), .an(an), .dp(dp),
        .vga_hs(vga_hs), .vga_vs(vga_vs),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );

    task tick; begin @(posedge clk); #1; end endtask

    function [31:0] enc_r;
        input [8:0] op;
        input [4:0] rd, ra, rb, rc;
        input [2:0] bank;
        enc_r = {op, rd, ra, rb, rc, bank};
    endfunction

    function [31:0] enc_i;
        input [8:0]  op;
        input [4:0]  rd, ra;
        input [12:0] imm13;
        enc_i = {op, rd, ra, imm13};
    endfunction

    function [31:0] enc_br;
        input [8:0]  op;
        input [21:0] off;
        enc_br = {op, 1'b0, off};
    endfunction

    // active-low gfedcba — match hex.v
    function [6:0] font;
        input [3:0] n;
        begin
            case (n)
                4'h0: font = 7'b1000000;
                4'h1: font = 7'b1111001;
                4'h2: font = 7'b0100100;
                4'h3: font = 7'b0110000;
                4'h4: font = 7'b0011001;
                4'h5: font = 7'b0010010;
                4'h6: font = 7'b0000010;
                4'h7: font = 7'b1111000;
                4'h8: font = 7'b0000000;
                4'h9: font = 7'b0010000;
                4'hA: font = 7'b0001000;
                4'hB: font = 7'b0000011;
                4'hC: font = 7'b1000110;
                4'hD: font = 7'b0100001;
                4'hE: font = 7'b0000110;
                default: font = 7'b0001110;
            endcase
        end
    endfunction

    localparam LOOP = 22'd3;
    // BNE @5: execute pc=6 → LOOP with off = 3-6 = -3
    localparam BNE_OFF = 22'h3FFFFD; // -3

    integer k;
    reg saw_halt;

    initial begin
        for (k = 0; k < 256; k = k + 1) uut.regs0.mem[k] = 32'h0;
        uut.regs0.bank = 3'd0;
        for (k = 0; k < 16384; k = k + 1) uut.dmem[k] = 32'h0;

        uut.dmem[0] = enc_r(9'h030, 5'd0, 5'd0, 5'd0, 5'd0, 3'd0); // ZERO r0
        uut.dmem[1] = enc_i(9'h020, 5'd2, 5'd0, 13'd10);           // ADDI r2,r0,10
        uut.dmem[2] = enc_i(9'h020, 5'd1, 5'd0, 13'd0);            // ADDI r1,r0,0
        uut.dmem[3] = enc_i(9'h020, 5'd1, 5'd1, 13'd1);            // LOOP: ADDI r1,r1,1
        uut.dmem[4] = enc_r(9'h007, 5'd0, 5'd1, 5'd2, 5'd0, 3'd0); // CMP r1,r2
        uut.dmem[5] = enc_br(9'h081, BNE_OFF);                     // BNE LOOP
        uut.dmem[6] = {9'h0FF, 23'd0};                             // HALT

        tick; tick;
        reset = 0;

        saw_halt = 0;
        for (k = 0; k < 2000; k = k + 1) begin
            tick;
            if (uut.pc0.halted) begin
                saw_halt = 1;
                k = 2000;
            end
        end

        if (!saw_halt) begin
            $display("FAIL: no halt pc=%h r1=%0d", uut.pcout, uut.regs0.mem[1]);
            $finish(1);
        end
        if (uut.regs0.mem[1] !== 32'd10) begin
            $display("FAIL: counter r1=%0d (want 10)", uut.regs0.mem[1]);
            $finish(1);
        end
        if (uut.disp !== 32'd10) begin
            $display("FAIL: disp latch=%h (want 10)", uut.disp);
            $finish(1);
        end

        // Digit 0 of 7-seg must show 0xA
        uut.hex0.div = {3'd0, 14'd0};
        tick;
        if (seg !== font(4'hA) || an !== ~8'b0000_0001) begin
            $display("FAIL: seg=%b an=%h (want font A on dig0)", seg, an);
            $finish(1);
        end

        $display("PASS: counter→disp=10 seg digit0=A");
        $finish;
    end
endmodule
