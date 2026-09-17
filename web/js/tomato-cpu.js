/* Tomato CPU — functional (ISA-level) emulator for the web.
 *
 * The OS assembly + microcode CSV + RTL ROMs are the source of truth; the
 * checked-in web/data/tomato-os.bin (tools/build_web_image.py) is only a
 * repacked form of those artifacts. This file translates no semantics by
 * hand: every control signal comes from the same burned ROM tables the
 * FPGA includes (control.v), and every datapath mux mirrors main.v.
 *
 * What it is: fetch/decode/execute over tables, dual-LUT ALU (alu.v),
 * shifter/muldiv (shift.v, muldiv.v), byte lanes (lane.v), stack pointer
 * (sp.v), keyboard/timer/BLE MMIO and tile RAM (main.v, vga.v), and the
 * ACI-mailbox radio model the desktop harness speaks
 * (tools/virtual_tomato.cpp, at the mailbox boundary, not SPI).
 *
 * What it is not: cycle-accurate RTL. No pipeline phases, no electrical
 * timing, no FPGA resources. web/tests/tomato-emu.mjs keeps it honest by
 * running scripted sessions here and in programs, against exact expects.
 *
 * DOM-free on purpose: Node imports this file directly for regression.
 */

const CPU_HZ = 6250000;
const CLOCKS_PER_MS = CPU_HZ / 1000;

// Microcode plane order in the image (matches build_web_image.py).
const P_ALU_SHIFT = 0, P_LUTA = 1, P_LUTB = 2, P_IR = 3;
const P_MEMIO = 4, P_MEMBUS = 5, P_PC = 6, P_PCSP = 7;

const OP_HALT_A = 0xff, OP_HALT_B = 0xe2, OP_ECALL = 0xe1;
const OP_IN = 0x0c8;

const KEYCODES = new Set([30, 31, 17, 16, 13]); // up down left right enter

export function loadImage(source) {
  // Accept fetch ArrayBuffers and Node Buffers alike.
  let ab;
  if (source instanceof ArrayBuffer) ab = source;
  else if (ArrayBuffer.isView(source)) {
    ab = new Uint8Array(source.buffer, source.byteOffset, source.byteLength).slice().buffer;
  } else {
    ab = new Uint8Array(source).buffer;
  }
  const buffer = ab;
  const v = new DataView(buffer);
  const magic = String.fromCharCode(v.getUint8(0), v.getUint8(1), v.getUint8(2), v.getUint8(3));
  if (magic !== "TOM1") throw new Error("bad web image magic");
  if (v.getUint32(4, true) !== 1) throw new Error("bad web image version");
  const memWords = v.getUint32(8, true);
  let off = 28;
  const mem = new Uint32Array(memWords);
  for (let i = 0; i < memWords; i++, off += 4) mem[i] = v.getUint32(off, true);
  const planes = [];
  for (let p = 0; p < 8; p++, off += 512) planes.push(new Uint8Array(buffer, off, 512));
  const font = new Uint8Array(buffer, off, 2048); off += 2048;
  const pal = new Uint8Array(buffer, off, 48); off += 48;
  const paper = new Uint16Array(320 * 240);
  for (let i = 0; i < paper.length; i += 2, off += 3) {
    const b0 = v.getUint8(off), b1 = v.getUint8(off + 1), b2 = v.getUint8(off + 2);
    paper[i] = (b0 << 4) | (b1 >> 4);
    paper[i + 1] = ((b1 & 15) << 8) | b2;
  }
  const id = Array.from(new Uint8Array(buffer, 12, 16)).map((c) => String.fromCharCode(c)).join("");
  return { mem, planes, font, pal, paper, id };
}

function signExtend(value, bits) {
  const shift = 32 - bits;
  return (value << shift) >> shift;
}

function alu(a, b, c, lutA, lutB, cin, flags) {
  let fa = 0, fb = 0;
  for (let i = 0; i < 32; i++) {
    const idx = ((((c >>> i) & 1) << 2) | (((b >>> i) & 1) << 1) | ((a >>> i) & 1));
    fa |= (((lutA >>> idx) & 1) << i);
    fb |= (((lutB >>> idx) & 1) << i);
  }
  fa >>>= 0; fb >>>= 0;
  const s = fa + fb + cin;
  const sum = s >>> 0;
  return { sum, cout: s >= 4294967296 ? 1 : 0, fa, fb };
}

// Flags exactly per alu.v: aeff/beff evaluate the LUTs at the top bits.
function computeFlags(sum, cout, a, b, c, lutA, lutB) {
  const aeff = (lutA >>> (((((c >>> 31) & 1) << 2) | (((b >>> 31) & 1) << 1) | ((a >>> 31) & 1)))) & 1;
  const beff = (lutB >>> (((((c >>> 31) & 1) << 2) | (((b >>> 31) & 1) << 1) | ((a >>> 31) & 1)))) & 1;
  const z = sum === 0 ? 1 : 0;
  const n = (sum >>> 31) & 1;
  const vv = ((aeff ^ n) & (n ^ beff)) & 1;
  const lt = (vv ^ n) & 1;
  const gte = (~lt) & 1;
  const gt = ((~z) & gte) & 1;
  return ((((((((gte << 7) | (gt << 6)) | (lt << 5)) | (vv << 4)) | ((cout & 1) << 3)) | (n << 2)) | (((~z) & 1) << 1)) | z) >>> 0;
}

function shiftOp(mode, a, b) {
  const sh = b & 31;
  if (mode === 0) return (a << sh) >>> 0;
  if (mode === 1) return a >>> sh;
  if (mode === 2) return (a >> sh) >>> 0;
  if (sh === 0) return a >>> 0;
  return (((a >>> sh) | (a << (32 - sh))) >>> 0);
}

function muldiv(a, b, mode, mulen, isdiv) {
  a >>>= 0; b >>>= 0;
  if (!mulen) return { lo: shiftOp(mode, a, b), hi: 0 };
  const unsigned = mode & 1;
  if (!isdiv) {
    // 33-bit widened multiply exactly like the RTL cascade.
    const xa = unsigned ? BigInt(a) : BigInt(a | 0);
    const xb = unsigned ? BigInt(b) : BigInt(b | 0);
    const prod = xa * xb;
    return {
      lo: Number(prod & 0xffffffffn) >>> 0,
      hi: Number((prod >> 32n) & 0xffffffffn) >>> 0,
    };
  }
  if (b === 0) return { lo: 0xffffffff, hi: a };
  const negA = !unsigned && (a >>> 31) === 1;
  const negB = !unsigned && (b >>> 31) === 1;
  const magA = negA ? 4294967296 - a : a;
  const magB = negB ? 4294967296 - b : b;
  const magQ = Math.floor(magA / magB);
  const magR = magA - magQ * magB;
  const quot = (negA !== negB) ? (4294967296 - magQ) % 4294967296 : magQ;
  const rem = negA ? (magR === 0 ? 0 : (4294967296 - magR) >>> 0) : magR;
  return { lo: quot >>> 0, hi: rem >>> 0 };
}

function laneOut(sel, memIn, ioData) {
  memIn >>>= 0;
  const b0 = memIn & 255, b1 = (memIn >>> 8) & 255;
  const b2 = (memIn >>> 16) & 255, b3 = (memIn >>> 24) & 255;
  const h0 = memIn & 65535, h1 = (memIn >>> 16) & 65535;
  switch (sel) {
    case 0: return memIn;
    case 1: return (((((b0 << 8) | b1) << 8) | b2) << 8 | b3) >>> 0;
    case 2: return ioData & 255;
    case 3: return 0;
    case 4: return ((b0 << 24) >> 24) >>> 0;
    case 5: return ((b1 << 24) >> 24) >>> 0;
    case 6: return ((b2 << 24) >> 24) >>> 0;
    case 7: return ((b3 << 24) >> 24) >>> 0;
    case 8: return b0;
    case 9: return b1;
    case 10: return b2;
    case 11: return b3;
    case 12: return ((h0 << 16) >> 16) >>> 0;
    case 13: return ((h1 << 16) >> 16) >>> 0;
    case 14: return h0;
    case 15: return h1;
    default: return memIn;
  }
}

function crc16(bytes) {
  let c = 0xffff;
  for (const x of bytes) {
    c ^= (x << 8);
    for (let i = 0; i < 8; i++) c = ((c << 1) ^ ((c & 0x8000) ? 0x1021 : 0)) & 0xffff;
  }
  return c;
}

export function makeFrame(type, route, payload) {
  const head = [0x50, 0x47, 1, type, (route >> 8) & 255, route & 255,
    (payload.length >> 8) & 255, payload.length & 255];
  const body = head.concat(payload);
  const c = crc16(body);
  return body.concat([(c >> 8) & 255, c & 255]);
}

// ACI-mailbox radio, ported from tools/virtual_tomato.cpp (mailbox boundary,
// not SPI). Behavior is identical by construction: same events, same order.
class Radio {
  constructor() { this.reset(); }
  reset() {
    this.done = false; this.attached = false; this.demo = false;
    this.length = 0; this.setups = 0;
    this.command = new Uint8Array(32);
    this.event = []; this.stream = []; this.events = [];
    this.token = 100;
    this.events.push([0x81, 2, 0, 3]);
  }
  receive(frame) {
    for (let i = 0; i < frame.length; i += 20) {
      this.events.push([0x8c, 2].concat(frame.slice(i, i + 20)));
    }
  }
  connect() {
    if (this.attached || !this.demo || this.setups < 21) return;
    this.attached = true;
    this.events.push([0x85]);
    this.events.push([0x88, 8]);
    this.receive(makeFrame(1, 0, []));
  }
  message(route, textBytes) {
    if (!this.attached) return;
    this.token = (this.token + 1) >>> 0;
    const t = this.token;
    const p = [(t >>> 24) & 255, (t >>> 16) & 255, (t >>> 8) & 255, t & 255].concat(textBytes);
    this.receive(makeFrame(7, route, p));
  }
  outgoing() {
    for (;;) {
      if (this.stream.length < 10) return;
      if (this.stream[0] !== 0x50 || this.stream[1] !== 0x47) { this.stream.shift(); continue; }
      const len = (this.stream[6] << 8) | this.stream[7];
      if (len > 512) { this.stream.shift(); continue; }
      if (this.stream.length < len + 10) return;
      const checked = this.stream.slice(0, len + 8);
      if (crc16(checked) !== ((this.stream[len + 8] << 8) | this.stream[len + 9])) {
        this.stream.shift(); continue;
      }
      const type = this.stream[3], route = (this.stream[4] << 8) | this.stream[5];
      const p = this.stream.slice(8, 8 + len);
      this.stream.splice(0, len + 10);
      this.onFrame?.({type, route, payload: p});
      const identity = "ENVELOP/1\nDEVICE=TOMATO\nID=TOMATO-001";
      if (type === 2 && p.map((c) => String.fromCharCode(c)).join("") === identity) {
        this.receive(makeFrame(3, 0, []));
        const names = ["Ama Mensah", "Kofi", "Ada"];
        for (let i = 0; i < 3; i++) {
          const nb = Array.from(names[i]).map((c) => c.charCodeAt(0));
          this.receive(makeFrame(4, i + 1, [i, 0].concat(nb)));
        }
        this.message(1, Array.from("Hello").map((c) => c.charCodeAt(0)));
      }
      if (type === 8 && p.length >= 5) {
        this.receive(makeFrame(9, route, p.slice(0, 4)));
      }
    }
  }
  read(a) {
    if (a & 64) return (a & 31) < this.event.length ? this.event[a & 31] : 0;
    if (a === 1) return this.length;
    if (a === 2) return this.event.length;
    return 8 | (this.events.length === 0 ? 4 : 0) | (this.done ? 1 : 0);
  }
  write(a, d) {
    d &= 255;
    if (a >= 32 && a < 64) { this.command[a - 32] = d; return; }
    if (a === 1) { this.length = d & 31; return; }
    if (a !== 0) return;
    if (d & 4) { this.reset(); return; }
    if (d & 2) this.done = false;
    if (!(d & 1)) return;
    this.event = [];
    if (this.events.length > 0) this.event = this.events.shift();
    if (this.length) {
      const op = this.command[0];
      if (op === 6) {
        this.setups++;
        this.events.push([0x84, 6, this.setups === 21 ? 2 : 1]);
        if (this.setups === 21) this.events.push([0x81, 3, 0, 3]);
      } else if (op === 0x0d) {
        this.events.push([0x84, 0x0d, 0]);
      } else if (op === 0x0f) {
        this.events.push([0x84, 0x0f, 0]);
        this.connect();
      } else if (op === 0x15) {
        for (let i = 2; i < this.length; i++) this.stream.push(this.command[i]);
        this.events.push([0x8a, 1]);
        this.outgoing();
      }
    }
    this.done = true;
  }
}

export class Tomato {
  constructor(image) {
    this.img = image;
    this.regs = new Uint32Array(256);
    this.dmem = new Uint32Array(16384);
    this.tiles = new Uint32Array(8192);
    this.dirty = new Set();
    this.radio = new Radio();
    this.reset();
  }
  reset() {
    this.pc = 0; this.bank = 0; this.flags = 0;
    this.pcLink = 0; this.sp = 0x3e00;
    this.clocks = 0; this.halted = false;
    this.kbData = 0; this.kbReady = false;
    this.compiler = {
      a: 0, b: 0, c: 0, expected: 0, cin: 0,
      count: 0, latched: 0,
      busy: false, hit: false, done: false, held: false,
    };
    this.regs.fill(0); this.tiles.fill(0); this.dirty.clear();
    this.dmem.set(this.img.mem.subarray(0, Math.min(this.img.mem.length, 16384)));
    this.radio.reset();
  }
  get ms() { return Math.floor(this.clocks / CLOCKS_PER_MS); }
  get menuSelection() { return this.regs[20]; }

  key(code) {
    if (!KEYCODES.has(code)) return false;
    this.kbData = code & 255;
    this.kbReady = true;
    return true;
  }
  demo() { this.radio.demo = true; this.radio.connect(); }
  disconnect() {
    this.radio.demo = false; this.radio.attached = false;
    this.radio.events = []; this.radio.stream = [];
    this.radio.events.push([0x86, 0, 0]);
  }
  contact(route, name) {
    if (!this.radio.attached) return false;
    if (!(route >= 1 && route <= 8) || name.length < 1 || name.length > 32) return false;
    for (const ch of name) {
      const c = ch.charCodeAt(0);
      if (c < 32 || c > 126) return false;
    }
    const nb = Array.from(name).map((c) => c.charCodeAt(0));
    this.radio.receive(makeFrame(4, route, [0, 0].concat(nb)));
    return true;
  }
  message(route, text) {
    if (!this.radio.attached) return false;
    if (!(route >= 1 && route <= 3) || text.length < 1 || text.length > 256) return false;
    const tb = Array.from(text).map((c) => c.charCodeAt(0));
    if (tb.some((c) => c < 32 || c > 126)) return false;
    this.radio.message(route, tb);
    return true;
  }

  mmioRead(addr) {
    if ((addr & 0x100) !== 0) return this.radio.read(addr & 0x7f);
    const sel = addr & 3;
    if (sel === 0) return this.kbData;
    if (sel === 1) return this.kbReady ? 1 : 0;
    if (sel === 2) return this.ms >>> 0;
    return CPU_HZ >>> 0;
  }

  compilerOut() {
    const c = this.compiler;
    return alu(c.a, c.b, c.c, c.count & 255, (c.count >>> 8) & 255, c.cin, 0).sum;
  }

  compilerRead(sel) {
    const c = this.compiler;
    if (sel === 0) return c.a;
    if (sel === 1) return c.b;
    if (sel === 2) return c.c;
    if (sel === 3) return c.cin;
    if (sel === 4) return c.expected;
    if (sel === 5) return this.compilerOut();
    if (sel === 6) return ((c.held ? 8 : 0) | (c.done ? 4 : 0) |
      (c.hit ? 2 : 0) | (c.busy ? 1 : 0)) >>> 0;
    return c.count >>> 0;
  }

  compilerWrite(sel, value) {
    const c = this.compiler;
    value >>>= 0;
    if (sel === 5 && (value & 4)) {
      c.count = 0; c.latched = 0;
      c.busy = false; c.hit = false; c.done = false; c.held = false;
    } else if (sel === 5 && (value & 2)) {
      c.busy = false; c.held = true;
    } else if (sel === 5 && (value & 1)) {
      c.busy = true; c.hit = false; c.done = false; c.held = false; c.count = 0;
    } else if (!c.busy) {
      if (sel === 0) c.a = value;
      else if (sel === 1) c.b = value;
      else if (sel === 2) c.c = value;
      else if (sel === 3) c.cin = value & 1;
      else if (sel === 4) c.expected = value;
    }
  }

  compilerAdvance(clocks) {
    const c = this.compiler;
    for (let i = 0; i < clocks && c.busy; i++) {
      if (this.compilerOut() === c.expected) {
        c.latched = c.count;
        c.hit = true; c.done = true; c.busy = false;
      } else if (c.count === 0xffff) {
        c.done = true; c.hit = false; c.busy = false;
      } else {
        c.count = (c.count + 1) & 0xffff;
      }
    }
  }

  stepOne() {
    if (this.halted) return;
    const P = this.img.planes;
    const w = this.dmem[this.pc & 0x3fff] >>> 0;
    const pcFall = (this.pc + 1) & 0xffffff;
    this.pc = pcFall;
    const op = (w >>> 23) & 0x1ff;
    const rd = (w >>> 18) & 31, ra = (w >>> 13) & 31;
    const rb = (w >>> 8) & 31, rc = (w >>> 3) & 31;
    const bankSel = w & 7;
    const b = w & 0x3fffff;

    const sh = P[P_ALU_SHIFT][op];
    const csel = sh & 7, flagWe = (sh >> 3) & 1;
    const shiftMode = (sh >> 4) & 3, mulEn = (sh >> 6) & 1, penc = (sh >> 7) & 1;
    const lutA = P[P_LUTA][op], lutB = P[P_LUTB][op];
    const ird = P[P_IR][op];
    const immSel = ird & 15, wbSel = (ird >> 4) & 7, regWe = (ird >> 7) & 1;
    const mio = P[P_MEMIO][op];
    const bankEn = mio & 1, memRd = (mio >> 1) & 1, memWr = (mio >> 2) & 1;
    const byteSel = (mio >> 3) & 15;
    const mb = P[P_MEMBUS][op];
    const busSel = mb & 7, aluSel = (mb >> 3) & 1;
    let d0 = P[P_PC][op];
    if (d0 === 0) d0 = 0x40;
    const branchEn = d0 & 1, jump = (d0 >> 1) & 1;
    const pcSrc = (d0 >> 2) & 7, linkWe = (d0 >> 5) & 1;
    const cycles = (d0 >> 6) & 3;
    const d1 = P[P_PCSP][op];
    const pcCond = d1 & 7, spOp = (d1 >> 4) & 3;

    const instructionClocks = cycles === 2 ? 3 : 2;
    this.clocks += instructionClocks;
    this.compilerAdvance(instructionClocks);
    if (op === OP_HALT_A || op === OP_HALT_B) { this.halted = true; return; }

    const base = this.bank * 32;
    const regA = ra === 0 ? 0 : this.regs[base + ra];
    const regB = rb === 0 ? 0 : this.regs[base + rb];
    const regC = rc === 0 ? 0 : this.regs[base + rc];

    let imm;
    switch (immSel) {
      case 0: imm = b & 255; break;
      case 1: imm = regB; break;
      case 2: imm = signExtend(b & 255, 8) >>> 0; break;
      case 3: imm = signExtend(b & 8191, 13) >>> 0; break;
      case 4: imm = b & 4095; break;
      case 5: imm = (b >>> 18) & 31; break;
      case 6: imm = (b >>> 16) & 31; break;
      case 7: imm = b & 65535; break;
      case 8: imm = signExtend(b & 65535, 16) >>> 0; break;
      case 9: imm = signExtend(b & 8388607, 23) >>> 0; break;
      case 10: imm = (((b >>> 7) & 65535) << 16) >>> 0; break;
      case 11: imm = (((b >>> 3) & 1048575) << 12) >>> 0; break;
      case 12: {
        imm = ((b & 65535) << 2) >>> 0;
        if ((b >>> 15) & 1) imm = (imm | 0xfffc0000) >>> 0;
        break;
      }
      case 13: {
        imm = ((b & 4194303) << 2) >>> 0;
        if ((b >>> 22) & 1) imm = (imm | 0x80000000) >>> 0;
        break;
      }
      case 14: imm = b; break;
      case 15: {
        imm = (b >>> 9) & 63;
        if ((b >>> 14) & 1) imm = (imm | 0xffffffc0) >>> 0;
        break;
      }
      default: imm = 0;
    }

    const aluA = aluSel ? regB : regA;
    // cin select: 0, 1, N, Z, C, GT, LT, V (alu.v).
    const cinMap = [0, 0, 2, 0, 3, 6, 5, 4];
    const cin = csel <= 1 ? csel : (this.flags >>> cinMap[csel]) & 1;
    const r = alu(aluA >>> 0, imm >>> 0, regC >>> 0, lutA, lutB, cin, this.flags);
    if (flagWe) this.flags = computeFlags(r.sum, r.cout, aluA >>> 0, imm >>> 0, regC >>> 0, lutA, lutB);
    const md = muldiv(aluA >>> 0, imm >>> 0, shiftMode, mulEn, penc);

    // Stack pointer (sp.v); op 2 presents post-decrement on the bus.
    let spOut = this.sp;
    if (spOp === 1) this.sp = (this.sp + 1) & 0xffffff;
    else if (spOp === 2) { spOut = (this.sp - 1) & 0xffffff; this.sp = spOut; }
    else if (spOp === 3) this.sp = r.sum & 0xffffff;

    // Address mux (bus.v).
    let addr;
    if (busSel === 0) addr = b;
    else if (busSel === 1) addr = r.sum & 0xffffff;
    else if (busSel === 2) addr = regB & 0xffffff;
    else if (busSel === 3) addr = pcFall;
    else if (busSel === 7) addr = spOut;
    else addr = 0;

    const isVga = ((addr >>> 19) & 7) === 6;
    const isKb = ((addr >>> 19) & 7) === 7;
    const isBle = isKb && (addr & 0x100) !== 0;
    const isCompiler = isKb && (addr & 0x80) !== 0 && !isBle;

    // Memory read.
    let memram;
    if (isBle) memram = this.radio.read(addr & 0x7f);
    else if (isCompiler) memram = this.compilerRead(addr & 7);
    else if (isKb) memram = this.mmioRead(addr);
    else memram = this.dmem[addr & 0x3fff];
    const memdin = laneOut(byteSel, memram, this.kbData);

    // Writeback mux (wb.v).
    let wb;
    if (wbSel === 0) wb = r.sum;
    else if (wbSel === 1) wb = md.lo;
    else if (wbSel === 2) wb = pcFall & 0xffffff;
    else if (wbSel === 3) wb = memdin;
    else if (wbSel === 4) wb = regA;
    else if (wbSel === 5) wb = imm >>> 0;
    else if (wbSel === 6) wb = this.flags;
    else wb = md.hi;
    wb >>>= 0;

    // Stores.
    if (memWr) {
      if (isBle) this.radio.write(addr & 0x7f, wb & 255);
      else if (isCompiler) this.compilerWrite(addr & 7, wb);
      else if (isVga) {
        const ti = addr & 0x1fff;
        this.tiles[ti] = wb;
        this.dirty.add(ti);
      } else if (!isKb) {
        const a = addr & 0x3fff;
        const cur = this.dmem[a];
        let nv;
        if (byteSel === 4 || byteSel === 8) nv = (cur & 0xffffff00) | (wb & 255);
        else if (byteSel === 5 || byteSel === 9) nv = (cur & 0xffff00ff) | ((wb & 255) << 8);
        else if (byteSel === 6 || byteSel === 10) nv = (cur & 0xff00ffff) | ((wb & 255) << 16);
        else if (byteSel === 7 || byteSel === 11) nv = (cur & 0x00ffffff) | ((wb & 255) << 24);
        else if (byteSel === 12 || byteSel === 14) nv = (cur & 0xffff0000) | (wb & 65535);
        else if (byteSel === 13 || byteSel === 15) nv = (cur & 0x0000ffff) | ((wb & 65535) << 16);
        else nv = wb;
        this.dmem[a] = nv >>> 0;
      }
    }

    // Key consume: MMIO word-0 load, or any IN.
    if ((memRd && isKb && !isBle && !isCompiler && (addr & 3) === 0) || op === OP_IN) this.kbReady = false;

    if (regWe && rd !== 0) this.regs[base + rd] = wb;

    // PC update (pc.v). Interrupts are hardwired off in main.v.
    const ecall = op === OP_ECALL;
    const cond = (this.flags >>> pcCond) & 1;
    const take = jump || (branchEn && cond) || ecall;
    const oldLink = this.pcLink;
    if (linkWe || ecall) this.pcLink = pcFall;
    if (ecall) this.pc = 0x100;
    else if (take) {
      if (pcSrc === 0) this.pc = b & 0xffffff;
      else if (pcSrc === 1) this.pc = (pcFall + signExtend(b, 22)) & 0xffffff;
      else if (pcSrc === 2) this.pc = oldLink;
      else if (pcSrc === 4) this.pc = r.sum & 0xffffff;
      else if (pcSrc === 5) this.pc = memdin & 0xffffff;
      else if (pcSrc !== 7) this.pc = pcFall;
    }

    if (bankEn) this.bank = bankSel;
  }

  step(count) {
    for (let i = 0; i < count && !this.halted; i++) this.stepOne();
    return this.halted;
  }

  tileText(x, y, n) {
    let s = "";
    for (let i = 0; i < n; i++) s += String.fromCharCode(this.tiles[y * 80 + x + i] & 255);
    return s;
  }
}
