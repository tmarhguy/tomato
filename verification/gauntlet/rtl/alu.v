/*
 * Tomato — dual-LUT ALU
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : alu.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * From alu-32b-final.dig. out = f(a,b,c) + g(a,b,c) + cin.
 * csr: [0]Z [1]~Z [2]N [3]C [4]V [5]LT [6]GT [7]GTE
 */
 
module alu1b (
    input  [7:0] lut,
    input        A, B, C,
    output       out
);
    assign out = lut[{C, B, A}];
endmodule

module alu4b (
    input  [7:0]  lutA,
    input  [7:0]  lutB,
    input  [3:0]  A, B, C,
    input         cin,
    output [3:0]  sum,
    output        cout
);
    wire [3:0] fa, fb;
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : g
            alu1b ua (.lut(lutA), .A(A[i]), .B(B[i]), .C(C[i]), .out(fa[i]));
            alu1b ub (.lut(lutB), .A(A[i]), .B(B[i]), .C(C[i]), .out(fb[i]));
        end
    endgenerate
    assign {cout, sum} = {1'b0, fa} + {1'b0, fb} + {4'b0, cin};
endmodule

module alu8b (
    input  [7:0]  lutA,
    input  [7:0]  lutB,
    input  [7:0]  A, B, C,
    input         cin,
    output [7:0]  sum,
    output        cout
);
    wire c4;
    alu4b lo (.lutA(lutA), .lutB(lutB), .A(A[3:0]), .B(B[3:0]), .C(C[3:0]), .cin(cin), .sum(sum[3:0]), .cout(c4));
    alu4b hi (.lutA(lutA), .lutB(lutB), .A(A[7:4]), .B(B[7:4]), .C(C[7:4]), .cin(c4),  .sum(sum[7:4]), .cout(cout));
endmodule

module alu (
    input  [7:0]  lutA,
    input  [7:0]  lutB,
    input  [31:0] A,
    input  [31:0] B,
    input  [31:0] C,
    input  [2:0]  csel,
    input         flag_we,
    input         clk,
    output [31:0] out,
    output [7:0]  csr
);
    // csr: [0]Z [1]~Z [2]N [3]C [4]V [5]LT [6]GT [7]GTE
    // csel: 0,1,N,Z,C,GT,LT,V
    reg [7:0] flags;
    wire cin =
        (csel == 3'd0) ? 1'b0 :
        (csel == 3'd1) ? 1'b1 :
        (csel == 3'd2) ? flags[2] :
        (csel == 3'd3) ? flags[0] :
        (csel == 3'd4) ? flags[3] :
        (csel == 3'd5) ? flags[6] :
        (csel == 3'd6) ? flags[5] :
                         flags[4];

    wire c8, c16, c24, c32;
    wire [31:0] sum;
    alu8b b0 (.lutA(lutA), .lutB(lutB), .A(A[7:0]),   .B(B[7:0]),   .C(C[7:0]),   .cin(cin), .sum(sum[7:0]),   .cout(c8));
    alu8b b1 (.lutA(lutA), .lutB(lutB), .A(A[15:8]),  .B(B[15:8]),  .C(C[15:8]),  .cin(c8),  .sum(sum[15:8]),  .cout(c16));
    alu8b b2 (.lutA(lutA), .lutB(lutB), .A(A[23:16]), .B(B[23:16]), .C(C[23:16]), .cin(c16), .sum(sum[23:16]), .cout(c24));
    alu8b b3 (.lutA(lutA), .lutB(lutB), .A(A[31:24]), .B(B[31:24]), .C(C[31:24]), .cin(c24), .sum(sum[31:24]), .cout(c32));

    assign out = sum;

    wire aeff = lutA[{C[31], B[31], A[31]}];
    wire beff = lutB[{C[31], B[31], A[31]}];
    wire z    = (sum == 32'h0);
    wire n    = sum[31];
    wire c    = c32;
    wire v    = (aeff ^ n) & (n ^ beff);
    wire lt   = v ^ n;
    wire gte  = ~lt;
    wire gt   = ~z & gte;
    wire [7:0] flags_next = {gte, gt, lt, v, c, n, ~z, z};

    always @(posedge clk) begin
        if (flag_we) flags <= flags_next;
    end
    initial flags = 8'h0;
    assign csr = flags;
endmodule
