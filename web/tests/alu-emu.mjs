/**
 * Dual-LUT model vs the Verilog in hardware/fpga/core/rtl/alu.v
 */
import assert from "node:assert/strict";
import test from "node:test";
import {
  aluEval,
  cinFromCsel,
  hex,
  lutEval,
  lutIndex,
  lutInfo,
  lutShort,
  matchProgram,
  pairTitle,
  parseIntWord,
  resolveConstraints,
  resolveTruth,
  sensitivity,
} from "../js/alu.js";

test("LUT index is {C,B,A} with A LSB", () => {
  assert.equal(lutIndex(1, 0, 0), 1);
  assert.equal(lutIndex(0, 1, 0), 2);
  assert.equal(lutIndex(0, 0, 1), 4);
  assert.equal(lutIndex(1, 1, 1), 7);
  assert.equal(lutEval(0x80, 1, 1, 1), 1);
  assert.equal(lutEval(0x80, 1, 1, 0), 0);
  assert.equal(lutEval(0xaa, 1, 0, 0), 1);
  assert.equal(lutEval(0xaa, 0, 1, 1), 0);
});

test("ADD 8-bit: PASS_A + PASS_B", () => {
  const r = aluEval({ width: 8, lutA: 0xaa, lutB: 0xcc, A: 0x12, B: 0x34, C: 0, cin: 0 });
  assert.equal(r.out, 0x46);
  assert.equal(r.cout, 0);
  assert.equal(r.fa, 0x12);
  assert.equal(r.fb, 0x34);
  assert.equal(matchProgram(0xaa, 0xcc, 0)?.id, "add");
});

test("SUB 8-bit: A + ~B + 1", () => {
  const r = aluEval({ width: 8, lutA: 0xaa, lutB: 0x33, A: 5, B: 3, C: 0, cin: 1 });
  assert.equal(r.out, 2);
  assert.equal(r.cout, 1);
});

test("AND / XOR3 / AND3 bitwise", () => {
  const and = aluEval({ width: 8, lutA: 0x88, lutB: 0x00, A: 0xf0, B: 0x3c, C: 0, cin: 0 });
  assert.equal(and.out, 0x30);
  const xor3 = aluEval({ width: 8, lutA: 0x96, lutB: 0x00, A: 0b101, B: 0b011, C: 0b001, cin: 0 });
  assert.equal(xor3.out, 0b111);
  const and3 = aluEval({ width: 1, lutA: 0x80, lutB: 0x00, A: 1, B: 1, C: 1, cin: 0 });
  assert.equal(and3.out, 1);
});

test("FPGA hit: dual AND3 on the Artix-7 vector", () => {
  const A = 0x2e653abb;
  const B = 0x7d0145cd;
  const C = 0x1455f659;
  const and3 = (A & B & C) >>> 0;
  assert.equal(and3, 0x04010009);
  const r = aluEval({ width: 32, lutA: 0x80, lutB: 0x80, A, B, C, cin: 0 });
  assert.equal(r.out >>> 0, 0x08020012);
  assert.equal(r.cout, 0);
  assert.equal(pairTitle(0x80, 0x80, 0, null), "AND3 + AND3");
  assert.equal(lutInfo(0x80).name, "AND3");
});

test("flags: Z N C V packing", () => {
  const z = aluEval({ width: 8, lutA: 0xaa, lutB: 0xcc, A: 0, B: 0, C: 0, cin: 0 });
  assert.equal(z.flags & 1, 1);
  assert.equal((z.flags >>> 1) & 1, 0);
  const n = aluEval({ width: 8, lutA: 0xaa, lutB: 0x00, A: 0x80, B: 0, C: 0, cin: 0 });
  assert.equal((n.flags >>> 2) & 1, 1);
  const ov = aluEval({ width: 8, lutA: 0xaa, lutB: 0xcc, A: 0x7f, B: 0x01, C: 0, cin: 0 });
  assert.equal(ov.out, 0x80);
  assert.equal((ov.flags >>> 4) & 1, 1);
});

test("32-bit add does not wrap the carry into the sum incorrectly", () => {
  const r = aluEval({
    width: 32,
    lutA: 0xaa,
    lutB: 0xcc,
    A: 0xfffffffe,
    B: 0x00000003,
    C: 0,
    cin: 0,
  });
  assert.equal(r.out, 0x00000001);
  assert.equal(r.cout, 1);
});

test("csel mux matches alu.v", () => {
  const flags = 0b0100_1001; // GTE=0 GT=1 LT=0 V=0 C=1 N=0 NZ=0 Z=1
  assert.equal(cinFromCsel(0, flags), 0);
  assert.equal(cinFromCsel(1, flags), 1);
  assert.equal(cinFromCsel(3, flags), 1);
  assert.equal(cinFromCsel(4, flags), 1);
  assert.equal(cinFromCsel(5, flags), 1);
  assert.equal(cinFromCsel(2, flags), 0);
});

test("sensitivity: only live LUT bit moves this vector", () => {
  const s = sensitivity({ width: 1, lutA: 0xaa, lutB: 0x00, A: 1, B: 0, C: 0, cin: 0 });
  const live = s.rows.find((row) => row.source === "lutA[1]");
  const dark = s.rows.find((row) => row.source === "lutA[0]");
  assert.equal(live.moved, true);
  assert.equal(dark.moved, false);
});

test("resolver: AND3 family prefers 0x80 / ZERO / cin 0", () => {
  const r = resolveTruth(0x80, { singlePlane: true });
  assert.ok(r.count >= 1);
  assert.equal(r.best.lutA, 0x80);
  assert.equal(r.best.lutB, 0);
  assert.equal(r.best.cin, 0);
  assert.equal(lutInfo(0x80).name, "AND3");
});

test("resolver: 0x12+0x34 hits ADD among many", () => {
  const r = resolveConstraints(8, [{ A: 0x12, B: 0x34, C: 0, out: 0x46 }]);
  assert.ok(r.count > 1);
  assert.ok(r.named.some((n) => n.name === "Add"));
});

test("pair title uses catalog names for both planes", () => {
  assert.equal(pairTitle(0x80, 0x69, 0, null), "AND3 + XNOR3");
  assert.equal(pairTitle(0x80, 0x17, 0, null), "AND3 + NMAJ");
  assert.equal(lutShort(lutInfo(0x80)), "AND3");
  assert.equal(lutInfo(0x13).known, false);
});

test("hex / parse helpers", () => {
  assert.equal(hex(0x12, 8), "0x12");
  assert.equal(parseIntWord("0x46", 8), 0x46);
  assert.equal(parseIntWord("0b00010010", 8), 0x12);
  assert.equal(parseIntWord("46", 8), 0x46);
  assert.equal(parseIntWord("0x46", 8), 0x46);
});
