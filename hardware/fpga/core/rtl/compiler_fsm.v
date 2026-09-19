/*
 * Tomato — Dual-LUT hardware compiler (counter FSM)
 *
 * Hold A, B, C, cin (1 bit) and expected out. Each clock {lutB, lutA} += 1
 * into alu.v: out = f(A,B,C) + g(A,B,C) + cin. Freeze on the first match.
 *
 * HOLD freezes the current opcodes; A/B/C/cin then live-update `out`.
 * RESET zeros the counter.
 *
 * MMIO window 0x780080 (kb_hit && addr[7] && !addr[8]):
 *   0 A  1 B  2 C  3 cin[0]  4 expected
 *   5 write bit0=GO bit1=HOLD bit2=RESET; read = live alu out
 *   6 status {held, done, hit, busy}
 *   7 opcode {lutB, lutA}
 *
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
module compiler_fsm (
    input         clk,
    input         reset,
    input         wr,
    input  [2:0]  sel,
    input  [31:0] wdata,
    output [31:0] rdata
);
    reg [31:0] a, b, c, expected;
    reg        cin;
    reg [15:0] count, latched;
    reg        busy, hit, done, held;

    wire [7:0] lutA = count[7:0];
    wire [7:0] lutB = count[15:8];
    wire [31:0] alu_out;
    wire [7:0]  alu_csr;

    alu sweep (
        .lutA(lutA), .lutB(lutB),
        .A(a), .B(b), .C(c),
        .csel({2'b0, cin}), .flag_we(1'b0), .clk(clk),
        .out(alu_out), .csr(alu_csr)
    );

    always @(posedge clk) begin
        if (reset) begin
            a <= 0; b <= 0; c <= 0; expected <= 0; cin <= 0;
            count <= 0; latched <= 0;
            busy <= 0; hit <= 0; done <= 0; held <= 0;
        end else if (wr && (sel == 3'd5) && wdata[2]) begin
            count <= 16'd0; latched <= 16'd0;
            busy <= 1'b0; hit <= 1'b0; done <= 1'b0; held <= 1'b0;
        end else if (wr && (sel == 3'd5) && wdata[1]) begin
            busy <= 1'b0; held <= 1'b1;
        end else if (wr && (sel == 3'd5) && wdata[0]) begin
            busy <= 1'b1; hit <= 1'b0; done <= 1'b0; held <= 1'b0; count <= 16'd0;
        end else if (wr && !busy) begin
            case (sel)
                3'd0: a <= wdata;
                3'd1: b <= wdata;
                3'd2: c <= wdata;
                3'd3: cin <= wdata[0];
                3'd4: expected <= wdata;
                default: ;
            endcase
        end else if (busy) begin
            if (alu_out == expected) begin
                latched <= count;
                hit <= 1'b1; done <= 1'b1; busy <= 1'b0;
            end else if (count == 16'hFFFF) begin
                done <= 1'b1; hit <= 1'b0; busy <= 1'b0;
            end else begin
                count <= count + 16'd1;
            end
        end
    end

    assign rdata =
        (sel == 3'd0) ? a :
        (sel == 3'd1) ? b :
        (sel == 3'd2) ? c :
        (sel == 3'd3) ? {31'b0, cin} :
        (sel == 3'd4) ? expected :
        (sel == 3'd5) ? alu_out :
        (sel == 3'd6) ? {28'b0, held, done, hit, busy} :
                        {16'b0, count};
endmodule
