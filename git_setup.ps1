# Git Account Setup Script
# This script helps you configure git with the correct account

Write-Host "=== Git Account Setup ===" -ForegroundColor Cyan
Write-Host ""

# Clear existing git credentials
Write-Host "Clearing existing git configuration..." -ForegroundColor Yellow

# Remove local git config
git config --unset user.name 2>$null
git config --unset user.email 2>$null

# Remove global git config (optional - uncomment if needed)
# git config --global --unset user.name 2>$null
# git config --global --unset user.email 2>$null

Write-Host "✓ Git configuration cleared" -ForegroundColor Green
Write-Host ""

# Clear Windows Credential Manager (GitHub credentials)
Write-Host "Clearing stored GitHub credentials..." -ForegroundColor Yellow
try {
    # Remove GitHub credentials from Windows Credential Manager
    cmdkey /list | Select-String "git:" | ForEach-Object {
        $target = $_.Line.Split(":")[1].Trim()
        cmdkey /delete:$target 2>$null
    }
    
    # Also try common GitHub credential names
    cmdkey /delete:"git:https://github.com" 2>$null
    cmdkey /delete:"github.com" 2>$null
    
    Write-Host "✓ Credentials cleared from Windows Credential Manager" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not clear all credentials (this is usually fine)" -ForegroundColor Yellow
}
Write-Host ""

# Prompt for new account details
Write-Host "=== Configure Your Git Account ===" -ForegroundColor Cyan
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
Write-Host "=== Configuration Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Current git configuration:" -ForegroundColor Cyan
Write-Host "  Name: $(git config user.name)" -ForegroundColor White
Write-Host "  Email: $(git config user.email)" -ForegroundColor White
Write-Host ""

# Ask if user wants to set global config
$setGlobal = Read-Host "Do you want to set this as your global git config? (y/n)"
if ($setGlobal -eq 'y' -or $setGlobal -eq 'Y') {
    git config --global user.name "$userName"
    git config --global user.email "$userEmail"
    Write-Host "✓ Global git config updated" -ForegroundColor Green
    Write-Host ""
}

Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. When you push to GitHub, you'll be prompted to authenticate" -ForegroundColor White
Write-Host "2. Use your GitHub username and Personal Access Token (not password)" -ForegroundColor White
Write-Host "3. To create a token: https://github.com/settings/tokens" -ForegroundColor White
Write-Host ""
Write-Host "Ready to commit and push? Run:" -ForegroundColor Yellow
Write-Host "  git commit -m 'Configure for Vercel deployment'" -ForegroundColor White
Write-Host "  git push origin main" -ForegroundColor White
Write-Host ""

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
