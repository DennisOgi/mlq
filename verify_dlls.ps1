# PowerShell Script to Verify DLLs and Dependencies
# Run this before creating the installer

Write-Host "=== My Leadership Quest - DLL Verification ===" -ForegroundColor Cyan
Write-Host ""

$releasePath = "build\windows\x64\runner\Release"

# Check if Release folder exists
if (-not (Test-Path $releasePath)) {
    Write-Host "ERROR: Release folder not found!" -ForegroundColor Red
    Write-Host "Please run: flutter build windows --release" -ForegroundColor Yellow
    exit 1
}

Write-Host "Checking Release folder: $releasePath" -ForegroundColor Green
Write-Host ""

# Check for main executable
$exePath = Join-Path $releasePath "my_leadership_quest.exe"
if (Test-Path $exePath) {
    $exeSize = (Get-Item $exePath).Length / 1MB
    Write-Host "[OK] Main executable found: my_leadership_quest.exe ($([math]::Round($exeSize, 2)) MB)" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Main executable not found!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== DLL Files ===" -ForegroundColor Cyan

# List all DLLs
$dlls = Get-ChildItem -Path $releasePath -Filter "*.dll"
if ($dlls.Count -eq 0) {
    Write-Host "[WARNING] No DLL files found!" -ForegroundColor Yellow
    Write-Host "This might cause issues. Rebuild with: flutter clean && flutter build windows --release" -ForegroundColor Yellow
} else {
    Write-Host "Found $($dlls.Count) DLL files:" -ForegroundColor Green
    foreach ($dll in $dlls) {
        $size = $dll.Length / 1KB
        Write-Host "  - $($dll.Name) ($([math]::Round($size, 2)) KB)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "=== Data Folder ===" -ForegroundColor Cyan

# Check data folder
$dataPath = Join-Path $releasePath "data"
if (Test-Path $dataPath) {
    $dataFiles = Get-ChildItem -Path $dataPath -Recurse -File
    $dataSize = ($dataFiles | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "[OK] Data folder found with $($dataFiles.Count) files ($([math]::Round($dataSize, 2)) MB)" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Data folder not found!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Required DLLs Check ===" -ForegroundColor Cyan

# Check for critical Flutter DLLs
$requiredDlls = @(
    "flutter_windows.dll"
)

$allFound = $true
foreach ($requiredDll in $requiredDlls) {
    $dllPath = Join-Path $releasePath $requiredDll
    if (Test-Path $dllPath) {
        Write-Host "[OK] $requiredDll found" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] $requiredDll NOT found!" -ForegroundColor Red
        $allFound = $false
    }
}

Write-Host ""
Write-Host "=== Plugin DLLs ===" -ForegroundColor Cyan

# Check for plugin DLLs
$pluginDlls = Get-ChildItem -Path $releasePath -Filter "*_plugin.dll"
if ($pluginDlls.Count -gt 0) {
    Write-Host "Found $($pluginDlls.Count) plugin DLLs:" -ForegroundColor Green
    foreach ($plugin in $pluginDlls) {
        Write-Host "  - $($plugin.Name)" -ForegroundColor White
    }
} else {
    Write-Host "[INFO] No plugin DLLs found (this is OK if you don't use plugins)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Total Size ===" -ForegroundColor Cyan

# Calculate total size
$allFiles = Get-ChildItem -Path $releasePath -Recurse -File
$totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "Total Release folder size: $([math]::Round($totalSize, 2)) MB" -ForegroundColor White
Write-Host "Estimated installer size: $([math]::Round($totalSize * 0.7, 2)) MB (with compression)" -ForegroundColor White

Write-Host ""
Write-Host "=== VC++ Redistributable Check ===" -ForegroundColor Cyan

# Check if VC++ Redistributable is available
$vcRedistPath = "redist\vcredist_x64.exe"
if (Test-Path $vcRedistPath) {
    $vcSize = (Get-Item $vcRedistPath).Length / 1MB
    Write-Host "[OK] VC++ Redistributable found: $vcRedistPath ($([math]::Round($vcSize, 2)) MB)" -ForegroundColor Green
    Write-Host "     Installer will include VC++ Redistributable" -ForegroundColor Green
} else {
    Write-Host "[INFO] VC++ Redistributable not found in redist folder" -ForegroundColor Yellow
    Write-Host "       Installer will check for VC++ on user's system" -ForegroundColor Yellow
    Write-Host "       To include it, download from:" -ForegroundColor Yellow
    Write-Host "       https://aka.ms/vs/17/release/vc_redist.x64.exe" -ForegroundColor Cyan
    Write-Host "       And place in: redist\vcredist_x64.exe" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan

if ($allFound) {
    Write-Host "[SUCCESS] All required files found!" -ForegroundColor Green
    Write-Host "You can now create the installer with:" -ForegroundColor White
    Write-Host '& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer_config.iss' -ForegroundColor Cyan
} else {
    Write-Host "[ERROR] Some required files are missing!" -ForegroundColor Red
    Write-Host "Please rebuild with: flutter clean && flutter build windows --release" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Recommendations ===" -ForegroundColor Cyan
Write-Host "1. Test the installer on a clean Windows machine" -ForegroundColor White
Write-Host "2. Consider including VC++ Redistributable for better compatibility" -ForegroundColor White
Write-Host "3. Test on both Windows 10 and Windows 11" -ForegroundColor White
Write-Host "4. Provide system requirements to users" -ForegroundColor White

Write-Host ""
