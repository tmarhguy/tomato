`timescale 1ns/1ps

module tb_alu_8b;
  import uvm_pkg::*;
  import alu_types_pkg::*;
  import alu_op_table_pkg::*;
  import alu_ref_model_pkg::*;
  import alu_cov_pkg::*;
  import alu_8b_pkg::*;

  bit clk;
  initial clk = 0;
  always #5 clk = ~clk;

  alu_8b_if alu_if (clk);

  \alu-8b-final dut (
    .opcode (alu_if.opcode),
    .asel   (alu_if.asel),
    .A      (alu_if.a),
    .B      (alu_if.b),
    .C      (alu_if.c),
    .ainv   (alu_if.ainv),
    .bsel   (alu_if.bsel),
    .binv   (alu_if.binv),
    .out    (alu_if.out),
    .P      (alu_if.p),
    .G      (alu_if.g)
  );

  initial begin
    uvm_config_db#(virtual alu_8b_if)::set(null, "uvm_test_top.env.agt*", "vif", alu_if);
    run_test();
  end
endmodule
