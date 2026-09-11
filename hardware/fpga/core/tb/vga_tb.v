/*
 * Tomato — VGA MMIO testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : vga_tb.v
 * Target   : simulation (compile with rtl/vga.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
`timescale 1ns/1ps
module vga_tb;
    reg         clk, mem_wr;
    reg  [23:0] mem_addr;
    reg  [31:0] mem_din;
    reg  [12:0] raddr;
    wire [31:0] rdata;

    vga uut (
        .clk(clk), .mem_addr(mem_addr), .mem_din(mem_din),
        .mem_wr(mem_wr), .rclk(clk), .raddr(raddr), .rdata(rdata)
    );

    always #5 clk = ~clk;

    task tick; begin @(posedge clk); #1; end endtask

    initial begin
        clk = 0; mem_addr = 0; mem_din = 0; mem_wr = 0; raddr = 0;

        // Out of window with mem_wr — no write
        mem_addr = 24'h00_0005; mem_din = 32'hAABB_CCDD; mem_wr = 1;
        tick;
        mem_wr = 0; raddr = 13'd5;
        tick; // registered read
        // may be X; proceed to in-window write

        // In window: [21:19]==110 → 0x30_xxxx
        mem_addr = 24'h30_0005;
        mem_din  = 32'h1234_5678;
        mem_wr   = 1;
        tick;
        mem_wr = 0;
        raddr  = 13'd5;
        tick;
        if (rdata !== 32'h1234_5678) begin
            $display("FAIL: vga readback got %h", rdata);
            $finish(1);
        end

        mem_addr = 24'h30_0064; // tile 100
        mem_din  = 32'hDEAD_BEEF;
        mem_wr   = 1;
        tick;
        mem_wr = 0; raddr = 13'd100;
        tick;
        if (rdata !== 32'hDEAD_BEEF) begin
            $display("FAIL: tile100 got %h", rdata);
            $finish(1);
        end

        // Window guard / mem_wr=0
        mem_addr = 24'h30_0005;
        mem_din  = 32'hFFFF_FFFF;
        mem_wr   = 0;
        tick;
        raddr = 13'd5; tick;
        if (rdata !== 32'h1234_5678) begin
            $display("FAIL: mem_wr gate got %h", rdata);
            $finish(1);
        end

        // Out of window must not overwrite
        mem_addr = 24'h00_0005; mem_din = 32'hFFFF_FFFF; mem_wr = 1;
        tick;
        mem_wr = 0; raddr = 13'd5; tick;
        if (rdata !== 32'h1234_5678) begin
            $display("FAIL: window guard got %h", rdata);
            $finish(1);
        end

        $display("PASS: vga");
        $finish;
    end
endmodule
