import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

test("isa page mirrors tomato.v1.csv burns", () => {
  const json = JSON.parse(readFileSync(new URL("../data/isa/tomato.v1.json", import.meta.url), "utf8"));
  const html = readFileSync(new URL("../isa.html", import.meta.url), "utf8");
  const burns = json.rows.filter((r) => r.status === "burn");
  const nops = json.rows.filter((r) => r.status === "nop");
  const insnCount = burns.filter((r) => String(r.mnemonic).toUpperCase() !== "NOP").length;
  assert.equal(json.romSlots, 512);
  assert.equal(json.burned, burns.length);
  assert.equal(json.open, nops.length);
  assert.equal(json.instructions, insnCount);
  assert.equal(burns.length, insnCount + 1, "NOP is a burned row, not a named instruction");
  assert.equal((html.match(/class="isa-op"/g) || []).length, burns.length);
  assert.equal((html.match(/class="isa-cell is-burn"/g) || []).length, burns.length);
  assert.equal((html.match(/class="isa-cell is-open"/g) || []).length, nops.length);
  assert.match(html, /<h1[^>]*>Tomato ISA<\/h1>/);
  assert.match(html, /data\/isa\/tomato\.v1\.csv/);
  assert.match(html, /id="isa-peek"/);
  assert.match(html, /data-op="/);
  assert.match(html, /<!-- isa-generated:start -->/);
  assert.match(html, new RegExp(`${insnCount} instructions plus NOP`));
  assert.match(html, new RegExp(`${burns.length} burned rows`));
  assert.doesNotMatch(html, /<strong>53<\/strong> burned/);
  assert.doesNotMatch(html, /The 53 opcodes in use/);
});
