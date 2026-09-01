/*
 * Tomato — Nexys A7-100T board top
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : rtl/board/nexys_top.v
 * Target   : Artix-7 xc7a100tcsg324-1
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * Video leaves on the 12-bit DVI PMOD across JC + JD, not the board's own VGA
 * bank. The dedicated VGA header only ever reached a monitor through a passive
 * adapter chain that never lit; the PMOD drives a TFP410 and does.
 *
 * Two clocks come off the 100 MHz oscillator:
 *
 *   pix_clk  100/4            25 MHz, the 640x480@60 dot clock
 *   cpu_clk  100/CPU_DIV      the machine, divided down to close timing
 *
 * They meet only inside the tile RAM, which is a true dual-port block with a
 * clock per port — the framebuffer is the clock-domain crossing.
 *
 * Buttons stand in for a keyboard (see rtl/board/keypad.v).
 */
module nexys_top #(
    // 100 MHz / CPU_DIV. 16 → 6.25 MHz, comfortably inside the ~8 MHz the
    // discrete-faithful datapath closes at. Override from the Makefile.
    parameter CPU_DIV_LOG2 = 4
) (
    input         clk,          // E3, 100 MHz
    input         cpu_resetn,   // C12, Digilent CPU_RESETN (low when pressed)
    input         btnc,         // N17  enter
    input         btnu,         // M18  up
    input         btnd,         // P18  down
    input         btnl,         // P17  left
    input         btnr,         // M17  right
    input  [15:0] sw,
    output [15:0] led,
    output [6:0]  seg,
    output [7:0]  an,
    output        dp,
    // JC = R/G, JD = B + sync/clk
    output [3:0]  dvi_r,
    output [3:0]  dvi_g,
    output [3:0]  dvi_b,
    output        dvi_hs,
    output        dvi_vs,
    output        dvi_de,
    output        dvi_clk
);
    wire por_reset = ~cpu_resetn;

    // ---- clocks -----------------------------------------------------------
    reg [CPU_DIV_LOG2-1:0] cpu_div;
    reg [1:0]              pix_div;
    always @(posedge clk) begin
        cpu_div <= cpu_div + 1'b1;
        pix_div <= pix_div + 1'b1;
    end

    wire cpu_clk, pix_clk;
`ifdef TOMATO_SIM
    assign cpu_clk = cpu_div[CPU_DIV_LOG2-1];
    assign pix_clk = pix_div[1];
`else
    BUFG bufg_cpu (.O(cpu_clk), .I(cpu_div[CPU_DIV_LOG2-1]));
    BUFG bufg_pix (.O(pix_clk), .I(pix_div[1]));
`endif

    // ---- reset, resynchronised into each domain ---------------------------
    reg [2:0] cpu_rst_sync, pix_rst_sync;
    always @(posedge cpu_clk) cpu_rst_sync <= {cpu_rst_sync[1:0], por_reset};
    always @(posedge pix_clk) pix_rst_sync <= {pix_rst_sync[1:0], por_reset};
    wire cpu_reset = cpu_rst_sync[2];
    wire pix_reset = pix_rst_sync[2];

    // ---- keypad → keyboard MMIO -------------------------------------------
    wire [7:0] kb_data;
    wire       kb_ready, kb_rd;

    keypad #(.SAMPLE(16)) keypad0 (
        .clk      (cpu_clk),
        .reset    (cpu_reset),
        .btnu     (btnu),
        .btnd     (btnd),
        .btnl     (btnl),
        .btnr     (btnr),
        .btnc     (btnc),
        .rd       (kb_rd),
        .kb_data  (kb_data),
        .kb_ready (kb_ready)
    );

    // ---- the machine ------------------------------------------------------
    wire [7:0]  io_out;
    wire [31:0] disp_value;
    wire        halted;
    wire [12:0] tile_raddr;
    wire [31:0] tile_rdata;
    wire [16:0] pix_raddr;
    wire [7:0]  pix_rdata;
    wire [11:0] pal_rgb;
    wire        mode_pix;
    reg         mode_pix_r, mode_pix_s;

    always @(posedge pix_clk) begin
        mode_pix_r <= mode_pix;
        mode_pix_s <= mode_pix_r;
    end

    main cpu (
        .clk        (cpu_clk),
        .reset      (cpu_reset),
        .kb_data    (kb_data),
        .kb_ready   (kb_ready),
        .kb_rd      (kb_rd),
        .io_out     (io_out),
        .disp_value (disp_value),
        .halted     (halted),
        .tile_rclk  (pix_clk),
        .tile_raddr (tile_raddr),
        .tile_rdata (tile_rdata),
        .pix_raddr  (pix_raddr),
        .pix_rdata  (pix_rdata),
        .pal_rgb    (pal_rgb),
        .mode_pix   (mode_pix)
    );

    // ---- scanout ----------------------------------------------------------
    wire [3:0] px_r, px_g, px_b;
    wire       px_hs, px_vs, px_de;

    videoout video0 (
        .pix_clk   (pix_clk),
        .reset     (pix_reset),
        .mode_pix  (mode_pix_s),
        .tile_addr (tile_raddr),
        .tile_data (tile_rdata),
        .pix_addr  (pix_raddr),
        .pix_index (pix_rdata),
        .pal_rgb   (pal_rgb),
        .r         (px_r),
        .g         (px_g),
        .b         (px_b),
        .hs        (px_hs),
        .vs        (px_vs),
        .de        (px_de)
    );

    dvi_out dvi0 (
        .pix_clk (pix_clk),
        .r       (px_r),
        .g       (px_g),
        .b       (px_b),
        .hs      (px_hs),
        .vs      (px_vs),
        .de      (px_de),
        .dvi_r   (dvi_r),
        .dvi_g   (dvi_g),
        .dvi_b   (dvi_b),
        .dvi_hs  (dvi_hs),
        .dvi_vs  (dvi_vs),
        .dvi_de  (dvi_de),
        .dvi_clk (dvi_clk)
    );

    // ---- bench instrumentation --------------------------------------------
    hex hex0 (
        .clk   (cpu_clk),
        .reset (cpu_reset),
        .value (disp_value),
        .seg   (seg),
        .an    (an),
        .dp    (dp)
    );

    // Slow blink proves the CPU clock is alive even with the monitor dark.
    reg [22:0] beat;
    always @(posedge cpu_clk) beat <= beat + 1'b1;

    assign led = {beat[22], halted, kb_ready, sw[12:8], io_out};
endmodule
