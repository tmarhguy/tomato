// Virtual interfaces for ALU UVM environments
interface alu_1b_if (input bit clk);
  logic [7:0] opcode;
  logic       a, b, c;
  logic       asel, bsel, a_inv, b_inv;
  logic       mux_out, g, p;

  modport drv_mp (output opcode, a, b, c, asel, bsel, a_inv, b_inv,
                  input  mux_out, g, p);
  modport mon_mp (input  opcode, a, b, c, asel, bsel, a_inv, b_inv,
                  input  mux_out, g, p);
endinterface

interface alu_8b_if (input bit clk);
  logic [7:0] opcode;
  logic [7:0] a, b, c;
  logic       asel, ainv, bsel, binv;
  logic [7:0] out, g, p;

  modport drv_mp (output opcode, a, b, c, asel, ainv, bsel, binv,
                  input  out, g, p);
  modport mon_mp (input  opcode, a, b, c, asel, ainv, bsel, binv,
                  input  out, g, p);
endinterface

interface alu_32b_if (input bit clk);
  logic [31:0] a, b, c;
  logic [7:0]  opcode;
  logic [3:0]  control;
  logic [1:0]  csel;
  logic        flag_we;
  logic        flag_a_is_zero_n;
  logic [31:0] out;
  logic [12:0] csr_flag;

  modport drv_mp (
    output a, b, c, opcode, control, csel, flag_we, flag_a_is_zero_n,
    input  out, csr_flag
  );
  modport mon_mp (
    input  a, b, c, opcode, control, csel, flag_we, flag_a_is_zero_n,
    input  out, csr_flag
  );
  modport clk_mp (output clk);
endinterface
