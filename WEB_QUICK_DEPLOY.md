# Web Version - Quick Deployment Guide

## ✅ Your Web App is Ready!

Your Flutter app is already configured for web with:
- ✅ Web-compatible authentication (no `InternetAddress.lookup` errors)
- ✅ Firebase initialization skips on web
- ✅ Updated manifest and index.html with proper metadata
- ✅ All platform-specific code properly handled

## Option 1: Deploy to Firebase Hosting (Recommended - FREE)

### Step 1: Build the Web App
```bash
cd my_leadership_quest
flutter build web --release
```

### Step 2: Install Firebase CLI
```bash
npm install -g firebase-tools
```

### Step 3: Login to Firebase
```bash
firebase login
```

### Step 4: Initialize Firebase Hosting
```bash
firebase init hosting
```

When prompted:
- **Public directory**: `build/web`
- **Configure as single-page app**: `Yes`
- **Set up automatic builds**: `No`
- **Overwrite index.html**: `No`

### Step 5: Deploy
```bash
firebase deploy --only hosting
```

Your app will be live at: `https://your-project.web.app`

---

## Option 2: Deploy to Netlify (Easy Drag & Drop)

### Step 1: Build the Web App
```bash
cd my_leadership_quest
flutter build web --release
```

### Step 2: Deploy
1. Go to https://app.netlify.com/drop
2. Drag the `build/web` folder onto the page
3. Done! You get a URL like `https://your-app.netlify.app`

### Optional: Custom Domain
- Go to Domain Settings in Netlify
- Add your custom domain
- Follow DNS configuration steps

---

## Option 3: Deploy to Vercel (Fast & Free)

### Step 1: Build the Web App
```bash
cd my_leadership_quest
flutter build web --release
```

### Step 2: Install Vercel CLI
```bash
npm install -g vercel
```

### Step 3: Deploy
```bash
cd build/web
vercel
```

Follow the prompts and your app will be live!

---

## Option 4: Test Locally First

### Quick Local Test
```bash
cd my_leadership_quest
flutter run -d chrome
```

### Or Build and Serve
```bash
# Build
flutter build web --release

# Serve with Python
cd build/web
python -m http.server 8000

# Open browser to: http://localhost:8000
```

---

## Important: Post-Deployment Configuration

### 1. Update Supabase CORS Settings
After deployment, add your domain to Supabase:

1. Go to Supabase Dashboard → Settings → API
2. Under "Additional Allowed Origins", add:
   - Your Firebase URL: `https://your-project.web.app`
   - Your custom domain: `https://yourdomain.com`
   - For testing: `http://localhost:8000`

### 2. Update Flutterwave Redirect URL
For web payments to work:

1. Go to Flutterwave Dashboard
2. Update redirect URL to your web domain
3. Or update in your code: `lib/services/config_service.dart`

```dart
static const String _defaultFlwRedirectUrl = 'https://yourdomain.com/payment-callback';
```

---

## Build Optimization Options

### Standard Build (Recommended)
```bash
flutter build web --release
```

### With CanvasKit (Better Performance)
```bash
flutter build web --release --web-renderer canvaskit
```

### With HTML Renderer (Faster Load)
```bash
flutter build web --release --web-renderer html
```

### Auto Renderer (Flutter Decides)
```bash
flutter build web --release --web-renderer auto
```

---

## Troubleshooting

### Issue: "Failed to load network image"
**Solution**: Check CORS settings in Supabase and image hosting

### Issue: Payment redirect doesn't work
**Solution**: 
1. Update Flutterwave redirect URL
2. Ensure HTTPS is used (not HTTP)

### Issue: App loads slowly
**Solution**: 
1. Use `--web-renderer html` for faster initial load
2. Enable caching in hosting provider
3. Use CDN for assets

### Issue: Features don't work on web
**Solution**: Check browser console for errors. Some native features may need web alternatives.

---

## Recommended Deployment Flow

1. **Test Locally**:
   ```bash
   flutter run -d chrome
   ```

2. **Build for Production**:
   ```bash
   flutter build web --release
   ```

3. **Deploy to Firebase** (or Netlify/Vercel):
   ```bash
   firebase deploy --only hosting
   ```

4. **Update Supabase CORS**:
   - Add your deployed URL to allowed origins

5. **Test Live Site**:
   - Test login/signup
   - Test all major features
   - Test on different browsers

6. **Set Up Custom Domain** (Optional):
   - Configure DNS
   - Add SSL certificate (automatic on Firebase/Netlify/Vercel)

---

## Your Web App URLs

After deployment, you'll have:
- **Firebase**: `https://your-project.web.app` or `https://your-project.firebaseapp.com`
- **Netlify**: `https://your-app.netlify.app`
- **Vercel**: `https://your-app.vercel.app`
- **Custom Domain**: `https://mlq.app` (if configured)

---

## Next Steps

1. ✅ Build the web app: `flutter build web --release`
2. ✅ Choose a hosting provider (Firebase recommended)
3. ✅ Deploy using the steps above
4. ✅ Update Supabase CORS settings
5. ✅ Test thoroughly on the live site
6. ✅ Share your web app URL!

---

## Support

If you encounter issues:
- Check browser console for errors
- Verify Supabase CORS settings
- Test in incognito mode
- Try different browsers (Chrome, Firefox, Safari, Edge)

Your web app is production-ready! 🚀
