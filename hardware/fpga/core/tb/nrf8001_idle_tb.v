`timescale 1ns/1ps
module nrf8001_idle_tb;
    reg clk = 0;
    reg reset = 1;
    wire rst_n, req_n, sck, mosi;

    always #5 clk = ~clk;

    nrf8001_idle #(.RESET_CYCLES(4)) dut (
        .clk(clk), .reset(reset), .rst_n(rst_n),
        .req_n(req_n), .sck(sck), .mosi(mosi)
    );

    initial begin
        repeat (2) @(posedge clk);
        if (rst_n || !req_n || sck || mosi) $fatal(1, "unsafe reset levels");
        reset = 0;
        repeat (3) @(posedge clk);
        if (rst_n) $fatal(1, "reset released early");
        @(posedge clk);
        #1;
        if (!rst_n || !req_n || sck || mosi) $fatal(1, "bad idle levels");
        reset = 1;
        @(posedge clk);
        #1;
        if (rst_n) $fatal(1, "reset did not reassert");
        $display("PASS: nrf8001_idle (reset delay and safe ACI idle levels)");
        $finish;
    end
endmodule
