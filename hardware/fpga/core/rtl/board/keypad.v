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
 */
module keypad #(
    // Debounce sample interval in clocks. 65536 @ 6.25 MHz ≈ 10 ms.
    parameter SAMPLE = 16
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

    // Sample the synchronised buttons slowly; contact bounce settles well
    // inside one interval, so the sampled value is the debounced value.
    reg [SAMPLE-1:0] div;
    wire tick = (div == {SAMPLE{1'b1}});
    always @(posedge clk) begin
        if (reset) div <= {SAMPLE{1'b0}};
        else       div <= div + 1'b1;
    end

    reg [4:0] stable, stable_d;
    always @(posedge clk) begin
        if (reset) begin
            stable   <= 5'b0;
            stable_d <= 5'b0;
        end else if (tick) begin
            stable   <= sync1;
            stable_d <= stable;
        end
    end

    wire [4:0] pressed = stable & ~stable_d;   // one-shot, one sample wide

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
        end else if (rd) begin
            ready_r <= 1'b0;
        end
    end
endmodule
