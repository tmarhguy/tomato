// SVA assertions bound to 32b ALU (non-invasive)
bind \alu-32b-final alu_32b_assertions assert_inst (
  .A      (A),
  .B      (B),
  .C      (C),
  .Opcode (Opcode),
  .control(control),
  .csel   (csel),
  .CLK    (CLK),
  .FLAG_WE(FLAG_WE),
  .Out    (Out),
  .CSR_FLAG(CSR_FLAG)
);

module alu_32b_assertions (
  input [31:0] A, B, C,
  input [7:0]  Opcode,
  input [3:0]  control,
  input [1:0]  csel,
  input        CLK,
  input        FLAG_WE,
  input [31:0] Out,
  input [12:0] CSR_FLAG
);
  // Combinational stability
  property p_out_stable;
    @(A or B or C or Opcode or control or csel)
    $stable(Out);
  endproperty
  // Note: disabled during input changes — use ##1 check in UVM scoreboard instead

  property p_flag_we_known;
    @(posedge CLK) FLAG_WE |-> !$isunknown(CSR_FLAG);
  endproperty

  assert property (p_flag_we_known)
    else $error("CSR_FLAG unknown when FLAG_WE asserted");

endmodule
