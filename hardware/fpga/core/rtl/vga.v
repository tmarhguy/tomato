/*
 * Tomato — VGA tile RAM (MMIO) — compatibility wrapper
 *
 * New designs should instantiate display.v directly (text + bitmap).
 * This module keeps the original vga port list for vga_tb.v.
 */
module vga (
    input         clk,
    input  [23:0] mem_addr,
    input  [31:0] mem_din,
    input         mem_wr,
    input         rclk,
    input  [12:0] raddr,
    output [31:0] rdata
);
    wire [31:0] cpu_unused;
    wire [7:0]  pix_unused;
    wire [11:0] pal_unused;
    wire [16:0] pix_addr_unused = 17'd0;
    wire        mode_unused;

    display disp0 (
        .clk        (clk),
        .mem_addr   (mem_addr),
        .mem_din    (mem_din),
        .mem_wr     (mem_wr),
        .mem_rd     (1'b0),
        .bytesel    (4'd0),
        .cpu_rdata  (cpu_unused),
        .rclk       (rclk),
        .tile_raddr (raddr),
        .tile_rdata (rdata),
        .pix_raddr  (pix_addr_unused),
        .pix_rdata  (pix_unused),
        .pal_rgb    (pal_unused),
        .mode_pix   (mode_unused)
    );
endmodule
