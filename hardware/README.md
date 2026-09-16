# Tomato hardware

Tomato's architecture appears in editable schematics, physical PCB work, and a
complete FPGA implementation. These layers share a design, but they prove
different things.

<p align="center">
  <img src="../web/assets/pcb/immersion_black.webp" alt="Tomato Dual-LUT ALU PCB" width="48%">
  <img src="../web/assets/assembly/fpga-board-pmod.webp" alt="Nexys A7 used by the complete FPGA Tomato machine" width="48%">
</p>
<p align="center"><em>Discrete ALU work at left; complete FPGA machine at right.</em></p>

## Current scope

- The physically assembled discrete hardware is a **Dual-LUT ALU slice**, not
  a complete discrete computer.
- The complete machine capable of booting Tomato OS is **FPGA Tomato** on the
  Nexys A7-100T.
- Digital schematics remain the editable architectural source for the discrete
  design.
- Exported Verilog is a derivative and must not be hand-edited as design source.

## Directory map

| Path | Role | Authority/evidence |
|---|---|---|
| [`digital/`](digital/) | Digital schematics and simulation | Editable architecture source |
| [`kicad/`](kicad/) | Numbered board designs and assembly documentation | Physical design and pictured build evidence |
| [`fpga/`](fpga/) | Complete Nexys A7 machine, board harness, and tests | Current FPGA implementation |
| [`verilog/`](verilog/) | Digital export policy and netlists | Generated/read-only derivatives |

The current FPGA implementation has a **256 × 32-bit** register file and uses
**61 instructions plus NOP, 62 burned rows**. Older hardware notes may describe
different register or ISA designs; use
[`../docs/status.md`](../docs/status.md) for current facts.

## Workflow boundaries

For discrete logic, edit Digital sources, export Verilog, then copy the export
to the relevant verification/implementation tree and run the appropriate
checks. For PCB work, KiCad sources and assembly records establish design and
physical scope.

For FPGA work, the default build uses Yosys, nextpnr-xilinx, and Project X-Ray.
An optional Linux Vivado batch target also exists. A successful build is not
proof that a board is currently programmed.

## Continue

- [Architecture guide](../docs/architecture.md)
- [Digital guide](digital/README.md)
- [KiCad guide](kicad/README.md)
- [FPGA guide](fpga/README.md)
- [FPGA core guide](fpga/core/README.md)
- [Documentation authority](../docs/documentation-policy.md)
