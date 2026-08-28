/*
 * Tomato — keyboard / IN / OUT / MMIO pipeline enforcement
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : kb_io_tb.v
 * Target   : simulation (cwd = hardware/fpga/core)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Pipeline under test:
 *   board kb_data → lane sel=2 (IN) → reg WB
 *   board kb_data → MMIO [21:19]==111 (LW)
 *   rA → OUT @exec → io_out
 *   kb_ready → MMIO status; IRQ remains off (int_en=0)
 */
`timescale 1ns/1ps
module kb_io_tb;
    reg clk = 0;
    reg reset = 1;
    reg  [7:0] kb_data = 8'h00;
    reg        kb_ready = 1'b0;
    wire [7:0]  io_out;
    wire [31:0] disp_value;
    wire        kb_rd, halted;
    reg  [12:0] tile_raddr = 13'd0;
    wire [31:0] tile_rdata;

    always #5 clk = ~clk;

    main uut (
        .clk(clk), .reset(reset),
        .kb_data(kb_data), .kb_ready(kb_ready), .kb_rd(kb_rd),
        .io_out(io_out), .disp_value(disp_value), .halted(halted),
        .tile_rclk(clk), .tile_raddr(tile_raddr), .tile_rdata(tile_rdata)
    );

    task tick; begin @(posedge clk); #1; end endtask

    function [31:0] enc_r;
        input [8:0] op;
        input [4:0] rd, ra, rb, rc;
        input [2:0] bank;
        enc_r = {op, rd, ra, rb, rc, bank};
    endfunction

    function [31:0] enc_i;
        input [8:0]  op;
        input [4:0]  rd, ra;
        input [12:0] imm13;
        enc_i = {op, rd, ra, imm13};
    endfunction

    function [31:0] enc_lui;
        input [8:0] op;
        input [4:0] rd;
        input [14:0] imm15;
        reg [19:0] field;
        begin
            field = {rd, imm15};
            enc_lui = {op, field, 3'b000};
        end
    endfunction

    integer i, saw_halt;
    reg [23:0] pc_sample;

    task clear_cpu;
        begin
            reset = 1;
            for (i = 0; i < 256; i = i + 1) uut.regs0.mem[i] = 32'h0;
            uut.regs0.bank = 3'd0;
            for (i = 0; i < 16384; i = i + 1) uut.dmem[i] = 32'h0;
            tick; tick;
            reset = 0;
        end
    endtask

    task run_until_halt;
        input integer maxc;
        begin
            saw_halt = 0;
            for (i = 0; i < maxc; i = i + 1) begin
                tick;
                if (uut.pc0.halted) begin
                    saw_halt = 1;
                    i = maxc;
                end
            end
            if (!saw_halt) begin
                $display("FAIL: no halt pc=%h", uut.pcout);
                $finish(1);
            end
        end
    endtask

    initial begin
        // --- A: microcode decode (IN / OUT) ---
        begin : decode
            reg [3:0] bs;
            reg [2:0] wb;
            reg       we, rd, wr;
            // force decode path via hierarchical ROMs already loaded
            // Spot-check through a tiny program is stronger; also poke control modules:
        end

        // --- B: OUT then IN (opcode path) ---
        clear_cpu;
        kb_data = 8'h00;
        kb_ready = 1'b0;
        // 0: ADDI r2,r0,0x5A
        // 1: OUT r2
        // 2: IN r1          (kb still 0)
        // 3: HALT
        uut.dmem[0] = enc_i(9'h020, 5'd2, 5'd0, 13'h05A);
        uut.dmem[1] = enc_r(9'h0C9, 5'd0, 5'd2, 5'd0, 5'd0, 3'd0); // OUT rA=r2
        uut.dmem[2] = enc_r(9'h0C8, 5'd1, 5'd0, 5'd0, 5'd0, 3'd0); // IN r1
        uut.dmem[3] = enc_r(9'h0FF, 5'd0, 5'd0, 5'd0, 5'd0, 3'd0);
        run_until_halt(80);
        if (io_out !== 8'h5A) begin
            $display("FAIL: OUT io_out=%h want 5A", io_out);
            $finish(1);
        end
        if (uut.regs0.mem[1] !== 32'h0) begin
            $display("FAIL: IN with kb=0 got %h", uut.regs0.mem[1]);
            $finish(1);
        end
        if (uut.regs0.mem[2] !== 32'h5A) begin
            $display("FAIL: r2 clobbered %h", uut.regs0.mem[2]);
            $finish(1);
        end

        // --- C: live key change → IN ---
        clear_cpu;
        kb_data = 8'h41; // 'A'
        kb_ready = 1'b1;
        uut.dmem[0] = enc_r(9'h0C8, 5'd3, 5'd0, 5'd0, 5'd0, 3'd0); // IN r3
        uut.dmem[1] = enc_r(9'h0C9, 5'd0, 5'd3, 5'd0, 5'd0, 3'd0); // OUT r3 (echo)
        uut.dmem[2] = enc_r(9'h0FF, 5'd0, 5'd0, 5'd0, 5'd0, 3'd0);
        run_until_halt(60);
        if (uut.regs0.mem[3] !== 32'h41) begin
            $display("FAIL: IN 'A' got %h", uut.regs0.mem[3]);
            $finish(1);
        end
        if (io_out !== 8'h41) begin
            $display("FAIL: echo OUT %h", io_out);
            $finish(1);
        end

        // --- D: two sequential INs see key updates ---
        clear_cpu;
        kb_data = 8'h10;
        kb_ready = 1'b1;
        uut.dmem[0] = enc_r(9'h0C8, 5'd1, 5'd0, 5'd0, 5'd0, 3'd0);
        uut.dmem[1] = enc_r(9'h0C8, 5'd2, 5'd0, 5'd0, 5'd0, 3'd0);
        uut.dmem[2] = enc_r(9'h0FF, 5'd0, 5'd0, 5'd0, 5'd0, 3'd0);
        // After first IN executes, flip kb before second — racey; instead
        // step manually for precision:
        reset = 1; tick; tick; reset = 0;
        // run until after first IN: ~ few cycles then change
        // Simpler: two programs. Re-do with mid-run poke:
        for (i = 0; i < 256; i = i + 1) uut.regs0.mem[i] = 32'h0;
        for (i = 0; i < 16384; i = i + 1) uut.dmem[i] = 32'h0;
        uut.dmem[0] = enc_r(9'h0C8, 5'd1, 5'd0, 5'd0, 5'd0, 3'd0);
        uut.dmem[1] = enc_r(9'h0C8, 5'd2, 5'd0, 5'd0, 5'd0, 3'd0);
        uut.dmem[2] = enc_r(9'h0FF, 5'd0, 5'd0, 5'd0, 5'd0, 3'd0);
        kb_data = 8'h11;
        reset = 1; tick; tick; reset = 0;
        // advance until r1 written (IN done), then change kb
        saw_halt = 0;
        for (i = 0; i < 40; i = i + 1) begin
            tick;
            if (uut.regs0.mem[1] === 32'h11 && kb_data === 8'h11)
                kb_data = 8'h22;
            if (uut.pc0.halted) begin saw_halt = 1; i = 40; end
        end
        if (!saw_halt) begin $display("FAIL: seq IN no halt"); $finish(1); end
        if (uut.regs0.mem[1] !== 32'h11) begin
            $display("FAIL: first IN %h", uut.regs0.mem[1]); $finish(1);
        end
        if (uut.regs0.mem[2] !== 32'h22) begin
            $display("FAIL: second IN %h want 22 (key updated)", uut.regs0.mem[2]);
            $finish(1);
        end

        // --- E: MMIO window [21:19]==111 data + status ---
        clear_cpu;
        kb_data = 8'h7E;
        kb_ready = 1'b1;
        // LUI r7, 0x780 → low24 = 0x780000 ([21:19]=111)
        uut.dmem[0] = enc_lui(9'h024, 5'd7, 15'h780);
        uut.dmem[1] = enc_i(9'h060, 5'd1, 5'd7, 13'd0);  // LW r1, r7, 0  data
        uut.dmem[2] = enc_i(9'h060, 5'd2, 5'd7, 13'd1);  // LW r2, r7, 1  status
        uut.dmem[3] = enc_r(9'h0FF, 5'd0, 5'd0, 5'd0, 5'd0, 3'd0);
        run_until_halt(120);
        if (uut.regs0.mem[1] !== 32'h7E) begin
            $display("FAIL: MMIO data %h want 7E (r7=%h)",
                     uut.regs0.mem[1], uut.regs0.mem[7]);
            $finish(1);
        end
        if (uut.regs0.mem[2] !== 32'h1) begin
            $display("FAIL: MMIO status %h want 1", uut.regs0.mem[2]);
            $finish(1);
        end

        // --- F: kb_ready high must NOT steal PC (IRQ gated off) ---
        clear_cpu;
        kb_data = 8'h99;
        kb_ready = 1'b1;
        uut.dmem[0] = enc_i(9'h020, 5'd1, 5'd0, 13'd1);
        uut.dmem[1] = enc_i(9'h020, 5'd1, 5'd1, 13'd1);
        uut.dmem[2] = enc_i(9'h020, 5'd1, 5'd1, 13'd1);
        uut.dmem[3] = enc_r(9'h0FF, 5'd0, 5'd0, 5'd0, 5'd0, 3'd0);
        run_until_halt(80);
        if (uut.regs0.mem[1] !== 32'd3) begin
            $display("FAIL: IRQ stole PC? r1=%0d want 3", uut.regs0.mem[1]);
            $finish(1);
        end
        pc_sample = uut.pcout;
        tick; tick; tick;
        if (uut.pcout !== pc_sample || !uut.pc0.halted) begin
            $display("FAIL: halt not sticky under kb_ready");
            $finish(1);
        end

        // --- G: asm io.s path (OUT 'A', IN kb) ---
        clear_cpu;
        kb_data = 8'h42;
        kb_ready = 1'b1;
        $readmemh("tb/mem/io.mem", uut.dmem);
        run_until_halt(200);
        if (io_out !== 8'h41) begin
            $display("FAIL: asm OUT %h", io_out); $finish(1);
        end
        if (uut.regs0.mem[1] !== 32'h42) begin
            $display("FAIL: asm IN %h", uut.regs0.mem[1]); $finish(1);
        end

        $display("PASS: kb_io (IN/OUT/MMIO/IRQ-off/asm)");
        $finish;
    end
endmodule
