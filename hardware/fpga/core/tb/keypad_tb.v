/*
 * Tomato — D-pad keypad: N17=enter, M18=up, P18=down, P17=left, M17=right
 *
 * SAMPLE is kept small so a tick is 16 clocks, not 10 ms of sim time.
 */
`timescale 1ns/1ps
module keypad_tb;
    reg        clk = 0;
    reg        reset = 1;
    reg        btnu = 0, btnd = 0, btnl = 0, btnr = 0, btnc = 0;
    reg        rd = 0;
    wire [7:0] kb_data;
    wire       kb_ready;

    always #5 clk = ~clk;

    keypad #(.SAMPLE(4), .REPEAT_AFTER(4), .REPEAT_RATE(4)) uut (
        .clk(clk), .reset(reset),
        .btnu(btnu), .btnd(btnd), .btnl(btnl), .btnr(btnr), .btnc(btnc),
        .rd(rd), .kb_data(kb_data), .kb_ready(kb_ready)
    );

    task tick; begin @(posedge clk); #1; end endtask

    // One debounce tick is 16 clocks (SAMPLE=4 → 4-bit wrap).
    task ticks;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) tick;
        end
    endtask

    task expect_key;
        input [7:0] code;
        input [255:0] tag;
        integer guard;
        begin
            guard = 0;
            while (!kb_ready && guard < 80) begin
                tick;
                guard = guard + 1;
            end
            if (!kb_ready) begin
                $display("FAIL: %0s never became ready", tag);
                $finish(1);
            end
            if (kb_data !== code) begin
                $display("FAIL: %0s got %02h want %02h", tag, kb_data, code);
                $finish(1);
            end
            rd = 1;
            tick;
            rd = 0;
            if (kb_ready) begin
                $display("FAIL: %0s still ready after rd", tag);
                $finish(1);
            end
        end
    endtask

    task tap;
        input [2:0] which; // 0 up, 1 down, 2 left, 3 right, 4 enter
        begin
            btnu = 0; btnd = 0; btnl = 0; btnr = 0; btnc = 0;
            case (which)
                0: btnu = 1;
                1: btnd = 1;
                2: btnl = 1;
                3: btnr = 1;
                4: btnc = 1;
            endcase
            // sync (2) + one stable sample + one rising-edge sample
            ticks(48);
            btnu = 0; btnd = 0; btnl = 0; btnr = 0; btnc = 0;
            ticks(32);
        end
    endtask

    initial begin
        ticks(4);
        reset = 0;
        ticks(4);

        tap(4); expect_key(8'h0D, "N17 enter");
        tap(0); expect_key(8'h1E, "M18 up");
        tap(1); expect_key(8'h1F, "P18 down");
        tap(2); expect_key(8'h11, "P17 left");
        tap(3); expect_key(8'h10, "M17 right");

        // A held enter is one key, not a burst — the screen must not bounce
        // back to the menu from the same press that opened it.
        btnc = 1;
        ticks(48);
        expect_key(8'h0D, "held enter first");
        ticks(80);
        if (kb_ready) begin
            $display("FAIL: held enter re-fired");
            $finish(1);
        end
        btnc = 0;
        ticks(32);

        // Held up auto-repeats; that is what lets Tetris slide.
        btnu = 1;
        ticks(48);
        expect_key(8'h1E, "up first");
        ticks(80);
        expect_key(8'h1E, "up repeat");
        btnu = 0;
        ticks(32);

        $display("PASS: keypad N17=0x0D M18=0x1E P18=0x1F P17=0x11 M17=0x10");
        $finish;
    end
endmodule
