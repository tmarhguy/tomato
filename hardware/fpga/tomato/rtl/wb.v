/*
 * Tomato — writeback mux
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : wb.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * sel=1: shift/mul lo; sel=7: mul hi / rem.
 */
module wb (
    input  [2:0]  wb_sel,
    input  [31:0] alu_out,
    input  [31:0] shift_mul,
    input  [23:0] pc_save,
    input  [31:0] mem_din,
    input  [31:0] reg_a,
    input  [31:0] imm,
    input  [7:0]  csr_flags,
    input  [31:0] mul_hi,
    output reg [31:0] wb_data
);
    always @(*) begin
        case (wb_sel)
            3'd0: wb_data = alu_out;
            3'd1: wb_data = shift_mul;
            3'd2: wb_data = {8'b0, pc_save};
            3'd3: wb_data = mem_din;
            3'd4: wb_data = reg_a;
            3'd5: wb_data = imm;
            3'd6: wb_data = {24'b0, csr_flags};
            3'd7: wb_data = mul_hi;
            default: wb_data = 32'b0;
        endcase
    end
endmodule
