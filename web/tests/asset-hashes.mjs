import test from "node:test";
import assert from "node:assert/strict";
import { scanAll } from "../scripts/hash-assets.mjs";

test("local CSS/JS references carry current content hashes (run npm run hash:assets)", () => {
  const stale = scanAll({ write: false });
  assert.deepEqual(
    stale,
    [],
    `stale asset versions in:\n${stale.join("\n")}\nrun: npm run hash:assets`
  );
});
