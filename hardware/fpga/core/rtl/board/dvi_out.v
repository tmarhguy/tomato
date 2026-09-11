/*
 * Tomato — 12-bit DVI PMOD (TFP410) output stage
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : rtl/board/dvi_out.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Lifted verbatim in spirit from hardware/fpga/hdmi_test — the arrangement
 * that actually lit a monitor: every payload bit registered on the pixel
 * clock, and the pixel clock itself forwarded through an ODDR so the TFP410
 * samples on a clean board-level edge rather than a routed fabric net.
 */
module dvi_out (
    input        pix_clk,
    input  [3:0] r,
    input  [3:0] g,
    input  [3:0] b,
    input        hs,
    input        vs,
    input        de,
    output reg [3:0] dvi_r,
    output reg [3:0] dvi_g,
    output reg [3:0] dvi_b,
    output reg   dvi_hs,
    output reg   dvi_vs,
    output reg   dvi_de,
    output       dvi_clk
);
    always @(posedge pix_clk) begin
        dvi_r  <= r;
        dvi_g  <= g;
        dvi_b  <= b;
        dvi_hs <= hs;
        dvi_vs <= vs;
        dvi_de <= de;
    end

`ifdef TOMATO_SIM
    assign dvi_clk = pix_clk;
`else
    ODDR #(
        .DDR_CLK_EDGE ("SAME_EDGE"),
        .INIT         (1'b0),
        .SRTYPE       ("SYNC")
    ) oddr_dvi_clk (
        .Q  (dvi_clk),
        .C  (pix_clk),
        .CE (1'b1),
        .D1 (1'b1),
        .D2 (1'b0),
        .R  (1'b0),
        .S  (1'b0)
    );
`endif
endmodule
