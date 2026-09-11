#!/usr/bin/env node
/**
 * Anti-slop copy check for Tomato web pages.
 * Hard-fails on known marketing / LLM stock phrases.
 * Optionally prints write-good cliché hints (non-fatal unless CHECK_COPY_STRICT=1).
 *
 * Usage:
 *   node scripts/check-copy.mjs [paths...]
 *   CHECK_COPY_STRICT=1 node scripts/check-copy.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import writeGood from 'write-good';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(__dirname, '..');
const strict = process.env.CHECK_COPY_STRICT === '1';

/** Phrases that read like generated marketing copy on this project. */
const BANNED = [
  /logic changes with each instruction/i,
  /growing in discrete logic/i,
  /a different kind of (home )?computer/i,
  /the proof you can see/i,
  /still wondering\?/i,
  /unlock(s|ing)? the (full |true )?potential/i,
  /cutting[- ]edge/i,
  /seamless(ly)?/i,
  /empower(s|ing)?/i,
  /reimagine/i,
  /delve into/i,
  /in today's (fast[- ]paced|digital)/i,
  /it's important to note/i,
  /at the end of the day/i,
  /game[- ]changer/i,
  /robust solution/i,
  /holistic/i,
  /synergy/i,
  /revolutionary/i,
  /transformative/i,
  /elevate your/i,
  /dive deep/i,
  /landscape of/i,
  /nestled (in|within)/i,
  /tapestry of/i,
  /beacon of/i,
  /journey of/i,
  /embark on/i,
];

function stripHtml(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<!--[\s\S]*?-->/g, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#?\w+;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function defaultTargets() {
  return fs
    .readdirSync(webRoot)
    .filter((name) => name.endsWith('.html'))
    .map((name) => path.join(webRoot, name));
}

const targets = (process.argv.slice(2).length
  ? process.argv.slice(2).map((p) => path.resolve(webRoot, p))
  : defaultTargets()
).filter((p) => fs.existsSync(p) && p.endsWith('.html'));

let hardFailures = 0;
let hints = 0;

for (const file of targets) {
  const rel = path.relative(webRoot, file);
  const raw = fs.readFileSync(file, 'utf8');
  const text = stripHtml(raw);
  const bannedHits = [];
  const softHits = [];

  for (const re of BANNED) {
    const m = text.match(re);
    if (m) bannedHits.push(`banned phrase: "${m[0]}"`);
  }

  const suggestions = writeGood(text, { passive: false, illusion: false, so: false }) || [];
  for (const s of suggestions) {
    const reason = String(s.reason || '');
    if (!/cliche/i.test(reason)) continue;
    const snippet = text.slice(s.index, s.index + Math.min(s.offset || 40, 48)).trim();
    softHits.push(`write-good (${reason}): …${snippet}…`);
  }

  if (bannedHits.length || softHits.length) {
    console.log(`\n${rel}`);
    for (const h of bannedHits) console.log(`  x ${h}`);
    for (const h of softHits) console.log(`  · ${h}`);
  }

  hardFailures += bannedHits.length;
  hints += softHits.length;
  if (strict) hardFailures += softHits.length;
}

if (hardFailures) {
  console.error(`\ncheck-copy: ${hardFailures} hard failure(s); ${hints} hint(s).`);
  process.exit(1);
}

console.log(`check-copy: ok (${targets.length} HTML file(s)${hints ? `, ${hints} hint(s)` : ''}).`);
