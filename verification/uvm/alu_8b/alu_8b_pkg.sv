package alu_8b_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import alu_types_pkg::*;
  import alu_op_table_pkg::*;
  import alu_ref_model_pkg::*;
  import alu_cov_pkg::*;

class alu_8b_seq_item extends uvm_sequence_item;
  rand bit [7:0] opcode;
  rand bit [7:0] a, b, c;
  rand bit       asel, ainv, bsel, binv;
  bit [7:0] out, g, p;
  `uvm_object_utils(alu_8b_seq_item)
  function new(string name = "alu_8b_seq_item"); super.new(name); endfunction
  function alu_8b_txn_t to_txn();
    alu_8b_txn_t t;
    t.opcode = opcode; t.a = a; t.b = b; t.c = c;
    t.asel = asel; t.ainv = ainv; t.bsel = bsel; t.binv = binv;
    return t;
  endfunction
endclass

class alu_8b_sequencer extends uvm_sequencer #(alu_8b_seq_item);
  `uvm_component_utils(alu_8b_sequencer)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass

class alu_8b_driver extends uvm_driver #(alu_8b_seq_item);
  `uvm_component_utils(alu_8b_driver)
  virtual alu_8b_if vif;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_8b_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "alu_8b vif missing")
  endfunction
  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      vif.opcode <= req.opcode;
      vif.a      <= req.a;
      vif.b      <= req.b;
      vif.c      <= req.c;
      vif.asel   <= req.asel;
      vif.ainv   <= req.ainv;
      vif.bsel   <= req.bsel;
      vif.binv   <= req.binv;
      #1;
      req.out = vif.out; req.g = vif.g; req.p = vif.p;
      seq_item_port.item_done();
    end
  endtask
endclass

class alu_8b_monitor extends uvm_monitor;
  `uvm_component_utils(alu_8b_monitor)
  virtual alu_8b_if vif;
  uvm_analysis_port #(alu_8b_seq_item) ap;
  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_8b_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "alu_8b vif missing")
  endfunction
  task run_phase(uvm_phase phase);
    alu_8b_seq_item item;
    forever begin
      @(vif.opcode or vif.a or vif.b or vif.c or vif.asel or vif.ainv or vif.bsel or vif.binv);
      #1;
      item = alu_8b_seq_item::type_id::create("item");
      item.opcode = vif.opcode;
      item.a = vif.a; item.b = vif.b; item.c = vif.c;
      item.asel = vif.asel; item.ainv = vif.ainv;
      item.bsel = vif.bsel; item.binv = vif.binv;
      item.out = vif.out; item.g = vif.g; item.p = vif.p;
      ap.write(item);
    end
  endtask
endclass

class alu_8b_agent extends uvm_agent;
  `uvm_component_utils(alu_8b_agent)
  alu_8b_driver drv; alu_8b_monitor mon; alu_8b_sequencer sqr;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = alu_8b_monitor::type_id::create("mon", this);
    if (is_active == UVM_ACTIVE) begin
      drv = alu_8b_driver::type_id::create("drv", this);
      sqr = alu_8b_sequencer::type_id::create("sqr", this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE) drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

class alu_8b_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_8b_scoreboard)
  uvm_analysis_imp #(alu_8b_seq_item, alu_8b_scoreboard) imp;
  int unsigned n_checked = 0, n_errors = 0;
  function new(string name, uvm_component parent);
    super.new(name, parent);
    imp = new("imp", this);
  endfunction
  function void write(alu_8b_seq_item item);
    alu_8b_txn_t t = item.to_txn();
    bit [7:0] exp_out = alu_ref_model::predict_out_8b(t);
    bit [7:0] exp_g, exp_p;
    alu_ref_model::predict_gp_8b(t, exp_g, exp_p);
    n_checked++;
    if (item.out !== exp_out || item.g !== exp_g || item.p !== exp_p) begin
      n_errors++;
      `uvm_error("SB", $sformatf("8b mismatch out %02x!=%02x g %02x!=%02x p %02x!=%02x",
        item.out, exp_out, item.g, exp_g, item.p, exp_p))
    end
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("8b: %0d checked, %0d errors", n_checked, n_errors), UVM_LOW)
    if (n_errors > 0) `uvm_fatal("SB", "8b scoreboard errors")
  endfunction
endclass

class alu_8b_cov_sub extends uvm_subscriber #(alu_8b_seq_item);
  `uvm_component_utils(alu_8b_cov_sub)
  alu_8b_coverage cov;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void write(alu_8b_seq_item t); cov.sample(t.to_txn()); endfunction
endclass

class alu_8b_env extends uvm_env;
  `uvm_component_utils(alu_8b_env)
  alu_8b_agent agt; alu_8b_scoreboard sb; alu_8b_coverage cov; alu_8b_cov_sub cov_sub;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = alu_8b_agent::type_id::create("agt", this);
    sb  = alu_8b_scoreboard::type_id::create("sb", this);
    cov = alu_8b_coverage::type_id::create("cov", this);
    cov_sub = alu_8b_cov_sub::type_id::create("cov_sub", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    cov_sub.cov = cov;
    agt.mon.ap.connect(sb.imp);
    agt.mon.ap.connect(cov_sub.analysis_export);
  endfunction
endclass

class alu_8b_random_seq extends uvm_sequence #(alu_8b_seq_item);
  `uvm_object_utils(alu_8b_random_seq)
  int unsigned count = 1000;
  function new(string name = "alu_8b_random_seq"); super.new(name); endfunction
  task body();
    repeat (count) begin
      alu_8b_seq_item item = alu_8b_seq_item::type_id::create("item");
      void'(item.randomize());
      start_item(item); finish_item(item);
    end
  endtask
endclass

class alu_8b_cla_boundary_seq extends uvm_sequence #(alu_8b_seq_item);
  `uvm_object_utils(alu_8b_cla_boundary_seq)
  function new(string name = "alu_8b_cla_boundary_seq"); super.new(name); endfunction
  task body();
    bit [7:0] apat[6] = '{8'hFF, 8'h7F, 8'hAA, 8'h55, 8'h00, 8'h01};
    bit [7:0] bpat[6] = '{8'h01, 8'h01, 8'h55, 8'hAA, 8'h00, 8'hFF};
    foreach (apat[i]) begin
      alu_8b_seq_item item = alu_8b_seq_item::type_id::create("item");
      item.opcode = 8'h96;
      item.asel = 1; item.ainv = 0; item.bsel = 1; item.binv = 0;
      item.a = apat[i]; item.b = bpat[i]; item.c = 8'h00;
      start_item(item); finish_item(item);
    end
  endtask
endclass

class alu_8b_logic_sweep_seq extends uvm_sequence #(alu_8b_seq_item);
  `uvm_object_utils(alu_8b_logic_sweep_seq)
  function new(string name = "alu_8b_logic_sweep_seq"); super.new(name); endfunction
  task body();
    for (int i = 30; i < NUM_OPS; i++) begin
      alu_8b_seq_item item = alu_8b_seq_item::type_id::create("item");
      void'(item.randomize() with {
        opcode == OP_TABLE[i].lut;
        asel == 1; ainv == 0; bsel == 1; binv == 0;
      });
      start_item(item); finish_item(item);
    end
  endtask
endclass

class alu_8b_base_test extends uvm_test;
  `uvm_component_utils(alu_8b_base_test)
  alu_8b_env env;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = alu_8b_env::type_id::create("env", this);
  endfunction
  virtual task run_sequences();
    alu_8b_random_seq r = alu_8b_random_seq::type_id::create("r");
    r.count = 500;
    r.start(env.agt.sqr);
  endtask
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_sequences();
    phase.drop_objection(this);
  endtask
endclass

class alu_8b_smoke_test extends alu_8b_base_test;
  `uvm_component_utils(alu_8b_smoke_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_sequences();
    alu_8b_cla_boundary_seq c = alu_8b_cla_boundary_seq::type_id::create("c");
    c.start(env.agt.sqr);
    alu_8b_logic_sweep_seq l = alu_8b_logic_sweep_seq::type_id::create("l");
    l.start(env.agt.sqr);
  endtask
endclass

class alu_8b_full_test extends alu_8b_base_test;
  `uvm_component_utils(alu_8b_full_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_sequences();
    alu_8b_cla_boundary_seq c = alu_8b_cla_boundary_seq::type_id::create("c");
    c.start(env.agt.sqr);
    alu_8b_logic_sweep_seq l = alu_8b_logic_sweep_seq::type_id::create("l");
    l.start(env.agt.sqr);
    alu_8b_random_seq r = alu_8b_random_seq::type_id::create("r");
    r.count = 5000;
    r.start(env.agt.sqr);
  endtask
endclass

endpackage
