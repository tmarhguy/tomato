/*
 * Tomato — FPGA burn boot smoke (NO TB $readmemh)
 *
 * Compiles WITHOUT -DTOMATO_SIM so dmem comes from rtl/burn/dmem_init.vh
 * (Tomato OS). Proves opcodes + OS are actually burned into the RTL: what the
 * board would put on the glass at power-up, checked in the tile RAM.
 */
`timescale 1ns/1ps
module burn_boot_tb;
    reg clk = 0;
    reg reset = 1;
    reg  [7:0] kb_data = 8'h00;
    reg        kb_ready = 1'b0;
    wire [7:0]  io_out;
    wire [31:0] disp_value;
    wire        kb_rd, halted;
    reg  [12:0] tile_raddr = 13'd0;
    wire [31:0] tile_rdata;

    always #5 clk = ~clk;

    main uut (
        .clk(clk), .reset(reset),
        .kb_data(kb_data), .kb_ready(kb_ready), .kb_rd(kb_rd),
        .io_out(io_out), .disp_value(disp_value), .halted(halted),
        .tile_rclk(clk), .tile_raddr(tile_raddr), .tile_rdata(tile_rdata)
    );

    // shell_desktop: large 'T' of TOMATO at (4,5); 'A' of APPLICATIONS at (5,12).
    // Theme words carry wallpaper/glass bits (and LUI rd-in-imm residue).
    localparam TITLE_AT = 5 * 80 + 4;
    localparam MENU_AT  = 12 * 80 + 5;
    localparam TITLE_W  = 32'he8070f54;
    localparam MENU_W   = 32'hd8030741;
    localparam MAXCYC   = 4000000;

    integer k, ready;
    reg [31:0] title_cell, menu_cell;

    function [31:0] tile;
        input integer idx;
        begin
            tile = {uut.vga0.hi[idx], uut.vga0.lo[idx]};
        end
    endfunction

    initial begin
        $display("burn_boot: checking burned dmem[0]=%h (expect nonzero OS word)", uut.dmem[0]);
        if (uut.dmem[0] === 32'h0 || uut.dmem[0] === 32'bx) begin
            $display("FAIL: dmem burn empty — run: make burn");
            $finish(1);
        end

        // Burn file only sets image words; the rest power up as X in sim.
        // Hardware BRAM is zero — clear X so stack/heap reads match silicon.
        for (k = 0; k < 98304; k = k + 1)
            if (uut.dmem[k] === 32'bx) uut.dmem[k] = 32'h0;
        for (k = 0; k < 256; k = k + 1) uut.regs0.mem[k] = 32'h0;
        uut.regs0.bank = 3'd0;
        for (k = 0; k < 8192; k = k + 1) begin
            uut.vga0.lo[k] = 16'h0;
            uut.vga0.hi[k] = 16'h0;
        end

        repeat (2) @(posedge clk);
        reset = 0;

        $display("burn_boot: running burned Tomato OS (clear, title bar, menu)...");
        $fflush;
        ready = 0;
        for (k = 0; k < MAXCYC && !ready; k = k + 1) begin
            @(posedge clk);
            if ((k % 500000) == 0) begin
                $display("burn_boot: ... %0d cycles", k);
                $fflush;
            end
            if ((tile(TITLE_AT) & 32'h007fffff) === (TITLE_W & 32'h007fffff) && (tile(MENU_AT) & 32'h007fffff) === (MENU_W & 32'h007fffff))
                ready = 1;
        end

        title_cell = tile(TITLE_AT);
        menu_cell  = tile(MENU_AT);

        if (!ready) begin
            $display("FAIL: burned OS desktop not drawn after %0d cycles", MAXCYC);
            $display("      title cell = %h (want %h)", title_cell, TITLE_W);
            $display("      menu  cell = %h (want %h)", menu_cell,  MENU_W);
            $finish(1);
        end

        $display("PASS: burn_boot desktop from RTL-burned dmem+microcode (%0d cycles)", k);
        $finish;
    end
endmodule
