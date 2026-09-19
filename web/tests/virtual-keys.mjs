import test from "node:test";
import assert from "node:assert/strict";
import { createKeypad, REPEAT_DELAY_MS, REPEAT_INTERVAL_MS } from "../js/virtual-keys.js";

function fakeCpu() {
  return {
    kbReady: false,
    keys: [],
    key(code) {
      this.keys.push(code);
      this.kbReady = true;
    },
    consume() {
      this.kbReady = false;
    },
  };
}

test("a single press is one key even if the OS is ready again before keyup", () => {
  let t = 0;
  const pad = createKeypad({ now: () => t });
  const cpu = fakeCpu();
  pad.press(31);
  pad.pump(cpu);
  assert.deepEqual(cpu.keys, [31]);
  cpu.consume();
  t = REPEAT_DELAY_MS - 1;
  pad.pump(cpu);
  pad.pump(cpu);
  pad.pump(cpu);
  assert.deepEqual(cpu.keys, [31]);
  pad.release(31);
  t = REPEAT_DELAY_MS + REPEAT_INTERVAL_MS;
  pad.pump(cpu);
  assert.deepEqual(cpu.keys, [31]);
});

test("holding past the delay keeps sending on the repeat interval", () => {
  let t = 0;
  const pad = createKeypad({ now: () => t });
  const cpu = fakeCpu();
  pad.press(31);
  pad.pump(cpu);
  cpu.consume();
  t = REPEAT_DELAY_MS;
  pad.pump(cpu);
  assert.deepEqual(cpu.keys, [31, 31]);
  cpu.consume();
  t += REPEAT_INTERVAL_MS - 1;
  pad.pump(cpu);
  assert.deepEqual(cpu.keys, [31, 31]);
  t += 1;
  pad.pump(cpu);
  assert.deepEqual(cpu.keys, [31, 31, 31]);
  pad.release(31);
  cpu.consume();
  t += REPEAT_INTERVAL_MS;
  pad.pump(cpu);
  assert.deepEqual(cpu.keys, [31, 31, 31]);
});
