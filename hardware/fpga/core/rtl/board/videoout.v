/*
 * Tomato — text-mode scanout for the 12-bit DVI PMOD
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : rtl/board/videoout.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * 640x480@60 from a real 25 MHz pixel clock (one pixel per clock — same
 * timing hdmi_test proved on the glass). 80x60 grid of 8x8 cells.
 *
 * Tile word written by the CPU into the VGA window (see rtl/vga.v):
 *
 *   [ 7: 0] glyph   CP437-ish code, looked up in font_rom
 *   [11: 8] fg      palette index for set pixels
 *   [15:12] bg      palette index for clear pixels
 *
 * Legacy escape: a word whose [15:8] are all zero is a SOLID cell painted in
 * palette[3:0]. That keeps the pre-font tile images (snake, bounce, sudoku)
 * rendering as flat colour blocks, and costs the OS nothing since any cell it
 * draws sets a foreground.
 *
 * Cell index is ty*80 + tx — the same arithmetic the software does. (The
 * pre-PMOD scanout packed {ty,tx} = ty*128 + tx and never agreed with any
 * program that wrote the framebuffer.)
 *
 * Pipeline, all at pix_clk: the fetch counters run two pixels ahead of the
 * displayed pixel to cover the registered tile RAM read and the registered
 * font ROM read. Syncs are delayed to match.
 */
module videoout (
    input             pix_clk,
    input             reset,
    // Tile RAM read port (registered read, 1 cycle)
    output     [12:0] tile_addr,
    input      [31:0] tile_data,
    // Pixel stream
    output reg [3:0]  r,
    output reg [3:0]  g,
    output reg [3:0]  b,
    output reg        hs,
    output reg        vs,
    output reg        de
);
    localparam H_VISIBLE = 10'd640;
    localparam H_FP      = 10'd16;
    localparam H_SYNC    = 10'd96;
    localparam H_TOTAL   = 10'd800;

    localparam V_VISIBLE = 10'd480;
    localparam V_FP      = 10'd10;
    localparam V_SYNC    = 10'd2;
    localparam V_TOTAL   = 10'd525;

    // ---- fetch position (two pixels ahead of what leaves the module) -------
    reg [9:0] fh, fv;
    always @(posedge pix_clk) begin
        if (reset) begin
            fh <= 10'd0;
            fv <= 10'd0;
        end else if (fh == H_TOTAL - 1) begin
            fh <= 10'd0;
            fv <= (fv == V_TOTAL - 1) ? 10'd0 : (fv + 10'd1);
        end else begin
            fh <= fh + 10'd1;
        end
    end

    wire [6:0] tx = fh[9:3];
    wire [5:0] ty = fv[9:3];
    // ty*80 = ty*64 + ty*16
    wire [12:0] row_base = {1'b0, ty, 6'b0} + {3'b0, ty, 4'b0};
    assign tile_addr = row_base + {6'b0, tx};

    wire f_de = (fh < H_VISIBLE) && (fv < V_VISIBLE);
    wire f_hs = ~((fh >= H_VISIBLE + H_FP) && (fh < H_VISIBLE + H_FP + H_SYNC));
    wire f_vs = ~((fv >= V_VISIBLE + V_FP) && (fv < V_VISIBLE + V_FP + V_SYNC));

    // ---- stage 1: tile_data valid --------------------------------------------
    reg [2:0] row_s1;
    reg [2:0] col_s1;
    reg       de_s1, hs_s1, vs_s1;
    always @(posedge pix_clk) begin
        row_s1 <= fv[2:0];
        col_s1 <= fh[2:0];
        de_s1  <= f_de;
        hs_s1  <= f_hs;
        vs_s1  <= f_vs;
    end

    wire [7:0] glyph = tile_data[7:0];
    wire [3:0] fg    = tile_data[11:8];
    wire [3:0] bg    = tile_data[15:12];
    wire       solid = (tile_data[15:8] == 8'h00);

    wire [7:0] font_data;
    font_rom font (
        .clk  (pix_clk),
        .addr ({glyph, row_s1}),
        .data (font_data)
    );

    // ---- stage 2: font_data valid --------------------------------------------
    reg [2:0] col_s2;
    reg [3:0] fg_s2, bg_s2, solid_s2;
    reg       is_solid_s2;
    reg       de_s2, hs_s2, vs_s2;
    always @(posedge pix_clk) begin
        col_s2      <= col_s1;
        fg_s2       <= fg;
        bg_s2       <= bg;
        solid_s2    <= tile_data[3:0];
        is_solid_s2 <= solid;
        de_s2       <= de_s1;
        hs_s2       <= hs_s1;
        vs_s2       <= vs_s1;
    end

    wire       ink = font_data[col_s2];
    wire [3:0] idx = is_solid_s2 ? solid_s2 : (ink ? fg_s2 : bg_s2);

    // 16-colour arcade palette — index roles the OS relies on:
    // 0 black, 1 deep space, 4 tomato, 7 silver, B cyan, C coral, E gold, F white
    reg [3:0] pr, pg, pb;
    always @(*) begin
        case (idx)
            4'h0: begin pr = 4'h0; pg = 4'h0; pb = 4'h0; end
            4'h1: begin pr = 4'h0; pg = 4'h1; pb = 4'h4; end
            4'h2: begin pr = 4'h0; pg = 4'h8; pb = 4'h2; end
            4'h3: begin pr = 4'h0; pg = 4'h8; pb = 4'h8; end
            4'h4: begin pr = 4'hC; pg = 4'h2; pb = 4'h1; end
            4'h5: begin pr = 4'h9; pg = 4'h2; pb = 4'h8; end
            4'h6: begin pr = 4'hB; pg = 4'h6; pb = 4'h1; end
            4'h7: begin pr = 4'hA; pg = 4'hA; pb = 4'hA; end
            4'h8: begin pr = 4'h4; pg = 4'h4; pb = 4'h5; end
            4'h9: begin pr = 4'h4; pg = 4'h6; pb = 4'hF; end
            4'hA: begin pr = 4'h4; pg = 4'hE; pb = 4'h4; end
            4'hB: begin pr = 4'h3; pg = 4'hE; pb = 4'hE; end
            4'hC: begin pr = 4'hF; pg = 4'h4; pb = 4'h3; end
            4'hD: begin pr = 4'hF; pg = 4'h5; pb = 4'hC; end
            4'hE: begin pr = 4'hF; pg = 4'hE; pb = 4'h3; end
            default: begin pr = 4'hF; pg = 4'hF; pb = 4'hF; end
        endcase
    end

    always @(posedge pix_clk) begin
        r  <= de_s2 ? pr : 4'h0;
        g  <= de_s2 ? pg : 4'h0;
        b  <= de_s2 ? pb : 4'h0;
        de <= de_s2;
        hs <= hs_s2;
        vs <= vs_s2;
    end
endmodule
