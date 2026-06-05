//  A testbench for alu-32b-final_tb
`timescale 1us/1ns

module alu-32b-final_tb;
    reg [31:0] A;
    reg nz0;
    reg [31:0] B;
    reg [7:0] Opcode;
    reg [4:0] control;
    reg [31:0] REG_C;
    reg \cin-sel ;
    reg FLAG_C;
    wire vout;
    wire zout;
    wire nzout;
    wire nout;
    wire [31:0] Out;
    wire cout;

  \alu-32b-final  \alu-32b-final 0 (
    .A(A),
    .nz0(nz0),
    .B(B),
    .Opcode(Opcode),
    .control(control),
    .REG_C(REG_C),
    .\cin-sel (\cin-sel ),
    .FLAG_C(FLAG_C),
    .vout(vout),
    .zout(zout),
    .nzout(nzout),
    .nout(nout),
    .Out(Out),
    .cout(cout)
  );

