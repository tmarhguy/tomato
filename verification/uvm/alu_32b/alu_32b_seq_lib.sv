class alu_32b_ops91_seq extends uvm_sequence #(alu_32b_seq_item);
  `uvm_object_utils(alu_32b_ops91_seq)
  function new(string name = "alu_32b_ops91_seq"); super.new(name); endfunction
  task body();
    for (int i = 0; i < NUM_OPS; i++) begin
      alu_32b_seq_item item = alu_32b_seq_item::type_id::create("item");
      void'(item.randomize() with {
        opcode  == OP_TABLE[i].lut;
        control == OP_TABLE[i].ctrl;
        csel    == OP_TABLE[i].csel;
        flag_we == 0;
      });
      if (OP_TABLE[i].cin_fixed >= 0)
        item.c[0] = OP_TABLE[i].cin_fixed[0];
      start_item(item); finish_item(item);
    end
  endtask
endclass

class alu_32b_random_seq extends uvm_sequence #(alu_32b_seq_item);
  `uvm_object_utils(alu_32b_random_seq)
  int unsigned count = 1000;
  function new(string name = "alu_32b_random_seq"); super.new(name); endfunction
  task body();
    repeat (count) begin
      alu_32b_seq_item item = alu_32b_seq_item::type_id::create("item");
      void'(item.randomize());
      start_item(item); finish_item(item);
    end
  endtask
endclass

class alu_32b_edge_seq extends uvm_sequence #(alu_32b_seq_item);
  `uvm_object_utils(alu_32b_edge_seq)
  function new(string name = "alu_32b_edge_seq"); super.new(name); endfunction
  task body();
    bit [31:0] apat[8] = '{
      32'h00000000, 32'hFFFFFFFF, 32'h7FFFFFFF, 32'h80000000,
      32'hDEADBEEF, 32'hAAAAAAAA, 32'h55555555, 32'h00000001
    };
    foreach (apat[i]) begin
      alu_32b_seq_item item = alu_32b_seq_item::type_id::create("item");
      item.a = apat[i]; item.b = apat[7-i];
      item.c = 32'h0;
      item.opcode = 8'h96; item.control = 4'h5; item.csel = 0;
      item.flag_we = 0;
      start_item(item); finish_item(item);
      item = alu_32b_seq_item::type_id::create("item2");
      item.a = apat[i]; item.b = apat[7-i];
      item.c = 32'h0;
      item.opcode = 8'h96; item.control = 4'hD; item.csel = 1;
      item.c[0] = 1;
      item.flag_we = 1;
      start_item(item); finish_item(item);
    end
  endtask
endclass

class alu_32b_flag_seq extends uvm_sequence #(alu_32b_seq_item);
  `uvm_object_utils(alu_32b_flag_seq)
  int unsigned count = 100;
  function new(string name = "alu_32b_flag_seq"); super.new(name); endfunction
  task body();
    repeat (count) begin
      alu_32b_seq_item item = alu_32b_seq_item::type_id::create("item");
      void'(item.randomize() with {
        opcode == 8'h96;
        control == 4'hD;
        csel == 1;
        flag_we == 1;
      });
      start_item(item); finish_item(item);
    end
  endtask
endclass

// Replay all Digital directed vectors (476 total from 3 exported TBs)
class alu_32b_directed_seq extends uvm_sequence #(alu_32b_seq_item);
  `uvm_object_utils(alu_32b_directed_seq)
  bit use_smoke_only;

  function new(string name = "alu_32b_directed_seq"); super.new(name); endfunction

  task body();
    int unsigned n = use_smoke_only ? 12 : NUM_DIRECTED_VECTORS;
    if (n > NUM_DIRECTED_VECTORS) n = NUM_DIRECTED_VECTORS;
    for (int i = 0; i < n; i++) begin
      alu_32b_seq_item item = alu_32b_seq_item::type_id::create($sformatf("item%0d", i));
      bit [143:0] p = VECTORS[i];
      item.a      = p[143:112];
      item.b      = p[111:80];
      item.c      = p[79:48];
      item.opcode = p[47:40];
      item.control= p[39:36];
      item.csel   = p[35:34];
      item.flag_we= p[32];
      item.flag_a_is_zero_n = 1;
      start_item(item); finish_item(item);
    end
    `uvm_info("DIRECTED", $sformatf("Replayed %0d directed vectors", n), UVM_LOW)
  endtask
endclass

class alu_32b_smoke_directed_seq extends alu_32b_directed_seq;
  `uvm_object_utils(alu_32b_smoke_directed_seq)
  function new(string name = "alu_32b_smoke_directed_seq"); super.new(name); use_smoke_only = 1; endfunction
endclass
