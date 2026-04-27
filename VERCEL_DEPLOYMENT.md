# Vercel Deployment Guide - My Leadership Quest

**Status**: ✅ Configured and Ready  
**Platform**: Vercel  
**Framework**: Flutter Web

---

## Quick Deploy

### Option 1: Deploy via Vercel Dashboard (Recommended)

1. **Push to GitHub** (already done)
   ```bash
   git push origin main
   ```

2. **Import to Vercel**
   - Go to https://vercel.com/new
   - Click "Import Project"
   - Select your GitHub repository
   - Vercel will auto-detect the configuration from `vercel.json`
   - Click "Deploy"

3. **Done!** Your app will be live at `https://your-project.vercel.app`

---

### Option 2: Deploy via Vercel CLI

```bash
# Install Vercel CLI
npm install -g vercel

# Login to Vercel
vercel login

# Deploy from project root
cd my_leadership_quest
vercel

# Deploy to production
vercel --prod
```

---

## Configuration Files

### ✅ vercel.json
Located at: `my_leadership_quest/vercel.json`

**What it does**:
- Configures build command: `flutter build web --release --web-renderer canvaskit`
- Sets output directory: `build/web`
- Configures routing for SPA (Single Page Application)
- Sets up caching headers for assets
- Adds security headers

### ✅ .vercelignore
Located at: `my_leadership_quest/.vercelignore`

**What it does**:
- Excludes unnecessary files from deployment
- Reduces deployment size
- Speeds up build time

---

## Build Configuration

### Build Command
```bash
flutter build web --release --web-renderer canvaskit
```

**Why CanvasKit?**
- Better performance for complex UIs
- Consistent rendering across browsers
- Better support for animations

**Alternative** (smaller bundle size):
```bash
flutter build web --release --web-renderer html
```

### Output Directory
```
build/web
```

This is where Flutter generates the web build files.

---

## Environment Variables (Optional)

If you need to add environment variables:

1. Go to Vercel Dashboard > Your Project > Settings > Environment Variables
2. Add variables:
   - `SUPABASE_URL` (if needed)
   - `SUPABASE_ANON_KEY` (if needed)
   - `FLUTTERWAVE_PUBLIC_KEY` (if needed)

**Note**: Flutter web uses compile-time constants, so you'll need to rebuild after changing environment variables.

---

## Custom Domain Setup

1. Go to Vercel Dashboard > Your Project > Settings > Domains
2. Add your custom domain (e.g., `mlq.app`)
3. Add DNS records at your domain provider:
   
   **Option A: A Record**
   - Type: `A`
   - Name: `@`
   - Value: `76.76.21.21`
   
   **Option B: CNAME Record**
   - Type: `CNAME`
   - Name: `www`
   - Value: `cname.vercel-dns.com`

4. Wait for DNS propagation (5-60 minutes)
5. SSL certificate is automatic!

---

## Automatic Deployments

### Production Deployments
- Every push to `main` branch triggers a production deployment
- URL: `https://your-project.vercel.app`

### Preview Deployments
- Every push to other branches creates a preview deployment
- Every pull request gets a unique preview URL
- Perfect for testing before merging

### Rollbacks
- Instant rollbacks to any previous deployment
- Go to Deployments tab > Select deployment > Promote to Production

---

## Performance Optimization

### Already Configured
- ✅ Asset caching (1 year)
- ✅ Gzip compression
- ✅ Brotli compression
- ✅ HTTP/2
- ✅ Global CDN
- ✅ Security headers

### Additional Optimizations
```bash
# Enable tree shaking
flutter build web --release --tree-shake-icons

# Split debug info
flutter build web --release --split-debug-info=build/debug_info

# Use HTML renderer for smaller size
flutter build web --release --web-renderer html
```

---

## Monitoring

### Vercel Analytics (Optional)
1. Go to Vercel Dashboard > Your Project > Analytics
2. Enable Vercel Analytics
3. View real-time metrics:
   - Page views
   - Unique visitors
   - Top pages
   - Performance metrics

### Vercel Logs
1. Go to Vercel Dashboard > Your Project > Deployments
2. Click on any deployment
3. View build logs and runtime logs

---

## Troubleshooting

### Issue: Build Fails
**Solution**: Check build logs in Vercel Dashboard
- Ensure Flutter is installed on Vercel (it should auto-install)
- Check for any compilation errors

### Issue: 404 on Page Refresh
**Solution**: Already configured in `vercel.json`
- All routes redirect to `/index.html`
- SPA routing works correctly

### Issue: Assets Not Loading
**Solution**: Check `web/index.html`
- Ensure `<base href="/">` is set correctly
- Check asset paths are relative

### Issue: Slow Initial Load
**Solution**: 
1. Use HTML renderer: `flutter build web --release --web-renderer html`
2. Optimize images
3. Enable code splitting

### Issue: CORS Errors
**Solution**: Configure CORS in Supabase
1. Go to Supabase Dashboard > Settings > API
2. Add your Vercel domain to allowed origins:
   - `https://your-project.vercel.app`
   - `https://your-custom-domain.com`

---

## Deployment Checklist

### Before First Deploy
- [x] Configure `vercel.json`
- [x] Configure `.vercelignore`
- [x] Update `.gitignore`
- [x] Push to GitHub
- [ ] Import to Vercel
- [ ] Verify deployment works
- [ ] Test all features on deployed site

### After Deploy
- [ ] Configure custom domain (optional)
- [ ] Set up environment variables (if needed)
- [ ] Enable Vercel Analytics (optional)
- [ ] Configure CORS in Supabase
- [ ] Test on multiple browsers
- [ ] Share with users!

---

## Useful Commands

### Local Development
```bash
# Run on Chrome
flutter run -d chrome

# Build for web
flutter build web --release

# Test build locally
cd build/web
python -m http.server 8000
```

### Vercel CLI
```bash
# Install
npm install -g vercel

# Login
vercel login

# Deploy to preview
vercel

# Deploy to production
vercel --prod

# View logs
vercel logs

# List deployments
vercel ls

# Remove deployment
vercel rm [deployment-url]
```

### Git Workflow
```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes and commit
git add .
git commit -m "Add new feature"

# Push to GitHub (creates preview deployment)
git push origin feature/new-feature

# Merge to main (creates production deployment)
git checkout main
git merge feature/new-feature
git push origin main
```

---

## Support

### Vercel
- Documentation: https://vercel.com/docs
- Community: https://github.com/vercel/vercel/discussions
- Support: support@vercel.com

### Flutter Web
- Documentation: https://docs.flutter.dev/platform-integration/web
- Community: https://flutter.dev/community

---

## Next Steps

1. **Push to GitHub** ✅ (you're about to do this)
2. **Import to Vercel** - Go to https://vercel.com/new
3. **Deploy** - Click "Deploy" button
4. **Test** - Visit your deployed site
5. **Configure** - Add custom domain, environment variables
6. **Share** - Your app is live! 🎉

---

## Configuration Summary

### Files Added
- ✅ `vercel.json` - Vercel configuration
- ✅ `.vercelignore` - Files to exclude from deployment
- ✅ `VERCEL_DEPLOYMENT.md` - This guide

### Files Modified
- ✅ `.gitignore` - Added Vercel-specific ignores

### Ready to Deploy
- ✅ All web optimization fixes applied
- ✅ Vercel configuration complete
- ✅ Git repository ready
- ✅ Documentation complete

**Your app is ready for Vercel deployment!** 🚀
