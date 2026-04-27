# Build Web Version - My Leadership Quest
# This script builds the Flutter web app for production deployment

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building My Leadership Quest - Web Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
Write-Host "Checking Flutter installation..." -ForegroundColor Yellow
$flutterVersion = flutter --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}
Write-Host "Flutter found!" -ForegroundColor Green
Write-Host ""

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
flutter clean
Write-Host ""

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get
Write-Host ""

# Build for web (release mode)
Write-Host "Building web app (release mode)..." -ForegroundColor Yellow
Write-Host "This may take a few minutes..." -ForegroundColor Gray
Write-Host ""

# Build with auto renderer (Flutter decides best option)
flutter build web --release --web-renderer auto

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Output location: build/web/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Test locally: python -m http.server 8000 (in build/web folder)" -ForegroundColor White
    Write-Host "2. Deploy to hosting provider (see WEB_DEPLOYMENT_GUIDE.md)" -ForegroundColor White
    Write-Host "3. Update Supabase CORS settings with your domain" -ForegroundColor White
    Write-Host "4. Update Flutterwave redirect URL" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "BUILD FAILED!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check the error messages above for details." -ForegroundColor Yellow
    exit 1
}
