/*
 * Tomato — instruction register
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : ir.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * [31:23] opcode [22:18] rd [17:13] rA [12:8] rB [7:3] rC [2:0] bank
 *
 * Imm sel 3 (I-type): signed imm13 = IR[12:0] — rd + rA stay independent
 * (old Dig IR[21:10] overlapped both; unusable for ADDI/LW).
 */
module ir (
    input         clk,
    input         load,
    input  [31:0] data_in,
    input  [3:0]  imm_sel,
    input  [31:0] reg_b,
    output [8:0]  opcode,
    output [4:0]  addr_a,
    output [4:0]  addr_b,
    output [4:0]  addr_c,
    output [4:0]  addr_w,
    output [2:0]  bank_sel,
    output [21:0] addr_abs,
    output [21:0] offset,
    output reg [31:0] imm_out
);
    reg [31:0] ir;
    initial ir = 32'h0;
    always @(posedge clk) if (load) ir <= data_in;

    assign opcode   = ir[31:23];
    assign addr_w   = ir[22:18];
    assign addr_a   = ir[17:13];
    assign addr_b   = ir[12:8];
    assign addr_c   = ir[7:3];
    assign bank_sel = ir[2:0];
    assign offset   = ir[21:0];
    assign addr_abs = ir[21:0];

    wire [22:0] b = ir[22:0];

    always @(*) begin
        case (imm_sel)
            4'd0:  imm_out = {24'b0, b[7:0]};
            4'd1:  imm_out = reg_b;
            4'd2:  imm_out = {{24{b[7]}},  b[7:0]};
            4'd3:  imm_out = {{19{b[12]}}, b[12:0]};        // ADDI / LW off13 (rd|rA free)
            4'd4:  imm_out = {20'b0, b[11:0]};
            4'd5:  imm_out = {27'b0, b[22:18]};
            4'd6:  imm_out = {27'b0, b[20:16]};
            4'd7:  imm_out = {16'b0, b[15:0]};              // ANDI/ORI/XORI
            4'd8:  imm_out = {{16{b[15]}}, b[15:0]};
            4'd9:  imm_out = {{9{b[22]}},  b};
            4'd10: imm_out = {b[22:7], 16'b0};
            4'd11: imm_out = {b[22:3], 12'b0};              // LUI
            4'd12: imm_out = {{14{b[15]}}, b[15:0], 2'b0};  // branch ×4
            4'd13: imm_out = {{7{b[22]}},  b, 2'b0};        // jump ×4
            4'd14: imm_out = {9'b0, b};
            4'd15: imm_out = {{26{b[14]}}, b[14:9]};
            default: imm_out = 32'b0;
        endcase
    end
endmodule
