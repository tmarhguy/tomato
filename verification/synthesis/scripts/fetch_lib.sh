#!/usr/bin/env bash
# Download Sky130 HD liberty (TT 1.8V) into pdk/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/pdk/sky130_fd_sc_hd__tt_025C_1v80.lib"
URL="https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/sky130_fd_sc_hd/latest/cells/sky130_fd_sc_hd__tt_025C_1v80.lib"

mkdir -p "$(dirname "$OUT")"
echo "Fetching $URL ..."
curl -fsSL "$URL" -o "$OUT"
echo "Written $OUT"
