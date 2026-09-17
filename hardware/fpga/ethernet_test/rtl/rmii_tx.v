// Minimal RMII 100Mb/s transmitter. LSB-first dibits, preamble/SFD,
// streaming payload with backpressure, auto-pad to 60 bytes, IEEE FCS,
// 96-bit IFG. No ARP/IP knowledge; lan_min.v builds the bytes.
module rmii_tx(
    input clk,
    input reset,
    // Frame control: pulse tx_start to begin preamble. tx_busy high until IFG done.
    input tx_start,
    output reg tx_busy,
    output reg tx_done,
    // Payload stream: feeder preloads the first byte BEFORE pulsing tx_start,
    // holds tx_valid+tx_data(+tx_last) stable, and keeps tx_valid high until
    // the last byte is accepted. Backpressure mid-frame is not supported
    // (Ethernet has no pauses); tx_accept pulses once per consumed byte.
    // tx_last marks the final payload byte (dstMAC..last payload, no FCS).
    input [7:0] tx_data,
    input tx_valid,
    input tx_last,
    output reg tx_accept,
    // RMII pins (net_clk domain, 2 bits per clock = 100Mb/s).
    output reg tx_en,
    output reg [1:0] txd
);
    localparam S_IDLE = 0, S_PREAMBLE = 1, S_DATA = 2, S_PAD = 3, S_FCS = 4, S_IFG = 5;
    reg [2:0] state = S_IDLE;
    reg [5:0] pre_cnt = 0;      // 0..31 dibits of preamble+SFD
    reg [1:0] dib_cnt = 0;      // 0..3 dibits within current byte
    reg [7:0] cur = 0;          // byte being serialized
    reg cur_last = 0;           // latched tx_last for cur
    reg have_byte = 0;          // cur holds a valid byte to serialize
    reg [15:0] byte_cnt = 0;    // payload+pad bytes accepted so far
    reg [31:0] crc = 32'hffffffff;
    wire [31:0] crc_inv = ~crc;
    reg [31:0] fcs = 0;         // latched ~crc at end of payload/pad
    reg [1:0] fcs_idx = 0;      // 0..3 FCS bytes sent
    reg [4:0] ifg_cnt = 0;

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

    // Preamble dibits LSB-first: 7x 0x55 then 0xD5 (SFD).
    function [1:0] pre_dibit;
        input [5:0] n;
        reg [7:0] b;
        begin
            b = (n < 28) ? 8'h55 : 8'hd5;
            case (n[1:0])
                0: pre_dibit = b[1:0];
                1: pre_dibit = b[3:2];
                2: pre_dibit = b[5:4];
                default: pre_dibit = b[7:6];
            endcase
        end
    endfunction

    function [7:0] fcs_byte;
        input [31:0] f;
        input [1:0] idx;
        begin
            case (idx)
                0: fcs_byte = f[7:0];
                1: fcs_byte = f[15:8];
                2: fcs_byte = f[23:16];
                default: fcs_byte = f[31:24];
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE; tx_busy <= 0; tx_done <= 0; tx_accept <= 0;
            tx_en <= 0; txd <= 0;
            pre_cnt <= 0; dib_cnt <= 0; cur <= 0; cur_last <= 0; have_byte <= 0;
            byte_cnt <= 0; crc <= 32'hffffffff; fcs <= 0; fcs_idx <= 0; ifg_cnt <= 0;
        end else begin
            tx_done <= 0;
            tx_accept <= 0;
            case (state)
                S_IDLE: begin
                    tx_en <= 0; txd <= 0;
                    if (tx_start) begin
                        state <= S_PREAMBLE; tx_busy <= 1;
                        pre_cnt <= 0; have_byte <= 0;
                        byte_cnt <= 0; crc <= 32'hffffffff;
                    end
                end
                S_PREAMBLE: begin
                    tx_en <= 1;
                    txd <= pre_dibit(pre_cnt);
                    if (pre_cnt == 31) begin
                        state <= S_DATA;
                        if (tx_valid) begin
                            // Pre-accept the first payload byte during the last
                            // SFD cycle so S_DATA drives data on its very first
                            // cycle (no stale-dibit bubble on the wire).
                            cur <= tx_data; cur_last <= tx_last;
                            have_byte <= 1; dib_cnt <= 0;
                            tx_accept <= 1;
                            crc <= crc_byte(crc, tx_data);
                            byte_cnt <= 1;
                        end else begin
                            have_byte <= 0; dib_cnt <= 0;
                            byte_cnt <= 0;
                        end
                    end else begin
                        pre_cnt <= pre_cnt + 1;
                    end
                end
                S_DATA: begin
                    tx_en <= 1;
                    if (!have_byte) begin
                        // Feeder contract: tx_valid is already high here
                        // (first byte preloaded before tx_start, held until
                        // last accept). First dibit driven at accept so the
                        // wire never idles mid-frame with tx_en high.
                        if (tx_valid) begin
                            txd <= tx_data[1:0];
                            cur <= {2'b00, tx_data[7:2]};
                            cur_last <= tx_last;
                            have_byte <= 1; dib_cnt <= 1;
                            tx_accept <= 1;
                            crc <= crc_byte(crc, tx_data);
                            byte_cnt <= byte_cnt + 1;
                        end
                    end else begin
                        txd <= cur[1:0];
                        cur <= {2'b00, cur[7:2]};
                        if (dib_cnt == 3) begin
                            have_byte <= 0;
                            if (cur_last) begin
                                fcs <= ~crc;
                                if (byte_cnt < 60) begin
                                    state <= S_PAD;
                                end else begin
                                    state <= S_FCS;
                                    fcs_idx <= 0; dib_cnt <= 0;
                                    cur <= crc_inv[7:0];
                                end
                            end
                        end else begin
                            dib_cnt <= dib_cnt + 1;
                        end
                    end
                end
                S_PAD: begin
                    tx_en <= 1;
                    if (!have_byte) begin
                        txd <= 2'b00;
                        cur <= 8'h00;
                        cur_last <= (byte_cnt + 1 >= 60);
                        have_byte <= 1; dib_cnt <= 1;
                        crc <= crc_byte(crc, 8'h00);
                        byte_cnt <= byte_cnt + 1;
                    end else begin
                        txd <= cur[1:0];
                        cur <= {2'b00, cur[7:2]};
                        if (dib_cnt == 3) begin
                            have_byte <= 0;
                            if (cur_last) begin
                                fcs <= ~crc;
                                state <= S_FCS;
                                fcs_idx <= 0; dib_cnt <= 0;
                                cur <= crc_inv[7:0];
                            end
                        end else begin
                            dib_cnt <= dib_cnt + 1;
                        end
                    end
                end
                S_FCS: begin
                    tx_en <= 1;
                    txd <= cur[1:0];
                    cur <= {2'b00, cur[7:2]};
                    if (dib_cnt == 3) begin
                        dib_cnt <= 0;
                        if (fcs_idx == 3) begin
                            state <= S_IFG; ifg_cnt <= 0;
                        end else begin
                            fcs_idx <= fcs_idx + 1;
                            cur <= fcs_byte(fcs, fcs_idx + 1);
                        end
                    end else begin
                        dib_cnt <= dib_cnt + 1;
                    end
                end
                S_IFG: begin
                    tx_en <= 0; txd <= 0;
                    if (ifg_cnt == 23) begin
                        state <= S_IDLE; tx_busy <= 0; tx_done <= 1;
                    end
                    ifg_cnt <= ifg_cnt + 1;
                end
                default: begin
                    state <= S_IDLE; tx_en <= 0;
                end
            endcase
        end
    end
endmodule
