// Spot-check: full `alu` with csel∈{0,1} matches golden (no flag-fed cin).
`default_nettype none

module alu32_top_verify (
    input [7:0]  lutA, lutB,
    input [31:0] A, B, C,
    input        cin_sel, // 0 → csel=0, 1 → csel=1
    input        clk
);
    wire [31:0] out;
    wire [7:0]  csr;

    alu dut (
        .lutA(lutA), .lutB(lutB), .A(A), .B(B), .C(C),
        .csel({2'b0, cin_sel}), .flag_we(1'b0), .clk(clk),
        .out(out), .csr(csr)
    );

    wire [31:0] ref_out = tomato_alu_predict_out(lutA, lutB, A, B, C, cin_sel);

    always @(*) begin
        assert (out === ref_out);
    end

    always @(*) begin
        cover (cin_sel == 1'b0);
        cover (cin_sel == 1'b1);
        cover (out == 32'h0);
    end
endmodule
