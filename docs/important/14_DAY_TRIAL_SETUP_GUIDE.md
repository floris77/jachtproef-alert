# 🎯 14-Day Trial Setup Guide - Complete Implementation

## ✅ **CONFIRMED PRODUCT ID FORMAT (Google Play Support Verified)**

**Android uses a SINGLE subscription ID with base plans:**
- **Main Subscription ID:** `jachtproef_premium`
- **Base Plans:** `monthly` and `yearly` (configured in Play Console)
- **NOT:** `jachtproef_premium:monthly` or `jachtproef_premium:yearly`

**iOS uses separate product IDs:**
- **Monthly:** `jachtproef_monthly_399`
- **Yearly:** `jachtproef_yearly_2999`

---

This guide will help you set up a **14-day free trial** system for your JachtProef Alert app that works correctly on both iOS and Android.

---

## 🎯 Complete 14-Day Trial Setup Guide
## Apple App Store Connect + Google Play Console

This guide will help you set up **proper 14-day free trials** on both platforms that will fix your subscription bypass issue and ensure users go through proper payment setup.

---

## 🍎 **APPLE APP STORE CONNECT SETUP**

### **Step 1: Access Your Subscriptions**
1. Go to: https://appstoreconnect.apple.com
2. Select your "Jachtproef Alert" app
3. Navigate to: **Features → In-App Purchases and Subscriptions**
4. Click **Manage** next to **Subscriptions**

### **Step 2: Check Current Products**
You already have these products (I saw them in your screenshot):
- ✅ `jachtproef_monthly_399` - €3.99/month
- ✅ `jachtproef_yearly_2999` - €29.99/year  
- ❌ **Status: "Ready to Submit"** (needs to be activated!)

### **Step 3: Configure 14-Day Trials** 
**For Monthly Subscription (`jachtproef_monthly_399`):**
1. Click on the monthly subscription
2. Scroll to **Subscription Pricing**
3. Click **Add Introductory Offer**
4. **Offer Type:** Free Trial
5. **Duration:** 14 days
6. **Availability:** First time subscribers
7. **Markets:** Select all your target countries
8. Click **Save**

**For Yearly Subscription (`jachtproef_yearly_2999`):**
1. Click on the yearly subscription  
2. Scroll to **Subscription Pricing**
3. Click **Add Introductory Offer**
4. **Offer Type:** Free Trial
5. **Duration:** 14 days
6. **Availability:** First time subscribers
7. **Markets:** Select all your target countries  
8. Click **Save**

### **Step 4: CRITICAL - Submit for Review**
1. **Both products must be submitted for Apple review**
2. Click **Submit for Review** on both products
3. **Review takes 1-7 days**
4. **Until approved, trials won't work properly**

---

## 🤖 **GOOGLE PLAY CONSOLE SETUP (NEW)**

### **Step 1: Access Google Play Console**
1. Go to: https://play.google.com/console
2. Sign in with your developer account
3. Select "Jachtproef Alert" app
4. Navigate to: **Monetize → Subscriptions**

### **Step 2: Create Main Subscription**
1. Click **Create subscription**
2. **Subscription ID:** `jachtproef_premium`
3. **Name:** `Jachtproef Alert Premium`
4. **Description:** `Premium access to all Jachtproef Alert features`
5. Click **Save**

### **Step 3: Create Base Plans**

**Monthly Base Plan:**
1. Click **Add base plan**
2. **Base plan ID:** `monthly`
3. **Billing period:** 1 month
4. **Price:** €3.99
5. **Availability:** Your target countries
6. **Auto-renewing:** Yes
7. Click **Save**

**Yearly Base Plan:**  
1. Click **Add base plan**
2. **Base plan ID:** `yearly`
3. **Billing period:** 1 year
4. **Price:** €29.99
5. **Availability:** Your target countries
6. **Auto-renewing:** Yes
7. Click **Save**

### **Step 4: Add 14-Day Trial Offers**

**For Monthly Base Plan:**
1. Select the `monthly` base plan
2. Click **Create offer**
3. **Offer ID:** `monthly_trial`
4. **Offer type:** Free trial
5. **Duration:** 14 days
6. **Eligibility:** New subscribers only
7. **Start date:** Today
8. **End date:** Leave blank (ongoing)
9. Click **Activate**

**For Yearly Base Plan:**
1. Select the `yearly` base plan
2. Click **Create offer**
3. **Offer ID:** `yearly_trial`
4. **Offer type:** Free trial
5. **Duration:** 14 days
6. **Eligibility:** New subscribers only
7. **Start date:** Today
8. **End date:** Leave blank (ongoing)
9. Click **Activate**

### **Step 5: Publish Subscriptions**
1. Review all settings
2. Click **Save and activate**
3. **Takes 2-4 hours to become live**

---

## 🔧 **UPDATE YOUR FLUTTER CODE**

I've already updated your `payment_service.dart`, but here's what changed:

```dart
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
```

---

## 🧪 **TESTING YOUR TRIALS**

### **iOS Testing:**
1. **Use TestFlight** with your Apple ID
2. **Delete and reinstall** app to simulate new user
3. **Go to subscription screen**
4. **Click monthly plan** → Should show Apple trial dialog
5. **Verify:** "14 days free, then €3.99/month"
6. **Must require payment method** even for trial

### **Android Testing:**
1. **Use Internal Testing** in Play Console
2. **Add your Gmail as tester**
3. **Upload APK** with updated code
4. **Install from Play Console link**
5. **Go to subscription screen**
6. **Click monthly plan** → Should show Google Play trial dialog
7. **Verify:** "14 days free, then €3.99/month"
8. **Must require payment method** even for trial

---

## ✅ **PROPER TRIAL FLOW (BOTH PLATFORMS)**

### **What Users Experience:**

**Step 1: User clicks "Start 14-Day Trial"**
- Platform shows subscription dialog
- **"14 days free, then €3.99/month"**
- **"Cancel anytime"**

**Step 2: Platform requires payment method**
- Must add credit card/PayPal
- **No charges for 14 days**
- Payment method validated

**Step 3: Trial starts**
- User gets premium access immediately
- **Subscription created with 14-day delay**
- Your app receives confirmation

**Step 4: Day 14 - Auto billing**
- **Platform automatically charges user**
- **No action needed from user**
- **Premium access continues**

### **What Your App Does:**

```dart
// User clicks trial button
await PaymentService().startTrialWithPlan('monthly');
// This now:
// 1. Shows platform purchase dialog
// 2. Requires payment method setup
// 3. Creates real subscription with 14-day delay
// 4. Grants premium access ONLY after payment setup
// 5. Sets up automatic billing
```

---

## 🚨 **WHAT THIS FIXES**

### **Before (Broken):**
```
User clicks "monthly" → Gets 14 days free immediately
❌ No payment method required
❌ No subscription created  
❌ No billing after 14 days
❌ Lost revenue
```

### **After (Fixed):**
```  
User clicks "monthly" → Platform dialog appears
✅ Payment method required
✅ Real subscription created with trial
✅ Auto-billing after 14 days
✅ Revenue secured
```

---

## 📊 **VERIFICATION CHECKLIST**

### **Apple App Store Connect:**
- [ ] Both products exist with correct IDs
- [ ] 14-day free trial configured on both
- [ ] Products submitted for Apple review
- [ ] Review approved (may take 1-7 days)
- [ ] Products show "Ready for Sale" status

### **Google Play Console:**
- [ ] Main subscription `jachtproef_premium` created
- [ ] Monthly base plan `monthly` created (€3.99)
- [ ] Yearly base plan `yearly` created (€29.99)
- [ ] 14-day trial offers created for both
- [ ] All subscriptions activated
- [ ] Status shows "Active"

### **Flutter App:**
- [ ] Code updated with platform-specific IDs
- [ ] `startTrialWithPlan()` requires purchase
- [ ] No premium access without payment setup
- [ ] Testing completed on both platforms

---

## ⏰ **TIMELINE**

### **Apple:**
- Setup: 30 minutes
- Review: 1-7 days
- **Total: 1-7 days until live**

### **Android:**  
- Setup: 45 minutes
- Activation: 2-4 hours
- **Total: Same day until live**

---

## 🎉 **SUCCESS METRICS**

Once properly set up, you should see:

**Revenue Metrics:**
- ✅ 0% subscription bypass rate  
- ✅ 100% trial users have payment method
- ✅ Automatic billing after 14 days
- ✅ Real subscription revenue

**User Experience:**
- ✅ Clear trial terms shown
- ✅ Proper platform payment dialogs
- ✅ Automatic billing (no user action needed)
- ✅ Easy cancellation in platform settings

---

## 🔗 **Resources**

### **Apple:**
- [App Store Connect Guide](https://developer.apple.com/app-store-connect/)
- [Subscription Setup](https://developer.apple.com/documentation/storekit/in-app_purchase/implementing_introductory_offers_in_your_app)
- [Testing Guide](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox)

### **Google:**
- [Play Console Guide](https://support.google.com/googleplay/android-developer/answer/140504)
- [Subscription Setup](https://developer.android.com/google/play/billing/subscriptions)
- [Testing Guide](https://developer.android.com/google/play/billing/test)

---

**Your 14-day trial system will now work properly on both platforms! 🚀** 