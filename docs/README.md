# Tomato documentation

This directory separates current reference material from Tomato's dated
engineering record. If two documents disagree, start with
[`status.md`](status.md) and apply
[`documentation-policy.md`](documentation-policy.md).

## Start here

| Document | Use it for |
|---|---|
| [`status.md`](status.md) | Current facts, exact terminology, and deployment boundaries |
| [`architecture.md`](architecture.md) | The 32-bit machine, ALU, control, registers, memory, and implementations |
| [`compute.md`](compute.md) | Browser, RTL, FPGA, Envelop, and remote-compute provenance |
| [`isa/README.md`](isa/README.md) | Burned ISA contract and assembler vocabulary |
| [`../software/os/README.md`](../software/os/README.md) | Tomato OS v3.0, its 14 entries, source layout, and checks |
| [`assets.md`](assets.md) | Image selection, captions, provenance, and reuse |
| [`documentation-policy.md`](documentation-policy.md) | Which source wins and how status words are used |

The [root README](../README.md) is the visual front door. Subsystem guides live
with their source:

- [hardware](../hardware/README.md)
- [FPGA](../hardware/fpga/README.md)
- [FPGA core](../hardware/fpga/core/README.md)
- [software](../software/README.md)
- [verification](../verification/README.md)
- [web and browser emulator](../web/README.md)

## Canonical versus historical

Current guides describe the repository as it exists now. The
[`log/`](log/) directory is a historical build journal: entries retain the
claims, terminology, and plans that were accurate to the author at the time.
Some therefore describe abandoned word widths, register designs, old ISA
counts, or preview-only integrations.

Use the [current journal index](log/README.md), which labels the collection and
links newer entries missing from the original welcome dispatch. Do not use a
dated entry to establish present status unless a current guide confirms it.

## Machine-readable contracts

| Path | Authority |
|---|---|
| [`isa/tomato.v1.csv`](isa/tomato.v1.csv) | Burned control-ROM rows |
| [`isa/tomato.v1.pseudo.csv`](isa/tomato.v1.pseudo.csv) | Assembler-only expansions |
| [`isa/datapath-audit.csv`](isa/datapath-audit.csv) | Derived implementation checklist |
| [`isa/lut.csv`](isa/lut.csv) | ALU LUT primitive catalog |
| [`isa/profiles.csv`](isa/profiles.csv) | Architecture-mapping exploration data |

Generated burns, memory images, screenshots, and packaged artifacts are
derivatives or evidence, not editable authorities.

## Focused checks

```bash
python3 tools/gen_microcode_v1.py --check
python3 software/assembler.py --selftest
make -C hardware/fpga/core burn-check
```

The first two check the ISA and assembler contracts. The third checks the FPGA
burn against the ISA source. Full simulation and hardware programming are
separate activities.

## Other references

- [`alu/`](alu/) contains the typeset ALU reference sources.
- [`nl-grammar.md`](nl-grammar.md) defines the deterministic controlled
  language used by local compute tooling.
- [`remote-compute-preview.md`](remote-compute-preview.md) records a
  simulation-only integration checkpoint; it is not current deployment proof.
- [tomato.tmarhguy.com](https://tomato.tmarhguy.com/) is the public narrative
  surface and may differ from the working tree until deployed.
