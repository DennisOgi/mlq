# My Leadership Quest - Windows Installation Guide

## For Users

### System Requirements
- Windows 10 (64-bit) version 1809 or later, OR Windows 11
- 4 GB RAM minimum
- 100 MB free disk space
- Internet connection for full functionality

### Installation Steps

1. Download `MyLeadershipQuest_Setup_v1.0.0.exe`
2. Double-click the installer
3. Follow the installation wizard
4. Launch the app from the Start Menu or Desktop shortcut

### Troubleshooting

#### "DLL is missing" Error

If you see an error about a missing DLL file (like VCRUNTIME140.dll or MSVCP140.dll):

**Solution 1: Install Visual C++ Redistributable**
1. Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe
2. Run the installer
3. Restart your computer
4. Try running My Leadership Quest again

**Solution 2: Update Windows**
1. Open Settings → Windows Update
2. Click "Check for updates"
3. Install all available updates
4. Restart your computer
5. Try running My Leadership Quest again

**Solution 3: Reinstall the App**
1. Uninstall My Leadership Quest
2. Download the latest installer
3. Install again
4. Try running the app

#### App Won't Start

1. Make sure you have Windows 10 version 1809 or later
2. Check if antivirus is blocking the app
3. Try running as administrator (right-click → Run as administrator)
4. Check Windows Event Viewer for error details

#### Other Issues

Contact support at: [your-support-email]

---

## For Developers

### Building the Installer

#### Prerequisites
1. Flutter SDK installed
2. Inno Setup 6 installed from: https://jrsoftware.org/isdl.php

#### Step 1: Verify DLLs
```powershell
cd my_leadership_quest
.\verify_dlls.ps1
```

This script checks:
- Main executable exists
- All DLLs are present
- Data folder is complete
- Plugin DLLs are included
- Total size estimation

#### Step 2: Build Release
```powershell
flutter clean
flutter build windows --release
```

#### Step 3: Verify Build
```powershell
.\verify_dlls.ps1
```

#### Step 4: Create Installer
```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer_config.iss
```

Output: `installer_output\MyLeadershipQuest_Setup_v1.0.0.exe`

### Including VC++ Redistributable (Recommended)

For maximum compatibility, include the VC++ Redistributable:

1. Download: https://aka.ms/vs/17/release/vc_redist.x64.exe
2. Create folder: `mkdir redist`
3. Copy `vcredist_x64.exe` to `redist\` folder
4. Uncomment lines in `installer_config.iss`:
   ```iss
   ; In [Files] section:
   Source: "redist\vcredist_x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
   
   ; In [Run] section:
   Filename: "{tmp}\vcredist_x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Installing Visual C++ Redistributables..."; Flags: waituntilterminated
   ```
5. Rebuild installer

This adds ~25 MB to installer size but ensures it works on any Windows machine.

### Testing

Test the installer on:
- [ ] Clean Windows 10 machine (VM recommended)
- [ ] Clean Windows 11 machine (VM recommended)
- [ ] Machine without VC++ Redistributables
- [ ] Machine with antivirus enabled
- [ ] Low-spec machine (4 GB RAM)

### Distribution Checklist

Before releasing:
- [ ] Version number updated in `pubspec.yaml`
- [ ] Version number updated in `installer_config.iss`
- [ ] Clean build completed
- [ ] DLLs verified with `verify_dlls.ps1`
- [ ] Installer created and tested
- [ ] Tested on clean machines
- [ ] README included with download
- [ ] Support contact provided
- [ ] Release notes prepared

### Updating the App

To release an update:

1. Update version in `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2
   ```

2. Update version in `installer_config.iss`:
   ```iss
   #define MyAppVersion "1.0.1"
   ```

3. Rebuild:
   ```powershell
   flutter clean
   flutter build windows --release
   .\verify_dlls.ps1
   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer_config.iss
   ```

4. Test the new installer

5. Distribute to users

### File Structure

```
my_leadership_quest/
├── build/
│   └── windows/
│       └── x64/
│           └── runner/
│               └── Release/          # Built app files
│                   ├── my_leadership_quest.exe
│                   ├── *.dll         # All DLLs
│                   └── data/         # Assets
├── installer_output/                 # Generated installers
│   └── MyLeadershipQuest_Setup_v1.0.0.exe
├── redist/                          # Optional
│   └── vcredist_x64.exe             # VC++ Redistributable
├── installer_config.iss             # Inno Setup script
├── verify_dlls.ps1                  # Verification script
└── DLL_FIX_GUIDE.md                 # Detailed guide
```

### Common Issues

#### "Generator mismatch" Error
```powershell
# Clean CMake cache
Remove-Item -Recurse -Force build\windows\CMakeFiles
Remove-Item build\windows\CMakeCache.txt
flutter build windows --release
```

#### DLLs Not Included
```powershell
# Ensure clean build
flutter clean
flutter pub get
flutter build windows --release
```

#### Installer Too Large
- Normal size: 25-30 MB without VC++ Redistributable
- With VC++ Redistributable: 50-55 MB
- This is expected and cannot be significantly reduced

### Support

For development issues:
- Check `DLL_FIX_GUIDE.md` for detailed troubleshooting
- Run `verify_dlls.ps1` to diagnose build issues
- Check Flutter logs: `flutter build windows --release --verbose`

---

## Quick Reference

### Build Commands
```powershell
# Clean build
flutter clean

# Build release
flutter build windows --release

# Verify DLLs
.\verify_dlls.ps1

# Create installer
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer_config.iss

# Create portable ZIP
.\create_portable_zip.ps1
```

### File Locations
- Executable: `build\windows\x64\runner\Release\my_leadership_quest.exe`
- Installer: `installer_output\MyLeadershipQuest_Setup_v1.0.0.exe`
- Portable ZIP: `installer_output\MyLeadershipQuest_Portable_v1.0.0.zip`

### Download Links
- Inno Setup: https://jrsoftware.org/isdl.php
- VC++ Redistributable: https://aka.ms/vs/17/release/vc_redist.x64.exe
- Flutter SDK: https://flutter.dev/docs/get-started/install/windows
