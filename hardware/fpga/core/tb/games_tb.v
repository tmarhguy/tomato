/*
 * Tomato OS — enter selects, then Fibonacci / Snake / Tetris actually play.
 *
 * Tunables at 0xE00 are poked to 1 so a world step is microseconds, not a
 * fifth of a second. The OS code path is otherwise identical to the board.
 */
`timescale 1ns/1ps
module games_tb;
    reg clk = 0;
    reg reset = 1;
    reg  [7:0]  kb_data = 8'h00;
    reg         kb_ready = 1'b0;
    wire [7:0]  io_out;
    wire [31:0] disp_value;
    wire        kb_rd, halted;
    reg  [12:0] tile_raddr = 13'd0;
    wire [31:0] tile_rdata;

    always #5 clk = ~clk;
    always @(posedge clk) if (kb_rd) kb_ready <= 1'b0;

    main uut (
        .clk(clk), .reset(reset),
        .kb_data(kb_data), .kb_ready(kb_ready), .kb_rd(kb_rd),
        .io_out(io_out), .disp_value(disp_value), .halted(halted),
        .tile_rclk(clk), .tile_raddr(tile_raddr), .tile_rdata(tile_rdata)
    );

    task tick; begin @(posedge clk); #1; end endtask

    task wait_n;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) tick;
        end
    endtask

    function [7:0] glyph;
        input integer x;
        input integer y;
        begin
            glyph = uut.vga0.lo[y * 80 + x][7:0];
        end
    endfunction

    task press;
        input [7:0] code;
        integer guard;
        begin
            kb_data  = code;
            kb_ready = 1'b1;
            guard = 0;
            while (kb_ready && guard < 300000) begin
                tick;
                guard = guard + 1;
            end
            if (kb_ready) begin
                $display("FAIL: key %02h never consumed", code);
                $finish(1);
            end
        end
    endtask

    task wait_ch;
        input integer x;
        input integer y;
        input [7:0] ch;
        input [255:0] tag;
        integer n;
        begin
            n = 0;
            while (glyph(x, y) !== ch && n < 500000) begin
                tick;
                n = n + 1;
            end
            if (glyph(x, y) !== ch) begin
                $display("FAIL: %0s timeout at (%0d,%0d) got %02h want %c",
                         tag, x, y, glyph(x, y), ch);
                $finish(1);
            end
        end
    endtask

    task wait_str;
        input integer x;
        input integer y;
        input [8*12-1:0] s;
        input integer nch;
        input [255:0] tag;
        integer i, n, match;
        begin
            n = 0;
            match = 0;
            while (!match && n < 500000) begin
                match = 1;
                for (i = 0; i < nch; i = i + 1)
                    if (glyph(x + i, y) !== s[8*(nch-1-i) +: 8]) match = 0;
                if (!match) tick;
                n = n + 1;
            end
            if (!match) begin
                $display("FAIL: %0s missing at (%0d,%0d)", tag, x, y);
                $finish(1);
            end
        end
    endtask

    integer n, x, y, db0, db1, minx, maxx, miny, maxy;

    task count_glyph;
        output integer nout;
        input integer x0;
        input integer y0;
        input integer x1;
        input integer y1;
        input [7:0] ch;
        integer cx, cy, c;
        begin
            c = 0;
            for (cy = y0; cy <= y1; cy = cy + 1)
                for (cx = x0; cx <= x1; cx = cx + 1)
                    if (glyph(cx, cy) === ch) c = c + 1;
            nout = c;
        end
    endtask

    task bbox_glyph;
        output integer xlo;
        output integer xhi;
        output integer ylo;
        output integer yhi;
        input integer x0;
        input integer y0;
        input integer x1;
        input integer y1;
        input [7:0] ch;
        integer cx, cy, seen;
        begin
            xlo = 99; xhi = 0; ylo = 99; yhi = 0; seen = 0;
            for (cy = y0; cy <= y1; cy = cy + 1)
                for (cx = x0; cx <= x1; cx = cx + 1)
                    if (glyph(cx, cy) === ch) begin
                        seen = 1;
                        if (cx < xlo) xlo = cx;
                        if (cx > xhi) xhi = cx;
                        if (cy < ylo) ylo = cy;
                        if (cy > yhi) yhi = cy;
                    end
            if (!seen) begin
                xlo = 0; xhi = 0; ylo = 0; yhi = 0;
            end
        end
    endtask

    task wait_bbox;
        input integer x0;
        input integer y0;
        input integer x1;
        input integer y1;
        input [7:0] ch;
        input integer want_maxx;
        input integer want_maxy;
        input integer limit_maxx;
        input [255:0] tag;
        integer n, xlo, xhi, ylo, yhi;
        begin
            n = 0;
            bbox_glyph(xlo, xhi, ylo, yhi, x0, y0, x1, y1, ch);
            while ((xhi <= want_maxx || yhi <= want_maxy) && n < 200000) begin
                tick;
                n = n + 1;
                if ((n % 200) == 0)
                    bbox_glyph(xlo, xhi, ylo, yhi, x0, y0, x1, y1, ch);
                if (xhi >= limit_maxx) begin
                    $display("FAIL: %0s hit the wall (maxx=%0d) at cycle %0d", tag, xhi, n);
                    $finish(1);
                end
            end
            bbox_glyph(xlo, xhi, ylo, yhi, x0, y0, x1, y1, ch);
            if (xhi <= want_maxx || yhi <= want_maxy) begin
                $display("FAIL: %0s bbox x=%0d..%0d y=%0d..%0d", tag, xlo, xhi, ylo, yhi);
                $finish(1);
            end
            minx = xlo; maxx = xhi; miny = ylo; maxy = yhi;
        end
    endtask

    localparam TUNE = 14'h0E00;

    initial begin
        for (n = 0; n < 256; n = n + 1) uut.regs0.mem[n] = 32'h0;
        uut.regs0.bank = 3'd0;
        for (n = 0; n < 16384; n = n + 1) uut.dmem[n] = 32'h0;
        for (n = 0; n < 8192; n = n + 1) begin
            uut.vga0.lo[n] = 16'h0;
            uut.vga0.hi[n] = 16'h0;
        end
        $readmemh("tb/mem/tomato_os.mem", uut.dmem);
        uut.dmem[TUNE + 0] = 32'd1;
        uut.dmem[TUNE + 1] = 32'd1;
        uut.dmem[TUNE + 2] = 32'd1;
        uut.dmem[TUNE + 3] = 32'd1;

        tick; tick;
        reset = 0;

        // ---- menu: nine entries, Fibonacci / Snake / Tetris among them ----
        wait_str(8, 6, "System info", 11, "menu sysinfo");
        wait_ch(8, 14, "F", "menu Fibonacci");
        wait_ch(9, 14, "i", "menu Fibonacci i");
        wait_ch(8, 16, "S", "menu Snake");
        wait_ch(9, 16, "n", "menu Snake n");
        wait_ch(8, 18, "T", "menu Tetris");
        wait_ch(9, 18, "e", "menu Tetris e");
        $display("menu: Fibonacci / Snake / Tetris listed");

        // ---- N17 enter opens the highlighted entry ----
        press(8'h0D);
        wait_str(7, 3, "SYSTEM INFO", 11, "enter -> system info");
        $display("enter: opened System info");
        press(8'h11);
        wait_str(8, 6, "System info", 11, "left back to menu");

        // ---- Fibonacci: down×4, enter, F(10)=55, up → F(11)=89, +10, back ----
        repeat (4) press(8'h1F);
        press(8'h0D);
        wait_str(7, 3, "FIBONACCI", 9, "fib title");
        wait_ch(10, 9, "1", "fib n tens");
        wait_ch(11, 9, "0", "fib n ones");
        wait_ch(13, 11, "5", "fib F(10) tens");
        wait_ch(14, 11, "5", "fib F(10) ones");
        $display("fib: F(10)=55");

        press(8'h1E);                    // up → n=11
        wait_ch(11, 9, "1", "fib n=11");
        wait_ch(13, 11, "8", "fib F(11) tens");
        wait_ch(14, 11, "9", "fib F(11) ones");
        $display("fib: up → F(11)=89");

        press(8'h10);                    // right → +10 → n=21
        wait_ch(10, 9, "2", "fib n=21 tens");
        wait_ch(11, 9, "1", "fib n=21 ones");
        $display("fib: right → n=21");

        press(8'h11);
        wait_str(8, 6, "System info", 11, "fib back");

        // r20 is kept, so one down from Fibonacci lands on Snake.
        press(8'h1F);
        press(8'h0D);
        wait_str(7, 3, "SNAKE", 5, "snake title");
        wait_str(24, 23, "press any k", 11, "snake start prompt");
        press(8'h10);                    // start (already heading right)
        n = 0;
        count_glyph(db0, 20, 14, 59, 33, 8'hDB);
        while (db0 < 3 && n < 80000) begin
            tick;
            n = n + 1;
            if ((n % 100) == 0) count_glyph(db0, 20, 14, 59, 33, 8'hDB);
        end
        if (db0 < 3) begin
            $display("FAIL: snake body missing (%0d blocks)", db0);
            $finish(1);
        end
        bbox_glyph(minx, maxx, miny, maxy, 20, 14, 59, 33, 8'hDB);
        if (maxx < 40) begin
            $display("FAIL: snake did not spawn heading right (maxx=%0d)", maxx);
            $finish(1);
        end
        $display("snake: spawned maxx=%0d maxy=%0d blocks=%0d", maxx, maxy, db0);

        press(8'h1F);                    // down — before it walks into the wall
        wait_bbox(20, 14, 58, 33, 8'hDB, -1, 24, 58, "snake turn down");
        $display("snake: turned down maxy=%0d", maxy);

        press(8'h11);                    // left
        wait_n(2000);
        press(8'h0D);                    // quit
        wait_str(8, 6, "System info", 11, "snake quit to menu");
        $display("snake: quit");

        press(8'h1F);
        press(8'h0D);
        wait_str(7, 3, "TETRIS", 6, "tetris title");
        wait_str(33, 25, "press any k", 11, "tetris start prompt");
        press(8'h10);
        n = 0;
        count_glyph(db0, 30, 16, 49, 35, 8'hDB);
        while (db0 < 4 && n < 80000) begin
            tick;
            n = n + 1;
            if ((n % 100) == 0) count_glyph(db0, 30, 16, 49, 35, 8'hDB);
        end
        if (db0 < 4) begin
            $display("FAIL: tetris piece missing (%0d blocks)", db0);
            $finish(1);
        end
        bbox_glyph(minx, maxx, miny, maxy, 30, 16, 49, 35, 8'hDB);
        $display("tetris: spawned blocks=%0d x=%0d..%0d y=%0d..%0d",
                 db0, minx, maxx, miny, maxy);

        press(8'h10);                    // right
        wait_bbox(30, 16, 49, 35, 8'hDB, maxx, -1, 50, "tetris slide right");
        $display("tetris: slid right maxx=%0d", maxx);

        press(8'h11);                    // left
        wait_n(2000);
        count_glyph(db0, 30, 16, 49, 35, 8'hDB);
        press(8'h1E);                    // rotate
        n = 0;
        count_glyph(db1, 30, 16, 49, 35, 8'hDB);
        while (n < 20000 && db1 == 0) begin
            tick;
            n = n + 1;
            if ((n % 200) == 0) count_glyph(db1, 30, 16, 49, 35, 8'hDB);
        end
        count_glyph(db1, 30, 16, 49, 35, 8'hDB);
        if (db1 < 4) begin
            $display("FAIL: tetris piece vanished after rotate (%0d, before=%0d, wait=%0d)",
                     db1, db0, n);
            $finish(1);
        end
        $display("tetris: rotated blocks=%0d", db1);

        press(8'h1F);                    // soft drop
        n = 0;
        count_glyph(db0, 30, 16, 49, 35, 8'hDB);
        while (n < 15000 && db0 < 4) begin
            tick;
            n = n + 1;
            if ((n % 200) == 0) count_glyph(db0, 30, 16, 49, 35, 8'hDB);
        end
        bbox_glyph(minx, maxx, miny, maxy, 30, 16, 49, 35, 8'hDB);
        if (db0 < 4) begin
            $display("FAIL: tetris piece vanished after drop (%0d)", db0);
            $finish(1);
        end
        $display("tetris: drop maxy=%0d blocks=%0d", maxy, db0);

        press(8'h0D);
        wait_str(8, 6, "System info", 11, "tetris quit to menu");
        $display("tetris: quit");

        if (halted) begin
            $display("FAIL: OS halted");
            $finish(1);
        end
        $display("PASS: games (enter selects, fib/snake/tetris play)");
        $finish;
    end
endmodule
