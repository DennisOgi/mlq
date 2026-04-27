# Serve Web App Locally - My Leadership Quest
# This script serves the built web app on localhost for testing

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Local Web Server - My Leadership Quest" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if build/web exists
if (-not (Test-Path "build/web")) {
    Write-Host "ERROR: build/web folder not found!" -ForegroundColor Red
    Write-Host "Please run build_web.ps1 first to build the app." -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Would you like to build now? (y/n)"
    if ($response -eq "y" -or $response -eq "Y") {
        .\build_web.ps1
        if ($LASTEXITCODE -ne 0) {
            exit 1
        }
    } else {
        exit 1
    }
}

Write-Host "Starting local web server..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Server will be available at:" -ForegroundColor Green
Write-Host "  http://localhost:8000" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""

# Change to build/web directory and start server
Set-Location build/web

# Try Python 3 first, then Python 2
try {
    python -m http.server 8000
} catch {
    try {
        python -m SimpleHTTPServer 8000
    } catch {
        Write-Host ""
        Write-Host "ERROR: Python is not installed or not in PATH" -ForegroundColor Red
        Write-Host "Please install Python or use another method to serve the files." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Alternative: Use 'flutter run -d chrome' to test without building" -ForegroundColor Cyan
        Set-Location ../..
        exit 1
    }
}

# Return to original directory when server stops
Set-Location ../..
