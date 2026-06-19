class alu_32b_base_test extends uvm_test;
  `uvm_component_utils(alu_32b_base_test)
  alu_32b_env env;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = alu_32b_env::type_id::create("env", this);
  endfunction
  virtual task run_sequences();
    alu_32b_random_seq r = alu_32b_random_seq::type_id::create("r");
    r.count = 200;
    r.start(env.agt.sqr);
  endtask
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_sequences();
    phase.drop_objection(this);
  endtask
endclass

class alu_32b_smoke_test extends alu_32b_base_test;
  `uvm_component_utils(alu_32b_smoke_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_sequences();
    alu_32b_smoke_directed_seq d = alu_32b_smoke_directed_seq::type_id::create("d");
    d.start(env.agt.sqr);
  endtask
endclass

class alu_32b_directed_test extends alu_32b_base_test;
  `uvm_component_utils(alu_32b_directed_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_sequences();
    alu_32b_directed_seq d = alu_32b_directed_seq::type_id::create("d");
    d.start(env.agt.sqr);
    alu_32b_ops91_seq o = alu_32b_ops91_seq::type_id::create("o");
    o.start(env.agt.sqr);
  endtask
endclass

class alu_32b_ops91_test extends alu_32b_base_test;
  `uvm_component_utils(alu_32b_ops91_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_sequences();
    alu_32b_ops91_seq o = alu_32b_ops91_seq::type_id::create("o");
    o.start(env.agt.sqr);
  endtask
endclass

class alu_32b_random_test extends alu_32b_base_test;
  `uvm_component_utils(alu_32b_random_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_sequences();
    alu_32b_random_seq r = alu_32b_random_seq::type_id::create("r");
    if (!$value$plusargs("COUNT=%0d", r.count)) r.count = 5000;
    r.start(env.agt.sqr);
  endtask
endclass

class alu_32b_edge_test extends alu_32b_base_test;
  `uvm_component_utils(alu_32b_edge_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_sequences();
    alu_32b_edge_seq e = alu_32b_edge_seq::type_id::create("e");
    e.start(env.agt.sqr);
  endtask
endclass

class alu_32b_flag_test extends alu_32b_base_test;
  `uvm_component_utils(alu_32b_flag_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_sequences();
    alu_32b_flag_seq f = alu_32b_flag_seq::type_id::create("f");
    f.count = 500;
    f.start(env.agt.sqr);
  endtask
endclass

class alu_32b_full_regression_test extends alu_32b_base_test;
  `uvm_component_utils(alu_32b_full_regression_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_sequences();
    alu_32b_directed_seq d = alu_32b_directed_seq::type_id::create("d");
    d.start(env.agt.sqr);
    alu_32b_ops91_seq o = alu_32b_ops91_seq::type_id::create("o");
    o.start(env.agt.sqr);
    alu_32b_edge_seq e = alu_32b_edge_seq::type_id::create("e");
    e.start(env.agt.sqr);
    alu_32b_flag_seq f = alu_32b_flag_seq::type_id::create("f");
    f.count = 200;
    f.start(env.agt.sqr);
    alu_32b_random_seq r = alu_32b_random_seq::type_id::create("r");
    if (!$value$plusargs("COUNT=%0d", r.count)) r.count = 10000;
    r.start(env.agt.sqr);
  endtask
endclass
