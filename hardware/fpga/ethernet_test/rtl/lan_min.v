// Minimal LAN endpoint for Tomato Ethernet bring-up. Static config only:
// no DHCP, no TCP, no TLS. Answers ARP for FPGA_IP, echoes UDP datagrams
// to UDP_PORT back to sender, and broadcasts a HELLO every ~5s so the
// laptop discovers us without any manual ARP. All traffic is small chat
// payloads; the laptop-side Python gateway (tools/tomato_lan.py) does the
// heavy lifting (cloud, auth, history). One outstanding TX; new requests
// while busy are dropped and counted (senders retry).
//
// Timing (50MHz net_clk, checked against an honest target): rx_buf/tx_buf
// are block RAM with SYNCHRONOUS reads only. Header decode runs off a
// register snapshot swept sequentially out of rx_buf (2 cycles/byte), the
// echo copy runs read-addr -> read-data -> write (3 phases), and the TX
// streamer prefetches one byte ahead. No cycle chains RAM address, RAM
// output and the next RAM port together.
module lan_min #(
    parameter [47:0] FPGA_MAC = 48'h02544F4D4154, // 02:54:4F:4D:41:54 locally administered
    parameter [31:0] FPGA_IP = 32'hC0A8010A,      // 192.168.1.10; edit + rebuild if router differs
    parameter [15:0] UDP_PORT = 16'd5000,
    parameter [27:0] HELLO_INTERVAL = 28'd250000000 // 5s @50MHz net_clk
)(
    input clk,
    input reset,
    input enable,               // link && 100M, same gate as rmii_rx
    input crs_dv,
    input [1:0] rxd,
    input rxerr,
    // to rmii_tx (feeder contract: first byte preloaded before tx_start pulse)
    output reg tx_start,
    output reg [7:0] tx_data,
    output reg tx_valid,
    output reg tx_last,
    input tx_accept,
    input tx_busy,
    input tx_done,
    // status for UART/HDMI diagnostics
    output reg [31:0] tx_frames,
    output reg [31:0] rx_udp_ok,
    output reg [31:0] arp_ok,
    output reg [31:0] dropped,
    output reg [31:0] last_src_ip,
    output reg [15:0] last_udp_len,
    output reg [63:0] last_payload_head
);
    // ---- RX sniffer: preamble/SFD + byte capture + CRC (mirrors rmii_rx) ----
    reg active = 0, low_seen = 0, in_frame = 0, error_seen = 0, crc_good = 0, oversize = 0;
    reg [5:0] preamble = 0;
    reg [1:0] phase = 0;
    reg [7:0] shift = 0;
    reg [15:0] count = 0, valid_length = 0;
    reg [31:0] crc = 32'hffffffff;
    reg [31:0] rx_ip_sum = 0, rx_udp_sum = 0;
    reg [15:0] rx_ip_total = 0, rx_udp_wire_len = 0;
    (* ram_style = "block" *) reg [7:0] rx_buf [0:1023];
    wire [7:0] octet = {rxd, shift[7:2]};
    reg frame_ok = 0;
    reg [15:0] frame_len = 0;

    function [31:0] crc_byte;
        input [31:0] c;
        input [7:0] b;
        reg [31:0] x;
        integer i;
        begin
            x = c;
            for (i = 0; i < 8; i = i + 1)
                x = (x >> 1) ^ ((x[0] ^ b[i]) ? 32'hedb88320 : 0);
            crc_byte = x;
        end
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            active <= 0; low_seen <= 0; in_frame <= 0; error_seen <= 0;
            crc_good <= 0; oversize <= 0; preamble <= 0; phase <= 0;
            count <= 0; valid_length <= 0; frame_ok <= 0; frame_len <= 0;
        end else if (!enable) begin
            active <= 0; in_frame <= 0; low_seen <= 0; preamble <= 0; frame_ok <= 0;
        end else if (!crs_dv && low_seen) begin
            frame_ok <= 0;
            if (active) begin
                if (in_frame && crc_good && count == valid_length && valid_length <= 1024 &&
                    valid_length >= 64 && !error_seen && !oversize) begin
                    frame_ok <= 1;
                    frame_len <= valid_length;
                end
            end
            active <= 0; in_frame <= 0; preamble <= 0; phase <= 0;
            crc_good <= 0; error_seen <= 0; oversize <= 0; count <= 0;
        end else begin
            frame_ok <= 0;
            low_seen <= !crs_dv;
            if (crs_dv && !active) active <= 1;
            if (crs_dv || active) begin
                if (rxerr) error_seen <= 1;
                if (!in_frame) begin
                    if (rxd == 1) begin
                        if (preamble != 63) preamble <= preamble + 1;
                    end else if (rxd == 3 && preamble >= 15) begin
                        in_frame <= 1; phase <= 0; count <= 0; crc <= 32'hffffffff;
                        rx_ip_sum <= 0; rx_udp_sum <= 0;
                        rx_ip_total <= 0; rx_udp_wire_len <= 0;
                        oversize <= 0;
                    end else preamble <= 0;
                end else begin
                    shift <= octet; phase <= phase + 1;
                    if (phase == 3) begin
                        if (count < 1024) rx_buf[count] <= octet;
                        else oversize <= 1;
                        // Accumulate exact on-wire IPv4 and UDP words while
                        // bytes are already streaming through this clock.
                        // Even offsets are the high byte of each network word.
                        if (count >= 14 && count < 34)
                            rx_ip_sum <= rx_ip_sum +
                                (count[0] ? {24'b0, octet} : {16'b0, octet, 8'b0});
                        if ((count >= 34 && count <= 39) ||
                            (count >= 40 && count < 34 + rx_udp_wire_len))
                            rx_udp_sum <= rx_udp_sum +
                                (count[0] ? {24'b0, octet} : {16'b0, octet, 8'b0});
                        if (count == 16) rx_ip_total[15:8] <= octet;
                        if (count == 17) rx_ip_total[7:0] <= octet;
                        if (count == 38) rx_udp_wire_len[15:8] <= octet;
                        if (count == 39) rx_udp_wire_len[7:0] <= octet;
                        if (count != 65535) count <= count + 1;
                        crc <= crc_byte(crc, octet);
                        if (count >= 63 && crc_byte(crc, octet) == 32'hdebb20e3) begin
                            crc_good <= 1; valid_length <= count + 1;
                        end
                    end
                end
            end
        end
    end

    // ---- header snapshot: swept sequentially from block RAM, 2 cycles/byte.
    // Bytes 0..49 cover eth + ARP/IP/UDP headers + first 8 payload bytes.
    // Overlapping ARP/IP views of the same offsets are latched together. ----
    reg [47:0] h_dstmac = 0, h_srcmac = 0;
    reg [15:0] h_etype = 0;
    reg [15:0] h_arp_hw = 0, h_arp_proto = 0, h_arp_op = 0;
    reg [7:0] h_arp_hlen = 0, h_arp_plen = 0;
    reg [31:0] h_arp_sip = 0, h_arp_tip = 0;
    reg [7:0] h_ip_vihl = 0, h_ip_proto = 0;
    reg [15:0] h_ip_frag = 0, h_udp_csum = 0;
    reg [31:0] h_ip_sip = 0, h_ip_dip = 0;
    reg [15:0] h_udp_sport = 0, h_udp_dport = 0, h_udp_len = 0;
    reg [63:0] h_pay8 = 0;
    reg [5:0] hdr_idx = 0;
    // No phase bit: the WAIT/CAP state pair itself sequences address/data.
    // Invariant on S_HDR_CAP / S_CPY_CAP entry: rx_dout == RAM[pointer].
    reg [9:0] rx_raddr = 0;    // shared sync-read address into rx_buf
    reg [7:0] rx_dout = 0;     // shared sync-read data out of rx_buf

    wire h_bcast = (h_dstmac == 48'hffffffffffff);
    wire h_for_us = (h_dstmac == FPGA_MAC) || h_bcast;
    wire arp_for_us = (h_etype == 16'h0806) &&
        (h_arp_hw == 16'h0001) && (h_arp_proto == 16'h0800) &&
        (h_arp_hlen == 8'd6) && (h_arp_plen == 8'd4) &&
        (h_arp_op == 16'h0001) && (h_arp_tip == FPGA_IP);
    function [15:0] fold_sum;
        input [31:0] sum;
        reg [31:0] folded;
        begin
            folded = (sum & 32'hffff) + (sum >> 16);
            folded = (folded & 32'hffff) + (folded >> 16);
            folded = (folded & 32'hffff) + (folded >> 16);
            fold_sum = folded[15:0];
        end
    endfunction

    wire [31:0] udp_checked_sum = rx_udp_sum +
        h_ip_sip[31:16] + h_ip_sip[15:0] +
        h_ip_dip[31:16] + h_ip_dip[15:0] +
        16'h0011 + h_udp_len;
    wire ip_checksum_ok = (fold_sum(rx_ip_sum) == 16'hffff);
    wire udp_checksum_ok = (h_udp_csum == 0) ||
        (fold_sum(udp_checked_sum) == 16'hffff);
    wire ipv4_udp =
        (h_etype == 16'h0800) && (h_ip_vihl == 8'h45) && (h_ip_proto == 8'd17) &&
        ((h_ip_frag & 16'hbfff) == 0) && ip_checksum_ok && udp_checksum_ok &&
        ((h_ip_dip == FPGA_IP) || (h_ip_dip == 32'hffffffff)) &&
        (h_udp_dport == UDP_PORT);
    // 34 = eth 14 + ip 20; udp_len covers UDP header + payload.
    wire udp_ok_shape = ipv4_udp && (h_udp_len >= 16'd8) && (h_udp_len <= 16'd530) &&
        (rx_ip_total == 16'd20 + h_udp_len) &&
        (16'd34 + h_udp_len <= frame_len);

    // ---- TX frame buffer: single-cycle header builds write many bytes at
    // once, so this stays distributed (sync prefetch read keeps it fast).
    // rx_buf above carries the critical path and is block RAM. ----
    reg [7:0] tx_buf [0:1023];
    reg [10:0] tx_len = 0;   // payload bytes in tx_buf (no FCS)
    reg [10:0] tx_ri = 0;    // streamer index
    reg [9:0] tx_ra = 0;     // prefetch read address (follows tx_ri)
    reg [15:0] ip_id = 0;
    reg [31:0] hello_ctr = 0;
    reg [27:0] hello_tmr = HELLO_INTERVAL; // first hello one interval after link

    function [15:0] ip_checksum;
        input [31:0] sip;
        input [31:0] dip;
        input [15:0] totlen;
        input [15:0] ident;
        reg [31:0] s;
        begin
            s = 32'h4500 + totlen + ident + 32'h4000 + 32'h4011 + sip[31:16] + sip[15:0] + dip[31:16] + dip[15:0];
            s = (s & 32'hffff) + (s >> 16);
            s = (s & 32'hffff) + (s >> 16);
            ip_checksum = ~s[15:0];
        end
    endfunction

    function [7:0] hexchar;
        input [3:0] nib;
        begin
            hexchar = nib < 10 ? 8'd48 + nib : 8'd55 + nib;
        end
    endfunction

    localparam S_RX = 0, S_HDR_WAIT = 1, S_HDR_CAP = 2, S_DISP = 3, S_ARP = 4,
               S_UHD = 5, S_CPY_WAIT = 6, S_CPY_CAP = 7, S_CPY_WR = 8,
               S_HELLO = 9, S_KICK = 10, S_TXWAIT = 11;
    reg [3:0] state = S_RX;
    reg [1:0] pend_kind = 0; // 1 arp, 2 echo, 3 hello (kind being transmitted)
    // Two/three-phase copy pointers: addresses are registers, payload data
    // crosses through cpy_rdata. No cycle chains RAM ports together.
    reg [10:0] cpy_ptr = 42;   // rx_buf read pointer (payload starts at 42)
    reg [10:0] cpy_wptr = 42;  // tx_buf write pointer
    reg [10:0] cpy_cnt = 0;    // bytes copied so far
    reg [10:0] cpy_n = 0;      // bytes to copy
    reg [7:0] cpy_rdata = 0;

    // Echo sizes derived from the latched request (IHL=5 so payload is at 42).
    wire [15:0] echo_pay = ((h_udp_len - 16'd8) > 16'd522) ? 16'd522 : (h_udp_len - 16'd8);
    wire [15:0] echo_tlen = 16'd28 + echo_pay;   // IP total: 20 + 8 + payload
    wire [10:0] echo_n = echo_pay[10:0];
    wire [15:0] echo_ulen = 16'd8 + echo_pay;    // UDP length field
    wire [15:0] echo_csum = ip_checksum(FPGA_IP, h_ip_sip, echo_tlen, ip_id);
    wire [15:0] hello_csum = ip_checksum(FPGA_IP, 32'hffffffff, 16'd61, ip_id);

    // TX prefetch: tx_data/tx_last trail tx_ri by the BRAM read latency.
    // tx_ri only advances on accepts (4+ cycles apart) and the first byte is
    // needed ~33 cycles after S_KICK, so the pair is always settled in time.
    always @(posedge clk) begin
        if (reset || !enable) begin
            tx_ra <= 0; tx_data <= 0; tx_last <= 0;
        end else begin
            tx_ra <= tx_ri[9:0];
            tx_data <= tx_buf[tx_ra];
            tx_last <= (tx_ra == tx_len[9:0] - 10'd1);
        end
    end

    // Shared sync read port into rx_buf (header sweep and echo copy take
    // turns; they never run in the same cycle).
    always @(posedge clk) begin
        if (reset || !enable) rx_dout <= 0;
        else rx_dout <= rx_buf[rx_raddr];
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= S_RX; pend_kind <= 0;
            tx_start <= 0; tx_valid <= 0;
            tx_ri <= 0; tx_len <= 0;
            cpy_ptr <= 42; cpy_wptr <= 42; cpy_cnt <= 0; cpy_n <= 0;
            cpy_rdata <= 0;
            rx_raddr <= 0; hdr_idx <= 0;
            ip_id <= 0; hello_ctr <= 0;
            hello_tmr <= HELLO_INTERVAL;
            tx_frames <= 0; rx_udp_ok <= 0; arp_ok <= 0; dropped <= 0;
            last_src_ip <= 0; last_udp_len <= 0; last_payload_head <= 0;
            h_dstmac <= 0; h_srcmac <= 0; h_etype <= 0;
            h_arp_hw <= 0; h_arp_proto <= 0; h_arp_op <= 0;
            h_arp_hlen <= 0; h_arp_plen <= 0; h_arp_sip <= 0; h_arp_tip <= 0;
            h_ip_vihl <= 0; h_ip_proto <= 0; h_ip_frag <= 0;
            h_ip_sip <= 0; h_ip_dip <= 0;
            h_udp_sport <= 0; h_udp_dport <= 0; h_udp_len <= 0;
            h_udp_csum <= 0; h_pay8 <= 0;
        end else if (!enable) begin
            state <= S_RX; tx_start <= 0; tx_valid <= 0; pend_kind <= 0;
            hello_tmr <= HELLO_INTERVAL;
        end else begin
            tx_start <= 0;
            // A frame that completes while the builder is busy is ignored
            // on the wire level (buffer is single); count it so the UART
            // dropped counter explains missing echoes. Senders retry.
            if (frame_ok && state != S_RX) dropped <= dropped + 1;
            // Hello timer runs whenever idle; skipped (not queued) if TX busy.
            if (hello_tmr == 0) begin
                hello_tmr <= HELLO_INTERVAL;
                if (state == S_RX && !tx_busy && !frame_ok) begin
                    state <= S_HELLO;
                end
            end else if (state == S_RX && !tx_busy) begin
                hello_tmr <= hello_tmr - 1;
            end

            case (state)
                S_RX: begin
                    tx_valid <= 0;
                    if (frame_ok) begin
                        // Present byte 0 now; S_HDR_WAIT lets BRAM answer.
                        hdr_idx <= 0; rx_raddr <= 0;
                        state <= S_HDR_WAIT;
                    end
                end
                S_HDR_WAIT: begin
                    // rx_dout == rx_buf[hdr_idx] from this edge on.
                    state <= S_HDR_CAP;
                end
                S_HDR_CAP: begin
                        // One byte per step into the snapshot (see map above).
                        case (hdr_idx)
                            0: h_dstmac[47:40] <= rx_dout;
                            1: h_dstmac[39:32] <= rx_dout;
                            2: h_dstmac[31:24] <= rx_dout;
                            3: h_dstmac[23:16] <= rx_dout;
                            4: h_dstmac[15:8] <= rx_dout;
                            5: h_dstmac[7:0] <= rx_dout;
                            6: h_srcmac[47:40] <= rx_dout;
                            7: h_srcmac[39:32] <= rx_dout;
                            8: h_srcmac[31:24] <= rx_dout;
                            9: h_srcmac[23:16] <= rx_dout;
                            10: h_srcmac[15:8] <= rx_dout;
                            11: h_srcmac[7:0] <= rx_dout;
                            12: h_etype[15:8] <= rx_dout;
                            13: h_etype[7:0] <= rx_dout;
                            14: begin h_arp_hw[15:8] <= rx_dout; h_ip_vihl <= rx_dout; end
                            15: h_arp_hw[7:0] <= rx_dout;
                            16: h_arp_proto[15:8] <= rx_dout;
                            17: h_arp_proto[7:0] <= rx_dout;
                            18: h_arp_hlen <= rx_dout;
                            19: h_arp_plen <= rx_dout;
                            20: begin h_arp_op[15:8] <= rx_dout; h_ip_frag[15:8] <= rx_dout; end
                            21: begin h_arp_op[7:0] <= rx_dout; h_ip_frag[7:0] <= rx_dout; end
                            23: h_ip_proto <= rx_dout; // (22..27 are sender MAC; unneeded)
                            26: h_ip_sip[31:24] <= rx_dout;
                            27: h_ip_sip[23:16] <= rx_dout;
                            28: begin h_ip_sip[15:8] <= rx_dout; h_arp_sip[31:24] <= rx_dout; end
                            29: begin h_ip_sip[7:0] <= rx_dout; h_arp_sip[23:16] <= rx_dout; end
                            30: begin h_ip_dip[31:24] <= rx_dout; h_arp_sip[15:8] <= rx_dout; end
                            31: begin h_ip_dip[23:16] <= rx_dout; h_arp_sip[7:0] <= rx_dout; end
                            32: h_ip_dip[15:8] <= rx_dout;
                            33: h_ip_dip[7:0] <= rx_dout;
                            34: h_udp_sport[15:8] <= rx_dout;
                            35: h_udp_sport[7:0] <= rx_dout;
                            36: h_udp_dport[15:8] <= rx_dout;
                            37: h_udp_dport[7:0] <= rx_dout;
                            38: begin h_udp_len[15:8] <= rx_dout; h_arp_tip[31:24] <= rx_dout; end
                            39: begin h_udp_len[7:0] <= rx_dout; h_arp_tip[23:16] <= rx_dout; end
                            40: begin h_arp_tip[15:8] <= rx_dout; h_udp_csum[15:8] <= rx_dout; end
                            41: begin h_arp_tip[7:0] <= rx_dout; h_udp_csum[7:0] <= rx_dout; end
                            default: h_pay8 <= {h_pay8[55:0], rx_dout};
                        endcase
                        if (hdr_idx == 49) begin
                            state <= S_DISP;
                        end else begin
                            hdr_idx <= hdr_idx + 1;
                            rx_raddr <= hdr_idx + 6'd1;
                            state <= S_HDR_WAIT;
                        end
                end
                S_DISP: begin
                    // Snapshot is stable; decode is small register logic.
                    if (arp_for_us) begin
                        if (tx_busy) dropped <= dropped + 1;
                        else state <= S_ARP;
                    end else if (udp_ok_shape && h_for_us) begin
                        last_src_ip <= h_ip_sip;
                        last_udp_len <= h_udp_len;
                        last_payload_head <= h_pay8;
                        rx_udp_ok <= rx_udp_ok + 1;
                        if (tx_busy) dropped <= dropped + 1;
                        else state <= S_UHD;
                    end else begin
                        state <= S_RX;
                    end
                end
                S_ARP: begin
                    // 14B eth + 28B ARP reply.
                    tx_buf[0] <= h_srcmac[47:40]; tx_buf[1] <= h_srcmac[39:32];
                    tx_buf[2] <= h_srcmac[31:24]; tx_buf[3] <= h_srcmac[23:16];
                    tx_buf[4] <= h_srcmac[15:8];  tx_buf[5] <= h_srcmac[7:0];
                    tx_buf[6] <= FPGA_MAC[47:40]; tx_buf[7] <= FPGA_MAC[39:32];
                    tx_buf[8] <= FPGA_MAC[31:24]; tx_buf[9] <= FPGA_MAC[23:16];
                    tx_buf[10] <= FPGA_MAC[15:8]; tx_buf[11] <= FPGA_MAC[7:0];
                    tx_buf[12] <= 8'h08; tx_buf[13] <= 8'h06;
                    tx_buf[14] <= 8'h00; tx_buf[15] <= 8'h01;
                    tx_buf[16] <= 8'h08; tx_buf[17] <= 8'h00;
                    tx_buf[18] <= 8'h06; tx_buf[19] <= 8'h04;
                    tx_buf[20] <= 8'h00; tx_buf[21] <= 8'h02; // reply
                    tx_buf[22] <= FPGA_MAC[47:40]; tx_buf[23] <= FPGA_MAC[39:32];
                    tx_buf[24] <= FPGA_MAC[31:24]; tx_buf[25] <= FPGA_MAC[23:16];
                    tx_buf[26] <= FPGA_MAC[15:8];  tx_buf[27] <= FPGA_MAC[7:0];
                    tx_buf[28] <= FPGA_IP[31:24]; tx_buf[29] <= FPGA_IP[23:16];
                    tx_buf[30] <= FPGA_IP[15:8];  tx_buf[31] <= FPGA_IP[7:0];
                    tx_buf[32] <= h_srcmac[47:40]; tx_buf[33] <= h_srcmac[39:32];
                    tx_buf[34] <= h_srcmac[31:24]; tx_buf[35] <= h_srcmac[23:16];
                    tx_buf[36] <= h_srcmac[15:8];  tx_buf[37] <= h_srcmac[7:0];
                    tx_buf[38] <= h_arp_sip[31:24]; tx_buf[39] <= h_arp_sip[23:16];
                    tx_buf[40] <= h_arp_sip[15:8];  tx_buf[41] <= h_arp_sip[7:0];
                    tx_len <= 42;
                    pend_kind <= 1;
                    state <= S_KICK;
                end
                S_UHD: begin
                    // Headers for echo; payload copied in S_CPY_*.
                    tx_buf[0] <= h_srcmac[47:40]; tx_buf[1] <= h_srcmac[39:32];
                    tx_buf[2] <= h_srcmac[31:24]; tx_buf[3] <= h_srcmac[23:16];
                    tx_buf[4] <= h_srcmac[15:8];  tx_buf[5] <= h_srcmac[7:0];
                    tx_buf[6] <= FPGA_MAC[47:40]; tx_buf[7] <= FPGA_MAC[39:32];
                    tx_buf[8] <= FPGA_MAC[31:24]; tx_buf[9] <= FPGA_MAC[23:16];
                    tx_buf[10] <= FPGA_MAC[15:8]; tx_buf[11] <= FPGA_MAC[7:0];
                    tx_buf[12] <= 8'h08; tx_buf[13] <= 8'h00;
                    tx_buf[14] <= 8'h45; tx_buf[15] <= 8'h00;
                    tx_buf[16] <= echo_tlen[15:8];
                    tx_buf[17] <= echo_tlen[7:0];
                    tx_buf[18] <= ip_id[15:8]; tx_buf[19] <= ip_id[7:0];
                    tx_buf[20] <= 8'h40; tx_buf[21] <= 8'h00; // DF, frag 0
                    tx_buf[22] <= 8'h40; tx_buf[23] <= 8'h11; // TTL 64, UDP
                    tx_buf[24] <= echo_csum[15:8]; tx_buf[25] <= echo_csum[7:0];
                    tx_buf[26] <= FPGA_IP[31:24]; tx_buf[27] <= FPGA_IP[23:16];
                    tx_buf[28] <= FPGA_IP[15:8];  tx_buf[29] <= FPGA_IP[7:0];
                    tx_buf[30] <= h_ip_sip[31:24]; tx_buf[31] <= h_ip_sip[23:16];
                    tx_buf[32] <= h_ip_sip[15:8];  tx_buf[33] <= h_ip_sip[7:0];
                    tx_buf[34] <= UDP_PORT[15:8]; tx_buf[35] <= UDP_PORT[7:0];
                    tx_buf[36] <= h_udp_sport[15:8]; tx_buf[37] <= h_udp_sport[7:0];
                    tx_buf[38] <= echo_ulen[15:8];
                    tx_buf[39] <= echo_ulen[7:0];
                    tx_buf[40] <= 8'h00; tx_buf[41] <= 8'h00; // UDP checksum disabled
                    tx_len <= 11'd42 + echo_n;
                    cpy_ptr <= 42; cpy_wptr <= 42; cpy_cnt <= 0;
                    cpy_n <= echo_n;
                    rx_raddr <= 42; // present first payload byte early
                    pend_kind <= 2;
                    state <= S_CPY_WAIT;
                end
                S_CPY_WAIT: begin
                    // rx_dout == rx_buf[cpy_ptr] from this edge on.
                    if (crs_dv) begin
                        dropped <= dropped + 1;
                        state <= S_RX;
                    end else begin
                        state <= S_CPY_CAP;
                    end
                end
                S_CPY_CAP: begin
                    if (crs_dv) begin
                        dropped <= dropped + 1;
                        state <= S_RX;
                    end else begin
                        cpy_rdata <= rx_dout;
                        state <= S_CPY_WR;
                    end
                end
                S_CPY_WR: begin
                    if (crs_dv) begin
                        dropped <= dropped + 1;
                        state <= S_RX;
                    end else begin
                        tx_buf[cpy_wptr[9:0]] <= cpy_rdata;
                        if (cpy_cnt + 11'd1 >= cpy_n) begin
                            ip_id <= ip_id + 1;
                            state <= S_KICK;
                        end else begin
                            cpy_ptr <= cpy_ptr + 11'd1;
                            cpy_wptr <= cpy_wptr + 11'd1;
                            cpy_cnt <= cpy_cnt + 11'd1;
                            rx_raddr <= cpy_ptr + 11'd1;
                            state <= S_CPY_WAIT;
                        end
                    end
                end
                S_HELLO: begin
                    // Broadcast UDP: "TOMATO HELLO <8hex ctr> IP=<8hex ip>".
                    tx_buf[0] <= 8'hff; tx_buf[1] <= 8'hff; tx_buf[2] <= 8'hff;
                    tx_buf[3] <= 8'hff; tx_buf[4] <= 8'hff; tx_buf[5] <= 8'hff;
                    tx_buf[6] <= FPGA_MAC[47:40]; tx_buf[7] <= FPGA_MAC[39:32];
                    tx_buf[8] <= FPGA_MAC[31:24]; tx_buf[9] <= FPGA_MAC[23:16];
                    tx_buf[10] <= FPGA_MAC[15:8]; tx_buf[11] <= FPGA_MAC[7:0];
                    tx_buf[12] <= 8'h08; tx_buf[13] <= 8'h00;
                    tx_buf[14] <= 8'h45; tx_buf[15] <= 8'h00;
                    tx_buf[16] <= 8'h00; tx_buf[17] <= 8'h3D; // total 61: 20+8+33
                    tx_buf[18] <= ip_id[15:8]; tx_buf[19] <= ip_id[7:0];
                    tx_buf[20] <= 8'h40; tx_buf[21] <= 8'h00;
                    tx_buf[22] <= 8'h40; tx_buf[23] <= 8'h11;
                    tx_buf[24] <= hello_csum[15:8]; tx_buf[25] <= hello_csum[7:0];
                    tx_buf[26] <= FPGA_IP[31:24]; tx_buf[27] <= FPGA_IP[23:16];
                    tx_buf[28] <= FPGA_IP[15:8];  tx_buf[29] <= FPGA_IP[7:0];
                    tx_buf[30] <= 8'hff; tx_buf[31] <= 8'hff;
                    tx_buf[32] <= 8'hff; tx_buf[33] <= 8'hff;
                    tx_buf[34] <= UDP_PORT[15:8]; tx_buf[35] <= UDP_PORT[7:0];
                    tx_buf[36] <= UDP_PORT[15:8]; tx_buf[37] <= UDP_PORT[7:0];
                    tx_buf[38] <= 8'h00; tx_buf[39] <= 8'h29; // UDP len 41: 8+33
                    tx_buf[40] <= 8'h00; tx_buf[41] <= 8'h00;
                    tx_buf[42] <= 8'h54; tx_buf[43] <= 8'h4f; // "TOMATO HELLO "
                    tx_buf[44] <= 8'h4d; tx_buf[45] <= 8'h41;
                    tx_buf[46] <= 8'h54; tx_buf[47] <= 8'h4f;
                    tx_buf[48] <= 8'h20; tx_buf[49] <= 8'h48;
                    tx_buf[50] <= 8'h45; tx_buf[51] <= 8'h4c;
                    tx_buf[52] <= 8'h4c; tx_buf[53] <= 8'h4f;
                    tx_buf[54] <= 8'h20;
                    tx_buf[55] <= hexchar(hello_ctr[31:28]); tx_buf[56] <= hexchar(hello_ctr[27:24]);
                    tx_buf[57] <= hexchar(hello_ctr[23:20]); tx_buf[58] <= hexchar(hello_ctr[19:16]);
                    tx_buf[59] <= hexchar(hello_ctr[15:12]); tx_buf[60] <= hexchar(hello_ctr[11:8]);
                    tx_buf[61] <= hexchar(hello_ctr[7:4]);   tx_buf[62] <= hexchar(hello_ctr[3:0]);
                    tx_buf[63] <= 8'h20; tx_buf[64] <= 8'h49; // " IP="
                    tx_buf[65] <= 8'h50; tx_buf[66] <= 8'h3d;
                    tx_buf[67] <= hexchar(FPGA_IP[31:28]); tx_buf[68] <= hexchar(FPGA_IP[27:24]);
                    tx_buf[69] <= hexchar(FPGA_IP[23:20]); tx_buf[70] <= hexchar(FPGA_IP[19:16]);
                    tx_buf[71] <= hexchar(FPGA_IP[15:12]); tx_buf[72] <= hexchar(FPGA_IP[11:8]);
                    tx_buf[73] <= hexchar(FPGA_IP[7:4]);   tx_buf[74] <= hexchar(FPGA_IP[3:0]);
                    tx_len <= 75;
                    hello_ctr <= hello_ctr + 1;
                    ip_id <= ip_id + 1;
                    pend_kind <= 3;
                    state <= S_KICK;
                end
                S_KICK: begin
                    tx_ri <= 0;
                    tx_valid <= 1;
                    tx_start <= 1;
                    state <= S_TXWAIT;
                end
                S_TXWAIT: begin
                    if (tx_accept) tx_ri <= tx_ri + 1;
                    if (tx_ri == tx_len) tx_valid <= 0;
                    if (tx_done) begin
                        tx_frames <= tx_frames + 1;
                        if (pend_kind == 1) arp_ok <= arp_ok + 1;
                        pend_kind <= 0;
                        tx_valid <= 0;
                        state <= S_RX;
                    end
                end
                default: state <= S_RX;
            endcase
        end
    end
endmodule
