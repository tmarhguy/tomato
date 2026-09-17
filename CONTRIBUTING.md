# Contributing to Tomato

Tomato is an active, experimental hardware and software project. Small,
evidence-backed changes are easiest to review.

## Before opening a change

- Start from the current canonical facts in [`docs/status.md`](docs/status.md)
  and the authority rules in
  [`docs/documentation-policy.md`](docs/documentation-policy.md).
- Keep discrete hardware, FPGA Tomato, RTL simulation, and Virtual Tomato
  claims distinct.
- Do not rewrite dated material under `docs/log/` as if it were current prose.
- Do not include credentials, private device identifiers, downloaded
  toolchains, generated build trees, or personal capture data.
- Preserve third-party notices and update
  [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) when adding material under
  different terms.

## Focused checks

Run checks appropriate to the files changed. Documentation-only changes should
at least run:

```sh
python3 tools/check_docs.py
```

Site changes should also run:

```sh
npm --prefix web test
```

Hardware build, simulation, assembler, and verification commands are documented
in their subsystem READMEs. A passing software check does not establish a
physical-hardware result; describe exactly what was run.

## Contributions and licensing

By submitting a contribution, you represent that you have the right to submit
it under the repository's [`LICENSE`](LICENSE), including the Apache-2.0
contribution terms incorporated by SHL-2.1. Call out third-party or generated
material explicitly rather than assuming the project licence applies.
