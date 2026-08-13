/*
 * Tomato — Nexys A7 board top (Vivado bitstream top-level)
 *
 * Add rtl/ to Vivado; set top = nexys_top; include dir = rtl/;
 * constraints = constr/nexys.xdc
 *
 * SW[3:0] reserved (boot image is burned at synth via gen_fpga_burn.py --boot).
 * Buttons → ASCII for Tomato OS menu: L=1 C=0 U=2 R=3 D=unused
 * LEDs ← last OUT byte
 *
 * Digilent CPU_RESETN (pin C12): HIGH at rest, LOW when pressed.
 * Invert once here → active-high rst for the core.
 */
module nexys_top (
    input        clk,
    input        cpu_resetn,     // Digilent CPU_RESETN (active-low press)
    input        btnc,
    input        btnu,
    input        btnl,
    input        btnr,
    input        btnd,
    input  [3:0] sw,
    output [7:0] led,
    output [6:0] seg,
    output [7:0] an,
    output       dp,
    output       vga_hs,
    output       vga_vs,
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b
);
    // Active-high core reset: pressed button or power-on until released
    wire reset = ~cpu_resetn;

    // Simple button → keycode (no debounce — OK for first bring-up)
    reg  [7:0] kb_data;
    reg        kb_ready;
    always @(*) begin
        kb_data  = 8'h00;
        kb_ready = 1'b0;
        if (btnc) begin kb_data = 8'h30; kb_ready = 1'b1; end // '0' quit
        else if (btnl) begin kb_data = 8'h31; kb_ready = 1'b1; end // '1'
        else if (btnu) begin kb_data = 8'h32; kb_ready = 1'b1; end // '2'
        else if (btnr) begin kb_data = 8'h33; kb_ready = 1'b1; end // '3'
        else if (btnd) begin kb_data = 8'h71; kb_ready = 1'b1; end // 'q'
    end

    wire [7:0] io_out;
    assign led = io_out | {4'h0, sw};

    main cpu (
        .clk     (clk),
        .reset   (reset),
        .kb_data (kb_data),
        .kb_ready(kb_ready),
        .io_out  (io_out),
        .seg     (seg),
        .an      (an),
        .dp      (dp),
        .vga_hs  (vga_hs),
        .vga_vs  (vga_vs),
        .vga_r   (vga_r),
        .vga_g   (vga_g),
        .vga_b   (vga_b)
    );
endmodule
