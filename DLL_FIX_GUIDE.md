# Windows DLL Missing Error - Complete Fix Guide

## Problem
Windows installer throws "DLL is missing" error when users try to run the application on their computers.

## Root Cause
The application requires Visual C++ Runtime libraries that may not be installed on the user's system.

## Solution Overview
We've implemented a multi-layered approach:
1. Bundle all DLLs from the build with the installer
2. Check for VC++ Redistributables during installation
3. Provide clear instructions if dependencies are missing
4. Optional: Include VC++ Redistributable installer

---

## Quick Fix - Rebuild and Reinstall

### Step 1: Clean Build
```powershell
cd my_leadership_quest
flutter clean
flutter build windows --release
```

### Step 2: Verify DLLs are Present
Check that these files exist in `build\windows\x64\runner\Release\`:
- `my_leadership_quest.exe`
- `flutter_windows.dll`
- `url_launcher_windows_plugin.dll`
- `file_selector_windows_plugin.dll`
- Other plugin DLLs
- `data\` folder with assets

### Step 3: Create Installer
```powershell
# Using Inno Setup
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer_config.iss
```

The installer will now:
- ✓ Bundle ALL DLLs from the Release folder
- ✓ Check if VC++ Redistributables are installed
- ✓ Show helpful message if dependencies are missing
- ✓ Include all necessary files

---

## Advanced Fix - Include VC++ Redistributable

For a completely self-contained installer that works on ANY Windows machine:

### Step 1: Download VC++ Redistributable
Download from Microsoft:
https://aka.ms/vs/17/release/vc_redist.x64.exe

### Step 2: Create Redist Folder
```powershell
mkdir redist
# Copy the downloaded vcredist_x64.exe to the redist folder
```

### Step 3: Update Installer Config
In `installer_config.iss`, uncomment these lines:

```iss
; In [Files] section:
Source: "redist\vcredist_x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

; In [Run] section:
Filename: "{tmp}\vcredist_x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Installing Visual C++ Redistributables..."; Flags: waituntilterminated
```

### Step 4: Rebuild Installer
```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer_config.iss
```

Now the installer will automatically install VC++ Redistributables if needed!

---

## Testing the Fix

### Test on Clean Machine
1. Use a virtual machine or clean Windows installation
2. Install your app
3. Run the application
4. Verify no DLL errors appear

### Test Without VC++ Redistributables
1. On a test machine, uninstall VC++ Redistributables
2. Install your app
3. Should either work (if DLLs bundled) or show helpful message

---

## Common DLL Errors and Solutions

### Error: "VCRUNTIME140.dll is missing"
**Solution**: Install VC++ 2015-2022 Redistributable (x64)
- Download: https://aka.ms/vs/17/release/vc_redist.x64.exe
- Or include in installer (see Advanced Fix above)

### Error: "MSVCP140.dll is missing"
**Solution**: Same as above - VC++ Redistributable

### Error: "flutter_windows.dll is missing"
**Solution**: Rebuild the app and ensure DLLs are bundled
```powershell
flutter clean
flutter build windows --release
```

### Error: "api-ms-win-*.dll is missing"
**Solution**: Update Windows or install VC++ Redistributable

---

## Distribution Checklist

Before distributing to users:

- [ ] Clean build completed
- [ ] All DLLs present in Release folder
- [ ] Installer created with updated config
- [ ] Tested on clean Windows 10 machine
- [ ] Tested on clean Windows 11 machine
- [ ] VC++ Redistributable included (optional but recommended)
- [ ] README includes system requirements
- [ ] Support contact provided

---

## System Requirements to Include

Add this to your distribution:

**Minimum Requirements:**
- Windows 10 (64-bit) version 1809 or later
- 4 GB RAM
- 100 MB free disk space
- Internet connection for full functionality
- Microsoft Visual C++ 2015-2022 Redistributable (x64)
  - Automatically installed by installer OR
  - Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe

---

## Troubleshooting for Users

If users still get DLL errors after installation:

### Option 1: Install VC++ Redistributable Manually
1. Download: https://aka.ms/vs/17/release/vc_redist.x64.exe
2. Run the installer
3. Restart computer
4. Try running the app again

### Option 2: Update Windows
1. Open Windows Update
2. Install all available updates
3. Restart computer
4. Try running the app again

### Option 3: Reinstall the App
1. Uninstall My Leadership Quest
2. Download the latest installer
3. Install again
4. Try running the app

---

## For Developers

### Check What DLLs Your App Needs
```powershell
# Use Dependency Walker or similar tool
# Or check with dumpbin (Visual Studio tool)
dumpbin /dependents build\windows\x64\runner\Release\my_leadership_quest.exe
```

### Verify DLLs are Bundled
```powershell
# List all DLLs in Release folder
Get-ChildItem build\windows\x64\runner\Release\*.dll
```

### Test Installer Contents
```powershell
# Extract installer to see what's included
# Or check the installer log after installation
```

---

## Summary

The updated installer now:
1. ✓ Bundles all DLLs from the build
2. ✓ Checks for VC++ Redistributables
3. ✓ Shows helpful error messages
4. ✓ Can optionally install VC++ Redistributables
5. ✓ Works on clean Windows installations

This should fix DLL errors for all users!
