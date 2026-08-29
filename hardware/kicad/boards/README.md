# Tomato — PCB lots

<p align="center"><strong>Eight modular boards · Dual-LUT copper · Lot 07 on the iron.</strong></p>

![Lots](https://img.shields.io/badge/Lots-01%E2%80%9308-011F5B) ![Active](https://img.shields.io/badge/Active-07__alu-2ea043)

Numbered KiCad projects for the discrete Tomato machine. Each lot owns one subsystem so ribbons stay short and bring-up can happen board-by-board.

**Project map:** [KiCad](../README.md) · [Hardware](../../README.md) · [07_alu](07_alu/README.md) · Paper: [boards.html](https://tomato.tmarhguy.com/boards.html)

<p align="center">
  <img src="../../../web/assets/pcb/hero.webp" alt="Tomato ALU PCB hero plate" width="48%" />
  <img src="../../../web/assets/pcb/pcb-arrive.webp" alt="Tomato PCBs arrived" width="48%" />
</p>
<p align="center"><em>Lot plates · hero render &amp; boards in hand · <a href="07_alu/README.md">07_alu</a></em></p>

<p align="center">
  <img src="../../../web/assets/pcb/drc.webp" alt="KiCad DRC on Tomato ALU" width="48%" />
  <img src="../../../web/assets/plates/kicad-sch.jpg" alt="KiCad schematic" width="48%" />
</p>
<p align="center"><em>DRC and schematic · copper before iron</em></p>

| Board | Path | Role | Status |
|-------|------|------|--------|
| 01 | [01_alu/](01_alu/) | Early ALU experiments | Historical |
| 02 | [02_shift_encoder/](02_shift_encoder/) | Shift encoder + mul-div control | In design |
| 03 | [03_memory/](03_memory/) | Memory, byte-lane decoder, VGA | In design |
| 04 | [04_register/](04_register/) | Register file, IR | In design |
| 05 | [05_program_counter/](05_program_counter/) | PC, stack pointer | In design |
| 06 | [06_data_bus/](06_data_bus/) | Data bus, wb_mux, arbitration | In design |
| 07 | [07_alu/](07_alu/) | Dual-LUT ALU — **board doc + figures** | Populating |
| 08 | [08_alu_fsm/](08_alu_fsm/), [08_display/](08_display/) | FSM bring-up, display | In design |

Also present: `08_alu/` (related lot experiments). Prefer the numbered names in the table when linking from the paper.

**Bring-up:** assemble and probe Lot 07 first ([First Phase of Assembly](<../../../docs/log/2026-08-18%20-%20First%20Phase%20of%20Assembly.md>)). Peripherals follow once the Dual-LUT slice signs off on the bench.

---

## Legacy — transistor-era board inventory

> Historical inventory for the pre-Tomato 8-bit transistor / modular ALU boards (`alu/`, `main_logic/`, …). Those folder names are **not** the current `01_`–`08_` lots.

### Board Designs

**Individual PCB boards for the 8-Bit Transistor ALU system**

This directory contains KiCad projects for each functional board in the ALU system.

---

## Board Inventory

| Board | Size | Transistors | Purpose | Status |
|-------|------|-------------|---------|--------|
| [alu/](alu/) | 270×270mm | 3,488 | **Main combinational ALU** (monolithic) | Complete |
| [main_logic/](main_logic/) | varies | 640+ | Logic unit subsystem | Complete |
| [add_sub/](add_sub/) | varies | 120+ | Add/subtract XOR array | Complete |
| [flags/](flags/) | varies | ~240 | Flag generation (LESS/EQUAL/POSITIVE/COUT) | Complete |
| [main_control/](main_control/) | varies | ~100 | Opcode decoder | Complete |
| [led_panel/](led_panel/) | varies | 0 | Output display panels | Complete |

**Note:** The ALU can be implemented as:
- **Monolithic:** Single 270×270mm board (alu/)
- **Modular:** Separate boards (main_logic/, add_sub/, flags/, main_control/)

Current implementation uses modular approach for easier assembly and debugging.

---

## Monolithic ALU Board

**Directory:** `alu/`

**Description:** Complete 8-bit ALU on single 270×270mm PCB

**Contents:**
- All arithmetic logic (adder + XOR array)
- All logic functions (NAND/NOR/XOR/PASS)
- 2:1 MUX and global inverter
- Flag generation
- Control decoder
- Power distribution

**Advantages:**
- Single board design
- No inter-board connections
- Lower assembly complexity
- Optimal signal integrity

**Challenges:**
- Large format PCB
- Difficult to debug subsystems
- Must solder all components (3,488 equiv. transistors) before testing

---

## Modular Board System

### Main Logic Board

**Directory:** `main_logic/`

**Schematic:** [main_logic.kicad_sch](main_logic/main_logic.kicad_sch)

![Main Logic Schematic](../../../web/assets/schematics/boards/main_logic.svg)
*Figure 1 - Main logic unit schematic*

**Function:** Core logic operations (NAND, NOR, XOR, PASS)

**Transistors:** 640+

**Interfaces:**
```
IN:  A[7:0], B[7:0], LOGIC_SEL[2:0], VCC, GND
OUT: LOGIC_OUT[7:0]
```

![Main Logic PCB](../../../web/assets/pcb/layouts/main_logic.png)
*Figure 2 - Fabricated main logic board*

**Evidence:** Logic unit board fabricated and tested.

### Add/Sub Board

**Directory:** `add_sub/`

**Schematic:** [add_sub.kicad_sch](add_sub/add_sub.kicad_sch)

![Add/Sub Schematic](../../../web/assets/schematics/boards/add_sub_page-0001.jpg)
*Figure 3 - Add/subtract module schematic*

**Function:** 8-bit ripple-carry adder with conditional B inversion

**Components:**
- 8× 1-bit full adders (336T)
- 8× XOR gates for B (96T)
- Carry chain routing

**Interfaces:**
```
IN:  A[7:0], B[7:0], M (ADD/SUB), Cin, VCC, GND
OUT: SUM[7:0], COUT
```

![Add/Sub PCB](../../../web/assets/pcb/layouts/add_sub.png)
*Figure 4 - Fabricated add/subtract board*

**Evidence:** Arithmetic unit core module.

### Flags Board

**Directory:** `flags/`

**Schematic:** [flags.kicad_sch](flags/flags.kicad_sch)

![Flags Schematic](../../../web/assets/schematics/boards/flags.svg)
*Figure 5 - Flags generation circuit*

**Function:** Generate comparison and status flags

**Flag Implementations:**
- **EQUAL (~100T):** 8-bit XOR + NOR comparator
- **LESS (~120T):** Cascaded magnitude comparator
- **POSITIVE (~20T):** (OUT > 0) detector
- **COUT (0T):** Direct routing from adder

**Interfaces:**
```
IN:  A[7:0], B[7:0], OUT[7:0], COUT_IN, VCC, GND
OUT: LESS, EQUAL, POSITIVE, COUT
```

![Flags PCB](../../../web/assets/pcb/layouts/flags.png)
*Figure 6 - Fabricated flags board*

**Evidence:** Dedicated flag generation hardware.

### Control Board

**Directory:** `main_control/`

**Schematic:** [main_control.kicad_sch](main_control/main_control.kicad_sch)

![Control Schematic](../../../web/assets/schematics/boards/main_control.svg)
*Figure 7 - Control unit opcode decoder*

**Function:** Decode 5-bit opcode to control signals

**Decoding:**
```
FUNC[4:0] → Combinational logic → {M, MUX_SEL, INV_OUT, LOGIC_SEL[2:0]}
```

**Transistors:** ~68T (decode logic gates)

**Interfaces:**
```
IN:  FUNC[4:0], VCC, GND
OUT: M, MUX_SEL, INV_OUT, LOGIC_SEL[2:0]
```

![Control PCB](../../../web/assets/pcb/layouts/main_control.png)
*Figure 8 - Fabricated control decoder board*

**Evidence:** Control unit generates all internal control signals from opcode.

### LED Display Panels

**Directory:** `led_panel/`

**Purpose:** Visual output display for 8-bit results

**Panels:**
- led_panel_1 - Bits [7:4]
- led_panel_2 - Bits [3:0]
- led_panel_3 - Flags
- led_panel_4 - Opcode display

![LED Panel 1](../../../web/assets/pcb/layouts/led_panel_1.png)
*Figure 9 - LED display panel for upper nibble*

![LED Panel 2](../../../web/assets/pcb/layouts/led_panel_2.png)
*Figure 10 - LED display panel for lower nibble*

**Evidence:** LED panels provide binary output visualization.

---

## Design Guidelines

### Schematic Best Practices

1. **Hierarchical design:**
   - Use subcircuits for repeated structures
   - Keep hierarchy shallow (3 levels max)
   - Clear signal flow left-to-right

2. **Net labeling:**
   - Label all buses: `A[7:0]`, not `A7 A6 A5...`
   - Use global labels for multi-sheet signals
   - Descriptive names: `ARITH_OUT[7:0]` not `O[7:0]`

3. **Power:**
   - Explicit power symbols
   - Decoupling caps near ICs (100nF)
   - Bulk caps on board (10µF)

### PCB Best Practices

1. **Component placement:**
   - Group by function
   - Signal flow matches schematic
   - Minimize trace lengths for critical paths

2. **Routing:**
   - Power rails: 1mm+ traces
   - Signals: 0.3-0.5mm traces
   - Ground plane on bottom layer
   - Avoid acute angles (>45°)

3. **Manufacturing:**
   - Follow DRC rules (0.2mm min spacing)
   - Add fiducials for assembly
   - Include test points
   - Add mounting holes

---

## Manufacturing Specs

### PCB Specifications

| Parameter | Value | Manufacturer Capability |
|-----------|-------|------------------------|
| Min trace width | 0.2mm | Standard |
| Min trace spacing | 0.2mm | Standard |
| Min drill size | 0.3mm | Standard |
| Copper weight | 1oz (35µm) | Standard |
| Board thickness | 1.6mm | Standard |
| Surface finish | HASL lead-free | Standard |
| **Board size** | **270×270mm** | **Large format** |

**Note:** 270×270mm exceeds standard 100×100mm size. Confirm manufacturer supports large format before ordering.

---

## Bill of Materials

### Component Summary

| Category | Quantity | Example Part |
|----------|----------|--------------|
| **NMOS Transistors** | ~312 | 2N7000 |
| **PMOS Transistors** | ~312 | BS250 |
| **74HC157 (MUX)** | 36 | 74HC157N |
| **74HC86 (XOR)** | 10 | 74HC86 |
| **Resistors** | ~500 | 10kΩ, 220Ω |
| **Capacitors** | ~50 | 100nF, 10µF |
| **LEDs** | ~32 | Red 5mm |
| **Headers** | ~20 | 2.54mm pitch |
| **PCB (270×270mm)** | 1 | Large format |
| **Total** | | |

See [docs/build-notes/bom.md](../../docs/build-notes/bom.md) for complete BOM.

---

## Testing

### Per-Board Testing

**Test each board before integration:**

1. **Power test:**
   ```
   VCC input → Measure at far end
   Acceptable: < 5% voltage drop
   ```

2. **Continuity:**
   ```
   Check all critical signal paths
   Verify no shorts (VCC to GND)
   ```

3. **Functional:**
   ```
   Apply known inputs
   Measure outputs
   Compare with expected (simulation/calculation)
   ```

### Integration Testing

1. Connect boards via headers
2. Apply power (5V)
3. Test simple operation (e.g., ADD 1 + 1)
4. Verify output and flags
5. Test all 19 operations systematically

---

## Summary

### Design Status

- All schematics complete and verified
- All PCB layouts routed and DRC-clean
- Gerber files generated
- BOMs complete
- Boards fabricated
- Assembly in progress (modular boards complete)

### Key Features

- **270×270mm main ALU** or modular boards
- **3,488 transistors** (Hybrid: Discrete + 74xx ICs)
- **5V CMOS logic**
- **Pure combinational architecture**
- **Fabrication-ready Gerbers**

---

**For detailed board documentation, see individual board directories.**

---

**Last Updated:** 2026-01-16  
**Version:** 1.0
