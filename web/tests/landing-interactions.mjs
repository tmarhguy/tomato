/** Exercise user-facing calculations and saved themes without WebGL or a browser. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';
import { aluEval, hex, lutInfo, lutShort } from '../js/alu.js';

const web = fileURLToPath(new URL('..', import.meta.url));
const source = readFileSync(new URL('../js/landing.js', import.meta.url), 'utf8')
  .replace(/import \{[^}]+\} from '\.\/alu\.js(\?v=[0-9a-f]+)?';/, '');

function harness({ savedTheme = 'dark', storageBlocked = false, media = false, reducedMotion = false } = {}) {
  const nodes = new Map();
  const makeNode = (key) => {
    const node = {
      textContent: '',
      value: '',
      src: '',
      hidden: true,
      disabled: true,
      handlers: {},
      attributes: {},
      classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } },
      addEventListener(type, handler) { this.handlers[type] = handler; },
      setAttribute(name, value) { this.attributes[name] = value; if (name in this) this[name] = value; },
      getAttribute(name) { return this.attributes[name] || null; },
    };
    nodes.set(key, node);
    return node;
  };
  const keys = [
    '[data-theme-toggle]', '.wordmark img', 'meta[name="theme-color"]',
    'logic-rule-select', 'logic-operands',
    'logic-a', 'logic-b', 'logic-c',
    'logic-a-binary', 'logic-b-binary', 'logic-c-binary',
    'logic-a-hex', 'logic-b-hex', 'logic-c-hex',
    'logic-expression', 'logic-output', 'logic-output-binary', 'logic-output-hex', 'logic-explanation', 'logic-error',
    'logic-f-opcode', 'logic-f-binary', 'logic-f-name',
    'logic-g-opcode', 'logic-g-binary', 'logic-g-name',
    'logic-f-value', 'logic-g-value', 'logic-carry', 'logic-trace-result', 'logic-carry-out',
    'logic-ft-0', 'logic-ft-1', 'logic-ft-2', 'logic-ft-3', 'logic-ft-4', 'logic-ft-5', 'logic-ft-6', 'logic-ft-7',
    'logic-gt-0', 'logic-gt-1', 'logic-gt-2', 'logic-gt-3', 'logic-gt-4', 'logic-gt-5', 'logic-gt-6', 'logic-gt-7',
    'immediate-mode', 'immediate-source', 'immediate-width', 'immediate-action', 'immediate-result', 'immediate-explanation', 'immediate-bits',
  ];
  for (const key of keys) makeNode(key);
  nodes.get('logic-a').value = '8';
  nodes.get('logic-b').value = '5';
  nodes.get('logic-c').value = '3';
  nodes.get('immediate-mode').value = 'unsigned8';
  const rule = { value: 'add' };
  const bytes = Array.from({ length: 4 }, (_, i) => makeNode(`byte-${i}`));
  let mediaObserver;
  if (media) {
    for (const id of ['os-preview','os-dialog','os-expand','os-full-video','os-preview-toggle','os-close']) makeNode(id);
    for (const id of ['os-preview','os-full-video']) {
      const video = nodes.get(id); video.paused = true; video.currentTime = 0;
      video.play = () => { video.paused = false; return Promise.resolve(); };
      video.pause = () => { video.paused = true; };
    }
    const dialog = nodes.get('os-dialog'); dialog.open = false;
    dialog.showModal = () => { dialog.open = true; };
    dialog.close = () => { dialog.open = false; dialog.handlers.close(); };
    nodes.get('os-expand').focus = () => { nodes.get('os-expand').focused = true; };
  }
  const document = {
    documentElement: { 
      dataset: { theme: savedTheme }, 
      style: {}, 
      setAttribute(attr, val) { if (attr === 'data-theme') this.dataset.theme = val; }, 
      removeAttribute(attr) { if (attr === 'data-theme') this.dataset.theme = 'light'; }, 
      classList: { add() {}, remove() {}, toggle() {} }, 
      getAttribute(attr) { return attr === 'data-theme' ? this.dataset.theme : null; } 
    },
    body: { dataset: {}, handlers: {}, addEventListener(type, handler) { this.handlers[type] = handler; }, insertAdjacentHTML() {} },
    head: { appendChild() {} },
    querySelector: (key) => {
      if (key === 'input[name="logic-rule"]:checked') return rule;
      return nodes.get(key) || null;
    },
    querySelectorAll: (key) => {
      if (key === '#immediate-bits > span') return bytes;
      if (key.includes('[data-theme-')) return [nodes.get('[data-theme-toggle]')];
      if (key.includes('img[src*="mark"]')) return [nodes.get('.wordmark img')];
      if (key.includes('.theme-switch')) return [document.body];
      return [];
    },
    getElementById: (key) => nodes.get(key) || null,
    createElement: (tag) => makeNode(tag),
    dispatchEvent() {},
    handlers: {},
    addEventListener(type, handler) { this.handlers[type] = handler; if (type === 'DOMContentLoaded') handler(); },
  };
  nodes.get('.wordmark img').setAttribute('src', 'assets/mark.svg');
  nodes.get('.wordmark img').src = 'assets/mark.svg';
  const writes = [];
  runInNewContext(source, {
    document, aluEval, hex, lutInfo, lutShort, console, Number, Math, String,
    window: { addEventListener() {}, matchMedia: () => ({ matches: reducedMotion }) },
    IntersectionObserver: class { constructor(fn) { mediaObserver = fn; } observe() {} },
    matchMedia: () => ({ matches: false }),
    requestAnimationFrame: (cb) => cb(),
    localStorage: {
      getItem(key) {
        if (storageBlocked) throw new Error('Storage disabled');
        return key === 'tomato.theme' ? (typeof savedTheme !== 'undefined' ? savedTheme : 'dark') : null;
      },
      setItem(key, value) {
        if (storageBlocked) throw new Error('Storage disabled');
        writes.push([key, value]);
      },
    },
    CustomEvent: class { constructor(name, options) { this.type = name; this.detail = options.detail; } },
  });
  return { nodes, document, writes, rule, showMedia: visible => mediaObserver([{ isIntersecting: visible }]) };
}

test('landing rules show binary, opcodes, and results that match the ALU model', () => {
  const { nodes, rule } = harness();
  assert.equal(nodes.get('logic-rule-select').disabled, false);
  assert.equal(nodes.get('logic-operands').disabled, false);
  assert.equal(nodes.get('logic-output').textContent, '13');
  assert.equal(nodes.get('logic-a-binary').textContent, '0000 1000');
  assert.equal(nodes.get('logic-f-opcode').textContent, '0xAA');
  assert.equal(nodes.get('logic-g-opcode').textContent, '0xCC');

  for (const [name, expected] of [
    ['add', 13],
    ['mask', 9],
    ['choose', 3],
    ['majority', 1],
    ['xor3', 14],
    ['and3', 0],
    ['subtract', 3],
    ['add', 13],
  ]) {
    nodes.get('logic-rule-select').value = name;
    nodes.get('logic-rule-select').handlers.change();
    assert.equal(nodes.get('logic-output').textContent, String(expected), name);
    assert.match(nodes.get('logic-output-binary').textContent, /^\d{4} \d{4}$/);
    assert.match(nodes.get('logic-f-opcode').textContent, /^0x[0-9A-F]{2}$/);
    assert.match(nodes.get('logic-g-opcode').textContent, /^0x[0-9A-F]{2}$/);
    assert.ok(nodes.get('logic-explanation').textContent.includes(String(expected)), `${name}: explanation agrees with result`);
  }
});

test('theme toggle honors the saved mode, persists the next mode, and works with blocked storage', () => {
  for (const storageBlocked of [false, true]) {
    const { nodes, document, writes } = harness({ savedTheme: 'light', storageBlocked });
    const button = nodes.get('[data-theme-toggle]');
    assert.equal(button.textContent, 'Dark mode');
    assert.equal(nodes.get('.wordmark img').src, 'assets/mark.svg');

    button.handlers.click();

    assert.equal(document.documentElement.dataset.theme, 'dark');
    assert.equal(button.textContent, 'Light mode');
    assert.equal(nodes.get('.wordmark img').src, 'assets/mark-dark.svg');
    assert.equal(writes.length, storageBlocked ? 0 : 1);
    button.handlers.click();
    assert.equal(document.documentElement.dataset.theme, 'light');
  }
});

test('homepage section links resolve to real anchors and IDs are unique', () => {
  const page = resolve(web, 'index.html');
  const html = readFileSync(page, 'utf8');
  const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map((m) => m[1]);
  assert.equal(ids.length, new Set(ids).size, 'duplicate homepage IDs');
  for (const match of html.matchAll(/href="([^"#]*)(#[^"]+)"/g)) {
    const [, path, hash] = match;
    if (/^https?:/.test(path)) continue;
    const target = path ? resolve(dirname(page), path) : page;
    assert.ok(existsSync(target), `missing page: ${path}`);
    let content = target === page ? html : readFileSync(target, 'utf8');
    // The existing playground renders its panels from its module and handles hashes.
    if (path === 'playground.html') {
      content += readFileSync(resolve(web, 'js/playground.js'), 'utf8');
    }
    const anchor = decodeURIComponent(hash.slice(1));
    assert.ok(content.includes(`id="${anchor}"`) || content.includes(`id='${anchor}'`), `missing anchor: ${path}${hash}`);
  }
});

test('immediate modes preserve unsigned and negative values and position LUI bits', () => {
  const { nodes } = harness();
  const control = nodes.get('immediate-mode');
  assert.equal(control.disabled, false);
  for (const [mode, expected] of [['unsigned8', 255], ['signed8', 2 ** 32 - 1], ['signed13', 2 ** 32 - 4], ['upper20', 0x12345 * 4096]]) {
    control.handlers.change({ target: { value: mode } });
    assert.equal(Number(nodes.get('immediate-result').textContent), expected, mode);
    const renderedBits = Array.from({ length: 4 }, (_, i) => nodes.get(`byte-${i}`).textContent).join('');
    assert.equal(renderedBits.length, 32);
    assert.equal(parseInt(renderedBits, 2), expected, `${mode}: diagram and numeric result agree`);
  }
});


test('all homepage ALU programs agree with independent arithmetic across varied inputs', () => {
  const { nodes, rule } = harness();
  const reference = {
    add: (a,b,c) => a + b,
    subtract: (a,b,c) => a - b,
    mask: (a,b,c) => a + (b & c),
    choose: (a,b,c) => (a & b) | (~a & c),
    majority: (a,b,c) => (a & b) | (a & c) | (b & c),
    xor3: (a,b,c) => a ^ b ^ c,
    and3: (a,b,c) => a & b & c,
    increment: a => a+1,
    decrement: a => a-1,
    double: a => a*2,
    setbits: (a,b) => a|b,
    clearbits: (a,b) => a&~b,
    togglebits: (a,b) => a^b,
    invert: a => ~a,
    masksubtract: (a,b,c) => a-(b&c),
    xorand: (a,b,c) => (a^b^c)+(a&b&c),
    choosemajority: (a,b,c) => ((a&b)|(~a&c))+((a&b)|(a&c)|(b&c)),
  };
  for (let i = 0; i < 64; i++) {
    const a = (i * 17) & 255, b = (255 - i * 3) & 255, c = (i * 31) & 255;
    for (const [name, calculate] of Object.entries(reference)) {
      nodes.get('logic-rule-select').value = name;
      nodes.get('logic-a').value = String(a);
      nodes.get('logic-b').value = String(b);
      nodes.get('logic-c').value = String(c);
      nodes.get('logic-operands').handlers.input();
      const expected = calculate(a,b,c) & 255;
      assert.equal(Number(nodes.get('logic-output').textContent), expected, `${name}(${a},${b},${c})`);
      assert.equal(parseInt(nodes.get('logic-output-binary').textContent.replace(/ /g,''),2), expected);
      assert.equal(Number(nodes.get('logic-output-hex').textContent), expected);
      const f = parseInt(nodes.get('logic-f-value').textContent.replace(/ /g,''),2);
      const g = parseInt(nodes.get('logic-g-value').textContent.replace(/ /g,''),2);
      const carry = Number(nodes.get('logic-carry').textContent);
      assert.equal((f + g + carry) & 255, expected, 'visible intermediate sum');
    }
  }
});

test('editing an operand never silently clamps or erases invalid input', () => {
  const { nodes } = harness();
  const input = nodes.get('logic-a');
  for (const value of ['', '-1', '256', '1.5']) {
    input.value = value;
    nodes.get('logic-operands').handlers.input();
    assert.equal(input.value, value);
    assert.equal(input.attributes['aria-invalid'], 'true');
    assert.equal(nodes.get('logic-output').textContent, '13');
    assert.match(nodes.get('logic-error').textContent, /0 to 255/);
  }
  input.value = '20';
  nodes.get('logic-operands').handlers.input();
  assert.equal(nodes.get('logic-output').textContent, '25');
  assert.equal(input.attributes['aria-invalid'], 'false');
  assert.equal(nodes.get('logic-error').textContent, '');
});

test('OS preview plays at 2× when visible and opens the larger controlled video', () => {
  const h = harness({media:true});
  const preview = h.nodes.get('os-preview'), full = h.nodes.get('os-full-video');
  h.showMedia(true); assert.equal(preview.playbackRate, 2); assert.equal(preview.paused,false);
  preview.currentTime = 40;
  let prevented = false;
  h.nodes.get('os-expand').handlers.click({preventDefault(){prevented=true;}});
  assert.equal(prevented,true); assert.equal(preview.paused,true);
  assert.equal(h.nodes.get('os-dialog').open,true); assert.equal(full.currentTime,40); assert.equal(full.paused,false);
  h.nodes.get('os-close').handlers.click();
  assert.equal(full.paused,true); assert.equal(preview.paused,false); assert.equal(h.nodes.get('os-expand').focused,true);
  h.showMedia(false); assert.equal(preview.paused,true);
});
test('OS preview honors reduced motion, explicit pause, and hidden documents', () => {
  const h=harness({media:true,reducedMotion:true}); const preview=h.nodes.get('os-preview');
  h.showMedia(true); assert.equal(preview.paused,true);
  h.nodes.get('os-preview-toggle').handlers.click(); assert.equal(preview.paused,false);
  h.document.hidden=true;h.document.handlers.visibilitychange();assert.equal(preview.paused,true);
  h.document.hidden=false;h.document.handlers.visibilitychange();assert.equal(preview.paused,false);
  h.nodes.get('os-preview-toggle').handlers.click();h.showMedia(false);h.showMedia(true);assert.equal(preview.paused,true);
});

test('journal entries number from the oldest upward and adjust to new entries', () => {
 const source = readFileSync(new URL('../js/journal-index.js',import.meta.url),'utf8');
 for (const count of [1,34,35]) {
  const nodes=Array.from({length:count},()=>({textContent:''}));
  runInNewContext(source,{document:{querySelectorAll:()=>nodes.map(n=>({querySelector:()=>n}))}});
  assert.equal(nodes[0].textContent,String(count).padStart(2,'0'));
  assert.equal(nodes.at(-1).textContent,'01');
 }
});
