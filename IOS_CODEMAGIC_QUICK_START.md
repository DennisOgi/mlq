# iOS + Codemagic Quick Start Checklist

## ⏱️ Time Required: ~2 hours (mostly waiting for Apple approvals)

---

## Phase 1: Apple Setup (30 minutes)

### ☐ Step 1: Apple Developer Account
- [ ] Go to https://developer.apple.com/programs/enroll/
- [ ] Pay $99 annual fee
- [ ] Wait for approval (usually instant, can take up to 24 hours)

### ☐ Step 2: Create App in App Store Connect
- [ ] Go to https://appstoreconnect.apple.com/
- [ ] Click "My Apps" → "+" → "New App"
- [ ] Fill in:
  - Platform: iOS
  - Name: My Leadership Quest
  - Bundle ID: com.mlq.myleadershipquest
  - SKU: mlq-ios-001
- [ ] Save the **App Store Connect App ID** (you'll need this)

### ☐ Step 3: Generate API Key
- [ ] Go to https://appstoreconnect.apple.com/access/api
- [ ] Click "Keys" → "+" 
- [ ] Name: Codemagic CI/CD
- [ ] Access: App Manager
- [ ] Download the `.p8` file (SAVE IT SAFELY!)
- [ ] Copy these 3 values:
  ```
  Issuer ID: _________________
  Key ID: _________________
  Key file: (the .p8 file content)
  ```

---

## Phase 2: Codemagic Setup (20 minutes)

### ☐ Step 4: Sign Up for Codemagic
- [ ] Go to https://codemagic.io/
- [ ] Sign up with GitHub
- [ ] Authorize Codemagic

### ☐ Step 5: Add Your App
- [ ] Click "Add application"
- [ ] Select GitHub
- [ ] Choose repository: `DennisOgi/mlq`
- [ ] Click "Finish: Add application"

### ☐ Step 6: Connect App Store Connect
- [ ] Go to "Teams" → "Integrations"
- [ ] Click "App Store Connect" → "Add key"
- [ ] Paste your 3 values from Step 3:
  - Issuer ID
  - Key ID
  - API Key (content of .p8 file)
- [ ] Click "Save"

### ☐ Step 7: Configure Code Signing
- [ ] Go to your app → "Settings" → "Code signing identities"
- [ ] Click "iOS code signing"
- [ ] Select "Automatic code signing"
- [ ] Choose your App Store Connect integration
- [ ] Click "Save"

---

## Phase 3: Update Configuration (10 minutes)

### ☐ Step 8: Update codemagic.yaml
Open `my_leadership_quest/codemagic.yaml` and update:

**Line 13** - Replace with your App Store Connect App ID:
```yaml
APP_STORE_APPLE_ID: 1234567890  # ← Change this
```

**Line 48** - Replace with your email:
```yaml
recipients:
  - your-email@example.com  # ← Change this
```

### ☐ Step 9: Commit and Push
```bash
cd my_leadership_quest
git add codemagic.yaml ios/Podfile IOS_BUILD_SETUP_GUIDE.md IOS_CODEMAGIC_QUICK_START.md
git commit -m "Add iOS build configuration for Codemagic"
git push origin main
```

---

## Phase 4: First Build (20-30 minutes)

### ☐ Step 10: Trigger Build
- [ ] Go to Codemagic dashboard
- [ ] Select your app
- [ ] Click "Start new build"
- [ ] Select branch: `main`
- [ ] Select workflow: `ios-workflow`
- [ ] Click "Start new build"
- [ ] ☕ Wait 15-25 minutes

### ☐ Step 11: Monitor Build
Watch the build logs for:
- ✅ Dependencies installed
- ✅ Code signing configured
- ✅ Build successful
- ✅ Upload to TestFlight

---

## Phase 5: TestFlight Testing (15 minutes)

### ☐ Step 12: Add Testers
- [ ] Go to App Store Connect → TestFlight
- [ ] Click "Internal Testing" → "+"
- [ ] Add tester emails
- [ ] Click "Add"

### ☐ Step 13: Test the App
- [ ] Install TestFlight app on iPhone
- [ ] Accept invitation email
- [ ] Download and test your app
- [ ] Report any issues

---

## 🎉 Success Criteria

You'll know everything worked when:
- ✅ Codemagic build shows "Success" (green)
- ✅ You receive email notification from Codemagic
- ✅ App appears in TestFlight (App Store Connect)
- ✅ You can install and run app on iPhone via TestFlight

---

## 🚨 Common Issues & Quick Fixes

### "No provisioning profile found"
→ Go to Codemagic → Code signing → Re-save automatic signing

### "Pod install failed"
→ Check that Podfile was committed and pushed

### "Code signing error"
→ Verify API key has "App Manager" access in App Store Connect

### "Upload to TestFlight failed"
→ Check that app exists in App Store Connect with correct Bundle ID

### "Build timeout"
→ Free tier has 120 min limit, your build should take ~20 min

---

## 📞 Need Help?

1. **Check build logs** in Codemagic (most errors are explained there)
2. **Codemagic Slack**: https://codemagic.io/slack
3. **Codemagic Docs**: https://docs.codemagic.io/
4. **Flutter Discord**: https://discord.gg/flutter

---

## 💰 Cost Breakdown

| Item | Cost | Frequency |
|------|------|-----------|
| Apple Developer Account | $99 | Per year |
| Codemagic Free Tier | $0 | Forever (500 min/month) |
| **Total to get started** | **$99** | **One-time** |

---

## ⏭️ What's Next?

After successful TestFlight build:

1. **Beta Testing** (1-2 weeks)
   - Gather feedback from testers
   - Fix bugs and issues
   - Iterate on features

2. **App Store Preparation** (2-3 days)
   - Create screenshots
   - Write description
   - Set up pricing
   - Complete privacy details

3. **Submit for Review** (1-2 days)
   - Submit from App Store Connect
   - Wait for Apple review (24-48 hours)
   - Respond to any feedback

4. **Launch!** 🚀
   - App goes live on App Store
   - Share with the world
   - Monitor reviews and ratings

---

## 📋 Pre-Flight Checklist

Before you start, make sure you have:
- [ ] Credit card for Apple Developer Account ($99)
- [ ] Access to email for Apple account verification
- [ ] GitHub account (for Codemagic)
- [ ] 2-3 hours of uninterrupted time
- [ ] iPhone for testing (optional but recommended)

**Ready? Let's build your iOS app!** 🚀
