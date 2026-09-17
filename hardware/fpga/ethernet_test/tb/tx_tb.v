`timescale 1ns/1ps
// rmii_tx: preamble/SFD, payload streaming, auto-pad, FCS, IFG, busy gate.
module tx_tb;
    reg clk = 0;
    always #10 clk = ~clk; // 50MHz net_clk
    reg reset = 1;
    reg tx_start = 0;
    wire tx_busy, tx_done;
    reg [7:0] tx_data = 0;
    reg tx_valid = 0, tx_last = 0;
    wire tx_accept, tx_en;
    wire [1:0] txd;
    rmii_tx dut(clk, reset, tx_start, tx_busy, tx_done,
                tx_data, tx_valid, tx_last, tx_accept, tx_en, txd);

    // Same 60B ARP payload as rx_tb (FCS 01 84 31 2B).
    reg [7:0] payload [0:63];
    reg [7:0] got [0:127];
    integer i, nbytes, errors;

    function [31:0] crc_byte;
        input [31:0] c;
        input [7:0] b;
        reg [31:0] x;
        integer k;
        begin
            x = c;
            for (k = 0; k < 8; k = k + 1)
                x = (x >> 1) ^ ((x[0] ^ b[k]) ? 32'hedb88320 : 0);
            crc_byte = x;
        end
    endfunction

    // Feeder: bytes payload[0..len-1], preloaded before tx_start per contract.
    task feed(input integer len);
        begin
            tx_data = payload[0]; tx_valid = 1; tx_last = (len == 1);
            i = 1;
            @(negedge clk); tx_start = 1;
            @(negedge clk); tx_start = 0;
            while (i < len) begin
                @(negedge clk);
                if (tx_accept) begin
                    tx_data = payload[i]; tx_last = (i == len - 1);
                    i = i + 1;
                end
            end
            // Hold last byte until accepted, then drop valid.
            // First wait for the current accept pulse to clear, otherwise
            // we mistake its tail for the last byte's accept and starve TX.
            while (tx_accept) @(negedge clk);
            while (!tx_accept) @(negedge clk);
            @(negedge clk); tx_valid = 0; tx_last = 0;
        end
    endtask

    // Capture one wire frame: returns bytes in got[], count in nbytes.
    task capture;
        integer d, b, f;
        reg [1:0] dib;
        begin
            // Wait for tx_en rise.
            while (!tx_en) @(negedge clk);
            // 32 preamble/SFD dibits: 28x 01 then D5 LSB-first (01,01,01,11).
            for (d = 0; d < 28; d = d + 1) begin
                if (txd !== 1) begin $display("FAIL preamble dibit %0d = %b", d, txd); $fatal(1); end
                @(negedge clk);
            end
            if (txd !== 1) begin $display("FAIL sfd0"); $fatal(1); end
            @(negedge clk);
            if (txd !== 1) begin $display("FAIL sfd1"); $fatal(1); end
            @(negedge clk);
            if (txd !== 1) begin $display("FAIL sfd2"); $fatal(1); end
            @(negedge clk);
            if (txd !== 3) begin $display("FAIL sfd3"); $fatal(1); end
            @(negedge clk);
            // Bytes until tx_en falls.
            nbytes = 0;
            while (tx_en) begin
                got[nbytes] = 0;
                for (b = 0; b < 4; b = b + 1) begin
                    dib = txd;
                    got[nbytes] = got[nbytes] | (dib << (b * 2));
                    if (b < 3 || tx_en) @(negedge clk);
                    // after last dibit of a byte, tx_en may fall; handled by while
                    if (b == 3) begin
                        // peeked one extra edge only if still enabled
                    end
                end
                nbytes = nbytes + 1;
                if (nbytes > 120) begin $display("FAIL runaway frame"); $fatal(1); end
            end
            // IFG: tx_en low for >= 24 clocks.
            for (f = 0; f < 24; f = f + 1) begin
                if (tx_en) begin $display("FAIL IFG violated at %0d", f); $fatal(1); end
                @(negedge clk);
            end
        end
    endtask

    initial begin
        payload[0]=8'hff; payload[1]=8'hff; payload[2]=8'hff; payload[3]=8'hff;
        payload[4]=8'hff; payload[5]=8'hff; payload[6]=8'h02; payload[7]=8'h00;
        payload[8]=8'h00; payload[9]=8'h00; payload[10]=8'h00; payload[11]=8'h01;
        payload[12]=8'h08; payload[13]=8'h06; payload[14]=8'h00; payload[15]=8'h01;
        payload[16]=8'h02; payload[17]=8'h03; payload[18]=8'h04; payload[19]=8'h05;
        payload[20]=8'h06; payload[21]=8'h07; payload[22]=8'h08; payload[23]=8'h09;
        payload[24]=8'h0a; payload[25]=8'h0b; payload[26]=8'h0c; payload[27]=8'h0d;
        payload[28]=8'h0e; payload[29]=8'h0f; payload[30]=8'h10; payload[31]=8'h11;
        payload[32]=8'h12; payload[33]=8'h13; payload[34]=8'h14; payload[35]=8'h15;
        payload[36]=8'h16; payload[37]=8'h17; payload[38]=8'h18; payload[39]=8'h19;
        payload[40]=8'h1a; payload[41]=8'h1b; payload[42]=8'h1c; payload[43]=8'h1d;
        payload[44]=8'h1e; payload[45]=8'h1f; payload[46]=8'h20; payload[47]=8'h21;
        payload[48]=8'h22; payload[49]=8'h23; payload[50]=8'h24; payload[51]=8'h25;
        payload[52]=8'h26; payload[53]=8'h27; payload[54]=8'h28; payload[55]=8'h29;
        payload[56]=8'h2a; payload[57]=8'h2b; payload[58]=8'h2c; payload[59]=8'h2d;
        errors = 0;
        repeat (4) @(negedge clk); reset = 0;
        repeat (2) @(negedge clk);

        // Test 1: exact 60B frame -> 60 payload + known FCS, no pad.
        fork
            feed(60);
            capture();
        join
        if (nbytes != 64) begin $display("FAIL t1 len %0d != 64", nbytes); $fatal(1); end
        for (i = 0; i < 60; i = i + 1)
            if (got[i] !== payload[i]) begin $display("FAIL t1 byte %0d", i); $fatal(1); end
        if (got[60] !== 8'h01 || got[61] !== 8'h84 || got[62] !== 8'h31 || got[63] !== 8'h2b) begin
            $display("FAIL t1 FCS %h %h %h %h", got[60], got[61], got[62], got[63]); $fatal(1);
        end
        $display("PASS t1 60B frame + known FCS");

        // Test 2: short 20B frame -> padded to 60 + self-consistent FCS.
        for (i = 0; i < 20; i = i + 1) payload[i] = i + 8'h41;
        fork
            feed(20);
            capture();
        join
        if (nbytes != 64) begin $display("FAIL t2 len %0d != 64", nbytes); $fatal(1); end
        for (i = 0; i < 20; i = i + 1)
            if (got[i] !== i + 8'h41) begin $display("FAIL t2 byte %0d", i); $fatal(1); end
        for (i = 20; i < 60; i = i + 1)
            if (got[i] !== 0) begin $display("FAIL t2 pad %0d", i); $fatal(1); end
        begin
            reg [31:0] c;
            c = 32'hffffffff;
            for (i = 0; i < 64; i = i + 1) c = crc_byte(c, got[i]);
            if (c !== 32'hdebb20e3) begin $display("FAIL t2 residue %h", c); $fatal(1); end
        end
        $display("PASS t2 pad-to-60 + residue FCS");

        // Test 3: tx_start while busy is ignored (exactly one frame on wire).
        for (i = 0; i < 60; i = i + 1) payload[i] = i;
        fork
            feed(60);
            begin
                // Spurious restart 40 clocks into the frame; must be ignored.
                wait (tx_busy);
                repeat (40) @(negedge clk);
                tx_start = 1; @(negedge clk); tx_start = 0;
            end
            capture();
        join
        if (nbytes != 64) begin $display("FAIL t3 len %0d", nbytes); $fatal(1); end
        repeat (30) @(negedge clk);
        if (tx_busy) begin $display("FAIL t3 still busy (double frame sent)"); $fatal(1); end
        $display("PASS t3 busy gate");
        $display("PASS TX: preamble/SFD, stream, pad, FCS, IFG, busy");
        $finish;
    end
endmodule
