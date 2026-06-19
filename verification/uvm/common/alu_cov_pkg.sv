package alu_cov_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import alu_types_pkg::*;
  import alu_op_table_pkg::*;

  class alu_1b_coverage extends uvm_component;
    `uvm_component_utils(alu_1b_coverage)
    alu_1b_txn_t txn;
    covergroup cg_1b;
      opcode_cp: coverpoint txn.opcode { bins all_ops[] = {[0:255]}; }
      ctrl_cp: coverpoint {txn.asel, txn.ainv, txn.bsel, txn.binv} {
        bins all_ctrl[] = {[0:15]};
      }
      abc_cp: coverpoint {txn.a, txn.b, txn.c};
    endgroup
    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg_1b = new();
    endfunction
    function void sample(alu_1b_txn_t t);
      txn = t; cg_1b.sample();
    endfunction
  endclass

  class alu_8b_coverage extends uvm_component;
    `uvm_component_utils(alu_8b_coverage)
    alu_8b_txn_t txn;
    covergroup cg_8b;
      opcode_cp: coverpoint txn.opcode { bins all_ops[] = {[0:255]}; }
      ctrl_cp: coverpoint {txn.asel, txn.ainv, txn.bsel, txn.binv} {
        bins all_ctrl[] = {[0:15]};
      }
      cross_opcode_ctrl: cross opcode_cp, ctrl_cp;
      data_cp: coverpoint txn.a {
        bins zero = {8'h00}; bins ones = {8'hFF};
        bins walk = {8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
      }
    endgroup
    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg_8b = new();
    endfunction
    function void sample(alu_8b_txn_t t);
      txn = t; cg_8b.sample();
    endfunction
  endclass

  class alu_32b_coverage extends uvm_component;
    `uvm_component_utils(alu_32b_coverage)
    alu_32b_txn_t txn;
    int matched_op = -1;

    covergroup cg_32b;
      opcode_cp: coverpoint txn.opcode { bins all_ops[] = {[0:255]}; }
      ctrl_cp: coverpoint txn.control { bins all_ctrl[] = {[0:15]}; }
      csel_cp: coverpoint txn.csel {
        bins arith0 = {0}; bins arith1 = {1};
        bins logic2 = {2}; bins logic3 = {3};
      }
      cross_mode: cross csel_cp, ctrl_cp, opcode_cp;
      data_cp: coverpoint txn.a {
        bins zero     = {32'h00000000};
        bins ones     = {32'hFFFFFFFF};
        bins deadbeef = {32'hDEADBEEF};
        bins checker  = {32'hAAAAAAAA, 32'h55555555};
      }
      flag_we_cp: coverpoint txn.flag_we;
      op91_cp: coverpoint matched_op {
        bins op[] = {[0:NUM_OPS-1]};
      }
      flags_cp: coverpoint txn.csr_flag {
        bins z_set  = {13'h0001}; // simplified — sampled when flag_we
      }
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg_32b = new();
    endfunction

    function void sample(alu_32b_txn_t t);
      txn = t;
      matched_op = -1;
      for (int i = 0; i < NUM_OPS; i++) begin
        if (t.opcode == OP_TABLE[i].lut &&
            t.control == OP_TABLE[i].ctrl &&
            t.csel == OP_TABLE[i].csel) begin
          matched_op = i;
          break;
        end
      end
      cg_32b.sample();
    endfunction
  endclass

endpackage
