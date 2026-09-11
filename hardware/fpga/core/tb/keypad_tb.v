/*
 * Tomato — D-pad keypad: N17=enter, M18=up, P18=down, P17=left, M17=right
 *
 * SAMPLE=4 keeps a debounce tick at 16 clocks instead of 10 ms of sim time.
 * STABLE_N=4 means a level must hold for four ticks (64 clocks) before
 * it counts, which lets the bounce test chatter faster than that on purpose.
 */
`timescale 1ns/1ps
module keypad_tb;
    reg        clk = 0;
    reg        reset = 1;
    reg        btnu = 0, btnd = 0, btnl = 0, btnr = 0, btnc = 0;
    reg        rd = 0;
    wire [7:0] kb_data;
    wire       kb_ready;
    integer    keys;
    reg  [7:0] last;

    always #5 clk = ~clk;

    keypad #(.SAMPLE(4), .STABLE_N(4), .REPEAT_AFTER(4), .REPEAT_RATE(4)) uut (
        .clk(clk), .reset(reset),
        .btnu(btnu), .btnd(btnd), .btnl(btnl), .btnr(btnr), .btnc(btnc),
        .rd(rd), .kb_data(kb_data), .kb_ready(kb_ready)
    );

    task tick; begin @(posedge clk); #1; end endtask

    task ticks;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) tick;
        end
    endtask

    task release_all;
        begin
            btnu = 0; btnd = 0; btnl = 0; btnr = 0; btnc = 0;
        end
    endtask

    task expect_key;
        input [7:0] code;
        input [255:0] tag;
        integer guard;
        begin
            guard = 0;
            while (!kb_ready && guard < 200) begin
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

    // Poll the port like the CPU does — thousands of times per sample — and
    // count how many distinct keycodes actually came through.
    task poll_count;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                if (kb_ready) begin
                    keys = keys + 1;
                    last = kb_data;
                    rd = 1;
                    tick;
                    rd = 0;
                end else tick;
            end
        end
    endtask

    task tap;
        input [2:0] which; // 0 up, 1 down, 2 left, 3 right, 4 enter
        begin
            release_all;
            case (which)
                0: btnu = 1;
                1: btnd = 1;
                2: btnl = 1;
                3: btnr = 1;
                4: btnc = 1;
            endcase
            ticks(128);           // sync + STABLE_N ticks, with margin
            release_all;
            ticks(128);
        end
    endtask

    initial begin
        keys = 0;
        last = 8'h00;
        ticks(8);
        reset = 0;
        ticks(8);

        tap(4); expect_key(8'h0D, "N17 enter");
        tap(0); expect_key(8'h1E, "M18 up");
        tap(1); expect_key(8'h1F, "P18 down");
        tap(2); expect_key(8'h11, "P17 left");
        tap(3); expect_key(8'h10, "M17 right");
        $display("codes: N17=0D M18=1E P18=1F P17=11 M17=10");

        // One clean push must deliver exactly ONE keycode even though the CPU
        // polls thousands of times faster than the debounce interval. The edge
        // is one clock wide for this reason; a sample-wide edge re-armed
        // kb_ready every cycle and turned one click into thousands.
        keys = 0;
        release_all;
        btnc = 1;
        poll_count(400);
        btnc = 0;
        poll_count(400);
        if (keys !== 1) begin
            $display("FAIL: one push delivered %0d keycodes, want 1", keys);
            $finish(1);
        end
        if (last !== 8'h0D) begin
            $display("FAIL: one push delivered %02h, want 0D", last);
            $finish(1);
        end
        $display("one push -> one key");

        // A dirty contact: chatter in stretches shorter than the debounce
        // window, then settle closed. Still exactly one keycode.
        keys = 0;
        release_all;
        btnc = 1; ticks(5);  btnc = 0; ticks(11);
        btnc = 1; ticks(7);  btnc = 0; ticks(9);
        btnc = 1; ticks(13); btnc = 0; ticks(6);
        btnc = 1;                       // contacts settle closed
        poll_count(400);
        btnc = 0;
        poll_count(400);
        if (keys !== 1) begin
            $display("FAIL: bouncing contact delivered %0d keycodes, want 1", keys);
            $finish(1);
        end
        $display("bouncing contact -> one key");

        // A held enter is one key, not a burst — the screen must not bounce
        // back to the menu from the same press that opened it.
        release_all;
        btnc = 1;
        ticks(128);
        expect_key(8'h0D, "held enter first");
        ticks(300);
        if (kb_ready) begin
            $display("FAIL: held enter re-fired");
            $finish(1);
        end
        btnc = 0;
        ticks(128);
        $display("held enter -> no re-fire");

        // Held up auto-repeats; that is what lets Tetris slide.
        release_all;
        btnu = 1;
        ticks(128);
        expect_key(8'h1E, "up first");
        expect_key(8'h1E, "up repeat");
        btnu = 0;
        ticks(128);
        $display("held arrow -> auto-repeat");

        $display("PASS: keypad (codes, one-push-one-key, bounce, repeat)");
        $finish;
    end
endmodule
