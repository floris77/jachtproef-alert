# JachtProef Alert v10.5.9 - Android Release

## Version Information
- **Version**: 10.5.9
- **Build Number**: 10443
- **Release Date**: July 6, 2024

## What's New
- ✅ **Fixed Android Trial Purchase Issue**: Resolved platform-specific product ID configuration
- ✅ **Platform-Specific Billing**: Android now uses correct `jachtproef_premium` product ID
- ✅ **iOS Compatibility**: No changes to iOS functionality - continues to work perfectly
- ✅ **Google Play Store Ready**: Properly signed and optimized for store distribution

## Technical Changes
- Updated plan selection screen to use platform-specific product IDs
- Android: Uses `jachtproef_premium` (Google Play Console format)
- iOS: Uses `jachtproef_monthly_399` and `jachtproef_yearly_2999` (App Store Connect format)

## Files Included
- `app-release.aab` (50.9MB) - **Use this for Google Play Store upload**
- `app-release.apk` (59.7MB) - Alternative APK format

## Upload Instructions
1. Go to Google Play Console
2. Navigate to your app
3. Go to "Release" → "Production" (or "Internal testing")
4. Upload `app-release.aab` file
5. Add release notes
6. Review and publish

## Testing Notes
- Android billing now works correctly with Google Play Store
- Trial purchases should no longer get stuck
- iOS functionality remains unchanged 