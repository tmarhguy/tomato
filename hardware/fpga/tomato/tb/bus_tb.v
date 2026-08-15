/*
 * Tomato — address mux testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : bus_tb.v
 * Target   : simulation (compile with rtl/bus.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */
`timescale 1ns/1ps
module bus_tb;
    reg         fetch, mem_rd_in;
    reg  [2:0]  addr_sel;
    reg  [21:0] ir_addr;
    reg  [31:0] reg_b, alu_in;
    reg  [23:0] pc, sp;
    wire [23:0] addr;
    wire        mem_rd;

    bus uut (
        .fetch(fetch), .mem_rd_in(mem_rd_in), .addr_sel(addr_sel),
        .ir_addr(ir_addr), .reg_b(reg_b), .alu_in(alu_in),
        .pc(pc), .sp(sp), .addr(addr), .mem_rd(mem_rd)
    );

    task check;
        input [23:0] exp_addr;
        input        exp_rd;
        input [255:0] tag;
        begin
            #1;
            if (addr !== exp_addr || mem_rd !== exp_rd) begin
                $display("FAIL: %0s addr exp=%h got=%h rd exp=%b got=%b",
                         tag, exp_addr, addr, exp_rd, mem_rd);
                $finish(1);
            end
        end
    endtask

    initial begin
        ir_addr   = 22'h2A_BCDE;
        reg_b     = 32'h00FF_1234;
        alu_in    = 32'h00AA_5678;
        pc        = 24'h00_0100;
        sp        = 24'h01_0000;
        mem_rd_in = 1'b0;
        addr_sel  = 3'd0;

        // Fetch overrides addr and forces mem_rd
        fetch = 1'b1;
        check(24'h00_0100, 1'b1, "fetch");

        fetch = 1'b0;
        addr_sel = 3'd0; check({2'b0, ir_addr}, 1'b0, "sel0_ir");
        addr_sel = 3'd1; check(alu_in[23:0], 1'b0, "sel1_alu");
        addr_sel = 3'd2; check(reg_b[23:0], 1'b0, "sel2_regb");
        addr_sel = 3'd3; check(pc, 1'b0, "sel3_pc");
        addr_sel = 3'd7; check(sp, 1'b0, "sel7_sp");
        addr_sel = 3'd4; check(24'b0, 1'b0, "sel_default");

        mem_rd_in = 1'b1;
        addr_sel  = 3'd0;
        check({2'b0, ir_addr}, 1'b1, "mem_rd_in");

        fetch = 1'b1;
        mem_rd_in = 1'b0;
        check(pc, 1'b1, "fetch_or_rd");

        $display("PASS: bus");
        $finish;
    end
endmodule
