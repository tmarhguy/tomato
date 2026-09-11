/*
 * Tomato — text-mode scanout testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : tb/videoout_tb.v
 * Target   : simulation (compile with rtl/board/videoout.v + font_rom.v)
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Covers the three things the scanout can get wrong and the monitor cannot
 * tell you about: the cell address arithmetic, the glyph/attribute decode,
 * and the two-pixel fetch lookahead lining up with the syncs.
 */
`timescale 1ns/1ps
module videoout_tb;
    reg         pix_clk = 0;
    reg         reset = 1;
    reg  [31:0] tile_data = 32'h0;
    wire [12:0] tile_addr;
    wire [3:0]  r, g, b;
    wire        hs, vs, de;

    videoout uut (
        .pix_clk(pix_clk), .reset(reset),
        .tile_addr(tile_addr), .tile_data(tile_data),
        .r(r), .g(g), .b(b), .hs(hs), .vs(vs), .de(de)
    );

    always #20 pix_clk = ~pix_clk;   // 25 MHz

    task tick; begin @(posedge pix_clk); #1; end endtask

    integer i, ink_pixels, lit_rows;
    reg [9:0] h_lo, h_hi, v_lo;
    reg [11:0] expected_paper;

    initial begin
        tick; tick;
        reset = 0;
        tick;

        // ---- cell address is ty*80 + tx, matching what software writes -----
        uut.fh = 10'd16;   // tx = 2
        uut.fv = 10'd8;    // ty = 1
        #1;
        if (tile_addr !== 13'd82) begin
            $display("FAIL: tile_addr=%0d want 82 (ty*80+tx)", tile_addr);
            $finish(1);
        end
        uut.fh = 10'd632;  // tx = 79
        uut.fv = 10'd472;  // ty = 59
        #1;
        if (tile_addr !== 13'd4799) begin
            $display("FAIL: last cell tile_addr=%0d want 4799", tile_addr);
            $finish(1);
        end

        // ---- legacy solid cell: [15:8] == 0 paints palette[3:0] ------------
        uut.fh = 10'd0; uut.fv = 10'd0;
        tile_data = 32'h0000_0004;      // tomato red
        repeat (4) tick;
        if (r !== 4'hC || g !== 4'h2 || b !== 4'h1) begin
            $display("FAIL: legacy solid rgb=%h%h%h want C21", r, g, b);
            $finish(1);
        end

        // ---- glyph cell: a full block in gold on black --------------------
        tile_data = 32'h0000_0EDB;      // glyph 0xDB, fg=E, bg=0
        repeat (4) tick;
        if (r !== 4'hF || g !== 4'hE || b !== 4'h3) begin
            $display("FAIL: block glyph rgb=%h%h%h want FE3", r, g, b);
            $finish(1);
        end

        // ---- a blank glyph shows the background, not the foreground -------
        tile_data = 32'h0000_4F20;      // space, fg=F, bg=4
        repeat (4) tick;
        if (r !== 4'hC || g !== 4'h2 || b !== 4'h1) begin
            $display("FAIL: space bg rgb=%h%h%h want C21 (tomato)", r, g, b);
            $finish(1);
        end

        // ---- '|' (0x7C) is ink on some columns and paper on others --------
        uut.fh = 10'd0; uut.fv = 10'd0;
        tile_data = 32'h0000_0F7C;
        ink_pixels = 0;
        repeat (3) tick;                 // flush the pipeline to column 0
        for (i = 0; i < 8; i = i + 1) begin
            if (r === 4'hF && g === 4'hF && b === 4'hF) ink_pixels = ink_pixels + 1;
            tick;
        end
        if (ink_pixels == 0 || ink_pixels == 8) begin
            $display("FAIL: glyph 0x7C rendered %0d/8 ink pixels", ink_pixels);
            $finish(1);
        end

        // Bitmap origin, scaling and glass must align with glyphs in the
        // same three-clock pipeline. Test edges and distant image locations.
        for (i=0; i<12; i=i+1) begin
            uut.fh = (i==11) ? 638 : i*52;
            uut.fv = (i==11) ? 478 : i*34;
            expected_paper = uut.wallpaper[(uut.fv/2)*320+uut.fh/2];
            tile_data = 32'h00010f20;
            repeat (3) tick;
            if ({r,g,b} !== expected_paper)
                $fatal(1,"bitmap alignment pixel %0d got %h want %h",i,{r,g,b},expected_paper);
            uut.fh = (i==11) ? 638 : i*52;
            uut.fv = (i==11) ? 478 : i*34;
            tile_data = 32'h00030f20;
            repeat (3) tick;
            if ({r,g,b} !== {2'b0,expected_paper[11:10],2'b0,expected_paper[7:6],2'b0,expected_paper[3:2]})
                $fatal(1,"glass pixel mismatch");
        end
        // Full block remains foreground even over wallpaper.
        uut.fh=20; uut.fv=20;
        tile_data=32'h00070fdb;
        repeat (3) tick;
        if ({r,g,b} !== 12'hfff) $fatal(1,"large foreground lost over bitmap");

        // ---- syncs are active low and land in the right window ------------
        uut.fh = 10'd660; uut.fv = 10'd0;   // inside H sync [656, 752)
        repeat (3) tick;
        if (hs !== 1'b0) begin
            $display("FAIL: hs=%b want 0 inside sync", hs);
            $finish(1);
        end
        uut.fh = 10'd100; uut.fv = 10'd0;
        repeat (3) tick;
        if (hs !== 1'b1) begin
            $display("FAIL: hs=%b want 1 outside sync", hs);
            $finish(1);
        end
        uut.fh = 10'd0; uut.fv = 10'd492;   // inside V sync [490, 492)... just past
        repeat (3) tick;
        if (vs !== 1'b1) begin
            $display("FAIL: vs=%b want 1 past sync", vs);
            $finish(1);
        end
        uut.fh = 10'd0; uut.fv = 10'd491;
        repeat (3) tick;
        if (vs !== 1'b0) begin
            $display("FAIL: vs=%b want 0 inside sync", vs);
            $finish(1);
        end

        // ---- blanking really blanks ---------------------------------------
        uut.fh = 10'd700; uut.fv = 10'd0;
        tile_data = 32'h0000_0FDB;
        repeat (4) tick;
        if (de !== 1'b0 || r !== 4'h0 || g !== 4'h0 || b !== 4'h0) begin
            $display("FAIL: blanking de=%b rgb=%h%h%h", de, r, g, b);
            $finish(1);
        end

        $display("PASS: videoout");
        $finish;
    end
endmodule
