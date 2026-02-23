# Create Portable ZIP Package
# No installation required - extract and run

Write-Host "=== My Leadership Quest - Portable Package Creator ===" -ForegroundColor Cyan
Write-Host ""

# Check if build exists
if (-not (Test-Path "build\windows\x64\runner\Release\my_leadership_quest.exe")) {
    Write-Host "ERROR: Windows build not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please build the app first:" -ForegroundColor Yellow
    Write-Host "  flutter build windows --release" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "✓ Windows build found" -ForegroundColor Green
Write-Host ""

# Get version from pubspec.yaml
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
    $version = $matches[1]
} else {
    $version = "1.0.0"
}

Write-Host "App Version: $version" -ForegroundColor Cyan
Write-Host ""

# Create output directory
if (-not (Test-Path "portable_output")) {
    New-Item -ItemType Directory -Path "portable_output" | Out-Null
    Write-Host "✓ Created portable_output directory" -ForegroundColor Green
} else {
    Write-Host "✓ Output directory exists" -ForegroundColor Green
}
Write-Host ""

# Create temporary staging directory
$stagingDir = "portable_output\staging"
if (Test-Path $stagingDir) {
    Remove-Item $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir | Out-Null

Write-Host "Preparing files..." -ForegroundColor Yellow

# Copy all files from Release folder
Copy-Item "build\windows\x64\runner\Release\*" -Destination $stagingDir -Recurse -Force

# Create README.txt
$readmeContent = @"
MY LEADERSHIP QUEST - PORTABLE VERSION
======================================

Thank you for downloading My Leadership Quest!

QUICK START:
1. Extract all files to a folder of your choice
2. Double-click my_leadership_quest.exe to launch
3. Enjoy your leadership journey!

SYSTEM REQUIREMENTS:
- Windows 10 or later (64-bit)
- 4 GB RAM minimum (8 GB recommended)
- 100 MB free disk space
- Internet connection for online features

FEATURES:
- Goal setting and tracking
- AI-powered coaching
- Challenge system with rewards
- Leaderboard and achievements
- Social victory wall
- Parent portal
- And much more!

TROUBLESHOOTING:
If the app doesn't start, you may need to install Microsoft Edge WebView2 Runtime.
Download it from: https://go.microsoft.com/fwlink/p/?LinkId=2124703

PORTABLE VERSION NOTES:
- No installation required
- All data stored in AppData folder
- Can run from USB drive
- No Start Menu shortcuts
- No automatic updates

DATA LOCATION:
User data is stored in:
C:\Users\[YourUsername]\AppData\Roaming\my_leadership_quest\

To completely remove the app:
1. Delete the app folder
2. Delete the AppData folder above

SUPPORT:
Website: https://yourwebsite.com
Email: support@yourwebsite.com

VERSION: $version
BUILD DATE: $(Get-Date -Format "MMMM dd, yyyy")

Copyright © 2026 My Leadership Quest. All rights reserved.
"@

$readmeContent | Out-File -FilePath "$stagingDir\README.txt" -Encoding UTF8

Write-Host "✓ Created README.txt" -ForegroundColor Green

# Create version info file
$versionInfo = @"
{
  "version": "$version",
  "buildDate": "$(Get-Date -Format "yyyy-MM-dd")",
  "platform": "Windows x64",
  "type": "Portable"
}
"@

$versionInfo | Out-File -FilePath "$stagingDir\version.json" -Encoding UTF8

Write-Host "✓ Created version.json" -ForegroundColor Green
Write-Host ""

# Create ZIP file
$zipFileName = "MyLeadershipQuest_Portable_v$version.zip"
$zipPath = "portable_output\$zipFileName"

Write-Host "Creating ZIP archive..." -ForegroundColor Yellow
Write-Host "This may take 1-2 minutes..." -ForegroundColor Gray
Write-Host ""

# Remove old ZIP if exists
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Create ZIP with maximum compression
Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipPath -CompressionLevel Optimal

# Clean up staging directory
Remove-Item $stagingDir -Recurse -Force

if (Test-Path $zipPath) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "   PORTABLE PACKAGE CREATED!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Get file info
    $zipFile = Get-Item $zipPath
    $sizeMB = [math]::Round($zipFile.Length / 1MB, 2)
    
    Write-Host "Package Details:" -ForegroundColor Cyan
    Write-Host "  File: $($zipFile.Name)" -ForegroundColor White
    Write-Host "  Size: $sizeMB MB" -ForegroundColor White
    Write-Host "  Location: $($zipFile.FullName)" -ForegroundColor White
    Write-Host ""
    
    # Generate SHA256 checksum
    Write-Host "Generating checksum..." -ForegroundColor Yellow
    $hash = Get-FileHash $zipPath -Algorithm SHA256
    Write-Host "  SHA256: $($hash.Hash)" -ForegroundColor White
    
    # Save checksum to file
    $checksumFile = "$zipPath.sha256"
    $hash.Hash | Out-File -FilePath $checksumFile -Encoding ASCII
    Write-Host "  Checksum saved to: $checksumFile" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "What's Included:" -ForegroundColor Cyan
    Write-Host "  ✓ Application executable" -ForegroundColor White
    Write-Host "  ✓ All required DLLs" -ForegroundColor White
    Write-Host "  ✓ Flutter assets and data" -ForegroundColor White
    Write-Host "  ✓ README.txt with instructions" -ForegroundColor White
    Write-Host "  ✓ Version information" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Test the ZIP on a clean Windows machine" -ForegroundColor White
    Write-Host "2. Upload to your website or file hosting" -ForegroundColor White
    Write-Host "3. Share the download link" -ForegroundColor White
    Write-Host ""
    
    Write-Host "To test:" -ForegroundColor Cyan
    Write-Host "1. Extract the ZIP to a test folder" -ForegroundColor White
    Write-Host "2. Run my_leadership_quest.exe" -ForegroundColor White
    Write-Host ""
    
    # Ask if user wants to open the output folder
    $response = Read-Host "Open output folder? (Y/N)"
    if ($response -eq "Y" -or $response -eq "y") {
        Start-Process "explorer.exe" -ArgumentList "portable_output"
    }
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "      PACKAGE CREATION FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check the error messages above." -ForegroundColor Yellow
    exit 1
}
