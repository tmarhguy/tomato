/*
 * Tomato — register file
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : regs.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * 8×32×32 GPRs. Addr = {bank, idx[4:0]}. 3R1W on exec.
 * r0 is hardwired to 0 (writes ignored) — keeps ADDI/JAL-link patterns sound.
 */
module regs (
    input         clk,
    input         we,
    input         exec,
    input         bank_en,
    input  [2:0]  bank_sel,
    input  [4:0]  addr_a,
    input  [4:0]  addr_b,
    input  [4:0]  addr_c,
    input  [4:0]  addr_w,
    input  [31:0] data_w,
    output [31:0] data_a,
    output [31:0] data_b,
    output [31:0] data_c
);
    reg [2:0]  bank;
    reg [31:0] mem [0:255];

    wire [7:0] pa = {bank, addr_a};
    wire [7:0] pb = {bank, addr_b};
    wire [7:0] pc = {bank, addr_c};
    wire [7:0] pw = {bank, addr_w};
    wire       wr_ok = exec & we & (addr_w != 5'd0);

    always @(posedge clk) begin
        if (bank_en) bank <= bank_sel;
        if (wr_ok) mem[pw] <= data_w;
    end

    assign data_a = (addr_a == 5'd0) ? 32'd0 : mem[pa];
    assign data_b = (addr_b == 5'd0) ? 32'd0 : mem[pb];
    assign data_c = (addr_c == 5'd0) ? 32'd0 : mem[pc];
endmodule
