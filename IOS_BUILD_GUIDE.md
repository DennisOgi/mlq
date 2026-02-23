# iOS Build Guide for My Leadership Quest

## Prerequisites

### You Need Access to a Mac
iOS apps can **only** be built on macOS due to Apple's requirements. Choose one option:

1. **Own/Borrow a Mac** - MacBook, iMac, Mac Mini, or Mac Studio
2. **Cloud Mac Service** - MacStadium ($30-50/month) or MacinCloud
3. **CI/CD Service** - Codemagic.io (500 free build minutes/month)

### Required Accounts
- **Apple Developer Account** - $99/year (required for App Store)
- **Apple ID** - Free (for development/testing only)

---

## Step 1: Set Up Mac Development Environment

### Install Xcode
```bash
# Download Xcode from Mac App Store (12+ GB, takes 30-60 minutes)
# After installation, accept license and install command line tools:
sudo xcodebuild -license accept
xcode-select --install
```

### Install Flutter (if not already installed)
```bash
# Download Flutter SDK
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Add to ~/.zshrc or ~/.bash_profile permanently:
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc

# Verify installation
flutter doctor
```

### Install CocoaPods
```bash
# CocoaPods manages iOS dependencies
sudo gem install cocoapods

# If you get permission errors, use:
sudo gem install -n /usr/local/bin cocoapods
```

---

## Step 2: Transfer Project to Mac

### Option A: Using Git (Recommended)
```bash
# Clone your repository
git clone <your-repo-url>
cd my_leadership_quest

# Install dependencies
flutter pub get
cd ios
pod install
cd ..
```

### Option B: Manual Transfer
1. Copy entire `my_leadership_quest` folder to Mac via:
   - USB drive
   - Cloud storage (Google Drive, Dropbox)
   - AirDrop (if you have another Apple device)
2. On Mac, run:
```bash
cd my_leadership_quest
flutter pub get
cd ios
pod install
cd ..
```

---

## Step 3: Configure iOS Project

### Update Info.plist with Required Permissions

Add these permissions to `ios/Runner/Info.plist` (before the closing `</dict>` tag):

```xml
<!-- Camera access for photo uploads -->
<key>NSCameraUsageDescription</key>
<string>My Leadership Quest needs camera access to let you share your achievements on the Victory Wall</string>

<!-- Photo library access -->
<key>NSPhotoLibraryUsageDescription</key>
<string>My Leadership Quest needs photo library access to let you upload images</string>

<!-- Microphone for video recording (if needed) -->
<key>NSMicrophoneUsageDescription</key>
<string>My Leadership Quest needs microphone access for video recording</string>

<!-- Internet access description (informational) -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>

<!-- Minimum iOS version -->
<key>MinimumOSVersion</key>
<string>12.0</string>
```

### Open Project in Xcode
```bash
# Always open the .xcworkspace file, NOT .xcodeproj
open ios/Runner.xcworkspace
```

### Configure Signing in Xcode

1. In Xcode, select **Runner** in the left sidebar
2. Select **Runner** target under TARGETS
3. Go to **Signing & Capabilities** tab
4. **Team**: Select your Apple Developer team
   - If you don't see your team, add your Apple ID in Xcode > Preferences > Accounts
5. **Bundle Identifier**: `com.mlq.my_leadership_quest`
6. Check **Automatically manage signing**

### Set Deployment Target
1. In Xcode, with Runner selected
2. Go to **General** tab
3. Set **Minimum Deployments** to **iOS 12.0** or higher

---

## Step 4: Build and Test

### Build for iOS Simulator
```bash
# List available simulators
flutter emulators

# Launch a simulator
open -a Simulator

# Build and run
flutter run
```

### Build for Physical Device
```bash
# Connect iPhone/iPad via USB
# Trust the computer on your device when prompted

# List connected devices
flutter devices

# Run on device
flutter run -d <device-id>
```

### Create Release Build
```bash
# Build release IPA for App Store
flutter build ipa --release

# Output location: build/ios/ipa/my_leadership_quest.ipa
```

---

## Step 5: App Store Submission

### Create App in App Store Connect

1. Go to https://appstoreconnect.apple.com
2. Click **My Apps** > **+** > **New App**
3. Fill in details:
   - **Platform**: iOS
   - **Name**: My Leadership Quest
   - **Primary Language**: English
   - **Bundle ID**: com.mlq.my_leadership_quest
   - **SKU**: MLQ001 (or any unique identifier)

### Upload Build Using Xcode

1. In Xcode, select **Product** > **Archive**
2. Wait for archive to complete
3. In Organizer window, click **Distribute App**
4. Select **App Store Connect**
5. Follow prompts to upload

### Or Upload Using Command Line
```bash
# Install Transporter app from Mac App Store
# Then drag the IPA file to Transporter to upload
```

### Complete App Store Listing

1. In App Store Connect, select your app
2. Fill in required information:
   - **App Description** (4000 characters max)
   - **Keywords** (100 characters max)
   - **Screenshots** (required for all device sizes)
   - **App Icon** (1024x1024 px)
   - **Privacy Policy URL**
   - **Support URL**
   - **Age Rating**
   - **Pricing** (Free or Paid)

3. Submit for Review

---

## Alternative: Cloud Build with Codemagic

If you don't have a Mac, use Codemagic:

### Setup Steps:

1. **Push code to GitHub**
   ```bash
   git add .
   git commit -m "Prepare for iOS build"
   git push origin main
   ```

2. **Sign up at https://codemagic.io**
   - Use GitHub to sign in
   - Connect your repository

3. **Add Apple Developer Credentials**
   - Go to Team settings > Code signing identities
   - Add your Apple Developer account
   - Upload certificates and provisioning profiles

4. **Configure Build**
   - Select Flutter app
   - Choose iOS platform
   - Set build configuration to Release
   - Enable automatic code signing

5. **Trigger Build**
   - Click "Start new build"
   - Wait for build to complete (10-20 minutes)
   - Download IPA or publish directly to App Store

---

## Common Issues and Solutions

### Issue: "No valid code signing certificates found"
**Solution**: 
- In Xcode, go to Preferences > Accounts
- Select your Apple ID
- Click "Download Manual Profiles"
- Or enable "Automatically manage signing"

### Issue: "Pod install failed"
**Solution**:
```bash
cd ios
rm Podfile.lock
rm -rf Pods
pod install --repo-update
cd ..
```

### Issue: "Module not found" errors
**Solution**:
```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter build ios
```

### Issue: "Unsupported Swift version"
**Solution**:
- Open `ios/Podfile`
- Uncomment and set: `platform :ios, '12.0'`
- Run `pod install` again

---

## iOS-Specific Features to Consider

### Push Notifications
- Configure in Apple Developer Portal
- Add Push Notifications capability in Xcode
- Upload APNs certificate to Firebase/Supabase

### In-App Purchases (if using)
- Set up in App Store Connect
- Add StoreKit capability in Xcode
- Test with sandbox accounts

### App Tracking Transparency (iOS 14.5+)
Add to Info.plist:
```xml
<key>NSUserTrackingUsageDescription</key>
<string>We use tracking to provide personalized content and improve your experience</string>
```

---

## Build Checklist

Before submitting to App Store:

- [ ] App builds without errors
- [ ] Tested on physical iOS device
- [ ] All features work correctly
- [ ] Push notifications configured
- [ ] App icon added (1024x1024)
- [ ] Launch screen configured
- [ ] Privacy policy URL added
- [ ] Support URL added
- [ ] Screenshots prepared (all device sizes)
- [ ] App description written
- [ ] Keywords optimized
- [ ] Age rating set correctly
- [ ] Pricing configured
- [ ] Test with TestFlight (optional but recommended)

---

## Next Steps

1. **Get a Mac** or sign up for Codemagic
2. **Follow Step 1-4** to build the app
3. **Test thoroughly** on iOS devices
4. **Submit to App Store** following Step 5
5. **Wait for review** (typically 1-3 days)

---

## Resources

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Apple Developer Portal](https://developer.apple.com)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Codemagic Documentation](https://docs.codemagic.io/flutter-configuration/flutter-projects/)
- [TestFlight Guide](https://developer.apple.com/testflight/)

---

## Cost Summary

| Item | Cost | Required |
|------|------|----------|
| Apple Developer Account | $99/year | Yes (for App Store) |
| Mac Computer | $600-2000+ | Yes (or use cloud) |
| Cloud Mac Service | $30-50/month | Alternative to buying Mac |
| Codemagic (Free tier) | $0 | Alternative for building |
| Codemagic (Pro) | $40/month | Optional (more build minutes) |

**Minimum to get started**: $99/year (using Codemagic free tier)
