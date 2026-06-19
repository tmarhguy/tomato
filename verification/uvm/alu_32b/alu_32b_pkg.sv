package alu_32b_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import alu_types_pkg::*;
  import alu_op_table_pkg::*;
  import alu_ref_model_pkg::*;
  import alu_cov_pkg::*;
  import directed_vectors_pkg::*;

class alu_32b_seq_item extends uvm_sequence_item;
  rand bit [31:0] a, b, c;
  rand bit [7:0]  opcode;
  rand bit [3:0]  control;
  rand bit [1:0]  csel;
  rand bit        flag_we;
  rand bit        flag_a_is_zero_n;
  bit [31:0] out;
  bit [12:0] csr_flag;
  `uvm_object_utils(alu_32b_seq_item)
  function new(string name = "alu_32b_seq_item"); super.new(name); endfunction
  function alu_32b_txn_t to_txn();
    alu_32b_txn_t t;
    t.a = a; t.b = b; t.c = c; t.opcode = opcode;
    t.control = control; t.csel = csel;
    t.flag_we = flag_we; t.flag_a_is_zero_n = flag_a_is_zero_n;
    return t;
  endfunction
endclass

class alu_32b_sequencer extends uvm_sequencer #(alu_32b_seq_item);
  `uvm_component_utils(alu_32b_sequencer)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass

class alu_32b_driver extends uvm_driver #(alu_32b_seq_item);
  `uvm_component_utils(alu_32b_driver)
  virtual alu_32b_if vif;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_32b_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "alu_32b vif missing")
  endfunction
  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      vif.a      <= req.a;
      vif.b      <= req.b;
      vif.c      <= req.c;
      vif.opcode <= req.opcode;
      vif.control<= req.control;
      vif.csel   <= req.csel;
      vif.flag_we<= req.flag_we;
      vif.flag_a_is_zero_n <= req.flag_a_is_zero_n;
      @(posedge vif.clk);
      #1;
      req.out = vif.out;
      req.csr_flag = vif.csr_flag;
      seq_item_port.item_done();
    end
  endtask
endclass

class alu_32b_monitor extends uvm_monitor;
  `uvm_component_utils(alu_32b_monitor)
  virtual alu_32b_if vif;
  uvm_analysis_port #(alu_32b_seq_item) ap;
  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_32b_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "alu_32b vif missing")
  endfunction
  task run_phase(uvm_phase phase);
    alu_32b_seq_item item;
    forever begin
      @(posedge vif.clk);
      #1;
      item = alu_32b_seq_item::type_id::create("item");
      item.a = vif.a; item.b = vif.b; item.c = vif.c;
      item.opcode = vif.opcode; item.control = vif.control;
      item.csel = vif.csel; item.flag_we = vif.flag_we;
      item.flag_a_is_zero_n = vif.flag_a_is_zero_n;
      item.out = vif.out; item.csr_flag = vif.csr_flag;
      ap.write(item);
    end
  endtask
endclass

class alu_32b_agent extends uvm_agent;
  `uvm_component_utils(alu_32b_agent)
  alu_32b_driver drv; alu_32b_monitor mon; alu_32b_sequencer sqr;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = alu_32b_driver::type_id::create("drv", this);
    mon = alu_32b_monitor::type_id::create("mon", this);
    sqr = alu_32b_sequencer::type_id::create("sqr", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

class alu_32b_clk_agent extends uvm_agent;
  `uvm_component_utils(alu_32b_clk_agent)
  virtual alu_32b_if vif;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_32b_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "alu_32b vif missing")
  endfunction
  task run_phase(uvm_phase phase);
    vif.clk <= 0;
    forever #5 vif.clk = ~vif.clk;
  endtask
endclass

class alu_32b_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_32b_scoreboard)
  uvm_analysis_imp #(alu_32b_seq_item, alu_32b_scoreboard) imp;
  int unsigned n_checked = 0, n_errors = 0;
  function new(string name, uvm_component parent);
    super.new(name, parent);
    imp = new("imp", this);
  endfunction
  function void write(alu_32b_seq_item item);
    bit [31:0] exp_out;
    bit [12:0] exp_flag;
    n_checked++;
    exp_out = alu_ref_model::predict_out_dut(
      item.a, item.b, item.c, item.opcode, item.control, item.csel, item.out);
    if (item.out !== exp_out) begin
      n_errors++;
      `uvm_error("SB", $sformatf(
        "Out mismatch op=%02x ctrl=%01x csel=%01x A=%08x B=%08x C=%08x | got %08x exp %08x",
        item.opcode, item.control, item.csel,
        item.a, item.b, item.c, item.out, exp_out))
    end
    if (item.flag_we) begin
      exp_flag = alu_ref_model::predict_csr_flag(
        item.out, item.a, item.b, item.control, item.flag_a_is_zero_n);
      if (item.csr_flag[11:0] !== exp_flag[11:0]) begin
        n_errors++;
        `uvm_warning("SB", $sformatf(
          "CSR_FLAG mismatch (lo 12b) got %013b exp %013b", item.csr_flag, exp_flag))
      end
    end
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("32b: %0d checked, %0d errors", n_checked, n_errors), UVM_LOW)
    if (n_errors > 0) `uvm_fatal("SB", "32b scoreboard errors")
  endfunction
endclass

class alu_32b_cov_sub extends uvm_subscriber #(alu_32b_seq_item);
  `uvm_component_utils(alu_32b_cov_sub)
  alu_32b_coverage cov;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void write(alu_32b_seq_item t); cov.sample(t.to_txn()); endfunction
endclass

class alu_32b_env extends uvm_env;
  `uvm_component_utils(alu_32b_env)
  alu_32b_agent agt; alu_32b_clk_agent clk_agt;
  alu_32b_scoreboard sb; alu_32b_coverage cov; alu_32b_cov_sub cov_sub;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt     = alu_32b_agent::type_id::create("agt", this);
    clk_agt = alu_32b_clk_agent::type_id::create("clk_agt", this);
    sb      = alu_32b_scoreboard::type_id::create("sb", this);
    cov     = alu_32b_coverage::type_id::create("cov", this);
    cov_sub = alu_32b_cov_sub::type_id::create("cov_sub", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    cov_sub.cov = cov;
    agt.mon.ap.connect(sb.imp);
    agt.mon.ap.connect(cov_sub.analysis_export);
  endfunction
endclass

  `include "alu_32b_seq_lib.sv"
  `include "alu_32b_tests.sv"

endpackage
