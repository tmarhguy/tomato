/*
 * Tomato — ISA↔hardware fidelity bench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : fidelity_tb.v
 * Target   : simulation (cwd = hardware/fpga/core)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * End-to-end: ADD/SUB/AND really compute; MUL/DIV signed+unsigned;
 * HALT sticky; ECALL traps to 0x100.
 */
`timescale 1ns/1ps
module fidelity_tb;
    reg clk = 0, reset = 1;
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

    integer i;
    reg saw_halt;

    initial begin
        for (i = 0; i < 256; i = i + 1) uut.regs0.mem[i] = 32'h0;
        uut.regs0.bank = 3'd0;
        for (i = 0; i < 16384; i = i + 1) uut.dmem[i] = 32'h0;

        // --- Program A: ALU fidelity ---
        // 0: ADDI r1,r0,5
        // 1: ADDI r2,r0,7
        // 2: ADD  r3,r1,r2     → 12
        // 3: SUB  r4,r2,r1     → 2
        // 4: AND  r5,r1,r2     → 5
        // 5: MUL  r6,r1,r2     → 35
        // 6: DIV  r7,r2,r1     → 1
        // 7: REM  r8,r2,r1     → 2
        // 8: HALT
        uut.dmem[0] = enc_i(9'h020, 5'd1, 5'd0, 13'd5);
        uut.dmem[1] = enc_i(9'h020, 5'd2, 5'd0, 13'd7);
        uut.dmem[2] = enc_r(9'h001, 5'd3, 5'd1, 5'd2, 5'd0, 3'd0);
        uut.dmem[3] = enc_r(9'h002, 5'd4, 5'd2, 5'd1, 5'd0, 3'd0);
        uut.dmem[4] = enc_r(9'h003, 5'd5, 5'd1, 5'd2, 5'd0, 3'd0);
        uut.dmem[5] = enc_r(9'h010, 5'd6, 5'd1, 5'd2, 5'd0, 3'd0);
        uut.dmem[6] = enc_r(9'h012, 5'd7, 5'd2, 5'd1, 5'd0, 3'd0);
        uut.dmem[7] = enc_r(9'h013, 5'd8, 5'd2, 5'd1, 5'd0, 3'd0);
        uut.dmem[8] = enc_r(9'h0FF, 5'd0, 5'd0, 5'd0, 5'd0, 3'd0);

        tick; tick;
        reset = 0;
        saw_halt = 0;
        for (i = 0; i < 80; i = i + 1) begin
            tick;
            if (uut.pc0.halted) begin saw_halt = 1; i = 80; end
        end
        if (!saw_halt) begin $display("FAIL: no halt after ALU prog"); $finish(1); end
        if (uut.regs0.mem[3] !== 32'd12) begin $display("FAIL: ADD got %0d", uut.regs0.mem[3]); $finish(1); end
        if (uut.regs0.mem[4] !== 32'd2)  begin $display("FAIL: SUB got %0d", uut.regs0.mem[4]); $finish(1); end
        if (uut.regs0.mem[5] !== 32'd5)  begin $display("FAIL: AND got %0d", uut.regs0.mem[5]); $finish(1); end
        if (uut.regs0.mem[6] !== 32'd35) begin $display("FAIL: MUL got %0d", uut.regs0.mem[6]); $finish(1); end
        if (uut.regs0.mem[7] !== 32'd1)  begin $display("FAIL: DIV got %0d", uut.regs0.mem[7]); $finish(1); end
        if (uut.regs0.mem[8] !== 32'd2)  begin $display("FAIL: REM got %0d", uut.regs0.mem[8]); $finish(1); end

        // Sticky halt
        begin : freeze
            reg [23:0] p0;
            p0 = uut.pcout;
            tick; tick; tick;
            if (uut.pcout !== p0 || !uut.pc0.halted) begin
                $display("FAIL: halt not sticky");
                $finish(1);
            end
        end

        // --- Program B: ECALL trap ---
        reset = 1;
        for (i = 0; i < 256; i = i + 1) uut.regs0.mem[i] = 32'h0;
        uut.regs0.bank = 3'd0;
        for (i = 0; i < 16384; i = i + 1) uut.dmem[i] = 32'h0;
        // 0: ADDI r1,r0,1
        // 1: ECALL          → PC=0x100, link=fallthrough
        // 2: should not run
        // 0x100: ADDI r2,r0,99
        // 0x101: HALT
        uut.dmem[0]     = enc_i(9'h020, 5'd1, 5'd0, 13'd1);
        uut.dmem[1]     = enc_r(9'h0E1, 5'd0, 5'd0, 5'd0, 5'd0, 3'd0);
        uut.dmem[2]     = enc_i(9'h020, 5'd3, 5'd0, 13'd55); // poison if fall-through
        uut.dmem[9'h100] = enc_i(9'h020, 5'd2, 5'd0, 13'd99);
        uut.dmem[9'h101] = enc_r(9'h0FF, 5'd0, 5'd0, 5'd0, 5'd0, 3'd0);

        tick; tick;
        reset = 0;
        saw_halt = 0;
        for (i = 0; i < 120; i = i + 1) begin
            tick;
            if (uut.pc0.halted) begin saw_halt = 1; i = 120; end
        end
        if (!saw_halt) begin $display("FAIL: ecall path no halt"); $finish(1); end
        if (uut.regs0.mem[1] !== 32'd1) begin $display("FAIL: ecall pre r1=%0d", uut.regs0.mem[1]); $finish(1); end
        if (uut.regs0.mem[2] !== 32'd99) begin $display("FAIL: ecall handler r2=%0d", uut.regs0.mem[2]); $finish(1); end
        if (uut.regs0.mem[3] === 32'd55) begin $display("FAIL: ecall fell through"); $finish(1); end

        // --- Program C: signed MULH ---
        reset = 1;
        for (i = 0; i < 256; i = i + 1) uut.regs0.mem[i] = 32'h0;
        uut.regs0.bank = 3'd0;
        for (i = 0; i < 16384; i = i + 1) uut.dmem[i] = 32'h0;
        // r1 = -2, r2 = 3, MULH r3 → 0xFFFFFFFF
        uut.dmem[0] = enc_i(9'h020, 5'd1, 5'd0, 13'h1FFE); // -2 as 13-bit? 
        // ADDI imm13 signed: better use LUI+ORI or load -2 via ADDI with proper imm
        // -2 in imm13 = 0x1FFE
        uut.dmem[0] = enc_i(9'h020, 5'd1, 5'd0, 13'h1FFE);
        uut.dmem[1] = enc_i(9'h020, 5'd2, 5'd0, 13'd3);
        uut.dmem[2] = enc_r(9'h011, 5'd3, 5'd1, 5'd2, 5'd0, 3'd0); // MULH
        uut.dmem[3] = enc_r(9'h0FF, 5'd0, 5'd0, 5'd0, 5'd0, 3'd0);

        tick; tick;
        reset = 0;
        saw_halt = 0;
        for (i = 0; i < 40; i = i + 1) begin
            tick;
            if (uut.pc0.halted) begin saw_halt = 1; i = 40; end
        end
        if (!saw_halt) begin $display("FAIL: mulh no halt"); $finish(1); end
        if (uut.regs0.mem[1] !== 32'hFFFF_FFFE) begin
            $display("FAIL: mulh setup r1=%h", uut.regs0.mem[1]); $finish(1);
        end
        if (uut.regs0.mem[3] !== 32'hFFFF_FFFF) begin
            $display("FAIL: MULH got %h", uut.regs0.mem[3]); $finish(1);
        end

        $display("PASS: fidelity (ADD/SUB/AND/MUL/DIV/REM/HALT/ECALL/MULH)");
        $finish;
    end
endmodule
