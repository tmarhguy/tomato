/**
 * Tomato Dual-LUT ALU — same machine as hardware/fpga/tomato/rtl/alu.v
 *
 * lut[{C,B,A}]  (C is MSB).  out = int(f(A,B,C)) + int(g(A,B,C)) + cin
 * csr: [0]Z [1]~Z [2]N [3]C [4]V [5]LT [6]GT [7]GTE
 * csel: 0, 1, N, Z, C, GT, LT, V
 */

export function mask(width) {
  return width >= 32 ? 0xffffffff : ((1 << width) - 1) >>> 0;
}

export function lutIndex(a, b, c) {
  return ((c & 1) << 2) | ((b & 1) << 1) | (a & 1);
}

export function lutEval(lut, a, b, c) {
  return (lut >>> lutIndex(a, b, c)) & 1;
}

export function popcount(n) {
  n >>>= 0;
  n = n - ((n >>> 1) & 0x55555555);
  n = (n & 0x33333333) + ((n >>> 2) & 0x33333333);
  return (((n + (n >>> 4)) & 0x0f0f0f0f) * 0x01010101) >>> 24;
}

export function hex(n, width) {
  const digits = Math.max(1, Math.ceil(width / 4));
  return "0x" + (n >>> 0).toString(16).toUpperCase().padStart(digits, "0");
}

export function parseIntWord(raw, width) {
  const s = String(raw).trim().replace(/[_ ]/g, "");
  if (!s) return 0;
  let v;
  if (/^0b/i.test(s)) v = parseInt(s.slice(2), 2);
  else v = parseInt(s.replace(/^0x/i, ""), 16);
  if (!Number.isFinite(v)) return 0;
  return (v >>> 0) & mask(width);
}

export const CSEL = [
  { id: 0, name: "0", hint: "tie-low" },
  { id: 1, name: "1", hint: "tie-high / ADC seed" },
  { id: 2, name: "N", hint: "latched sign" },
  { id: 3, name: "Z", hint: "latched zero" },
  { id: 4, name: "C", hint: "latched carry" },
  { id: 5, name: "GT", hint: "latched greater" },
  { id: 6, name: "LT", hint: "latched less" },
  { id: 7, name: "V", hint: "latched overflow" },
];

export const FLAG_BITS = [
  { bit: 0, name: "Z", title: "Zero" },
  { bit: 1, name: "~Z", title: "Not zero" },
  { bit: 2, name: "N", title: "Negative" },
  { bit: 3, name: "C", title: "Carry out" },
  { bit: 4, name: "V", title: "Overflow" },
  { bit: 5, name: "LT", title: "Less than (signed)" },
  { bit: 6, name: "GT", title: "Greater than (signed)" },
  { bit: 7, name: "GTE", title: "Greater or equal" },
];

export function cinFromCsel(csel, flags) {
  switch (csel & 7) {
    case 0:
      return 0;
    case 1:
      return 1;
    case 2:
      return (flags >>> 2) & 1;
    case 3:
      return flags & 1;
    case 4:
      return (flags >>> 3) & 1;
    case 5:
      return (flags >>> 6) & 1;
    case 6:
      return (flags >>> 5) & 1;
    default:
      return (flags >>> 4) & 1;
  }
}

function flagsNext(width, lutA, lutB, A, B, C, out, cout) {
  const msb = width - 1;
  const aeff = lutEval(lutA, (A >>> msb) & 1, (B >>> msb) & 1, (C >>> msb) & 1);
  const beff = lutEval(lutB, (A >>> msb) & 1, (B >>> msb) & 1, (C >>> msb) & 1);
  const z = out === 0 ? 1 : 0;
  const n = (out >>> msb) & 1;
  const c = cout & 1;
  const v = (aeff ^ n) & (n ^ beff);
  const lt = v ^ n;
  const gte = lt ^ 1;
  const gt = (z ^ 1) & gte;
  return (gte << 7) | (gt << 6) | (lt << 5) | (v << 4) | (c << 3) | (n << 2) | ((z ^ 1) << 1) | z;
}

/**
 * Combinational Dual-LUT add. Matches alu8b / alu (without the flag latch).
 */
export function aluEval({ width, lutA, lutB, A, B, C, cin }) {
  const w = width | 0;
  const m = mask(w);
  lutA &= 255;
  lutB &= 255;
  A = (A >>> 0) & m;
  B = (B >>> 0) & m;
  C = (C >>> 0) & m;
  cin &= 1;

  let fa = 0;
  let fb = 0;
  let out = 0;
  const bits = new Array(w);
  let carry = cin;
  for (let i = 0; i < w; i++) {
    const a = (A >>> i) & 1;
    const b = (B >>> i) & 1;
    const c = (C >>> i) & 1;
    const idx = lutIndex(a, b, c);
    const f = (lutA >>> idx) & 1;
    const g = (lutB >>> idx) & 1;
    const s = f + g + carry;
    const sum = s & 1;
    const coutBit = s >>> 1;
    if (f) fa += 2 ** i;
    if (g) fb += 2 ** i;
    if (sum) out += 2 ** i;
    bits[i] = { i, a, b, c, idx, f, g, cin: carry, sum, cout: coutBit };
    carry = coutBit;
  }

  fa >>>= 0;
  fb >>>= 0;
  out >>>= 0;
  const cout = carry;
  const flags = flagsNext(w, lutA, lutB, A, B, C, out, cout);

  return { width: w, lutA, lutB, A, B, C, cin, fa, fb, out, cout, flags, bits };
}

export function liveLutBits(evaled) {
  const used = new Set();
  for (const bit of evaled.bits) used.add(bit.idx);
  return [...used].sort((a, b) => a - b);
}

/**
 * Flip each source; report which OUT bits and flags moved.
 */
export function sensitivity(state) {
  const base = aluEval(state);
  const w = state.width;
  const rows = [];

  const push = (source, next) => {
    const r = aluEval(next);
    const outXor = (r.out ^ base.out) >>> 0;
    const flagXor = (r.flags ^ base.flags) & 255;
    rows.push({
      source,
      outXor,
      flagXor,
      outBits: bitsOn(outXor, w),
      flagNames: FLAG_BITS.filter((f) => (flagXor >>> f.bit) & 1).map((f) => f.name),
      moved: outXor !== 0 || flagXor !== 0,
    });
  };

  for (const name of ["A", "B", "C"]) {
    for (let i = 0; i < w; i++) {
      push(`${name}[${i}]`, { ...state, [name]: state[name] ^ (1 << i) });
    }
  }
  for (let i = 0; i < 8; i++) {
    push(`lutA[${i}]`, { ...state, lutA: state.lutA ^ (1 << i) });
    push(`lutB[${i}]`, { ...state, lutB: state.lutB ^ (1 << i) });
  }
  push("cin", { ...state, cin: state.cin ^ 1 });
  return { base, rows };
}

function bitsOn(word, width) {
  const out = [];
  for (let i = 0; i < width; i++) if ((word >>> i) & 1) out.push(i);
  return out;
}

export function truthTable(lutA, lutB, cin) {
  const rows = [];
  for (let idx = 0; idx < 8; idx++) {
    const a = idx & 1;
    const b = (idx >>> 1) & 1;
    const c = (idx >>> 2) & 1;
    const f = (lutA >>> idx) & 1;
    const g = (lutB >>> idx) & 1;
    const s = f + g + (cin & 1);
    rows.push({ idx, a, b, c, f, g, sum: s & 1, cout: s >>> 1 });
  }
  return rows;
}

/* Curated LUT3 names from docs/isa/lut.csv (pin order A LSB). */
export const LUT_CATALOG = [
  [0x00, "ZERO", "0"],
  [0x01, "NOR3", "~(A|B|C)"],
  [0x03, "NOR_BC", "~(B|C)"],
  [0x05, "NOR_AC", "~(A|C)"],
  [0x0a, "A_AND_NOT_C", "A&~C"],
  [0x0c, "B_AND_NOT_C", "B&~C"],
  [0x0f, "NOT_C", "~C"],
  [0x11, "NOR_AB", "~(A|B)"],
  [0x17, "NMAJ", "~((A&B)|(B&C)|(A&C))"],
  [0x1b, "NMUX_A_CB", "~(A?B:C)"],
  [0x22, "A_AND_NOT_B", "A&~B"],
  [0x28, "A_XOR_BC", "A&(B^C)"],
  [0x33, "NOT_B", "~B"],
  [0x3c, "XOR_BC", "B^C"],
  [0x3f, "NAND_BC", "~(B&C)"],
  [0x44, "NOT_A_AND_B", "~A&B"],
  [0x55, "NOT_A", "~A"],
  [0x5a, "XOR_AC", "A^C"],
  [0x5f, "NAND_AC", "~(A&C)"],
  [0x66, "XOR_AB", "A^B"],
  [0x69, "XNOR3", "~(A^B^C)"],
  [0x77, "NAND_AB", "~(A&B)"],
  [0x7f, "NAND3", "~(A&B&C)"],
  [0x80, "AND3", "A&B&C"],
  [0x88, "AND_AB", "A&B"],
  [0x96, "XOR3", "A^B^C"],
  [0x99, "XNOR_AB", "~(A^B)"],
  [0xa0, "AND_AC", "A&C"],
  [0xa5, "XNOR_AC", "~(A^C)"],
  [0xaa, "PASS_A", "A"],
  [0xac, "MUX_C_AB", "C?A:B"],
  [0xc0, "AND_BC", "B&C"],
  [0xc3, "XNOR_BC", "~(B^C)"],
  [0xcc, "PASS_B", "B"],
  [0xe8, "MAJ", "(A&B)|(B&C)|(A&C)"],
  [0xee, "OR_AB", "A|B"],
  [0xf0, "PASS_C", "C"],
  [0xfa, "OR_AC", "A|C"],
  [0xfc, "OR_BC", "B|C"],
  [0xfe, "OR3", "A|B|C"],
  [0xff, "ONE", "1"],
];

const LUT_BY_HEX = new Map(LUT_CATALOG.map((row) => [row[0], { name: row[1], expr: row[2] }]));

/** Human-facing LUT names — no underscores in the UI. */
const LUT_LABELS = {
  ZERO: "Always low",
  ONE: "Always high",
  NOR3: "All three low",
  NOR_BC: "Neither B nor C",
  NOR_AC: "Neither A nor C",
  A_AND_NOT_C: "A when C is low",
  B_AND_NOT_C: "B when C is low",
  NOT_C: "Invert C",
  NOR_AB: "Neither A nor B",
  NMAJ: "Minority vote",
  NMUX_A_CB: "Opposite of C ? A : B",
  A_AND_NOT_B: "A when B is low",
  A_XOR_BC: "A when B ≠ C",
  NOT_B: "Invert B",
  XOR_BC: "B xor C",
  NAND_BC: "Not (B and C)",
  NOT_A_AND_B: "Not A, and B",
  NOT_A: "Invert A",
  XOR_AC: "A xor C",
  NAND_AC: "Not (A and C)",
  XOR_AB: "A xor B",
  XNOR3: "Even parity",
  NAND_AB: "Not (A and B)",
  NAND3: "Not all three",
  AND3: "All three high",
  AND_AB: "A and B",
  XOR3: "Odd parity",
  XNOR_AB: "A equals B",
  AND_AC: "A and C",
  XNOR_AC: "A equals C",
  PASS_A: "Wire A through",
  MUX_C_AB: "C picks A or B",
  AND_BC: "B and C",
  XNOR_BC: "B equals C",
  PASS_B: "Wire B through",
  MAJ: "Majority vote",
  OR_AB: "A or B",
  PASS_C: "Wire C through",
  OR_AC: "A or C",
  OR_BC: "B or C",
  OR3: "Any input high",
};

export function lutLabel(name) {
  if (LUT_LABELS[name]) return LUT_LABELS[name];
  if (name.startsWith("LUT_")) {
    const n = parseInt(name.slice(4), 16);
    const expr = truthExpr(n);
    if (expr.length <= 28) return expr;
    return `Unlisted ${hex(n, 8)}`;
  }
  return name.replace(/_/g, " ");
}

/** Catalog token for titles — AND3, PASS A, or a compact expr / hex. */
export function lutShort(info) {
  if (info.known) return info.name.replace(/_/g, " ");
  if (info.expr.length <= 20) return info.expr;
  return hex(info.hex, 8);
}

export function pairTitle(lutA, lutB, cin, prog) {
  if (prog) return prog.name;
  const xa = lutInfo(lutA);
  const yb = lutInfo(lutB);
  const xs = lutShort(xa);
  const ys = lutShort(yb);
  if ((lutB & 255) === 0 && (cin & 1) === 0) return xs;
  return `${xs} + ${ys}`;
}

export function lutInfo(lut) {
  const n = lut & 255;
  const known = LUT_BY_HEX.get(n);
  if (known) {
    return { hex: n, name: known.name, label: lutLabel(known.name), expr: known.expr, known: true };
  }
  const code = `LUT_${n.toString(16).toUpperCase().padStart(2, "0")}`;
  return { hex: n, name: code, label: lutLabel(code), expr: truthExpr(n), known: false };
}

function truthExpr(lut) {
  const terms = [];
  for (let i = 0; i < 8; i++) {
    if ((lut >>> i) & 1) {
      const a = i & 1 ? "A" : "~A";
      const b = i & 2 ? "B" : "~B";
      const c = i & 4 ? "C" : "~C";
      terms.push(`${a}&${b}&${c}`);
    }
  }
  return terms.length === 0 ? "0" : terms.length === 8 ? "1" : terms.join(" | ");
}

export const PRESET_GROUPS = [
  { id: "arith", label: "Arithmetic" },
  { id: "bitwise", label: "Bitwise" },
  { id: "bool3", label: "3-input" },
  { id: "hybrid", label: "Hybrid" },
];

/** Dual-LUT programs the inbound board actually runs. */
export const PROGRAMS = [
  { id: "add", group: "arith", name: "Add", lutA: 0xaa, lutB: 0xcc, cin: 0, csel: 0, blurb: "Sum A and B. X plane wires A; Y plane wires B." },
  { id: "adc", group: "arith", name: "Add + carry", lutA: 0xaa, lutB: 0xcc, cin: 1, csel: 1, blurb: "Same add, but carry in is tied high." },
  { id: "sub", group: "arith", name: "Subtract", lutA: 0xaa, lutB: 0x33, cin: 1, csel: 1, blurb: "A minus B — invert B on the Y plane, seed carry." },
  { id: "inc", group: "arith", name: "Increment", lutA: 0xaa, lutB: 0x00, cin: 1, csel: 1, blurb: "Bump A by one." },
  { id: "dec", group: "arith", name: "Decrement", lutA: 0xaa, lutB: 0xff, cin: 0, csel: 0, blurb: "Drop A by one." },
  { id: "neg", group: "arith", name: "Negate", lutA: 0x55, lutB: 0x00, cin: 1, csel: 1, blurb: "Two’s complement: invert A, add one." },
  { id: "and", group: "bitwise", name: "And", lutA: 0x88, lutB: 0x00, cin: 0, csel: 0, blurb: "Bitwise AND — one plane, Y tied off." },
  { id: "or", group: "bitwise", name: "Or", lutA: 0xee, lutB: 0x00, cin: 0, csel: 0, blurb: "Bitwise OR on the X plane." },
  { id: "xor", group: "bitwise", name: "Xor", lutA: 0x66, lutB: 0x00, cin: 0, csel: 0, blurb: "Bitwise XOR — the half-adder sum trick." },
  { id: "pass", group: "bitwise", name: "Pass A", lutA: 0xaa, lutB: 0x00, cin: 0, csel: 0, blurb: "Run operand A straight through." },
  { id: "not", group: "bitwise", name: "Not A", lutA: 0x55, lutB: 0x00, cin: 0, csel: 0, blurb: "Invert every bit of A." },
  { id: "and3", group: "bool3", name: "All three", lutA: 0x80, lutB: 0x00, cin: 0, csel: 0, blurb: "True only when A, B, and C are all high — opcode 0x80." },
  { id: "or3", group: "bool3", name: "Any input", lutA: 0xfe, lutB: 0x00, cin: 0, csel: 0, blurb: "True if any of A, B, or C is high." },
  { id: "nand3", group: "bool3", name: "Not all three", lutA: 0x7f, lutB: 0x00, cin: 0, csel: 0, blurb: "False only when every input is high." },
  { id: "xor3", group: "bool3", name: "Odd parity", lutA: 0x96, lutB: 0x00, cin: 0, csel: 0, blurb: "Three-way XOR — the full-adder sum bit." },
  { id: "xnor3", group: "bool3", name: "Even parity", lutA: 0x69, lutB: 0x00, cin: 0, csel: 0, blurb: "True when an even number of inputs are high." },
  { id: "maj", group: "bool3", name: "Majority", lutA: 0xe8, lutB: 0x00, cin: 0, csel: 0, blurb: "Two-of-three wins — the full-adder carry bit." },
  { id: "nmaj", group: "bool3", name: "Minority", lutA: 0x17, lutB: 0x00, cin: 0, csel: 0, blurb: "Inverted majority — carry-out’s shy cousin." },
  { id: "mux", group: "bool3", name: "Mux", lutA: 0xac, lutB: 0x00, cin: 0, csel: 0, blurb: "C high picks A; C low picks B." },
  { id: "hybrid", group: "hybrid", name: "Both bools", lutA: 0x80, lutB: 0x7f, cin: 0, csel: 0, blurb: "All-three on X, not-all-three on Y — sum stuck at one." },
];

export function matchProgram(lutA, lutB, cin) {
  return PROGRAMS.find((p) => p.lutA === (lutA & 255) && p.lutB === (lutB & 255) && p.cin === (cin & 1)) || null;
}

function scoreProgram(p) {
  const named = matchProgram(p.lutA, p.lutB, p.cin) ? 0 : 1;
  const single = p.lutB === 0 ? 0 : 1;
  const pop = popcount(p.lutA) + popcount(p.lutB) + p.cin;
  return (named << 24) | (single << 16) | (pop << 8) | p.lutA;
}

/**
 * Sweep the 16-bit opcode space (and cin) until every constraint row matches.
 * Same job as the hardware compiler FSM: compress a family to one program.
 */
export function resolveConstraints(width, rows, opts = {}) {
  const cinChoices = opts.cin == null ? [0, 1] : [opts.cin & 1];
  const lutBMax = opts.singlePlane ? 0 : 255;
  let count = 0;
  let best = null;
  let bestScore = Infinity;
  const sample = [];
  const named = [];
  const seenNamed = new Set();

  for (let lutA = 0; lutA < 256; lutA++) {
    for (let lutB = 0; lutB <= lutBMax; lutB++) {
      for (const cin of cinChoices) {
        let ok = true;
        for (const row of rows) {
          const r = aluEval({
            width,
            lutA,
            lutB,
            A: row.A,
            B: row.B,
            C: row.C,
            cin,
          });
          if (r.out !== ((row.out >>> 0) & mask(width))) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        count++;
        const prog = { lutA, lutB, cin };
        const sc = scoreProgram(prog);
        if (sc < bestScore) {
          bestScore = sc;
          best = prog;
        }
        if (sample.length < 16) sample.push(prog);
        const hit = matchProgram(lutA, lutB, cin);
        if (hit && !seenNamed.has(hit.id)) {
          seenNamed.add(hit.id);
          named.push({ ...prog, name: hit.name });
        }
      }
    }
  }

  return { count, best, sample, named, space: 256 * (lutBMax + 1) * cinChoices.length };
}

/**
 * Find Dual-LUT programs whose 1-bit sum matches an 8-row truth table
 * (ABC → out) with a constant cin.
 */
export function resolveTruth(truth, opts = {}) {
  const t = truth & 255;
  const rows = [];
  for (let idx = 0; idx < 8; idx++) {
    rows.push({
      A: idx & 1,
      B: (idx >>> 1) & 1,
      C: (idx >>> 2) & 1,
      out: (t >>> idx) & 1,
    });
  }
  return resolveConstraints(1, rows, opts);
}
