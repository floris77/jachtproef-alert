# PaymentService Initialization Fix - Apple Payment Dialog Issue

## Issue Description
Users were unable to see the Apple payment dialog when trying to purchase subscriptions. The button would be pressed but no payment dialog would appear.

## Root Cause Analysis

### The Problem
The PaymentService was being **completely reset** after successful initialization, causing the payment flow to fail.

### Timeline of Events
1. **PaymentService initializes successfully** ✅
   - `_isAvailable = true`
   - Products loaded: `jachtproef_monthly_399`, `jachtproef_yearly_2999`
   - `_inAppPurchase` properly initialized
   - Purchase stream listener set up

2. **Device state cleanup runs** ❌
   - `_clearDeviceStateOnStartup()` called in main.dart
   - This calls `PaymentService().cleanupOldDormantPayments()`
   - `cleanupOldDormantPayments()` **completely resets** PaymentService state:
     ```dart
     _isAvailable = false;
     _products.clear();
     _inAppPurchase = null;
     _isInitializing = false;
     ```

3. **User tries to purchase** ❌
   - PaymentService checks: `_isAvailable: false, _inAppPurchase: false`
   - Returns "payment_not_available" error
   - No Apple payment dialog appears

## Solution Implemented

### 1. Removed Dangerous Cleanup Call
**File:** `lib/main.dart`
```dart
// BEFORE (BROKEN):
await _clearDeviceStateOnStartup();

// AFTER (FIXED):
// CRITICAL: Do NOT call _clearDeviceStateOnStartup() here
// This method calls PaymentService().cleanupOldDormantPayments() which
// completely resets the PaymentService state after it was successfully initialized
DebugLoggingService().info('🚫 Skipping device state cleanup to preserve PaymentService initialization', tag: 'STARTUP');
```

### 2. Added Comprehensive Warnings
**File:** `lib/services/payment_service.dart`
```dart
/// ⚠️ WARNING: This method COMPLETELY RESETS the PaymentService state!
/// It should ONLY be called for debugging/testing, NEVER during normal app startup.
/// 
/// This method resets:
/// - _isAvailable = false
/// - _products.clear()
/// - _inAppPurchase = null
/// - _isInitializing = false
/// 
/// If called after initialization, it will break the payment flow.
/// Use forceRefreshPaymentService() instead if you need to refresh the service.
```

### 3. Ensured Singleton Instance Usage
**File:** `lib/main.dart`
```dart
// CRITICAL: Use the SAME PaymentService instance that was initialized
// PaymentService uses singleton pattern, so this gets the initialized instance
// ChangeNotifierProvider.value() ensures the widget tree uses this instance
final paymentService = PaymentService();
paymentService.clearNavigationFlag();
```

## Critical Rules for Future Development

### ✅ DO:
- Let PaymentService initialize normally during app startup
- Use `forceRefreshPaymentService()` if you need to refresh the service
- Call `cleanupOldDormantPayments()` only for debugging/testing via debug settings
- Use the singleton PaymentService instance consistently

### ❌ DON'T:
- Call `_clearDeviceStateOnStartup()` during normal app startup
- Call `cleanupOldDormantPayments()` after PaymentService initialization
- Create new PaymentService instances that bypass initialization
- Reset PaymentService state without re-initializing

## Verification Steps

### To verify the fix is working:
1. Check logs for successful initialization:
   ```
   🔍 Initialize: Products loaded: 2
   🔍 Initialize: Initialization complete - Available: true, Products: 2
   ```

2. Check logs during purchase attempt:
   ```
   🔍 Purchase Error Handling: _isAvailable: true, _inAppPurchase: true
   ✅ Purchase Error Handling: Payment service is available
   ```

3. Apple payment dialog should appear when user taps "Start Gratis Proefperiode"

### To test if the issue returns:
1. Manually call `cleanupOldDormantPayments()` via debug settings
2. Try to purchase - should fail with "payment_not_available"
3. Restart app - should work again

## Related Files Modified

1. **`lib/main.dart`**
   - Removed `_clearDeviceStateOnStartup()` call
   - Added comprehensive comments explaining the fix
   - Ensured singleton PaymentService instance usage

2. **`lib/services/payment_service.dart`**
   - Added critical warnings to `cleanupOldDormantPayments()`
   - Added comprehensive documentation at class level
   - Enhanced logging to track state changes

3. **`lib/services/auth_service.dart`**
   - Removed direct InAppPurchase calls that could interfere with PaymentService

## Future Maintenance

### When modifying PaymentService:
1. **Always check** if changes affect the initialization flow
2. **Never reset** PaymentService state without re-initializing
3. **Test thoroughly** on real iOS devices with TestFlight
4. **Monitor logs** for initialization success/failure

### When adding new cleanup methods:
1. **Consider the timing** - don't call during startup
2. **Use `forceRefreshPaymentService()`** instead of full reset
3. **Add comprehensive warnings** about state reset
4. **Test the payment flow** after any cleanup

## Debugging Commands

### To check PaymentService status:
```dart
final diagnostics = await PaymentService().getDiagnosticInfo();
print('PaymentService diagnostics: $diagnostics');
```

### To force refresh (safe):
```dart
await PaymentService().forceRefreshPaymentService();
```

### To reset completely (dangerous, only for debugging):
```dart
await PaymentService().cleanupOldDormantPayments();
await PaymentService().initialize(); // Must re-initialize after reset
```

---

**Last Updated:** [Current Date]
**Issue Resolved:** Apple payment dialog not appearing on iOS
**Status:** ✅ FIXED 