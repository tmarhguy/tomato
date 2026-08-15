/*
 * Tomato — microcode decode spot-check (512-row v1 images)
 *
 * Engineer : Tyrone Marhguy
 * Project  : Tomato 32-bit CPU
 * File     : control_tb.v
 * Target   : simulation (cwd = hardware/fpga/tomato)
 * ISA      : docs/isa/tomato.v1.csv
 *
 * Copyright (c) 2025-2026 Tyrone Marhguy
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */
`timescale 1ns/1ps
module control_tb;
    reg  [8:0] op;
    reg        fetch, exec;

    wire [7:0] lutA, lutB;
    wire [2:0] csel, wbsel, bussel, pcsrc, pccond;
    wire [3:0] immsel, bytesel;
    wire [1:0] shiftop, cycles, spop;
    wire flagwe, mulen, penc, regwe, banken, memrd, memwr;
    wire branchen, jumptype, pclinkwe, halt, alusel;

    aluctrl a (.op(op), .lutA(lutA), .lutB(lutB), .csel(csel),
               .flagwe(flagwe), .shiftop(shiftop), .mulen(mulen), .penc(penc));
    irctrl  i (.op(op), .immsel(immsel), .wbsel(wbsel), .regwe(regwe));
    memio   m (.op(op), .fetch(fetch), .banken(banken), .memrd(memrd),
               .memwr(memwr), .bytesel(bytesel));
    membus  b (.op(op), .bussel(bussel), .alusel(alusel));
    pcctrl  p (.exec(exec), .op(op), .branchen(branchen), .jumptype(jumptype),
               .pcsrc(pcsrc), .pclinkwe(pclinkwe), .cycles(cycles),
               .pccond(pccond), .spop(spop), .halt(halt));

    initial begin
        fetch = 0; exec = 1;

        op = 9'h001; #1;
        if (lutA !== 8'hAA || lutB !== 8'hCC) begin
            $display("FAIL: ADD lut %h %h", lutA, lutB); $finish(1);
        end
        if (csel !== 3'd0 || flagwe !== 1'b1 || regwe !== 1'b1 || immsel !== 4'd1) begin
            $display("FAIL: ADD ctrl csel=%0d flag=%b reg=%b imm=%0d",
                     csel, flagwe, regwe, immsel);
            $finish(1);
        end

        op = 9'h002; #1;
        if (lutA !== 8'hAA || lutB !== 8'h33 || csel !== 3'd1) begin
            $display("FAIL: SUB lut/csel %h %h %0d", lutA, lutB, csel); $finish(1);
        end

        // ADDI uses imm13
        op = 9'h020; #1;
        if (immsel !== 4'd3 || regwe !== 1) begin
            $display("FAIL: ADDI imm=%0d", immsel); $finish(1);
        end

        // LW: ALU.A = rA
        op = 9'h060; #1;
        if (memrd !== 1 || cycles !== 2'd2 || wbsel !== 3'd3 || alusel !== 0) begin
            $display("FAIL: LW"); $finish(1);
        end

        // SW: ALU.A = rB, imm8, store rA
        op = 9'h068; #1;
        if (memwr !== 1 || alusel !== 1 || immsel !== 4'd0 || wbsel !== 3'd4) begin
            $display("FAIL: SW alu=%b imm=%0d wb=%0d", alusel, immsel, wbsel);
            $finish(1);
        end

        // BNE → ~Z
        op = 9'h081; #1;
        if (branchen !== 1 || pccond !== 3'd1) begin
            $display("FAIL: BNE cond=%0d", pccond); $finish(1);
        end

        // JR → ALU / pass B
        op = 9'h0A3; #1;
        if (jumptype !== 1 || pcsrc !== 3'd4 || immsel !== 4'd1) begin
            $display("FAIL: JR src=%0d imm=%0d", pcsrc, immsel); $finish(1);
        end
        if (lutA !== 8'h00 || lutB !== 8'hCC) begin
            $display("FAIL: JR lut %h %h", lutA, lutB); $finish(1);
        end

        op = 9'h010; #1;
        if (mulen !== 1 || penc !== 0 || wbsel !== 3'd1) begin
            $display("FAIL: MUL"); $finish(1);
        end

        op = 9'h0C0; #1;
        if (spop !== 2'd2 || memwr !== 1 || bussel !== 3'd7) begin
            $display("FAIL: PUSH"); $finish(1);
        end

        // IN: lane sel=2, wb=mem, reg_we, no mem cycle
        op = 9'h0C8; #1;
        if (bytesel !== 4'd2 || wbsel !== 3'd3 || regwe !== 1'b1) begin
            $display("FAIL: IN bs=%0d wb=%0d we=%b", bytesel, wbsel, regwe);
            $finish(1);
        end
        if (memrd !== 1'b0 || memwr !== 1'b0) begin
            $display("FAIL: IN should not touch mem rd/wr"); $finish(1);
        end

        // OUT: latch path (no reg_we); imm_sel=1 passes rB unused — rA from IR
        op = 9'h0C9; #1;
        if (regwe !== 1'b0 || memrd !== 1'b0 || memwr !== 1'b0) begin
            $display("FAIL: OUT we/mem"); $finish(1);
        end

        op = 9'h0FF; #1;
        if (halt !== 1) begin $display("FAIL: HALT"); $finish(1); end

        $display("PASS: control (real-machine decode)");
        $finish;
    end
endmodule
