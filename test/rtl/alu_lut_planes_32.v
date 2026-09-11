// Copyright (c) 2025-2026 Tyrone Marhguy
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// 32-bit dual LUT planes: f = lutB(A,B,C), g = lutA(A,B,C) per bit.

`default_nettype none

module alu_lut_planes_32 (
    input  wire [7:0]  lutA,
    input  wire [7:0]  lutB,
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [31:0] C,
    output wire [31:0] plane_lutB,
    output wire [31:0] plane_lutA
);
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : g_bit
            alu_1b_final lutB_i (
                .OPCODE(lutB),
                .A(A[i]), .B(B[i]), .C(C[i]),
                .MUX_OUT(plane_lutB[i])
            );
            alu_1b_final lutA_i (
                .OPCODE(lutA),
                .A(A[i]), .B(B[i]), .C(C[i]),
                .MUX_OUT(plane_lutA[i])
            );
        end
    endgenerate
endmodule
