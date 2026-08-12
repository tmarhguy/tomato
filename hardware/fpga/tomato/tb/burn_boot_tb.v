/*
 * Tomato — FPGA burn boot smoke (NO TB $readmemh)
 *
 * Compiles WITHOUT -DTOMATO_SIM so dmem comes from rtl/burn/dmem_init.vh
 * (Tomato OS). Proves opcodes + OS are actually burned into the RTL.
 */
`timescale 1ns/1ps
module burn_boot_tb;
    reg clk = 0;
    reg reset = 1;
    reg  [7:0] kb_data = 8'h00;
    reg        kb_ready = 1'b0;
    wire [7:0] io_out;
    wire [6:0] seg;
    wire [7:0] an;
    wire       dp, vga_hs, vga_vs;
    wire [3:0] vga_r, vga_g, vga_b;

    always #5 clk = ~clk;

    main uut (
        .clk(clk), .reset(reset),
        .kb_data(kb_data), .kb_ready(kb_ready), .io_out(io_out),
        .seg(seg), .an(an), .dp(dp),
        .vga_hs(vga_hs), .vga_vs(vga_vs),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );

    integer k, ready;
    localparam TOM   = 18 * 80 + 40;
    localparam TITLE = 28 * 80 + 22;
    localparam MAXCYC = 6000000;

    initial begin
        $display("burn_boot: checking burned dmem[0]=%h (expect nonzero OS word)", uut.dmem[0]);
        if (uut.dmem[0] === 32'h0) begin
            $display("FAIL: dmem burn empty — run: make burn");
            $finish(1);
        end

        for (k = 0; k < 256; k = k + 1) uut.regs0.mem[k] = 32'h0;
        uut.regs0.bank = 3'd0;

        repeat (2) @(posedge clk);
        reset = 0;

        $display("burn_boot: running burned Tomato OS (slow cls)...");
        $fflush;
        ready = 0;
        for (k = 0; k < MAXCYC && !ready; k = k + 1) begin
            @(posedge clk);
            if ((k % 500000) == 0) begin
                $display("burn_boot: ... %0d cycles", k);
                $fflush;
            end
            if ({uut.vga0.hi[TOM], uut.vga0.lo[TOM]} === 32'h4 &&
                {uut.vga0.hi[TITLE], uut.vga0.lo[TITLE]} === 32'hE) begin
                ready = 1;
                repeat (200000) @(posedge clk);
            end
        end

        if (!ready) begin
            $display("FAIL: burned OS splash not visible (tom=%h title=%h)",
                     {uut.vga0.hi[TOM], uut.vga0.lo[TOM]},
                     {uut.vga0.hi[TITLE], uut.vga0.lo[TITLE]});
            $finish(1);
        end

        $display("PASS: burn_boot OS splash from RTL-burned dmem+microcode");
        $finish;
    end
endmodule
