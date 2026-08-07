# install_templates.ps1
# Automates the setup of Godot export templates on Windows systems.

$ErrorActionPreference = "Stop"

# 1. Find Godot executable
$godotExe = Get-Command godot -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $godotExe) {
    # Try common local path
    $commonPath = "D:\Godot\Godot.exe"
    if (Test-Path $commonPath) {
        $godotExe = $commonPath
    } else {
        Write-Error "Godot executable was not found in your PATH or at the common fallback path '$commonPath'.`nPlease ensure Godot is installed and added to your PATH, or run the script after editing the executable location."
    }
}

Write-Host "Using Godot executable: $godotExe" -ForegroundColor Cyan

# 2. Get Godot version
$versionOutput = & $godotExe --version --headless 2>$null
if (-not $versionOutput) {
    # Fallback to redirecting standard output if a console isn't attached (GUI subsystem app)
    $tempFile = [System.IO.Path]::GetTempFileName()
    Start-Process -FilePath $godotExe -ArgumentList "--version", "--headless" -NoNewWindow -RedirectStandardOutput $tempFile -Wait
    $versionOutput = Get-Content $tempFile -Raw
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}

$versionOutput = $versionOutput.Trim()
if (-not $versionOutput) {
    Write-Error "Failed to retrieve the Godot version from $godotExe."
}

Write-Host "Detected Godot version: $versionOutput" -ForegroundColor Cyan

# 3. Parse version parts
# Examples:
#   4.7.1.stable.official.a13da4feb -> Base: 4.7.1, Status: stable, Mono: False
#   4.3.stable.mono.official.xxxx -> Base: 4.3, Status: stable, Mono: True
$isMono = $versionOutput -like "*mono*"
$versionParts = $versionOutput -split '\.'
$baseParts = @()
$status = "stable"

foreach ($part in $versionParts) {
    if ($part -match '^\d+$') {
        $baseParts += $part
    } elseif ($part -match '^(stable|rc\d*|beta\d*|alpha\d*|dev\d*)$') {
        $status = $part
        break
    }
}
$baseVersion = $baseParts -join "."

Write-Host "Parsed Base Version: $baseVersion"
Write-Host "Build Status: $status"
Write-Host "Mono (.NET): $isMono"

# 4. Construct URL and Target Path
if ($isMono) {
    $zipName = "Godot_v${baseVersion}-${status}_mono_export_templates.tpz"
    $targetFolderName = "${baseVersion}.${status}.mono"
} else {
    $zipName = "Godot_v${baseVersion}-${status}_export_templates.tpz"
    $targetFolderName = "${baseVersion}.${status}"
}

$url = "https://github.com/godotengine/godot/releases/download/${baseVersion}-${status}/${zipName}"
$appdata = [Environment]::GetFolderPath("ApplicationData")
$destDir = Join-Path $appdata "Godot" | Join-Path -ChildPath "export_templates" | Join-Path -ChildPath $targetFolderName

Write-Host "Target Folder: $destDir" -ForegroundColor Yellow

# Check if templates are already installed
if (Test-Path $destDir) {
    Write-Host "Export templates for version $targetFolderName are already installed at $destDir." -ForegroundColor Green
    $response = Read-Host "Do you want to re-download and re-install? (y/N)"
    if ($response -ne "y") {
        Write-Host "Skipped installation."
        exit
    }
}

# Create target directory
New-Item -ItemType Directory -Force -Path $destDir | Out-Null

# 5. Download the template archive
$tempZip = Join-Path ([System.IO.Path]::GetTempPath()) $zipName
Write-Host "Downloading templates from: $url" -ForegroundColor Green
Write-Host "Downloading to temporary file: $tempZip"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    # Set User-Agent to prevent blockages
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    $webClient.DownloadFile($url, $tempZip)
} catch {
    Write-Error "Failed to download templates. Please check your network connection or verify the URL: $url"
}

# 6. Extract archive
Write-Host "Download complete. Extracting files..." -ForegroundColor Green
$tempExtractDir = Join-Path ([System.IO.Path]::GetTempPath()) "godot_templates_extract"
if (Test-Path $tempExtractDir) {
    Remove-Item $tempExtractDir -Recurse -Force | Out-Null
}
New-Item -ItemType Directory -Force -Path $tempExtractDir | Out-Null

try {
    Expand-Archive -Path $tempZip -DestinationPath $tempExtractDir -Force
    
    $extractedTemplates = Join-Path $tempExtractDir "templates"
    if (Test-Path $extractedTemplates) {
        # Copy contents from the "templates" root folder inside the zip into the destination folder
        Copy-Item -Path "$extractedTemplates\*" -Destination $destDir -Recurse -Force
        Write-Host "Export templates successfully installed!" -ForegroundColor Green
    } else {
        Write-Error "Invalid templates archive format (could not find 'templates' subdirectory)."
    }
} finally {
    # Clean up temporary folders
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
}
