# Git Account Setup Guide

## Clear Existing Configuration and Login with Correct Account

---

## Option 1: Use PowerShell Script (Easiest)

Run this script to automatically clear and reconfigure:

```powershell
.\git_setup.ps1
```

The script will:
1. Clear existing git configuration
2. Clear stored GitHub credentials
3. Prompt for your correct account details
4. Configure git with your account

---

## Option 2: Manual Setup

### Step 1: Clear Existing Git Config

```bash
# Clear local git config (in this repository only)
git config --unset user.name
git config --unset user.email

# Optional: Clear global git config (affects all repositories)
git config --global --unset user.name
git config --global --unset user.email
```

### Step 2: Clear Stored GitHub Credentials

**Windows Credential Manager:**
1. Press `Win + R`
2. Type `control /name Microsoft.CredentialManager`
3. Click "Windows Credentials"
4. Find and remove any entries for:
   - `git:https://github.com`
   - `github.com`
5. Click "Remove"

**Or use Command Line:**
```powershell
# Remove GitHub credentials
cmdkey /delete:"git:https://github.com"
cmdkey /delete:"github.com"
```

### Step 3: Configure Your Correct Account

```bash
# Set your name
git config user.name "Your Name"

# Set your email (use your GitHub email)
git config user.email "your@email.com"
```

**Example:**
```bash
git config user.name "John Doe"
git config user.email "john@myleadershipquest.com"
```

### Step 4: Verify Configuration

```bash
# Check current config
git config user.name
git config user.email

# Or view all config
git config --list
```

---

## GitHub Authentication

### When You Push

When you run `git push origin main`, you'll be prompted to authenticate.

### Authentication Options

#### Option A: Personal Access Token (Recommended)

1. **Create a Token**:
   - Go to https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Give it a name: "My Leadership Quest Deployment"
   - Select scopes:
     - ✅ `repo` (Full control of private repositories)
   - Click "Generate token"
   - **Copy the token** (you won't see it again!)

2. **Use Token When Pushing**:
   ```bash
   git push origin main
   ```
   - Username: Your GitHub username
   - Password: Paste your Personal Access Token (not your password!)

3. **Save Token** (Optional):
   - Windows will save it in Credential Manager
   - You won't need to enter it again

#### Option B: GitHub CLI

```bash
# Install GitHub CLI
winget install GitHub.cli

# Login
gh auth login

# Follow the prompts
```

#### Option C: SSH Key

1. **Generate SSH Key**:
   ```bash
   ssh-keygen -t ed25519 -C "your@email.com"
   ```

2. **Add to GitHub**:
   - Copy the public key:
     ```bash
     cat ~/.ssh/id_ed25519.pub
     ```
   - Go to https://github.com/settings/keys
   - Click "New SSH key"
   - Paste your key

3. **Update Remote URL**:
   ```bash
   git remote set-url origin git@github.com:username/repository.git
   ```

---

## Common Issues

### Issue: "Permission denied"
**Solution**: 
- Make sure you're using the correct GitHub account
- Verify you have push access to the repository
- Check your Personal Access Token has `repo` scope

### Issue: "Authentication failed"
**Solution**:
- Clear credentials and try again
- Use Personal Access Token instead of password
- Verify your GitHub username is correct

### Issue: "Remote rejected"
**Solution**:
- Pull latest changes first:
  ```bash
  git pull origin main
  ```
- Then push again:
  ```bash
  git push origin main
  ```

---

## Quick Reference

### Clear Everything
```bash
# Clear local config
git config --unset user.name
git config --unset user.email

# Clear credentials
cmdkey /delete:"git:https://github.com"
```

### Set New Account
```bash
# Configure git
git config user.name "Your Name"
git config user.email "your@email.com"

# Verify
git config --list
```

### Push to GitHub
```bash
# Commit changes
git commit -m "Configure for Vercel deployment"

# Push (will prompt for authentication)
git push origin main
```

---

## After Authentication

Once you've authenticated successfully:

1. ✅ Your credentials will be saved
2. ✅ Future pushes won't require authentication
3. ✅ You can proceed with Vercel deployment

---

## Next Steps

After setting up your account:

1. **Commit changes**:
   ```bash
   git commit -m "Configure for Vercel deployment"
   ```

2. **Push to GitHub**:
   ```bash
   git push origin main
   ```

3. **Deploy on Vercel**:
   - Go to https://vercel.com/new
   - Import your repository
   - Click "Deploy"

---

## Support

### GitHub Help
- Personal Access Tokens: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
- SSH Keys: https://docs.github.com/en/authentication/connecting-to-github-with-ssh
- Credential Manager: https://docs.github.com/en/get-started/getting-started-with-git/caching-your-github-credentials-in-git

### Git Help
- Configuration: https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup
- Authentication: https://git-scm.com/book/en/v2/Git-Tools-Credential-Storage

---

## Summary

### To Clear and Reconfigure:

**Quick Method:**
```powershell
.\git_setup.ps1
```

**Manual Method:**
```bash
# 1. Clear config
git config --unset user.name
git config --unset user.email

# 2. Clear credentials
cmdkey /delete:"git:https://github.com"

# 3. Set new account
git config user.name "Your Name"
git config user.email "your@email.com"

# 4. Push (will prompt for authentication)
git push origin main
```

**That's it!** You'll be authenticated with the correct account. 🎉
