class alu_1b_base_test extends uvm_test;
  `uvm_component_utils(alu_1b_base_test)
  alu_1b_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = alu_1b_env::type_id::create("env", this);
  endfunction

  virtual task run_sequence();
    alu_1b_random_seq seq = alu_1b_random_seq::type_id::create("seq");
    seq.count = 500;
    seq.start(env.agt.sqr);
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_sequence();
    phase.drop_objection(this);
  endtask
endclass

class alu_1b_exhaustive_test extends alu_1b_base_test;
  `uvm_component_utils(alu_1b_exhaustive_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_sequence();
    alu_1b_exhaustive_seq seq = alu_1b_exhaustive_seq::type_id::create("seq");
    seq.start(env.agt.sqr);
    alu_1b_lut256_seq lut = alu_1b_lut256_seq::type_id::create("lut");
    lut.n_per_opcode = 1;
    lut.start(env.agt.sqr);
    alu_1b_gp_seq gp = alu_1b_gp_seq::type_id::create("gp");
    gp.start(env.agt.sqr);
  endtask
endclass

class alu_1b_smoke_test extends alu_1b_base_test;
  `uvm_component_utils(alu_1b_smoke_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_sequence();
    alu_1b_exhaustive_seq seq = alu_1b_exhaustive_seq::type_id::create("seq");
    seq.start(env.agt.sqr);
  endtask
endclass
