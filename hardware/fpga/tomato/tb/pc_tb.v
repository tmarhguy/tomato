/*
 * Tomato — program counter testbench
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : pc_tb.v
 * Target   : simulation (compile with rtl/pc.v)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */
`timescale 1ns/1ps
module pc_tb;
    reg         clk, rst;
    reg  [1:0]  cycles;
    reg  [2:0]  pc_src, pc_cond;
    reg  [21:0] offset;
    reg  [31:0] alu_in, mem_din;
    reg  [7:0]  csr_flags;
    reg         jump, branch_en, link_we, halt_in, ecall_in;
    reg         int_en_in, int_req, int_vec0, int_vec1, int_vec2;
    wire [23:0] pc, pc_next, pc_link;
    wire        fetch, execute;

    pc uut (
        .clk(clk), .rst(rst), .cycles(cycles), .pc_src(pc_src),
        .offset(offset), .alu_in(alu_in), .mem_din(mem_din),
        .csr_flags(csr_flags), .pc_cond(pc_cond), .jump(jump),
        .branch_en(branch_en), .link_we(link_we), .halt_in(halt_in),
        .ecall_in(ecall_in),
        .int_en_in(int_en_in), .int_req(int_req),
        .int_vec0(int_vec0), .int_vec1(int_vec1), .int_vec2(int_vec2),
        .pc(pc), .pc_next(pc_next), .pc_link(pc_link),
        .fetch(fetch), .execute(execute)
    );

    always #5 clk = ~clk;

    task tick; begin @(posedge clk); #1; end endtask

    task clear_ctrl;
        begin
            cycles = 2'd1; pc_src = 3'd7; offset = 0;
            alu_in = 0; mem_din = 0; csr_flags = 0; pc_cond = 0;
            jump = 0; branch_en = 0; link_we = 0; halt_in = 0; ecall_in = 0;
            int_en_in = 0; int_req = 0;
            int_vec0 = 1; int_vec1 = 1; int_vec2 = 1;
        end
    endtask

    initial begin
        clk = 0; rst = 1; clear_ctrl();
        tick; tick;
        rst = 0;
        #1;
        if (pc !== 0 || !fetch || execute) begin
            $display("FAIL: reset state pc=%h f=%b e=%b", pc, fetch, execute);
            $finish(1);
        end

        // F→E: fetch edge advances PC
        tick;
        if (!execute || pc !== 24'd1) begin
            $display("FAIL: execute pc=%h f=%b e=%b", pc, fetch, execute);
            $finish(1);
        end
        tick; // back to fetch, pc stays 1
        if (!fetch || pc !== 24'd1) begin
            $display("FAIL: wrap pc=%h", pc);
            $finish(1);
        end

        // Abs jump: assert jump before entering execute
        jump = 1; pc_src = 3'd0; offset = 22'h00_1000;
        tick; // → execute; fetch also bumped pc to 2 this edge...
        // On that edge fetch was true so pc<=pc+1 first; jump applies same edge?
        // pc_en = fetch | (execute & take_br). At edge seq still FETCH, so target=pc_p1.
        // Jump does not win on fetch edge. Now in execute with pc=2.
        tick; // execute + jump → 0x1000
        if (pc !== 24'h00_1000) begin
            $display("FAIL: abs jump pc=%h", pc);
            $finish(1);
        end
        jump = 0; pc_src = 3'd7;

        // Rel branch from execute
        if (!fetch) tick;
        // fetch @ 0x1000
        branch_en = 1; pc_cond = 3'd0; csr_flags = 8'h01;
        pc_src = 3'd1; offset = 22'd4;
        tick; // → execute, pc=0x1001
        tick; // branch: 0x1001+4
        if (pc !== 24'h00_1005) begin
            $display("FAIL: rel branch pc=%h", pc);
            $finish(1);
        end
        branch_en = 0; csr_flags = 0; pc_src = 3'd7;

        // Link: during execute pc already advanced past call → save `pc` (fall-through)
        if (!fetch) tick;
        link_we = 1;
        tick; // → execute, pc=0x1006
        tick; // link stores pc (= fall-through)
        if (pc_link !== 24'h00_1006) begin
            $display("FAIL: link pc_link=%h (want 1006)", pc_link);
            $finish(1);
        end
        link_we = 0;

        // Halt freeze (sticky — stays after halt_in drops)
        if (!fetch) tick;
        halt_in = 1;
        tick;
        begin : hf
            reg [23:0] p0;
            p0 = pc;
            halt_in = 0;
            tick; tick; tick;
            if (pc !== p0) begin
                $display("FAIL: halt pc=%h", pc);
                $finish(1);
            end
            if (!uut.halted) begin
                $display("FAIL: halt not sticky");
                $finish(1);
            end
        end

        // Reset
        rst = 1; tick; rst = 0; #1;
        if (pc !== 0 || !fetch) begin
            $display("FAIL: reset clear");
            $finish(1);
        end

        // cycles=2: F E M F
        cycles = 2'd2;
        tick;
        if (!execute) begin $display("FAIL: c2 exec"); $finish(1); end
        tick;
        if (fetch || execute) begin
            $display("FAIL: c2 memwait"); $finish(1);
        end
        tick;
        if (!fetch) begin $display("FAIL: c2 wrap"); $finish(1); end

        // IRQ
        clear_ctrl();
        rst = 1; tick; rst = 0; #1;
        int_en_in = 1;
        tick; // latch int_en; may leave fetch
        while (!fetch) tick;
        int_req = 1;
        tick;
        if (pc !== 24'h000038) begin
            $display("FAIL: irq pc=%h", pc);
            $finish(1);
        end

        // ECALL → 0x100 + link (assert ecall during fetch, then enter execute)
        clear_ctrl();
        rst = 1; tick; rst = 0; #1;
        while (!fetch) tick;
        ecall_in = 1;
        tick; // fetch edge: PC may +1; seq→exec — ecall not yet (still fetch when evaluated)
        // On that edge seq was fetch, so ecall in target mux was ignored (fetch branch).
        // Now in execute with ecall_in still 1:
        if (!execute) begin $display("FAIL: ecall expect exec"); $finish(1); end
        tick; // execute + ecall → 0x100
        if (pc !== 24'h000100) begin
            $display("FAIL: ecall vec pc=%h", pc);
            $finish(1);
        end
        ecall_in = 0;

        $display("PASS: pc");
        $finish;
    end
endmodule
