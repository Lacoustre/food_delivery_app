# Firebase Configuration Update Instructions

## Steps to Replace GoogleService-Info.plist

1. **Download the new configuration file:**
   - Go to your Firebase Console: https://console.firebase.google.com
   - Select your project
   - Go to Project Settings (gear icon)
   - Under "Your apps" section, find your iOS app
   - Click "Download GoogleService-Info.plist"

2. **Replace the existing file:**
   - Navigate to: `/Users/khestra/Desktop/african_cuisine/driver_app/ios/Runner/`
   - Replace the existing `GoogleService-Info.plist` with your new one

3. **Update Android configuration (if needed):**
   - Download `google-services.json` from Firebase Console
   - Replace: `/Users/khestra/Desktop/african_cuisine/driver_app/android/app/google-services.json`

4. **Clean and rebuild:**
   ```bash
   cd /Users/khestra/Desktop/african_cuisine/driver_app
   flutter clean
   flutter pub get
   cd ios
   pod install
   cd ..
   flutter run
   ```

## Important Notes:
- Make sure the Bundle ID in your new Firebase project matches: `com.khestra.africanCuisine`
- Ensure all Firebase services you're using are enabled in the new project
- Update any Firebase Security Rules if needed