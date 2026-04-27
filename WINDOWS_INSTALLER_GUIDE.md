# Windows Installer & Distribution Guide

## Status: COMPLETE ✓

### App Icon Fixed ✓
The app icon has been updated to use your custom icon instead of the Flutter logo.

### Portable ZIP Package Created ✓
- File: `installer_output/MyLeadershipQuest_Portable_v1.0.0.zip`
- Size: 41.53 MB
- Ready for distribution!

## Distribution Options

### Option 1: Portable ZIP Package (Easiest - No Installation Required)

**Create the package:**
```powershell
.\create_portable_zip.ps1
```

**Output:**
- File: `installer_output/MyLeadershipQuest_Portable_v1.0.0.zip`
- Size: ~25-30 MB
- Users extract and run - no installation needed

**Advantages:**
- ✓ No installation required
- ✓ Can run from USB drive
- ✓ Easy to distribute
- ✓ No admin rights needed

### Option 2: Inno Setup Installer (Professional)

**Requirements:**
1. Download and install Inno Setup: https://jrsoftware.org/isdl.php
2. Install to default location

**Create the installer:**
```powershell
# After installing Inno Setup
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer_config.iss
```

**Output:**
- File: `installer_output/MyLeadershipQuest_Setup_v1.0.0.exe`
- Size: ~25-30 MB
- Professional Windows installer

**Advantages:**
- ✓ Professional installation experience
- ✓ Start menu shortcuts
- ✓ Desktop icon option
- ✓ Proper uninstaller
- ✓ Windows integration

### Option 3: MSIX Package (Microsoft Store)

For Microsoft Store distribution, you'll need:
1. Microsoft Partner Center account
2. App certification
3. MSIX packaging

**Create MSIX:**
```powershell
flutter build windows --release
# Then use Windows App Certification Kit
```

## Rebuild with New Icon

Since we updated the icon, rebuild the app:

```powershell
# Clean previous build
flutter clean

# Rebuild with new icon
flutter build windows --release
```

The new build will include your custom app icon!

## Quick Start - Create Portable Package Now

Run this command to create a distributable ZIP:

```powershell
.\create_portable_zip.ps1
```

This creates a ZIP file in `installer_output/` that you can:
- Email to users
- Upload to your website
- Share via cloud storage
- Distribute on USB drives

## File Locations

After building:
- **Executable**: `build\windows\x64\runner\Release\my_leadership_quest.exe`
- **Portable ZIP**: `installer_output\MyLeadershipQuest_Portable_v1.0.0.zip`
- **Installer** (if using Inno Setup): `installer_output\MyLeadershipQuest_Setup_v1.0.0.exe`

## Distribution Checklist

Before distributing:
- [ ] Test the app on a clean Windows machine
- [ ] Verify icon appears correctly
- [ ] Check all features work
- [ ] Test on Windows 10 and 11
- [ ] Include README with system requirements
- [ ] Provide support contact information

## System Requirements

Include these in your distribution:
- Windows 10 (64-bit) or later
- 4 GB RAM minimum
- 100 MB free disk space
- Internet connection for full functionality

## Updating the App

To release updates:
1. Update version in `pubspec.yaml`
2. Update version in `installer_config.iss`
3. Update version in `create_portable_zip.ps1`
4. Rebuild: `flutter build windows --release`
5. Create new package
6. Distribute to users

## Troubleshooting

**Icon not showing:**
- Rebuild after copying icon: `flutter clean && flutter build windows --release`
- Clear icon cache: Restart Windows Explorer

**Installer fails:**
- Check Inno Setup is installed
- Verify paths in installer_config.iss
- Run as administrator if needed

**ZIP too large:**
- This is normal (~25-30 MB)
- Includes Flutter runtime and all dependencies
- Cannot be reduced significantly

## Next Steps

1. Rebuild the app with new icon
2. Create portable ZIP package
3. Test on another computer
4. Distribute to users!
