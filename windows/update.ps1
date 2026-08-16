[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Tag,
    [string]$Repository = 'Tonkic/CLIProxyAPIPlus',
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$Bucket = '',
    [string]$Prefix = '',
    [string]$Endpoint = '',
    [string]$OssutilBin = 'ossutil',
    [switch]$NoRestart
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
. (Join-Path $PSScriptRoot 'windows-common.ps1')
$paths = Get-CpaPaths $Root
if (-not (Test-Path -LiteralPath (Join-Path $paths.Root 'config.yaml'))) { throw "Config not found: $($paths.Root)\config.yaml" }
if ($Tag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$') { throw "Invalid release tag: $Tag" }
if (-not $Bucket) { $Bucket = if ($env:ALIYUN_OSS_BUCKET) { $env:ALIYUN_OSS_BUCKET } else { 'update-cpa-plus' } }
if (-not $Endpoint) { $Endpoint = if ($env:ALIYUN_OSS_ENDPOINT) { $env:ALIYUN_OSS_ENDPOINT } else { 'oss-cn-shenzhen.aliyuncs.com' } }
if (-not $Prefix) { $Prefix = if ($env:ALIYUN_OSS_PREFIX) { $env:ALIYUN_OSS_PREFIX } else { 'CLIProxyAPIPlus' } }
$architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
switch ($architecture.ToUpperInvariant()) { 'AMD64' { $arch = 'amd64' } 'ARM64' { $arch = 'aarch64' } default { throw "Unsupported architecture: $architecture" } }
$version = $Tag.Substring(1)
$asset = "CLIProxyAPIPlus_${version}_windows_${arch}.zip"
$downloadDir = Join-Path $paths.Root ".update\downloads\$Tag"
$archive = Join-Path $downloadDir $asset
$checksums = Join-Path $downloadDir 'checksums.txt'
$staging = Join-Path $paths.Root '.update\staging'
$backup = Join-Path $paths.Root ('.update\backups\' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))
New-Item -ItemType Directory -Force -Path $downloadDir, (Split-Path $staging), (Split-Path $backup) | Out-Null
$lock = New-Object IO.FileStream((Join-Path (Split-Path $staging) 'update.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)

function Invoke-DownloadPair([string]$Base) {
    try {
        Invoke-WebRequest -Uri "$Base/$asset" -OutFile $archive -UseBasicParsing
        Invoke-WebRequest -Uri "$Base/checksums.txt" -OutFile $checksums -UseBasicParsing
        return $true
    } catch {
        Remove-Item -LiteralPath $archive, $checksums -Force -ErrorAction SilentlyContinue
        return $false
    }
}

try {
    if (-not (Test-Path -LiteralPath $archive) -or -not (Test-Path -LiteralPath $checksums)) {
        $downloaded = $false
        $ossutil = Get-Command $OssutilBin -ErrorAction SilentlyContinue
        $cleanPrefix = $Prefix.Trim('/')
        $ossBase = if ($cleanPrefix) { "oss://$Bucket/$cleanPrefix/$Tag" } else { "oss://$Bucket/$Tag" }
        if ($ossutil) {
            Write-Host "Trying authenticated OSS mirror: $ossBase"
            & $ossutil.Source cp "$ossBase/$asset" $archive -f -e $Endpoint
            if ($LASTEXITCODE -eq 0) { & $ossutil.Source cp "$ossBase/checksums.txt" $checksums -f -e $Endpoint }
            if ($LASTEXITCODE -eq 0 -and (Test-Path $archive) -and (Test-Path $checksums)) { $downloaded = $true } else { Remove-Item $archive, $checksums -Force -ErrorAction SilentlyContinue }
        }
        if (-not $downloaded) {
            $hostName = $Endpoint -replace '^https?://', '' -replace '/$', ''
            if (-not $hostName.StartsWith("$Bucket.", [StringComparison]::OrdinalIgnoreCase)) { $hostName = "$Bucket.$hostName" }
            $httpsBase = if ($cleanPrefix) { "https://$hostName/$cleanPrefix/$Tag" } else { "https://$hostName/$Tag" }
            Write-Host "Trying public OSS mirror: $httpsBase"
            $downloaded = Invoke-DownloadPair $httpsBase
        }
        if (-not $downloaded) {
            Write-Host 'OSS download failed; falling back to GitHub Releases.'
            if (-not (Invoke-DownloadPair "https://github.com/$Repository/releases/download/$Tag")) { throw 'Release download failed.' }
        }
    }

    $line = Get-Content -LiteralPath $checksums | Where-Object { $_ -match ('(?i)^[0-9a-f]{64}\s+\*?' + [regex]::Escape($asset) + '$') } | Select-Object -First 1
    if (-not $line) { throw "Archive checksum not found: $asset" }
    $expected = ($line -split '\s+')[0]
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    if (-not $actual.Equals($expected, [StringComparison]::OrdinalIgnoreCase)) { throw 'Checksum verification failed.' }
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $staging, $backup, (Join-Path $backup 'manager') | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $staging -Force
    $newCpa = @(Get-ChildItem -LiteralPath $staging -Recurse -File -Filter 'cli-proxy-api-plus.exe')
    $newManager = @(Get-ChildItem -LiteralPath $staging -Recurse -File -Filter 'cpa-manager-plus.exe')
    if ($newCpa.Count -ne 1 -or $newManager.Count -ne 1) { throw 'Release archive has an unexpected executable layout.' }
    $wasRunning = ($null -ne (Get-OwnedProcess $paths.CpaPid $paths.CpaExe)) -or ($null -ne (Get-OwnedProcess $paths.ManagerPid $paths.ManagerExe))
    & (Join-Path $PSScriptRoot 'stop.ps1') -Root $paths.Root
    if (Test-Path $paths.CpaExe) { Copy-Item $paths.CpaExe (Join-Path $backup 'cli-proxy-api-plus.exe') }
    if (Test-Path $paths.ManagerExe) { Copy-Item $paths.ManagerExe (Join-Path $backup 'manager\cpa-manager-plus.exe') }
    foreach ($name in @('windows-common.ps1','start.ps1','stop.ps1','restart.ps1','update.ps1','start.cmd','stop.cmd','restart.cmd','update.cmd')) {
        $current = Join-Path $paths.Root "windows\$name"
        if (Test-Path $current) { Copy-Item $current (Join-Path $backup $name) }
    }
    Copy-Item $newCpa[0].FullName $paths.CpaExe -Force
    New-Item -ItemType Directory -Force -Path (Split-Path $paths.ManagerExe) | Out-Null
    Copy-Item $newManager[0].FullName $paths.ManagerExe -Force
    foreach ($name in @('windows-common.ps1','start.ps1','stop.ps1','restart.ps1','update.ps1','start.cmd','stop.cmd','restart.cmd','update.cmd')) {
        $source = Join-Path $staging "windows\$name"
        if (Test-Path $source) { Copy-Item $source (Join-Path $paths.Root "windows\$name") -Force }
    }
    $rootStart = Get-ChildItem -LiteralPath $staging -File -Filter 'start.cmd' | Select-Object -First 1
    if ($rootStart) { Copy-Item $rootStart.FullName (Join-Path $paths.Root 'start.cmd') -Force }
    if (-not $NoRestart) { & (Join-Path $paths.Root 'windows\start.ps1') -Root $paths.Root }
    Write-Host "Updated to $Tag. Backup: $backup"
} catch {
    if (Test-Path (Join-Path $backup 'cli-proxy-api-plus.exe')) { Copy-Item (Join-Path $backup 'cli-proxy-api-plus.exe') $paths.CpaExe -Force }
    if (Test-Path (Join-Path $backup 'manager\cpa-manager-plus.exe')) { Copy-Item (Join-Path $backup 'manager\cpa-manager-plus.exe') $paths.ManagerExe -Force }
    foreach ($name in @('windows-common.ps1','start.ps1','stop.ps1','restart.ps1','update.ps1','start.cmd','stop.cmd','restart.cmd','update.cmd')) {
        $saved = Join-Path $backup $name
        if (Test-Path $saved) { Copy-Item $saved (Join-Path $paths.Root "windows\$name") -Force }
    }
    if ($wasRunning -and -not $NoRestart) {
        try { & (Join-Path $paths.Root 'windows\start.ps1') -Root $paths.Root } catch { Write-Warning "Rollback restored the previous files, but restart failed: $_" }
    }
    throw
} finally {
    if ($lock) { $lock.Dispose() }
}
