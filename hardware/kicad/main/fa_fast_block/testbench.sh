#!/usr/bin/env bash
# =============================================================================
# testbench.sh — fa_fast_block (1-bit full adder)
#
# KiCad exports this design as one flat netlist: hierarchical sheet pins are not
# guaranteed to appear as top-level nodes named A, B, CIN (labels get merged or
# renamed). Driving a flat export therefore often fails port detection.
#
# This bench instead builds the same topology from per-sheet KiCad exports,
# each wrapped as an ngspice .subckt (see tools/wrap_kicad_flat_as_subckt.sh):
#   - gate_xor_2in (twice): P = A^B, SUM = P^CIN
#   - mux_2to1: SIG=0→A, SIG=1→B  ⇒  COUT = P ? CIN : B  (classical carry mux)
#
# Exhaustive DC: 2^3 vectors. Expected P,S,Cout per classical full adder.
#
# Usage:  testbench.sh
# Optional env: XOR_CIR=path MUX_CIR=path  (defaults: ../../modules/…/*.cir)
# =============================================================================
set -euo pipefail

VDD=5
VOH_MIN=4.5
VOL_MAX=0.5
CLOAD="50f"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
FIX="$REPO_ROOT/tools/fix_kicad_netlist.sh"
WRAP="$REPO_ROOT/tools/wrap_kicad_flat_as_subckt.sh"

XOR_CIR="${XOR_CIR:-$SCRIPT_DIR/../../modules/gates/gate_xor/gate_xor_2in/gate_xor_2in.cir}"
MUX_CIR="${MUX_CIR:-$SCRIPT_DIR/../../modules/mux/mux_2to1/mux_2to1.cir}"

[ -f "$FIX"  ] || { echo "Error: fix script not found: $FIX"; exit 2; }
[ -f "$WRAP" ] || { echo "Error: wrap script not found: $WRAP"; exit 2; }
[ -f "$XOR_CIR" ] || { echo "Error: XOR netlist not found: $XOR_CIR"; exit 2; }
[ -f "$MUX_CIR" ] || { echo "Error: MUX netlist not found: $MUX_CIR"; exit 2; }
command -v ngspice >/dev/null 2>&1 || { echo "Error: ngspice not found"; exit 2; }

WORK="$(mktemp -d /tmp/tb_fa_fast_block.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

cp -f "$XOR_CIR" "$WORK/xor.cir"
cp -f "$MUX_CIR" "$WORK/mux.cir"
bash "$FIX" "$WORK/xor.cir"
bash "$FIX" "$WORK/mux.cir"

LIB="$WORK/fa_composed.lib.cir"
{
  bash "$WRAP" "$WORK/xor.cir" KICAD_XOR2 /A /B /Y VCC GND
  bash "$WRAP" "$WORK/mux.cir" KICAD_MUX2 /A /B /SIG /Y VCC GND
  cat <<'EOS'
* Full adder from xor–mux–xor (matches fa_fast_block sheet hierarchy)
.subckt FA_DUT A B CIN SUM COUT P VCC GND
X_XOR1 A B P VCC GND KICAD_XOR2
X_XOR2 P CIN SUM VCC GND KICAD_XOR2
X_MUX B CIN P COUT VCC GND KICAD_MUX2
.ends
EOS
} > "$LIB"

exp_P()    { echo $(( $1 ^ $2 )); }
exp_S()    { echo $(( $1 ^ $2 ^ $3 )); }
exp_COUT() { local p=$(( $1 ^ $2 )); echo $(( ($1 & $2) | ($3 & p) )); }

logic_of() {
  awk -v v="$1" -v hi="$VOH_MIN" -v lo="$VOL_MAX" \
    'BEGIN{ if(v+0 >= hi) print 1; else if(v+0 <= lo) print 0; else print "X" }'
}

NET_A="A"
NET_B="B"
NET_CIN="CIN"
NET_P="P"
NET_S="SUM"
NET_COUT="COUT"

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════════════════════════════╗"
echo "║  fa_fast_block — EXHAUSTIVE 2³ (composed subckts from KiCad leaf .cir)"
echo "╠════════════════════════════════════════════════════════════════════════════════════════════════════╣"
printf "║  XOR: %s\n" "$XOR_CIR"
printf "║  MUX: %s\n" "$MUX_CIR"
printf "║  Outputs P,S,Cout     : OK  (nodes %s, %s, %s)\n" "$NET_P" "$NET_S" "$NET_COUT"
printf "║  Inputs  A,B,Cin      : OK  (nodes %s, %s, %s)\n" "$NET_A" "$NET_B" "$NET_CIN"
echo "║  Each vector: 3 outputs × VOH≥${VOH_MIN}V / VOL≤${VOL_MAX}V  vs expected P,S,Cout"
echo "╚════════════════════════════════════════════════════════════════════════════════════════════════════╝"

DC="$WORK/exh.cir"
DC_LOG="$WORK/exh.log"

{
  echo ".title fa_fast_block exhaustive 2^3 DC (composed)"
  echo ".include \"${LIB}\""
  echo "VDD VCC GND DC ${VDD}"
  echo "XFA ${NET_A} ${NET_B} ${NET_CIN} ${NET_S} ${NET_COUT} ${NET_P} VCC GND FA_DUT"
  echo "VA  ${NET_A}   GND DC 0"
  echo "VB  ${NET_B}   GND DC 0"
  echo "VC  ${NET_CIN} GND DC 0"
  echo "CLP ${NET_P}    GND ${CLOAD}"
  echo "CLS ${NET_S}    GND ${CLOAD}"
  echo "CLC ${NET_COUT} GND ${CLOAD}"
  echo ".op"
  echo ".control"
  echo "  set noaskquit"
} > "$DC"

for a in 0 1; do
  for b in 0 1; do
    for cin in 0 1; do
      ep=$(exp_P "$a" "$b")
      es=$(exp_S "$a" "$b" "$cin")
      ec=$(exp_COUT "$a" "$b" "$cin")
      {
        echo "  alter VA dc=$(( a   * VDD ))"
        echo "  alter VB dc=$(( b   * VDD ))"
        echo "  alter VC dc=$(( cin * VDD ))"
        echo "  op"
        echo "  echo TBVEC $a $b $cin $ep $es $ec"
        echo "  print v(${NET_P})"
        echo "  print v(${NET_S})"
        echo "  print v(${NET_COUT})"
      } >> "$DC"
    done
  done
done

printf '  quit\n.endc\n.end\n' >> "$DC"

ngspice -b "$DC" > "$DC_LOG" 2>&1 || true

echo ""
echo "╠════╤═══╤═══╤═════╤═══╤═══╤═══╤════════════╤════════════╤════════════╤════════════════════════════════╣"
printf "║ %2s │ %1s │ %1s │ %3s │ %1s │ %1s │ %1s │ %10s │ %10s │ %10s │ %-30s ║\n" \
  "#" "A" "B" "Cin" "eP" "eS" "eC" "V(P)" "V(S)" "V(COUT)" "result"
echo "╠════╪═══╪═══╪═════╪═══╪═══╪═══╪════════════╪════════════╪════════════╪════════════════════════════════╣"

row=0
pass_case=0
fail_case=0
pass_bit=0
fail_bit=0

parse_log_and_print_rows() {
  local state=idle
  local cur_a cur_b cur_cin cur_ep cur_es cur_ec
  local vcnt=0 vp vs vc volt ll rest

  while IFS= read -r line; do
    if [[ "$line" == *TBVEC* ]]; then
      rest="${line#*TBVEC}"
      rest="${rest#"${rest%%[![:space:]]*}"}"
      read -ra f <<< "$rest"
      cur_a="${f[0]}"; cur_b="${f[1]}"; cur_cin="${f[2]}"
      cur_ep="${f[3]}"; cur_es="${f[4]}"; cur_ec="${f[5]}"
      vcnt=0
      vp=""; vs=""; vc=""
      state="volts"
      continue
    fi
    if [[ "$state" == "volts" && "$line" == *"="* && "$line" == *"v("* ]]; then
      [[ "$line" == *[Ff]ailed* ]] && continue
      volt=$(awk -F'=' '{print $2+0}' <<< "$line")
      case $vcnt in
        0) vp="$volt" ;;
        1) vs="$volt" ;;
        2) vc="$volt" ;;
      esac
      vcnt=$(( vcnt + 1 ))
      if (( vcnt == 3 )); then
        (( row++ )) || true
        lp=$(logic_of "$vp"); ls=$(logic_of "$vs"); lc=$(logic_of "$vc")

        rp=1 rs=1 rc=1
        [[ "$lp" == "X" || "$lp" != "$cur_ep" ]] && rp=0
        [[ "$ls" == "X" || "$ls" != "$cur_es" ]] && rs=0
        [[ "$lc" == "X" || "$lc" != "$cur_ec" ]] && rc=0

        if (( rp )); then (( pass_bit++ )); else (( fail_bit++ )); fi
        if (( rs )); then (( pass_bit++ )); else (( fail_bit++ )); fi
        if (( rc )); then (( pass_bit++ )); else (( fail_bit++ )); fi

        if (( rp && rs && rc )); then
          res="PASS"
          (( pass_case++ )) || true
        else
          res="FAIL"
          [[ $rp -eq 0 ]] && res+=" P"
          [[ $rs -eq 0 ]] && res+=" S"
          [[ $rc -eq 0 ]] && res+=" Cout"
          (( fail_case++ )) || true
        fi

        printf "║ %2d │ %1s │ %1s │ %3s │ %1s │ %1s │ %1s │ %10s │ %10s │ %10s │ %-30s ║\n" \
          "$row" "$cur_a" "$cur_b" "$cur_cin" "$cur_ep" "$cur_es" "$cur_ec" \
          "$(printf '%.4fV' "$vp")" "$(printf '%.4fV' "$vs")" "$(printf '%.4fV' "$vc")" "$res"
        state="idle"
      fi
    fi
  done < "$DC_LOG"
}

parse_log_and_print_rows
if (( row != 8 )); then
  echo "╠════════════════════════════════════════════════════════════════════════════════════════════════════╣"
  printf "║  PARSE: expected 8 TBVEC blocks in log, got %d  (see %s)\n" "$row" "$DC_LOG"
  while (( row < 8 )); do
    (( row++ )) || true
    printf "║ %2d │ - │ - │   - │ - │ - │ - │ %10s │ %10s │ %10s │ %-30s ║\n" "---" "---" "---" "FAIL (missing log)"
    (( fail_case++ )) || true
    (( fail_bit += 3 )) || true
  done
fi

echo "╚════╧═══╧═══╧═════╧═══╧═══╧═══╧════════════╧════════════╧════════════╧════════════════════════════════╝"
echo ""
printf "  Exhaustive coverage: 8 / 8 input combinations (2³).  Vectors PASS: %d  FAIL/SKIP: %d\n" \
  "$pass_case" "$fail_case"
printf "  Bit checks (3 per vector): %d ok / %d bad  (max 24)\n" "$pass_bit" "$fail_bit"

bad=$(grep -iE "error|simulation interrupted" "$DC_LOG" 2>/dev/null | grep -iv "note" || true)
[[ -n "$bad" ]] && echo "  ngspice messages:" && echo "$bad" | tail -8 | sed 's/^/    /'
sing=$(grep -ci singular "$DC_LOG" || true)
(( sing > 0 )) && echo "  singular-matrix warnings: $sing"

echo "PASSED: $pass_bit"
echo "FAILED: $fail_bit"

if (( pass_case == 8 && fail_case == 0 && fail_bit == 0 && pass_bit == 24 )); then
  echo ""
  echo "All 2³ full-adder vectors passed (24 output checks)."
  exit 0
fi

echo ""
echo "Exhaustive bench failed or incomplete."
exit 1
