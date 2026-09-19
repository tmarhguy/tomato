#!/usr/bin/env bash
# Download the latest Tomato core bitstream into DEST (default: build/nexys_top.bit).
# Prefers: current-branch CI artifact → main CI artifact → bitstream-latest release.
set -euo pipefail

DEST="${1:-build/nexys_top.bit}"
DEST_DIR="$(cd "$(dirname "$DEST")" && pwd)"
DEST_BASE="$(basename "$DEST")"
DEST_PATH="${DEST_DIR}/${DEST_BASE}"
SHA_PATH="${DEST_PATH}.sha256"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/tomato-fetch-bit.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

die() { echo "fetch-bit: $*" >&2; exit 1; }

command -v gh >/dev/null || die "missing gh — install GitHub CLI and authenticate"

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
[[ -n "$REPO" ]] || die "not inside a GitHub repo (gh repo view failed)"

find_run() {
  local branch="$1"
  gh run list \
    --repo "$REPO" \
    --workflow=fpga-bitstream.yml \
    --branch "$branch" \
    --status success \
    --limit 20 \
    --json databaseId,conclusion,headSha \
    --jq '.[0].databaseId // empty' 2>/dev/null || true
}

download_artifact() {
  local run_id="$1"
  [[ -n "$run_id" ]] || return 1
  echo "==> fetch-bit: CI run $run_id → $DEST_PATH"
  mkdir -p "$WORK/art"
  if ! gh run download "$run_id" --repo "$REPO" -D "$WORK/art" 2>/dev/null; then
    return 1
  fi
  local bit
  bit="$(find "$WORK/art" -name 'nexys_top.bit' -type f | head -n 1)"
  [[ -n "$bit" ]] || return 1
  mkdir -p "$DEST_DIR"
  cp "$bit" "$DEST_PATH"
  local sha
  sha="$(find "$WORK/art" -name 'nexys_top.bit.sha256' -type f | head -n 1)"
  if [[ -n "$sha" ]]; then
    cp "$sha" "$SHA_PATH"
  fi
  return 0
}

download_release() {
  echo "==> fetch-bit: release bitstream-latest → $DEST_PATH"
  mkdir -p "$WORK/rel" "$DEST_DIR"
  if ! gh release download bitstream-latest --repo "$REPO" -D "$WORK/rel" -p 'nexys_top.bit*' 2>/dev/null; then
    return 1
  fi
  [[ -f "$WORK/rel/nexys_top.bit" ]] || return 1
  cp "$WORK/rel/nexys_top.bit" "$DEST_PATH"
  if [[ -f "$WORK/rel/nexys_top.bit.sha256" ]]; then
    cp "$WORK/rel/nexys_top.bit.sha256" "$SHA_PATH"
  fi
  return 0
}

verify_sha() {
  [[ -f "$SHA_PATH" ]] || return 0
  local expected actual
  expected="$(awk '{print $1}' "$SHA_PATH")"
  if command -v sha256sum >/dev/null; then
    actual="$(sha256sum "$DEST_PATH" | awk '{print $1}')"
  else
    actual="$(shasum -a 256 "$DEST_PATH" | awk '{print $1}')"
  fi
  [[ "$expected" == "$actual" ]] || die "sha256 mismatch (expected $expected, got $actual)"
  echo "fetch-bit: sha256 ok ($actual)"
}

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
[[ "$BRANCH" == "HEAD" ]] && BRANCH="main"

RUN_ID="$(find_run "$BRANCH")"
if [[ -z "$RUN_ID" && "$BRANCH" != "main" ]]; then
  echo "fetch-bit: no success on '$BRANCH', trying main"
  RUN_ID="$(find_run main)"
fi

ok=0
if [[ -n "$RUN_ID" ]] && download_artifact "$RUN_ID"; then
  ok=1
elif download_release; then
  ok=1
fi

[[ "$ok" == 1 ]] || die "no bitstream found (CI artifact or release bitstream-latest)"
verify_sha
echo "wrote $DEST_PATH ($(wc -c < "$DEST_PATH" | tr -d ' ') bytes)"
