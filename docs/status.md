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
  A7-100T and capable of booting Tomato OS. A reply produced there may be
  labeled **Hardware Tomato** or **Physical Tomato** only when an active bridge
  reports a completed hardware job.
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
| ISA count | **61 instructions plus NOP, 62 burned rows** in a 512-row control ROM. Pseudos do not add burned rows. | `docs/isa/tomato.v1.csv`; consistency check: `tools/gen_microcode_v1.py --check` |
| Registers | The current FPGA register file is **256 × 32-bit**, arranged as eight banks of 32 registers with `r0` hardwired to zero. | `hardware/fpga/core/rtl/regs.v` |
| Tomato OS | The assembled source identifies **TOMATO OS v3.0** and contains **14 menu entries**. `Desktop v1.2` is the workspace UI revision, not the OS version. | `software/os/tomato_os.s` (`s_title`, `s_sp_tag`, `menu_items`, `n_menu`) |
| Envelop in Tomato OS | Envelop is one of those 14 entries. Its firmware, setup data, and bounded remote executor are linked into the OS image. | `software/os/envelop_lite.s`, `envelop_setup.s`, `remote_exec.s`, FPGA core `Makefile` |
| Browser execution | The public browser implementation is a functional ISA-level emulator, not cycle-accurate RTL. Its checked-in image is derived from OS assembly and control data. | `web/js/tomato-cpu.js`, `tools/build_web_image.py`, `web/data/tomato-os.*` |
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
- **Deployment-dependent:** public site content and Envelop's hosted backend
  may differ from a working tree. Verify the deployed artifact before using
  “live now,” “online,” or equivalent wording.

## Known documentation drift

Older prose still contains prior OS versions, prior menu/app counts, prior ISA
counts, a 32,768-register/`SETBANK2` design not present in current FPGA RTL,
and ambiguous clock language. Later documentation phases should replace those
claims with this file's wording while preserving journal entries as dated
historical records.
