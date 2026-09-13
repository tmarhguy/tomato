import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WEB = resolve(__dirname, '..');

test('board never auto-resets: idle module removed', () => {
  assert.equal(existsSync(join(WEB, 'js/bench-idle.js')), false, 'js/bench-idle.js should be removed');
  const bench = readFileSync(join(WEB, 'js/bench.js'), 'utf8');
  assert.doesNotMatch(bench, /createBenchIdle/, 'bench.js must not use idle helper');
  assert.doesNotMatch(bench, /idleResetMs/, 'bench.js must not accept idleResetMs');
  assert.doesNotMatch(bench, /resumeAfterReset/, 'bench.js must not auto-resume after reset');
  const landing = readFileSync(join(WEB, 'js/landing.js'), 'utf8');
  assert.doesNotMatch(landing, /idleResetMs/, 'landing.js must not pass idleResetMs');
  assert.doesNotMatch(landing, /15000/, 'landing.js must not contain 15s reset');
});
