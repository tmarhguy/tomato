// Copyright (c) 2025-2026 Tyrone Marhguy
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Tomato ALU datapath: dual LUT3 planes + Kogge-Stone 32b add (same principle, fastest carry).

`default_nettype none

module alu_32b_kogge_stone (
    input  wire [7:0]  lutA,
    input  wire [7:0]  lutB,
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [31:0] C,
    input  wire [2:0]  csel,
    input  wire        FLAG_WE,
    input  wire        CLK,
    output wire [31:0] OUT,
    output wire [7:0]  csr
);
    wire [31:0] plane_lutB;
    wire [31:0] plane_lutA;
    wire        cout_ks;

    alu_lut_planes_32 planes (
        .lutA(lutA),
        .lutB(lutB),
        .A(A), .B(B), .C(C),
        .plane_lutB(plane_lutB),
        .plane_lutA(plane_lutA)
    );

    // Carry in from csel (bit 0 = external cin on arithmetic path; flags omitted in this benchmark)
    kogge_stone_32 adder (
        .a(plane_lutB),
        .b(plane_lutA),
        .cin(csel[0]),
        .sum(OUT),
        .cout(cout_ks)
    );

    assign csr = 8'b0;
endmodule
