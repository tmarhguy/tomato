# Tomato documentation authority

This policy defines which source wins when Tomato documentation disagrees.
Current status and public wording start at [`status.md`](status.md).

## Authority order

1. **Executable/editable design sources**
   - architecture: `hardware/digital/`
   - FPGA implementation: `hardware/fpga/core/rtl/`
   - operating system: `software/os/*.s`
   - browser emulator behavior: `web/js/tomato-cpu.js`
2. **Machine-readable contracts**
   - burned ISA contract: `docs/isa/tomato.v1.csv`
   - assembler pseudos: `docs/isa/tomato.v1.pseudo.csv`
   - generated web-image format: `tools/build_web_image.py`
3. **Consistency generators and tests**
   - `tools/gen_microcode_v1.py --check`
   - `software/assembler.py --selftest`
   - focused testbenches and web tests
4. **Canonical current prose**
   - `docs/status.md`
   - focused subsystem documentation that cites the sources above
5. **Narrative surfaces**
   - root README and `web/`
6. **Historical records**
   - `docs/log/`

Generated Verilog burns, assembled memory files, web data images, screenshots,
and packaged artifacts are evidence or derivatives, not editable authorities.
Regenerate them from source and identify their provenance. A dated journal
entry remains valid as history but must not override current code or
`docs/status.md`.

## Claim rules

- Pair mutable numerical claims with their source path or generate them.
- Use the exact ISA wording: **61 instructions plus NOP, 62 burned rows**.
- Use **TOMATO OS v3.0** for the OS and **Desktop v1.2** only for the workspace
  UI revision. Count the current menu as 14 entries.
- Keep routing target, oscillator, pixel clock, and CPU runtime clock distinct.
- Never use an emulator or RTL-simulation result as evidence of physical
  execution.
- Never call hardware “online” without a current lease or equivalent live
  observation.
- Describe the complete discrete machine as a goal. Describe only the
  physically assembled Dual-LUT ALU slice as built.
- Preserve hardware-versus-virtual provenance in captions, result labels, alt
  text, and metadata.

## Status words

- **Implemented:** present in current source.
- **Verified:** a named reproducible check passed against that source.
- **Hardware-demonstrated:** direct evidence identifies an FPGA or physical
  assembly and the operation shown.
- **Deployed:** the checked artifact or revision is confirmed at its public
  endpoint.
- **Preview:** intentionally incomplete or non-production behavior.
- **Planned:** no current implementation claim.

Do not substitute one status for another. In particular, “implemented” does
not imply deployed, and “verified” without a target does not imply hardware.

## Updating canonical facts

When a source change alters a fact:

1. update the machine-readable or executable authority;
2. run its focused consistency check;
3. update `docs/status.md` in the same change;
4. update current subsystem docs, README, and site copy;
5. leave historical logs intact, adding a short current/superseded note only
   when readers could otherwise mistake one for present status.
