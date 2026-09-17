`timescale 1ns/1ps
// lan_min + rmii_tx loopback: ARP reply, UDP echo, wrong-port silence,
// bad-CRC silence, auto-HELLO. Least-friction LAN proof before board time.
module echo_tb;
    reg clk = 0;
    always #10 clk = ~clk; // 50MHz
    reg reset = 1;
    reg enable = 0;
    reg dv = 0, err = 0;
    reg [1:0] d = 0;
    // lan_min <-> rmii_tx link
    wire tx_start, tx_busy, tx_done, tx_valid, tx_last, tx_accept, tx_en;
    wire [7:0] tx_data;
    wire [1:0] txd;
    wire [31:0] tx_frames, rx_udp_ok, arp_ok, dropped, last_src_ip;
    wire [15:0] last_udp_len;
    wire [63:0] last_head;

    lan_min #(.HELLO_INTERVAL(28'd50000)) lan(
        clk, reset, enable, dv, d, err,
        tx_start, tx_data, tx_valid, tx_last, tx_accept, tx_busy, tx_done,
        tx_frames, rx_udp_ok, arp_ok, dropped, last_src_ip, last_udp_len, last_head);
    rmii_tx txm(clk, reset || !enable, tx_start, tx_busy, tx_done,
                tx_data, tx_valid, tx_last, tx_accept, tx_en, txd);
    // Proven reference sniffer on the same pins; splits stimulus vs RTL blame.
    wire [31:0] ref_good, ref_bad, ref_act;
    wire [15:0] ref_type, ref_len;
    rmii_rx refmon(clk, reset, enable, dv, d, err,
                   ref_good, ref_bad, ref_act, ref_type, ref_len);

    localparam [47:0] FPGA_MAC = 48'h02544F4D4154;
    localparam [31:0] FPGA_IP = 32'hC0A8010A; // 192.168.1.10
    localparam [47:0] LAP_MAC = 48'h02AABBCCDDEE;
    localparam [31:0] LAP_IP = 32'hC0A80114;  // 192.168.1.20

    reg [7:0] txpkt [0:1100]; // frame under test (no FCS)
    reg [7:0] rxpkt [0:1100]; // captured wire frame (no preamble/SFD)
    integer txlen, rxlen;

    function [31:0] crc_byte;
        input [31:0] c; input [7:0] b;
        reg [31:0] x; integer k;
        begin
            x = c;
            for (k = 0; k < 8; k = k + 1) x = (x >> 1) ^ ((x[0] ^ b[k]) ? 32'hedb88320 : 0);
            crc_byte = x;
        end
    endfunction

    function [15:0] ip_sum;
        input [31:0] sip; input [31:0] dip; input [15:0] tot; input [15:0] id;
        reg [31:0] s;
        begin
            s = 32'h4500 + tot + id + 32'h4000 + 32'h4011 + sip[31:16] + sip[15:0] + dip[31:16] + dip[15:0];
            s = (s & 32'hffff) + (s >> 16);
            s = (s & 32'hffff) + (s >> 16);
            ip_sum = ~s[15:0];
        end
    endfunction

    task dibit(input [1:0] v, input on);
        begin @(negedge clk); d = v; dv = on; end
    endtask

    // Send txpkt[0..txlen-1] with valid FCS (corrupt flips one payload bit).
    task send_frame(input corrupt);
        integer a, b;
        reg [31:0] c;
        reg [7:0] by;
        begin
            c = 32'hffffffff;
            for (a = 0; a < txlen; a = a + 1) c = crc_byte(c, txpkt[a]);
            for (a = 0; a < 7; a = a + 1)
                for (b = 0; b < 4; b = b + 1) dibit(1, 1);
            for (b = 0; b < 4; b = b + 1) dibit((8'hd5 >> (b * 2)) & 3, 1);
            for (a = 0; a < txlen; a = a + 1) begin
                by = txpkt[a];
                if (corrupt && a == 10) by = by ^ 8'h01;
                for (b = 0; b < 4; b = b + 1) dibit((by >> (b * 2)) & 3, 1);
            end
            // FCS = ~crc (final-xor) little-endian over the uncorrupted
            // payload, so `corrupt` breaks the residue check.
            for (a = 0; a < 4; a = a + 1) begin
                case (a)
                    0: by = (~c) & 8'hff;
                    1: by = ((~c) >> 8) & 8'hff;
                    2: by = ((~c) >> 16) & 8'hff;
                    default: by = ((~c) >> 24) & 8'hff;
                endcase
                for (b = 0; b < 4; b = b + 1) dibit((by >> (b * 2)) & 3, 1);
            end
            dibit(0, 0); err = 0; dibit(0, 0);
            repeat (8) @(negedge clk);
        end
    endtask

    // Wait up to `budget` clocks for tx_en; capture frame; returns 1 if got one.
    task expect_tx(input integer budget, output gotit);
        integer t, b, n;
        reg [1:0] dib;
        begin
            gotit = 0;
            t = 0;
            while (!tx_en && t < budget) begin @(negedge clk); t = t + 1; end
            if (!tx_en) begin gotit = 0; end
            else begin
                gotit = 1;
                repeat (32) @(negedge clk); // skip preamble+SFD
                n = 0;
                while (tx_en) begin
                    rxpkt[n] = 0;
                    for (b = 0; b < 4; b = b + 1) begin
                        dib = txd;
                        rxpkt[n] = rxpkt[n] | (dib << (b * 2));
                        if (b < 3 || tx_en) @(negedge clk);
                    end
                    n = n + 1;
                    if (n > 1100) begin $display("FAIL capture runaway"); $fatal(1); end
                end
                rxlen = n;
            end
        end
    endtask

    task expect_silence(input integer clocks);
        integer t;
        begin
            t = 0;
            while (t < clocks) begin
                @(negedge clk);
                if (tx_en) begin $display("FAIL unexpected TX at %0d", t); $fatal(1); end
                t = t + 1;
            end
        end
    endtask

    task build_arp_req;
        integer a;
        begin
            txpkt[0]=8'hff; txpkt[1]=8'hff; txpkt[2]=8'hff; txpkt[3]=8'hff; txpkt[4]=8'hff; txpkt[5]=8'hff;
            txpkt[6]=8'h02; txpkt[7]=8'haa; txpkt[8]=8'hbb; txpkt[9]=8'hcc; txpkt[10]=8'hdd; txpkt[11]=8'hee;
            txpkt[12]=8'h08; txpkt[13]=8'h06;
            txpkt[14]=8'h00; txpkt[15]=8'h01; txpkt[16]=8'h08; txpkt[17]=8'h00;
            txpkt[18]=8'h06; txpkt[19]=8'h04; txpkt[20]=8'h00; txpkt[21]=8'h01;
            txpkt[22]=8'h02; txpkt[23]=8'haa; txpkt[24]=8'hbb; txpkt[25]=8'hcc; txpkt[26]=8'hdd; txpkt[27]=8'hee;
            txpkt[28]=8'hc0; txpkt[29]=8'ha8; txpkt[30]=8'h01; txpkt[31]=8'h14;
            txpkt[32]=8'h00; txpkt[33]=8'h00; txpkt[34]=8'h00; txpkt[35]=8'h00; txpkt[36]=8'h00; txpkt[37]=8'h00;
            txpkt[38]=8'hc0; txpkt[39]=8'ha8; txpkt[40]=8'h01; txpkt[41]=8'h0a;
            for (a = 42; a < 60; a = a + 1) txpkt[a] = 8'h00; // explicit pad, no X
            txlen = 60; // padded (42 real + 18 zero)
        end
    endtask

    // UDP laptop -> FPGA with `plen` payload bytes from pattern seed.
    task build_udp(input [15:0] dport, input integer plen, input [7:0] seed);
        integer a;
        reg [15:0] tot, c;
        begin
            txpkt[0]=FPGA_MAC[47:40]; txpkt[1]=FPGA_MAC[39:32]; txpkt[2]=FPGA_MAC[31:24];
            txpkt[3]=FPGA_MAC[23:16]; txpkt[4]=FPGA_MAC[15:8]; txpkt[5]=FPGA_MAC[7:0];
            txpkt[6]=8'h02; txpkt[7]=8'haa; txpkt[8]=8'hbb; txpkt[9]=8'hcc; txpkt[10]=8'hdd; txpkt[11]=8'hee;
            txpkt[12]=8'h08; txpkt[13]=8'h00;
            tot = 16'd28 + plen;
            txpkt[14]=8'h45; txpkt[15]=8'h00; txpkt[16]=tot[15:8]; txpkt[17]=tot[7:0];
            txpkt[18]=8'h12; txpkt[19]=8'h34; txpkt[20]=8'h40; txpkt[21]=8'h00;
            txpkt[22]=8'h40; txpkt[23]=8'h11;
            c = ip_sum(LAP_IP, FPGA_IP, tot, 16'h1234);
            txpkt[24]=c[15:8]; txpkt[25]=c[7:0];
            txpkt[26]=8'hc0; txpkt[27]=8'ha8; txpkt[28]=8'h01; txpkt[29]=8'h14;
            txpkt[30]=8'hc0; txpkt[31]=8'ha8; txpkt[32]=8'h01; txpkt[33]=8'h0a;
            txpkt[34]=8'h04; txpkt[35]=8'hd2; // sport 1234
            txpkt[36]=dport[15:8]; txpkt[37]=dport[7:0];
            txpkt[38]=(16'd8+plen)>>8; txpkt[39]=(16'd8+plen)&8'hff;
            txpkt[40]=8'h00; txpkt[41]=8'h00;
            for (a = 0; a < plen; a = a + 1) txpkt[42+a] = seed + a;
            for (a = 42 + plen; a < 60; a = a + 1) txpkt[a] = 8'h00; // pad, no X
            txlen = 42 + plen;
            if (txlen < 60) txlen = 60; // pad
        end
    endtask

    task verify_ip;
        input integer off; // offset of IP header in rxpkt
        input [31:0] esip; input [31:0] edip; input [15:0] etot; input [15:0] eid;
        reg [15:0] want;
        begin
            want = ip_sum(esip, edip, etot, eid);
            if ({rxpkt[off+10], rxpkt[off+11]} !== want) begin
                $display("FAIL ip csum got %h%h want %h", rxpkt[off+10], rxpkt[off+11], want);
                $fatal(1);
            end
        end
    endtask

    reg gotit;
    integer a, plen;

    initial begin
        fork
            begin
                repeat (4) @(negedge clk); reset = 0; enable = 1;
                repeat (10) @(negedge clk);

                // T1: ARP request for us -> ARP reply.
                // Fork: the reply starts before send_frame returns.
                build_arp_req();
                fork
                    send_frame(0);
                    expect_tx(3000, gotit);
                join
                wait (!tx_busy);
                repeat (2) @(negedge clk);
                if (rxlen != 64) begin $display("FAIL t1 len %0d", rxlen); $fatal(1); end
                if ({rxpkt[0],rxpkt[1],rxpkt[2],rxpkt[3],rxpkt[4],rxpkt[5]} !== LAP_MAC) begin $display("FAIL t1 dstmac got %h%h%h%h%h%h len=%0d", rxpkt[0],rxpkt[1],rxpkt[2],rxpkt[3],rxpkt[4],rxpkt[5], rxlen); $fatal(1); end
                if ({rxpkt[6],rxpkt[7],rxpkt[8],rxpkt[9],rxpkt[10],rxpkt[11]} !== FPGA_MAC) begin $display("FAIL t1 srcmac"); $fatal(1); end
                if ({rxpkt[20],rxpkt[21]} !== 16'h0002) begin $display("FAIL t1 opcode"); $fatal(1); end
                if ({rxpkt[28],rxpkt[29],rxpkt[30],rxpkt[31]} !== FPGA_IP) begin $display("FAIL t1 sip"); $fatal(1); end
                if ({rxpkt[38],rxpkt[39],rxpkt[40],rxpkt[41]} !== LAP_IP) begin $display("FAIL t1 tip"); $fatal(1); end
                if (arp_ok !== 1) begin $display("FAIL t1 counter %0d", arp_ok); $fatal(1); end
                $display("PASS t1 ARP reply");

                // T2: UDP echo, 9B payload.
                build_udp(16'd5000, 9, 8'h68); // "h..p"
                fork
                    send_frame(0);
                    expect_tx(4000, gotit);
                join
                if (!gotit) begin $display("FAIL t2 no echo"); $fatal(1); end
                if ({rxpkt[36],rxpkt[37]} !== 16'd1234) begin $display("FAIL t2 dport"); $fatal(1); end
                if ({rxpkt[34],rxpkt[35]} !== 16'd5000) begin $display("FAIL t2 sport"); $fatal(1); end
                if ({rxpkt[38],rxpkt[39]} !== 16'd17) begin $display("FAIL t2 ulen"); $fatal(1); end
                for (a = 0; a < 9; a = a + 1)
                    if (rxpkt[42+a] !== (8'h68 + a)) begin $display("FAIL t2 payload %0d", a); $fatal(1); end
                verify_ip(14, FPGA_IP, LAP_IP, 16'd37, lan.ip_id - 1);
                if (rx_udp_ok !== 1) begin $display("FAIL t2 counter"); $fatal(1); end
                if (last_src_ip !== LAP_IP) begin $display("FAIL t2 srcip latch"); $fatal(1); end
                $display("PASS t2 UDP echo 9B");

                // T3: wrong port -> silence.
                build_udp(16'd9999, 9, 8'h41);
                send_frame(0);
                expect_silence(2500);
                if (rx_udp_ok !== 1) begin $display("FAIL t3 counter moved"); $fatal(1); end
                $display("PASS t3 wrong-port silence");

                // T4: bad CRC -> silence.
                build_udp(16'd5000, 9, 8'h42);
                send_frame(1);
                expect_silence(2500);
                if (rx_udp_ok !== 1) begin $display("FAIL t4 counter moved"); $fatal(1); end
                $display("PASS t4 bad-CRC silence");

                // T5: long echo, 100B (multi-cycle copy + no pad).
                build_udp(16'd5000, 100, 8'h30);
                fork
                    send_frame(0);
                    expect_tx(6000, gotit);
                join
                if (!gotit) begin $display("FAIL t5 no echo"); $fatal(1); end
                if (rxlen !== 142 + 4) begin $display("FAIL t5 len %0d", rxlen); $fatal(1); end
                for (a = 0; a < 100; a = a + 1)
                    if (rxpkt[42+a] !== ((8'h30 + a) & 8'hff)) begin $display("FAIL t5 payload %0d", a); $fatal(1); end
                $display("PASS t5 UDP echo 100B");

                // T6: auto-HELLO broadcast.
                expect_tx(60000, gotit);
                if (!gotit) begin $display("FAIL t6 no hello"); $fatal(1); end
                if ({rxpkt[0],rxpkt[1],rxpkt[2],rxpkt[3],rxpkt[4],rxpkt[5]} !== 48'hffffffffffff) begin $display("FAIL t6 bcast"); $fatal(1); end
                if ({rxpkt[30],rxpkt[31],rxpkt[32],rxpkt[33]} !== 32'hffffffff) begin $display("FAIL t6 dstip"); $fatal(1); end
                if (rxpkt[42] !== 8'h54 || rxpkt[43] !== 8'h4f || rxpkt[48] !== 8'h20) begin $display("FAIL t6 magic"); $fatal(1); end
                $display("PASS t6 auto-HELLO");
                wait (!tx_busy);
                repeat (2) @(negedge clk);
                if (tx_frames !== 4) begin $display("FAIL tx count %0d", tx_frames); $fatal(1); end
                $display("PASS ECHO: arp, echo 9/100B, port/crc silence, hello (drops=%0d)", dropped);
                $finish;
            end
            begin
                repeat (400000) @(posedge clk);
                $display("FAIL global watchdog");
                $fatal(1);
            end
        join
    end
endmodule
