# iOS Build Setup & Codemagic Guide

## Part 1: Prerequisites (Before Codemagic)

### 1. Apple Developer Account
- **Cost**: $99/year
- **Sign up**: https://developer.apple.com/programs/enroll/
- **What you get**: Ability to publish apps to App Store, TestFlight access, code signing certificates

### 2. App Store Connect Setup
1. Go to https://appstoreconnect.apple.com/
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - **Platform**: iOS
   - **Name**: My Leadership Quest
   - **Primary Language**: English
   - **Bundle ID**: Create new → `com.mlq.myleadershipquest`
   - **SKU**: `mlq-ios-001` (any unique identifier)
   - **User Access**: Full Access

4. Note down your **App Store Connect App ID** (found in App Information)

### 3. Required Information
Prepare these details:
- App Name: My Leadership Quest
- Bundle ID: com.mlq.myleadershipquest
- Version: 1.0.0
- Build Number: 26
- Category: Education
- Age Rating: 4+
- Privacy Policy URL: (your website URL)
- Support URL: (your website URL)

---

## Part 2: Codemagic Setup (Step-by-Step)

### Step 1: Sign Up for Codemagic
1. Go to https://codemagic.io/
2. Click "Sign up for free"
3. Sign up with GitHub (recommended) or email
4. **Free tier includes**: 500 build minutes/month, perfect for getting started

### Step 2: Connect Your Repository
1. In Codemagic dashboard, click "Add application"
2. Select "GitHub" as source
3. Authorize Codemagic to access your repositories
4. Select your repository: `DennisOgi/mlq`
5. Click "Finish: Add application"

### Step 3: Configure iOS Code Signing

#### A. Generate App Store Connect API Key
1. Go to https://appstoreconnect.apple.com/access/api
2. Click "Keys" tab → "+" to generate new key
3. Fill in:
   - **Name**: Codemagic CI/CD
   - **Access**: App Manager (or Developer)
4. Click "Generate"
5. **IMPORTANT**: Download the `.p8` file immediately (you can't download it again!)
6. Note down:
   - **Issuer ID** (at top of page)
   - **Key ID** (in the keys list)
   - **Key file content** (open the .p8 file in notepad)

#### B. Add API Key to Codemagic
1. In Codemagic, go to "Teams" → "Integrations"
2. Click "App Store Connect"
3. Click "Add key"
4. Fill in:
   - **Issuer ID**: (from App Store Connect)
   - **Key ID**: (from App Store Connect)
   - **API Key**: (paste content of .p8 file)
5. Click "Save"

#### C. Set Up Code Signing Identity
1. In Codemagic, go to your app → "Settings" → "Code signing identities"
2. Click "iOS code signing"
3. Two options:

**Option A: Automatic (Recommended for beginners)**
- Select "Automatic code signing"
- Choose your App Store Connect integration
- Codemagic will handle certificates automatically

**Option B: Manual**
- Upload your Distribution Certificate (.p12 file)
- Upload your Provisioning Profile
- Enter certificate password

### Step 4: Configure Build Settings

1. In your app settings, go to "Workflow editor"
2. Select "iOS" workflow
3. Configure:

**Build triggers:**
- ✅ Trigger on push (to main branch)
- ✅ Trigger on pull request
- ⬜ Trigger on tag

**Environment variables:**
Add these in "Environment variables" section:
```
BUNDLE_ID = com.mlq.myleadershipquest
APP_STORE_APPLE_ID = [Your App ID from App Store Connect]
```

**Build configuration:**
- Flutter version: Stable
- Xcode version: Latest
- CocoaPods: Default
- Build mode: Release

### Step 5: Update codemagic.yaml

The `codemagic.yaml` file has been created in your project. Update these values:

```yaml
# Line 13: Replace with your App Store Connect App ID
APP_STORE_APPLE_ID: 1234567890

# Line 48: Replace with your email
recipients:
  - your-email@example.com
```

### Step 6: Commit and Push

```bash
cd my_leadership_quest
git add codemagic.yaml ios/Podfile
git commit -m "Add iOS build configuration for Codemagic"
git push origin main
```

### Step 7: Start Your First Build

1. Go to Codemagic dashboard
2. Select your app
3. Click "Start new build"
4. Select branch: `main`
5. Select workflow: `ios-workflow`
6. Click "Start new build"

**Build time**: Expect 15-25 minutes for first build

---

## Part 3: What Happens During Build

### Build Process:
1. ✅ Codemagic clones your repository
2. ✅ Sets up Flutter environment
3. ✅ Runs `flutter pub get`
4. ✅ Installs CocoaPods dependencies
5. ✅ Configures code signing
6. ✅ Runs `flutter build ipa --release`
7. ✅ Creates .ipa file
8. ✅ Uploads to TestFlight (if configured)
9. ✅ Sends email notification

### Build Artifacts:
- **IPA file**: `build/ios/ipa/my_leadership_quest.ipa`
- **Build logs**: Available in Codemagic dashboard
- **dSYM files**: For crash reporting

---

## Part 4: TestFlight Distribution

### After Successful Build:

1. **Automatic Upload** (if configured in codemagic.yaml):
   - Build automatically uploads to TestFlight
   - Processing takes 5-15 minutes in App Store Connect

2. **Manual Upload** (if automatic fails):
   - Download .ipa from Codemagic artifacts
   - Use Transporter app (Mac) or Codemagic's upload feature

### Add TestFlight Testers:

1. Go to App Store Connect → TestFlight
2. Click "Internal Testing" or "External Testing"
3. Add testers by email
4. They'll receive invitation to test the app

---

## Part 5: Troubleshooting Common Issues

### Issue 1: "No provisioning profile found"
**Solution**: 
- Ensure Bundle ID matches in App Store Connect and Xcode
- Regenerate provisioning profile in Codemagic

### Issue 2: "Pod install failed"
**Solution**:
- Check Podfile syntax
- Ensure minimum iOS version is 12.0 or higher

### Issue 3: "Build failed: Code signing error"
**Solution**:
- Verify App Store Connect API key is correct
- Check certificate hasn't expired
- Try "Automatic code signing" in Codemagic

### Issue 4: "Flutter build failed"
**Solution**:
- Check build logs for specific errors
- Ensure all dependencies are compatible with iOS
- Run `flutter doctor` locally to check setup

### Issue 5: "Upload to TestFlight failed"
**Solution**:
- Verify App Store Connect API key has "App Manager" access
- Check app is properly created in App Store Connect
- Ensure version/build number is unique

---

## Part 6: App Store Submission Checklist

Before submitting to App Store:

### Required Assets:
- [ ] App Icon (1024x1024px)
- [ ] Screenshots (6.5", 5.5" iPhone sizes)
- [ ] App Preview video (optional but recommended)

### Required Information:
- [ ] App Description (4000 characters max)
- [ ] Keywords (100 characters max)
- [ ] Support URL
- [ ] Privacy Policy URL
- [ ] Age Rating questionnaire completed

### App Store Connect Setup:
- [ ] App Information filled
- [ ] Pricing and Availability set
- [ ] App Privacy details submitted
- [ ] Export Compliance information provided

### Testing:
- [ ] TestFlight testing completed
- [ ] No crashes or major bugs
- [ ] All features working as expected
- [ ] Tested on multiple iOS versions

---

## Part 7: Costs Summary

### One-Time Costs:
- Apple Developer Account: $99/year

### Codemagic Costs:
- **Free Tier**: 500 minutes/month
  - ~20-25 iOS builds per month
  - Perfect for small teams
  
- **Paid Plans** (if you need more):
  - Starter: $99/month (unlimited builds)
  - Professional: $299/month (faster builds, more features)

### Recommendation:
Start with free tier, upgrade only if you need more builds.

---

## Part 8: Quick Reference Commands

### Local Testing (if you get a Mac later):
```bash
# Install dependencies
flutter pub get
cd ios && pod install && cd ..

# Build for iOS
flutter build ios --release

# Run on simulator
flutter run -d ios

# Clean build
flutter clean
cd ios && pod deintegrate && pod install && cd ..
```

### Codemagic CLI (optional):
```bash
# Install Codemagic CLI
pip3 install codemagic-cli-tools

# Trigger build from command line
codemagic builds start --app-id YOUR_APP_ID --workflow ios-workflow
```

---

## Part 9: Next Steps After First Build

1. **Test on TestFlight**:
   - Install TestFlight app on iPhone
   - Accept invitation
   - Test all features thoroughly

2. **Gather Feedback**:
   - Share with beta testers
   - Collect crash reports
   - Fix critical bugs

3. **Prepare for App Store**:
   - Create marketing materials
   - Write compelling description
   - Take professional screenshots
   - Record app preview video

4. **Submit for Review**:
   - Complete all App Store Connect fields
   - Submit for review
   - Review typically takes 24-48 hours

---

## Support Resources

- **Codemagic Docs**: https://docs.codemagic.io/
- **Flutter iOS Deployment**: https://docs.flutter.dev/deployment/ios
- **App Store Connect Help**: https://developer.apple.com/support/app-store-connect/
- **TestFlight Guide**: https://developer.apple.com/testflight/

---

## Your Current Configuration

✅ **App Name**: My Leadership Quest
✅ **Bundle ID**: com.mlq.myleadershipquest
✅ **Version**: 1.0.0+26
✅ **Minimum iOS**: 12.0
✅ **Repository**: https://github.com/DennisOgi/mlq.git
✅ **Codemagic Config**: codemagic.yaml (created)
✅ **Podfile**: ios/Podfile (created)

**You're ready to start building!** 🚀
