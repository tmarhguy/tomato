/*
 * Tomato — five-button keypad → keyboard MMIO
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : rtl/board/keypad.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * The Nexys A7 D-pad stands in for a keyboard until a real PS/2 front end
 * lands. Pin → key, as wired in constr/nexys.xdc:
 *
 *   M18 BTNU  up      0x1E
 *   P18 BTND  down    0x1F
 *   P17 BTNL  left    0x11
 *   M17 BTNR  right   0x10
 *   N17 BTNC  enter   0x0D
 *
 * The four arrow codes are also their CP437 glyphs (^ v < >), so software can
 * echo a keycode straight into the framebuffer and get the right picture.
 *
 * One key per press: a code is latched on the debounced rising edge and held
 * with kb_ready until the CPU reads the data word (rd), so a held button does
 * not machine-gun the menu. A fresh press always wins over a stale unread one.
 *
 * Two things make exactly one clean keycode per push:
 *   1. An integrating debounce: a level must agree with itself for STABLE_N
 *      samples before it is accepted, so chattering contacts never get in.
 *   2. A press edge that is one CLOCK wide, not one SAMPLE wide. The CPU polls
 *      this port thousands of times per sample interval, and a fresh press
 *      outranks `rd` in the latch below; a sample-wide edge therefore re-armed
 *      kb_ready on every cycle and turned one click into thousands of keys.
 */
module keypad #(
    // Debounce sample interval in clocks. 8192 @ 6.25 MHz ≈ 1.3 ms.
    parameter SAMPLE = 13,
    // A level has to agree with itself for this many samples before it is
    // believed. 12 × 1.3 ms ≈ 16 ms, longer than the contacts bounce, and
    // bounce keeps resetting the count so it never reaches the threshold.
    parameter STABLE_N = 12,
    // Held arrows auto-repeat so Tetris/Snake can slide without mashing.
    // Enter never repeats: the press that opens a screen must not also
    // dismiss it. 0 disables. 180 ticks ≈ 240 ms, then every 60 ≈ 80 ms.
    parameter REPEAT_AFTER = 180,
    parameter REPEAT_RATE  = 60
) (
    input        clk,
    input        reset,
    input        btnu,
    input        btnd,
    input        btnl,
    input        btnr,
    input        btnc,
    input        rd,          // CPU read the kb data word this cycle
    output [7:0] kb_data,
    output       kb_ready
);
    localparam [7:0] KEY_UP    = 8'h1E;
    localparam [7:0] KEY_DOWN  = 8'h1F;
    localparam [7:0] KEY_LEFT  = 8'h11;
    localparam [7:0] KEY_RIGHT = 8'h10;
    localparam [7:0] KEY_ENTER = 8'h0D;

    // Two-flop synchroniser — the buttons are asynchronous to every clock here.
    reg [4:0] sync0, sync1;
    always @(posedge clk) begin
        sync0 <= {btnc, btnr, btnl, btnd, btnu};
        sync1 <= sync0;
    end

    // Slow sample tick.
    reg [SAMPLE-1:0] div;
    wire tick = (div == {SAMPLE{1'b1}});
    always @(posedge clk) begin
        if (reset) div <= {SAMPLE{1'b0}};
        else       div <= div + 1'b1;
    end

    // Integrating debounce: the sampled vector must agree with the accepted
    // one for STABLE_N consecutive ticks before it is accepted. A bouncing
    // contact flips back and forth, resets the count, and never gets through.
    reg [4:0] stable;
    reg [7:0] agree;
    always @(posedge clk) begin
        if (reset) begin
            stable <= 5'b0;
            agree  <= 8'd0;
        end else if (tick) begin
            if (sync1 == stable)              agree <= 8'd0;
            else if (agree >= (STABLE_N - 1)) begin
                stable <= sync1;
                agree  <= 8'd0;
            end else                          agree <= agree + 8'd1;
        end
    end

    // The press edge is taken against a CLOCK-rate copy, so it is exactly one
    // clock wide. Taken against a tick-rate copy it would stay asserted for a
    // whole sample interval, and because a fresh press outranks `rd` in the
    // latch below, that re-armed kb_ready every cycle — one click, thousands
    // of keys.
    reg [4:0] stable_q;
    always @(posedge clk) stable_q <= stable;

    wire [4:0] pressed = stable & ~stable_q;   // one-shot, one clock wide
    wire [3:0] arrows  = stable[3:0];

    // Count debounce ticks while any arrow is down. Enter is excluded so a
    // held N17 cannot machine-gun the menu or bounce out of a screen.
    reg [7:0] hold;
    always @(posedge clk) begin
        if (reset) hold <= 8'd0;
        else if (tick) begin
            if (arrows == 4'b0) hold <= 8'd0;
            else if (hold == REPEAT_AFTER + REPEAT_RATE - 1) hold <= REPEAT_AFTER[7:0];
            else hold <= hold + 8'd1;
        end
    end

    wire do_repeat = (REPEAT_AFTER != 0) && tick && (arrows != 4'b0) &&
                     (hold == REPEAT_AFTER);

    reg [7:0] data_r;
    reg       ready_r;
    assign kb_data  = data_r;
    assign kb_ready = ready_r;

    always @(posedge clk) begin
        if (reset) begin
            data_r  <= 8'h00;
            ready_r <= 1'b0;
        end else if (|pressed) begin
            ready_r <= 1'b1;
            // Enter wins, then vertical, then horizontal — a diagonal press on
            // a D-pad is a fumble, not a chord.
            if      (pressed[4]) data_r <= KEY_ENTER;
            else if (pressed[0]) data_r <= KEY_UP;
            else if (pressed[1]) data_r <= KEY_DOWN;
            else if (pressed[2]) data_r <= KEY_LEFT;
            else                 data_r <= KEY_RIGHT;
        end else if (do_repeat) begin
            ready_r <= 1'b1;
            if      (stable[0]) data_r <= KEY_UP;
            else if (stable[1]) data_r <= KEY_DOWN;
            else if (stable[2]) data_r <= KEY_LEFT;
            else                data_r <= KEY_RIGHT;
        end else if (rd) begin
            ready_r <= 1'b0;
        end
    end
endmodule
