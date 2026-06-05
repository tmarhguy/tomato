`timescale 1ns / 1ps

module tb_mosaic32;

    reg clk;
    reg reset;

    // Instantiate Top-Level CPU
    main uut (
        .clk(clk),
        .reset(reset)
    );

    // Clock Generation
    always #5 clk = ~clk;

    initial begin
        $dumpfile("mosaic32.vcd");
        $dumpvars(0, tb_mosaic32);

        // Reset Sequence
        clk = 0;
        reset = 0;
        
        // Load fib.hex into memory
        // Removed memory read in initial block
        #20 reset = 1;

        // Run for enough cycles to fetch and execute a few instructions
        #2000;
        
        $display("Simulation Finished.");
        $finish;
    end

    // Monitor internal registers

    always @(posedge clk) begin
        if (uut.seq_fetch) begin
            $display("Time %0t | FETCH | b_temp(PC) = %0d | pc_save = %0d | mem_addr = %0d | MEM_OUT(l_temp) = %08x | reg_w_data(m_temp) = %08x", $time, uut.b_temp, uut.pc_save, uut.mem_addr, uut.l_temp, uut.m_temp);
        end
        if (uut.seq_exec) begin
            $display("Time %0t | EXEC | PC = %0d | IR = %08x", $time, uut.pc_save, uut.f_temp);
        end
        if (uut.ctrl_mem_wr === 1'b1 || uut.ctrl_mem_wr === 1'bx) begin
            $display("Time %0t | MEM WRITE | ADDR = %0d | DATA = %08x | MEM_WR = %b", $time, uut.mem_addr, uut.l_temp, uut.ctrl_mem_wr);
        end
        if (uut.register_i4.WE && uut.register_i4.EXEC) begin
            $display("Time %0t | REG[%0d] <= %0d (0x%0x)", $time, uut.register_i4.ADDR_W, uut.register_i4.DATA_W, uut.register_i4.DATA_W);
        end
    end

endmodule
