/*
 * Tomato — Display v2 (text + bitmap)
 *
 * MMIO window mem_addr[21:19]==3'b110. See software/os/DISPLAY.md.
 *
 *   0x300000..0x30FFFF  mode-dependent (text tiles or bitmap bytes)
 *   0x310000            MODE
 *   0x310004            PAL_IDX
 *   0x310008            PAL_RGB
 *
 * Port A: CPU (clk). Port B: scanout (rclk).
 */
module display (
    input         clk,
    input  [23:0] mem_addr,
    input  [31:0] mem_din,
    input         mem_wr,
    input         mem_rd,
    input  [3:0]  bytesel,
    output reg [31:0] cpu_rdata,

    input         rclk,
    // Text scanout (mode 0)
    input  [12:0] tile_raddr,
    output reg [31:0] tile_rdata,
    // Bitmap scanout (mode 1)
    input  [16:0] pix_raddr,
    output reg [7:0]  pix_rdata,
    output reg [11:0] pal_rgb,
    output            mode_pix
);
    wire hit = (mem_addr[21:19] == 3'b110);
    wire reg_hit = hit & mem_addr[16];
    wire [15:0] fb_addr = mem_addr[15:0];

    reg       mode_r;
    reg [7:0] pal_idx;
    // nextpnr-xilinx cannot pack RAM256X1S; keep the 256×12 table in FFs.
    (* ram_style = "registers" *) reg [11:0] palette [0:255];

  integer i;
  initial begin
      mode_r = 1'b0;
      pal_idx = 8'd0;
      for (i = 0; i < 256; i = i + 1)
          palette[i] = 12'h000;
      // Arcade text colours in indices 0–15 (4:4:4)
      palette[0]  = 12'h000;
      palette[1]  = 12'h014;
      palette[2]  = 12'h082;
      palette[3]  = 12'h088;
      palette[4]  = 12'hC21;
      palette[5]  = 12'h928;
      palette[6]  = 12'hB61;
      palette[7]  = 12'hAAA;
      palette[8]  = 12'h445;
      palette[9]  = 12'h46F;
      palette[10] = 12'h4E4;
      palette[11] = 12'h3EE;
      palette[12] = 12'hF43;
      palette[13] = 12'hF5C;
      palette[14] = 12'hFE3;
      palette[15] = 12'hFFF;
      for (i = 16; i < 256; i = i + 1)
          palette[i] = (i[7:4]) * 12'h111;
  end

    assign mode_pix = mode_r;

    // ---- text tile RAM (8192 × 32) -----------------------------------------
    (* ram_style = "block" *) reg [15:0] lo [0:8191];
    (* ram_style = "block" *) reg [15:0] hi [0:8191];

    wire tile_we = hit & ~reg_hit & ~mode_r & mem_wr;
    wire [12:0] tile_waddr = mem_addr[12:0];
    wire [12:0] tile_rdaddr = mem_addr[12:0];

    // ---- bitmap framebuffer (reuse lo/hi + one 32 KiB bank = 64 KiB) --------
    wire fb_we = hit & ~reg_hit & mode_r & mem_wr & (bytesel == 4'd0);
    wire        fb_bank  = mem_addr[15];
    wire [12:0] fb_idx   = mem_addr[14:2];
    wire        fb_bank_r = pix_raddr[15];
    wire [12:0] fb_idx_r  = pix_raddr[14:2];
    wire [1:0]  fb_roff   = pix_raddr[1:0];
    wire fb_lo_we = fb_we & ~fb_bank;

    wire [12:0] lo_hi_waddr = mode_r ? fb_idx : tile_waddr;
    wire        lo_hi_we    = tile_we | fb_lo_we;

    always @(posedge clk) begin
        if (lo_hi_we) begin
            lo[lo_hi_waddr] <= mem_din[15:0];
            hi[lo_hi_waddr] <= mem_din[31:16];
        end
    end

    wire [12:0] lo_hi_pixaddr = mode_r ? fb_idx_r : tile_raddr;
    reg  [31:0] lo_hi_pixword;
    always @(posedge rclk) begin
        lo_hi_pixword <= {hi[lo_hi_pixaddr], lo[lo_hi_pixaddr]};
        tile_rdata  <= lo_hi_pixword;
    end

    wire [12:0] lo_hi_cpuaddr = mode_r ? fb_idx : tile_rdaddr;
    reg  [31:0] lo_hi_cpuword;
    always @(negedge clk)
        lo_hi_cpuword <= {hi[lo_hi_cpuaddr], lo[lo_hi_cpuaddr]};

    wire [31:0] fb1_cpu, fb1_pix;
    disp_fb_bank fb_hi (
        .clk(clk), .waddr(fb_idx), .wdata(mem_din), .we(fb_we & fb_bank),
        .raddr_cpu(fb_idx), .rdata_cpu(fb1_cpu),
        .rclk(rclk), .raddr_pix(fb_idx_r), .rdata_pix(fb1_pix)
    );

    function automatic [7:0] fb_extract_byte;
        input [31:0] word;
        input [1:0]  off;
        begin
            case (off)
                2'd0: fb_extract_byte = word[7:0];
                2'd1: fb_extract_byte = word[15:8];
                2'd2: fb_extract_byte = word[23:16];
                default: fb_extract_byte = word[31:24];
            endcase
        end
    endfunction

    wire [31:0] fb_rd_word = fb_bank ? fb1_cpu : lo_hi_cpuword;

    reg [31:0] fb_pix_word;
    reg [7:0]  pix_r;
    always @(posedge rclk) begin
        fb_pix_word <= fb_bank_r ? fb1_pix : lo_hi_pixword;
        pix_r     <= fb_extract_byte(fb_pix_word, fb_roff);
        pix_rdata <= pix_r;
        pal_rgb   <= palette[pix_r];
    end

    // ---- control registers ---------------------------------------------------
    always @(posedge clk) begin
        if (hit & reg_hit & mem_wr) begin
            case (mem_addr[3:2])
                2'b00: mode_r <= mem_din[0];
                2'b01: pal_idx <= mem_din[7:0];
                2'b10: palette[pal_idx] <= mem_din[11:0];
                default: ;
            endcase
        end
    end

    reg [31:0] reg_rdata;
    always @(*) begin
        case (mem_addr[3:2])
            2'b00: reg_rdata = {31'b0, mode_r};
            2'b01: reg_rdata = {24'b0, pal_idx};
            2'b10: reg_rdata = {20'b0, palette[pal_idx]};
            default: reg_rdata = 32'h0;
        endcase
    end

    always @(*) begin
        if (!hit)
            cpu_rdata = 32'h0;
        else if (reg_hit)
            cpu_rdata = reg_rdata;
        else if (mode_r)
            cpu_rdata = fb_rd_word;
        else
            cpu_rdata = lo_hi_cpuword;
    end

    // Export palette for scanout (combinational read on pix domain)
endmodule
