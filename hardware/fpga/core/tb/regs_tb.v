/*
 * Tomato — register file testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : regs_tb.v
 * Target   : simulation (compile with rtl/regs.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
`timescale 1ns/1ps
module regs_tb;
    reg         clk, we, exec, bank_en;
    reg  [2:0]  bank_sel;
    reg  [4:0]  addr_a, addr_b, addr_c, addr_w;
    reg  [31:0] data_w;
    wire [31:0] data_a, data_b, data_c;

    regs uut (
        .clk(clk), .we(we), .exec(exec), .bank_en(bank_en),
        .bank_sel(bank_sel), .addr_a(addr_a), .addr_b(addr_b),
        .addr_c(addr_c), .addr_w(addr_w), .data_w(data_w),
        .data_a(data_a), .data_b(data_b), .data_c(data_c)
    );

    always #5 clk = ~clk;

    task tick; begin @(posedge clk); #1; end endtask

    task check3;
        input [31:0] ea, eb, ec;
        input [255:0] tag;
        begin
            #1;
            if (data_a !== ea || data_b !== eb || data_c !== ec) begin
                $display("FAIL: %0s a=%h/%h b=%h/%h c=%h/%h",
                         tag, ea, data_a, eb, data_b, ec, data_c);
                $finish(1);
            end
        end
    endtask

    initial begin
        clk = 0; we = 0; exec = 0; bank_en = 0;
        bank_sel = 0; addr_a = 0; addr_b = 0; addr_c = 0; addr_w = 0; data_w = 0;

        // init bank 0
        bank_en = 1; bank_sel = 3'd0;
        tick;
        bank_en = 0;

        // write only when exec & we
        we = 1; exec = 0; addr_w = 5'd1; data_w = 32'hDEAD_BEEF;
        tick;
        addr_a = 5'd1;
        #1;
        // may be X; must not be DEADBEEF from a completed write
        if (data_a === 32'hDEAD_BEEF) begin
            $display("FAIL: write without exec");
            $finish(1);
        end

        exec = 1; we = 1; addr_w = 5'd1; data_w = 32'h1111_1111;
        tick;
        addr_a = 5'd1; addr_b = 5'd1; addr_c = 5'd1;
        check3(32'h1111_1111, 32'h1111_1111, 32'h1111_1111, "raw");

        // 3R1W distinct
        addr_w = 5'd2; data_w = 32'h2222_2222; tick;
        addr_w = 5'd3; data_w = 32'h3333_3333; tick;
        addr_a = 5'd1; addr_b = 5'd2; addr_c = 5'd3;
        check3(32'h1111_1111, 32'h2222_2222, 32'h3333_3333, "3r");

        // bank 1 isolation
        bank_en = 1; bank_sel = 3'd1; tick; bank_en = 0;
        addr_w = 5'd1; data_w = 32'hAAAA_BBBB; tick;
        addr_a = 5'd1;
        #1;
        if (data_a !== 32'hAAAA_BBBB) begin
            $display("FAIL: bank1 write got %h", data_a);
            $finish(1);
        end
        bank_en = 1; bank_sel = 3'd0; tick; bank_en = 0;
        addr_a = 5'd1;
        #1;
        if (data_a !== 32'h1111_1111) begin
            $display("FAIL: bank0 preserved got %h", data_a);
            $finish(1);
        end

        // we=0 no write
        we = 0; exec = 1; addr_w = 5'd1; data_w = 32'h9999_9999; tick;
        addr_a = 5'd1;
        #1;
        if (data_a !== 32'h1111_1111) begin
            $display("FAIL: we gated");
            $finish(1);
        end

        // r0 hardwired zero: writes ignored, reads always 0
        we = 1; exec = 1; addr_w = 5'd0; data_w = 32'hFFFF_FFFF; tick;
        addr_a = 5'd0; addr_b = 5'd0; addr_c = 5'd0;
        check3(32'd0, 32'd0, 32'd0, "r0");

        $display("PASS: regs");
        $finish;
    end
endmodule
