$ErrorActionPreference = 'Stop'

function Get-CpaPaths {
    param([string]$Root)
    $resolved = [IO.Path]::GetFullPath($Root)
    return @{
        Root = $resolved
        Runtime = Join-Path $resolved '.runtime'
        Logs = Join-Path $resolved 'logs'
        CpaExe = Join-Path $resolved 'cli-proxy-api-plus.exe'
        ManagerExe = Join-Path $resolved 'manager\cpa-manager-plus.exe'
        CpaPid = Join-Path $resolved '.runtime\cli-proxy-api-plus.pid'
        ManagerPid = Join-Path $resolved '.runtime\cpa-manager-plus.pid'
    }
}

function Get-OwnedProcess {
    param([string]$PidFile, [string]$ExpectedPath)
    if (-not (Test-Path -LiteralPath $PidFile)) { return $null }
    $text = (Get-Content -LiteralPath $PidFile -Raw).Trim()
    if ($text -notmatch '^\d+$') { Remove-Item -LiteralPath $PidFile -Force; return $null }
    $process = Get-Process -Id ([int]$text) -ErrorAction SilentlyContinue
    if ($null -eq $process) { Remove-Item -LiteralPath $PidFile -Force; return $null }
    try { $actual = $process.MainModule.FileName } catch { throw "Cannot verify executable path for PID $text; refusing to manage it." }
    if (-not [string]::Equals([IO.Path]::GetFullPath($actual), [IO.Path]::GetFullPath($ExpectedPath), [StringComparison]::OrdinalIgnoreCase)) {
        throw "PID $text belongs to another executable: $actual"
    }
    return $process
}

function Wait-HttpHealthy {
    param([string]$Url, [int]$TimeoutSeconds = 30)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) { return }
        } catch { }
        Start-Sleep -Seconds 1
    }
    throw "Health check timed out: $Url"
}

function Stop-OwnedProcess {
    param([string]$PidFile, [string]$ExpectedPath, [int]$TimeoutSeconds = 15)
    $process = Get-OwnedProcess -PidFile $PidFile -ExpectedPath $ExpectedPath
    if ($null -eq $process) { return }
    Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline -and (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) { Start-Sleep -Milliseconds 250 }
    if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) { Stop-Process -Id $process.Id -Force }
    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
}
