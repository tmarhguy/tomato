`timescale 1ns/1ps

module tb_alu_1b;
  import uvm_pkg::*;
  import alu_types_pkg::*;
  import alu_op_table_pkg::*;
  import alu_ref_model_pkg::*;
  import alu_cov_pkg::*;
  import alu_1b_pkg::*;

  bit clk;
  initial clk = 0;
  always #5 clk = ~clk;

  alu_1b_if alu_if (clk);

  \alu-1b-final dut (
    .OPCODE (alu_if.opcode),
    .A      (alu_if.a),
    .B      (alu_if.b),
    .C      (alu_if.c),
    .Asel   (alu_if.asel),
    .Bsel   (alu_if.bsel),
    .A_inv  (alu_if.a_inv),
    .B_inv  (alu_if.b_inv),
    .MUX_OUT(alu_if.mux_out),
    .G      (alu_if.g),
    .P      (alu_if.p)
  );

  initial begin
    uvm_config_db#(virtual alu_1b_if)::set(null, "uvm_test_top.env.agt*", "vif", alu_if);
    run_test();
  end
endmodule
