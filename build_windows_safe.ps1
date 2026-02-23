# Safe Windows Build Script
# Handles Firebase and problematic plugin exclusions for Windows

Write-Host "=== My Leadership Quest - Windows Build ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Clean
Write-Host "[1/5] Cleaning previous build..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "Clean failed!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Clean complete" -ForegroundColor Green
Write-Host ""

# Step 2: Get dependencies
Write-Host "[2/5] Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Pub get failed!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Dependencies downloaded" -ForegroundColor Green
Write-Host ""

# Step 3: Modify generated_plugins.cmake to remove problematic plugins
Write-Host "[3/5] Configuring Windows plugins..." -ForegroundColor Yellow
$pluginsFile = "windows\flutter\generated_plugins.cmake"

if (Test-Path $pluginsFile) {
    $content = Get-Content $pluginsFile -Raw
    
    # Remove firebase_core (not supported on Windows)
    $content = $content -replace '\s*firebase_core\s*', ''
    
    # Keep flutter_inappwebview_windows but we'll handle it
    Write-Host "  - Removed firebase_core from Windows build" -ForegroundColor Gray
    
    Set-Content $pluginsFile -Value $content -NoNewline
    Write-Host "✓ Plugin configuration updated" -ForegroundColor Green
} else {
    Write-Host "⚠ Plugin file not found yet (will be generated)" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Ensure TLS 1.2 is enabled for NuGet
Write-Host "[4/5] Configuring network security..." -ForegroundColor Yellow
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Host "✓ TLS 1.2 enabled for NuGet" -ForegroundColor Green
Write-Host ""

# Step 5: Build
Write-Host "[5/5] Building Windows application..." -ForegroundColor Yellow
Write-Host "This will take 5-10 minutes..." -ForegroundColor Gray
Write-Host ""

flutter build windows --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "         BUILD SUCCESSFUL! ✓" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Executable location:" -ForegroundColor Cyan
    Write-Host "  build\windows\x64\runner\Release\my_leadership_quest.exe" -ForegroundColor White
    Write-Host ""
    Write-Host "To run the app:" -ForegroundColor Cyan
    Write-Host "  .\build\windows\x64\runner\Release\my_leadership_quest.exe" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: Windows build runs without Firebase push notifications" -ForegroundColor Yellow
    Write-Host "      All other features work normally" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "          BUILD FAILED ✗" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Yellow
    Write-Host "1. Ensure Visual Studio 2022 is installed with C++ workload" -ForegroundColor White
    Write-Host "2. Check that nuget.exe is unblocked (right-click → Properties → Unblock)" -ForegroundColor White
    Write-Host "3. Try running as Administrator" -ForegroundColor White
    Write-Host "4. Check the error messages above for specific issues" -ForegroundColor White
    exit 1
}
