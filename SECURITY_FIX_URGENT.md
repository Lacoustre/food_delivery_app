# 🔒 URGENT: API Key Security Fix

## Your Google API keys were exposed in the GitHub repository. Follow these steps immediately:

### 1. Revoke Exposed Google Maps API Key
1. Go to: https://console.cloud.google.com/apis/credentials
2. Find your exposed API key
3. Click on it and select "DELETE" or "REGENERATE"
4. Create a new API key
5. Add restrictions:
   - Application restrictions: HTTP referrers (websites)
   - Add your domain: `yourdomain.com/*`
   - API restrictions: Only enable "Maps JavaScript API" and "Distance Matrix API"

### 2. Revoke Exposed Firebase Keys
1. Go to: https://console.firebase.google.com
2. Select your project
3. Go to Project Settings > Service Accounts
4. Generate new keys if needed
5. Update Firebase Security Rules to restrict access

### 3. Update Your Local Environment
1. Create a `.env.local` file in `cuisine-webapp/` directory
2. Add your NEW API keys (never commit this file):
   ```
   NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_new_key_here
   ```

### 4. Update Your Code to Use Environment Variables
Replace hardcoded API keys with:
```javascript
const apiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY
```

### 5. Clean Git History (Optional but Recommended)
```bash
# Use BFG Repo Cleaner or git filter-branch to remove keys from history
# Or create a fresh repository if this is early in development
```

### 6. Enable API Key Restrictions
- Set up application restrictions (HTTP referrers)
- Set up API restrictions (only enable needed APIs)
- Set up usage quotas to prevent abuse
- Enable billing alerts

### 7. Monitor for Unauthorized Usage
- Check Google Cloud Console for unusual API usage
- Set up billing alerts
- Monitor Firebase usage

## Prevention for Future:
✅ Always use `.env.local` for secrets
✅ Never commit `.env` files
✅ Use `.env.example` for documentation
✅ Add API key restrictions
✅ Use GitHub secret scanning alerts
✅ Review code before committing

## Need Help?
- Google Cloud Console: https://console.cloud.google.com
- Firebase Console: https://console.firebase.google.com
