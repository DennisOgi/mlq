# Windows Build Script - Excludes Firebase for Desktop
# This script builds the Windows app without Firebase dependencies

Write-Host "Building My Leadership Quest for Windows (without Firebase)" -ForegroundColor Cyan
Write-Host ""

# Step 1: Clean previous build
Write-Host "Step 1: Cleaning previous build..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter clean failed" -ForegroundColor Red
    exit 1
}
Write-Host "Clean complete" -ForegroundColor Green
Write-Host ""

# Step 2: Get dependencies
Write-Host "Step 2: Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter pub get failed" -ForegroundColor Red
    exit 1
}
Write-Host "Dependencies downloaded" -ForegroundColor Green
Write-Host ""

# Step 3: Remove Firebase from generated_plugins.cmake
Write-Host "Step 3: Removing Firebase from Windows build..." -ForegroundColor Yellow
$pluginsFile = "windows\flutter\generated_plugins.cmake"

if (Test-Path $pluginsFile) {
    # Read the file
    $content = Get-Content $pluginsFile -Raw
    
    # Remove firebase_core from the plugin list
    $content = $content -replace '\s*firebase_core\s*', ''
    
    # Remove firebase_messaging if it exists
    $content = $content -replace '\s*firebase_messaging\s*', ''
    
    # Write back
    Set-Content $pluginsFile -Value $content -NoNewline
    
    Write-Host "Firebase plugins removed from Windows build" -ForegroundColor Green
    Write-Host "Modified: $pluginsFile" -ForegroundColor Gray
} else {
    Write-Host "Warning: $pluginsFile not found" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Build for Windows
Write-Host "Step 4: Building Windows executable..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Gray
Write-Host ""

flutter build windows --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Output location:" -ForegroundColor Cyan
    Write-Host "build\windows\x64\runner\Release\my_leadership_quest.exe" -ForegroundColor White
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Test the executable" -ForegroundColor White
    Write-Host "2. The app will run without push notifications on Windows" -ForegroundColor White
    Write-Host "3. All other features work normally" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "BUILD FAILED" -ForegroundColor Red
    Write-Host "Check the error messages above" -ForegroundColor Yellow
    exit 1
}
