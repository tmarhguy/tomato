package alu_1b_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import alu_types_pkg::*;
  import alu_ref_model_pkg::*;
  import alu_cov_pkg::*;

// 1-bit ALU UVM transaction
class alu_1b_seq_item extends uvm_sequence_item;
  rand bit [7:0] opcode;
  rand bit       a, b, c;
  rand bit       asel, bsel, a_inv, b_inv;

  bit mux_out, g, p;

  `uvm_object_utils(alu_1b_seq_item)

  function new(string name = "alu_1b_seq_item");
    super.new(name);
  endfunction

  function alu_1b_txn_t to_txn();
    alu_1b_txn_t t;
    t.opcode = opcode;
    t.a = a; t.b = b; t.c = c;
    t.asel = asel; t.bsel = bsel;
    t.ainv = a_inv; t.binv = b_inv;
    return t;
  endfunction

  function void from_txn(alu_1b_txn_t t);
    opcode = t.opcode;
    a = t.a; b = t.b; c = t.c;
    asel = t.asel; bsel = t.bsel;
    a_inv = t.ainv; b_inv = t.binv;
  endfunction

  constraint c_opcode_96 { opcode dist { 8'h96 := 80, [0:255] := 1 }; }
endclass

class alu_1b_sequencer extends uvm_sequencer #(alu_1b_seq_item);
  `uvm_component_utils(alu_1b_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class alu_1b_driver extends uvm_driver #(alu_1b_seq_item);
  `uvm_component_utils(alu_1b_driver)
  virtual alu_1b_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_1b_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "alu_1b virtual interface not set")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      vif.opcode  <= req.opcode;
      vif.a       <= req.a;
      vif.b       <= req.b;
      vif.c       <= req.c;
      vif.asel    <= req.asel;
      vif.bsel    <= req.bsel;
      vif.a_inv   <= req.a_inv;
      vif.b_inv   <= req.b_inv;
      #1;
      req.mux_out = vif.mux_out;
      req.g       = vif.g;
      req.p       = vif.p;
      seq_item_port.item_done();
    end
  endtask
endclass

class alu_1b_monitor extends uvm_monitor;
  `uvm_component_utils(alu_1b_monitor)
  virtual alu_1b_if vif;
  uvm_analysis_port #(alu_1b_seq_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_1b_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "alu_1b virtual interface not set")
  endfunction

  task run_phase(uvm_phase phase);
    alu_1b_seq_item item;
    forever begin
      @(vif.opcode or vif.a or vif.b or vif.c or
        vif.asel or vif.bsel or vif.a_inv or vif.b_inv);
      #1;
      item = alu_1b_seq_item::type_id::create("item");
      item.opcode  = vif.opcode;
      item.a       = vif.a;
      item.b       = vif.b;
      item.c       = vif.c;
      item.asel    = vif.asel;
      item.bsel    = vif.bsel;
      item.a_inv   = vif.a_inv;
      item.b_inv   = vif.b_inv;
      item.mux_out = vif.mux_out;
      item.g       = vif.g;
      item.p       = vif.p;
      ap.write(item);
    end
  endtask
endclass

class alu_1b_agent extends uvm_agent;
  `uvm_component_utils(alu_1b_agent)
  alu_1b_driver    drv;
  alu_1b_monitor   mon;
  alu_1b_sequencer sqr;
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = alu_1b_monitor::type_id::create("mon", this);
    if (is_active == UVM_ACTIVE) begin
      drv = alu_1b_driver::type_id::create("drv", this);
      sqr = alu_1b_sequencer::type_id::create("sqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

class alu_1b_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_1b_scoreboard)
  uvm_analysis_imp #(alu_1b_seq_item, alu_1b_scoreboard) imp;
  int unsigned n_checked = 0;
  int unsigned n_errors  = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    imp = new("imp", this);
  endfunction

  function void write(alu_1b_seq_item item);
    alu_1b_txn_t t = item.to_txn();
    bit exp_mux = alu_ref_model::predict_mux_1b(t);
    bit exp_g, exp_p;
    alu_ref_model::predict_gp_1b(t, exp_g, exp_p);
    n_checked++;
    if (item.mux_out !== exp_mux || item.g !== exp_g || item.p !== exp_p) begin
      n_errors++;
      `uvm_error("SB", $sformatf(
        "1b mismatch opcode=%02x ctrl=%b A=%b B=%b C=%b | mux %b!=%b g %b!=%b p %b!=%b",
        item.opcode, {item.asel,item.a_inv,item.bsel,item.b_inv},
        item.a, item.b, item.c,
        item.mux_out, exp_mux, item.g, exp_g, item.p, exp_p))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("1b scoreboard: %0d checked, %0d errors", n_checked, n_errors), UVM_LOW)
    if (n_errors > 0)
      `uvm_fatal("SB", "1b scoreboard errors detected")
  endfunction
endclass

class alu_1b_cov_subscriber extends uvm_subscriber #(alu_1b_seq_item);
  `uvm_component_utils(alu_1b_cov_subscriber)
  alu_1b_coverage cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void write(alu_1b_seq_item t);
    cov.sample(t.to_txn());
  endfunction
endclass

class alu_1b_env extends uvm_env;
  `uvm_component_utils(alu_1b_env)
  alu_1b_agent          agt;
  alu_1b_scoreboard     sb;
  alu_1b_coverage       cov;
  alu_1b_cov_subscriber cov_sub;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt     = alu_1b_agent::type_id::create("agt", this);
    sb      = alu_1b_scoreboard::type_id::create("sb", this);
    cov     = alu_1b_coverage::type_id::create("cov", this);
    cov_sub = alu_1b_cov_subscriber::type_id::create("cov_sub", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    cov_sub.cov = cov;
    agt.mon.ap.connect(sb.imp);
    agt.mon.ap.connect(cov_sub.analysis_export);
  endfunction
endclass

  `include "alu_1b_seq_lib.sv"
  `include "alu_1b_tests.sv"

endpackage
