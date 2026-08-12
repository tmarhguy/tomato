/*
 * Tomato — VGA tile RAM (MMIO)
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : vga.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Window mem_addr[21:19]==3'b110; tile index mem_addr[12:0].
 * Port A: CPU write. Port B: scanout read (registered).
 */
module vga (
    input         clk,
    input  [23:0] mem_addr,
    input  [31:0] mem_din,
    input         mem_wr,
    input  [12:0] raddr,
    output reg [31:0] rdata
);
    wire we = mem_wr & (mem_addr[21:19] == 3'b110);
    wire [12:0] waddr = mem_addr[12:0];

    (* ram_style = "block" *) reg [15:0] lo [0:8191];
    (* ram_style = "block" *) reg [15:0] hi [0:8191];

    always @(posedge clk) begin
        if (we) begin
            lo[waddr] <= mem_din[15:0];
            hi[waddr] <= mem_din[31:16];
        end
        rdata <= {hi[raddr], lo[raddr]};
    end
endmodule
