# Tomato compute and execution provenance

Tomato can execute programs in a browser emulator, RTL simulation, or the FPGA
machine. Those targets share architecture and software artifacts, but they are
not interchangeable evidence. Every result should identify where it ran.

## Execution targets

| Target | What it is | Honest result label |
|---|---|---|
| Virtual Tomato | Functional browser ISA emulator using generated OS/control data | Virtual Tomato |
| Local RTL | Icarus-driven machine and testbenches | RTL simulation |
| FPGA Tomato | Complete machine on the Nexys A7-100T | Hardware Tomato or Physical Tomato, only with live completion evidence |
| Discrete ALU slice | Physically assembled ALU hardware, not a complete computer | Discrete ALU demonstration |

An emulator screenshot cannot establish FPGA execution. A passing simulation or
a generated bitstream cannot establish that a board is programmed. Source code
for a bridge cannot establish that hardware is online.

## Virtual Tomato

Virtual Tomato is a functional ISA-level emulator. It consumes the checked-in
OS image and burned control information generated from this repository. It is
useful for interactive exploration and browser regression, but it is not
cycle-accurate RTL and does not model the physical ALU or FPGA fabric.

Virtual execution is explicit and separate. It is never silently replayed as a
substitute for a timed-out hardware request.

## RTL simulation

The core and OS can run locally under Icarus:

```bash
make -C hardware/fpga/core os
make -C hardware/fpga/core test
```

The local remote-compute checkpoint can be exercised with:

```bash
make -C hardware/fpga/core remote-test
```

These checks execute Tomato RTL and assembly without programming an FPGA.
[`remote-compute-preview.md`](remote-compute-preview.md) documents that
simulation checkpoint and its limitations.

## Envelop boundary

Envelop is a separate messaging project. Tomato contains only the machine-side
pieces linked into Tomato OS: the Envelop client firmware, setup data, and a
bounded compute executor.

The intended hardware path is:

`person → Envelop web app → Envelop backend queue → nearby verified bridge → Envelop in Tomato OS → Tomato CPU → labeled reply`

A human message stays queued until Tomato accepts it and the active bridge
records the acknowledgement. That acknowledgement is transport state, not a
human read receipt.

Hardware compute is a durable job. A timeout means the outcome is unknown; it
must not trigger automatic virtual execution. Hardware is considered online
only while the backend observes an unexpired authenticated bridge lease after
the bridge verifies Tomato's exact identity.

## Bounded compute

The current repository contains:

- a deterministic controlled-language compiler;
- bounded Tomato bytecode and an OS-side executor;
- private job registers and memory;
- focused compiler, firmware, sandbox, and simulation tests.

The compiler does not calculate the result itself. It produces a bounded
program; Tomato execution produces the result. Unknown language and unsupported
operators fail closed rather than being guessed. The grammar contract is
[`nl-grammar.md`](nl-grammar.md).

Repository presence does not prove production deployment. Hosted queues,
active bridges, attached peripherals, and completed physical results require
separate live evidence.

## Result-label rules

- Use **Virtual Tomato** for browser-emulator results.
- Use **RTL simulation** for Icarus and testbench results.
- Use **Hardware Tomato** or **Physical Tomato** only when a verified active
  bridge reports that the FPGA completed that job.
- Do not use “online,” “live now,” or “deployed” based only on source,
  screenshots, tests, build output, or a programmed-board recipe.
- Preserve the label in screenshots, captions, metadata, and copied results.

For the broader status vocabulary, see
[`documentation-policy.md`](documentation-policy.md).
