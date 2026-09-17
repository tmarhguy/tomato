/*
 * Counter FSM: 65,536 Dual-LUT programs, cin is a 1-bit held input.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
`timescale 1ns/1ps
module compiler_tb;
    reg clk, reset, wr;
    reg [2:0] sel;
    reg [31:0] wdata;
    wire [31:0] rdata;

    compiler_fsm uut (
        .clk(clk), .reset(reset), .wr(wr), .sel(sel),
        .wdata(wdata), .rdata(rdata)
    );

    always #5 clk = ~clk;

    task tick; begin @(posedge clk); #1; end endtask

    task poke;
        input [2:0] s;
        input [31:0] v;
        begin
            sel = s; wdata = v; wr = 1; tick; wr = 0; tick;
        end
    endtask

    task peek;
        input [2:0] s;
        begin
            sel = s; wr = 0; #1;
        end
    endtask

    integer n;

    initial begin
        clk = 0; reset = 1; wr = 0; sel = 0; wdata = 0;
        tick; tick; reset = 0; tick;

        // A=B=C=0, cin=0, expected=0 → lutA=lutB=0 is an immediate hit.
        poke(3'd0, 32'd0);
        poke(3'd1, 32'd0);
        poke(3'd2, 32'd0);
        poke(3'd3, 32'd0);
        poke(3'd4, 32'd0);
        poke(3'd5, 32'd1);
        n = 0;
        peek(3'd6);
        while (rdata[0] && n < 8) begin tick; peek(3'd6); n = n + 1; end
        if (rdata[0] || !rdata[1] || !rdata[2]) begin
            $display("FAIL: zero vector did not latch immediately");
            $finish(1);
        end
        peek(3'd7);
        if (rdata[15:0] !== 16'd0) begin
            $display("FAIL: zero vector latched %h", rdata[15:0]);
            $finish(1);
        end
        $display("PASS: cin=0 zero vector latched lutA=00 lutB=00");

        // cin=1, A=B=C=0, expected=1 → 0+0+1 hits at lut 00/00.
        poke(3'd3, 32'd1);
        poke(3'd4, 32'd1);
        poke(3'd5, 32'd1);
        n = 0;
        peek(3'd6);
        while (rdata[0] && n < 8) begin tick; peek(3'd6); n = n + 1; end
        if (rdata[0] || !rdata[1]) begin
            $display("FAIL: cin=1 expected=1 no hit");
            $finish(1);
        end
        peek(3'd7);
        if (rdata[15:0] !== 16'd0) begin
            $display("FAIL: cin=1 latched %h, want 0000", rdata[15:0]);
            $finish(1);
        end
        $display("PASS: cin=1 latched lutA=00 lutB=00 for out=1");

        // A=1, B=0, C=0, cin=0, expected=1. Index {C,B,A}=001 → lut bit 1.
        poke(3'd0, 32'd1);
        poke(3'd1, 32'd0);
        poke(3'd2, 32'd0);
        poke(3'd3, 32'd0);
        poke(3'd4, 32'd1);
        poke(3'd5, 32'd1);
        n = 0;
        peek(3'd6);
        while (rdata[0] && n < 16) begin tick; peek(3'd6); n = n + 1; end
        if (rdata[0] || !rdata[1]) begin
            $display("FAIL: A=1 expected=1 no hit");
            $finish(1);
        end
        peek(3'd7);
        if (rdata[7:0] !== 8'h02 || rdata[15:8] !== 8'h00) begin
            $display("FAIL: A=1 latched %h, want lutA=02 lutB=00", rdata[15:0]);
            $finish(1);
        end
        $display("PASS: A=1 latched lutA=02 lutB=00");

        // Miss: A=B=C=0, cin=1, expected=4. Dual-LUT + cin can only make 0..3.
        poke(3'd0, 32'd0);
        poke(3'd1, 32'd0);
        poke(3'd2, 32'd0);
        poke(3'd3, 32'd1);
        poke(3'd4, 32'd4);
        poke(3'd5, 32'd1);
        n = 0;
        peek(3'd6);
        while (rdata[0] && n < 70000) begin tick; peek(3'd6); n = n + 1; end
        if (rdata[0] || rdata[1] || !rdata[2] || n < 65000) begin
            $display("FAIL: miss status busy=%0d hit=%0d done=%0d clocks=%0d",
                     rdata[0], rdata[1], rdata[2], n);
            $finish(1);
        end
        $display("PASS: no Dual-LUT+cin sum equals 4; sweep ended in %0d clocks", n);

        // HOLD: A=1 latched lutA=02. Freeze opcodes, then A=0 → out=0, A=1 → out=1.
        poke(3'd0, 32'd1);
        poke(3'd1, 32'd0);
        poke(3'd2, 32'd0);
        poke(3'd3, 32'd0);
        poke(3'd4, 32'd1);
        poke(3'd5, 32'd1);
        n = 0;
        peek(3'd6);
        while (rdata[0] && n < 16) begin tick; peek(3'd6); n = n + 1; end
        poke(3'd5, 32'd2);
        peek(3'd6);
        if (!rdata[3] || rdata[0]) begin
            $display("FAIL: HOLD did not freeze opcodes");
            $finish(1);
        end
        peek(3'd7);
        if (rdata[7:0] !== 8'h02) begin
            $display("FAIL: HOLD lost lutA=%h", rdata[7:0]);
            $finish(1);
        end
        poke(3'd0, 32'd0);
        peek(3'd5);
        if (rdata !== 32'd0) begin
            $display("FAIL: held A=0 out=%h want 0", rdata);
            $finish(1);
        end
        poke(3'd0, 32'd1);
        peek(3'd5);
        if (rdata !== 32'd1) begin
            $display("FAIL: held A=1 out=%h want 1", rdata);
            $finish(1);
        end
        $display("PASS: HOLD freezes opcodes; A toggles live out");

        poke(3'd5, 32'd4);
        peek(3'd6);
        if (rdata[3] || rdata[0] || rdata[1] || rdata[2]) begin
            $display("FAIL: RESET status %h", rdata);
            $finish(1);
        end
        peek(3'd7);
        if (rdata[15:0] !== 16'd0) begin
            $display("FAIL: RESET count %h", rdata[15:0]);
            $finish(1);
        end
        peek(3'd5);
        if (rdata !== 32'd0) begin
            $display("FAIL: RESET out=%h want 0 at lut 00/00", rdata);
            $finish(1);
        end
        $display("PASS: RESET zeros the counter");
        $display("PASS: compiler counter FSM");
        $finish;
    end
endmodule
