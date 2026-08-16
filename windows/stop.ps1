[CmdletBinding()]
param([string]$Root = '', [int]$Timeout = 15)
$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'windows-common.ps1')
$paths = Get-CpaPaths $Root
Stop-OwnedProcess $paths.ManagerPid $paths.ManagerExe $Timeout
Stop-OwnedProcess $paths.CpaPid $paths.CpaExe $Timeout
Write-Host 'CPA and CPA-Manager-Plus are stopped.'
