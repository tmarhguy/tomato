// Formal: 32-bit dual-LUT datapath (four alu8b) ≡ fa+fb+cin for all inputs.
// Free cin abstracts the csel/flag mux; Verilator gauntlet exercises that mux.
`default_nettype none

module alu32_verify (
    input [7:0]  lutA, lutB,
    input [31:0] A, B, C,
    input        cin
);
    wire c8, c16, c24, c32;
    wire [31:0] sum;

    alu8b b0 (.lutA(lutA), .lutB(lutB), .A(A[7:0]),   .B(B[7:0]),   .C(C[7:0]),   .cin(cin), .sum(sum[7:0]),   .cout(c8));
    alu8b b1 (.lutA(lutA), .lutB(lutB), .A(A[15:8]),  .B(B[15:8]),  .C(C[15:8]),  .cin(c8),  .sum(sum[15:8]),  .cout(c16));
    alu8b b2 (.lutA(lutA), .lutB(lutB), .A(A[23:16]), .B(B[23:16]), .C(C[23:16]), .cin(c16), .sum(sum[23:16]), .cout(c24));
    alu8b b3 (.lutA(lutA), .lutB(lutB), .A(A[31:24]), .B(B[31:24]), .C(C[31:24]), .cin(c24), .sum(sum[31:24]), .cout(c32));

    wire [31:0] ref_out = tomato_alu_predict_out(lutA, lutB, A, B, C, cin);
    wire        ref_cout = tomato_alu_predict_cout(lutA, lutB, A, B, C, cin);

    always @(*) begin
        assert (sum === ref_out);
        assert (c32 === ref_cout);
    end

    always @(*) begin
        cover (cin == 1'b0);
        cover (cin == 1'b1);
        cover (c32 == 1'b1);
        cover (sum == 32'h0);
        cover (sum == 32'hFFFFFFFF);
    end
endmodule
