/*
 * Tomato — VGA timing testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : vgatiming_tb.v
 * Target   : simulation (compile with rtl/vgatiming.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
`timescale 1ns/1ps
module vgatiming_tb;
    reg         clk, reset;
    reg  [31:0] tile;
    wire [12:0] raddr;
    wire        vga_hs, vga_vs;
    wire [3:0]  vga_r, vga_g, vga_b;

    vgatiming uut (
        .clk(clk), .reset(reset), .tile(tile), .raddr(raddr),
        .vga_hs(vga_hs), .vga_vs(vga_vs),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );

    always #5 clk = ~clk;

    task tick; begin @(posedge clk); #1; end endtask

    initial begin
        clk = 0; reset = 1; tile = 32'h0;
        tick; tick;
        reset = 0;

        // Idle black at reset position (visible origin)
        tile = 32'h0;
        repeat (8) tick;
        if (vga_r !== 0 || vga_g !== 0 || vga_b !== 0) begin
            $display("FAIL: black palette");
            $finish(1);
        end

        // Palette index 4 → tomato red (arcade palette)
        tile = 32'h0000_0004;
        // Stay in visible region: force counters
        uut.hcnt = 10'd0;
        uut.vcnt = 10'd0;
        uut.pixdiv = 2'd3; // next tick advances? pixen when pixdiv==3
        tick;
        if (vga_r !== 4'hC || vga_g !== 4'h2 || vga_b !== 4'h1) begin
            $display("FAIL: palette4 rgb=%h%h%h want C21", vga_r, vga_g, vga_b);
            $finish(1);
        end

        // Outside visible → blank
        uut.hcnt = 10'd700;
        uut.vcnt = 10'd0;
        tick;
        if (vga_r !== 0 || vga_g !== 0 || vga_b !== 0) begin
            $display("FAIL: blanking");
            $finish(1);
        end

        // Sync active-low during H sync window: h in [656, 752)
        uut.hcnt = 10'd660;
        uut.vcnt = 10'd0;
        tick;
        if (vga_hs !== 1'b0) begin
            $display("FAIL: hsync active-low got %b", vga_hs);
            $finish(1);
        end
        uut.hcnt = 10'd0;
        tick;
        if (vga_hs !== 1'b1) begin
            $display("FAIL: hsync inactive");
            $finish(1);
        end

        // raddr packing: tile_y=1,tile_x=2 → hx/vx are hcnt+1 lookahead
        uut.hcnt = 10'd15; // hx=16 → tile_x=2; vx=vcnt
        uut.vcnt = 10'd8;  // tile_y=1
        #1;
        if (raddr !== {6'd1, 7'd2}) begin
            $display("FAIL: raddr=%h", raddr);
            $finish(1);
        end

        $display("PASS: vgatiming");
        $finish;
    end
endmodule
