#!/usr/bin/env bash
# Enter the Tomato FOSS FPGA toolchain, then run a command in it.
#
#   ../scripts/env.sh make            # from core/ or hdmi_test/
#   ../scripts/env.sh make program
#   ../scripts/env.sh                 # interactive shell
#
# OSS CAD Suite supplies yosys + openFPGALoader; nixpkgs supplies
# nextpnr-xilinx + bbasm; hardware/fpga/.tools holds the prjxray bitgen built
# by setup-prjxray-tools.sh. One install is shared by every project here.
#
# Nix on a fresh macOS install ships with the `nix-command` + `flakes`
# experimental features off, so every `nix shell` invocation below carries
# `--extra-experimental-features`. No NIX_CONFIG export or nix.conf edit needed.
set -euo pipefail

FPGA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NIX_FLAGS=(--extra-experimental-features 'nix-command flakes')

run_in_env() {
  local fpga_dir="$1"
  local workdir="$2"
  shift 2
  local oss_env="${fpga_dir}/.tools/oss-cad-suite/environment"
  if [[ -f "${oss_env}" ]]; then
    # shellcheck disable=SC1090
    source "${oss_env}"
  fi
  export PATH="${fpga_dir}/.tools/prjxray/build/tools:${fpga_dir}/.tools:${PATH}"
  # Marks the re-exec below (and the common.mk auto-wrap) as done, so a
  # bare `make program` inside core/ or hdmi_test/ stops re-entering here.
  export TOMATO_FPGA_ENV=1
  # Stay where the caller was: each project builds in its own directory.
  cd "${workdir}"
  if (($#)); then
    exec "$@"
  fi
  exec "${SHELL:-/bin/bash}"
}

if command -v nextpnr-xilinx >/dev/null; then
  run_in_env "${FPGA_DIR}" "${PWD}" "$@"
fi

if ! command -v nix >/dev/null; then
  echo "missing nix — install from https://nixos.org/download" >&2
  exit 1
fi

exec nix "${NIX_FLAGS[@]}" shell nixpkgs#nextpnr-xilinx --command bash -c \
  "$(declare -f run_in_env); run_in_env $(printf '%q ' "${FPGA_DIR}" "${PWD}" "$@")"
