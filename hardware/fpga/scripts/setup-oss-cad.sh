#!/usr/bin/env bash
# Download OSS CAD Suite (darwin-arm64) — prebuilt Yosys/nextpnr/prjxray bitgen.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${ROOT}/.tools"
OSS_TAG="${OSS_TAG:-2026-08-28}"
OSS_BUILD="${OSS_BUILD:-20260828}"
ARCH="$(uname -m)"
case "${ARCH}" in
  arm64) OSS_ASSET="oss-cad-suite-darwin-arm64-${OSS_BUILD}.tgz" ;;
  x86_64) OSS_ASSET="oss-cad-suite-darwin-x64-${OSS_BUILD}.tgz" ;;
  *) echo "unsupported arch: ${ARCH}" >&2; exit 1 ;;
esac

OSS_URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_TAG}/${OSS_ASSET}"
OSS_DIR="${TOOLS}/oss-cad-suite"

mkdir -p "${TOOLS}"

if [[ ! -f "${OSS_DIR}/environment" ]]; then
  echo "==> downloading ${OSS_ASSET}"
  tmp="$(mktemp -d)"
  curl -fL "${OSS_URL}" -o "${tmp}/${OSS_ASSET}"
  tar -xzf "${tmp}/${OSS_ASSET}" -C "${TOOLS}"
  rm -rf "${tmp}"
fi

if [[ ! -f "${OSS_DIR}/environment" ]]; then
  echo "expected ${OSS_DIR}/environment after extract" >&2
  exit 1
fi

echo "oss-cad-suite ready: ${OSS_DIR}"
