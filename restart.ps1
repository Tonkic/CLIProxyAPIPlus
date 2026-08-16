[CmdletBinding()]
param([string]$Root = $PSScriptRoot, [int]$HealthTimeout = 30)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'stop.ps1') -Root $Root
& (Join-Path $PSScriptRoot 'start.ps1') -Root $Root -HealthTimeout $HealthTimeout
