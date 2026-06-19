// Bit-accurate combinational golden for alu-32b-final (unified ripple-LUT model)
// Matches exported netlist for all csel modes including carry-fed logic (csel=10).
`default_nettype none

function automatic [31:0] alu_a_eff32;
  input [31:0] a;
  input [3:0]  control;
  reg [31:0] r;
  begin
    r = ((control[0] ? a : 32'b0) ^ (control[1] ? 32'hFFFFFFFF : 32'b0));
    alu_a_eff32 = r;
  end
endfunction

function automatic [31:0] alu_b_eff32;
  input [31:0] b;
  input [3:0]  control;
  reg [31:0] r;
  begin
    r = ((control[2] ? b : 32'b0) ^ (control[3] ? 32'hFFFFFFFF : 32'b0));
    alu_b_eff32 = r;
  end
endfunction

function automatic alu_lut3_bit;
  input [7:0] opcode;
  input       a, b, c;
  begin
    alu_lut3_bit = opcode[{c, b, a}];
  end
endfunction

// csel: 00=cin0, 01=cin1, 10=flag_c@bit0+ripple, 11=C[i] per bit
function automatic [31:0] alu_predict_out;
  input [31:0] a, b, c;
  input [7:0]  opcode;
  input [3:0]  control;
  input [1:0]  csel;
  input        flag_c;
  integer i;
  reg [31:0] ae, be, out;
  reg ai, bi, cin, oi, carry, g, p;
  begin
    ae = alu_a_eff32(a, control);
    be = alu_b_eff32(b, control);
    out = 32'b0;
    carry = 1'b0;
    for (i = 0; i < 32; i = i + 1) begin
      ai = ae[i];
      bi = be[i];
      if (i == 0)
        case (csel)
          2'b00: cin = 1'b0;
          2'b01: cin = 1'b1;
          2'b10: cin = flag_c;
          2'b11: cin = c[0];
          default: cin = 1'b0;
        endcase
      else
        cin = (csel == 2'b11) ? c[i] : carry;
      oi = alu_lut3_bit(opcode, ai, bi, cin);
      out[i] = oi;
      g = ai & bi;
      p = ai ^ bi;
      carry = g | (p & cin);
    end
    alu_predict_out = out;
  end
endfunction
