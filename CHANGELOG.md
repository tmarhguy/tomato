# Changelog

Tomato’s project history, written from the engineering journal
([`docs/log/`](docs/log/)) and the full git timeline (606 commits,
2026-06-05 → 2026-09-18). This is not a dump of commit subjects: each
section explains what changed, why it mattered, and what was later
superseded.

**Current machine facts** live in [`docs/status.md`](docs/status.md).
Where a journal entry disagrees with that file (word width, opcode
counts, register file size, OS version), the status file wins. Journals
remain valuable as the trail of how the machine was discovered.

---

## Unreleased

Local work not yet committed to `main` (ISA LUT CSV exploration,
remote-compute preview notes, Nordic envelop setup scratch, regenerated
FPGA/microcode artifacts, and similar) is omitted until it lands.

---

## [2026-09-14] – [2026-09-18] — Envelop, Dual-LUT compiler, Virtual Tomato

Tomato stopped being only a desktop-on-HDMI demo and grew a path to the
outside world: a messaging client, a bounded remote compute story, and a
browser emulator that can run the same OS image without waiting on a
bitstream.

### Envelop (messaging + remote compute)

Envelop began as a separate project so Tomato could send and receive
text without turning the Tomato repository into a chat product. The
name replaced a short-lived “Pigeon” label. On the Tomato side, an OS
menu entry, assembly client, and bounded executor were linked into the
firmware image; web/native clients, backend, and nearby bridge live in
the Envelop repository.

Design choices that stuck:

- **Chat-only scope.** Envelop is not a general companion app. It
  carries messages and bounded compute requests.
- **Nearby radio as a radio.** An nRF8001 ACI controller was wired onto
  the Nexys path so the FPGA talks BLE ACI rather than absorbing Wi-Fi
  into the same board story. Nordic-generated setup records are not
  redistributed; physical radio use needs a locally supplied setup
  image.
- **Provenance over personality.** Remote math is a tiny deterministic
  parser → Tomato IR path, fail-closed on unknowns—not an LLM persona
  pretending to be the machine.
- **Hardware vs preview are separate.** A hardware job that times out
  is an unknown outcome; it must not silently fall back to Virtual
  Tomato. Browser preview is explicit and labeled.

Journal trail:
[Origin](docs/log/2026-09-14%20-%20Envelop%20Origin.md),
[message app](docs/log/2026-09-14%20-%20Envelop%20-%20Tomato%20gets%20a%20message%20app.md),
[Native Bridge](docs/log/2026-09-14%20-%20Envelop%20Native%20Bridge.md),
[Website and World Connect](docs/log/2026-09-14%20-%20Envelop%20Website%20and%20World%20Connect.md),
[Multiple Participants](docs/log/2026-09-14%20-%20Multiple%20Participants.md),
[Parsing](docs/log/2026-09-15%20-%20Envelop%20Parsing%20-%20Simplest.md),
[Scope](docs/log/2026-09-15%20-%20Envelop%20Scope%20Optimization.md),
[Virtual vs AI](docs/log/2026-09-15%20-%20Virtual%20Fallback%20vs%20AI.md).

### Dual-LUT compiler on the FPGA

The opcode-search idea from July returned as real RTL: a 16-bit counter
FSM that enumerates all 65,536 `{lutB,lutA}` pairs for fixed A, B, C,
carry, and expected output, stopping at the first match. A hit proves
that example only—not a full truth table. HOLD/RESET controls and a
Compiler panel landed in the OS menu so the sweep is visible on the
desktop, not only in a testbench.

MMIO mapped the compiler (and radio) onto the keyboard-adjacent control
plane so software could drive the hardware without inventing a second
I/O architecture.

### Virtual Tomato

Long synth waits pushed a Python/web preview that runs the assembled OS
image functionally. Instead of discarding it, the preview became
**Virtual Tomato** on the site: a functional ISA-level emulator with
dual-LUT ALU behavior, banks, MMIO, and an ACI mailbox model—honestly
labeled as not cycle-accurate and not a substitute for a programmed
board. Image build tooling packs mem words, microcode planes, and
assets into a checked-in web image with freshness checks.

Journal:
[Synthesis Bypass](docs/log/2026-09-14%20-%20Synthesis%20Bypass.md),
[Discard or Integrate](docs/log/2026-09-15%20-%20Discard%20Previewer%20or%20Integrate.md).

### Documentation and site

Canonical project facts were written down, the docs hierarchy rebuilt,
architecture diagrams published, and the public site foregrounded the
board plus live OS/compiler story. The build journal became searchable.
An Ethernet bring-up harness appeared briefly and was removed as a
superseded experiment.

### Also in this window

- Assembler and microcode regenerated for the expanded ALU family;
  FPGA burn/sim copies kept in sync.
- Envelop firmware shipped with site refresh; remote/Envelop test
  targets made self-contained.
- Dual-LUT remote ABI polish and live board activity LEDs (2026-09-18).

**PRs:** #34 (compiler FSM), #35/#36 (messaging entry points).

---

## [2026-09-05] – [2026-09-13] — Desktop v1.2, ISA growth, open verify

### Desktop polish on real glass

With HDMI working, attention shifted to making Tomato feel like a small
computer rather than a menu of demos. Ghana wallpaper was burned as an
RGB444 ROM and composited under the text framebuffer. Data memory grew
to **384 KiB**. Keypad debounce was restored and exercised so one press
stayed one press after the earlier edge fix.

**Sudoku** joined the OS despite the five-button keyboard: arrows move,
a button cycles digits 1–9—hardware limits treated as UI constraints,
not blockers. An HDMI capture card replaced phone-at-monitor footage
for documentation.

The workspace UI revision is **Desktop v1.2**; the assembled OS title
string is **TOMATO OS v3.0** with a **14-entry** menu (see status.md).
Early August’s six-entry menu and ~52-opcode burns are historical.

Journal:
[Sudoku](docs/log/2026-09-11%20-%20Of%20Course%20Tomato%20Needs%20Sudoku.md),
[Wallpaper & polish](docs/log/2026-09-11%20-%20Wallpaper%2C%20Polish%2C%20and%20the%20Rest%20of%20the%20Computer.md),
[HDMI captured](docs/log/2026-09-11%20-%20HDMI%2C%20Properly%20Captured.md),
[Assembly barrier](docs/log/2026-09-11%20-%20When%20assembly%20is%20still%20too%20high-level%20for%20Tomato.md).

### ISA upgrade — naming what the ALU already could do

Assembly mnemonics had been hiding capacity already present in the
dual-LUT hardware. Nine new ALU tricks were burned as named rows
without new chips—ANDN, ORN, CSEL, the MASKADD family (ANDADD / ORADD /
XORADD), ADC, SBC, RSB—taking the control ROM from the mid-50s up to
**61 instructions plus NOP (62 burned rows)** in a 512-row table.
Pseudos still do not add burned rows.

A latent RSB bug (always returning zero) was caught and fixed; a
`p0p1` regression covers the new set. MASKADD/XORAND also landed in
assembler, microcode packing, FPGA headers, and exhibit benches (ALU
Studio alongside Sudoku and Racer).

Journal: [ISA Upgrade](docs/log/2026-09-13%20-%20ISA%20Upgrade.md).

### Verification and CI

An open verification tier was added: gauntlet smoke / 10B / 130B paths,
signoff separated from everyday `make test`, a GitHub verify workflow,
and a Digital testbench extractor. Bare FPGA `make` targets wrap
through `env.sh`. Solderpad **SHL-2.1** SPDX headers were restored after
the mid-August license experiment.

**PR:** #33.

---

## [2026-08-26] – [2026-08-31] — HDMI OS, FOSS FPGA flow, “Tomato works”

### Video that actually reaches a monitor

Passive VGA→HDMI adapters failed on the lab monitor. The pivot was a
**PMOD DVI** path so the Artix-7 generates pixel data on pins that
already work. Color bars appeared immediately once the module arrived;
Tomato OS GUI work was unblocked.

Journal: [PMOD Pivot](docs/log/2026-08-26%20-%20The%20PMOD%20Pivot.md),
[Successful Video](docs/log/2026-08-28%20-%20Successful%20Video%20-%20FPGA%20+%20PMOD.md),
[Pixels on the Glass](docs/log/2026-08-28%20-%20Pixels%20on%20the%20Glass.md).

### Leaving Vivado as the daily driver

With video proven, Vivado on the available Windows machine became the
bottleneck. The default FPGA flow moved to **Yosys → nextpnr-xilinx →
Project X-Ray → openFPGALoader**, with an optional Vivado batch target
kept for the same board. The point was minutes-scale iteration, not
abandoning Xilinx silicon.

Journal:
[Beyond Vivado](docs/log/2026-08-28%20-%20Exploring%20Beyond%20Vivado%20-%20Open-Source%20Synthesis%20Pivot.md).

### Tomato OS v1.0 on HDMI

A real desktop burned into dmem: chrome, About, Fibonacci, Snake,
Tetris, Racer. Assembler gained `.space` for runtime arrays.
Place-and-route was targeted at **90 MHz** (a nextpnr `--freq` goal—not
the CPU clock; the board still divides 100 MHz to a **6.25 MHz** CPU
domain per status.md).

### One press, one key

The menu was unusable: a single D-pad tap skipped several entries
because the edge stayed asserted for the entire sample window while
software polled thousands of times. The fix was a short debounce plus a
**one-clock-wide edge**, plus a temporary cut to a clean six-entry menu
while the input path settled. Assembler **pseudos** (`CALL`, `BEQZ`,
`LI`, …) were driven from `tomato.v1.pseudo.csv` and rewritten across
the OS without adding burned ROM rows—binary stayed byte-identical to
the expanded source story.

Journal: [One Press, One Key](docs/log/2026-08-28%20-%20One%20Press%2C%20One%20Key.md).

### Milestone: it feels like a computer

By 29 August the FPGA was driving a TV with a multi-thousand-line OS
and playable games—the first experience that matches the project’s
vocabulary of **FPGA Tomato as the complete machine**, while the
soldering bench still held a **discrete ALU slice**. Dual-LUT ALU
gauntlet verification was wired into the harness. Gallery and README
heroes filled with Lot 07 plates and OS stills. A discrete-era proposal
for a much larger register file appeared in narrative surfaces; the
**current FPGA RTL remains 256 × 32-bit entries**.

Journal:
[Tomato works beautifully!](docs/log/2026-08-29%20-%20Tomato%20works%20beautifully!.md).

**PRs:** #27–#32.

---

## [2026-08-16] – [2026-08-25] — Broadsheet web, media, first solder

### Making the site as careful as the copper

The public site stayed vanilla HTML/CSS/JS plus Three.js—no React
bundler. The 3D ALU tour was the performance crisis: a ~31 MB KiCad
GLB with tens of thousands of meshes froze the main thread. A Draco
pipeline (dedup → join → flatten → weld → compress) brought it to
~1.3 MB and a handful of meshes. Paper/Black stock themes, hero MP4s,
opcode-sweep clips (Digital sim and FPGA), and security/caching
headers on Vercel followed. A film-letterbox/fog camera pass was tried
and removed for honesty.

Journal:
[Web Optimization](docs/log/2026-08-16%20-%20Tomato%20Web%20Optimization.md).

### Gallery temptation, then restraint

A magazine-layout gallery with save-scroll felt like a second website.
It was **reverted** to a simple slideshow with captions—the
“gallery paradox.”

Journal: [Gallery Paradox](docs/log/2026-08-20%20-%20The%20Gallery%20Paradox.md).

### First phase of assembly

DigiKey parts arrived. The first `07_alu` board took ACT151 muxes,
ACT283 adders, then LEDs and headers. Power-on showed light without
shorts; bad joints were hunted down. Caps were left off for early LED
tests. Without an onboard FSM, stimulus planning for A/B/C and opcode
pins pointed at 5 V ATmega rather than 3.3 V ESP32 headaches—useful for
slice validation even as the complete machine story moved to FPGA.

Journal:
[First Phase of Assembly](docs/log/2026-08-18%20-%20First%20Phase%20of%20Assembly.md),
[First Lights and Flux](docs/log/2026-08-21%20-%20First%20Lights%20and%20Flux.md),
[Invisible Logic](docs/log/2026-08-23%20-%20The%20Invisible%20Logic.md).

**PRs:** #23–#26.

---

## [2026-08-01] – [2026-08-15] — Order, license, FPGA burn, public face

### Remaining boards while fab runs

With the ALU routed, work shifted to 32-bit plumbing: data bus
arbitration via tri-state drivers and one-hot decode rather than
forests of 74257s, then register, PC/SP, memory, and shift/mul lots.
The July advice held: do not build a throwaway FSM for the fab wait;
build pieces that ship in the final machine.

Journal:
[Designing Additional Boards](docs/log/2026-08-02%20-%20Designing%20Additional%20Boards.md).

### Ordered Tomato

JLCPCB bare `07_alu` boards and DigiKey BOM for **two** 8-bit dual-LUT
slices (16-bit cascade bring-up): ACT151s, ACT283s, flag latch, zero
compare, LEDs, SIP networks—on the order of tens of dollars for parts
plus near-nothing for bare boards. Tomato left the screen.

Journal: [Ordered Tomato](docs/log/2026-08-07%20-%20Ordered%20Tomato.md).

### Broadsheet identity

The site rejected Stripe-product polish and generic colorful React.
Tomato is 70s–90s 74xx copper with a door back to now, so the front
became a **1990s broadsheet** (Ashtown Valley framing) with modern 3D
KiCad plates. The name “Tomato” itself was an escape from endless
“32b/40b cpu” generics—not a tomato joke with a backstory.

Journal:
[Ashtown Valley](docs/log/2026-08-13%20-%20Front-Page%20News%20in%20Ashtown%20Valley.md),
[Solder Station](docs/log/2026-08-13%20-%20Solder%20Station%20Arrives.md).

### ISA as a wire

Public wording rejected “supports N ISAs” marketing. An ISA here is a
parametric map of external bits onto mux selects—overlay word,
immediate box, dual-LUT—not a second computer in copper. Profiles and
CSV revisions can look numerous; the mechanism is the claim.

Journal: [ISA as a Wire](docs/log/2026-08-15%20-%20ISA%20as%20a%20Wire.md).

### PCBs arrive; FPGA and software pipelines land

Five `07_alu` boards arrived and passed power-rail continuity. On the
digital side: `main.v` with tomato.v1 microcode burn, assembler
`.s` → `.mem`, fib/collatz/MMIO smoke programs, Sky130 synthesis
hooks, formal/directed/UVM ALU harness, CPI reporting from Icarus.
Licensing and SPDX headers went public (SHL-2.1; a brief CERN-OHL-P-2.0
experiment on Aug 15 was later restored to SHL in September). The first
tomato.tmarhguy.com wave shipped Dual-LUT playground, board catalog
(lots 01–08), architecture map, and 3D tour.

Journal: [PCBs Arrive!](docs/log/2026-08-15%20-%20PCBs%20Arrive!.md).

**PRs:** #7–#21.

---

## [2026-07-30] – [2026-07-31] — The 40-bit day, then settling on 32

After months on Tomato32, instruction encoding—not the ALU—felt like
the bottleneck: 10-bit opcode, three register fields, and bank bits
filled a 32-bit word with no honest fourth operand for dual-LUT. A
unified **40-bit** word (12-bit INS, four register fields, roomier
banking) was designed and briefly widened through Digital.

The next day, buildability won. Tomato **fell back to 32-bit**: 512-row
/ 9-bit opcode index, four 5-bit operand fields plus 3-bit bank → **256
addressable GPRs** in the scheme that matches current RTL addressing.
The dual-LUT ALU PCB stayed as designed. The lingering strategic choice
was how to bring the board up—minimal FSM vs real peripherals—settling
toward peripherals and sim vectors rather than disposable stimulus
hardware, and not investing further in the 40-bit widen.

Journal:
[40b redesign](docs/log/2026-07-30%20-%20Redesign%20into%2040b%20(Old%20design%20=%2032b).md)
*(superseded)*,
[Falling back to 32b](docs/log/2026-07-31%20-%20Falling%20back%20to%2032b.md),
[Lingering thoughts](docs/log/2026-07-31%20-%20The%20lingering%20thoughts.md).

This is the permanent width decision. Tomato remains 32-bit.

---

## [2026-07-04] – [2026-07-26] — Dual-LUT lock-in, reusable slices, demos

### Architecture: two LUT3 planes into the adder

The lasting ALU identity landed: **`f(a,b,c) + g(a,b,c) + cin`**. A
single masked-invert / LUT2 path was rejected in favor of a second
independent 8:1 LUT3 despite needing more opcode bits—the operational
space mattered more than saving two chips per cell. Theoretical
redundancy was acknowledged for later pruning.

Journal:
[Architecture Upgrade](docs/log/2026-07-13%20-%20Architecture%20Upgrade.md).

### Board strategy experiments

A **16-bit cascading macro-cell** plan aimed at fab reuse (four boards
→ 64-bit) and smaller ~120 mm squares instead of a cramped 240 mm
monolith. Flag logic was planned only on edge boards; zero would
propagate Zin/Zout. That exploration is **superseded** as the primary
story—the physical path that shipped was an **8-bit dual-LUT slice**,
with the complete computer on FPGA—but modularity intent survived.

Journal:
[16b × 4](docs/log/2026-07-13%20-%20Downgrade%20for%20an%20upgrade%20-%2032b%20to%2016b%20x%204.md)
*(superseded exploration)*.

### Truth-table latch and opcode-search demos

Opcode truth tables gained latch thinking so repeated ADD does not
“black out” mid-resolve. Demo ideas rejected Fib/Collatz as the only
showpiece and sketched a self-programming FSM that searches opcodes
against expected results—seed of the later Dual-LUT compiler. Pipelined
“reprogram a cell just before use” stayed a thought experiment.

Journal:
[Truth Table Latch](docs/log/2026-07-13%20-%20Truth%20Table%20Latch.md),
[Demo Ideas](docs/log/2026-07-13%20-%20Demo%20Ideas.md),
[Pipelined FPGA](docs/log/2026-07-13%20-%20Pipelined%20FPGA%20-%20What%20if....md).

### Copper progress

KiCad routing drove through 16-bit and 8-bit boards toward DRC-clean
signoff; zero-flag logic used a 74688 instead of a reduction tree;
silkscreen art (Ghana, Achimota, Penn) appeared; FPGA FSM stubs began
brute-force opcode search and segment display tests.

---

## [2026-06-22] – [2026-06-30] — Schematics complete, then de-bloating the ALU

### Getting to zero ERC

Core ALU schematics closed; hex displays confirmed 32-bit sim behavior;
gated clocks gave way to OR-enforced output enables; global labeling
drove ERC from hundreds of issues to clean. `inv32`, LEDs, and override
switches made the board probeable. PCB dimensions and placements locked;
buses started to route.

### The big discrete optimizations

Routing pressure forced several architectural cleanups that define the
physical slice:

1. **74251 / 151 mux cells** over 125+138 trees—same logic, stronger
   drive, less contention, shorter buses.
2. **4-bit 74283 slices** instead of a one-bit soup, with generate /
   propagate cleaned via NAND identities (~eight inverter-driver chips
   saved vs naïve AND + 54541 banks).
3. **Elimination of mode multiplexers.** Parallel adder-vs-LUT races
   into banks of 74257s were deleted. The LUT3 feeds the adder A inputs:
   arithmetic programs the LUT as a wire; logic programs the LUT and
   forces B=0 / cin=0 so the adder is a transparent exit. Eight 74257s
   and thirty-two A-mask gates left the design. Carry-skip inside each
   4-bit slice replaced a full CLA “central spine” that was hell to
   route on PCB.
4. Tri-state 251 paths later preferred **151** where High-Z faults
   threatened.

Journal:
[74251 redesign](docs/log/2026-06-26%20-%20ALU%20-%20Redesign%20with%2074251.md),
[ALU refinement](docs/log/2026-06-26%20-%20ALU%20Architecture%20Refinement%20&%20Logic%20Optimization.md),
[Mode mux elimination](docs/log/2026-06-27%20-%20Elimination%20of%20Mode%20Multiplexers.md).

Register-file testing (3R/1W), CSR flag widening, and ATF16V8B segment
displays rounded out the month. Absolute discrete-MHz claims in the
journals are historical estimates—not the current Nexys CPU clock story.

---

## [2026-06-15] – [2026-06-21] — Multiply, modular microcode, seeing the buses

### Multiplication without a chip farm

Naïve shift-add (~32 cycles) and Wallace-tree area were both rejected.
The settled discrete approach is a **priority-encoder feedback loop**:
smaller operand into the encoder, jump to the next set bit, barrel-shift
the multiplicand by 2ⁿ in one cycle, clear that bit, repeat—best case
about one cycle, worst case on the order of sixteen for a 32-bit-out
multiply, reusing shifter and ALU rather than a dedicated array. Shift
and mul-div boards merged.

Journal:
[Mul-Div Engine](docs/log/2026-06-10%20-%20Implementing%20Mul-Div%20Engine.md),
[Multiplication and Division](docs/log/2026-06-15%20-%20Multiplication%20and%20Division.md).

### Microcode as six local boards

One central EEPROM and a 64-bit splitter was fanout hell on a real
backplane. Decode split into small boards next to what they drive—ALU,
shift/mul, IR/reg/writeback, mem I/O, mem bus, PC/stack—each with its
own small EEPROM on a shared IR opcode backplane. HALT stayed on main.
The FPGA later burns the same modular planes as headers and mem files.

Journal:
[Microcode Modularization](docs/log/2026-06-16%20-%20Microcode%20Control%20Modularization.md).

### Display and verification

A thirty-two-digit hex display for A/B/C/W went through BCD dead-ends
and gate-count disasters into a shared font ROM with scanned latches
(~69 ICs). Formal 1b/8b/32b proofs, directed replay, and UVM scaffolding
started. Register file was pulled onto the ALU board to cut inter-board
wires (~96 → under 40). Writeback mux became the main bus; store-mux
left main.

Journal:
[ALU segment display](docs/log/2026-06-19%20-%20ALU%20segment%20display%20design.md).

---

## [2026-06-08] – [2026-06-14] — Flexible datapath, IR, PC, first ISA lock

The top-level Digital sheet stopped being a sketch and became a
multiplexed machine:

- Bus arbitration widened to **8:1 via drivers with enables**—more
  flexibility without a cost explosion.
- Instruction register gained **native immediate decode** and a
  byte-lane decoder aimed at RISC-V-shaped imm overlays—not to become
  RISC-V, but to map foreign encodings onto Tomato’s muxes.
- Sign extension replaced naïve split/merge; memory addressing moved
  toward banked models.
- **Program counter** was redesigned for ISA flexibility; **stack
  pointer** and **store-mux** appeared; VGA pins showed up on main.
- Microcode words grew toward **48 bits** as control fields multiplied;
  multiply results entered the writeback mux.
- Fetch discipline hardened: PC-out asserted on every fetch so other
  paths cannot steal the bus mid-instruction.
- Load/store microcode was audited: several offsetted load/store rows
  forced address zero (`alu-op`/`alu-pre` clear while bus-select said
  ALU)—fixed in the field map. Store data remaining hardwired to one
  register was noted as a conventional `SW` limitation without Din
  wiring changes.

By mid-June, dozens of Digital tests passed and on the order of forty
ISA operations were locked in JSON—early counts, later superseded by
the burned CSV.

The engineering **build log** started here so questions and answers
would not live only in chat.

Journal:
[Load Store Pipeline](docs/log/2026-06-11%20-%20Load%20Store%20Pipeline%20Analysis.md),
[Welcome](docs/log/Welcome%20to%20Tomato%2032.md).

---

## [2026-06-05] – [2026-06-07] — Project birth

Tomato began as scaffolding, docs, and toolchains, then immediately as
hardware: custom symbols, gate primitives, cascading mux hierarchies,
slice and adder cells, and a hierarchical **32-bit ALU** in Digital and
KiCad. Shift, flag, register, microcode, and IR boards appeared;
program-counter subcircuits and keyboard I/O simulation followed.

Primitive ALU operations were mapped and tested at about **ninety-one
single-cycle** truth-table ops—the first concrete “what can this cell
do?” catalog, long before the named ISA CSV. Early Verilog exports that
did not match the living Digital design were cleared out.

**PR:** #1.

---

## What was tried and later set aside

Useful as a reverse index when old docs disagree with the present
machine:

| Idea | When | Fate |
|------|------|------|
| Unified 40-bit machine word | 2026-07-30 | Reverted next day; Tomato is 32-bit |
| 16b × 4 cascade as primary PCB story | 2026-07-13 | Superseded exploration; shipped discrete path is 8b slice + FPGA computer |
| 32,768-GPR / deep bank narrative | late Aug narrative | Not current FPGA RTL (256 × 32-bit) |
| Gallery as magazine + save-scroll | 2026-08-20 | Reverted to slideshow |
| Film letterbox / fog 3D tour | 2026-08-16 | Removed |
| “Supports N ISAs” marketing | 2026-08-15 | Rejected framing (ISA as wire) |
| Vivado as default daily FPGA flow | pre-2026-08-28 | Default is Yosys / nextpnr / X-Ray |
| Six-entry menu / ~52–53 burned opcodes | Aug–early Sep | Grown to 14-entry OS v3.0 / Desktop v1.2 / 61+NOP |
| Envelop name “Pigeon” | Sep 14 | Retired |
| Ethernet bring-up harness | Sep 16–17 | Removed as superseded |
| Brief CERN-OHL-P-2.0 relicense | 2026-08-15 | SHL-2.1 restored |

---

## How to read this against the raw history

```bash
# Every subject line, oldest first
git log --reverse --pretty=format:'%ad  %s' --date=short

# Journal index (narrative companion to this file)
open docs/log/README.md
```

Commit messages record *that* something changed; this changelog and the
journals record *why*. Prefer [`docs/status.md`](docs/status.md) whenever
a dated number fights the machine that boots today.
