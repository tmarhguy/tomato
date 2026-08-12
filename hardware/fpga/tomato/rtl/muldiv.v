/*
 * Tomato — shift / mul / div
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : muldiv.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * mulen=0: shift (mode = LSL/LSR/ASR/ROR).
 * mulen=1: mul/div; mode[0]=1 → unsigned (MULHU/DIVU/REMU).
 * result = lo/shift/quot; resulthi = hi/rem. Div0: lo=all1, hi=a.
 *
 * FPGA v1: mul/div use synthesizable * / % (DSP/LUT inferred).
 * Discrete Tomato keeps the priority-encoder loop on KiCad — not this RTL.
 */
module muldiv (
    input  [31:0] a,
    input  [31:0] b,
    input  [1:0]  mode,
    input         mulen,
    input         isdiv,
    output [31:0] result,
    output [31:0] resulthi,
    output        anz
);
    wire [31:0] sh;
    shift sh0 (
        .A(a), .mode(mode), .B(b[4:0]), .Out(sh)
    );

    wire usigned = mode[0];

    wire signed [31:0] sa = a;
    wire signed [31:0] sb = b;
    wire [63:0] uprod = a * b;
    wire signed [63:0] sprod = sa * sb;

    wire        div0 = (b == 32'd0);
    wire [31:0] uquot = div0 ? 32'hFFFF_FFFF : (a / b);
    wire [31:0] urem  = div0 ? a             : (a % b);
    wire signed [31:0] squot = div0 ? -32'sd1 : (sa / sb);
    wire signed [31:0] srem  = div0 ? sa      : (sa % sb);

    wire [31:0] prod_lo = usigned ? uprod[31:0]  : sprod[31:0];
    wire [31:0] prod_hi = usigned ? uprod[63:32] : sprod[63:32];
    wire [31:0] quot    = usigned ? uquot : squot;
    wire [31:0] remn    = usigned ? urem  : srem;

    assign result =
        !mulen ? sh      :
         isdiv ? quot    :
                 prod_lo;

    assign resulthi =
        !mulen ? 32'b0   :
         isdiv ? remn    :
                 prod_hi;

    assign anz = |a;
endmodule
