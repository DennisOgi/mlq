# PowerShell Script to Download Visual C++ Redistributable
# This ensures the installer includes all necessary runtime files

Write-Host "=== Downloading Visual C++ Redistributable ===" -ForegroundColor Cyan
Write-Host ""

# Create redist folder if it doesn't exist
$redistFolder = "redist"
if (-not (Test-Path $redistFolder)) {
    Write-Host "Creating redist folder..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $redistFolder | Out-Null
}

# Download URL
$vcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
$outputPath = Join-Path $redistFolder "vcredist_x64.exe"

# Check if already downloaded
if (Test-Path $outputPath) {
    $fileSize = (Get-Item $outputPath).Length / 1MB
    Write-Host "[INFO] VC++ Redistributable already exists" -ForegroundColor Green
    Write-Host "       File: $outputPath" -ForegroundColor White
    Write-Host "       Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor White
    Write-Host ""
    
    $response = Read-Host "Do you want to re-download? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "Using existing file." -ForegroundColor Green
        exit 0
    }
    
    Write-Host "Deleting existing file..." -ForegroundColor Yellow
    Remove-Item $outputPath -Force
}

Write-Host "Downloading from: $vcRedistUrl" -ForegroundColor White
Write-Host "Saving to: $outputPath" -ForegroundColor White
Write-Host ""
Write-Host "This may take a few minutes (file is ~25 MB)..." -ForegroundColor Yellow
Write-Host ""

try {
    # Download with progress
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $vcRedistUrl -OutFile $outputPath -UseBasicParsing
    $ProgressPreference = 'Continue'
    
    # Verify download
    if (Test-Path $outputPath) {
        $fileSize = (Get-Item $outputPath).Length / 1MB
        Write-Host ""
        Write-Host "[SUCCESS] Download complete!" -ForegroundColor Green
        Write-Host "          File: $outputPath" -ForegroundColor White
        Write-Host "          Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor White
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. The installer will now include VC++ Redistributable" -ForegroundColor White
        Write-Host "2. Rebuild the installer:" -ForegroundColor White
        Write-Host '   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer_config.iss' -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host "[ERROR] Download failed - file not found" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "[ERROR] Download failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual download:" -ForegroundColor Yellow
    Write-Host "1. Open browser and go to: $vcRedistUrl" -ForegroundColor White
    Write-Host "2. Save file as: $outputPath" -ForegroundColor White
    exit 1
}
