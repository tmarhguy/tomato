// Copyright (c) 2025-2026 Tyrone Marhguy
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// LUT3 mux + 1b programmable slice (from Tomato alu-32b-final export)

`default_nettype none

module Mux_8x1 (
    input  wire [2:0] sel,
    input  wire in_0, in_1, in_2, in_3, in_4, in_5, in_6, in_7,
    output reg out
);
    always @(*) begin
        case (sel)
            3'h0: out = in_0;
            3'h1: out = in_1;
            3'h2: out = in_2;
            3'h3: out = in_3;
            3'h4: out = in_4;
            3'h5: out = in_5;
            3'h6: out = in_6;
            3'h7: out = in_7;
            default: out = 1'b0;
        endcase
    end
endmodule

module alu_1b_final (
    input  wire [7:0] OPCODE,
    input  wire A, B, C,
    output wire MUX_OUT
);
    wire [2:0] sel = {C, B, A};
    Mux_8x1 mux (
        .sel(sel),
        .in_0(OPCODE[0]), .in_1(OPCODE[1]), .in_2(OPCODE[2]), .in_3(OPCODE[3]),
        .in_4(OPCODE[4]), .in_5(OPCODE[5]), .in_6(OPCODE[6]), .in_7(OPCODE[7]),
        .out(MUX_OUT)
    );
endmodule
