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

    // One multiplier, not one per signedness. Widening both operands by their
    // sign bit — or by zero when unsigned — makes a single signed 33x33 cover
    // both cases; the low half is identical either way and only the high half
    // ever differed. Two 32x32 products cost eight DSP48s in eight cascaded
    // pairs, and nextpnr cannot route a PCOUT/PCIN cascade across DSP columns.
    wire signed [32:0] mula = {usigned ? 1'b0 : a[31], a};
    wire signed [32:0] mulb = {usigned ? 1'b0 : b[31], b};
    wire signed [65:0] prod = mula * mulb;

    // One divider likewise: divide magnitudes, then re-apply the signs. Verilog
    // truncates toward zero and gives the remainder the dividend's sign, which
    // is exactly what negating back does — including -2^31 / -1, where the
    // magnitude 2^31 wraps to -2^31 the same way the operator would.
    wire        div0 = (b == 32'd0);
    wire        neg_a = ~usigned & a[31];
    wire        neg_b = ~usigned & b[31];
    wire [31:0] mag_a = neg_a ? -a : a;
    wire [31:0] mag_b = neg_b ? -b : b;
    wire [31:0] mag_q = div0 ? 32'hFFFF_FFFF : (mag_a / mag_b);
    wire [31:0] mag_r = div0 ? mag_a         : (mag_a % mag_b);

    wire [31:0] prod_lo = prod[31:0];
    wire [31:0] prod_hi = prod[63:32];
    wire [31:0] quot    = div0            ? 32'hFFFF_FFFF        // -1 either way
                        : (neg_a ^ neg_b) ? -mag_q : mag_q;
    wire [31:0] remn    = div0  ? a
                        : neg_a ? -mag_r : mag_r;

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
