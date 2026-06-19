// Formal cover: FLAG_WE reachability and flag rail encoding (exact latch in UVM)
`default_nettype none

module alu_32b_flags_verify (
    input        CLK,
    input        FLAG_WE,
    input        Flag_A_is_Zero_n,
    input  [31:0] A,
    input  [31:0] B,
    input  [31:0] C,
    input  [7:0]  Opcode,
    input  [3:0]  control,
    input  [1:0]  csel
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

    always @(posedge CLK) begin
        cover (FLAG_WE);
        cover (FLAG_WE && (Out == 32'h0));
        cover (FLAG_WE && (Out != 32'h0));
        cover (FLAG_WE && Out[31]);
        // Dual-rail: ~Z rail set when Out==0
        cover (FLAG_WE && CSR_FLAG[1] == (Out == 32'h0));
    end

endmodule
