// Full combinational equivalence via CSR_FLAG[4] (= latched flag_c)
`default_nettype none

module alu_32b_equiv_verify (
    input  [31:0] A,
    input  [31:0] B,
    input  [31:0] C,
    input  [7:0]  Opcode,
    input  [3:0]  control,
    input  [1:0]  csel,
    input         CLK,
    input         FLAG_WE,
    input         Flag_A_is_Zero_n
);

    wire [31:0] Out;
    wire [12:0] CSR_FLAG;

    \alu-32b-final dut (
        .A              (A),
        .B              (B),
        .C              (C),
        .Opcode         (Opcode),
        .control        (control),
        .csel           (csel),
        .CLK            (CLK),
        .FLAG_WE        (FLAG_WE),
        .\~flag_a_is_zero (Flag_A_is_Zero_n),
        .Out            (Out),
        .CSR_FLAG       (CSR_FLAG)
    );

    wire [31:0] ref_out = alu_predict_out(A, B, C, Opcode, control, csel, CSR_FLAG[4]);

    always @(*) begin
        assert (Out === ref_out);
    end

    always @(*) begin
        cover (csel == 2'b10);
        cover (csel == 2'b11);
        cover (Out == 32'h0);
    end

endmodule
