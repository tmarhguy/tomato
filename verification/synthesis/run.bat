@echo off
setlocal
cd /d "%~dp0"

if not exist "pdk\sky130_fd_sc_hd__tt_025C_1v80.lib" (
    echo Liberty file missing. Run scripts\fetch_lib.ps1
    exit /b 1
)

call C:\tools\oss-cad-suite\environment.bat

if not exist reports mkdir reports

echo === Yosys synthesis: rtl/alu-32b-final.v ===
yosys.exe scripts/synth.ys > reports\synth.log 2>&1
if errorlevel 1 (
    echo Synthesis failed. See reports\synth.log
    exit /b 1
)

echo === Extract metrics ===
python scripts\extract_metrics.py
if errorlevel 1 (
    echo Metrics extraction failed.
    exit /b 1
)

echo Done. See reports\metrics.txt
