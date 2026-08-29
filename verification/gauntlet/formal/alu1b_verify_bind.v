// Formal: alu1b LUT3 plane matches lut[{C,B,A}] for all inputs.
`default_nettype none

module alu1b_verify (
    input [7:0] lut,
    input       A, B, C
);
    wire out;
    alu1b dut (.lut(lut), .A(A), .B(B), .C(C), .out(out));

    always @(*) begin
        assert (out == lut[{C, B, A}]);
    end

    always @(*) begin
        cover (out == 1'b0);
        cover (out == 1'b1);
    end
endmodule
