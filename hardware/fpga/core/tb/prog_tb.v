/*
 * Tomato — run assembled program image from tb/mem/<PROG>.mem
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : prog_tb.v
 * Target   : simulation (cwd = hardware/fpga/core)
 *
 * Plusargs:
 *   +PROG=counter|fib|collatz|call|bytes  (default counter)
 *   +EXPECT_R1=<int>            expected r1 at halt
 *   +EXPECT_R2=<int>            optional
 *   +EXPECT_DISP=<int>          optional (default = EXPECT_R1)
 *   +EXPECT_R6=<int>            optional (fib loadback)
 */
`timescale 1ns/1ps
module prog_tb;
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

    reg [8*64-1:0] prog;
    integer expect_r1, expect_r2, expect_disp, expect_r6;
    integer have_r2, have_r6, have_disp;
    integer k, saw_halt, kb_val;
    integer cycles_to_halt, instr_retired;
    real cpi;
    reg measuring;
    reg [1023:0] path;

    // Retire count = fetch edges after reset (one fetch per instruction).
    always @(posedge clk) begin
        if (!reset && measuring && !uut.pc0.halted && uut.fetch)
            instr_retired <= instr_retired + 1;
    end

    initial begin
        prog = "counter";
        expect_r1 = 10;
        expect_r2 = 0; have_r2 = 0;
        expect_r6 = 0; have_r6 = 0;
        expect_disp = 10; have_disp = 0;
        kb_val = 0;
        cycles_to_halt = 0;
        instr_retired = 0;
        measuring = 0;

        if ($value$plusargs("PROG=%s", prog)) begin end
        if ($value$plusargs("EXPECT_R1=%d", expect_r1)) begin end
        if ($value$plusargs("EXPECT_R2=%d", expect_r2)) have_r2 = 1;
        if ($value$plusargs("EXPECT_R6=%d", expect_r6)) have_r6 = 1;
        if ($value$plusargs("EXPECT_DISP=%d", expect_disp)) have_disp = 1;
        if ($value$plusargs("KB=%d", kb_val)) begin
            kb_data = kb_val[7:0];
            kb_ready = 1'b1;
        end

        for (k = 0; k < 256; k = k + 1) uut.regs0.mem[k] = 32'h0;
        uut.regs0.bank = 3'd0;
        for (k = 0; k < 16384; k = k + 1) uut.dmem[k] = 32'h0;

        $sformat(path, "tb/mem/%0s.mem", prog);
        $readmemh(path, uut.dmem);

        tick; tick;
        reset = 0;
        measuring = 1;

        saw_halt = 0;
        for (k = 0; k < 200000; k = k + 1) begin
            tick;
            cycles_to_halt = cycles_to_halt + 1;
            if (uut.pc0.halted) begin
                saw_halt = 1;
                measuring = 0;
                k = 200000;
            end
        end

        if (!saw_halt) begin
            $display("FAIL: no halt prog=%0s pc=%h r1=%0d r2=%0d",
                     prog, uut.pcout, uut.regs0.mem[1], uut.regs0.mem[2]);
            $finish(1);
        end
        if (uut.regs0.mem[1] !== expect_r1) begin
            $display("FAIL: r1=%0d want %0d (%0s)", uut.regs0.mem[1], expect_r1, prog);
            $finish(1);
        end
        if (have_r2 && uut.regs0.mem[2] !== expect_r2) begin
            $display("FAIL: r2=%0d want %0d", uut.regs0.mem[2], expect_r2);
            $finish(1);
        end
        if (have_r6 && uut.regs0.mem[6] !== expect_r6) begin
            $display("FAIL: r6=%0d want %0d", uut.regs0.mem[6], expect_r6);
            $finish(1);
        end
        if (have_disp && uut.disp !== expect_disp) begin
            $display("FAIL: disp=%0d want %0d", uut.disp, expect_disp);
            $finish(1);
        end
        if (prog == "io" && uut.io_out !== 8'h41) begin
            $display("FAIL: io_out=%0d want 65", uut.io_out);
            $finish(1);
        end
        if (prog == "kb_mmio" && uut.io_out !== expect_r1[7:0]) begin
            $display("FAIL: kb_mmio io_out=%0d want %0d", uut.io_out, expect_r1[7:0]);
            $finish(1);
        end

        if (instr_retired > 0)
            cpi = cycles_to_halt * 1.0 / instr_retired;
        else
            cpi = 0.0;

        $display("PASS: prog %0s r1=%0d disp=%0d", prog, uut.regs0.mem[1], uut.disp);
        $display("CPI: prog=%0s cycles=%0d instr=%0d cpi=%0.3f",
                 prog, cycles_to_halt, instr_retired, cpi);
        $finish;
    end
endmodule
