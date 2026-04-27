# Git Configuration and Push Script for Vercel Deployment
# Run this script to configure git and push to repository

Write-Host "=== Git Configuration and Push Script ===" -ForegroundColor Cyan
Write-Host ""

# Check if git is configured
$gitUserName = git config user.name
$gitUserEmail = git config user.email

if (-not $gitUserName -or -not $gitUserEmail) {
    Write-Host "Git user not configured. Please enter your details:" -ForegroundColor Yellow
    Write-Host ""
    
    # Get user name
    $userName = Read-Host "Enter your name (e.g., John Doe)"
    if ($userName) {
        git config user.name "$userName"
        Write-Host "✓ Git user name set to: $userName" -ForegroundColor Green
    }
    
    # Get user email
    $userEmail = Read-Host "Enter your email (e.g., john@example.com)"
    if ($userEmail) {
        git config user.email "$userEmail"
        Write-Host "✓ Git user email set to: $userEmail" -ForegroundColor Green
    }
    
    Write-Host ""
}
else {
    Write-Host "✓ Git already configured:" -ForegroundColor Green
    Write-Host "  Name: $gitUserName"
    Write-Host "  Email: $gitUserEmail"
    Write-Host ""
}

# Show current status
Write-Host "Current git status:" -ForegroundColor Cyan
git status --short
Write-Host ""

# Confirm push
$confirm = Read-Host "Do you want to commit and push these changes? (y/n)"

if ($confirm -eq 'y' -or $confirm -eq 'Y') {
    Write-Host ""
    Write-Host "Committing changes..." -ForegroundColor Cyan
    
    git commit -m "Configure app for Vercel deployment with web optimizations

- Add vercel.json with build configuration and routing
- Add .vercelignore to exclude unnecessary files
- Update .gitignore for Vercel-specific files
- Apply web optimization fixes:
  * Cache service now uses SharedPreferences on web
  * Image picker fixed for web (uses readAsBytes)
  * Responsive design already implemented
- Add comprehensive deployment documentation
- Ready for Vercel deployment with automatic builds"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Changes committed successfully!" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "Pushing to remote repository..." -ForegroundColor Cyan
        git push origin main
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "✓ SUCCESS! Changes pushed to repository" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "Next Steps:" -ForegroundColor Cyan
            Write-Host "1. Go to https://vercel.com/new" -ForegroundColor White
            Write-Host "2. Click 'Import Project'" -ForegroundColor White
            Write-Host "3. Select your GitHub repository" -ForegroundColor White
            Write-Host "4. Vercel will auto-detect the configuration" -ForegroundColor White
            Write-Host "5. Click 'Deploy'" -ForegroundColor White
            Write-Host ""
            Write-Host "Your app will be live in minutes! 🚀" -ForegroundColor Green
        }
        else {
            Write-Host ""
            Write-Host "❌ Push failed. Please check your internet connection and try again." -ForegroundColor Red
            Write-Host ""
            Write-Host "You can manually push with:" -ForegroundColor Yellow
            Write-Host "  git push origin main" -ForegroundColor White
        }
    }
    else {
        Write-Host ""
        Write-Host "❌ Commit failed. Please check the error message above." -ForegroundColor Red
    }
}
else {
    Write-Host ""
    Write-Host "Push cancelled. You can commit and push manually later with:" -ForegroundColor Yellow
    Write-Host "  git commit -m 'Your commit message'" -ForegroundColor White
    Write-Host "  git push origin main" -ForegroundColor White
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
