`timescale 1ns/1ps

module tb_alu_32b;
  import uvm_pkg::*;
  import alu_types_pkg::*;
  import alu_op_table_pkg::*;
  import alu_ref_model_pkg::*;
  import alu_cov_pkg::*;
  import alu_32b_pkg::*;

  bit clk;
  alu_32b_if alu_if (clk);

  \alu-32b-final dut (
    .A              (alu_if.a),
    .B              (alu_if.b),
    .Opcode         (alu_if.opcode),
    .control        (alu_if.control),
    .C              (alu_if.c),
    .csel           (alu_if.csel),
    .CLK            (alu_if.clk),
    .FLAG_WE        (alu_if.flag_we),
    .\~flag_a_is_zero (alu_if.flag_a_is_zero_n),
    .Out            (alu_if.out),
    .CSR_FLAG       (alu_if.csr_flag)
  );

  initial begin
    uvm_config_db#(virtual alu_32b_if)::set(null, "uvm_test_top.env.agt*", "vif", alu_if);
    uvm_config_db#(virtual alu_32b_if)::set(null, "uvm_test_top.env.clk_agt", "vif", alu_if);
    run_test();
  end
endmodule
