/*
 * Tomato — Tomato OS end-to-end testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : tb/os_tb.v
 * Target   : simulation (cwd = hardware/fpga/core)
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * Boots the OS image, feeds it keystrokes through the keyboard MMIO exactly
 * the way rtl/board/keypad.v does, and prints the framebuffer as text. A
 * monitor cannot tell you why a screen is wrong; this can, before the bitstream
 * is ever built.
 *
 *   +PROG=<name>   image under tb/mem  (default tomato_os)
 *   +KEYS=<hex>    keystrokes to send, e.g. 1f1f0d for down,down,enter
 *   +SETTLE=<n>    cycles to run between keys (default 400000)
 *   +DUMP=1        print the framebuffer after each key
 */
`timescale 1ns/1ps
module os_tb;
    reg clk = 0;
    reg reset = 1;
    reg  [7:0]  kb_data = 8'h00;
    reg         kb_ready = 1'b0;
    wire [7:0]  io_out;
    wire [31:0] disp_value;
    wire        kb_rd, halted;
    reg  [12:0] tile_raddr = 13'd0;
    wire [31:0] tile_rdata;

    always #5 clk = ~clk;

    main uut (
        .clk(clk), .reset(reset),
        .kb_data(kb_data), .kb_ready(kb_ready), .kb_rd(kb_rd),
        .io_out(io_out), .disp_value(disp_value), .halted(halted),
        .tile_rclk(clk), .tile_raddr(tile_raddr), .tile_rdata(tile_rdata)
    );

    // Same handshake as the keypad: the key clears when the CPU reads it.
    always @(posedge clk) if (kb_rd) kb_ready <= 1'b0;

    task tick; begin @(posedge clk); #1; end endtask

    task press;
        input [7:0] code;
        integer guard;
        begin
            kb_data  = code;
            kb_ready = 1'b1;
            guard = 0;
            while (kb_ready && guard < 200000) begin
                tick;
                guard = guard + 1;
            end
            if (kb_ready) begin
                $display("FAIL: key %02h never consumed (CPU not polling)", code);
                $finish(1);
            end
        end
    endtask

    // ---- framebuffer → text ------------------------------------------------
    integer x, y;
    reg [31:0] fb_word;
    
    reg [8*80-1:0] line;

    function [7:0] printable;
        input [31:0] word;
        begin
            if (word[15:8] == 8'h00)
                printable = (word[3:0] == 4'h0) ? 8'h20 : 8'h23;   // blank / '#'
            else if (word[7:0] >= 8'h20 && word[7:0] < 8'h7F)
                printable = word[7:0];
            else if (word[7:0] == 8'h00)
                printable = 8'h20;
            else
                printable = 8'h2E;                                  // '.'
        end
    endfunction

    task dump_screen;
        begin
            $display("+------------------------------------------------------------------------------+");
            for (y = 0; y < 60; y = y + 1) begin
                line = 0;
                for (x = 0; x < 80; x = x + 1) begin
                    fb_word = {uut.vga0.hi[y * 80 + x], uut.vga0.lo[y * 80 + x]};
                    line = {line[8*79-1:0], printable(fb_word)};
                end
                $display("|%0s|", line);
            end
            $display("+------------------------------------------------------------------------------+");
        end
    endtask

    // Count non-blank cells so the test can assert something actually drew.
    function integer painted;
        input dummy;
        integer i, n;
        begin
            n = 0;
            for (i = 0; i < 4800; i = i + 1)
                if ({uut.vga0.hi[i], uut.vga0.lo[i]} != 32'h0) n = n + 1;
            painted = n;
        end
    endfunction

    integer k, nkeys, settle, want_dump, drawn;
    reg [8*64-1:0] prog;
    reg [1023:0]   path;
    reg [8*32-1:0] keys_arg;
    reg [7:0]      keys [0:31];

    // Parse an ASCII hex string of keycodes into a byte list.
    task parse_keys;
        input [8*32-1:0] s;
        integer i, n, hi_nib;
        reg [7:0] c;
        begin
            // $value$plusargs right-justifies, so walk down from the top byte
            // and take the non-NUL hex digits in order, two per keycode.
            n = 0;
            nkeys = 0;
            hi_nib = 0;
            for (i = 31; i >= 0; i = i - 1) begin
                c = s[i*8 +: 8];
                if (c != 8'h00) begin
                    if (n[0] == 0) hi_nib = hex_val(c);
                    else begin
                        keys[nkeys] = (hi_nib << 4) | hex_val(c);
                        nkeys = nkeys + 1;
                    end
                    n = n + 1;
                end
            end
        end
    endtask

    function integer hex_val;
        input [7:0] c;
        begin
            if (c >= "0" && c <= "9")      hex_val = c - "0";
            else if (c >= "a" && c <= "f") hex_val = c - "a" + 10;
            else if (c >= "A" && c <= "F") hex_val = c - "A" + 10;
            else                           hex_val = 0;
        end
    endfunction

    initial begin
        prog     = "tomato_os";
        keys_arg = "";
        settle   = 200000;
        want_dump = 0;
        nkeys = 0;

        if ($value$plusargs("PROG=%s", prog)) begin end
        if ($value$plusargs("SETTLE=%d", settle)) begin end
        if ($value$plusargs("DUMP=%d", want_dump)) begin end
        if ($value$plusargs("KEYS=%s", keys_arg)) parse_keys(keys_arg);

        for (k = 0; k < 256; k = k + 1) uut.regs0.mem[k] = 32'h0;
        uut.regs0.bank = 3'd0;
        for (k = 0; k < 16384; k = k + 1) uut.dmem[k] = 32'h0;
        for (k = 0; k < 8192; k = k + 1) begin
            uut.vga0.lo[k] = 16'h0;
            uut.vga0.hi[k] = 16'h0;
        end

        $sformat(path, "tb/mem/%0s.mem", prog);
        $readmemh(path, uut.dmem);

        tick; tick;
        reset = 0;

        // Let the first screen paint.
        for (k = 0; k < settle; k = k + 1) tick;

        drawn = painted(1'b0);
        if (drawn < 300) begin
            $display("FAIL: only %0d cells painted after boot — no GUI on screen", drawn);
            dump_screen;
            $finish(1);
        end
        $display("boot: %0d cells painted", drawn);
        if (want_dump) dump_screen;

        for (k = 0; k < nkeys; k = k + 1) begin
            press(keys[k]);
            for (x = 0; x < settle; x = x + 1) tick;
            $display("after key %02h: %0d cells painted", keys[k], painted(1'b0));
            if (want_dump) dump_screen;
        end

        if (halted) begin
            $display("FAIL: OS halted — the shell should never stop");
            $finish(1);
        end

        $display("PASS: tomato_os");
        $finish;
    end
endmodule
