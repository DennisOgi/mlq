# Create Windows Installer using Inno Setup
# Requires Inno Setup 6.x to be installed

Write-Host "=== My Leadership Quest - Installer Creator ===" -ForegroundColor Cyan
Write-Host ""

# Check if Inno Setup is installed
$innoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
$innoSetupPath2 = "C:\Program Files\Inno Setup 6\ISCC.exe"

if (Test-Path $innoSetupPath) {
    $iscc = $innoSetupPath
} elseif (Test-Path $innoSetupPath2) {
    $iscc = $innoSetupPath2
} else {
    Write-Host "ERROR: Inno Setup not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Inno Setup 6.x from:" -ForegroundColor Yellow
    Write-Host "https://jrsoftware.org/isdl.php" -ForegroundColor White
    Write-Host ""
    Write-Host "After installation, run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found Inno Setup at: $iscc" -ForegroundColor Green
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

Write-Host "Windows build found" -ForegroundColor Green
Write-Host ""

# Check if VC++ Redistributable is downloaded
if (-not (Test-Path "vc_redist.x64.exe")) {
    Write-Host "Visual C++ Redistributable not found!" -ForegroundColor Yellow
    Write-Host "Downloading now..." -ForegroundColor Cyan
    Write-Host ""
    
    # Download VC++ Redistributable
    $vcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    try {
        Invoke-WebRequest -Uri $vcRedistUrl -OutFile "vc_redist.x64.exe" -UseBasicParsing
        Write-Host "VC++ Redistributable downloaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to download VC++ Redistributable" -ForegroundColor Red
        Write-Host "Please download manually from: $vcRedistUrl" -ForegroundColor Yellow
        Write-Host "Save it as 'vc_redist.x64.exe' in the project root" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "VC++ Redistributable found" -ForegroundColor Green
}
Write-Host ""

# Check if installer script exists
if (-not (Test-Path "installer_setup.iss")) {
    Write-Host "ERROR: installer_setup.iss not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure installer_setup.iss is in the project root." -ForegroundColor Yellow
    exit 1
}

Write-Host "Installer script found" -ForegroundColor Green
Write-Host ""

# Create output directory
if (-not (Test-Path "installer_output")) {
    New-Item -ItemType Directory -Path "installer_output" | Out-Null
    Write-Host "Created installer_output directory" -ForegroundColor Green
} else {
    Write-Host "Output directory exists" -ForegroundColor Green
}
Write-Host ""

# Compile installer
Write-Host "Building installer..." -ForegroundColor Yellow
Write-Host "This may take 2-3 minutes..." -ForegroundColor Gray
Write-Host ""

& $iscc "installer_setup.iss"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "    INSTALLER CREATED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Get installer file info
    $installerFile = Get-ChildItem "installer_output\*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if ($installerFile) {
        $sizeMB = [math]::Round($installerFile.Length / 1MB, 2)
        
        Write-Host "Installer Details:" -ForegroundColor Cyan
        Write-Host "  File: $($installerFile.Name)" -ForegroundColor White
        Write-Host "  Size: $sizeMB MB" -ForegroundColor White
        Write-Host "  Location: $($installerFile.FullName)" -ForegroundColor White
        Write-Host ""
        
        # Generate SHA256 checksum
        Write-Host "Generating checksum..." -ForegroundColor Yellow
        $hash = Get-FileHash $installerFile.FullName -Algorithm SHA256
        Write-Host "  SHA256: $($hash.Hash)" -ForegroundColor White
        
        # Save checksum to file
        $checksumFile = "$($installerFile.FullName).sha256"
        $hash.Hash | Out-File -FilePath $checksumFile -Encoding ASCII
        Write-Host "  Checksum saved to: $checksumFile" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "Next Steps:" -ForegroundColor Cyan
        Write-Host "1. Test the installer on a clean Windows machine" -ForegroundColor White
        Write-Host "2. Upload to your website or GitHub Releases" -ForegroundColor White
        Write-Host "3. Share the download link with users" -ForegroundColor White
        Write-Host ""
        
        Write-Host "To test the installer:" -ForegroundColor Cyan
        Write-Host "  .\installer_output\$($installerFile.Name)" -ForegroundColor White
        Write-Host ""
        
        # Ask if user wants to open the output folder
        $response = Read-Host "Open installer folder? (Y/N)"
        if ($response -eq "Y" -or $response -eq "y") {
            Start-Process "explorer.exe" -ArgumentList "installer_output"
        }
    }
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "       INSTALLER BUILD FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check the error messages above." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "- Missing files in build directory" -ForegroundColor White
    Write-Host "- Syntax errors in installer_setup.iss" -ForegroundColor White
    Write-Host "- Insufficient disk space" -ForegroundColor White
    exit 1
}
