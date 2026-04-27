# Submit Upload Key Reset to Google Play - Step by Step

## ✓ PREPARATION COMPLETE

All files are ready for submission!

### Files Ready
- ✓ New keystore: `C:\Users\HP\new-upload-keystore.jks`
- ✓ New certificate: `C:\Users\HP\new_upload_certificate.pem` (1.27 KB)
- ✓ SHA1 fingerprint: `36:BD:78:71:3F:2E:C0:04:0A:B5:A2:6E:CE:3D:39:7F:DF:36:C9:E3`
- ✓ Google pre-approval received from Belle

---

## 🔴 NEXT: Submit to Google Play Console

Follow these exact steps:

### Step 1: Open Google Play Console
1. Go to: https://play.google.com/console
2. Sign in with your developer account
3. Select your app: **My Leadership Quest**

### Step 2: Navigate to App Integrity
1. In the left sidebar, click: **Test and release**
2. Click: **App integrity**
3. You should see the "Play app signing" section

### Step 3: Access Play App Signing Settings
1. Look for the **Play app signing** card/section
2. Click on **Settings** (usually a gear icon or "Settings" button)
3. This opens the signing key management page

### Step 4: Request Upload Key Reset
1. Look for: **Request Upload key reset** button or link
2. Click it to open the reset request form

### Step 5: Fill Out the Form

**Reason for Reset:**
```
Lost original upload key. Generated new 2048-bit RSA key with 25-year validity as instructed by Google Play Support representative Belle in ticket response dated March 2026.
```

**Upload PEM File:**
1. Click "Choose file" or "Browse"
2. Navigate to: `C:\Users\HP\`
3. Select: `new_upload_certificate.pem`
4. Click "Open"

### Step 6: Submit Request
1. Review the information
2. Click: **Request** or **Submit**
3. You should see a confirmation message

### Step 7: Confirmation
You should receive:
- On-screen confirmation that request was submitted
- Email confirmation to your developer account email
- Response from Google within 1-3 business days (likely faster since Belle pre-approved)

---

## 📧 Expected Email from Google

You'll receive an email similar to:

```
Subject: Upload key reset approved for com.mlq.my_leadership_quest

Hi [Your Name],

Your upload key reset request for My Leadership Quest (com.mlq.my_leadership_quest) 
has been approved.

You can now upload app bundles signed with your new upload key.

Please note: There is a 48-hour buffer period before you can use the new upload key.

Best regards,
Google Play Developer Support
```

---

## ⏳ After Approval: 48-Hour Buffer Period

### What to Do During the Buffer Period

1. **Update key.properties** (do this immediately after approval)
2. **Prepare your app** (test, fix bugs, update version)
3. **Wait 48 hours** before uploading

### Update key.properties

Edit: `my_leadership_quest/android/key.properties`

Change from:
```properties
storePassword=Blackboi787898
keyPassword=Blackboi787898
keyAlias=upload
storeFile=C:\\Users\\HP\\upload-keystore.jks
```

To:
```properties
storePassword=Blackboi787898
keyPassword=Blackboi787898
keyAlias=upload
storeFile=C:\\Users\\HP\\new-upload-keystore.jks
```

---

## 🚀 After 48 Hours: Build and Upload

### Step 1: Clean Build
```powershell
cd my_leadership_quest
flutter clean
flutter pub get
```

### Step 2: Build App Bundle
```powershell
flutter build appbundle --release
```

### Step 3: Verify Build
Check that the bundle was created:
```powershell
Test-Path build\app\outputs\bundle\release\app-release.aab
Get-Item build\app\outputs\bundle\release\app-release.aab
```

### Step 4: Upload to Google Play
1. Go to Google Play Console
2. Navigate to: **Test and release** → **Production** (or your desired track)
3. Click: **Create new release**
4. Upload: `build\app\outputs\bundle\release\app-release.aab`
5. Fill in release notes
6. Click: **Review release**
7. Click: **Start rollout to production**

---

## 📋 Checklist

### Before Submission
- [x] New keystore created (`new-upload-keystore.jks`)
- [x] Certificate exported (`new_upload_certificate.pem`)
- [x] Google pre-approval received
- [ ] Submit reset request in Play Console

### After Approval
- [ ] Receive approval email from Google
- [ ] Update `key.properties` to use new keystore
- [ ] Wait 48 hours
- [ ] Build new app bundle
- [ ] Upload to Google Play
- [ ] Verify upload successful

---

## 🔍 Verification Steps

### Verify Certificate File
```powershell
# Check file exists
Test-Path C:\Users\HP\new_upload_certificate.pem

# Check file size (should be ~1.27 KB)
Get-Item C:\Users\HP\new_upload_certificate.pem

# View certificate content (should start with -----BEGIN CERTIFICATE-----)
Get-Content C:\Users\HP\new_upload_certificate.pem | Select-Object -First 3
```

### Verify Keystore
```powershell
# Check keystore fingerprint
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore C:\Users\HP\new-upload-keystore.jks -alias upload -storepass Blackboi787898 | Select-String -Pattern "SHA1:"
```

Expected output:
```
SHA1: 36:BD:78:71:3F:2E:C0:04:0A:B5:A2:6E:CE:3D:39:7F:DF:36:C9:E3
```

---

## ⚠️ Important Reminders

### DO NOT
- ❌ Use the old `upload-keystore.jks` (wrong key)
- ❌ Use the old `upload_certificate.pem` (wrong certificate)
- ❌ Upload app bundle before 48-hour buffer period
- ❌ Delete the new keystore after submission

### DO
- ✓ Use `new-upload-keystore.jks` for all future builds
- ✓ Use `new_upload_certificate.pem` for the reset request
- ✓ Wait 48 hours after approval before uploading
- ✓ Backup the new keystore in a secure location
- ✓ Keep the password safe: `Blackboi787898`

---

## 🆘 Troubleshooting

### "Cannot find upload key reset option"
- Make sure you're in: Test and release → App integrity → Play app signing → Settings
- Look for "Upload key" section
- May be labeled "Request upload key reset" or "Reset upload key"

### "PEM file rejected"
- Verify file is `new_upload_certificate.pem` (not the old one)
- Check file size is ~1.27 KB
- Ensure file starts with `-----BEGIN CERTIFICATE-----`

### "Request already submitted"
- Check your email for previous submission
- Wait for response from Google
- Contact Google Play Support if needed

### "48-hour buffer period not clear"
- Count 48 hours from when you receive the approval email
- To be safe, wait 2 full days (48 hours) before uploading

---

## 📞 Support

If you encounter issues:

1. **Google Play Console Help**: Click the "?" icon in Play Console
2. **Contact Support**: Use the support form in Play Console
3. **Reference**: Mention Belle's pre-approval and your ticket number
4. **App Package**: `com.mlq.my_leadership_quest`

---

## 🎯 Summary

**What You Need to Do NOW:**

1. Go to Google Play Console
2. Navigate to: Test and release → App integrity → Play app signing → Settings
3. Click: Request Upload key reset
4. Reason: "Lost original upload key. Generated new 2048-bit RSA key with 25-year validity as instructed by Google Play Support representative Belle."
5. Upload: `C:\Users\HP\new_upload_certificate.pem`
6. Submit and wait for approval

**After Approval:**

1. Update `key.properties` to use `new-upload-keystore.jks`
2. Wait 48 hours
3. Build and upload new app bundle

---

## ✅ You're Ready!

All preparation is complete. The certificate file is ready at:
`C:\Users\HP\new_upload_certificate.pem`

Go to Google Play Console and submit the reset request now!
