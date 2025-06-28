# 🤖 Android Subscription Setup Guide - Google Play Console

## 🚨 **CRITICAL: This Will Fix Your Subscription Bypass Issue**

Currently, Android users can bypass payments because **no subscription products exist in Google Play Console**. This guide will fix that.

## ✅ **CONFIRMED PRODUCT ID FORMAT (Google Play Support Verified)**

**Android uses a SINGLE subscription ID with base plans:**
- **Main Subscription ID:** `jachtproef_premium`
- **Base Plans:** `monthly` and `yearly` (configured in Play Console)
- **NOT:** `jachtproef_premium:monthly` or `jachtproef_premium:yearly`

**iOS uses separate product IDs:**
- **Monthly:** `jachtproef_monthly_399`
- **Yearly:** `jachtproef_yearly_2999`

---

## 📋 **Step 1: Access Google Play Console**

1. Go to: https://play.google.com/console
2. Sign in with your developer account
3. Select your "Jachtproef Alert" app
4. Navigate to: **"Monetize" → "Subscriptions"**

---

## 📦 **Step 2: Create Your Main Subscription Product**

### **Create New Subscription:**
1. Click **"Create subscription"**
2. **Subscription ID:** `jachtproef_premium`
3. **Name:** `Jachtproef Alert Premium`
4. **Description:** `Premium access to all Jachtproef Alert features`

---

## 💰 **Step 3: Create Base Plans (Pricing Tiers)**

### **Monthly Base Plan:**
1. Click **"Add base plan"**
2. **Base plan ID:** `monthly`
3. **Billing period:** `1 month`
4. **Price:** `€3.99`
5. **Availability:** Select your target countries

### **Yearly Base Plan:**
1. Click **"Add base plan"** 
2. **Base plan ID:** `yearly`
3. **Billing period:** `1 year` 
4. **Price:** `€29.99`
5. **Availability:** Select your target countries

---

## 🎁 **Step 4: Add Free Trial Offers**

### **For Monthly Plan:**
1. Select the `monthly` base plan
2. Click **"Add offer"**
3. **Offer ID:** `monthly_trial`
4. **Offer type:** `Free trial`
5. **Duration:** `14 days`
6. **Eligibility:** `New subscribers only`

### **For Yearly Plan:**
1. Select the `yearly` base plan  
2. Click **"Add offer"**
3. **Offer ID:** `yearly_trial`
4. **Offer type:** `Free trial`
5. **Duration:** `14 days`
6. **Eligibility:** `New subscribers only`

---

## 🔧 **Step 5: Update Your Flutter Code**

Your current code only works for Apple. Here's the fix for both platforms:

### **Update payment_service.dart:**

```dart
class PaymentService {
  // Platform-specific product IDs
  static String get monthlySubscriptionId {
    if (Platform.isIOS) {
      return 'jachtproef_monthly_399';  // Apple format
    } else if (Platform.isAndroid) {
      return 'jachtproef_premium';  // Google format - main subscription ID
    }
    throw UnsupportedError('Platform not supported');
  }
  
  static String get yearlySubscriptionId {
    if (Platform.isIOS) {
      return 'jachtproef_yearly_2999';  // Apple format
    } else if (Platform.isAndroid) {
      return 'jachtproef_premium';  // Google format - same subscription ID, different base plan
    }
    throw UnsupportedError('Platform not supported');
  }
}
```

---

## 📱 **Step 6: Test Your Setup**

### **Testing Requirements:**
1. **Create a test account** in Google Play Console
2. **Add your Gmail as a tester**
3. **Upload a new APK** with updated code
4. **Test the subscription flow** on Android device/emulator

### **Testing Steps:**
1. Install app from Google Play Console (internal testing)
2. Go to subscription screen
3. Click monthly/yearly button
4. **Should now show Google Play purchase dialog** ✅
5. **Should NOT bypass to premium access** ✅

---

## 🚀 **Step 7: Publish Your Subscriptions**

1. **Review all settings**
2. **Save and activate** base plans
3. **Publish subscription** (takes 2-4 hours to be live)
4. **Update your app** and push to Play Store

---

## 📚 **Official Google Resources:**

- **Main Guide:** https://developer.android.com/google/play/billing/subscriptions
- **Play Console Help:** https://support.google.com/googleplay/android-developer/answer/140504
- **Testing Guide:** https://developer.android.com/google/play/billing/test

---

## ✅ **What This Fixes:**

**Before:** 
- Android user clicks "monthly" → gets 14 days free premium (BYPASS!)
- No payment method required
- No recurring billing after trial

**After:**
- Android user clicks "monthly" → Google Play purchase dialog appears
- Must add payment method to start trial
- Automatic billing after 14 days = REVENUE! 💰

---

## 🔍 **Final Structure:**

### **Apple (App Store Connect):**
```
🍎 jachtproef_monthly_399 (€3.99/month + 14-day trial)
🍎 jachtproef_yearly_2999 (€29.99/year + 14-day trial)
```

### **Google (Play Console):**
```
�� jachtproef_premium (main subscription ID)
   ├── Base Plan: monthly (€3.99/month)
   │   └── Offer: monthly_trial (14 days free)
   └── Base Plan: yearly (€29.99/year)
       └── Offer: yearly_trial (14 days free)
```

**Note:** Android uses ONE subscription ID (`jachtproef_premium`) with different base plans, NOT separate product IDs like iOS.

---

## ⚠️ **Important Notes:**

1. **Subscriptions take 2-4 hours** to become active after publishing
2. **You must update your app** with the new product IDs
3. **Test thoroughly** before releasing to production
4. **Both platforms will now work correctly** 🎉

Ready to fix your subscription bypass issue! 🚀 