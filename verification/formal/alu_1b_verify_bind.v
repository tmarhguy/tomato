// Formal verification wrapper for 1-bit ALU slice
`default_nettype none

module alu_1b_verify (
    input  [7:0] OPCODE,
    input        A,
    input        B,
    input        C,
    input        Asel,
    input        Bsel,
    input        A_inv,
    input        B_inv
);

    wire MUX_OUT;
    wire G;
    wire P;

    \alu-1b-final dut (
        .OPCODE (OPCODE),
        .A      (A),
        .B      (B),
        .C      (C),
        .Asel   (Asel),
        .Bsel   (Bsel),
        .A_inv  (A_inv),
        .B_inv  (B_inv),
        .MUX_OUT(MUX_OUT),
        .G      (G),
        .P      (P)
    );

    wire A_eff = ((Asel & A) ^ A_inv);
    wire B_eff = ((Bsel & B) ^ B_inv);
    wire ref_mux = OPCODE[{C, B_eff, A_eff}];

    always @(*) begin
        assert (MUX_OUT == ref_mux);
        assert (G == (A_eff & B_eff));
        assert (P == (A_eff ^ B_eff));
    end

    always @(*) begin
        cover (MUX_OUT == 1'b1);
        cover (MUX_OUT == 1'b0);
        cover (G == 1'b1);
        cover (P == 1'b1);
    end

endmodule
