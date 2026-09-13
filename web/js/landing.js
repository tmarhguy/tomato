/** Front page: progressive enhancement, with the same ALU model as the playground. */
import { aluEval, hex, lutInfo, lutShort } from './alu.js?v=d026bffa';

const themeButton = document.querySelector('[data-theme-toggle]');
function syncBoardPoster() {
  const img = document.querySelector('.board-image');
  if (!img) return;
  const light = document.documentElement.dataset.theme === 'light';
  const next = light
    ? (img.dataset.srcLight || 'assets/pcb/board-iso-light.webp')
    : (img.dataset.srcDark || 'assets/pcb/board-iso.webp');
  if (img.getAttribute('src') !== next) img.src = next;
  window.__TOMATO_BOARD_ISO__ = next;
}
function reflectTheme() {
  const light = document.documentElement.dataset.theme === 'light';
  if (themeButton) {
    themeButton.hidden = false;
    themeButton.textContent = light ? 'Dark mode' : 'Light mode';
    themeButton.setAttribute('aria-label', light ? 'Switch to dark theme' : 'Switch to light theme');
  }
  const mark = document.querySelector('.wordmark img');
  if (mark) mark.src = light ? 'assets/mark.svg' : 'assets/mark-dark.svg';
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.content = light ? '#f5f5f0' : '#050505';
  syncBoardPoster();
}
function applyTheme(mode) {
  document.documentElement.dataset.theme = mode;
  document.documentElement.style.colorScheme = mode;
  try { localStorage.setItem('tomato.theme', mode); } catch { /* Theme works without storage. */ }
  reflectTheme();
  document.dispatchEvent(new CustomEvent('tomato:theme', { detail: { mode } }));
}
if (themeButton) {
  themeButton.hidden = false;
  reflectTheme();
  themeButton.addEventListener('click', () => {
    const mode = document.documentElement.dataset.theme === 'light' ? 'dark' : 'light';
    applyTheme(mode);
  });
}
try {
  const scheme = matchMedia('(prefers-color-scheme: dark)');
  const onSystem = (event) => {
    applyTheme(event.matches ? 'dark' : 'light');
  };
  if (scheme.addEventListener) scheme.addEventListener('change', onSystem);
  else if (scheme.addListener) scheme.addListener(onSystem);
} catch { /* matchMedia optional */ }
window.addEventListener('storage', (event) => {
  if (event.key !== 'tomato.theme') return;
  if (event.newValue === 'dark' || event.newValue === 'light') {
    document.documentElement.dataset.theme = event.newValue;
    document.documentElement.style.colorScheme = event.newValue;
    reflectTheme();
  }
});

function nibbleBinary(value) {
  const bits = (value & 255).toString(2).padStart(8, '0');
  return `${bits.slice(0, 4)} ${bits.slice(4)}`;
}

/** Curated Dual-LUT programs for the homepage 8-bit walkthrough. */
const RULES = {
  add: {
    lutA: 0xaa, lutB: 0xcc, cin: 0,
    expression: 'A + B',
    explain: (A, B, C, out) => `${A} + ${B} = ${A + B}. The low 8 bits are ${nibbleBinary(out)} (${out}); carry out is ${A + B > 255 ? 1 : 0}.`,
  },
  subtract: {
    lutA: 0xaa, lutB: 0x33, cin: 1,
    expression: 'A − B',
    explain: (A, B, C, out) => `Subtract by inverting B on G and seeding carry. ${A} − ${B} = ${A - B} (shown as an 8-bit wrap: ${nibbleBinary(out)}).`,
  },
  mask: {
    lutA: 0xaa, lutB: 0xc0, cin: 0,
    expression: 'A + (B ∧ C)',
    explain: (A, B, C, out) => {
      const mask = B & C;
      return `Keep bits shared by B and C (${mask} = ${nibbleBinary(mask)}), then add A: ${A} + ${mask} = ${A + mask}. Low 8 bits: ${out}.`;
    },
  },
  choose: {
    lutA: 0xd8, lutB: 0x00, cin: 0,
    expression: '(A ∧ B) ⊕ (¬A ∧ C)',
    explain: (A, B, C, out) => `SHA-256 Choose: for each bit, if A is 1 take B, else take C. Result ${out} = ${nibbleBinary(out)}.`,
  },
  majority: {
    lutA: 0xe8, lutB: 0x00, cin: 0,
    expression: 'Majority(A, B, C)',
    explain: (A, B, C, out) => `SHA-256 Majority: each output bit is 1 when at least two of A, B, C are 1. Result ${out} = ${nibbleBinary(out)}.`,
  },
  xor3: {
    lutA: 0x96, lutB: 0x00, cin: 0,
    expression: 'A ⊕ B ⊕ C',
    explain: (A, B, C, out) => `Three-way XOR (odd parity / full-adder sum bit). ${nibbleBinary(A)} ⊕ ${nibbleBinary(B)} ⊕ ${nibbleBinary(C)} = ${nibbleBinary(out)} (${out}).`,
  },
  and3: {
    lutA: 0x80, lutB: 0x00, cin: 0,
    expression: 'A ∧ B ∧ C',
    explain: (A, B, C, out) => `AND3: a bit survives only when A, B, and C are all 1. Result ${out} = ${nibbleBinary(out)}.`,
  },
  increment: { lutA:0xaa, lutB:0x00, cin:1, expression:'A + 1', explain:(A,B,C,out)=>`Advance a counter: ${A} + 1 = ${A+1}. Low 8 bits: ${out}.` },
  decrement: { lutA:0xaa, lutB:0xff, cin:0, expression:'A − 1', explain:(A,B,C,out)=>`Count down: ${A} − 1 = ${A-1}. Low 8 bits: ${out}.` },
  double: { lutA:0xaa, lutB:0xaa, cin:0, expression:'A + A', explain:(A,B,C,out)=>`Double an unsigned value: ${A} × 2 = ${A*2}. Low 8 bits: ${out}.` },
  setbits: { lutA:0xee, lutB:0x00, cin:0, expression:'A OR B', explain:(A,B,C,out)=>`Set the bits selected by mask B, keeping the other bits of A. Result: ${out}.` },
  clearbits: { lutA:0x22, lutB:0x00, cin:0, expression:'A AND NOT B', explain:(A,B,C,out)=>`Clear the bits selected by mask B, keeping the other bits of A. Result: ${out}.` },
  togglebits: { lutA:0x66, lutB:0x00, cin:0, expression:'A XOR B', explain:(A,B,C,out)=>`Toggle the bits selected by mask B. Result: ${out}.` },
  invert: { lutA:0x55, lutB:0x00, cin:0, expression:'NOT A', explain:(A,B,C,out)=>`Invert all eight bits of A: ones become zeros and zeros become ones. Result: ${out}.` },
  masksubtract: { lutA:0xaa, lutB:0x3f, cin:1, expression:'A − (B AND C)', explain:(A,B,C,out)=>`Keep the bits shared by B and C, then subtract that mask from A: ${A} − ${B&C} = ${A-(B&C)}. Low 8 bits: ${out}.` },
  xorand: { lutA:0x96, lutB:0x80, cin:0, expression:'XOR3(A,B,C) + AND3(A,B,C)', explain:(A,B,C,out)=>`F computes odd parity; G finds bits set in all three inputs. Add both Boolean results. Low 8 bits: ${out}.` },
  choosemajority: { lutA:0xd8, lutB:0xe8, cin:0, expression:'Choose(A,B,C) + Majority(A,B,C)', explain:(A,B,C,out)=>`Run two different Boolean functions on F and G, then add their results. Low 8 bits: ${out}. This compound example is not a complete SHA-256 step.` },
};

function paintOperand(prefix, value) {
  const el = document.getElementById(`logic-${prefix}`);
  if (el && Number(el.value) !== value) el.value = String(value);
  document.getElementById(`logic-${prefix}-binary`).textContent = nibbleBinary(value);
  document.getElementById(`logic-${prefix}-hex`).textContent = hex(value, 8);
}

function paintTruth(lutA, lutB) {
  for (let i = 0; i < 8; i++) {
    document.getElementById(`logic-ft-${i}`).textContent = String((lutA >>> i) & 1);
    document.getElementById(`logic-gt-${i}`).textContent = String((lutB >>> i) & 1);
  }
}

function updateLogic() {
  const error = document.getElementById('logic-error');
  const ruleInput = document.getElementById('logic-rule-select');
  const rule = RULES[ruleInput?.value || 'add'];
  if (!rule) return;

  const values = ['a', 'b', 'c'].map(name => {
    const input = document.getElementById(`logic-${name}`);
    const value = Number(input.value);
    const valid = input.value.trim() !== '' && Number.isInteger(value) && value >= 0 && value <= 255;
    input.setAttribute('aria-invalid', String(!valid));
    return valid ? value : null;
  });
  if (values.includes(null)) {
    if (error) error.textContent = 'Enter whole numbers from 0 to 255. The last valid result remains visible.';
    return;
  }
  const [A, B, C] = values;
  paintOperand('a', A);
  paintOperand('b', B);
  paintOperand('c', C);

  const result = aluEval({ width: 8, A, B, C, cin: rule.cin, lutA: rule.lutA, lutB: rule.lutB });
  const fInfo = lutInfo(rule.lutA);
  const gInfo = lutInfo(rule.lutB);

  document.getElementById('logic-expression').textContent = rule.expression;
  document.getElementById('logic-output').textContent = String(result.out);
  document.getElementById('logic-output-binary').textContent = nibbleBinary(result.out);
  document.getElementById('logic-output-hex').textContent = hex(result.out, 8);
  document.getElementById('logic-explanation').textContent = rule.explain(A, B, C, result.out);

  document.getElementById('logic-f-opcode').textContent = hex(rule.lutA, 8);
  document.getElementById('logic-f-binary').textContent = nibbleBinary(rule.lutA);
  document.getElementById('logic-f-name').textContent = lutShort(fInfo);
  document.getElementById('logic-g-opcode').textContent = hex(rule.lutB, 8);
  document.getElementById('logic-g-binary').textContent = nibbleBinary(rule.lutB);
  document.getElementById('logic-g-name').textContent = lutShort(gInfo);

  document.getElementById('logic-f-value').textContent = nibbleBinary(result.fa);
  document.getElementById('logic-g-value').textContent = nibbleBinary(result.fb);
  document.getElementById('logic-carry').textContent = String(rule.cin);
  document.getElementById('logic-trace-result').textContent = nibbleBinary(result.out);
  document.getElementById('logic-carry-out').textContent =
    `Carry out: ${result.cout} · low 8 bits shown · f=${result.fa}, g=${result.fb}`;

  paintTruth(rule.lutA, rule.lutB);
  if (error) error.textContent = '';
}

const choices = document.getElementById('logic-rule-select');
const operands = document.getElementById('logic-operands');
if (choices) choices.disabled = false;
if (operands) operands.disabled = false;
choices?.addEventListener('change', updateLogic);
operands?.addEventListener('input', updateLogic);
if (choices || operands) updateLogic();

// Representative modes from hardware/fpga/core/rtl/ir.v.
const immediateModes = {
  unsigned8: { raw: 0xff, width: 8, signed: false, shift: 0, source: '0xFF', action: 'Fill the upper 24 bits with zeros', explanation: 'Unsigned 255 stays 255. The extra bits are zero-filled.' },
  signed8: { raw: 0xff, width: 8, signed: true, shift: 0, source: '0xFF', action: 'Repeat the sign bit across the upper 24 bits', explanation: 'In signed 8-bit form, 0xFF means −1. Sign extension keeps it −1 at 32 bits.' },
  signed13: { raw: 0x1ffc, width: 13, signed: true, shift: 0, source: '0x1FFC', action: 'Repeat the sign bit across the upper 19 bits', explanation: 'The signed 13-bit offset −4 becomes a full-width −4, ready for address arithmetic.' },
  upper20: { raw: 0x12345, width: 20, signed: false, shift: 12, source: '0x12345', action: 'Move the field left 12 bits; fill the low bits with zeros', explanation: 'LUI places 20 instruction bits in the top of the result: 0x12345 becomes 0x12345000.' },
};
const immediateControl = document.getElementById('immediate-mode');
function updateImmediate(mode) {
  const example = immediateModes[mode];
  if (!example) return;
  const extended = example.signed ? (example.raw << (32 - example.width)) >> (32 - example.width) : example.raw;
  const result = (extended << example.shift) >>> 0;
  document.getElementById('immediate-source').textContent = example.source;
  document.getElementById('immediate-width').textContent = `${example.width} bits`;
  document.getElementById('immediate-action').textContent = example.action;
  document.getElementById('immediate-result').textContent = '0x' + result.toString(16).toUpperCase().padStart(8, '0');
  document.getElementById('immediate-explanation').textContent = example.explanation;
  const binary = result.toString(2).padStart(32, '0');
  document.getElementById('immediate-bits').setAttribute('aria-label', `32-bit result in binary: ${binary}`);
  document.querySelectorAll('#immediate-bits > span').forEach((byte, index) => {
    byte.textContent = binary.slice(index * 8, index * 8 + 8);
    byte.className = (example.shift ? index === 3 : index < Math.floor((32 - example.width) / 8)) ? 'bit-extension' : '';
  });
}
if (immediateControl) {
  immediateControl.disabled = false;
  immediateControl.addEventListener('change', (event) => updateImmediate(event.target.value));
  updateImmediate(immediateControl.value);
}

// The board leads the page. The poster image is the fallback; there is no
// loading text so Controls + Tour never shift. They stay in place always.
const loadButton = document.getElementById('load-board');
const canvas = document.getElementById('front-bench');
const feedback = document.getElementById('board-feedback');
const viewerControls = document.getElementById('viewer-controls');
if (loadButton && canvas) {
  // The Controls disclosure is always visible so its position never shifts.
  // It stays open when picking views — only an explicit minimize
  // (summary toggle or Escape) closes it. Board drags never dismiss it.
  if (viewerControls) {
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && viewerControls.open) viewerControls.open = false;
    });
  }
  async function loadBoard() {
    loadButton.disabled = true;
    const stage = canvas.parentElement;
    try {
      const { mountBench } = await import('./bench.js?v=29899518');
      canvas.hidden = false;
      const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      // Spin on first load; halt on drag; the board never auto-resets.
      // hud:false — the hero chrome owns its single Controls disclosure.
      // scrollFriendly:false — every gesture inside the board box drives the
      // board, never the page. Users scroll from outside the stage.
      await mountBench(canvas, { glb: 'assets/pcb/alu.glb', autoRotate: !reducedMotion, hud: false, scrollFriendly: false });
      canvas.tabIndex = 0;
      loadButton.hidden = true;
      if (feedback) {
        feedback.hidden = true;
        feedback.textContent = '';
      }

    } catch (error) {
      canvas.hidden = true;
      stage.classList.remove('is-ready');
      stage.querySelectorAll('.bench-hud, .bench-mark-wrap').forEach((node) => node.remove());
      stage.style.touchAction = 'auto';
      if (feedback) {
        feedback.hidden = false;
        feedback.textContent = 'The interactive model could not load. The board image is still available; you can also open the full 3D tour.';
      }
      loadButton.hidden = false;
      loadButton.disabled = false;
      loadButton.textContent = 'Retry 3D view';
      console.warn('Tomato board preview unavailable:', error);
    }
  }
  loadButton.addEventListener('click', loadBoard);
  loadBoard();
}

// Small, silent 2× preview; a click opens the full recording with native controls.
const osPreview = document.getElementById('os-preview');
const osDialog = document.getElementById('os-dialog');
if (osPreview && osDialog) {
  const expand = document.getElementById('os-expand');
  const fullVideo = document.getElementById('os-full-video');
  const toggle = document.getElementById('os-preview-toggle');
  let held = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let visible = false;
  osPreview.defaultPlaybackRate = 2;
  osPreview.playbackRate = 2;
  toggle.hidden = false;
  const syncPreview = () => {
    if (visible && !held && !osDialog.open && !document.hidden) {
      osPreview.playbackRate = 2;
      osPreview.play().catch(() => { toggle.textContent = 'Play preview'; });
    } else osPreview.pause();
    toggle.textContent = held ? 'Play preview' : 'Pause preview';
  };
  toggle.addEventListener('click', () => { held = !held; syncPreview(); });
  new IntersectionObserver(entries => { visible = entries[0].isIntersecting; syncPreview(); }, { threshold: .15 }).observe(osPreview);
  document.addEventListener('visibilitychange', syncPreview);
  expand.addEventListener('click', event => {
    if (typeof osDialog.showModal !== 'function') return;
    event.preventDefault();
    osPreview.pause();
    osDialog.showModal();
    fullVideo.currentTime = osPreview.currentTime;
    fullVideo.play().catch(() => {});
  });
  document.getElementById('os-close').addEventListener('click', () => osDialog.close());
  osDialog.addEventListener('click', event => { if (event.target === osDialog) {
    const box = osDialog.getBoundingClientRect();
    if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) osDialog.close();
  }});
  osDialog.addEventListener('close', () => { fullVideo.pause(); syncPreview(); expand.focus(); });
}
