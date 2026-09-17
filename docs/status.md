# Tomato canonical facts and status

Last verified from repository sources: 2026-09-16.

This file is the short, current factual backbone for Tomato documentation. It
describes what the repository proves; it does not turn plans, historical
journal entries, or an available build target into a deployment claim.

## Canonical vocabulary

- **Tomato** is the 32-bit architecture and project as a whole.
- **Discrete ALU slice** means the physically assembled 74xx Dual-LUT ALU
  hardware shown in the repository. Do not describe it as a complete discrete
  computer.
- **FPGA Tomato** means the complete Tomato machine implemented on the Nexys
  A7-100T; it boots the assembly-written Tomato OS. A reply produced there may
  be labeled **Physical Tomato** only when an active bridge reports a completed
  hardware job.
- **Virtual Tomato** means the browser ISA-level emulator. It consumes the
  generated OS image and burned control tables but is not cycle-accurate RTL,
  an FPGA, or the discrete ALU hardware.
- **RTL simulation** means the local Icarus-driven machine used by
  `tools/virtual_tomato.py` and the FPGA testbenches. Label its results as
  simulation, never physical execution.
- **Envelop** is a separate messaging project. Its Tomato-side client and
  bounded compute executor are assembly linked into Tomato OS; its web/native
  clients, backend, and nearby bridge live in the Envelop repository.

## Current canonical facts

| Topic | Adopted fact | Repository authority |
|---|---|---|
| Word size | Tomato is a 32-bit architecture. | `hardware/digital/`, `hardware/fpga/core/rtl/`, `docs/isa/tomato.v1.csv` |
| Physical scope | A discrete ALU slice has been built; the complete running computer is the FPGA implementation. | `hardware/kicad/`, `web/assets/pcb/`, `hardware/fpga/core/` |
| Dual-LUT ALU | The custom ALU takes three 32-bit sources; two independently programmed LUT3 functions feed an adder as `f(a,b,c) + g(a,b,c) + carry`. | `hardware/fpga/core/rtl/alu.v`, `hardware/digital/`, `hardware/kicad/boards/07_alu/` |
| ISA count | **61 instructions plus NOP, 62 burned rows** in a 512-row control ROM. Pseudos do not add burned rows. | `docs/isa/tomato.v1.csv`; consistency check: `tools/gen_microcode_v1.py --check` |
| Register array | The current FPGA RTL physically declares **256 × 32-bit entries**, addressed as `{bank[2:0], register[4:0]}`, with `r0` hardwired to zero. The current burned ISA does not establish access to a 32,768-entry superbank. | `hardware/fpga/core/rtl/regs.v`, `hardware/fpga/core/rtl/ir.v`, `docs/isa/tomato.v1.csv` |
| Tomato OS | The assembled source identifies **TOMATO OS v3.0** and contains **14 menu entries**. `Desktop v1.2` is the workspace UI revision, not the OS version. | `software/os/tomato_os.s` (`s_title`, `s_sp_tag`, `menu_items`, `n_menu`) |
| Envelop in Tomato OS | Envelop is one of those 14 entries. Its firmware and bounded remote executor are linked into the OS image. The shipped setup records are simulator-only placeholders; Nordic-generated ACI bytes are not redistributed, so physical radio use requires a locally supplied setup image. | `software/os/envelop_lite.s`, `envelop_setup.s`, `remote_exec.s`, FPGA core `Makefile` |
| Browser execution | The public browser implementation is a functional ISA-level emulator, not cycle-accurate RTL. Its checked-in image is derived from OS assembly and control data. | `web/js/tomato-cpu.js`, `tools/build_web_image.py`, `web/data/tomato-os.*` |
| Hardware compiler scope | The counter FSM enumerates all **65,536** `{lutB,lutA}` pairs for fixed A, B, C, carry, and expected-output values, stopping at the first match. A hit verifies only that fixed example; it does not prove a full truth table or general function. | `hardware/fpga/core/rtl/compiler_fsm.v` |
| Recorded ALU run | The verification record reports a completed **130-billion-vector** 32-bit ALU run against a reference model. The harness and reproduction command are checked in; the full run log/artifact is not. | `verification/gauntlet/README.md`, `verification/gauntlet/` |
| FPGA clocks | The Nexys A7's **100 MHz board oscillator** is the input clock. The default RTL divides it by 16 for a **6.25 MHz CPU clock** and by 4 for a **25 MHz pixel clock**. With 800×525 scan totals, that pixel clock produces **~59.52 Hz** refresh (640×480 nominal-60-Hz timing). These are different clock domains/metrics, not alternate CPU speeds. | `hardware/fpga/core/constr/nexys.xdc`, `hardware/fpga/core/rtl/board/nexys_top.v`, `videoout.v` |
| 90 MHz wording | **90 MHz is the configured nextpnr place-and-route timing target** (`--freq`), not an oscillator value, CPU runtime frequency, measured Fmax, or instruction rate. | `hardware/fpga/core/Makefile` (`FREQ_MHZ := 90`), `hardware/fpga/common.mk` |
| FPGA throughput | At 6.25 MHz, instruction throughput depends on CPI. The checked-in Icarus samples range from 2.000 to 2.556 CPI; converting their unweighted ~2.13-CPI summary gives a **workload-derived projection of ~2.9 million instructions/s**, not measured board throughput or a universal operations/s rating. | `hardware/fpga/core/reports/CPI.md`, `hardware/fpga/core/reports/METRICS.md` |
| Browser speed | Virtual Tomato is host-budgeted functional execution. Its `CPU_HZ = 6,250,000` value drives the guest timer model, while the UI loop runs as many ISA steps as an 8 ms/60,000-step frame budget permits. It must not be described as a 6.25 MHz or cycle-accurate emulator. | `web/js/tomato-cpu.js`, `web/js/virtual.js` |
| FPGA build flow | The default documented build is Yosys → nextpnr-xilinx → Project X-Ray; an optional Linux Vivado batch target exists for the same board. Neither target alone proves a currently programmed board. | `hardware/fpga/core/Makefile`, `hardware/fpga/common.mk` |

## Envelop execution boundary

Use this path when explaining the integrated system:

`person → Envelop web app → Envelop backend queue → nearby verified bridge → Envelop in Tomato OS → Tomato CPU → labeled reply`

- Human-to-Tomato text remains queued until Tomato accepts it and the active
  bridge records the acknowledgement. That acknowledgement is not a human read
  receipt.
- Hardware compute is a durable backend job. A timeout is an unknown outcome;
  it must not trigger an automatic virtual replay.
- Virtual Tomato preview is explicit and labeled. It runs separately in the
  browser, is not sent to the FPGA, and is never queued for later hardware
  execution.
- “Online” for hardware means the backend observes an unexpired authenticated
  bridge lease after the bridge verifies Tomato's exact `ENVELOP/1` identity.
  It does not mean that source code merely contains bridge support.

## Status boundaries

- **Source-complete:** FPGA Tomato, Tomato OS, its 14-entry menu, Envelop
  firmware, the browser emulator, and local RTL simulation are present in this
  repository.
- **Testable without hardware:** ISA consistency, assembly/layout, FPGA
  simulation, OS boot, browser-emulator regression, and the local remote
  executor have repository tests.
- **Hardware-dependent:** a currently programmed FPGA, attached radio, active
  nearby bridge, and completed physical reply require live evidence. Do not
  infer them from source, a screenshot, or a build recipe.
- **Envelop availability:** the Tomato-side client and executor are checked in
  here; web/native clients, backend, and bridge software are in the separate
  Envelop project. Neither repository proves that a nearby authenticated bridge
  is currently active.
- **Deployment-dependent:** public site content and Envelop's hosted backend
  may differ from a working tree. Verify the deployed artifact before using
  “live now,” “online,” or equivalent wording.

## Known documentation drift

The 32,768-register/`SETBANK2` proposal is a historical discrete-memory design,
not current FPGA behavior. It depended on mirrored external SRAM and an
additional seven-bit superbank latch. Current FPGA RTL instead declares a
**256 × 32-bit physical array** addressed by three bank bits and a five-bit
register field; neither the superbank latch nor `SETBANK2` is present in the
RTL or burned ISA.

This is an implementation and ISA distinction, not a demonstrated Artix-7
capacity ceiling. The present asynchronous 3-read/1-write array maps to
distributed RAM; the repository does not contain a failed 32,768-entry FPGA
implementation or evidence that raw block-RAM capacity was exhausted.
