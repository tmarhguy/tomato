`timescale 1ns / 1ps

// ============================================================
// tb_count.v - Mosaic32 ALU Counter Testbench
// 
// Goal: Run a simple R0++ loop to verify ALU increment works.
//
// Opcode 0x96 (XOR truth-table = full-adder sum):
//   ctrl=1 (asel=1, bsel=0, ainv=0, binv=0, csel=0) + cin-sel=1
//   => ALU OUT = A + 0 + 1 = A + 1  (increment!)
//
// Microcode word for 0x96 (INC): 0x000C2196
//   [7:0]  = 0x96 (alu-op: XOR truth-table)
//   [12:8] = 0x01 (ctrl=1: asel=1 only)
//   [13]   = 1    (cin-sel=1: force carry-in=1)
//   [15:14]= 0    (wb-sel=0: ALU output)
//   [18]   = 1    (flags-we=1)
//   [19]   = 1    (reg-we=1)
//   cycles = 0    -> 2-cycle (fetch+exec)
//
// Program: 8 x (INC R0) at memory addresses 0..7
// ============================================================

module tb_count;

    reg clk;
    reg reset;

    // Instantiate Top-Level CPU
    main uut (
        .clk(clk),
        .reset(reset)
    );

    // ── Clock: 10 ns period ────────────────────────────────
    always #5 clk = ~clk;

    // ── Patch microcode ROM for opcode 0x96 ───────────────
    // Fix entry 150 (0x96) to be a proper INC instruction:
    //   Encoding (32-bit microcode word):
    //     [7:0]  = 0x96  alu-op (XOR/add full-adder truth table)
    //     [12:8] = 1     ctrl=1 (asel=1 only — pass A, zero B)
    //     [13]   = 1     cin-sel=1 (force carry-in=1 => A+0+1=A+1)
    //     [15:14]= 0     wb-sel=0 (write back ALU result)
    //     [18]   = 1     flags-we=1
    //     [19]   = 1     reg-we=1
    //     [27]   = 1     cycles[0]=1 -> cycles=01 (fetch+exec, 2-phase)
    //   = 0x080C2196
    task patch_microcode;
        integer i;
        begin
            // Opcode 0x96 = INC: ctrl=1, cin-sel=1, reg-we=1, flags-we=1, cycles=01
            uut.microcode_i7.DIG_ROM_256X32_microcodeeeprom_i0.my_rom[8'h96] = 32'h080C2196;
            $display("Microcode patched: ROM[0x96] = 0x%08x",
                     uut.microcode_i7.DIG_ROM_256X32_microcodeeeprom_i0.my_rom[8'h96]);
        end
    endtask

    // ── Load count program into memory ────────────────────
    task load_program;
        integer i;
        begin
            // 8 x INC R0: opcode=0x96, A=0, B=0, W=0
            for (i = 0; i < 8; i = i + 1) begin
                uut.memory_i8.DIG_RAMDualPort_i0.memory[i] = 32'h96000000;
            end
            $display("Program loaded: 8 x INC R0 (0x96000000) at addr 0..7");
        end
    endtask

    // ── Simulation ────────────────────────────────────────
    integer cycle_count;

    initial begin
        $dumpfile("count.vcd");
        $dumpvars(0, tb_count);

        // Initialize
        clk   = 0;
        reset = 0;
        cycle_count = 0;

        // Patch microcode and load program before reset
        #1;
        patch_microcode;
        load_program;

        // Bring reset high (active-high in this design based on sequencer)
        #9 reset = 1;
        $display("--- Reset released at t=%0t ---", $time);

        // Run for 200 ns (covers ~10 fetch+exec pairs at 10 ns/cycle)
        #400;

        $display("--- Simulation complete at t=%0t ---", $time);
        $finish;
    end

    // ── Monitoring ────────────────────────────────────────
    always @(posedge clk) begin
        cycle_count = cycle_count + 1;

        // Show FETCH phase
        if (uut.seq_fetch) begin
            $display("t=%6t [cyc%0d] FETCH  PC=%0d  mem[%0d]=%08x",
                     $time, cycle_count,
                     uut.b_temp, uut.mem_addr, uut.l_temp);
        end

        // Show EXECUTE phase - ALU result and register write
        if (uut.seq_exec) begin
            $display("t=%6t [cyc%0d] EXEC   IR=%08x  OPCODE=%02x  ctrl=%02b  cin-sel=%b",
                     $time, cycle_count,
                     uut.f_temp, uut.c_temp, uut.ctrl_alu_pre, uut.ctrl_cin_sel);
            $display("            ALU: A=%0d  B=%0d  OUT=%0d  Z=%b  N=%b  C=%b  V=%b",
                     uut.reg_a, uut.reg_b,
                     uut.j_temp,
                     uut.alu_zout, uut.alu_nout, uut.alu_cout, uut.alu_vout);
        end

        // Show register writes
        if (uut.register_i3.WE && uut.register_i3.EXEC) begin
            $display("            >>> REG[%0d] <= %0d (0x%08x) <<<",
                     uut.register_i3.ADDR_W,
                     uut.register_i3.DATA_W,
                     uut.register_i3.DATA_W);
        end
    end

    // ── Final register snapshot ───────────────────────────
    always @(negedge uut.seq_fetch) begin
        // Read R0 directly from the regfile after each instruction
        if (reset && uut.b_temp > 0) begin
            $display("        R0 = %0d",
                     uut.register_i3.DIG_RAMDualAccess_i0.memory[0]);
        end
    end

endmodule
