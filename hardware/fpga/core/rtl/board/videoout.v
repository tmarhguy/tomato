/*
 * Tomato — text / bitmap scanout for the 12-bit DVI PMOD
 *
 * Mode 0: 80×60 text cells (8×8 glyphs), same as Tomato v1.
 * Mode 1: 320×200 indexed framebuffer, 2× upscale centred on 640×480.
 */
module videoout (
    input             pix_clk,
    input             reset,
    input             mode_pix,
    // Text path
    output     [12:0] tile_addr,
    input      [31:0] tile_data,
    // Bitmap path
    output     [16:0] pix_addr,
    input      [7:0]  pix_index,
    input      [11:0] pal_rgb,
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

    localparam PIX_W = 9'd320;
    localparam PIX_H = 8'd200;
    localparam PIX_Y0 = 10'd40;

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

    // ---- text mode addressing ------------------------------------------------
    wire [6:0] tx = fh[9:3];
    wire [5:0] ty = fv[9:3];
    wire [12:0] row_base = {1'b0, ty, 6'b0} + {3'b0, ty, 4'b0};
    wire [12:0] text_addr = row_base + {6'b0, tx};

    // ---- bitmap mode addressing (2× scale, centred) ------------------------
    wire       in_pix_win = (fv >= PIX_Y0) && (fv < PIX_Y0 + {2'b0, PIX_H, 1'b0});
    wire [9:0] fv_rel = fv - PIX_Y0;
    wire [8:0] src_x = fh[9:1];
    wire [7:0] src_y = fv_rel[9:1];
    wire       src_ok = in_pix_win && (src_x < PIX_W) && (src_y < PIX_H);
    wire [16:0] bmp_addr = {src_y, 8'b0} + {2'b0, src_y, 6'b0} + {7'b0, src_x};

    assign tile_addr = text_addr;
    assign pix_addr  = bmp_addr;

    wire f_de = (fh < H_VISIBLE) && (fv < V_VISIBLE);
    wire f_hs = ~((fh >= H_VISIBLE + H_FP) && (fh < H_VISIBLE + H_FP + H_SYNC));
    wire f_vs = ~((fv >= V_VISIBLE + V_FP) && (fv < V_VISIBLE + V_FP + V_SYNC));

    // ---- text pipeline (mode 0) --------------------------------------------
    reg [2:0] row_s1, col_s1;
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
    wire [3:0] text_idx = is_solid_s2 ? solid_s2 : (ink ? fg_s2 : bg_s2);

  reg [3:0] tpr, tpg, tpb;
  always @(*) begin
      case (text_idx)
          4'h0: begin tpr = 4'h0; tpg = 4'h0; tpb = 4'h0; end
          4'h1: begin tpr = 4'h0; tpg = 4'h1; tpb = 4'h4; end
          4'h2: begin tpr = 4'h0; tpg = 4'h8; tpb = 4'h2; end
          4'h3: begin tpr = 4'h0; tpg = 4'h8; tpb = 4'h8; end
          4'h4: begin tpr = 4'hC; tpg = 4'h2; tpb = 4'h1; end
          4'h5: begin tpr = 4'h9; tpg = 4'h2; tpb = 4'h8; end
          4'h6: begin tpr = 4'hB; tpg = 4'h6; tpb = 4'h1; end
          4'h7: begin tpr = 4'hA; tpg = 4'hA; tpb = 4'hA; end
          4'h8: begin tpr = 4'h4; tpg = 4'h4; tpb = 4'h5; end
          4'h9: begin tpr = 4'h4; tpg = 4'h6; tpb = 4'hF; end
          4'hA: begin tpr = 4'h4; tpg = 4'hE; tpb = 4'h4; end
          4'hB: begin tpr = 4'h3; tpg = 4'hE; tpb = 4'hE; end
          4'hC: begin tpr = 4'hF; tpg = 4'h4; tpb = 4'h3; end
          4'hD: begin tpr = 4'hF; tpg = 4'h5; tpb = 4'hC; end
          4'hE: begin tpr = 4'hF; tpg = 4'hE; tpb = 4'h3; end
          default: begin tpr = 4'hF; tpg = 4'hF; tpb = 4'hF; end
      endcase
  end

    // ---- bitmap pipeline (mode 1) ------------------------------------------
    reg [7:0]  pix_s1;
    reg        pix_ok_s1;
    reg        de_p1, hs_p1, vs_p1;
    always @(posedge pix_clk) begin
        pix_s1   <= pix_index;
        pix_ok_s1 <= src_ok;
        de_p1    <= f_de;
        hs_p1    <= f_hs;
        vs_p1    <= f_vs;
    end

    reg [11:0] pal_s2;
    reg        pix_ok_s2;
    reg        de_p2, hs_p2, vs_p2;
    always @(posedge pix_clk) begin
        pal_s2    <= pal_rgb;
        pix_ok_s2 <= pix_ok_s1;
        de_p2     <= de_p1;
        hs_p2     <= hs_p1;
        vs_p2     <= vs_p1;
    end

    wire [3:0] bpr = pix_ok_s2 ? pal_s2[11:8] : 4'h0;
    wire [3:0] bpg = pix_ok_s2 ? pal_s2[7:4]  : 4'h0;
    wire [3:0] bpb = pix_ok_s2 ? pal_s2[3:0]  : 4'h0;

    reg mode_s2;
    always @(posedge pix_clk)
        mode_s2 <= mode_pix;

    always @(posedge pix_clk) begin
        if (mode_s2) begin
            r  <= de_p2 ? bpr : 4'h0;
            g  <= de_p2 ? bpg : 4'h0;
            b  <= de_p2 ? bpb : 4'h0;
            de <= de_p2;
            hs <= hs_p2;
            vs <= vs_p2;
        end else begin
            r  <= de_s2 ? tpr : 4'h0;
            g  <= de_s2 ? tpg : 4'h0;
            b  <= de_s2 ? tpb : 4'h0;
            de <= de_s2;
            hs <= hs_s2;
            vs <= vs_s2;
        end
    end
endmodule
