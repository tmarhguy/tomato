/*
 * Tomato — address mux
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : bus.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * On FETCH: addr=PC, mem_rd=1. Else addr_sel selects source.
 */
module bus (
    input         fetch,
    input         mem_rd_in,
    input  [2:0]  addr_sel,
    input  [21:0] ir_addr,
    input  [31:0] reg_b,
    input  [31:0] alu_in,
    input  [23:0] pc,
    input  [23:0] sp,
    output [23:0] addr,
    output        mem_rd
);
    reg [23:0] exec_addr;

    always @(*) begin
        case (addr_sel)
            3'd0: exec_addr = {2'b0, ir_addr};
            3'd1: exec_addr = alu_in[23:0];
            3'd2: exec_addr = reg_b[23:0];
            3'd3: exec_addr = pc;
            3'd7: exec_addr = sp;
            default: exec_addr = 24'b0;
        endcase
    end

    assign addr   = fetch ? pc : exec_addr;
    assign mem_rd = mem_rd_in | fetch;
endmodule
