// Copyright (c) 2025-2026 Tyrone Marhguy
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// 32-bit Kogge-Stone parallel prefix adder — industry fastest classical topology.
// Benchmark for Sky130 HD synthesis vs Tomato ALU ripple structure.

`default_nettype none

module kogge_stone_32 (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire        cin,
    output wire [31:0] sum,
    output wire        cout
);
    wire [31:0] p = a ^ b;
    wire [31:0] g = a & b;

    wire [31:0] g_lvl [0:5];
    wire [31:0] p_lvl [0:5];

    assign g_lvl[0] = g;
    assign p_lvl[0] = p;

    // Level 1: span 1
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : L1
            if (i == 0) begin
                assign g_lvl[1][i] = g_lvl[0][i];
                assign p_lvl[1][i] = p_lvl[0][i];
            end else begin
                assign g_lvl[1][i] = g_lvl[0][i] | (p_lvl[0][i] & g_lvl[0][i-1]);
                assign p_lvl[1][i] = p_lvl[0][i] & p_lvl[0][i-1];
            end
        end
    endgenerate

    // Level 2: span 2
    generate
        for (i = 0; i < 32; i = i + 1) begin : L2
            if (i < 2) begin
                assign g_lvl[2][i] = g_lvl[1][i];
                assign p_lvl[2][i] = p_lvl[1][i];
            end else begin
                assign g_lvl[2][i] = g_lvl[1][i] | (p_lvl[1][i] & g_lvl[1][i-2]);
                assign p_lvl[2][i] = p_lvl[1][i] & p_lvl[1][i-2];
            end
        end
    endgenerate

    // Level 3: span 4
    generate
        for (i = 0; i < 32; i = i + 1) begin : L3
            if (i < 4) begin
                assign g_lvl[3][i] = g_lvl[2][i];
                assign p_lvl[3][i] = p_lvl[2][i];
            end else begin
                assign g_lvl[3][i] = g_lvl[2][i] | (p_lvl[2][i] & g_lvl[2][i-4]);
                assign p_lvl[3][i] = p_lvl[2][i] & p_lvl[2][i-4];
            end
        end
    endgenerate

    // Level 4: span 8
    generate
        for (i = 0; i < 32; i = i + 1) begin : L4
            if (i < 8) begin
                assign g_lvl[4][i] = g_lvl[3][i];
                assign p_lvl[4][i] = p_lvl[3][i];
            end else begin
                assign g_lvl[4][i] = g_lvl[3][i] | (p_lvl[3][i] & g_lvl[3][i-8]);
                assign p_lvl[4][i] = p_lvl[3][i] & p_lvl[3][i-8];
            end
        end
    endgenerate

    // Level 5: span 16
    generate
        for (i = 0; i < 32; i = i + 1) begin : L5
            if (i < 16) begin
                assign g_lvl[5][i] = g_lvl[4][i];
                assign p_lvl[5][i] = p_lvl[4][i];
            end else begin
                assign g_lvl[5][i] = g_lvl[4][i] | (p_lvl[4][i] & g_lvl[4][i-16]);
                assign p_lvl[5][i] = p_lvl[4][i] & p_lvl[4][i-16];
            end
        end
    endgenerate

    wire [31:0] carry_in;
    assign carry_in[0] = cin;
    generate
        for (i = 1; i < 32; i = i + 1) begin : CIN
            assign carry_in[i] = g_lvl[5][i-1];
        end
    endgenerate

    assign sum = p ^ carry_in;
    assign cout = g_lvl[5][31];
endmodule
