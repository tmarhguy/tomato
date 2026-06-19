// Formal verification wrapper for 8-bit ALU slice
`default_nettype none

module alu_8b_verify (
    input  [7:0] opcode,
    input        asel,
    input  [7:0] A,
    input  [7:0] B,
    input  [7:0] C,
    input        ainv,
    input        bsel,
    input        binv
);

    wire [7:0] out;
    wire [7:0] P;
    wire [7:0] G;

    \alu-8b-final dut (
        .opcode (opcode),
        .asel   (asel),
        .A      (A),
        .B      (B),
        .C      (C),
        .ainv   (ainv),
        .bsel   (bsel),
        .binv   (binv),
        .out    (out),
        .P      (P),
        .G      (G)
    );

    wire [7:0] A_eff = ((asel ? A : 8'b0) ^ (ainv ? 8'hFF : 8'b0));
    wire [7:0] B_eff = ((bsel ? B : 8'b0) ^ (binv ? 8'hFF : 8'b0));

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : bit_check
        wire ref_out = opcode[{C[i], B_eff[i], A_eff[i]}];
        always @(*) begin
            assert (out[i] == ref_out);
            assert (G[i] == (A_eff[i] & B_eff[i]));
            assert (P[i] == (A_eff[i] ^ B_eff[i]));
        end
    end
  endgenerate

    always @(*) begin
        cover (out == 8'hFF);
        cover (out == 8'h00);
        cover (|G);
        cover (|P);
    end

endmodule
