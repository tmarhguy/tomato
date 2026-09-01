/*
 * One 32 KiB framebuffer bank (8192 × 32) as lo/hi BRAM pair.
 * CPU read on negedge clk, scanout on posedge rclk — no async read port.
 */
module disp_fb_bank (
    input         clk,
    input  [12:0] waddr,
    input  [31:0] wdata,
    input         we,

    input  [12:0] raddr_cpu,
    output reg [31:0] rdata_cpu,

    input         rclk,
    input  [12:0] raddr_pix,
    output reg [31:0] rdata_pix
);
    (* ram_style = "block" *) reg [15:0] lo [0:8191];
    (* ram_style = "block" *) reg [15:0] hi [0:8191];

    always @(posedge clk) begin
        if (we) begin
            lo[waddr] <= wdata[15:0];
            hi[waddr] <= wdata[31:16];
        end
    end

    always @(negedge clk)
        rdata_cpu <= {hi[raddr_cpu], lo[raddr_cpu]};

    always @(posedge rclk)
        rdata_pix <= {hi[raddr_pix], lo[raddr_pix]};
endmodule
