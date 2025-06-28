# iOS Product Configuration Check Guide

## 🚨 **CRITICAL: Check Your App Store Connect Setup**

The issue is that your iOS app can't find the subscription products. This means either:

1. **Products don't exist** in App Store Connect
2. **Products exist but aren't approved**
3. **Products aren't included in TestFlight build**

---

## 📋 **Step 1: Check App Store Connect**

1. Go to: https://appstoreconnect.apple.com
2. Select your "JachtProef Alert" app
3. Go to **"Features" → "In-App Purchases"**

### **What to Look For:**

**✅ CORRECT SETUP:**
- You should see 2 subscription products:
  - `jachtproef_monthly_399` (Monthly subscription)
  - `jachtproef_yearly_2999` (Yearly subscription)

**❌ MISSING SETUP:**
- No products listed
- Only 1 product
- Different product IDs

---

## 🔧 **Step 2: Create Missing Products**

If products don't exist, create them:

### **Monthly Subscription:**
1. Click **"+" → "Auto-Renewable Subscriptions"**
2. **Product ID:** `jachtproef_monthly_399`
3. **Reference Name:** JachtProef Alert Monthly
4. **Subscription Group:** JachtProef Premium (create new)
5. **Price:** €3.99/month
6. **Subscription Duration:** 1 month
7. **Free Trial:** 14 days
8. **Display Name:** Maandelijks Abonnement
9. **Description:** Krijg toegang tot alle premium functies van JachtProef Alert

### **Yearly Subscription:**
1. Click **"+" → "Auto-Renewable Subscriptions"**
2. **Product ID:** `jachtproef_yearly_2999`
3. **Reference Name:** JachtProef Alert Yearly
4. **Subscription Group:** JachtProef Premium (same group)
5. **Price:** €29.99/year
6. **Subscription Duration:** 1 year
7. **Free Trial:** 14 days
8. **Display Name:** Jaarlijks Abonnement
9. **Description:** Het beste aanbod - bespaar 37% met een jaarlijks abonnement

---

## ✅ **Step 3: Configure Trial Period**

1. In the subscription group settings:
   - Set **Introductory Offers**: 14 days free trial
   - Check **Eligible for Introductory Offer**: Yes
   - Set **Trial Duration**: 14 days

---

## 📱 **Step 4: Include in TestFlight**

1. Go to **"TestFlight" → "Builds"**
2. Select your latest build
3. Go to **"Test Information"**
4. Make sure **"In-App Purchases"** are included
5. Verify both products are listed

---

## 🧪 **Step 5: Test the Fix**

1. **Update your TestFlight build** with the debug code
2. **Install the app** on your iPhone 12
3. **Go to subscription screen**
4. **Check the debug section** - it should show:
   - Available: true
   - Products loaded: 2
   - Products: jachtproef_monthly_399, jachtproef_yearly_2999

---

## 🔍 **Common Issues:**

### **Issue 1: Products Not Found**
- **Cause:** Products don't exist in App Store Connect
- **Fix:** Create the products as shown above

### **Issue 2: Products Not Approved**
- **Cause:** Products exist but status is "Waiting for Review"
- **Fix:** Submit products for review or use "Ready to Submit" status

### **Issue 3: Products Not in TestFlight**
- **Cause:** Products aren't included in the TestFlight build
- **Fix:** Include in-app purchases in TestFlight build

### **Issue 4: Wrong Product IDs**
- **Cause:** Code uses different IDs than App Store Connect
- **Fix:** Update either the code or App Store Connect to match

---

## 📞 **Need Help?**

If you're still having issues:

1. **Check the debug output** in the app
2. **Verify product IDs** match exactly
3. **Ensure products are approved** in App Store Connect
4. **Test with a fresh TestFlight build**

The debug section in the app will show you exactly what's happening! 