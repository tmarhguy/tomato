// Exhaustive ALU encoding verification — canonical encodings from isa/docs/alu/alu-32b/opcode_table.csv
`timescale 1ns/1ps

module alu_32b_final_exhaustive_tb;
  reg [31:0] A, B, REG_C;
  reg [7:0] Opcode;
  reg [4:0] control;
  reg \cin-sel , FLAG_C, nz0;
  wire [31:0] Out;
  wire cout, vout, zout, nzout, nout;

  \alu-32b-final dut (
    .A(A), .B(B), .REG_C(REG_C), .Opcode(Opcode), .control(control),
    .\cin-sel (\cin-sel ), .FLAG_C(FLAG_C), .nz0(nz0),
    .Out(Out), .cout(cout), .vout(vout), .zout(zout), .nzout(nzout), .nout(nout)
  );

  integer pass, fail;

  task check;
    input [255:0] name;
    input [31:0] exp;
    begin
      if (Out !== exp) begin
        $display("FAIL %s: got %h exp %h (ctrl=%b op=%h cin=%b FC=%b)", name, Out, exp, control, Opcode, \cin-sel , FLAG_C);
        fail = fail + 1;
      end else
        pass = pass + 1;
    end
  endtask

  initial begin
    pass = 0; fail = 0;
    nz0 = 0; REG_C = 0; FLAG_C = 0;

    // --- Arithmetic (opcode 0x96) ---
    Opcode = 8'h96;

    A = 32'd5; B = 32'd3;
    control = 5'b00101; \cin-sel  = 0; FLAG_C = 0; #1;
    check("ADD", 32'd8);

    control = 5'b01101; \cin-sel  = 1; #1;
    check("SUB", 32'd2);

    A = 32'd8; B = 32'd3;
    control = 5'b01101; \cin-sel  = 1; #1;
    check("SUB 8-3", 32'd5);

    A = 32'd10; B = 0;
    control = 5'b00001; \cin-sel  = 1; #1;
    check("INC A", 32'd11);

    A = 32'd10; B = 0;
    control = 5'b01001; \cin-sel  = 0; #1;
    check("DEC A", 32'd9);

    A = 32'd5; B = 0;
    control = 5'b00011; \cin-sel  = 1; #1;
    check("NEG A", 32'hFFFFFFFB);

    A = 32'd3; B = 32'd8;
    control = 5'b00111; \cin-sel  = 1; #1;
    check("RSB B-A", 32'd5);

    A = 32'hFFFFFFFF; B = 32'd1;
    control = 5'b00101; \cin-sel  = 0; FLAG_C = 0; #1;
    check("ADD wrap", 32'd0);

  // --- Two-variable logic (control 00101) ---
    control = 5'b00101; \cin-sel  = 0;
    A = 32'hFF00FF00; B = 32'h0F0F0F0F;

    Opcode = 8'hC0; #1; check("AND", 32'h0F000F00);
    Opcode = 8'hFC; #1; check("OR",  32'hFF0FFF0F);
    Opcode = 8'h3C; #1; check("XOR", 32'hF00FF00F);
    Opcode = 8'hC3; #1; check("XNOR",32'h0FF00FF0);
    Opcode = 8'h03; #1; check("NOR", 32'h00F000F0);
    Opcode = 8'h3F; #1; check("NAND",32'hF0FFF0FF);

    Opcode = 8'hF0; A = 32'hDEADBEEF; B = 0; #1;
    check("PASS A", 32'hDEADBEEF);

    control = 5'b00100; Opcode = 8'hCC; B = 32'h12345678; A = 0; #1;
    check("PASS B", 32'h12345678);

    control = 5'b01100; Opcode = 8'hCC; A = 0; B = 32'h12345678; #1;
    check("NOT B", 32'hEDCBA987);

    control = 5'b00011; Opcode = 8'hF0; A = 32'h00000000; B = 0; #1;
    check("NOT A", 32'hFFFFFFFF);

  // --- REG_C / 3-var (control 10101) ---
    control = 5'b10101;
    REG_C = 32'hAAAAAAAA;
    Opcode = 8'hAA; A = 0; B = 0; \cin-sel  = 0; #1;
    check("PASS C", 32'hAAAAAAAA);

    Opcode = 8'h55; #1;
    check("NOT C", 32'h55555555);

    A = 32'hFFFFFFFF; B = 0;
    Opcode = 8'hA0; #1;
    check("A AND C", 32'hAAAAAAAA);

    #10;
    if (fail == 0)
      $display("PASS: all %0d checks ok", pass);
    else
      $display("FAIL: %0d failed, %0d passed", fail, pass);
    $finish;
  end
endmodule
