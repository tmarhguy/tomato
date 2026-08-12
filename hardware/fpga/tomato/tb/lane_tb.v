/*
 * Tomato — byte-lane decoder testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : lane_tb.v
 * Target   : simulation (compile with rtl/lane.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
`timescale 1ns/1ps
module lane_tb;
    reg  [31:0] mem_in;
    reg  [3:0]  sel;
    reg  [7:0]  io_data;
    wire [31:0] mem_out;

    lane uut (.mem_in(mem_in), .sel(sel), .io_data(io_data), .mem_out(mem_out));

    task check;
        input [31:0] exp;
        input [255:0] tag;
        begin
            #1;
            if (mem_out !== exp) begin
                $display("FAIL: %0s expected %h found %h (sel=%0d)", tag, exp, mem_out, sel);
                $finish(1);
            end
        end
    endtask

    initial begin
        mem_in  = 32'h84A3_5B19;
        io_data = 8'h7E;

        sel = 4'd0;  check(32'h84A3_5B19, "word");
        sel = 4'd1;  check(32'h195B_A384, "swap");
        sel = 4'd2;  check(32'h0000_007E, "io");
        sel = 4'd3;  check(32'h0000_0000, "zero");

        // b0=19 +, b1=5B +, b2=A3 -, b3=84 -
        sel = 4'd4;  check(32'h0000_0019, "sb0");
        sel = 4'd5;  check(32'h0000_005B, "sb1");
        sel = 4'd6;  check(32'hFFFF_FFA3, "sb2");
        sel = 4'd7;  check(32'hFFFF_FF84, "sb3");

        sel = 4'd8;  check(32'h0000_0019, "zb0");
        sel = 4'd9;  check(32'h0000_005B, "zb1");
        sel = 4'd10; check(32'h0000_00A3, "zb2");
        sel = 4'd11; check(32'h0000_0084, "zb3");

        sel = 4'd12; check(32'h0000_5B19, "sh0+");
        sel = 4'd13; check(32'hFFFF_84A3, "sh1-");
        sel = 4'd14; check(32'h0000_5B19, "zh0");
        sel = 4'd15; check(32'h0000_84A3, "zh1");

        $display("PASS: lane");
        $finish;
    end
endmodule
