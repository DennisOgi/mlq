# 🚀 Google Play Store Publishing Checklist

## 📋 **Pre-Publishing Checklist**

### ✅ **COMPLETED ITEMS**

1. **App Identity**
   - ✅ Package Name: `com.mlq.my_leadership_quest`
   - ✅ App Name: "MLQ" (My Leadership Quest)
   - ✅ Version: 1.0.0+1
   - ✅ Description: "A gamified goal-setting app for kids with AI coaching"

2. **Android Configuration**
   - ✅ Min SDK: 23 (Android 6.0+)
   - ✅ Target SDK: Latest Flutter target
   - ✅ Compile SDK: Latest Flutter compile
   - ✅ App Icon: Custom launcher icon configured

3. **Permissions**
   - ✅ INTERNET (for Supabase & AI)
   - ✅ RECEIVE_BOOT_COMPLETED (for background tasks)
   - ✅ POST_NOTIFICATIONS (Android 13+)

---

## ⚠️ **CRITICAL TASKS TO COMPLETE**

### 1. **🔐 App Signing (REQUIRED)**

**Status**: ❌ NOT CONFIGURED

You MUST create a signing key for release builds!

#### **Step 1: Generate Upload Key**

Run this command in your terminal:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Important**: 
- Save the password securely!
- Store the keystore file safely (you'll need it for all future updates)
- **NEVER commit the keystore to Git!**

#### **Step 2: Create key.properties**

Create file: `android/key.properties`

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=<path-to-your-keystore>/upload-keystore.jks
```

**Add to .gitignore**:
```
android/key.properties
*.jks
*.keystore
```

#### **Step 3: Update build.gradle.kts**

Update `android/app/build.gradle.kts`:

```kotlin
// Add at the top, before plugins
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

---

### 2. **📱 App Icons & Branding**

**Status**: ⚠️ NEEDS REVIEW

#### **Required Assets**:

- [ ] **App Icon**: 512x512 PNG (for Play Store)
- [ ] **Feature Graphic**: 1024x500 PNG (Play Store banner)
- [ ] **Screenshots**: At least 2 (phone), recommended 8
  - Phone: 1080x1920 or 1080x2340
  - Tablet: 1200x1920 (optional but recommended)
- [ ] **Promo Video**: YouTube link (optional)

#### **Current Icon**:
- ✅ Launcher icon configured: `@mipmap/launcher_icon`
- ⚠️ Verify all densities exist (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)

---

### 3. **📝 Store Listing Content**

#### **App Title** (max 50 characters)
```
My Leadership Quest - Goals & AI Coach
```

#### **Short Description** (max 80 characters)
```
Gamified goal-setting for kids with AI coaching, challenges & rewards!
```

#### **Full Description** (max 4000 characters)

```
🎯 My Leadership Quest - Empower Your Child's Future!

Transform goal-setting into an exciting adventure! My Leadership Quest (MLQ) is a gamified app designed to help children and teens develop leadership skills, achieve their goals, and build positive habits.

🌟 KEY FEATURES:

🎮 GAMIFICATION & REWARDS
• Earn coins and XP for completing goals
• Unlock badges and achievements
• Compete on global leaderboards
• Join exciting challenges with friends

🤖 AI COACH - QUESTOR
• Personal AI mentor for guidance
• Smart coaching based on your progress
• Motivational support when you need it
• Context-aware advice and tips

📊 GOAL TRACKING
• Set main goals with timelines
• Break down into daily tasks
• Track progress with beautiful graphs
• Link daily goals to main objectives

🎓 MINI-COURSES
• Learn leadership skills
• Complete interactive lessons
• Take quizzes to test knowledge
• Earn rewards for learning

🏆 CHALLENGES
• Join community challenges
• Create custom challenges
• Track progress in real-time
• Earn special rewards

💝 GRATITUDE JOURNAL
• Daily gratitude entries
• Build positive mindset
• Track gratitude streaks
• Reflect on achievements

👨‍👩‍👧 PARENT FEATURES
• Weekly progress reports via email
• Monitor child's achievements
• Safe, kid-friendly environment
• No ads or inappropriate content

🎨 BEAUTIFUL DESIGN
• Modern neumorphic UI
• Child-friendly interface
• Smooth animations
• Engaging visual feedback

🔒 PRIVACY & SECURITY
• Secure authentication
• Data encryption
• COPPA compliant
• No data selling

Perfect for:
✓ Kids aged 8-16
✓ Students developing leadership skills
✓ Young goal-setters
✓ Parents supporting their children's growth

Download My Leadership Quest today and start your child's journey to becoming a confident leader! 🚀

---
Need help? Contact us at: support@myleadershipquest.com
Privacy Policy: https://myleadershipquest.com/privacy
Terms of Service: https://myleadershipquest.com/terms
```

---

### 4. **🔒 Privacy & Legal**

**Status**: ❌ REQUIRED

#### **Privacy Policy** (REQUIRED)
- [ ] Create privacy policy page
- [ ] Host at: `https://myleadershipquest.com/privacy`
- [ ] Must include:
  - Data collection practices
  - Third-party services (Supabase, Gemini AI)
  - Children's privacy (COPPA compliance)
  - Data retention and deletion
  - Contact information

#### **Terms of Service**
- [ ] Create terms of service
- [ ] Host at: `https://myleadershipquest.com/terms`

#### **Content Rating**
- [ ] Complete Google Play content rating questionnaire
- [ ] Expected rating: **Everyone** or **Everyone 10+**

---

### 5. **🧪 Testing & Quality**

**Status**: ⚠️ NEEDS COMPLETION

#### **Pre-Launch Testing**:

- [ ] **Test on Multiple Devices**
  - Phone (various screen sizes)
  - Tablet
  - Different Android versions (6.0+)

- [ ] **Feature Testing**
  - ✅ User authentication (login/signup)
  - ✅ Goal creation and completion
  - ✅ Challenge system
  - ✅ Mini-courses completion
  - ✅ AI coach (Questor)
  - ✅ Leaderboard
  - ✅ Badge system
  - ⚠️ Payment system (if enabled)
  - ✅ Offline functionality

- [ ] **Performance Testing**
  - App startup time < 3 seconds
  - Smooth animations (60 FPS)
  - No memory leaks
  - Efficient battery usage

- [ ] **Security Testing**
  - API keys not exposed in code
  - Secure authentication flow
  - Data encryption
  - No sensitive data in logs

#### **Fix Critical Issues**:
- ✅ XP for daily goals working
- ✅ Mini-course challenge tracking fixed
- ⚠️ Badge definition warnings (non-critical)
- [ ] Test all edge cases

---

### 6. **📦 Build Configuration**

#### **Update pubspec.yaml**:

```yaml
name: my_leadership_quest
description: "A gamified goal-setting app for kids with AI coaching"
publish_to: 'none'

version: 1.0.0+1  # Update before each release

environment:
  sdk: '>=3.2.3 <4.0.0'
```

#### **Version Management**:
- Format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`
- Current: `1.0.0+1`
- Next update: `1.0.1+2` (bug fixes) or `1.1.0+2` (new features)

---

### 7. **🔧 Code Optimization**

#### **Remove Debug Code**:
- [ ] Remove excessive `debugPrint()` statements
- [ ] Remove test/dummy data
- [ ] Remove unused imports
- [ ] Clean up commented code

#### **Obfuscation** (Optional but recommended):

Add to `android/app/build.gradle.kts`:

```kotlin
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

Build with obfuscation:
```bash
flutter build appbundle --obfuscate --split-debug-info=build/app/outputs/symbols
```

---

### 8. **🌐 API Keys & Secrets**

**Status**: ⚠️ CRITICAL

#### **Verify API Keys are Secure**:

- [ ] Gemini API key not hardcoded
- [ ] Supabase keys properly configured
- [ ] No secrets in version control
- [ ] Environment-specific configs

#### **Current Configuration**:
- ✅ Supabase URL/keys in `config_service.dart`
- ✅ Gemini API key location documented
- ⚠️ Verify keys are production-ready

---

## 🚀 **BUILD & RELEASE PROCESS**

### **Step 1: Clean Build**

```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### **Step 2: Run Tests**

```bash
flutter test
flutter analyze
```

### **Step 3: Build Release Bundle**

```bash
# Build App Bundle (recommended)
flutter build appbundle --release

# Or build APK
flutter build apk --release --split-per-abi
```

**Output locations**:
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

### **Step 4: Test Release Build**

```bash
# Install on device
flutter install --release

# Or manually install APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 📤 **GOOGLE PLAY CONSOLE SETUP**

### **1. Create Developer Account**
- Cost: $25 one-time fee
- URL: https://play.google.com/console

### **2. Create App**
- Choose "App" (not Game)
- Select "Free" or "Paid"
- Add app details

### **3. Store Listing**
- Upload app icon (512x512)
- Upload feature graphic (1024x500)
- Upload screenshots (min 2, max 8)
- Add descriptions
- Select category: **Education** or **Lifestyle**
- Add contact email
- Link privacy policy

### **4. Content Rating**
- Complete questionnaire
- Mention:
  - Educational content
  - Goal-setting features
  - AI chat (moderated)
  - No violence/mature content

### **5. App Content**
- Privacy policy URL
- Ads declaration (No ads)
- Target audience: Children
- Data safety form

### **6. Release**
- Upload app bundle (.aab file)
- Add release notes
- Choose release track:
  - **Internal testing**: For team testing
  - **Closed testing**: For beta testers
  - **Open testing**: Public beta
  - **Production**: Public release

---

## ✅ **FINAL CHECKLIST BEFORE SUBMISSION**

- [ ] App signing configured
- [ ] Release build tested on real devices
- [ ] All features working correctly
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] Store listing complete (title, description, screenshots)
- [ ] Content rating completed
- [ ] Data safety form completed
- [ ] App bundle built and tested
- [ ] Version number updated
- [ ] No debug code or test data
- [ ] API keys secured
- [ ] Crash reporting configured (optional: Firebase Crashlytics)
- [ ] Analytics configured (optional: Firebase Analytics)

---

## 📊 **POST-LAUNCH**

### **Monitor**:
- Crash reports
- User reviews
- Performance metrics
- Download statistics

### **Update Strategy**:
- Bug fixes: Patch version (1.0.1)
- New features: Minor version (1.1.0)
- Major changes: Major version (2.0.0)

### **User Feedback**:
- Respond to reviews
- Fix reported bugs
- Implement feature requests
- Regular updates (monthly recommended)

---

## 🆘 **NEED HELP?**

### **Resources**:
- [Flutter Publishing Guide](https://docs.flutter.dev/deployment/android)
- [Play Console Help](https://support.google.com/googleplay/android-developer)
- [App Signing Guide](https://developer.android.com/studio/publish/app-signing)

### **Common Issues**:
1. **Signing errors**: Verify key.properties path
2. **Build failures**: Run `flutter clean` and rebuild
3. **Upload rejected**: Check file size (<150MB for bundle)
4. **Policy violations**: Review content rating and privacy policy

---

## 🎯 **ESTIMATED TIMELINE**

- **App Signing Setup**: 30 minutes
- **Store Assets Creation**: 2-4 hours
- **Privacy Policy**: 1-2 hours
- **Testing**: 4-8 hours
- **Play Console Setup**: 1-2 hours
- **Review Process**: 1-7 days (Google's review)

**Total**: ~2-3 days of work + Google's review time

---

## 🚀 **READY TO PUBLISH?**

Once all checkboxes are complete, you're ready to submit to Google Play Store!

Good luck with your launch! 🎉
