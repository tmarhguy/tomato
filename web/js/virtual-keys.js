/* Shared Virtual Tomato keypad: one tap is one event; hold repeats after a delay.
 *
 * Used by the full board (virtual.js) and the homepage embed (virtual-embed.js).
 * Repeat starts only after REPEAT_DELAY_MS so a short press cannot look like
 * several steps while the key is still physically down. Auto-repeat is capped
 * by REPEAT_INTERVAL_MS so a hold ticks instead of racing the OS.
 */
export const KEYMAP = { ArrowUp: 30, ArrowDown: 31, ArrowLeft: 17, ArrowRight: 16, Enter: 13 };
export const REPEAT_DELAY_MS = 333;
export const REPEAT_INTERVAL_MS = 147;

export function createKeypad({ now = () => performance.now() } = {}) {
  const queue = [];
  const heldCount = new Map();
  const heldOrder = [];
  const heldSince = new Map();
  let nextRepeatAt = 0;

  function resetTiming() {
    nextRepeatAt = 0;
  }

  function noteSent() {
    nextRepeatAt = now() + REPEAT_INTERVAL_MS;
  }

  function press(code) {
    const n = (heldCount.get(code) || 0) + 1;
    heldCount.set(code, n);
    if (n === 1) {
      heldOrder.push(code);
      heldSince.set(code, now());
      queue.push(code);
      resetTiming();
    }
  }

  function release(code) {
    const n = (heldCount.get(code) || 0) - 1;
    if (n <= 0) {
      heldCount.delete(code);
      heldSince.delete(code);
      const i = heldOrder.lastIndexOf(code);
      if (i >= 0) heldOrder.splice(i, 1);
      if (!heldOrder.length) resetTiming();
    } else {
      heldCount.set(code, n);
    }
  }

  function clear() {
    heldCount.clear();
    heldOrder.length = 0;
    heldSince.clear();
    queue.length = 0;
    resetTiming();
  }

  function held() {
    return heldOrder.length ? heldOrder[heldOrder.length - 1] : 0;
  }

  function idle() {
    return queue.length === 0 && heldOrder.length === 0;
  }

  function pump(cpu, paused = false) {
    if (!cpu) return;
    while (queue.length > 0 && !cpu.kbReady) {
      cpu.key(queue.shift());
      noteSent();
    }
    if (queue.length > 32) queue.splice(0, queue.length - 32);
    const code = held();
    if (paused || !code || cpu.kbReady || queue.length > 0) return;
    const t = now();
    if (t - heldSince.get(code) < REPEAT_DELAY_MS) return;
    if (t < nextRepeatAt) return;
    cpu.key(code);
    noteSent();
  }

  return { press, release, clear, pump, idle };
}
