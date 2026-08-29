// Formal: alu8b sum/cout ≡ dual-LUT planes + cin (all inputs).
`default_nettype none

module alu8b_verify (
    input [7:0] lutA, lutB,
    input [7:0] A, B, C,
    input       cin
);
    wire [7:0] sum;
    wire       cout;
    alu8b dut (
        .lutA(lutA), .lutB(lutB), .A(A), .B(B), .C(C), .cin(cin),
        .sum(sum), .cout(cout)
    );

    wire [7:0] fa, fb;
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : g
            assign fa[i] = lutA[{C[i], B[i], A[i]}];
            assign fb[i] = lutB[{C[i], B[i], A[i]}];
        end
    endgenerate
    wire [8:0] ref_sum = {1'b0, fa} + {1'b0, fb} + {8'b0, cin};

    always @(*) begin
        assert (sum == ref_sum[7:0]);
        assert (cout == ref_sum[8]);
    end

    always @(*) begin
        cover (cin == 1'b0);
        cover (cin == 1'b1);
        cover (cout == 1'b1);
        cover (sum == 8'h00);
    end
endmodule
