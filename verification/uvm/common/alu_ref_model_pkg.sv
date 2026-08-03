// Behavioral reference model for Tomato 32-bit ALU (matches formal bind properties)
package alu_ref_model_pkg;
  import alu_types_pkg::*;
  import alu_op_table_pkg::*;

  class alu_ref_model;

    static function bit eff1(input bit sel, input bit inv, input bit val);
      return ((sel & val) ^ inv);
    endfunction

    static function bit [31:0] a_eff32(input bit asel, input bit ainv, input bit [31:0] a);
      bit [31:0] r;
      for (int i = 0; i < 32; i++)
        r[i] = eff1(asel, ainv, a[i]);
      return r;
    endfunction

    static function bit [31:0] b_eff32(input bit bsel, input bit binv, input bit [31:0] b);
      bit [31:0] r;
      for (int i = 0; i < 32; i++)
        r[i] = eff1(bsel, binv, b[i]);
      return r;
    endfunction

    static function bit lut3_bit(input bit [7:0] op, input bit a, input bit b, input bit c);
      return op[{c, b, a}];
    endfunction

    static function bit [31:0] lut3_vec(
      input bit [7:0] opcode,
      input bit [31:0] a_eff,
      input bit [31:0] b_eff,
      input bit [31:0] c
    );
      bit [31:0] out;
      for (int i = 0; i < 32; i++)
        out[i] = lut3_bit(opcode, a_eff[i], b_eff[i], c[i]);
      return out;
    endfunction

    static function bit [31:0] predict_out(
      input bit [31:0] a,
      input bit [31:0] b,
      input bit [31:0] c,
      input bit [7:0]  opcode,
      input bit [3:0]  control,
      input bit [1:0]  csel,
      input bit        flag_c = 0
    );
      bit [31:0] a_e = a_eff32(control[0], control[1], a);
      bit [31:0] b_e = b_eff32(control[2], control[3], b);
      bit [31:0] out;
      bit        carry;
      out = 0;
      carry = 0;
      for (int i = 0; i < 32; i++) begin
        bit ai = a_e[i];
        bit bi = b_e[i];
        bit cin;
        if (i == 0)
          case (csel)
            2'b00: cin = 0;
            2'b01: cin = 1;
            2'b10: cin = flag_c;
            2'b11: cin = c[0];
            default: cin = 0;
          endcase
        else
          cin = (csel == 2'b11) ? c[i] : carry;
        out[i] = lut3_bit(opcode, ai, bi, cin);
        carry = (ai & bi) | ((ai ^ bi) & cin);
      end
      return out;
    endfunction

    // Match DUT when internal Flag_C is unknown: accept either rail at csel==2'b10
    static function bit [31:0] predict_out_dut(
      input bit [31:0] a,
      input bit [31:0] b,
      input bit [31:0] c,
      input bit [7:0]  opcode,
      input bit [3:0]  control,
      input bit [1:0]  csel,
      input bit [31:0] out
    );
      bit [31:0] e0 = predict_out(a, b, c, opcode, control, csel, 0);
      if (out === e0) return e0;
      if (csel == 2'b10) begin
        bit [31:0] e1 = predict_out(a, b, c, opcode, control, csel, 1);
        if (out === e1) return e1;
      end
      return e0;
    endfunction

    static function bit [31:0] predict_out_op(
      input bit [31:0] a,
      input bit [31:0] b,
      input bit [31:0] c,
      input alu_op_entry_t op,
      input bit cin_override = 0
    );
      bit cin;
      if (op.cin_fixed >= 0)
        cin = op.cin_fixed[0];
      else
        cin = c[0];
      return predict_out(a, b, {31'b0, cin}, op.lut, op.ctrl, op.csel, 0);
    endfunction

    // 1-bit slice
    static function bit predict_mux_1b(alu_1b_txn_t t);
      bit a_e = eff1(t.asel, t.ainv, t.a);
      bit b_e = eff1(t.bsel, t.binv, t.b);
      return lut3_bit(t.opcode, a_e, b_e, t.c);
    endfunction

    static function void predict_gp_1b(
      input alu_1b_txn_t t,
      output bit g,
      output bit p
    );
      bit a_e = eff1(t.asel, t.ainv, t.a);
      bit b_e = eff1(t.bsel, t.binv, t.b);
      g = a_e & b_e;
      p = a_e ^ b_e;
    endfunction

    // 8-bit slice
    static function bit [7:0] predict_out_8b(alu_8b_txn_t t);
      bit [7:0] out;
      for (int i = 0; i < 8; i++) begin
        alu_1b_txn_t s;
        s.opcode = t.opcode;
        s.asel   = t.asel;
        s.ainv   = t.ainv;
        s.bsel   = t.bsel;
        s.binv   = t.binv;
        s.a      = t.a[i];
        s.b      = t.b[i];
        s.c      = t.c[i];
        out[i]   = predict_mux_1b(s);
      end
      return out;
    endfunction

    static function void predict_gp_8b(
      input alu_8b_txn_t t,
      output bit [7:0] g,
      output bit [7:0] p
    );
      for (int i = 0; i < 8; i++) begin
        alu_1b_txn_t s;
        bit gi, pi;
        s.opcode = t.opcode;
        s.asel   = t.asel;
        s.ainv   = t.ainv;
        s.bsel   = t.bsel;
        s.binv   = t.binv;
        s.a      = t.a[i];
        s.b      = t.b[i];
        s.c      = t.c[i];
        predict_gp_1b(s, gi, pi);
        g[i] = gi;
        p[i] = pi;
      end
    endfunction

    // Dual-rail CSR_FLAG: [1]=~Z (1 when Out==0), [0]=Z, [2]=N, [3]=~N
    static function bit [12:0] predict_csr_flag(
      input bit [31:0] out,
      input bit [31:0] a,
      input bit [31:0] b,
      input bit [3:0]  control,
      input bit        flag_a_is_zero_n
    );
      bit [31:0] a_e = a_eff32(control[0], control[1], a);
      bit [31:0] b_e = b_eff32(control[2], control[3], b);
      bit [32:0] sum = {1'b0, a_e} + {1'b0, b_e} + 33'd0;
      bit is_zero = (out == 32'h0);
      bit n       = out[31];
      bit c       = sum[32];
      bit v       = (a_e[31] == b_e[31]) && (out[31] != a_e[31]);
      bit lt      = ($signed(a) < $signed(b));
      bit gt      = ($signed(a) > $signed(b));
      bit lte     = is_zero | lt;
      bit gte     = ~lt;
      predict_csr_flag = {
        flag_a_is_zero_n,
        gte, gt, lte, lt,
        ~v, v, ~c, c, ~n, n, ~is_zero, is_zero
      };
    endfunction

  endclass

endpackage
