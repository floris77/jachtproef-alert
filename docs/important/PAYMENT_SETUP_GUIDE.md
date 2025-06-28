# JachtProef Alert - Payment Setup Guide

This guide will help you set up the payment system for your JachtProef Alert app with a **14-day free trial** and two subscription options.

## 📋 Overview

Your app now uses a **free trial model** with these features:
- **14-day free trial** for all new users
- **Monthly subscription**: €3.99/month  
- **Yearly subscription**: €29.99/year (saves 37%)
- Automatic trial-to-paid conversion
- Firebase integration for subscription tracking

## 📱 Product Configuration

### Product IDs to Create:
- `jachtproef_monthly_399` - Monthly subscription (€3.99)
- `jachtproef_yearly_2999` - Yearly subscription (€29.99)

## 🍎 Apple App Store Connect Setup

### 1. Create Subscriptions

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app → **Features** → **In-App Purchases**
3. Click **+** → **Auto-Renewable Subscriptions**

#### Monthly Subscription:
- **Product ID**: `jachtproef_monthly_399`
- **Reference Name**: JachtProef Alert Monthly
- **Subscription Group**: JachtProef Premium (create new)
- **Price**: €3.99/month
- **Subscription Duration**: 1 month
- **Free Trial**: 14 days
- **Display Name**: Maandelijks Abonnement
- **Description**: Krijg toegang tot alle premium functies van JachtProef Alert

#### Yearly Subscription:
- **Product ID**: `jachtproef_yearly_2999`
- **Reference Name**: JachtProef Alert Yearly
- **Subscription Group**: JachtProef Premium (same group)
- **Price**: €29.99/year
- **Subscription Duration**: 1 year
- **Free Trial**: 14 days
- **Display Name**: Jaarlijks Abonnement
- **Description**: Het beste aanbod - bespaar 37% met een jaarlijks abonnement

### 2. Configure Trial Period

1. In the subscription group settings:
   - Set **Introductory Offers**: 14 days free trial
   - Check **Eligible for Introductory Offer**: Yes
   - Set **Trial Duration**: 14 days

### 3. App Review Information

Add these details for App Review:
- **Screenshot**: Include subscription screen screenshots
- **Review Notes**: "App offers hunting exam notifications with 14-day free trial, then €3.99/month or €29.99/year"

## 🤖 Google Play Console Setup

### 1. Create Subscription Products

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app → **Monetize** → **Products** → **Subscriptions**
3. Click **Create subscription**

#### Monthly Subscription:
- **Product ID**: `jachtproef_monthly_399`
- **Name**: JachtProef Alert Maandelijks
- **Description**: Alle premium functies voor jachtproef alerts
- **Price**: €3.99
- **Billing period**: 1 month
- **Free trial period**: 14 days
- **Grace period**: 7 days

#### Yearly Subscription:
- **Product ID**: `jachtproef_yearly_2999`
- **Name**: JachtProef Alert Jaarlijks  
- **Description**: Jaarlijks abonnement - beste waarde met 37% korting
- **Price**: €29.99
- **Billing period**: 1 year
- **Free trial period**: 14 days
- **Grace period**: 7 days

### 2. Set Up Base Plans

For each subscription:
1. Click **Add base plan**
2. Set renewal type to **Auto-renewing**
3. Configure the billing period and price
4. Add **Free trial offer**: 14 days

### 3. Testing

1. Add test accounts in **Setup** → **License Testing**
2. Upload a test version with the subscription products
3. Test the free trial flow

## 🔧 Code Configuration

### 1. Update Stripe Keys (Optional)

In `lib/services/payment_service.dart`, replace the test keys:

```dart
static const String stripePublishableKey = 'pk_live_your_key_here';
static const String stripeSecretKey = 'sk_live_your_key_here'; // Keep on backend
```

### 2. Firebase Security Rules

Update your Firestore rules to protect subscription data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Protect subscription data
      match /subscription/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

## 🧪 Testing Your Payment System

### 1. Test Free Trial Flow

1. Create a new account
2. Tap "Start Gratis Proefperiode" 
3. Verify 14-day access is granted
4. Check Firebase for correct trial data

### 2. Test Subscription Purchase

1. After trial period or direct purchase
2. Test both monthly and yearly options
3. Verify subscription status in Firebase
4. Test purchase restoration

### 3. Test Trial Expiration

1. Manually adjust trial end date in Firebase
2. Verify app behavior when trial expires
3. Test subscription prompts

## 📊 Analytics & Monitoring

### Key Metrics to Track:

1. **Trial Conversion Rate**: % of trial users who subscribe
2. **Trial Completion Rate**: % who use full 14 days
3. **Plan Preference**: Monthly vs yearly selection
4. **Churn Rate**: Subscription cancellations
5. **Revenue Metrics**: MRR, ARR, LTV

### Firebase Analytics Events:

```dart
// Track trial start
AnalyticsService.logUserAction('trial_started');

// Track subscription purchase
AnalyticsService.logUserAction('subscription_purchased', parameters: {
  'plan_type': 'monthly', // or 'yearly'
  'price': '3.90',
  'currency': 'EUR'
});

// Track trial expiration
AnalyticsService.logUserAction('trial_expired');
```

## 🚀 Launch Checklist

- [ ] Both subscription products created in App Store Connect
- [ ] Both subscription products created in Google Play Console  
- [ ] Free trial periods configured (14 days)
- [ ] Pricing set correctly (€3.99/month, €29.99/year)
- [ ] App tested with real payment flow
- [ ] Firebase rules updated for security
- [ ] Analytics tracking implemented
- [ ] App Store/Play Store descriptions updated
- [ ] Screenshots updated to show trial offer

## 🎯 Revenue Optimization Tips

### 1. Trial Length Optimization
- 14 days is optimal for utility apps
- Consider A/B testing 7 vs 14 days
- Monitor completion rates

### 2. Pricing Strategy
- €3.99/month is competitive for Netherlands market
- €29.99/year offers compelling 37% savings
- Consider seasonal promotions

### 3. Conversion Optimization
- Show value during trial period
- Send reminder notifications at day 10
- Highlight annual savings (37% off)
- Show trial countdown in app

### 4. Retention Strategies
- Immediate value delivery
- Regular feature updates
- Responsive customer support
- Community building

## 📞 Support Information

For questions about payment setup:
- **Firebase**: Check Firebase Console for subscription data
- **Apple**: App Store Connect support
- **Google**: Google Play Console support
- **Stripe**: Stripe Dashboard and documentation

## 🔒 Security Best Practices

1. **Never store payment credentials in app**
2. **Validate subscriptions server-side** 
3. **Use Firebase security rules**
4. **Implement proper error handling**
5. **Regular security audits**
6. **Monitor for subscription fraud**

---

Your 14-day free trial payment system is now ready to generate revenue while providing excellent user experience! 🎉 