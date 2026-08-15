/*
 * Tomato — top-level CPU (Nexys A7 board)
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : main.v
 * Target   : Artix-7 / synthesizable Verilog-2001
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 *
 * Board: 7-seg = last WB mux value during execute; VGA = tile RAM scanout.
 * Peripherals: IN/OUT via lane sel=2 + io_out latch; MMIO [21:19]==111.
 *
 * FPGA burn: without -DTOMATO_SIM, dmem is initialized from rtl/burn/dmem_init.vh
 * (Tomato OS by default). Microcode is always burned in control.v.
 * Board top: nexys_top.v (buttons → kb, LEDs ← io_out).
 */

module main (
    input        clk,
    input        reset,
    input  [7:0] kb_data,   // PS/2 / UART RX byte (lane IN / MMIO)
    input        kb_ready,  // key pending (IRQ + status MMIO)
    output [7:0] io_out,    // last OUT byte (UART TX / LED)
    output [6:0] seg,
    output [7:0] an,
    output       dp,
    output       vga_hs,
    output       vga_vs,
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b
);
    wire       kb_en = kb_ready;

    wire        cregwe, cbanken;
    wire        cmemrd, cmemwr;
    wire [3:0]  cbytesel;
    wire [2:0]  cbussel, cwbsel, cpcsrc, cpccond, ccsel;
    wire [3:0]  cirsel;
    wire [1:0]  ccycles, cspop, cshiftop;
    wire        cbranchen, cjumptype, cpclinkwe;
    wire        cmulen, cpenc, halt, calusel;
    wire [7:0]  clutA, clutB;

    wire        fetch, exec;
    wire [8:0]  opcode;
    wire [4:0]  addra, addrb, addrc, addrw;
    wire [2:0]  banksel;
    wire [21:0] addrabs, offset;
    wire [31:0] imm;
    wire [31:0] ra, rb, rc;
    wire [31:0] alu_a = calusel ? rb : ra;
    wire [31:0] aluout;
    wire [7:0]  flags;
    wire [31:0] shiftmul;
    wire [31:0] mulhi;
    wire        anz;
    wire [23:0] pcsave, pclink, spout, memaddr;
    wire [23:0] pcout;
    wire        memrdout;
    wire [31:0] memram, memdin;
    wire [31:0] wbdata;
    wire        aluflagwe;
    wire        flagswe = aluflagwe & exec;

    wire        vga_hit = (memaddr[21:19] == 3'b110);
    wire        kb_hit  = (memaddr[21:19] == 3'b111);
    wire [12:0] vga_raddr;
    wire [31:0] vga_rdata;
    reg  [7:0]  io_out_r;
    assign io_out = io_out_r;

    // OUT opcode: latch peripheral byte (board UART/LED glue — same spirit as VGA MMIO)
    always @(posedge clk) begin
        if (reset)                         io_out_r <= 8'h00;
        else if (exec && (opcode == 9'h0C9)) io_out_r <= ra[7:0];
    end

    lane lane0 (
        .mem_in  (memram),
        .sel     (cbytesel),
        .io_data (kb_data),
        .mem_out (memdin)
    );

    pc pc0 (
        .clk       (clk),
        .rst       (reset),
        .cycles    (ccycles),
        .pc_src    (cpcsrc),
        .offset    (offset),
        .alu_in    (aluout),
        .mem_din   (memdin),
        .csr_flags (flags),
        .pc_cond   (cpccond),
        .jump      (cjumptype),
        .branch_en (cbranchen),
        .link_we   (cpclinkwe),
        .halt_in   (halt),
        .ecall_in  ((opcode == 9'h0E1) & exec),
        .int_en_in (1'b0),   // IRQ off until SEI; kb via IN / MMIO only
        .int_req   (kb_en),
        .int_vec0  (1'b0),
        .int_vec1  (1'b0),
        .int_vec2  (1'b0),
        .pc        (pcout),
        .pc_next   (pcsave),
        .pc_link   (pclink),
        .fetch     (fetch),
        .execute   (exec)
    );

    sp sp0 (
        .clk     (clk),
        .rst     (reset),
        .exec    (exec),
        .sp_op   (cspop),
        .load_in (aluout),
        .sp_out  (spout)
    );

    vga vga0 (
        .clk      (clk),
        .mem_addr (memaddr),
        .mem_din  (wbdata),
        .mem_wr   (cmemwr),
        .raddr    (vga_raddr),
        .rdata    (vga_rdata)
    );

    vgatiming vgatiming0 (
        .clk    (clk),
        .reset  (reset),
        .tile   (vga_rdata),
        .raddr  (vga_raddr),
        .vga_hs (vga_hs),
        .vga_vs (vga_vs),
        .vga_r  (vga_r),
        .vga_g  (vga_g),
        .vga_b  (vga_b)
    );

    // 7-seg = last WB mux value during execute (stable between exec cycles / HALT)
    reg [31:0] disp;
    always @(posedge clk) begin
        if (reset)     disp <= 32'h0;
        else if (exec) disp <= wbdata;
    end

    hex hex0 (
        .clk   (clk),
        .reset (reset),
        .value (disp),
        .seg   (seg),
        .an    (an),
        .dp    (dp)
    );

    regs regs0 (
        .clk      (clk),
        .we       (cregwe),
        .exec     (exec),
        .bank_en  (cbanken),
        .bank_sel (banksel),
        .addr_a   (addra),
        .addr_b   (addrb),
        .addr_c   (addrc),
        .addr_w   (addrw),
        .data_w   (wbdata),
        .data_a   (ra),
        .data_b   (rb),
        .data_c   (rc)
    );

    wb wb0 (
        .wb_sel      (cwbsel),
        .alu_out     (aluout),
        .shift_mul   (shiftmul),
        .pc_save     (pcsave),
        .mem_din     (memdin),
        .reg_a       (ra),
        .imm         (imm),
        .csr_flags   (flags),
        .mul_hi      (mulhi),
        .wb_data     (wbdata)
    );

    // IR must see raw mem words — lane/byte_sel is for loads only. Fetching
    // through memdin after LB/SB leaves byte_sel≠0 and corrupts the next insn.
    ir ir0 (
        .clk      (clk),
        .load     (fetch),
        .data_in  (memram),
        .imm_sel  (cirsel),
        .reg_b    (rb),
        .opcode   (opcode),
        .addr_a   (addra),
        .addr_b   (addrb),
        .addr_c   (addrc),
        .addr_w   (addrw),
        .bank_sel (banksel),
        .addr_abs (addrabs),
        .offset   (offset),
        .imm_out  (imm)
    );

    bus bus0 (
        .fetch     (fetch),
        .mem_rd_in (cmemrd),
        .addr_sel  (cbussel),
        .ir_addr   (addrabs),
        .reg_b     (rb),
        .alu_in    (aluout),
        .pc        (pcout),
        .sp        (spout),
        .addr      (memaddr),
        .mem_rd    (memrdout)
    );

    // 16K×32 dmem (not VGA window). Byte/half stores merge via cbytesel (lane map).
    // FPGA: program image burned here (tools/gen_fpga_burn.py → burn/dmem_init.vh).
    // Sim TBs: compile with -DTOMATO_SIM and $readmemh into uut.dmem themselves.
    (* ram_style = "block" *) reg [31:0] dmem [0:16383];
`ifndef TOMATO_SIM
    integer burn_i;
    initial begin
        for (burn_i = 0; burn_i < 16384; burn_i = burn_i + 1)
            dmem[burn_i] = 32'h0;
        `include "burn/dmem_init.vh"
    end
`endif
    wire [13:0] dmema = memaddr[13:0];
    wire [31:0] dread = dmem[dmema];
    reg  [31:0] dmerge;
    always @(*) begin
        case (cbytesel)
            4'd4, 4'd8:  dmerge = {dread[31:8],  wbdata[7:0]};                 // byte0
            4'd5, 4'd9:  dmerge = {dread[31:16], wbdata[7:0], dread[7:0]};     // byte1
            4'd6, 4'd10: dmerge = {dread[31:24], wbdata[7:0], dread[15:0]};    // byte2
            4'd7, 4'd11: dmerge = {wbdata[7:0],  dread[23:0]};                 // byte3
            4'd12, 4'd14: dmerge = {dread[31:16], wbdata[15:0]};               // half0
            4'd13, 4'd15: dmerge = {wbdata[15:0], dread[15:0]};                // half1
            default:      dmerge = wbdata;                                      // word
        endcase
    end
    always @(posedge clk) begin
        if (cmemwr & exec & ~vga_hit & ~kb_hit) dmem[dmema] <= dmerge;
    end
    // MMIO [21:19]==111: word0 = kb data, word1 = {ready}
    assign memram = kb_hit
                  ? (memaddr[0] ? {31'b0, kb_ready} : {24'b0, kb_data})
                  : dread;

    alu alu0 (
        .lutA    (clutA),
        .lutB    (clutB),
        .A       (alu_a),
        .B       (imm),
        .C       (rc),
        .csel    (ccsel),
        .flag_we (flagswe),
        .clk     (clk),
        .out     (aluout),
        .csr     (flags)
    );

    muldiv muldiv0 (
        .a        (alu_a),
        .b        (imm),
        .mode     (cshiftop),
        .mulen    (cmulen),
        .isdiv    (cpenc),
        .result   (shiftmul),
        .resulthi (mulhi),
        .anz      (anz)
    );

    memio memio0 (
        .op      (opcode),
        .fetch   (fetch),
        .banken  (cbanken),
        .memrd   (cmemrd),
        .memwr   (cmemwr),
        .bytesel (cbytesel)
    );
    pcctrl pcctrl0 (
        .exec     (exec),
        .op       (opcode),
        .branchen (cbranchen),
        .jumptype (cjumptype),
        .pcsrc    (cpcsrc),
        .pclinkwe (cpclinkwe),
        .cycles   (ccycles),
        .pccond   (cpccond),
        .spop     (cspop),
        .halt     (halt)
    );
    aluctrl aluctrl0 (
        .op      (opcode),
        .lutA    (clutA),
        .lutB    (clutB),
        .csel    (ccsel),
        .flagwe  (aluflagwe),
        .shiftop (cshiftop),
        .mulen   (cmulen),
        .penc    (cpenc)
    );
    irctrl irctrl0 (
        .op     (opcode),
        .immsel (cirsel),
        .wbsel  (cwbsel),
        .regwe  (cregwe)
    );
    membus membus0 (
        .op     (opcode),
        .bussel (cbussel),
        .alusel (calusel)
    );
endmodule
