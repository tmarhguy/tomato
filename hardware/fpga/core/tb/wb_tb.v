/*
 * Tomato — writeback mux testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : wb_tb.v
 * Target   : simulation (compile with rtl/wb.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
 
`timescale 1ns/1ps
module wb_tb;
    reg  [2:0]  wb_sel;
    reg  [31:0] alu_out, shift_mul, mem_din, reg_a, imm, mul_hi;
    reg  [23:0] pc_save;
    reg  [7:0]  csr_flags;
    wire [31:0] wb_data;

    wb uut (
        .wb_sel(wb_sel), .alu_out(alu_out), .shift_mul(shift_mul),
        .pc_save(pc_save), .mem_din(mem_din), .reg_a(reg_a),
        .imm(imm), .csr_flags(csr_flags), .mul_hi(mul_hi), .wb_data(wb_data)
    );

    task check;
        input [31:0] exp;
        input [255:0] tag;
        begin
            #1;
            if (wb_data !== exp) begin
                $display("FAIL: %0s expected %h found %h (sel=%0d)", tag, exp, wb_data, wb_sel);
                $finish(1);
            end
        end
    endtask

    initial begin
        alu_out   = 32'h1111_1111;
        shift_mul = 32'h2222_2222;
        pc_save   = 24'hABCDEF;
        mem_din   = 32'h3333_3333;
        reg_a     = 32'h4444_4444;
        imm       = 32'h5555_5555;
        csr_flags = 8'hA5;
        mul_hi    = 32'h6666_6666;

        wb_sel = 3'd0; check(32'h1111_1111, "alu");
        wb_sel = 3'd1; check(32'h2222_2222, "shift_mul");
        wb_sel = 3'd2; check(32'h00AB_CDEF, "pc_save");
        wb_sel = 3'd3; check(32'h3333_3333, "mem");
        wb_sel = 3'd4; check(32'h4444_4444, "reg_a");
        wb_sel = 3'd5; check(32'h5555_5555, "imm");
        wb_sel = 3'd6; check(32'h0000_00A5, "flags");
        wb_sel = 3'd7; check(32'h6666_6666, "mul_hi");

        $display("PASS: wb");
        $finish;
    end
endmodule
