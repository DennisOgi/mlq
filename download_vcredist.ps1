# Download Visual C++ Redistributable
# This script downloads the VC++ 2015-2022 Redistributable (x64)

$vcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
$outputPath = "vc_redist.x64.exe"

Write-Host "Downloading Visual C++ Redistributable..." -ForegroundColor Cyan
Write-Host "URL: $vcRedistUrl" -ForegroundColor Gray

try {
    # Download the file
    Invoke-WebRequest -Uri $vcRedistUrl -OutFile $outputPath -UseBasicParsing
    
    if (Test-Path $outputPath) {
        $fileSize = (Get-Item $outputPath).Length / 1MB
        Write-Host "`nDownload complete!" -ForegroundColor Green
        Write-Host "File: $outputPath" -ForegroundColor Green
        Write-Host "Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
        Write-Host "`nThis file will be included in your installer." -ForegroundColor Yellow
    }
} catch {
    Write-Host "`nError downloading VC++ Redistributable:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nPlease download manually from:" -ForegroundColor Yellow
    Write-Host $vcRedistUrl -ForegroundColor Cyan
    exit 1
}
