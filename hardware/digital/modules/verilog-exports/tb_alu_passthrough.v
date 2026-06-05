`timescale 1ns / 1ps

// ============================================================
// tb_alu_passthrough.v - Mosaic32 ALU passthrough verification
//
// Program loaded into instruction memory (memory_i11):
//   addr 0: 0x22000801  LDI R1, 8   (OPCODE=0x22, ADDR_A=R0, ADDR_B=imm=8, ADDR_W=R1)
//   addr 1: 0x01010001  ADD R1,R1,R0 (OPCODE=0x01, ADDR_A=R1, ADDR_B=R0, ADDR_W=R1)
//   addr 2: 0x30000001  JMP 1        (OPCODE=0x30, addr=1)
//
// Expected: after LDI sets R1=8, ADD computes j = R1+R0 = 8+0 = 8 every loop
// ============================================================

module tb_alu_passthrough;

    reg clk;
    reg reset;

    wire [23:0] b;   // PC output
    wire [31:0] j;   // ALU output (alu_out)
    wire [31:0] m;   // writeback data
    wire [7:0]  c;   // opcode
    wire [7:0]  h;   // ADDR_W dest reg
    wire [7:0]  g;   // ADDR_A src A reg
    wire [7:0]  d;   // ADDR_B src B reg

    main uut (
        .clk(clk),
        .reset(reset),
        .b(b), .j(j), .m(m), .c(c), .h(h), .g(g), .d(d)
    );

    // 10 ns clock
    always #5 clk = ~clk;

    // Load program into instruction memory (memory_i11)
    task load_program;
        begin
            // Mirror exact counter.hex structure, proven to work in Digital
            uut.memory_i11.DIG_RAMDualPort_i0.memory[0] = 32'h2200001f; // LDI R31, 0  (CPU init)
            uut.memory_i11.DIG_RAMDualPort_i0.memory[1] = 32'h22000801; // LDI R1, 8   (load 8)
            uut.memory_i11.DIG_RAMDualPort_i0.memory[2] = 32'h22000000; // LDI R0, 0   (clear R0)
            uut.memory_i11.DIG_RAMDualPort_i0.memory[3] = 32'h01000100; // ADD R0,R0,R1 (j = R0+R1 = 0+8 = 8)
            uut.memory_i11.DIG_RAMDualPort_i0.memory[4] = 32'h30000003; // JMP 3        (loop to ADD)
            uut.memory_i11.DIG_RAMDualPort_i0.memory[5] = 32'h00000000;
            $display("[LOAD] 2200001f  LDI R31,0");
            $display("[LOAD] 22000801  LDI R1,8");
            $display("[LOAD] 22000000  LDI R0,0");
            $display("[LOAD] 01000100  ADD R0,R0,R1  <-- loop body, expect j=8");
            $display("[LOAD] 30000003  JMP 3");
        end
    endtask

    integer cycle_count;
    integer j_eq_8_count;
    integer add_count;

    initial begin
        $dumpfile("alu_passthrough.vcd");
        $dumpvars(0, tb_alu_passthrough);

        clk   = 0;
        reset = 0;
        cycle_count  = 0;
        j_eq_8_count = 0;
        add_count    = 0;

        // Load program before any clocks
        #1;
        load_program;

        // Verify load
        $display("[VERIFY] mem[0]=%08x  mem[1]=%08x  mem[2]=%08x",
                 uut.memory_i11.DIG_RAMDualPort_i0.memory[0],
                 uut.memory_i11.DIG_RAMDualPort_i0.memory[1],
                 uut.memory_i11.DIG_RAMDualPort_i0.memory[2]);

        // Release reset (reset=1 means RUN in this design)
        #9 reset = 1;
        $display("[SIM]  reset=1 at t=%0t  CPU running...", $time);
        $display("-------------------------------------------------------");

        // Run 600 ns (~60 cycles, enough for multiple LDI+ADD+JMP loops)
        #600;

        $display("=======================================================");
        $display("SUMMARY:");
        $display("  ADD instructions observed: %0d", add_count);
        $display("  j==8 count:                %0d", j_eq_8_count);
        if (j_eq_8_count > 0)
            $display("  RESULT: PASS - ALU output = 8 confirmed");
        else
            $display("  RESULT: FAIL - ALU output never reached 8");

        // Final register snapshot
        $display("  R0 = %0d (should be 0)",
                 uut.register_i3.DIG_RAMDualAccess_i0.memory[0]);
        $display("  R1 = %0d (should be 8)",
                 uut.register_i3.DIG_RAMDualAccess_i0.memory[1]);
        $display("=======================================================");
        $finish;
    end

    // Trace every clock edge
    always @(posedge clk) begin
        cycle_count = cycle_count + 1;

        if (reset) begin

            // --- FETCH phase ---
            if (uut.seq_fetch) begin
                $display("t=%6t [%02d] FETCH   PC=%0d  mem_rd=%b  raw_data=0x%08x  IR_loaded=0x%08x",
                         $time, cycle_count,
                         b,
                         uut.mem_rd_out,
                         uut.l_temp,
                         uut.f_temp);
            end

            // --- EXECUTE phase ---
            if (uut.seq_exec) begin
                $display("t=%6t [%02d] EXECUTE opcode=0x%02x (%s)  ADDR_A=R%0d  ADDR_B=R%0d  ADDR_W=R%0d",
                         $time, cycle_count, c,
                         (c==8'h22)?"LDI":(c==8'h01)?"ADD":(c==8'h30)?"JMP":"???",
                         g, d, h);
                $display("             reg_a=%0d  reg_b=%0d  b_main_sel=%b  alu_b=%0d",
                         uut.reg_a, uut.reg_b,
                         uut.b_main_sel,
                         uut.alu_b);
                $display("             j(alu_out)=%0d  (0x%08x)  reg_we=%b",
                         j, j, uut.ctrl_reg_we);

                // Track ADD specifically
                if (c == 8'h01) begin
                    add_count = add_count + 1;
                    $display("             *** ADD#%0d: reg_a(%0d) + alu_b(%0d) = j(%0d) ***",
                             add_count, uut.reg_a, uut.alu_b, j);
                    if (j == 32'd8) j_eq_8_count = j_eq_8_count + 1;
                end

                // Register writeback
                if (uut.ctrl_reg_we) begin
                    $display("             <<< WRITE R%0d <= %0d (wb_data=0x%08x) >>>",
                             h, uut.m_temp, uut.m_temp);
                end
            end

        end
    end

endmodule
