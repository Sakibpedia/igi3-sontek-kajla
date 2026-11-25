# Runs the headless IGI smoke test for every mission (1..15).
# Usage: powershell tools/test/run_all_missions.ps1
# Optional: -Godot "C:\path\to\Godot_v4.3-stable_win64_console.exe"
param(
    [string]$Godot = "godot",
    [switch]$KeepLogs
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$logDir = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$failed = @()
for ($m = 1; $m -le 15; $m++) {
    $env:MISSION = "$m"
    $log = Join-Path $logDir "mission_$m.log"
    & $Godot --headless --path $root "res://tools/test/IgiTest.tscn" *> $log
    $code = $LASTEXITCODE
    $line = (Select-String -Path $log -Pattern '\[IGI\]' | Select-Object -Last 1).Line
    Write-Output "M$m (exit $code): $line"
    if ($code -ne 0 -or $line -notmatch '\[IGI\] PASS') {
        $failed += $m
        Select-String -Path $log -Pattern 'FAIL|SCRIPT ERROR' | Select-Object -First 8 |
            ForEach-Object { Write-Output "    $($_.Line.Trim())" }
    }
    if (-not $KeepLogs) { Remove-Item $log -Force }
}
Remove-Item Env:MISSION -ErrorAction SilentlyContinue

if ($failed.Count -gt 0) {
    throw "Failing missions: $($failed -join ', ')"
}
Write-Output "[IGI] ALL 15 MISSIONS PASS"
