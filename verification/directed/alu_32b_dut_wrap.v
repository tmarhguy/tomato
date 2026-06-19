// Wrapper for Icarus — avoids escaped port names in testbench
`default_nettype none

module alu_32b_dut_wrap (
    input  [31:0] a,
    input  [31:0] b,
    input  [31:0] c,
    input  [7:0]  opcode,
    input  [3:0]  control,
    input  [1:0]  csel,
    input         clk,
    input         flag_we,
    input         flag_a_is_zero_n,
    output [31:0] out,
    output [12:0] csr_flag
);
    \alu-32b-final dut (
        .A              (a),
        .B              (b),
        .C              (c),
        .Opcode         (opcode),
        .control        (control),
        .csel           (csel),
        .CLK            (clk),
        .FLAG_WE        (flag_we),
        .\~flag_a_is_zero (flag_a_is_zero_n),
        .Out            (out),
        .CSR_FLAG       (csr_flag)
    );
endmodule
