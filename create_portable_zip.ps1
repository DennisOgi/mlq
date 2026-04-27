# Create Portable ZIP Package for My Leadership Quest
# This creates a ZIP file that users can extract and run anywhere

$AppName = "MyLeadershipQuest"
$Version = "1.0.0"
$SourceDir = "build\windows\x64\runner\Release"
$OutputDir = "installer_output"
$ZipName = "${AppName}_Portable_v${Version}.zip"

Write-Host "Creating portable package for My Leadership Quest..." -ForegroundColor Cyan

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Green
}

# Check if source directory exists
if (-not (Test-Path $SourceDir)) {
    Write-Host "Error: Build directory not found at $SourceDir" -ForegroundColor Red
    Write-Host "Please run 'flutter build windows --release' first" -ForegroundColor Yellow
    exit 1
}

# Create temporary staging directory
$StagingDir = "temp_portable"
if (Test-Path $StagingDir) {
    Remove-Item -Path $StagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $StagingDir | Out-Null

Write-Host "Copying files to staging directory..." -ForegroundColor Yellow

# Copy all files from Release folder
Copy-Item -Path "$SourceDir\*" -Destination $StagingDir -Recurse -Force

# Create README file
$ReadmeContent = @"
My Leadership Quest - Portable Edition
Version: $Version

INSTALLATION:
1. Extract all files to a folder of your choice
2. Double-click 'my_leadership_quest.exe' to run the application
3. No installation required!

REQUIREMENTS:
- Windows 10 or later (64-bit)
- Internet connection for full functionality

FEATURES:
- Leadership goal tracking
- Daily challenges
- AI-powered coaching
- Progress analytics
- And much more!

SUPPORT:
Visit: https://mlq.app
Email: support@mlq.app

Copyright (C) 2026 MLQ. All rights reserved.
"@

$ReadmeContent | Out-File -FilePath "$StagingDir\README.txt" -Encoding UTF8

Write-Host "Creating ZIP archive..." -ForegroundColor Yellow

# Create ZIP file
$ZipPath = Join-Path $OutputDir $ZipName
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

# Use .NET compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($StagingDir, $ZipPath, 'Optimal', $false)

# Clean up staging directory
Remove-Item -Path $StagingDir -Recurse -Force

# Get file size
$FileSize = (Get-Item $ZipPath).Length / 1MB
$FileSizeFormatted = "{0:N2} MB" -f $FileSize

Write-Host ""
Write-Host "SUCCESS: Portable package created!" -ForegroundColor Green
Write-Host "Location: $ZipPath" -ForegroundColor Cyan
Write-Host "Size: $FileSizeFormatted" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now distribute this ZIP file to users." -ForegroundColor Yellow
Write-Host "Users extract and run my_leadership_quest.exe" -ForegroundColor Yellow
