/*
 * Tomato — counter → 7-seg via latched writeback
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : counter_tb.v
 * Target   : simulation (cwd = hardware/fpga/core)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * Counts r1 from 0 → 10, HALT. The display latch holds the last register
 * writeback (=10) and presents it on disp_value for the board's 7-seg driver.
 * The segment font itself is hex_tb's job.
 */
`timescale 1ns/1ps
module counter_tb;
    reg clk = 0;
    reg reset = 1;
    reg  [7:0] kb_data = 8'h00;
    reg        kb_ready = 1'b0;
    wire [7:0]  io_out;
    wire [31:0] disp_value;
    wire        kb_rd, halted;
    reg  [12:0] tile_raddr = 13'd0;
    wire [31:0] tile_rdata;

    always #5 clk = ~clk;

    main uut (
        .clk(clk), .reset(reset),
        .kb_data(kb_data), .kb_ready(kb_ready), .kb_rd(kb_rd),
        .io_out(io_out), .disp_value(disp_value), .halted(halted),
        .tile_rclk(clk), .tile_raddr(tile_raddr), .tile_rdata(tile_rdata)
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

        // The latch is what leaves the machine, so check the port too.
        if (disp_value !== 32'd10) begin
            $display("FAIL: disp_value=%h (want 10)", disp_value);
            $finish(1);
        end

        $display("PASS: counter→disp=10");
        $finish;
    end
endmodule
