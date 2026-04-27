# Web Deployment Guide - My Leadership Quest

## Current Status ✅

Your Flutter app is **already configured for web** with the following fixes applied:
- ✅ Web-compatible authentication (no `InternetAddress.lookup` errors)
- ✅ Firebase initialization skips on web (not needed)
- ✅ Supabase integration works on web
- ✅ Basic web configuration files present

## Quick Start - Run Web Locally

### 1. Test the Web App Locally

```bash
# Run in Chrome (recommended for development)
flutter run -d chrome

# Or run in Edge
flutter run -d edge

# Or run on any available browser
flutter run -d web-server
```

### 2. Build for Production

```bash
# Build optimized web app
flutter build web --release

# Build with custom base URL (if hosting in subdirectory)
flutter build web --release --base-href /myapp/

# Build output will be in: my_leadership_quest/build/web/
```

## Deployment Options

### Option 1: Firebase Hosting (Recommended - Free & Fast)

**Setup:**
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project
cd my_leadership_quest
firebase init hosting
```

**Configuration:**
- Select your Firebase project
- Set public directory: `build/web`
- Configure as single-page app: **Yes**
- Set up automatic builds: **No** (optional)

**Deploy:**
```bash
# Build the app
flutter build web --release

# Deploy to Firebase
firebase deploy --only hosting
```

**Custom Domain:**
- Go to Firebase Console → Hosting
- Click "Add custom domain"
- Follow DNS configuration steps

---

### Option 2: Netlify (Easy & Free)

**Method A - Drag & Drop:**
1. Build your app: `flutter build web --release`
2. Go to https://app.netlify.com/drop
3. Drag the `build/web` folder
4. Done! You get a URL like `https://your-app.netlify.app`

**Method B - Git Integration:**
1. Push your code to GitHub
2. Connect Netlify to your repository
3. Build settings:
   - Build command: `flutter build web --release`
   - Publish directory: `build/web`
4. Deploy automatically on every push

---

### Option 3: Vercel (Fast & Free)

```bash
# Install Vercel CLI
npm install -g vercel

# Build the app
flutter build web --release

# Deploy
cd build/web
vercel
```

---

### Option 4: GitHub Pages (Free)

**Setup:**
```bash
# Build with correct base href
flutter build web --release --base-href /my_leadership_quest/

# Create gh-pages branch
git checkout -b gh-pages

# Copy build files
cp -r build/web/* .

# Commit and push
git add .
git commit -m "Deploy to GitHub Pages"
git push origin gh-pages
```

**Enable in GitHub:**
- Go to repository Settings → Pages
- Source: Deploy from branch `gh-pages`
- Your app will be at: `https://yourusername.github.io/my_leadership_quest/`

---

### Option 5: Supabase Storage (Simple)

Since you're already using Supabase:

```bash
# Build the app
flutter build web --release

# Upload build/web/* to Supabase Storage
# Then configure a public bucket and enable website hosting
```

---

### Option 6: Custom Server (VPS/Cloud)

**Using Nginx:**
```nginx
server {
    listen 80;
    server_name yourdomain.com;
    root /var/www/my_leadership_quest;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

**Deploy:**
```bash
# Build
flutter build web --release

# Copy to server
scp -r build/web/* user@server:/var/www/my_leadership_quest/
```

---

## Web-Specific Considerations

### 1. Update Web Manifest

Edit `web/manifest.json`:
```json
{
    "name": "My Leadership Quest",
    "short_name": "MLQ",
    "start_url": ".",
    "display": "standalone",
    "background_color": "#1E3A8A",
    "theme_color": "#1E3A8A",
    "description": "Transform your leadership journey with daily challenges and AI coaching",
    "orientation": "portrait-primary",
    "icons": [...]
}
```

### 2. Update index.html

Edit `web/index.html`:
```html
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="My Leadership Quest - Transform your leadership journey">
  <title>My Leadership Quest</title>
  
  <!-- SEO Meta Tags -->
  <meta property="og:title" content="My Leadership Quest">
  <meta property="og:description" content="Transform your leadership journey">
  <meta property="og:image" content="icons/Icon-512.png">
  
  <!-- Add your favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>
</head>
```

### 3. Configure CORS for Supabase

Your Supabase project needs to allow your web domain:
- Go to Supabase Dashboard → Settings → API
- Add your domain to allowed origins (e.g., `https://yourdomain.com`)

### 4. Update Flutterwave Redirect URL

For web payments, update the redirect URL:
```dart
// In config_service.dart or where you set Flutterwave config
static const String _defaultFlwRedirectUrl = 'https://yourdomain.com/payment-callback';
```

### 5. Handle Deep Links on Web

Web uses URL routing instead of deep links. Your current setup should work, but test payment callbacks.

---

## Testing Checklist

Before deploying to production:

- [ ] Test login/signup on web
- [ ] Test payment flow (Flutterwave redirects)
- [ ] Test all major features (courses, challenges, community)
- [ ] Test on different browsers (Chrome, Firefox, Safari, Edge)
- [ ] Test on mobile browsers
- [ ] Check console for errors
- [ ] Verify images and assets load correctly
- [ ] Test offline behavior (if applicable)
- [ ] Check responsive design on different screen sizes

---

## Performance Optimization

### 1. Enable Web Renderer

```bash
# Use CanvasKit for better performance (larger initial load)
flutter build web --release --web-renderer canvaskit

# Use HTML renderer for faster initial load (some features limited)
flutter build web --release --web-renderer html

# Auto (default - Flutter decides based on device)
flutter build web --release --web-renderer auto
```

### 2. Code Splitting

Add to `web/index.html`:
```html
<script>
  window.flutterConfiguration = {
    canvasKitBaseUrl: "https://unpkg.com/canvaskit-wasm@0.38.0/bin/"
  };
</script>
```

### 3. Enable Caching

Add service worker configuration in `web/index.html`.

---

## Troubleshooting

### Issue: "Failed to load network image"
**Solution:** Ensure CORS is configured for image sources.

### Issue: Payment redirect doesn't work
**Solution:** 
1. Update Flutterwave redirect URL to your web domain
2. Test with `http://localhost:port` first

### Issue: App loads slowly
**Solution:**
1. Use `--web-renderer html` for faster initial load
2. Optimize images and assets
3. Enable caching

### Issue: Features don't work on web
**Solution:** Check browser console for errors. Some native features may need web alternatives.

---

## Recommended Deployment Flow

**For Production:**
1. **Firebase Hosting** - Best for Flutter apps, free tier generous
2. **Netlify** - Great CI/CD, easy custom domains
3. **Vercel** - Fast edge network, good for global users

**Quick Test:**
1. Build: `flutter build web --release`
2. Test locally: `python -m http.server 8000` (in build/web)
3. Open: `http://localhost:8000`

---

## Next Steps

1. Choose a hosting provider
2. Build the web app: `flutter build web --release`
3. Deploy following the provider's instructions
4. Update Supabase CORS settings
5. Update Flutterwave redirect URL
6. Test thoroughly
7. Set up custom domain (optional)

Your app is ready for web deployment! 🚀
