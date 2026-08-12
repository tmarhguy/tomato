/*
 * Tomato — VGA 640x480@60 scanout
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : vgatiming.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * 100 MHz → 25 MHz pixel. 80x60 tiles of 8x8. Color from tile[3:0].
 */
module vgatiming (
    input         clk,
    input         reset,
    input  [31:0] tile,
    output [12:0] raddr,
    output        vga_hs,
    output        vga_vs,
    output [3:0]  vga_r,
    output [3:0]  vga_g,
    output [3:0]  vga_b
);
    // 640x480@60 timings (pixel clocks)
    localparam H_VISIBLE = 10'd640;
    localparam H_FP      = 10'd16;
    localparam H_SYNC    = 10'd96;
    localparam H_BP      = 10'd48;
    localparam H_TOTAL   = 10'd800;

    localparam V_VISIBLE = 10'd480;
    localparam V_FP      = 10'd10;
    localparam V_SYNC    = 10'd2;
    localparam V_BP      = 10'd33;
    localparam V_TOTAL   = 10'd525;

    reg [1:0] pixdiv;
    wire pixen = (pixdiv == 2'd3);

    always @(posedge clk) begin
        if (reset) pixdiv <= 2'd0;
        else       pixdiv <= pixdiv + 2'd1;
    end

    reg [9:0] hcnt, vcnt;
    always @(posedge clk) begin
        if (reset) begin
            hcnt <= 10'd0;
            vcnt <= 10'd0;
        end else if (pixen) begin
            if (hcnt == H_TOTAL - 1) begin
                hcnt <= 10'd0;
                if (vcnt == V_TOTAL - 1) vcnt <= 10'd0;
                else                     vcnt <= vcnt + 10'd1;
            end else
                hcnt <= hcnt + 10'd1;
        end
    end

    wire hs_active = (hcnt >= H_VISIBLE + H_FP) &&
                     (hcnt <  H_VISIBLE + H_FP + H_SYNC);
    wire vs_active = (vcnt >= V_VISIBLE + V_FP) &&
                     (vcnt <  V_VISIBLE + V_FP + V_SYNC);
    // Nexys: sync active-low
    assign vga_hs = ~hs_active;
    assign vga_vs = ~vs_active;

    wire visible = (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);

    // Next pixel address one pixel early to cover registered RAM read
    wire [9:0] hx = (hcnt < H_TOTAL - 1) ? (hcnt + 10'd1) : 10'd0;
    wire [9:0] vx = (hcnt < H_TOTAL - 1) ? vcnt :
                    ((vcnt < V_TOTAL - 1) ? (vcnt + 10'd1) : 10'd0);
    wire [6:0] tile_x = hx[9:3]; // 0..79
    wire [5:0] tile_y = vx[9:3]; // 0..59
    assign raddr = {tile_y, tile_x}; // 6+7 = 13

    // 16-color arcade palette (Tomato) — richer than classic CGA while
    // keeping index roles: 0 black, 1 space, 4 tomato, B cyan, C hot, E gold, F white
    wire [3:0] idx = tile[3:0];
    reg [3:0] pr, pg, pb;
    always @(*) begin
        case (idx)
            4'h0: begin pr = 4'h0; pg = 4'h0; pb = 4'h0; end // black
            4'h1: begin pr = 4'h0; pg = 4'h1; pb = 4'h4; end // deep space
            4'h2: begin pr = 4'h0; pg = 4'h8; pb = 4'h2; end // forest
            4'h3: begin pr = 4'h0; pg = 4'h8; pb = 4'h8; end // teal
            4'h4: begin pr = 4'hC; pg = 4'h2; pb = 4'h1; end // tomato red
            4'h5: begin pr = 4'h9; pg = 4'h2; pb = 4'h8; end // plum
            4'h6: begin pr = 4'hB; pg = 4'h6; pb = 4'h1; end // amber
            4'h7: begin pr = 4'hA; pg = 4'hA; pb = 4'hA; end // silver
            4'h8: begin pr = 4'h4; pg = 4'h4; pb = 4'h5; end // gunmetal
            4'h9: begin pr = 4'h4; pg = 4'h6; pb = 4'hF; end // sky
            4'hA: begin pr = 4'h4; pg = 4'hE; pb = 4'h4; end // neon green
            4'hB: begin pr = 4'h3; pg = 4'hE; pb = 4'hE; end // ship cyan
            4'hC: begin pr = 4'hF; pg = 4'h4; pb = 4'h3; end // hot coral
            4'hD: begin pr = 4'hF; pg = 4'h5; pb = 4'hC; end // pink
            4'hE: begin pr = 4'hF; pg = 4'hE; pb = 4'h3; end // gold
            default: begin pr = 4'hF; pg = 4'hF; pb = 4'hF; end // white
        endcase
    end

    assign vga_r = visible ? pr : 4'h0;
    assign vga_g = visible ? pg : 4'h0;
    assign vga_b = visible ? pb : 4'h0;
endmodule
