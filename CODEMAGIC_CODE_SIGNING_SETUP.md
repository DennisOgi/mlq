# Codemagic Code Signing Setup Guide

## Why You Got Runner.app.zip Instead of .ipa

Your build succeeded but produced a **simulator build** instead of a **distribution build**. This happens when code signing is not properly configured.

---

## Quick Fix: Set Up Code Signing in Codemagic

### Step 1: Generate App Store Connect API Key

1. Go to https://appstoreconnect.apple.com/access/api
2. Click **"Keys"** tab
3. Click **"+"** to generate new key
4. Fill in:
   - **Name**: Codemagic CI/CD
   - **Access**: App Manager
5. Click **"Generate"**
6. **IMPORTANT**: Download the `.p8` file immediately (you can't download it again!)
7. **Save these 3 values**:
   ```
   Issuer ID: ________________________________
   Key ID: ________________________________
   Key file content: (open .p8 file in notepad and copy all text)
   ```

### Step 2: Add API Key to Codemagic

1. Go to **Codemagic Dashboard**
2. Click **"Teams"** (top right)
3. Click **"Integrations"**
4. Find **"App Store Connect"** section
5. Click **"Add key"**
6. Fill in the form:
   - **Issuer ID**: (paste from Step 1)
   - **Key ID**: (paste from Step 1)
   - **API Key**: (paste entire content of .p8 file)
7. Click **"Save"**

### Step 3: Enable Code Signing for Your App

1. Go back to **Codemagic Dashboard**
2. Select your app: **mlq**
3. Click **"Settings"** (gear icon)
4. Click **"Code signing identities"**
5. Click **"iOS code signing"**
6. Configure:
   - **Code signing method**: Automatic
   - **Distribution type**: App Store
   - **Bundle identifier**: com.mlq.myleadershipquest
   - **App Store Connect integration**: Select the integration you just added
7. Click **"Save"**

### Step 4: Update codemagic.yaml (If Needed)

Make sure your `codemagic.yaml` has the correct App Store Connect App ID:

```yaml
vars:
  APP_STORE_APPLE_ID: 1234567890  # ← Replace with your actual App ID
```

**How to find your App Store Connect App ID:**
1. Go to https://appstoreconnect.apple.com/
2. Click "My Apps"
3. Select your app
4. Click "App Information" (left sidebar)
5. Look for "Apple ID" (it's a number like 1234567890)

### Step 5: Start New Build

1. Go to **Codemagic Dashboard**
2. Select your app
3. Click **"Start new build"**
4. Select:
   - **Branch**: main
   - **Workflow**: ios-workflow
5. Click **"Start new build"**
6. Wait 20-30 minutes

---

## What to Expect in Correct Build

### Build Logs Should Show:

```bash
✓ Setting up code signing
✓ Fetching provisioning profiles
✓ Installing certificates
✓ Code signing configured successfully

Building for distribution...
flutter build ipa --release

✓ Built build/ios/ipa/my_leadership_quest.ipa
✓ Uploading to TestFlight
```

### Artifacts Should Include:

1. ✅ **my_leadership_quest.ipa** (50-100 MB)
2. ✅ **Runner.app.dSYM.zip** (debug symbols)
3. ✅ Build logs

### TestFlight:

- App should automatically appear in TestFlight
- Processing takes 5-15 minutes
- You'll receive email when ready for testing

---

## Troubleshooting

### Issue: "No provisioning profile found"

**Solution:**
1. Verify Bundle ID matches exactly: `com.mlq.myleadershipquest`
2. Check that API key has "App Manager" access
3. Try regenerating the API key

### Issue: "Code signing failed"

**Solution:**
1. Delete and re-add App Store Connect integration
2. Ensure you copied the entire .p8 file content (including BEGIN/END lines)
3. Check that Issuer ID and Key ID are correct

### Issue: "Still getting Runner.app.zip"

**Solution:**
1. Check build logs for "Code signing configured"
2. Verify distribution type is "app_store" (not "development")
3. Ensure build command includes `--release` flag

### Issue: "Build timeout"

**Solution:**
- Free tier has 120 min limit
- Your build should take ~20-30 min
- If timing out, contact Codemagic support

---

## Verification Checklist

Before starting new build:

- [ ] App Store Connect API key generated
- [ ] API key added to Codemagic Teams → Integrations
- [ ] Code signing enabled for your app
- [ ] Distribution type set to "App Store"
- [ ] Bundle ID matches: com.mlq.myleadershipquest
- [ ] APP_STORE_APPLE_ID updated in codemagic.yaml
- [ ] App created in App Store Connect

---

## Alternative: Manual Code Signing (Advanced)

If automatic code signing doesn't work, you can use manual signing:

### Requirements:
- Distribution Certificate (.p12 file)
- Provisioning Profile (.mobileprovision file)
- Certificate password

### Steps:
1. Generate certificates on Mac or using Codemagic
2. Upload to Codemagic → Code signing identities
3. Select "Manual" instead of "Automatic"

**Note**: Automatic is recommended for beginners.

---

## Expected Timeline

### With Proper Code Signing:
1. **Build starts**: 0 min
2. **Code signing setup**: 2-3 min
3. **Dependencies**: 5 min
4. **Build ipa**: 10-15 min
5. **Upload to TestFlight**: 3-5 min
6. **TestFlight processing**: 5-15 min
7. **Ready for testing**: ~30-40 min total

---

## Success Indicators

You'll know code signing is working when:

1. ✅ Build logs show "Code signing configured"
2. ✅ Build logs show "Provisioning profile: App Store"
3. ✅ Artifacts include `.ipa` file (not `.app.zip`)
4. ✅ File size is 50-100 MB
5. ✅ App appears in TestFlight automatically

---

## Quick Reference: App Store Connect API Key

### What You Need:
```
Issuer ID: Found at top of API Keys page
Key ID: Listed next to your key name
Key file: Download .p8 file, open in notepad, copy all content
```

### Where to Add in Codemagic:
```
Teams → Integrations → App Store Connect → Add key
```

### Where to Use in App:
```
Settings → Code signing identities → iOS code signing
```

---

## Next Steps After Successful Build

1. **Download .ipa** from Codemagic artifacts
2. **Check TestFlight** in App Store Connect
3. **Add testers** in TestFlight
4. **Install TestFlight app** on iPhone
5. **Test your app** thoroughly

---

## Common Questions

**Q: Do I need a Mac for code signing?**
A: No! Codemagic handles everything on their Mac servers.

**Q: How much does code signing cost?**
A: Only the $99/year Apple Developer Account. Codemagic is free (500 min/month).

**Q: Can I test without TestFlight?**
A: No, you need TestFlight or App Store for real device testing.

**Q: How long is the API key valid?**
A: Forever, unless you revoke it.

**Q: Can I use the same API key for multiple apps?**
A: Yes! One API key works for all your apps.

---

## Summary

**Problem**: Got Runner.app.zip (simulator build)

**Cause**: Code signing not configured

**Solution**: 
1. Generate App Store Connect API key
2. Add to Codemagic integrations
3. Enable code signing for your app
4. Rebuild

**Expected Result**: .ipa file + automatic TestFlight upload

---

**Last Updated**: February 23, 2026
**Status**: Awaiting code signing configuration
