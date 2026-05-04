param(
    [string]$InstallDir = "",
    [string]$Tag = "",
    [string]$Repo = "Tonkic/CLIProxyAPIPlus",
    [string]$Config = "",
    [string]$Log = "",
    [switch]$NoRestart,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host $Message
}

function Invoke-Step {
    param(
        [string]$Message,
        [scriptblock]$Action
    )
    Write-Step "+ $Message"
    if (-not $DryRun) {
        & $Action
    }
}

function Get-LatestTag {
    param([string]$Repository)
    $Uri = "https://api.github.com/repos/$Repository/releases/latest"
    $Release = Invoke-RestMethod -Uri $Uri -Headers @{ "User-Agent" = "CLIProxyAPIPlus-Updater" }
    if (-not $Release.tag_name) {
        throw "failed to parse latest release tag for $Repository"
    }
    return $Release.tag_name
}

function Get-AssetArch {
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") {
        return "aarch64"
    }
    return "amd64"
}

function Get-ChecksumHash {
    param(
        [string]$ChecksumPath,
        [string]$Asset
    )
    $Pattern = "(^|\s)([A-Fa-f0-9]{64})\s+\*?$([regex]::Escape($Asset))$"
    foreach ($Line in Get-Content -Path $ChecksumPath) {
        if ($Line -match $Pattern) {
            return $Matches[2].ToLowerInvariant()
        }
    }
    throw "checksum entry not found for $Asset"
}

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$InstallDir = [System.IO.Path]::GetFullPath($InstallDir)
$ConfigPath = if ([string]::IsNullOrWhiteSpace($Config)) { Join-Path $InstallDir "config.yaml" } else { [System.IO.Path]::GetFullPath($Config) }
$LogPath = if ([string]::IsNullOrWhiteSpace($Log)) { Join-Path $InstallDir "runtime.log" } else { [System.IO.Path]::GetFullPath($Log) }
$BinPath = Join-Path $InstallDir "cli-proxy-api-plus.exe"
$UpdateDir = Join-Path $InstallDir ".update"
$DownloadDir = Join-Path $UpdateDir "downloads"
$StagingDir = Join-Path $UpdateDir "staging"
$BackupDir = Join-Path (Join-Path $UpdateDir "backups") ((Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ"))
$Arch = Get-AssetArch
$OS = "windows"

if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = Get-LatestTag -Repository $Repo
}
$Version = if ($Tag.StartsWith("v")) { $Tag.Substring(1) } else { $Tag }
$Asset = "CLIProxyAPIPlus_${Version}_${OS}_${Arch}.zip"
$BaseUrl = "https://github.com/$Repo/releases/download/$Tag"
$ArchiveUrl = "$BaseUrl/$Asset"
$ChecksumUrl = "$BaseUrl/checksums.txt"
$ArchivePath = Join-Path $DownloadDir $Asset
$ChecksumPath = Join-Path $DownloadDir "checksums.txt"

Write-Step "Repository: $Repo"
Write-Step "Release tag: $Tag"
Write-Step "Asset: $Asset"
Write-Step "Install dir: $InstallDir"
Write-Step "Binary: $BinPath"
Write-Step "Config: $ConfigPath"
Write-Step "Log: $LogPath"

if (-not (Test-Path $ConfigPath)) {
    throw "config not found: $ConfigPath"
}

Invoke-Step "New-Item -ItemType Directory -Force $DownloadDir $StagingDir $BackupDir" {
    New-Item -ItemType Directory -Force -Path $DownloadDir, $StagingDir, $BackupDir | Out-Null
}
Invoke-Step "Invoke-WebRequest $ArchiveUrl -OutFile $ArchivePath" {
    Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ArchivePath
}
Invoke-Step "Invoke-WebRequest $ChecksumUrl -OutFile $ChecksumPath" {
    Invoke-WebRequest -Uri $ChecksumUrl -OutFile $ChecksumPath
}

if ($DryRun) {
    Write-Step "Dry run complete. No files were changed."
    exit 0
}

Write-Step "Verifying checksum..."
$ExpectedHash = Get-ChecksumHash -ChecksumPath $ChecksumPath -Asset $Asset
$ActualHash = (Get-FileHash -Algorithm SHA256 -Path $ArchivePath).Hash.ToLowerInvariant()
if ($ExpectedHash -ne $ActualHash) {
    throw "checksum verification failed for $Asset"
}

if (Test-Path $StagingDir) {
    Remove-Item -Recurse -Force $StagingDir
}
New-Item -ItemType Directory -Force -Path $StagingDir | Out-Null
Expand-Archive -Path $ArchivePath -DestinationPath $StagingDir -Force

$NewBin = Join-Path $StagingDir "cli-proxy-api-plus.exe"
if (-not (Test-Path $NewBin)) {
    $NestedBin = Join-Path $StagingDir "bin\cli-proxy-api-plus.exe"
    if (Test-Path $NestedBin) {
        $NewBin = $NestedBin
    } else {
        $Found = Get-ChildItem -Path $StagingDir -Recurse -Filter "cli-proxy-api-plus.exe" -File | Select-Object -First 1
        if ($Found) {
            $NewBin = $Found.FullName
        }
    }
}
if (-not (Test-Path $NewBin)) {
    throw "cli-proxy-api-plus.exe not found in archive"
}

if (Test-Path $BinPath) {
    Copy-Item -Path $BinPath -Destination (Join-Path $BackupDir "cli-proxy-api-plus.exe") -Force
}
Copy-Item -Path $NewBin -Destination $BinPath -Force

foreach ($File in @("start-plus-with-keeper.ps1", "start-plus-with-keeper.sh", "README.md", "README_CN.md", "README_JA.md", "config.example.yaml", "update-linux.sh", "update-windows.ps1")) {
    $Source = Join-Path $StagingDir $File
    if (Test-Path $Source) {
        Copy-Item -Path $Source -Destination (Join-Path $InstallDir $File) -Force
    }
}

$KeeperDir = Join-Path $InstallDir "keeper"
$KeeperEnvExample = Join-Path $StagingDir "keeper\.env.example"
if (Test-Path $KeeperEnvExample) {
    New-Item -ItemType Directory -Force -Path $KeeperDir | Out-Null
    Copy-Item -Path $KeeperEnvExample -Destination (Join-Path $KeeperDir ".env.example") -Force
}
$KeeperExe = Join-Path $StagingDir "keeper\cpa-usage-keeper.exe"
if (Test-Path $KeeperExe) {
    New-Item -ItemType Directory -Force -Path $KeeperDir | Out-Null
    Copy-Item -Path $KeeperExe -Destination (Join-Path $KeeperDir "cpa-usage-keeper.exe") -Force
}

if ($NoRestart) {
    Write-Step "Skipping restart because -NoRestart was provided."
} else {
    Write-Step "Update installed. Restart your Windows service/process with:"
    Write-Step "  cd `"$InstallDir`""
    Write-Step "  .\cli-proxy-api-plus.exe -config `"$ConfigPath`" >> `"$LogPath`" 2>&1"
}

Write-Step "Update complete."
