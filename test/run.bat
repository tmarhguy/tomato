@echo off
setlocal
cd /d "%~dp0"

if not exist "..\verification\synthesis\pdk\sky130_fd_sc_hd__tt_025C_1v80.lib" (
    echo Liberty missing. Run verification\synthesis\scripts\fetch_lib.ps1 first.
    exit /b 1
)

call C:\tools\oss-cad-suite\environment.bat
if not exist reports mkdir reports

echo === Yosys synthesis: kogge_stone_32 (benchmark) ===
yosys.exe scripts/synth.ys > reports\synth.log 2>&1
if errorlevel 1 (
    echo Synthesis failed. See reports\synth.log
    exit /b 1
)

echo === Extract metrics ===
python scripts\extract_metrics.py
if errorlevel 1 exit /b 1

echo === Yosys synthesis: alu_32b_kogge_stone (dual-LUT + KS carry) ===
yosys.exe scripts/synth_alu_ks.ys > reports\alu_ks_synth.log 2>&1
if errorlevel 1 (
    echo ALU+KS synthesis failed. See reports\alu_ks_synth.log
    exit /b 1
)

echo === Extract ALU+KS metrics ===
python scripts\extract_metrics_alu_ks.py
if errorlevel 1 exit /b 1

echo === Compare all three designs ===
python scripts\compare.py

echo Done. See reports\metrics.txt, reports\alu_ks_metrics.txt, reports\comparison.txt
