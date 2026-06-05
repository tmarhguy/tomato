//  A testbench for shift_tb
`timescale 1us/1ns

module shift_tb;
    reg [31:0] A;
    reg [1:0] mode;
    reg [4:0] B;
    wire [31:0] Out;

  shift shift0 (
    .A(A),
    .mode(mode),
    .B(B),
    .Out(Out)
  );

