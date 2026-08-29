// Golden model for the FPGA dual-LUT ALU (hardware/fpga/core/rtl/alu.v).
// Structural bit-plane + wide add — friendly to SMT bitvector solvers.
`default_nettype none

function automatic [31:0] tomato_alu_planes32;
  input [7:0]  lut;
  input [31:0] A, B, C;
  integer i;
  reg [31:0] r;
  begin
    for (i = 0; i < 32; i = i + 1)
      r[i] = lut[{C[i], B[i], A[i]}];
    tomato_alu_planes32 = r;
  end
endfunction

function automatic [31:0] tomato_alu_predict_out;
  input [7:0]  lutA, lutB;
  input [31:0] A, B, C;
  input        cin;
  begin
    tomato_alu_predict_out =
        tomato_alu_planes32(lutA, A, B, C) +
        tomato_alu_planes32(lutB, A, B, C) +
        {31'b0, cin};
  end
endfunction

function automatic tomato_alu_predict_cout;
  input [7:0]  lutA, lutB;
  input [31:0] A, B, C;
  input        cin;
  reg [32:0] sum;
  begin
    sum = {1'b0, tomato_alu_planes32(lutA, A, B, C)} +
          {1'b0, tomato_alu_planes32(lutB, A, B, C)} +
          {32'b0, cin};
    tomato_alu_predict_cout = sum[32];
  end
endfunction
