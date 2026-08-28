`timescale 1ns / 1ps
// Minimal 640x480@60 → 12-bit DVI PMOD (TFP410) on JC+JD
module main (
    input  logic        clk,          // 100 MHz
    input  logic        cpu_resetn,   // active-low
    output logic        led,
    // JC = R/G
    output logic [3:0]  dvi_r,
    output logic [3:0]  dvi_g,
    // JD = B + sync/clk
    output logic [3:0]  dvi_b,
    output logic        dvi_hs,
    output logic        dvi_vs,
    output logic        dvi_de,
    output logic        dvi_clk
);
    logic reset;
    assign reset = ~cpu_resetn;

    // 100 MHz → 25 MHz pixel clock
    logic [1:0] div;
    logic       pix_clk_u, pix_clk;
    always_ff @(posedge clk) begin
        if (reset) div <= 2'd0;
        else       div <= div + 2'd1;
    end
    assign pix_clk_u = div[1];
    BUFG bufg_pix (.O(pix_clk), .I(pix_clk_u));

    // Heartbeat on LED (visible life even if monitor fails)
    logic [23:0] blink;
    always_ff @(posedge pix_clk) begin
        if (reset) blink <= 24'd0;
        else       blink <= blink + 24'd1;
    end
    assign led = blink[23];

    // 640x480@60 (25 MHz)
    localparam int H_VISIBLE = 640;
    localparam int H_FP      = 16;
    localparam int H_SYNC    = 96;
    localparam int H_BP      = 48;
    localparam int H_TOTAL   = 800;

    localparam int V_VISIBLE = 480;
    localparam int V_FP      = 10;
    localparam int V_SYNC    = 2;
    localparam int V_BP      = 33;
    localparam int V_TOTAL   = 525;

    logic [9:0] h, v;
    always_ff @(posedge pix_clk) begin
        if (reset) begin
            h <= 10'd0;
            v <= 10'd0;
        end else if (h == H_TOTAL - 1) begin
            h <= 10'd0;
            v <= (v == V_TOTAL - 1) ? 10'd0 : (v + 10'd1);
        end else begin
            h <= h + 10'd1;
        end
    end

    logic hs_n, vs_n, de;
    assign hs_n = ~((h >= H_VISIBLE + H_FP) && (h < H_VISIBLE + H_FP + H_SYNC));
    assign vs_n = ~((v >= V_VISIBLE + V_FP) && (v < V_VISIBLE + V_FP + V_SYNC));
    assign de   = (h < H_VISIBLE) && (v < V_VISIBLE);

    // Color bars: R | G | B | white  (easy pass/fail)
    logic [3:0] r, g, b;
    always_comb begin
        r = 4'h0; g = 4'h0; b = 4'h0;
        if (de) begin
            if      (h < 160) begin r = 4'hF; end
            else if (h < 320) begin g = 4'hF; end
            else if (h < 480) begin b = 4'hF; end
            else              begin r = 4'hF; g = 4'hF; b = 4'hF; end
        end
    end

    // Register data/sync to pix_clk; forward clock with ODDR
    always_ff @(posedge pix_clk) begin
        dvi_r  <= r;
        dvi_g  <= g;
        dvi_b  <= b;
        dvi_hs <= hs_n;
        dvi_vs <= vs_n;
        dvi_de <= de;
    end

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) oddr_dvi_clk (
        .Q (dvi_clk),
        .C (pix_clk),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R (1'b0),
        .S (1'b0)
    );
endmodule