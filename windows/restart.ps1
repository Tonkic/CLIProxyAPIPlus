[CmdletBinding()]
param([string]$Root = '', [int]$HealthTimeout = 30)
$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
& (Join-Path $PSScriptRoot 'stop.ps1') -Root $Root
& (Join-Path $PSScriptRoot 'start.ps1') -Root $Root -HealthTimeout $HealthTimeout
