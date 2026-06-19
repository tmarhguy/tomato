// Shared types for ALU UVM verification
package alu_types_pkg;

  localparam int WIDTH_1B  = 1;
  localparam int WIDTH_8B  = 8;
  localparam int WIDTH_32B = 32;

  // CSR_FLAG bit map (alu-32b-final)
  localparam int FLAG_Z   = 0;
  localparam int FLAG_ZB  = 1;
  localparam int FLAG_N   = 2;
  localparam int FLAG_NB  = 3;
  localparam int FLAG_C   = 4;
  localparam int FLAG_CB  = 5;
  localparam int FLAG_V   = 6;
  localparam int FLAG_VB  = 7;
  localparam int FLAG_LT  = 8;
  localparam int FLAG_LTE = 9;
  localparam int FLAG_GT  = 10;
  localparam int FLAG_GTE = 11;
  localparam int FLAG_AZ  = 12;

  typedef struct packed {
    bit [7:0]  opcode;
    bit        asel;
    bit        ainv;
    bit        bsel;
    bit        binv;
    bit [31:0] a;
    bit [31:0] b;
    bit [31:0] c;
    bit [1:0]  csel;
    bit        clk;
    bit        flag_we;
    bit        flag_a_is_zero_n;
  } alu_32b_txn_t;

  typedef struct packed {
    bit [31:0] out;
    bit [12:0] csr_flag;
  } alu_32b_result_t;

  typedef struct packed {
    bit [7:0] opcode;
    bit       asel;
    bit       ainv;
    bit       bsel;
    bit       binv;
    bit [7:0] a;
    bit [7:0] b;
    bit [7:0] c;
  } alu_8b_txn_t;

  typedef struct packed {
    bit [7:0] out;
    bit [7:0] g;
    bit [7:0] p;
  } alu_8b_result_t;

  typedef struct packed {
    bit [7:0] opcode;
    bit       asel;
    bit       ainv;
    bit       bsel;
    bit       binv;
    bit       a;
    bit       b;
    bit       c;
  } alu_1b_txn_t;

  typedef struct packed {
    bit mux_out;
    bit g;
    bit p;
  } alu_1b_result_t;

endpackage
