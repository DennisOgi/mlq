# Google Play Upload Key Reset - Status & Next Steps

## Current Status Overview

### ✓ COMPLETED STEPS

#### Step 1: Generate New Upload Key ✓
**Status**: COMPLETED

You have TWO keystores:

1. **Old Keystore** (Wrong key - causes error)
   - File: `C:\Users\HP\upload-keystore.jks`
   - SHA1: `56:86:E1:87:FE:8C:87:2D:8F:B9:69:83:B2:81:E0:CF:DA:C0:50:5E`
   - Created: March 13, 2026
   - Size: 2.2 KB
   - Status: ❌ Wrong fingerprint (not matching Play Store)

2. **New Keystore** (For reset request)
   - File: `C:\Users\HP\new-upload-keystore.jks`
   - SHA1: `36:BD:78:71:3F:2E:C0:04:0A:B5:A2:6E:CE:3D:39:7F:DF:36:C9:E3`
   - Created: March 18, 2026
   - Size: 2.68 KB
   - Status: ✓ Ready for reset request

**Expected by Play Store**:
- SHA1: `12:51:B2:4C:6C:C8:F1:34:C4:2D:FA:3F:CE:30:14:36:70:68:02:0E`

#### Step 2: Export Certificate ⚠️ NEEDS UPDATE
**Status**: PARTIALLY COMPLETED

You have an old certificate:
- File: `C:\Users\HP\upload_certificate.pem`
- Created: March 15, 2026
- Size: 1.27 KB
- Status: ⚠️ This is from the OLD keystore, needs to be regenerated

---

## 🔴 NEXT STEPS TO COMPLETE

### Step 1: Export NEW Certificate from NEW Keystore

Run this command to export the certificate from the NEW keystore:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -export -rfc -alias upload -file C:\Users\HP\new_upload_certificate.pem -keystore C:\Users\HP\new-upload-keystore.jks -storepass Blackboi787898
```

This will create: `C:\Users\HP\new_upload_certificate.pem`

### Step 2: Submit to Google Play Console

1. Go to Google Play Console: https://play.google.com/console
2. Select your app: **My Leadership Quest** (`com.mlq.my_leadership_quest`)
3. Navigate to: **Test and release** → **App integrity**
4. Click on: **Play app signing**
5. Click: **Settings** (gear icon or settings button)
6. Click: **Request Upload key reset**
7. Fill in the form:
   - **Reason**: "Lost original upload key. Generated new 2048-bit RSA key with 25-year validity as instructed by Google Play Support (Belle)."
   - **Upload PEM file**: Select `C:\Users\HP\new_upload_certificate.pem`
8. Click: **Request** or **Submit**

### Step 3: Wait for Google Approval

- Google typically responds within 1-3 business days
- You'll receive an email confirmation
- Belle from Google Play Support has already pre-approved your request

### Step 4: Update key.properties (After Approval)

Once Google approves the reset, update your `android/key.properties`:

```properties
storePassword=Blackboi787898
keyPassword=Blackboi787898
keyAlias=upload
storeFile=C:\\Users\\HP\\new-upload-keystore.jks
```

### Step 5: Wait 48 Hours Buffer Period

⚠️ **IMPORTANT**: After Google resets the upload key, wait 48 hours before uploading a new app bundle.

### Step 6: Build and Upload New App Bundle

After the 48-hour buffer period:

```powershell
cd my_leadership_quest
flutter clean
flutter build appbundle --release
```

Upload the bundle from: `build\app\outputs\bundle\release\app-release.aab`

---

## Quick Command Reference

### Export NEW Certificate (DO THIS NOW)
```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -export -rfc -alias upload -file C:\Users\HP\new_upload_certificate.pem -keystore C:\Users\HP\new-upload-keystore.jks -storepass Blackboi787898
```

### Verify Certificate Was Created
```powershell
Test-Path C:\Users\HP\new_upload_certificate.pem
Get-Item C:\Users\HP\new_upload_certificate.pem
```

### View Certificate Contents (Optional)
```powershell
Get-Content C:\Users\HP\new_upload_certificate.pem
```

### Check Keystore Fingerprint (Verification)
```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore C:\Users\HP\new-upload-keystore.jks -alias upload -storepass Blackboi787898
```

---

## Keystore Summary

| Keystore | SHA1 Fingerprint | Status | Action |
|----------|------------------|--------|--------|
| **Expected by Play Store** | `12:51:B2:4C:6C:C8:F1:34:C4:2D:FA:3F:CE:30:14:36:70:68:02:0E` | Original (lost) | Cannot recover |
| **upload-keystore.jks** | `56:86:E1:87:FE:8C:87:2D:8F:B9:69:83:B2:81:E0:CF:DA:C0:50:5E` | Wrong key | ❌ Don't use |
| **new-upload-keystore.jks** | `36:BD:78:71:3F:2E:C0:04:0A:B5:A2:6E:CE:3D:39:7F:DF:36:C9:E3` | New key for reset | ✓ Use this |

---

## Important Notes

### Why You Need a NEW Key

Google requires the new upload key to be:
- ✓ Different from any previous keys (including the wrong one)
- ✓ 2048-bit RSA key
- ✓ 25-year validity (9125 days)

Your `new-upload-keystore.jks` meets all these requirements.

### What Happens After Reset

1. Google will register your new upload key
2. The old/wrong keys will be invalidated
3. You'll be able to upload app bundles signed with the new key
4. App signing key (used by Play Store) remains the same
5. Users won't be affected - updates will work normally

### 48-Hour Buffer Period

Google mentioned a 48-hour buffer period:
- This is the time between when Google resets the key and when you can use it
- Plan accordingly - don't try to upload immediately after approval
- Use this time to prepare your app bundle

### Certificate File Naming

- Old certificate: `upload_certificate.pem` (from wrong keystore)
- New certificate: `new_upload_certificate.pem` (from new keystore)
- Keep them separate to avoid confusion

---

## Troubleshooting

### "Certificate already exists"
If the file already exists, delete it first:
```powershell
Remove-Item C:\Users\HP\new_upload_certificate.pem -Force
```
Then run the export command again.

### "Keystore not found"
Verify the keystore exists:
```powershell
Test-Path C:\Users\HP\new-upload-keystore.jks
```

### "Wrong password"
The password is: `Blackboi787898`
Make sure there are no typos.

### "Cannot find keytool"
Use the full path:
```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
```

---

## Timeline

### Completed
- ✓ March 13: Created upload-keystore.jks (wrong key)
- ✓ March 15: Exported certificate from wrong key
- ✓ March 18: Created new-upload-keystore.jks (correct key)
- ✓ March 18: Received Google approval from Belle

### To Do
- 🔴 Export certificate from NEW keystore
- 🔴 Submit reset request in Play Console
- ⏳ Wait for Google confirmation (1-3 days)
- ⏳ Wait 48-hour buffer period
- ⏳ Update key.properties
- ⏳ Build and upload new app bundle

---

## Contact Information

**Google Play Support Contact**: Belle
**Your App**: My Leadership Quest (`com.mlq.my_leadership_quest`)
**Support Email**: Check your Google Play Console for support contact

---

## Ready to Proceed?

Run this command NOW to export the certificate:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -export -rfc -alias upload -file C:\Users\HP\new_upload_certificate.pem -keystore C:\Users\HP\new-upload-keystore.jks -storepass Blackboi787898
```

Then follow Step 2 above to submit to Google Play Console.
