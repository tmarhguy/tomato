module mosaic32_top (
    input clk,
    input reset_n,       // Active-low reset
    input [31:0] mem_din, // Data from memory
    output [31:0] mem_dout, // Data to memory
    output [23:0] mem_addr, // Memory address
    output mem_rd_out,
    output mem_wr
);

// -------------------------------------------------------------------------
// internal wiring
// -------------------------------------------------------------------------

// Instruction Register
wire [31:0] ir_bus;
wire [7:0] ir_opcode, ir_addr_a, ir_addr_b, ir_addr_w;
wire [23:0] ir_addr_abs, ir_offset;

// Microcode
wire ctrl_mem_rd;
wire [7:0] ctrl_alu_op;
wire [4:0] ctrl_alu_pre;
wire ctrl_cin_sel;
wire [1:0] ctrl_wb_sel, ctrl_shift_op;
wire ctrl_flags_we, ctrl_reg_we;
wire ctrl_addr_csel;
wire ctrl_branch_en, ctrl_jump_type;
wire [1:0] ctrl_sp_op, ctrl_cycles;
wire [2:0] ctrl_unused;

// Sequencer
wire seq_fetch, seq_execute, seq_mem_wait;

// PC Subsystem
wire [23:0] pc_out, sp_out, pc_save;
wire pc_halted, pc_int_ack, pc_int_en;
wire [3:0] pc_flags_save;

// Register File
wire [31:0] reg_a, reg_b, reg_c;
reg [31:0] reg_w_data;
wire [7:0] reg_addr_c;

// ALU
wire [31:0] alu_out;
wire alu_vout, alu_zout, alu_nzout, alu_nout, alu_cout;
wire [31:0] alu_c_bus;

// Flag Register
wire flag_z, flag_c, flag_n, flag_v;

// Shifter
wire [31:0] shift_out;

// -------------------------------------------------------------------------
// Sub-module Instantiation
// -------------------------------------------------------------------------

// 1. Sequencer
// Invert the clock to the sequencer so it updates on the falling edge.
// This prevents the clock-gating AND gate in ir.v from glitching and corrupting the instruction register.
sequencer seq_inst (
    .reset(~reset_n),
    .cycles(ctrl_cycles),
    .CLK(~clk),
    .FETCH(seq_fetch),
    .EXECUTE(seq_execute),
    .MEM_WAIT(seq_mem_wait)
);

// 2. Instruction Register
ir ir_inst (
    .CLK(clk),
    .LOAD(seq_fetch),
    .DATA_IN(mem_din),
    .OPCODE(ir_opcode),
    .ADDR_A(ir_addr_a),
    .ADDR_B(ir_addr_b),
    .ADDR_W(ir_addr_w),
    .ADDR_ABS(ir_addr_abs),
    .OFFSET(ir_offset),
    .IR_BUS(ir_bus)
);

// 3. Microcode ROM (Static Decode based on Opcode)
microcode ucode_inst (
    .op(ir_opcode),
    .\alu-op (ctrl_alu_op),
    .\alu-pre (ctrl_alu_pre),
    .\cin-sel (ctrl_cin_sel),
    .\wb-sel (ctrl_wb_sel),
    .\shift-op (ctrl_shift_op),
    .\flags-we (ctrl_flags_we),
    .\reg-we (ctrl_reg_we),
    .\mem-rd (ctrl_mem_rd),
    .\mem-wr (mem_wr),
    .\addr-csel (ctrl_addr_csel),
    .\branch-en (ctrl_branch_en),
    .\jump-type (ctrl_jump_type),
    .\sp-op (ctrl_sp_op),
    .cycles(ctrl_cycles),
    .unused(ctrl_unused)
);

// 4. Program Counter
pc pc_inst (
    .CLK(clk),
    .\~SR (reset_n),
    .\pc-en (seq_fetch),
    .ADDR_ABS(ir_addr_abs),
    .OFFSET(ir_offset),
    .ADDR_RET(24'd0),   // Tie off for now
    .MUX1_SEL(ctrl_jump_type),
    .MUX2_SEL(1'b0),    // Tie off RET for now
    .FLAG_N(flag_n),
    .FLAG_C(flag_c),
    .FLAG_Z(flag_z),
    .FLAG_O(flag_v),
    .COND(ir_bus[2:0]), // The lowest 3 bits of Instruction contain the COND code
    .BRANCH_EN(ctrl_branch_en),
    .INT_EN_IN(1'b0),
    .HALT_IN(1'b0),
    .INT_REQ(1'b0),
    .INT_VEC_0(1'b0),
    .INT_VEC_1(1'b0),
    .INT_VEC_2(1'b0),
    .SP_DELTA(24'd0),
    .SP_LOAD_N(1'b1),
    .JUMP_UNCOND(1'b0),
    .INT_EN(pc_int_en),
    .HALTED(pc_halted),
    .PC_OUT(pc_out),
    .SP_OUT(sp_out),
    .INT_ACK(pc_int_ack),
    .FLAGS_SAVE(pc_flags_save),
    .PC_SAVE(pc_save)
);

// 5. Bus Arbitration
// The digital schematic was wired backwards (it routed IR_ADDR when FETCH=1).
// We invert seq_fetch here to correctly route PC_OUT during FETCH=1.
\bus-arbitration  bus_arb_inst (
    .FETCH(~seq_fetch),
    .PC_OUT(pc_out),
    .IR_ADDR(ir_bus[23:0]), // IR Address for memory access
    .ADDR_BUS(mem_addr)
);

// 6. Register File
assign reg_addr_c = ctrl_addr_csel ? ir_bus[23:16] : 8'd0; // Example static routing for port C
wire actual_reg_we = ctrl_reg_we & seq_execute; // Only write back on EXECUTE phase

register regfile_inst (
    .WE(actual_reg_we),
    .DATA_W(reg_w_data),
    .ADDR_A(ir_addr_a),
    .ADDR_B(ir_addr_b),
    .ADDR_C(reg_addr_c),
    .ADDR_W(ir_addr_w),
    .clock(clk),
    .DATA_A(reg_a),
    .DATA_B(reg_b),
    .DATA_C(reg_c)
);

// 7. ALU
// Multiplexer for C Bus (incorporates cin hack)
assign alu_c_bus = (ctrl_alu_pre[4] == 1'b1) ? reg_c :                     // Logic Mode (csel=1): Pass C Vector
                   (ctrl_cin_sel == 1'b1)    ? {31'd0, 1'b1} :             // Forced Carry (Subtraction)
                                               {31'd0, flag_c};            // Normal Carry Chain

\alu-32b-final  alu_inst (
    .A(reg_a),
    .nz0(1'b0), // Tied to 0 (lowest ripple block)
    .B(reg_b),
    .C(alu_c_bus),
    .Opcode(ctrl_alu_op),
    .control(ctrl_alu_pre),
    .vout(alu_vout),
    .zout(alu_zout),
    .nzout(alu_nzout),
    .nout(alu_nout),
    .Out(alu_out),
    .cout(alu_cout)
);

// 8. Flag Register
wire actual_flag_we = ctrl_flags_we & seq_execute;
\flag-reg  flag_reg_inst (
    .ZERO_IN(alu_zout),
    .CARRY_IN(alu_cout),
    .NEGATIVE_IN(alu_nout),
    .OVERFLOW_IN(alu_vout),
    .FLAG_WE(actual_flag_we),
    .CLK(clk),
    .FLAG_Z(flag_z),
    .FLAG_C(flag_c),
    .FLAG_N(flag_n),
    .FLAG_O(flag_v)
);

// 9. Barrel Shifter
shift shift_inst (
    .A(reg_a),
    .mode(ctrl_shift_op),
    .B(reg_b[4:0]),
    .Out(shift_out)
);

// 10. Write-Back Multiplexer (Glue logic)
always @(*) begin
    case (ctrl_wb_sel)
        2'b00: reg_w_data = alu_out;
        2'b01: reg_w_data = shift_out;
        2'b10: reg_w_data = mem_din; // Memory Read Data
        2'b11: reg_w_data = {8'd0, pc_save};
    endcase
end

// Route register A to memory data in (for Store instructions)
assign mem_dout = reg_a;

// Force Memory Read during FETCH phase
assign mem_rd_out = ctrl_mem_rd | seq_fetch;

endmodule
