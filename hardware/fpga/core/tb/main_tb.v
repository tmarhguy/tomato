/*
 * Tomato — fibonacci integration smoke (real program)
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : main_tb.v
 * Target   : simulation (cwd = hardware/fpga/core)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * Computes fib(8)=21 in r1 using ADDI/CMP/BEQ/ADD/MOV/ADDI/JMP/HALT,
 * then SW/LW round-trip of the result.
 *
 * Encoding (I-type ADDI/LW): {op, rd, rA, imm13}
 * Encoding (SW):             {op, 5'0, rA_data, rB_base, imm8}
 * Encoding (BEQ/JMP):        {op, offset[22:0]}  (PC uses ir[21:0])
 */
`timescale 1ns/1ps
module main_tb;
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

    // R-type: op rd rA rB rC bank
    function [31:0] enc_r;
        input [8:0] op;
        input [4:0] rd, ra, rb, rc;
        input [2:0] bank;
        enc_r = {op, rd, ra, rb, rc, bank};
    endfunction

    // I-type ADDI/LW: op rd rA imm13
    function [31:0] enc_i;
        input [8:0]  op;
        input [4:0]  rd, ra;
        input [12:0] imm13;
        enc_i = {op, rd, ra, imm13};
    endfunction

    // SW: op | 0 | rA_data | rB_base | imm8
    function [31:0] enc_sw;
        input [8:0] op;
        input [4:0] ra, rb;
        input [7:0] imm8;
        enc_sw = {op, 5'd0, ra, rb, imm8};
    endfunction

    // Branch / JMP: op | off22 in ir[21:0] (rd[4] cleared)
    function [31:0] enc_br;
        input [8:0]  op;
        input [21:0] off;
        enc_br = {op, 1'b0, off};
    endfunction

    integer k;
    reg saw_halt;

    // Word addresses of program labels
    localparam LOOP = 22'd4;
    localparam DONE = 22'd11;
    // BEQ at word 5: execute pc=6 → DONE with offset = DONE-6 = 5
    localparam BEQ_OFF = DONE - 22'd6;
    // JMP at word 10: abs → LOOP
    localparam JMP_ABS = LOOP;

    initial begin
        for (k = 0; k < 256; k = k + 1) uut.regs0.mem[k] = 32'h0;
        uut.regs0.bank = 3'd0;
        for (k = 0; k < 16384; k = k + 1) uut.dmem[k] = 32'h0;

        // 0: ZERO r0
        uut.dmem[0] = enc_r(9'h030, 5'd0, 5'd0, 5'd0, 5'd0, 3'd0);
        // 1: ADDI r1, r0, 0   a=0
        uut.dmem[1] = enc_i(9'h020, 5'd1, 5'd0, 13'd0);
        // 2: ADDI r2, r0, 1   b=1
        uut.dmem[2] = enc_i(9'h020, 5'd2, 5'd0, 13'd1);
        // 3: ADDI r3, r0, 8   n=8
        uut.dmem[3] = enc_i(9'h020, 5'd3, 5'd0, 13'd8);
        // 4 LOOP: CMP r3, r0
        uut.dmem[4] = enc_r(9'h007, 5'd0, 5'd3, 5'd0, 5'd0, 3'd0);
        // 5: BEQ DONE
        uut.dmem[5] = enc_br(9'h080, BEQ_OFF);
        // 6: ADD r4, r1, r2   t=a+b
        uut.dmem[6] = enc_r(9'h001, 5'd4, 5'd1, 5'd2, 5'd0, 3'd0);
        // 7: MOV r1, r2       a=b  (rd=rB)
        uut.dmem[7] = enc_r(9'h006, 5'd1, 5'd0, 5'd2, 5'd0, 3'd0);
        // 8: MOV r2, r4       b=t
        uut.dmem[8] = enc_r(9'h006, 5'd2, 5'd0, 5'd4, 5'd0, 3'd0);
        // 9: ADDI r3, r3, -1  n--
        uut.dmem[9] = enc_i(9'h020, 5'd3, 5'd3, 13'h1FFF);
        // 10: JMP LOOP
        uut.dmem[10] = enc_br(9'h0A0, JMP_ABS);
        // 11 DONE: ADDI r5, r0, 32  scratch ptr
        uut.dmem[11] = enc_i(9'h020, 5'd5, 5'd0, 13'd32);
        // 12: SW r1, [r5+0]   store fib result
        uut.dmem[12] = enc_sw(9'h068, 5'd1, 5'd5, 8'd0);
        // 13: LW r6, [r5+0]   reload
        uut.dmem[13] = enc_i(9'h060, 5'd6, 5'd5, 13'd0);
        // 14: HALT
        uut.dmem[14] = {9'h0FF, 23'd0};

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
            $display("FAIL: no halt pc=%h op=%h r1=%0d r3=%0d",
                     uut.pcout, uut.opcode, uut.regs0.mem[1], uut.regs0.mem[3]);
            $finish(1);
        end
        if (uut.regs0.mem[1] !== 32'd21) begin
            $display("FAIL: fib r1=%0d (want 21)", uut.regs0.mem[1]);
            $finish(1);
        end
        if (uut.regs0.mem[6] !== 32'd21) begin
            $display("FAIL: LW r6=%0d", uut.regs0.mem[6]);
            $finish(1);
        end
        if (uut.dmem[32] !== 32'd21) begin
            $display("FAIL: SW mem[32]=%0d", uut.dmem[32]);
            $finish(1);
        end

        $display("PASS: fib(8)=21 + SW/LW (real program)");
        $finish;
    end
endmodule
