class alu_1b_exhaustive_seq extends uvm_sequence #(alu_1b_seq_item);
  `uvm_object_utils(alu_1b_exhaustive_seq)

  function new(string name = "alu_1b_exhaustive_seq");
    super.new(name);
  endfunction

  task body();
    // 128-row exhaustive table for opcode 0x96 (Digital Arithmetic Tests)
    for (int i = 0; i < 128; i++) begin
      alu_1b_seq_item item = alu_1b_seq_item::type_id::create("item");
      item.opcode = 8'h96;
      item.asel   = i[6];
      item.a_inv  = i[5];
      item.bsel   = i[4];
      item.b_inv  = i[3];
      item.a      = i[2];
      item.b      = i[1];
      item.c      = i[0];
      start_item(item);
      finish_item(item);
    end
  endtask
endclass

class alu_1b_lut256_seq extends uvm_sequence #(alu_1b_seq_item);
  `uvm_object_utils(alu_1b_lut256_seq)
  int unsigned n_per_opcode = 4;

  function new(string name = "alu_1b_lut256_seq");
    super.new(name);
  endfunction

  task body();
    for (int op = 0; op < 256; op++) begin
      repeat (n_per_opcode) begin
        alu_1b_seq_item item = alu_1b_seq_item::type_id::create("item");
        void'(item.randomize() with { opcode == op; });
        start_item(item);
        finish_item(item);
      end
    end
  endtask
endclass

class alu_1b_random_seq extends uvm_sequence #(alu_1b_seq_item);
  `uvm_object_utils(alu_1b_random_seq)
  rand int unsigned count;
  constraint c_count { count inside {[100:10000]}; }

  function new(string name = "alu_1b_random_seq");
    super.new(name);
    count = 1000;
  endfunction

  task body();
    repeat (count) begin
      alu_1b_seq_item item = alu_1b_seq_item::type_id::create("item");
      void'(item.randomize());
      start_item(item);
      finish_item(item);
    end
  endtask
endclass

class alu_1b_gp_seq extends uvm_sequence #(alu_1b_seq_item);
  `uvm_object_utils(alu_1b_gp_seq)

  function new(string name = "alu_1b_gp_seq");
    super.new(name);
  endfunction

  task body();
    // G/P corner: both inputs high, both low, propagate-only
    bit [3:0] patterns[4] = '{4'b1111, 4'b0000, 4'b1010, 4'b0101};
    foreach (patterns[i]) begin
      alu_1b_seq_item item = alu_1b_seq_item::type_id::create("item");
      item.opcode = 8'h96;
      item.asel   = 1; item.bsel = 1;
      item.a_inv  = 0; item.b_inv = 0;
      item.a      = patterns[i][1];
      item.b      = patterns[i][0];
      item.c      = patterns[i][2];
      start_item(item);
      finish_item(item);
    end
  endtask
endclass
