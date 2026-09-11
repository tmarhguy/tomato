/*
 * Tomato — 8-digit hex → 7-segment
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : hex.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Shows a 32-bit value (last nonzero writeback / store) on Nexys A7 digits.
 */
module hex (
    input         clk,
    input         reset,
    input  [31:0] value,
    output reg [6:0] seg,
    output reg [7:0] an,
    output        dp
);
    assign dp = 1'b1; // off (active-low)

    reg [16:0] div;
    always @(posedge clk) begin
        if (reset) div <= 17'd0;
        else       div <= div + 17'd1;
    end

    wire [2:0] dig = div[16:14];
    reg [3:0] nibble;
    always @(*) begin
        case (dig)
            3'd0: nibble = value[3:0];
            3'd1: nibble = value[7:4];
            3'd2: nibble = value[11:8];
            3'd3: nibble = value[15:12];
            3'd4: nibble = value[19:16];
            3'd5: nibble = value[23:20];
            3'd6: nibble = value[27:24];
            default: nibble = value[31:28];
        endcase
    end

    // gfedcba, active-low
    reg [6:0] font;
    always @(*) begin
        case (nibble)
            4'h0: font = 7'b1000000;
            4'h1: font = 7'b1111001;
            4'h2: font = 7'b0100100;
            4'h3: font = 7'b0110000;
            4'h4: font = 7'b0011001;
            4'h5: font = 7'b0010010;
            4'h6: font = 7'b0000010;
            4'h7: font = 7'b1111000;
            4'h8: font = 7'b0000000;
            4'h9: font = 7'b0010000;
            4'hA: font = 7'b0001000;
            4'hB: font = 7'b0000011;
            4'hC: font = 7'b1000110;
            4'hD: font = 7'b0100001;
            4'hE: font = 7'b0000110;
            default: font = 7'b0001110; // F
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            seg <= 7'b1111111;
            an  <= 8'hFF;
        end else begin
            seg <= font;
            an  <= ~(8'b1 << dig);
        end
    end
endmodule
