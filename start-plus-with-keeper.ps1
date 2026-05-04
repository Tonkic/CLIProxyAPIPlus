param(
    [string]$Config = "config.yaml",
    [string]$KeeperEnv = "keeper\.env"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $Root "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$CpaExe = Join-Path $Root "cli-proxy-api-plus.exe"
if (-not (Test-Path $CpaExe)) {
    $CpaExe = Join-Path $Root "CLIProxyAPIPlus.exe"
}
if (-not (Test-Path $CpaExe)) {
    throw "CLIProxyAPIPlus executable not found. Expected cli-proxy-api-plus.exe or CLIProxyAPIPlus.exe next to this script."
}

$KeeperExe = Join-Path $Root "keeper\cpa-usage-keeper.exe"
if (-not (Test-Path $KeeperExe)) {
    throw "CPA Usage Keeper executable not found: $KeeperExe"
}

$ConfigPath = Join-Path $Root $Config
$KeeperEnvPath = Join-Path $Root $KeeperEnv
if (-not (Test-Path $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}
if (-not (Test-Path $KeeperEnvPath)) {
    throw "Keeper env file not found: $KeeperEnvPath"
}

$Cpa = Start-Process -FilePath $CpaExe -ArgumentList @("--config", $ConfigPath) -WorkingDirectory $Root -RedirectStandardOutput (Join-Path $LogDir "cli-proxy-api-plus.out.log") -RedirectStandardError (Join-Path $LogDir "cli-proxy-api-plus.err.log") -PassThru
Start-Sleep -Seconds 2
$Keeper = Start-Process -FilePath $KeeperExe -ArgumentList @("--env", $KeeperEnvPath) -WorkingDirectory (Join-Path $Root "keeper") -RedirectStandardOutput (Join-Path $LogDir "cpa-usage-keeper.out.log") -RedirectStandardError (Join-Path $LogDir "cpa-usage-keeper.err.log") -PassThru

Write-Host "CLIProxyAPIPlus started: PID=$($Cpa.Id), http://127.0.0.1:8317"
Write-Host "CPA Usage Keeper started: PID=$($Keeper.Id), http://127.0.0.1:8080"
Write-Host "Logs: $LogDir"
Write-Host "Press Ctrl+C to stop both services."

try {
    while (-not $Cpa.HasExited -and -not $Keeper.HasExited) {
        Start-Sleep -Seconds 1
        $Cpa.Refresh()
        $Keeper.Refresh()
    }
} finally {
    foreach ($Process in @($Keeper, $Cpa)) {
        if ($Process -and -not $Process.HasExited) {
            Stop-Process -Id $Process.Id -Force
        }
    }
}
