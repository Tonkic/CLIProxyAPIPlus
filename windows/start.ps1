[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$Config = '',
    [string]$ManagerAddress = '127.0.0.1:18317',
    [string]$CollectorMode = 'auto',
    [string]$CpaHealthUrl = 'http://127.0.0.1:8317/',
    [string]$ManagerHealthUrl = 'http://127.0.0.1:18317/health',
    [int]$HealthTimeout = 30
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows-common.ps1')
$paths = Get-CpaPaths $Root
if (-not $Config) { $Config = Join-Path $paths.Root 'config.yaml' }
if (-not (Test-Path -LiteralPath $Config)) {
    $exampleConfig = Join-Path $paths.Root 'config.example.yaml'
    if (-not (Test-Path -LiteralPath $exampleConfig)) { throw "Config and template not found: $Config" }
    Copy-Item -LiteralPath $exampleConfig -Destination $Config
    Write-Host "Created $Config from config.example.yaml."
    Write-Host 'Edit host, api-keys, and remote-management.secret-key as needed, then run start.cmd again.'
    exit 2
}
if (-not (Test-Path -LiteralPath $paths.CpaExe)) { throw "CPA executable not found: $($paths.CpaExe)" }
if (-not (Test-Path -LiteralPath $paths.ManagerExe)) { throw "Manager executable not found: $($paths.ManagerExe)" }
New-Item -ItemType Directory -Force -Path $paths.Runtime, $paths.Logs, (Join-Path $paths.Root 'manager\data') | Out-Null

$cpa = Get-OwnedProcess $paths.CpaPid $paths.CpaExe
if ($null -eq $cpa) {
    $configArgument = '"' + $Config.Replace('"', '\"') + '"'
    $cpa = Start-Process -FilePath $paths.CpaExe -ArgumentList @('--config', $configArgument) -WorkingDirectory $paths.Root -RedirectStandardOutput (Join-Path $paths.Logs 'runtime.out.log') -RedirectStandardError (Join-Path $paths.Logs 'runtime.err.log') -WindowStyle Hidden -PassThru
    try { Set-Content -LiteralPath $paths.CpaPid -Value $cpa.Id -Encoding ASCII } catch { Stop-Process -Id $cpa.Id -Force -ErrorAction SilentlyContinue; throw }
}
try { Wait-HttpHealthy $CpaHealthUrl $HealthTimeout } catch { Stop-OwnedProcess $paths.CpaPid $paths.CpaExe; throw }

$manager = Get-OwnedProcess $paths.ManagerPid $paths.ManagerExe
if ($null -eq $manager) {
    $oldAddr = $env:HTTP_ADDR; $oldData = $env:USAGE_DATA_DIR; $oldMode = $env:USAGE_COLLECTOR_MODE
    try {
        $env:HTTP_ADDR = $ManagerAddress
        $env:USAGE_DATA_DIR = Join-Path $paths.Root 'manager\data'
        $env:USAGE_COLLECTOR_MODE = $CollectorMode
        $manager = Start-Process -FilePath $paths.ManagerExe -WorkingDirectory (Join-Path $paths.Root 'manager') -RedirectStandardOutput (Join-Path $paths.Logs 'cpa-manager-plus.out.log') -RedirectStandardError (Join-Path $paths.Logs 'cpa-manager-plus.err.log') -WindowStyle Hidden -PassThru
        try { Set-Content -LiteralPath $paths.ManagerPid -Value $manager.Id -Encoding ASCII } catch { Stop-Process -Id $manager.Id -Force -ErrorAction SilentlyContinue; throw }
    } finally {
        $env:HTTP_ADDR = $oldAddr; $env:USAGE_DATA_DIR = $oldData; $env:USAGE_COLLECTOR_MODE = $oldMode
    }
}
try { Wait-HttpHealthy $ManagerHealthUrl $HealthTimeout } catch { Stop-OwnedProcess $paths.ManagerPid $paths.ManagerExe; Stop-OwnedProcess $paths.CpaPid $paths.CpaExe; throw }
Write-Host "CPA and CPA-Manager-Plus are running."
