/*
 * Tomato — microcode decode
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : control.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * Opcode tables are BURNED via rtl/burn/mc_*.vh (tools/gen_fpga_burn.py).
 * Include dir must be rtl/ so `include "burn/..." resolves.
 *
 * The eight planes are asynchronous-read constant tables, deliberately left
 * unhinted: 461 of the 512 rows are NOP, so letting the mapper fold them into
 * LUT logic is both smaller and the only thing nextpnr can place — a 512-deep
 * async ROM does not cascade into Xilinx LUTRAM primitives.
 */
module rom512_alu_shift (
    input  [8:0] addr,
    output [7:0] data
);
    reg [7:0] mem [0:511];
    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1) mem[i] = 8'h00;
        `include "burn/mc_alu_shift_control.vh"
    end
    assign data = mem[addr];
endmodule

module rom512_alu_a (
    input  [8:0] addr,
    output [7:0] data
);
    reg [7:0] mem [0:511];
    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1) mem[i] = 8'h00;
        `include "burn/mc_alu_control_1.vh"
    end
    assign data = mem[addr];
endmodule

module rom512_alu_b (
    input  [8:0] addr,
    output [7:0] data
);
    reg [7:0] mem [0:511];
    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1) mem[i] = 8'h00;
        `include "burn/mc_alu_lut_b.vh"
    end
    assign data = mem[addr];
endmodule

module rom512_ir_reg (
    input  [8:0] addr,
    output [7:0] data
);
    reg [7:0] mem [0:511];
    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1) mem[i] = 8'h00;
        `include "burn/mc_ir_reg_control.vh"
    end
    assign data = mem[addr];
endmodule

module rom512_mem_io (
    input  [8:0] addr,
    output [7:0] data
);
    reg [7:0] mem [0:511];
    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1) mem[i] = 8'h00;
        `include "burn/mc_mem_io_control.vh"
    end
    assign data = mem[addr];
endmodule

module rom512_mem_bus (
    input  [8:0] addr,
    output [7:0] data
);
    reg [7:0] mem [0:511];
    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1) mem[i] = 8'h00;
        `include "burn/mc_mem_bus_control.vh"
    end
    assign data = mem[addr];
endmodule

module rom512_pc (
    input  [8:0] addr,
    output [7:0] data
);
    reg [7:0] mem [0:511];
    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1) mem[i] = 8'h00;
        `include "burn/mc_pc_control.vh"
    end
    assign data = mem[addr];
endmodule

module rom512_pc_sp (
    input  [8:0] addr,
    output [7:0] data
);
    reg [7:0] mem [0:511];
    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1) mem[i] = 8'h00;
        `include "burn/mc_pc_sp_mul_control.vh"
    end
    assign data = mem[addr];
endmodule

module aluctrl (
    input  [8:0] op,
    output [7:0] lutA,
    output [7:0] lutB,
    output [2:0] csel,
    output       flagwe,
    output [1:0] shiftop,
    output       mulen,
    output       penc
);
    wire [7:0] sh;
    rom512_alu_shift shrom (.addr(op), .data(sh));
    rom512_alu_a     arom  (.addr(op), .data(lutA));
    rom512_alu_b     brom  (.addr(op), .data(lutB));
    assign csel    = sh[2:0];
    assign flagwe  = sh[3];
    assign shiftop = sh[5:4];
    assign mulen   = sh[6];
    assign penc    = sh[7];
endmodule

module irctrl (
    input  [8:0] op,
    output [3:0] immsel,
    output [2:0] wbsel,
    output       regwe
);
    wire [7:0] d;
    rom512_ir_reg rom (.addr(op), .data(d));
    assign immsel = d[3:0];
    assign wbsel  = d[6:4];
    assign regwe  = d[7];
endmodule

module memio (
    input  [8:0] op,
    input        fetch,
    output       banken,
    output       memrd,
    output       memwr,
    output [3:0] bytesel
);
    wire [7:0] d;
    rom512_mem_io rom (.addr(op), .data(d));
    assign banken  = d[0];
    assign memrd   = d[1];
    assign memwr   = d[2] & ~fetch;
    assign bytesel = d[6:3];
endmodule

module membus (
    input  [8:0] op,
    output [2:0] bussel,
    output       alusel
);
    wire [7:0] d;
    rom512_mem_bus rom (.addr(op), .data(d));
    assign bussel = d[2:0];
    assign alusel = d[3];
endmodule

module pcctrl (
    input        exec,
    input  [8:0] op,
    output       branchen,
    output       jumptype,
    output [2:0] pcsrc,
    output       pclinkwe,
    output [1:0] cycles,
    output [2:0] pccond,
    output [1:0] spop,
    output       halt
);
    wire [7:0] d0, d1;
    rom512_pc    rom0 (.addr(op), .data(d0));
    rom512_pc_sp rom1 (.addr(op), .data(d1));
    wire [7:0] pc = (|d0) ? d0 : 8'h40;
    assign branchen  = pc[0];
    assign jumptype  = pc[1];
    assign pcsrc     = pc[4:2];
    assign pclinkwe  = pc[5];
    assign cycles    = pc[7:6];
    assign pccond    = d1[2:0];
    assign spop      = d1[5:4];
    assign halt      = ((op == 9'h0FF) | (op == 9'h0E2)) & exec;
endmodule
