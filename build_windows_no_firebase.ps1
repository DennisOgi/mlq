# Script to build Windows without Firebase
Write-Host "Building Windows app without Firebase..." -ForegroundColor Green

# Backup pubspec.yaml
Copy-Item "pubspec.yaml" "pubspec.yaml.backup"

# Read pubspec and comment out Firebase dependencies
$content = Get-Content "pubspec.yaml" -Raw
$content = $content -replace '(\s+firebase_core:)', '  # $1'
$content = $content -replace '(\s+firebase_messaging:)', '  # $1'
Set-Content "pubspec.yaml" $content

# Run flutter pub get
Write-Host "Running flutter pub get..." -ForegroundColor Yellow
flutter pub get

# Build Windows
Write-Host "Building Windows release..." -ForegroundColor Yellow
flutter build windows --release

# Restore pubspec.yaml
Write-Host "Restoring pubspec.yaml..." -ForegroundColor Yellow
Move-Item "pubspec.yaml.backup" "pubspec.yaml" -Force

Write-Host "Build complete!" -ForegroundColor Green
