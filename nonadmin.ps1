<#
.SYNOPSIS
    Non-Admin PowerShell Environment Setup (Chris Titus Tech style)
.DESCRIPTION
    Installs Oh My Posh, Zoxide, Terminal-Icons, CaskaydiaCove Nerd Font, 
    and configures $PROFILE entirely in CurrentUser / HKCU scope without elevation.
#>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "==> [1/6] Configuring execution policy and directories..." -ForegroundColor Cyan

# 1. Execution Policy (silently continue if overridden by Process scope)
if ((Get-ExecutionPolicy) -in @('Restricted', 'Undefined')) {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction SilentlyContinue
}

# Directories
$binDir     = "$env:LOCALAPPDATA\Programs\bin"
$fontDir    = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$profileDir = Split-Path -Path $PROFILE -Parent

foreach ($dir in @($binDir, $fontDir, $profileDir)) {
    if (-not (Test-Path -Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# Persistent User PATH Configuration
$userPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::User)
$pathEntries = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($pathEntries -notcontains $binDir) {
    $pathEntries += $binDir
    [Environment]::SetEnvironmentVariable('Path', ($pathEntries -join ';'), [EnvironmentVariableTarget]::User)
}
if (($env:Path -split ';') -notcontains $binDir) {
    $env:Path = "$env:Path;$binDir"
}

Write-Host "==> [2/6] Installing Terminal-Icons module..." -ForegroundColor Cyan
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction SilentlyContinue
}

Write-Host "==> [3/6] Installing Oh My Posh & Zoxide binaries..." -ForegroundColor Cyan

# 3a. Oh My Posh (standalone executable)
$ompExe = Join-Path $binDir 'oh-my-posh.exe'
if (-not (Test-Path $ompExe)) {
    Invoke-WebRequest -Uri 'https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-windows-amd64.exe' `
        -OutFile $ompExe -UseBasicParsing
}

# 3b. Zoxide (GitHub Release extraction)
$zoxideExe = Join-Path $binDir 'zoxide.exe'
if (-not (Test-Path $zoxideExe)) {
    $zRel = Invoke-RestMethod -Uri 'https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest'
    $zAsset = $zRel.assets | Where-Object { $_.name -match 'x86_64-pc-windows-msvc\.zip$' } | Select-Object -First 1
    if (-not $zAsset) {
        throw 'Could not find a Windows x86_64 zoxide release asset.'
    }
    $zZip = Join-Path $env:TEMP 'zoxide.zip'
    $zExt = Join-Path $env:TEMP 'zoxide_ext'

    Invoke-WebRequest -Uri $zAsset.browser_download_url -OutFile $zZip -UseBasicParsing
    Expand-Archive -Path $zZip -DestinationPath $zExt -Force
    Copy-Item -Path "$zExt\zoxide.exe" -Destination $zoxideExe -Force
    Remove-Item -Path $zZip, $zExt -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "==> [4/6] Installing CaskaydiaCove Nerd Font (User Scope)..." -ForegroundColor Cyan
$fZip = Join-Path $env:TEMP 'CascadiaCode.zip'
$fExt = Join-Path $env:TEMP 'CascadiaCode_ext'

Invoke-WebRequest -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/CascadiaCode.zip' `
    -OutFile $fZip -UseBasicParsing
Expand-Archive -Path $fZip -DestinationPath $fExt -Force

Get-ChildItem -Path $fExt -Filter '*.ttf' | ForEach-Object {
    $targetFontFile = Join-Path $fontDir $_.Name
    
    # Safely copy if not present; avoid throwing if file is locked in memory
    if (-not (Test-Path -Path $targetFontFile)) {
        try {
            Copy-Item -Path $_.FullName -Destination $targetFontFile -Force -ErrorAction Stop
        } catch {
            Write-Verbose "Skipped locked file: $($_.Name)"
        }
    }

    # Register in user registry
    New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' `
        -Name "$($_.BaseName) (TrueType)" -Value $targetFontFile -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
}
Remove-Item -Path $fZip, $fExt -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "==> [5/6] Downloading Oh My Posh theme..." -ForegroundColor Cyan
$themeFile = Join-Path $profileDir 'cobalt2.omp.json'
if (-not (Test-Path $themeFile)) {
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/cobalt2.omp.json' `
        -OutFile $themeFile -UseBasicParsing
}

Write-Host "==> [6/6] Writing PowerShell profile..." -ForegroundColor Cyan
$profileScript = @'
# =====================================================================
# Standalone Non-Admin Profile (Titus-Style)
# =====================================================================

# 1. PSReadLine Configuration
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# 2. Terminal-Icons
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}

# 3. Zoxide
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& zoxide init powershell | Out-String)
}

# 4. Oh My Posh
$theme = Join-Path (Split-Path -Path $PROFILE -Parent) 'cobalt2.omp.json'
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    if (Test-Path -Path $theme) {
        oh-my-posh init pwsh --config $theme | Invoke-Expression
    } else {
        oh-my-posh init pwsh | Invoke-Expression
    }
}

# =====================================================================
# Aliases & Helper Functions
# =====================================================================
function touch { param([Parameter(Mandatory)][string]$File) if (Test-Path $File) { (Get-Item $File).LastWriteTime = Get-Date } else { New-Item -Path $File -ItemType File -Force | Out-Null } }
function mkcd { param([Parameter(Mandatory)][string]$Path) New-Item -Path $Path -ItemType Directory -Force | Out-Null; Set-Location $Path }
function ff   { param([Parameter(Mandatory)][string]$Name) Get-ChildItem -Recurse -Filter "*$Name*" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName }

function k9    { param([Parameter(Mandatory)][string]$Name) Stop-Process -Name $Name -Force }
function pkill { param([Parameter(Mandatory)][string]$Name) Stop-Process -Name $Name -Force }
function pgrep { param([Parameter(Mandatory)][string]$Name) Get-Process | Where-Object ProcessName -Like "*$Name*" }

function ep             { notepad $PROFILE }
function reload-profile { . $PROFILE }
function pubip          { (Invoke-RestMethod -Uri 'https://api.ipify.org').Trim() }
function uptime         { (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime }
function which          { param([string]$Name) (Get-Command $Name -ErrorAction SilentlyContinue).Source }

function la   { Get-ChildItem -Force }
function ll   { Get-ChildItem -Force | Format-Wide }
function df   { Get-PSDrive -PSProvider FileSystem }
function head { param([string]$Path, [int]$n = 10) Get-Content $Path -Head $n }
function tail { param([string]$Path, [int]$n = 10) Get-Content $Path -Tail $n }
function grep { param([string]$Pattern, [string]$Path) Select-String -Pattern $Pattern -Path $Path }

# Git Shortcuts
function gs    { git status }
function ga    { git add @args }
function gc    { git commit -m "$args" }
function gp    { git push @args }
function gpull { git pull @args }
function lazyg {
    git add .
    git commit -m (if ($args.Count -gt 0) {$args -join ' ' } else { "Quick update: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" })
    git push
}
'@

Set-Content -Path $PROFILE -Value $profileScript -Encoding UTF8

Write-Host "`nSetup completed successfully!" -ForegroundColor Green
Write-Host "Run '. `$PROFILE' or restart your terminal to load the changes." -ForegroundColor Yellow