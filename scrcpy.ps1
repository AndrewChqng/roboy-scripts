$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1. Define target directory
$installDir = "$env:LOCALAPPDATA\Programs\scrcpy"
if (-not (Test-Path $installDir)) {
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
}

# 2. Fetch latest release metadata from GitHub API
Write-Host "Fetching latest scrcpy release metadata..." -ForegroundColor Cyan
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/Genymobile/scrcpy/releases/latest"
$asset = $release.assets | Where-Object { $_.name -match '^scrcpy-win64-.*\.zip$' } | Select-Object -First 1

if (-not $asset) {
    throw "Unable to locate a 64-bit Windows release asset from GitHub."
}

# 3. Download and extract
$tempZip = Join-Path $env:TEMP "scrcpy.zip"
$tempExtract = Join-Path $env:TEMP "scrcpy_extract"

Write-Host "Downloading $($asset.name)..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip -UseBasicParsing

Write-Host "Extracting binaries..." -ForegroundColor Cyan
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

# Locate extracted contents (GitHub zip contains an internal root folder like scrcpy-win64-vX.XX)
$extractedRoot = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
Get-ChildItem -Path $extractedRoot.FullName | Copy-Item -Destination $installDir -Recurse -Force

# Clean up temporary archives
Remove-Item -Path $tempZip, $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

# 4. Register to User PATH (HKCU persistent + current process)
$userPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::User)
$pathList = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($pathList -notcontains $installDir) {
    $pathList += $installDir
    [Environment]::SetEnvironmentVariable('Path', ($pathList -join ';'), [EnvironmentVariableTarget]::User)
}

if (($env:Path -split ';') -notcontains $installDir) {
    $env:Path = "$env:Path;$installDir"
}

Write-Host "scrcpy installed to: $installDir" -ForegroundColor Green
Get-Command scrcpy | Select-Object Name, Source
