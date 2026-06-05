#!/usr/bin/env bash
# =============================================================================
# fix_kicad_netlist.sh  --  General KiCad SPICE Netlist Fixer
#
# Modifies a KiCad-exported .cir file IN PLACE:
#
#   1. .model lines  →  replaces with canonical Level-1 MOSFET parameters
#   2. MOSFET device lines (M* with 6+ tokens):
#        - Looks up the device's model name to determine NMOS or PMOS
#        - Sets bulk pin → GND  (NMOS)  or  VCC  (PMOS)
#        - Handles NC-* bulk pins, wrong nets, or already-correct nets
#
# Works on ANY KiCad export regardless of circuit type (inverter, NAND, NOR,
# MUX, adder, full-custom, …).  No circuit-specific knowledge required.
# The transform is idempotent – safe to run multiple times.
#
# Usage:
#   ./fix_kicad_netlist.sh <netlist.cir>
#
# A timestamped backup is written next to the original before any changes.
#
# Requirements:
#   awk, grep  (POSIX – available by default on macOS and Linux)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 0. Usage / argument check
# ---------------------------------------------------------------------------
if [ $# -ne 1 ]; then
    echo "Usage: $0 <netlist.cir>"
    exit 1
fi

NETLIST="$1"

if [ ! -f "$NETLIST" ]; then
    echo "Error: file not found: $NETLIST"
    exit 1
fi

# ---------------------------------------------------------------------------
# 1. Canonical MOSFET model parameters
#    Edit these two lines to match your process corner / PDK.
# ---------------------------------------------------------------------------
NMOS_PARAMS="(LEVEL=1 VTO=1.0 KP=120e-6 GAMMA=0.4 LAMBDA=0.01)"
PMOS_PARAMS="(LEVEL=1 VTO=-1.2 KP=60e-6  GAMMA=0.4 LAMBDA=0.01)"

# ---------------------------------------------------------------------------
# 2. Backup the original before touching anything
# ---------------------------------------------------------------------------
BACKUP="${NETLIST}.bak.$(date +%Y%m%d_%H%M%S)"
cp "$NETLIST" "$BACKUP"
echo "  ✓ Backup written → $BACKUP"

# ---------------------------------------------------------------------------
# 3. Pass 1 – build a model_name→type map from all .model lines in the file.
#    Output is a simple key=value list, one per line, stored in a temp file.
#    This avoids bash-4-only associative arrays and works on macOS bash 3.
# ---------------------------------------------------------------------------
MAPFILE=$(mktemp /tmp/kicad_modelmap.XXXXXX)

awk '
    tolower($1) == ".model" {
        # $2 = model name, $3 = NMOS|PMOS (may be mixed-case from KiCad)
        printf "%s=%s\n", tolower($2), toupper($3)
    }
' "$NETLIST" > "$MAPFILE"

# ---------------------------------------------------------------------------
# 4. Pass 2 – rewrite the file using awk, loading the map from the temp file.
# ---------------------------------------------------------------------------
TMPFILE=$(mktemp /tmp/kicad_fixed.XXXXXX)

awk \
    -v nmos_p="$NMOS_PARAMS" \
    -v pmos_p="$PMOS_PARAMS" \
    -v mapfile="$MAPFILE" \
'
BEGIN {
    # Load the model-type lookup table from the map file
    while ((getline line < mapfile) > 0) {
        eq = index(line, "=")
        if (eq > 0) {
            k = substr(line, 1, eq - 1)
            v = substr(line, eq + 1)
            mtype[k] = v
        }
    }
    close(mapfile)
}

# ── .model lines ─────────────────────────────────────────────────────────────
# Replace model declaration with canonical parameters (any existing params
# from a prior partial fix are discarded and replaced with canonical values).
tolower($1) == ".model" {
    name = $2
    typ  = toupper($3)
    if (typ == "NMOS") {
        print ".model", name, "NMOS", nmos_p
    } else if (typ == "PMOS") {
        print ".model", name, "PMOS", pmos_p
    } else {
        print   # unknown/resistor/cap model – leave untouched
    }
    next
}

# ── MOSFET device lines ───────────────────────────────────────────────────────
# Detect by first character being M or m with at least 6 fields.
# KiCad raw format:  Mname  D  G  S  NC-Qxx-0  model_name
# Fixed format:      Mname  D  G  S  GND|VCC   model_name
tolower(substr($1, 1, 1)) == "m" && NF >= 6 {
    mname = $1
    drain = $2
    gate  = $3
    src   = $4
    # $5 is the bulk pin (NC-* or already GND/VCC) – we always override it
    model = $6

    # Lookup type; default to NMOS if not found (safe fallback)
    typ = mtype[tolower(model)]
    if (typ == "") typ = "NMOS"

    bulk = (typ == "PMOS") ? "VCC" : "GND"

    print mname, drain, gate, src, bulk, model
    next
}

# ── Everything else passes through verbatim ───────────────────────────────────
{ print }
' "$NETLIST" > "$TMPFILE"

# ---------------------------------------------------------------------------
# 5. Atomically replace the original and clean up temp files
# ---------------------------------------------------------------------------
mv "$TMPFILE" "$NETLIST"
rm -f "$MAPFILE"

# ---------------------------------------------------------------------------
# 6. Report summary
# ---------------------------------------------------------------------------
nmos_models=$(grep -ci "^\.model.*NMOS" "$NETLIST" 2>/dev/null || echo 0)
pmos_models=$(grep -ci "^\.model.*PMOS" "$NETLIST" 2>/dev/null || echo 0)
mos_devices=$(grep -c  "^[Mm]"          "$NETLIST" 2>/dev/null || echo 0)

echo ""
echo "  ✓ Netlist fixed in-place: $NETLIST"
echo ""
printf "    %-30s %s\n" "NMOS models patched:"  "$nmos_models"
printf "    %-30s %s\n" "PMOS models patched:"  "$pmos_models"
printf "    %-30s %s\n" "MOSFET bulk pins set:" "$mos_devices"
echo ""
echo "    NMOS bulk → GND  |  params: ${NMOS_PARAMS}"
echo "    PMOS bulk → VCC  |  params: ${PMOS_PARAMS}"
echo ""
echo "  To restore original:"
echo "    cp \"$BACKUP\" \"$NETLIST\""
echo ""
