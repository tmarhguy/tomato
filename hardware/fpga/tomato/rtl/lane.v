/*
 * Tomato — byte-lane decoder
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : lane.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * Width/sign format for loads; sel from mem-io microcode.
 */
module lane (
    input  [31:0] mem_in,
    input  [3:0]  sel,
    input  [7:0]  io_data,
    output reg [31:0] mem_out
);
    wire [7:0]  b0 = mem_in[7:0],   b1 = mem_in[15:8];
    wire [7:0]  b2 = mem_in[23:16], b3 = mem_in[31:24];
    wire [15:0] h0 = mem_in[15:0],  h1 = mem_in[31:16];

    always @(*) begin
        case (sel)
            4'd0:  mem_out = mem_in;
            4'd1:  mem_out = {b0, b1, b2, b3};
            4'd2:  mem_out = {24'b0, io_data};
            4'd3:  mem_out = 32'b0;
            4'd4:  mem_out = {{24{b0[7]}}, b0};
            4'd5:  mem_out = {{24{b1[7]}}, b1};
            4'd6:  mem_out = {{24{b2[7]}}, b2};
            4'd7:  mem_out = {{24{b3[7]}}, b3};
            4'd8:  mem_out = {24'b0, b0};
            4'd9:  mem_out = {24'b0, b1};
            4'd10: mem_out = {24'b0, b2};
            4'd11: mem_out = {24'b0, b3};
            4'd12: mem_out = {{16{h0[15]}}, h0};
            4'd13: mem_out = {{16{h1[15]}}, h1};
            4'd14: mem_out = {16'b0, h0};
            4'd15: mem_out = {16'b0, h1};
            default: mem_out = mem_in;
        endcase
    end
endmodule
