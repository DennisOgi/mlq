# Windows Build Script - With Network Retry
# Handles network issues when downloading dependencies

Write-Host "🚀 Building My Leadership Quest for Windows (with network retry)" -ForegroundColor Cyan
Write-Host ""

# Configuration
$maxRetries = 3
$retryDelay = 5

# Step 1: Clean previous build
Write-Host "Step 1: Cleaning previous build..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter clean failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Clean complete" -ForegroundColor Green
Write-Host ""

# Step 2: Get dependencies with retry
Write-Host "Step 2: Getting dependencies (with retry)..." -ForegroundColor Yellow
$attempt = 1
$success = $false

while ($attempt -le $maxRetries -and -not $success) {
    if ($attempt -gt 1) {
        Write-Host "   Retry attempt $attempt of $maxRetries..." -ForegroundColor Yellow
        Start-Sleep -Seconds $retryDelay
    }
    
    flutter pub get
    
    if ($LASTEXITCODE -eq 0) {
        $success = $true
        Write-Host "✅ Dependencies downloaded" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Attempt $attempt failed" -ForegroundColor Yellow
        $attempt++
    }
}

if (-not $success) {
    Write-Host ""
    Write-Host "❌ Failed to download dependencies after $maxRetries attempts" -ForegroundColor Red
    Write-Host ""
    Write-Host "This is likely a network issue. Try:" -ForegroundColor Yellow
    Write-Host "  1. Check your internet connection" -ForegroundColor White
    Write-Host "  2. Try again in a few minutes" -ForegroundColor White
    Write-Host "  3. Use a VPN if dl.google.com is blocked" -ForegroundColor White
    Write-Host "  4. Run: flutter pub get --verbose (to see detailed errors)" -ForegroundColor White
    exit 1
}
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
    
    Write-Host "✅ Firebase plugins removed from Windows build" -ForegroundColor Green
    Write-Host "   Modified: $pluginsFile" -ForegroundColor Gray
} else {
    Write-Host "⚠️  Warning: $pluginsFile not found" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Build for Windows with retry
Write-Host "Step 4: Building Windows executable (with retry)..." -ForegroundColor Yellow
Write-Host "   This may take several minutes..." -ForegroundColor Gray
Write-Host ""

$attempt = 1
$success = $false

while ($attempt -le $maxRetries -and -not $success) {
    if ($attempt -gt 1) {
        Write-Host "   Build retry attempt $attempt of $maxRetries..." -ForegroundColor Yellow
        Start-Sleep -Seconds $retryDelay
    }
    
    flutter build windows --release
    
    if ($LASTEXITCODE -eq 0) {
        $success = $true
    } else {
        Write-Host "⚠️  Build attempt $attempt failed" -ForegroundColor Yellow
        $attempt++
    }
}

if ($success) {
    Write-Host ""
    Write-Host "✅ BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📦 Output location:" -ForegroundColor Cyan
    Write-Host "   build\windows\x64\runner\Release\my_leadership_quest.exe" -ForegroundColor White
    Write-Host ""
    Write-Host "🎯 Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Test the executable" -ForegroundColor White
    Write-Host "   2. The app will run without push notifications on Windows" -ForegroundColor White
    Write-Host "   3. All other features work normally" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "❌ BUILD FAILED after $maxRetries attempts" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check the error messages above" -ForegroundColor White
    Write-Host "  2. Ensure Visual Studio Build Tools are installed" -ForegroundColor White
    Write-Host "  3. Try running: flutter doctor -v" -ForegroundColor White
    Write-Host "  4. Check network connectivity to dl.google.com" -ForegroundColor White
    exit 1
}
