/*
 * Tomato — program counter
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : pc.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * States: FETCH, EXECUTE, MEM_WAIT. cycles=1 → F+E; cycles=2 → F+E+M.
 * HALT/EBREAK sticky until reset. ECALL → trap @ 0x100 with link save.
 */
module pc (
    input         clk,
    input         rst,
    input  [1:0]  cycles,
    input  [2:0]  pc_src,
    input  [21:0] offset,
    input  [31:0] alu_in,
    input  [31:0] mem_din,
    input  [7:0]  csr_flags,
    input  [2:0]  pc_cond,
    input         jump,
    input         branch_en,
    input         link_we,
    input         halt_in,
    input         ecall_in,      // opcode ECALL @ execute
    input         int_en_in,
    input         int_req,
    input         int_vec0,
    input         int_vec1,
    input         int_vec2,
    output reg [23:0] pc,
    output     [23:0] pc_next,   // fall-through (link / JAL rd)
    output reg [23:0] pc_link,
    output            fetch,
    output            execute,
    output            halted_o
);
    localparam [23:0] ECALL_VEC = 24'h000100;

    reg [1:0] seq;
    reg       halted, int_en, int_gate_d;

    wire [23:0] pc_p1     = pc + 24'd1;
    wire [23:0] abs_addr  = {2'b0, offset};
    wire [23:0] rel_addr  = pc + {{2{offset[21]}}, offset};
    wire [23:0] int_vec   = {18'b0, int_vec2, int_vec1, int_vec0, 3'b0};

    wire cond     = csr_flags[pc_cond];
    wire take_br  = jump | (branch_en & cond) | ecall_in;
    wire irq      = int_req & int_en;

    assign fetch    = (seq == 2'd0);
    assign execute  = (seq == 2'd1);
    assign halted_o = halted;
    // After fetch edge advanced PC, `pc` is the fall-through of the executing insn.
    assign pc_next = pc;

    reg [23:0] target;
    always @(*) begin
        if (irq)
            target = int_vec;
        else if (fetch)
            target = pc_p1;
        else if (ecall_in)
            target = ECALL_VEC;
        else begin
            case (pc_src)
                3'd0: target = abs_addr;
                3'd1: target = rel_addr;
                3'd2: target = pc_link;
                3'd3: target = int_vec;
                3'd4: target = alu_in[23:0];
                3'd5: target = mem_din[23:0];
                3'd7: target = pc_p1;
                default: target = pc_p1;
            endcase
        end
    end

    wire pc_en = rst | (!halted & (fetch | irq | (execute & take_br)));
    wire link_en = rst | (!halted & (
        (execute & (link_we | ecall_in)) |
        (fetch & irq & ~int_gate_d)
    ));

    always @(posedge clk) begin
        if (rst) begin
            seq        <= 2'd0;
            pc         <= 24'd0;
            pc_link    <= 24'd0;
            halted     <= 1'b0;
            int_en     <= 1'b0;
            int_gate_d <= 1'b0;
        end else begin
            halted     <= halted | halt_in; // sticky until reset
            int_en     <= int_en_in;
            int_gate_d <= irq;

            if (!halted) begin
                if (seq == cycles) seq <= 2'd0;
                else               seq <= seq + 2'd1;
            end

            if (pc_en)   pc      <= rst ? 24'd0 : target;
            if (link_en) pc_link <= rst ? 24'd0 : pc;
        end
    end
endmodule