import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

test("isa page mirrors tomato.v1.csv burns", () => {
  const json = JSON.parse(readFileSync(new URL("../data/isa/tomato.v1.json", import.meta.url), "utf8"));
  const html = readFileSync(new URL("../isa.html", import.meta.url), "utf8");
  assert.equal(json.romSlots, 512);
  assert.equal(json.burned, 53);
  assert.equal(json.open, 459);
  assert.equal((html.match(/class="isa-op"/g) || []).length, 53);
  assert.equal((html.match(/class="isa-cell is-burn"/g) || []).length, 53);
  assert.equal((html.match(/class="isa-cell is-open"/g) || []).length, 459);
  assert.match(html, /<h1[^>]*>Tomato ISA<\/h1>/);
  assert.match(html, /data\/isa\/tomato\.v1\.csv/);
  assert.match(html, /id="isa-peek"/);
  assert.match(html, /data-op="/);
  assert.match(html, /<!-- isa-generated:start -->/);
});
