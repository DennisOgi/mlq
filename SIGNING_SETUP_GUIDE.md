# 🔐 App Signing Setup Guide

## ⚠️ CRITICAL: Required for Play Store Release

You **MUST** complete this before publishing to Google Play Store!

---

## 📋 **Step-by-Step Instructions**

### **Step 1: Generate Upload Keystore**

Open your terminal and run:

```bash
keytool -genkey -v -keystore C:\Users\HP\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**You'll be asked for:**
1. **Keystore password** - Choose a strong password (save it!)
2. **Key password** - Can be same as keystore password
3. **Your name** - Your name or company name
4. **Organizational unit** - e.g., "Development"
5. **Organization** - e.g., "My Leadership Quest"
6. **City/Locality** - Your city
7. **State/Province** - Your state
8. **Country code** - Two letter code (e.g., "US", "NG")

**IMPORTANT**: 
- ⚠️ **Save the passwords securely!** You'll need them for every app update
- ⚠️ **Backup the keystore file!** If you lose it, you can't update your app
- ⚠️ **NEVER commit it to Git!** (Already in .gitignore)

---

### **Step 2: Create key.properties File**

Create file: `android/key.properties`

```properties
storePassword=YOUR_KEYSTORE_PASSWORD_HERE
keyPassword=YOUR_KEY_PASSWORD_HERE
keyAlias=upload
storeFile=C:\\Users\\HP\\upload-keystore.jks
```

**Replace**:
- `YOUR_KEYSTORE_PASSWORD_HERE` with your keystore password
- `YOUR_KEY_PASSWORD_HERE` with your key password
- Update `storeFile` path if you saved it elsewhere

**Note**: Use double backslashes (`\\`) in Windows paths!

---

### **Step 3: Update build.gradle.kts**

I'll update the file for you now...
