# Download Sky130 HD liberty (TT 1.8V) into pdk/
$ErrorActionPreference = "Stop"
$Root = Split-Path (Split-Path $PSScriptRoot)
$Out = Join-Path $Root "pdk\sky130_fd_sc_hd__tt_025C_1v80.lib"
$Url = "https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/sky130_fd_sc_hd/latest/cells/sky130_fd_sc_hd__tt_025C_1v80.lib"

New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null
Write-Host "Fetching $Url ..."
Invoke-WebRequest -Uri $Url -OutFile $Out
Write-Host "Written $Out"
