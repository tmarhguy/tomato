/*
 * Tomato — barrel shifter
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : shift.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * mode: 0=LSL 1=LSR 2=ASR 3=ROR; amount = B[4:0].
 */
module shift (
    input  [31:0] A,
    input  [1:0]  mode,
    input  [4:0]  B,
    output reg [31:0] Out
);
    wire [4:0] sh = B;

    always @(*) begin
        case (mode)
            2'b00: Out = A << sh;                                      // LSL
            2'b01: Out = A >> sh;                                      // LSR
            2'b10: Out = $signed(A) >>> sh;                            // ASR
            2'b11: Out = (sh == 5'd0) ? A
                                      : ((A >> sh) | (A << (5'd32 - sh))); // ROR
            default: Out = A;
        endcase
    end
endmodule
