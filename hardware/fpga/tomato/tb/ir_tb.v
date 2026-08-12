/*
 * Tomato — instruction register testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : ir_tb.v
 * Target   : simulation (compile with rtl/ir.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
`timescale 1ns/1ps
module ir_tb;
    reg         clk, load;
    reg  [31:0] data_in, reg_b;
    reg  [3:0]  imm_sel;
    wire [8:0]  opcode;
    wire [4:0]  addr_a, addr_b, addr_c, addr_w;
    wire [2:0]  bank_sel;
    wire [21:0] addr_abs, offset;
    wire [31:0] imm_out;

    ir uut (
        .clk(clk), .load(load), .data_in(data_in), .imm_sel(imm_sel),
        .reg_b(reg_b), .opcode(opcode), .addr_a(addr_a), .addr_b(addr_b),
        .addr_c(addr_c), .addr_w(addr_w), .bank_sel(bank_sel),
        .addr_abs(addr_abs), .offset(offset), .imm_out(imm_out)
    );

    always #5 clk = ~clk;

    task tick; begin @(posedge clk); #1; end endtask

    // Word: op=0x120, rd=5, rA=6, rB=7, rC=8, bank=3
    // [31:23]=0x120 [22:18]=5 [17:13]=6 [12:8]=7 [7:3]=8 [2:0]=3
    localparam [31:0] WORD =
        {9'h120, 5'd5, 5'd6, 5'd7, 5'd8, 3'd3};

    initial begin
        clk = 0; load = 0; data_in = 0; imm_sel = 0; reg_b = 32'hCAFE_BABE;

        // no load
        data_in = WORD; load = 0; tick;
        if (opcode !== 9'h000) begin
            $display("FAIL: load gate opcode=%h", opcode);
            $finish(1);
        end

        load = 1; tick; load = 0;
        if (opcode !== 9'h120 || addr_w !== 5'd5 || addr_a !== 5'd6 ||
            addr_b !== 5'd7 || addr_c !== 5'd8 || bank_sel !== 3'd3) begin
            $display("FAIL: field extract op=%h w=%0d a=%0d b=%0d c=%0d bank=%0d",
                     opcode, addr_w, addr_a, addr_b, addr_c, bank_sel);
            $finish(1);
        end
        if (offset !== WORD[21:0] || addr_abs !== WORD[21:0]) begin
            $display("FAIL: offset/abs");
            $finish(1);
        end

        // Imm mux — use WORD bits b=ir[22:0]
        begin : imm_tests
            reg [22:0] b;
            b = WORD[22:0];

            imm_sel = 4'd0; #1;
            if (imm_out !== {24'b0, b[7:0]}) begin $display("FAIL: imm0"); $finish(1); end
            imm_sel = 4'd1; #1;
            if (imm_out !== 32'hCAFE_BABE) begin $display("FAIL: imm1 reg_b"); $finish(1); end
            imm_sel = 4'd2; #1;
            if (imm_out !== {{24{b[7]}}, b[7:0]}) begin $display("FAIL: imm2"); $finish(1); end
            imm_sel = 4'd3; #1;
            if (imm_out !== {{19{b[12]}}, b[12:0]}) begin $display("FAIL: imm3"); $finish(1); end
            imm_sel = 4'd4; #1;
            if (imm_out !== {20'b0, b[11:0]}) begin $display("FAIL: imm4"); $finish(1); end
            imm_sel = 4'd5; #1;
            if (imm_out !== {27'b0, b[22:18]}) begin $display("FAIL: imm5"); $finish(1); end
            imm_sel = 4'd6; #1;
            if (imm_out !== {27'b0, b[20:16]}) begin $display("FAIL: imm6"); $finish(1); end
            imm_sel = 4'd7; #1;
            if (imm_out !== {16'b0, b[15:0]}) begin $display("FAIL: imm7"); $finish(1); end
            imm_sel = 4'd8; #1;
            if (imm_out !== {{16{b[15]}}, b[15:0]}) begin $display("FAIL: imm8"); $finish(1); end
            imm_sel = 4'd9; #1;
            if (imm_out !== {{9{b[22]}}, b}) begin $display("FAIL: imm9"); $finish(1); end
            imm_sel = 4'd10; #1;
            if (imm_out !== {b[22:7], 16'b0}) begin $display("FAIL: imm10"); $finish(1); end
            imm_sel = 4'd11; #1;
            if (imm_out !== {b[22:3], 12'b0}) begin $display("FAIL: imm11 LUI"); $finish(1); end
            imm_sel = 4'd12; #1;
            if (imm_out !== {{14{b[15]}}, b[15:0], 2'b0}) begin $display("FAIL: imm12"); $finish(1); end
            imm_sel = 4'd13; #1;
            if (imm_out !== {{7{b[22]}}, b, 2'b0}) begin $display("FAIL: imm13"); $finish(1); end
            imm_sel = 4'd14; #1;
            if (imm_out !== {9'b0, b}) begin $display("FAIL: imm14"); $finish(1); end
            imm_sel = 4'd15; #1;
            if (imm_out !== {{26{b[14]}}, b[14:9]}) begin $display("FAIL: imm15"); $finish(1); end
        end

        $display("PASS: ir");
        $finish;
    end
endmodule
