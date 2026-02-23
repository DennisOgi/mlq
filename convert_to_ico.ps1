# Convert PNG to ICO using .NET
# This creates a simple ICO file from your PNG

Write-Host "Converting PNG to ICO..." -ForegroundColor Cyan

$pngPath = "assets\images\questor 9.png"
$icoPath = "assets\images\app_icon.ico"

if (-not (Test-Path $pngPath)) {
    Write-Host "ERROR: PNG file not found at $pngPath" -ForegroundColor Red
    exit 1
}

try {
    # Load the PNG image
    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile((Resolve-Path $pngPath))
    
    # Create a bitmap at 256x256 (standard icon size)
    $size = 256
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($img, 0, 0, $size, $size)
    
    # Save as ICO
    $icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
    $fileStream = [System.IO.File]::Create((Resolve-Path .).Path + "\$icoPath")
    $icon.Save($fileStream)
    $fileStream.Close()
    
    # Cleanup
    $graphics.Dispose()
    $bitmap.Dispose()
    $img.Dispose()
    
    Write-Host ""
    Write-Host "SUCCESS! ICO file created:" -ForegroundColor Green
    Write-Host "  $icoPath" -ForegroundColor White
    Write-Host ""
    Write-Host "You can now run the installer script again." -ForegroundColor Cyan
    
} catch {
    Write-Host ""
    Write-Host "ERROR: Conversion failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Use an online converter:" -ForegroundColor Cyan
    Write-Host "  1. Go to https://convertio.co/png-ico/" -ForegroundColor White
    Write-Host "  2. Upload your PNG file" -ForegroundColor White
    Write-Host "  3. Download the ICO file" -ForegroundColor White
    Write-Host "  4. Save as assets\images\app_icon.ico" -ForegroundColor White
    exit 1
}
