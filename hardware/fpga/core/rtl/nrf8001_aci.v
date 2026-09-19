// Envelop Lite: one ACI transaction, 32 command bytes + 31 event bytes.
// MMIO offsets: 0 status/control, 1 command length, 2 event length,
// 0x20..3f command bytes, 0x40..5f event bytes (opcode first).
// Status bits: done, busy, RDY_n, reset-released, fault. Control: start=1,
// acknowledge=2, reset=4. Firmware owns setup, framing, credits, and UI.
module nrf8001_aci #(
    parameter RESET_CYCLES = 62500,
    parameter SETTLE_CYCLES = 250000,
    parameter TIMEOUT_CYCLES = 625000,
    parameter HALF_CYCLES = 4
) (
    input clk, reset, input [6:0] addr, input wr,
    input [7:0] wdata, output [31:0] rdata,
    input rdy_n, miso, output reg rst_n, req_n, sck, mosi
);
    reg [7:0] cmd [0:31];
    reg [7:0] evt [0:31];
    reg [4:0] cmd_len;
    reg [5:0] evt_len;
    reg [2:0] state;
    localparam RESET=0, SETTLE=1, IDLE=2, READY=3, SHIFT=4, RELEASE=5;
    reg [19:0] timer;
    reg [7:0] divider;
    reg [5:0] byte_no, last_byte;
    reg [2:0] bit_no;
    reg [7:0] received;
    reg done, fault;
    (* ASYNC_REG = "TRUE" *) reg [1:0] rdy_sync;
    always @(posedge clk) rdy_sync <= {rdy_sync[0], rdy_n};
    wire busy = state != IDLE;
    assign rdata = addr[6] ? {24'b0,evt[addr[4:0]]} :
                   addr == 1 ? {27'b0,cmd_len} :
                   addr == 2 ? {26'b0,evt_len} :
                   {27'b0,fault,rst_n,rdy_sync[1],busy,done};
    wire soft_reset = wr && addr == 0 && wdata[2];
    always @(posedge clk) begin
        if (wr && addr[6:5] == 1 && !busy) cmd[addr[4:0]] <= wdata;
        if (reset || soft_reset) begin
            state <= RESET; timer <= 0; rst_n <= 0; req_n <= 1;
            sck <= 0; mosi <= 0; done <= 0; fault <= 0;
            cmd_len <= 0; evt_len <= 0; divider <= 0;
            byte_no <= 0; bit_no <= 0; received <= 0; last_byte <= 1;
        end else begin
            case (state)
            RESET: if (timer == RESET_CYCLES-1) begin
                rst_n <= 1; timer <= 0; state <= SETTLE;
            end else timer <= timer + 1'b1;
            SETTLE: if (timer == SETTLE_CYCLES-1) begin
                timer <= 0; state <= IDLE;
            end else timer <= timer + 1'b1;
            IDLE: begin
                if (wr && addr == 1) cmd_len <= wdata[4:0];
                if (wr && addr == 0 && wdata[1]) done <= 0;
                if (wr && addr == 0 && wdata[0]) begin
                    done <= 0; fault <= 0; evt_len <= 0; req_n <= 0;
                    timer <= 0; state <= READY;
                    byte_no <= 0; bit_no <= 0; received <= 0;
                    mosi <= cmd_len[0];
                    last_byte <= cmd_len > 1 ? {1'b0,cmd_len} : 6'd1;
                end
            end
            READY: if (!rdy_sync[1]) begin
                state <= SHIFT; divider <= 0; timer <= 0;
            end else if (timer == TIMEOUT_CYCLES-1) begin
                fault <= 1; done <= 1; req_n <= 1; mosi <= 0; state <= IDLE;
            end else timer <= timer + 1'b1;
            SHIFT: if (divider == HALF_CYCLES-1) begin
                divider <= 0;
                if (!sck) begin
                    sck <= 1; received[bit_no] <= miso;
                end else begin
                    sck <= 0;
                    if (bit_no == 7) begin
                        if (byte_no == 1) begin
                            evt_len <= received > 31 ? 0 : received[5:0];
                            if (received > 31) fault <= 1;
                            if (received <= 31 && received + 6'd1 > last_byte)
                                last_byte <= received[5:0] + 1'b1;
                        end
                        if (byte_no >= 2 && byte_no < evt_len + 2)
                            evt[byte_no-2] <= received;
                        // At length byte, new event length is not latched yet.
                        if (byte_no >= last_byte &&
                            !(byte_no == 1 && received != 0 && received <= 31)) begin
                            req_n <= 1; mosi <= 0; timer <= 0; state <= RELEASE;
                        end else begin
                            byte_no <= byte_no + 1'b1; bit_no <= 0;
                            mosi <= byte_no < cmd_len ? cmd[byte_no[4:0]][0] : 1'b0;
                        end
                    end else begin
                        bit_no <= bit_no + 1'b1;
                        if (byte_no == 0) mosi <= ({3'b0,cmd_len} >> (bit_no+1'b1)) & 1'b1;
                        else if (byte_no <= cmd_len) mosi <= (cmd[byte_no-1] >> (bit_no+1'b1)) & 1'b1;
                        else mosi <= 0;
                    end
                end
            end else divider <= divider + 1'b1;
            RELEASE: if (rdy_sync[1]) begin
                state <= IDLE; done <= 1;
            end else if (timer == TIMEOUT_CYCLES-1) begin
                state <= IDLE; done <= 1; fault <= 1;
            end else timer <= timer + 1'b1;
            default: state <= RESET;
            endcase
        end
    end
endmodule
