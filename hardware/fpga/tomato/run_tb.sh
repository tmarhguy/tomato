#!/usr/bin/env bash
# Run FPGA unit TBs + assembled programs (needs iverilog). cwd = hardware/fpga/tomato.
set -euo pipefail
TOMATO="$(cd "$(dirname "$0")" && pwd)"
cd "$TOMATO"
export PATH="${HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}"

if ! command -v iverilog >/dev/null 2>&1; then
  echo "iverilog not in PATH — try: nix shell nixpkgs#iverilog"
  exit 1
fi

ROOT="$(cd ../../.. && pwd)"
ASM="python3 ${ROOT}/tools/tomato_asm.py"
GEN="python3 ${ROOT}/tools/gen_microcode_v1.py"

$GEN >/dev/null
echo "=== burn-check ==="
$GEN --check

echo "=== asm ==="
$ASM "${ROOT}/software/asm/counter.s" -o tb/mem/counter.mem
$ASM "${ROOT}/software/asm/fib.s"     -o tb/mem/fib.mem
$ASM "${ROOT}/software/asm/collatz.s" -o tb/mem/collatz.mem
$ASM "${ROOT}/software/asm/call.s"    -o tb/mem/call.mem
$ASM "${ROOT}/software/asm/bytes.s"   -o tb/mem/bytes.mem

fail=0
run_one() {
  local tb="$1"; shift
  echo "=== $tb ==="
  if ! iverilog -g2005 -o "/tmp/tomato_$tb" "tb/${tb}_tb.v" "$@" 2>/tmp/tomato_$tb.err; then
    echo "COMPILE FAIL"; cat /tmp/tomato_$tb.err; fail=1; return
  fi
  if ! vvp "/tmp/tomato_$tb" 2>&1 | tee "/tmp/tomato_$tb.out" | tail -3; then
    fail=1
  fi
  grep -q FAIL "/tmp/tomato_$tb.out" && fail=1 || true
}

run_prog() {
  local name="$1"; shift
  echo "=== prog $name ==="
  if ! vvp /tmp/tomato_prog "$@" 2>&1 | tee "/tmp/tomato_prog_$name.out" | tail -3; then
    fail=1
  fi
  grep -q FAIL "/tmp/tomato_prog_$name.out" && fail=1 || true
}

run_one shift   rtl/shift.v
run_one wb      rtl/wb.v
run_one lane    rtl/lane.v
run_one bus     rtl/bus.v
run_one sp      rtl/sp.v
run_one regs    rtl/regs.v
run_one ir      rtl/ir.v
run_one pc      rtl/pc.v
run_one muldiv  rtl/muldiv.v rtl/shift.v
run_one vga     rtl/vga.v
run_one hex     rtl/hex.v
run_one control rtl/control.v
run_one main    rtl/*.v
run_one counter rtl/*.v

echo "=== compile prog_tb ==="
iverilog -g2005 -o /tmp/tomato_prog tb/prog_tb.v rtl/*.v
run_prog counter +PROG=counter +EXPECT_R1=10 +EXPECT_DISP=10
run_prog fib     +PROG=fib +EXPECT_R1=21 +EXPECT_R6=21 +EXPECT_DISP=21
run_prog collatz +PROG=collatz +EXPECT_R1=111 +EXPECT_DISP=111
run_prog call    +PROG=call +EXPECT_R1=99 +EXPECT_R2=42 +EXPECT_DISP=99
run_prog bytes   +PROG=bytes +EXPECT_R1=90 +EXPECT_R2=-128 +EXPECT_DISP=-128

echo "=== summary fail=$fail ==="
exit "$fail"
