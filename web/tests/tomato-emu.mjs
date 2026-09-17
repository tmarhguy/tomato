/* Tomato web emulator regression: exact program expects + OS boot oracles.
 *
 * Programs carry the EXPECT values from hardware/fpga/core/tb/prog_tb.v, so
 * this file checks the JS core against the same answers as the RTL benches.
 * OS boot checks mirror the screen landmarks in tb/os_tb.v and tb/games_tb.v.
 */
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Tomato, loadImage } from "../js/tomato-cpu.js";

const WEB = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const ROOT = resolve(WEB, "..");

test("web image is fresh vs OS/ISA/RTL sources (rebuild: tools/build_web_image.py)", () => {
  const manifest = JSON.parse(readFileSync(join(WEB, "data/tomato-os.json"), "utf8"));
  const bin = readFileSync(join(WEB, manifest.image));
  assert.equal(bin.length, manifest.bytes);
  assert.equal(bin.subarray(0, 4).toString("latin1"), "TOM1");
  for (const [rel, sha] of Object.entries(manifest.files)) {
    const got = createHash("sha256").update(readFileSync(join(ROOT, rel))).digest("hex");
    assert.equal(got, sha, `${rel} changed: rebuild the web image`);
  }
});

function loadMem(path, words) {
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const s = line.trim();
    if (/^[0-9a-fA-F]{1,8}$/.test(s)) words.push(parseInt(s, 16) >>> 0);
  }
  return words;
}

function runProg(name, { kb = 0, cap = 200000 } = {}) {
  const image = loadImage(readFileSync(join(WEB, "data/tomato-os.bin")));
  const t = new Tomato(image);
  t.dmem.fill(0);
  const words = loadMem(join(ROOT, `hardware/fpga/core/tb/mem/${name}.mem`), []);
  t.dmem.set(words.subarray ? words : words, 0);
  if (kb) { t.kbData = kb & 255; t.kbReady = true; }
  t.step(cap);
  assert.ok(t.halted, `${name}: no halt`);
  return t;
}

test("counter: r1 = disp = 10", () => {
  const t = runProg("counter");
  assert.equal(t.regs[1], 10);
});

test("fib: fib(8) = 21", () => {
  const t = runProg("fib");
  assert.equal(t.regs[1], 21);
  assert.equal(t.regs[6], 21);
});

test("collatz: n=27 takes 111 steps", () => {
  const t = runProg("collatz");
  assert.equal(t.regs[1], 111);
});

test("call: JAL/RET link discipline", () => {
  const t = runProg("call");
  assert.equal(t.regs[1], 99);
  assert.equal(t.regs[2], 42);
});

test("bytes: SB/LB signed byte", () => {
  const t = runProg("bytes");
  assert.equal(t.regs[1], 90);
  assert.equal(t.regs[2] | 0, -128);
});

test("ecall: trap + RET", () => {
  const t = runProg("ecall");
  assert.equal(t.regs[1], 42);
});

test("softops: ROR/LBU", () => {
  const t = runProg("softops");
  assert.equal(t.regs[1], 129);
  assert.equal(t.regs[6], 129);
});

test("io: IN/OUT keyboard echo", () => {
  const t = runProg("io", { kb: 65 });
  assert.equal(t.regs[1], 65);
});

test("kb_mmio: LW keypad data/status", () => {
  const t = runProg("kb_mmio", { kb: 126 });
  assert.equal(t.regs[1], 126);
  // r2 differs from prog_tb on purpose: that bench never drops kb_ready, but
  // the real keypad (main.v) consumes the key on the word-0 load, so status
  // reads 0 afterwards. The core implements hardware behavior.
  assert.equal(t.regs[2], 0);
});

// ---- Whole-OS session (mirrors tools/test_virtual_tomato.py) ------------
// One harness tick is 105000 clocks; the core counts instructions, and every
// Tomato instruction retires in 2 clocks (3 for loads/stores), so a tick is
// ~52500 instructions. Helpers poll instead of sleeping fixed settles.
const TICK = 52500;

function bootOs() {
  const image = loadImage(readFileSync(join(WEB, "data/tomato-os.bin")));
  const t = new Tomato(image);
  t.step(200000);
  return t;
}

function settleUntil(t, x, y, want, cap = 130) {
  for (let i = 0; i < cap; i++) {
    if (t.tileText(x, y, want.length) === want) return i;
    t.step(TICK);
  }
  assert.fail(`never saw "${want}" at (${x},${y}); got "${t.tileText(x, y, want.length)}"`);
}

function settleReplies(t, replies, count, cap = 220) {
  for (let i = 0; i < cap && replies.length < count; i++) t.step(TICK);
  assert.equal(replies.length, count, `expected ${count} chat replies`);
}

test("os: boots to the menu", () => {
  const t = bootOs();
  assert.equal(t.tileText(9, 15, 11), "System info");
});

test("os: Envelop opens from the menu", () => {
  const t = bootOs();
  t.key(30); t.step(TICK);
  assert.equal(t.menuSelection, 13);
  t.key(13); t.step(TICK);
  assert.equal(t.tileText(2, 2, 7), "Envelop");
});

test("compiler MMIO matches the counter FSM and the OS can deep-boot it", () => {
  const t = bootOs();
  t.compilerWrite(0, 0x89);
  t.compilerWrite(1, 0x33);
  t.compilerWrite(2, 0x22);
  t.compilerWrite(3, 0);
  t.compilerWrite(4, 0xbc);
  t.compilerWrite(5, 1);
  t.compilerAdvance(65536);
  assert.equal(t.compilerRead(6), 0b0110);
  assert.equal(t.compilerRead(5), 0xbc);
  assert.equal(t.compilerRead(7), 0x084e);

  const ui = bootOs();
  ui.key(30); ui.step(TICK);
  ui.key(30); ui.step(TICK);
  assert.equal(ui.menuSelection, 12);
  ui.key(13); ui.step(TICK);
  ui.key(13); ui.step(TICK * 5);
  assert.match(ui.tileText(6, 39, 18), /L+A+T+C+H+E+D+/);
  assert.equal(ui.compilerRead(5), 0xbc);
});

test("os: demo phone delivers contacts and a greeting", () => {
  const t = bootOs();
  const replies = [];
  t.radio.onFrame = ({type, route, payload}) => {
    if (type === 8) replies.push({route,
      text: String.fromCharCode(...payload.slice(4))});
  };
  t.key(30); t.step(TICK);
  t.key(13); t.step(TICK);
  t.demo();
  settleUntil(t, 2, 11, "Ama");
  settleUntil(t, 29, 23, "Hello");
  settleReplies(t, replies, 4);
  assert.deepEqual(replies, [
    {route: 1, text: "Hello, Ama! I'm Tomato."},
    {route: 1, text: "I reply from a dorm table I call home."},
    {route: 1, text: "Tyrone Marhguy built me transistor-up!"},
    {route: 1, text: "Try 23 + 19 on my dual-LUT ALU!"},
  ]);
});

test("os: reply arrives on another contact, disconnect goes offline", () => {
  const t = bootOs();
  const replies = [];
  t.radio.onFrame = ({type, route, payload}) => {
    if (type === 8) replies.push({route,
      text: String.fromCharCode(...payload.slice(4))});
  };
  t.key(30); t.step(TICK);
  t.key(13); t.step(TICK);
  t.demo();
  settleUntil(t, 2, 11, "Ama");
  settleUntil(t, 29, 23, "Hello");
  settleReplies(t, replies, 4);
  // Wait for the last personality line before
  // opening another conversation. Displaying Hello alone is not TX completion.
  settleUntil(t, 33, 32, "Try 23 + 19");
  t.step(TICK * 20);
  // Only navigate once the first greeting fully clears TX: the firmware
  // paces BLE chunks 35ms apart, so rapid input mid-transmit is a different
  // (firmware-level) scenario, not navigation.
  t.key(13); t.step(TICK); // open Ama chat
  t.key(17); t.step(TICK); // back to contacts
  t.key(31); t.step(TICK); // down to Kofi
  t.key(13); t.step(TICK); // open Kofi chat
  t.message(2, "Hey");
  settleUntil(t, 27, 7, "Kofi");
  settleUntil(t, 29, 23, "Hey");
  settleReplies(t, replies, 8);
  assert.deepEqual(replies.slice(4), [
    {route: 2, text: "Hello, Kofi! I'm Tomato."},
    {route: 2, text: "I reply from a dorm table I call home."},
    {route: 2, text: "Tyrone Marhguy built me transistor-up!"},
    {route: 2, text: "Try 23 + 19 on my dual-LUT ALU!"},
  ]);
  t.disconnect();
  settleUntil(t, 52, 2, "Bridge offline", 20);
});
