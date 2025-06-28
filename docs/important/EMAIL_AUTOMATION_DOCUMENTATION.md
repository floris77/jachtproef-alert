# 📧 JachtProef Alert - Complete Email Automation Documentation

## 🎯 Overview

This document provides a complete overview of all automated email systems implemented in JachtProef Alert. Use this as a reference to understand what emails are sent, when they're triggered, and how the flows work.

---

## 📊 Email System Summary

| Email Type | Trigger | Timing | Status | Purpose |
|------------|---------|--------|--------|---------|
| **Welcome Email** | User registration | Immediate | ✅ Active | Onboard new users |
| **Subscription Receipt** | Successful purchase | Immediate | ✅ Active | Confirm subscription |
| **Plan Abandonment** | Plan visit without purchase | 24 hours later | ✅ Active | Recover conversions |
| **Match Notifications** | User-enabled notifications | User-defined timing | ✅ Active | Notify about hunting matches |

---

## 🔄 Complete Email Flows

### **1. 👋 Welcome Email Flow**

**Trigger**: User creates a new account
**Timing**: Immediate (within seconds)
**Cloud Function**: `send-welcome-email`

```
User Registration Flow:
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ User Registers  │───▶│ AuthService      │───▶│ Welcome Email   │
│ (Email/Apple)   │    │ _sendWelcomeEmail│    │ Sent via Resend │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

**Email Content**:
- **Subject**: "🎯 Welkom bij JachtProef Alert!"
- **Content**: Welcome message, app introduction, next steps
- **CTA**: "Start je Premium proefperiode"
- **From**: `JachtProef Alert <onboarding@resend.dev>`

**Code Location**:
- **Service**: `lib/services/welcome_email_service.dart`
- **Integration**: `lib/services/auth_service.dart` → `_sendWelcomeEmailAsync()`
- **Cloud Function**: `cloud_function_deploy/main.py` → `send_welcome_email()`

---

### **2. 💳 Subscription Receipt Flow**

**Trigger**: User completes subscription purchase
**Timing**: Immediate after successful payment
**Cloud Function**: `send-subscription-email`

```
Subscription Purchase Flow:
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Payment Success │───▶│ PaymentService   │───▶│ Receipt Email   │
│ (Trial/Premium) │    │ sendSubscription │    │ Sent via Resend │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

**Email Content**:
- **Subject**: "✅ Je JachtProef Alert Premium is actief!"
- **Content**: Subscription confirmation, amount paid, billing details
- **Details**: Shows plan type (Monthly €3.99 or Yearly €29.99)
- **CTA**: "Open JachtProef Alert"

**Code Location**:
- **Integration**: `lib/services/payment_service.dart` → `sendSubscriptionEmail()`
- **Cloud Function**: `cloud_function_deploy/main.py` → `send_subscription_email()`

---

### **3. ⏰ Plan Abandonment Recovery Flow**

**Trigger**: User visits plan selection but doesn't purchase within 24 hours
**Timing**: 24 hours after plan selection visit
**Cloud Function**: `send-plan-abandonment-email`

```
Plan Abandonment Flow:
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ User Visits     │───▶│ Track Visit      │───▶│ Wait 24 Hours   │───▶│ Check & Send    │
│ Plan Selection  │    │ (Firestore)      │    │ (Auto Delay)    │    │ Abandonment     │
└─────────────────┘    └──────────────────┘    └─────────────────┘    └─────────────────┘
```

**Email Content**:
- **Subject**: "🎯 Vergeten je Premium abonnement te activeren? 14 dagen gratis wacht nog steeds!"
- **Content**: Personalized reminder, Premium benefits, pricing display
- **Pricing**: €3,99/month and €29,99/year with 14-day trial
- **CTA**: "🚀 Start je 14 dagen gratis proefperiode"

**Tracking Data** (Firestore: `plan_abandonment_tracking`):
```json
{
  "userId": "user123",
  "userEmail": "user@example.com", 
  "userName": "John",
  "visitedPlanSelection": true,
  "visitTimestamp": "2024-01-01T10:00:00Z",
  "completedPurchase": false,
  "abandonmentEmailSent": false
}
```

**Code Location**:
- **Service**: `lib/services/plan_abandonment_service.dart`
- **Integration**: `lib/screens/plan_selection_screen.dart` → `initState()`
- **Tracking**: `lib/services/payment_service.dart` → purchase completion
- **Cloud Function**: `cloud_function_deploy/main.py` → `send_plan_abandonment_email()`

---

### **4. 🎯 Match Notification Flow**

**Trigger**: User enables notifications for specific hunting matches
**Timing**: User-defined (7 days, 3 days, 1 day, 2 hours before match)
**Cloud Function**: `send-match-notification`

```
Match Notification Flow:
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ User Enables    │───▶│ Store Preference │───▶│ Match Date      │───▶│ Send Notification│
│ Match Alerts    │    │ (Firestore)      │    │ Approaches      │    │ Email + Push    │
└─────────────────┘    └──────────────────┘    └─────────────────┘    └─────────────────┘
```

**Email Types**:

**A. Enrollment Opening**:
- **Subject**: "🎯 Inschrijving geopend: [Match Name]"
- **Content**: Match details, enrollment now open
- **CTA**: "🎯 Open JachtProef Alert"

**B. Match Reminder**:
- **Subject**: "📅 Herinnering: [Match Name] is binnenkort"
- **Content**: Upcoming match reminder, checklist
- **CTA**: Success wishes

**Code Location**:
- **Integration**: Match detail screens (when user taps "Meldingen aan")
- **Cloud Function**: `cloud_function_deploy/main.py` → `send_match_notification()`

---

## 🔧 Technical Implementation

### **Cloud Functions Deployed**

| Function Name | URL | Purpose | Status |
|---------------|-----|---------|--------|
| `send-welcome-email` | `us-central1-jachtproefalert.cloudfunctions.net/send-welcome-email` | New user onboarding | ✅ |
| `send-subscription-email` | `us-central1-jachtproefalert.cloudfunctions.net/send-subscription-email` | Payment confirmations | ✅ |
| `send-match-notification` | `us-central1-jachtproefalert.cloudfunctions.net/send-match-notification` | Match alerts | ✅ |
| `send-plan-abandonment-email` | `us-central1-jachtproefalert.cloudfunctions.net/send-plan-abandonment-email` | Conversion recovery | ✅ |

### **Email Provider**
- **Service**: Resend API
- **API Key**: `re_8AvpZCWL_4jPJQY4v99Ypmc6jBhZNijoj`
- **From Address**: `JachtProef Alert <onboarding@resend.dev>`
- **Reply-To**: `jachtproefalert@gmail.com`

### **Firestore Collections**

```
📂 Firestore Collections Used:
├── 📁 users/ (user data, subscription status)
├── 📁 plan_abandonment_tracking/ (abandonment flow tracking)
├── 📁 user_notifications/ (match notification preferences)
└── 📁 matches/ (hunting match data)
```

---

## 📱 Flutter Integration Points

### **Services Created**
```
lib/services/
├── 📄 welcome_email_service.dart (Welcome emails)
├── 📄 payment_service.dart (Subscription emails + abandonment tracking)
├── 📄 plan_abandonment_service.dart (Abandonment flow management)
└── 📄 auth_service.dart (User registration → welcome email trigger)
```

### **Screen Integration**
```
lib/screens/
├── 📄 plan_selection_screen.dart (Tracks abandonment via initState)
├── 📄 register_screen.dart (Triggers welcome email)
└── 📄 [match detail screens] (Enable match notifications)
```

---

## 🎯 Email Triggers & User Journey

### **Complete User Email Journey**

```
1. Registration → Welcome Email (Immediate)
   ↓
2. Plan Selection Visit → Abandonment Tracking Starts
   ↓
3a. Purchase Complete → Receipt Email (Immediate)
   OR
3b. No Purchase → Abandonment Email (24h later)
   ↓
4. Enable Match Notifications → Match Alert Emails (User-defined timing)
```

### **Email Frequency per User**

| Email Type | Frequency | Notes |
|------------|-----------|--------|
| Welcome | Once per registration | |
| Subscription Receipt | Once per purchase | Multiple if they resubscribe |
| Plan Abandonment | Once per user | Single recovery attempt |
| Match Notifications | Per enabled match | User controls frequency |

---

## 🧪 Testing & Debugging

### **Test Scripts Available**
```bash
# Test plan abandonment email
cd cloud_function_deploy
python3 test_plan_abandonment.py

# Test email sends to floris@nordrobe.com
# Check Resend dashboard for delivery status
```

### **Monitoring Locations**
- **Firebase Console**: Function logs and errors
- **Resend Dashboard**: Email delivery, opens, clicks
- **Firestore**: User tracking data and preferences

### **Debug Output Examples**
```dart
// Plan abandonment tracking
print('📊 Plan selection visit tracked for user: $userId');
print('✅ Purchase completion tracked for user: $userId');
print('📧 Abandonment email sent successfully to: $userEmail');

// Welcome email
print('✅ Welcome email sent: ${result['message']}');
print('📧 Email ID: ${result['email_id']}');
```

---

## 📊 Analytics & Metrics

### **Key Metrics Tracked**

```dart
// Plan abandonment analytics
await PlanAbandonmentService.getAbandonmentStats();

// Returns:
{
  'totalPlanVisits': 150,
  'completedPurchases': 45,
  'abandoners': 105,
  'abandonmentEmailsSent': 92,
  'conversionRate': '30.0%'
}
```

### **Conversion Funnels**
1. **Registration Funnel**: Registration → Welcome Email → Plan Selection
2. **Purchase Funnel**: Plan Selection → Purchase → Receipt Email
3. **Recovery Funnel**: Abandonment → Recovery Email → Return Purchase
4. **Engagement Funnel**: Match Interest → Notification Setup → Alert Emails

---

## 🔒 Privacy & Compliance

### **GDPR Compliance**
- **Legitimate Interest**: Emails sent based on user actions (registration, purchases, explicit preferences)
- **Data Minimization**: Only essential data collected (email, name, timestamps)
- **User Control**: Users can contact support to opt out
- **Single Touch**: Abandonment emails sent only once to prevent spam

### **Email Best Practices**
- **Professional Design**: Responsive, branded templates
- **Clear Unsubscribe**: Contact information provided
- **Personalization**: User names used where available
- **Value-Focused**: Each email provides clear value to user

---

## 🚀 Future Email Enhancements

### **Planned Improvements**
- **A/B Testing**: Subject line optimization
- **Segmentation**: Different emails for different user types
- **Advanced Analytics**: Open rates, click-through rates
- **Behavioral Triggers**: Time-based user activity emails

### **Email Template Roadmap**
- **Trial Ending Reminders**: Day 12 of trial
- **Feature Announcements**: New app features
- **Seasonal Campaigns**: Hunting season reminders
- **User Success Stories**: Social proof emails

---

## 📞 Support Information

### **For Developers**
- **Cloud Functions**: All in `cloud_function_deploy/main.py`
- **Flutter Services**: Check `lib/services/` directory
- **Email Templates**: Inline HTML in cloud functions
- **Testing**: Use test scripts in `cloud_function_deploy/`

### **For Product/Marketing**
- **Email Content**: Modify templates in cloud functions
- **Timing**: Adjust delays in Flutter services
- **Analytics**: Monitor via Firestore and Resend dashboard
- **A/B Testing**: Deploy alternate cloud functions

---

## 🎉 Summary

**JachtProef Alert has a complete, automated email system with:**

✅ **4 Email Types**: Welcome, Receipt, Abandonment, Match Notifications  
✅ **Professional Templates**: Responsive, branded, conversion-optimized  
✅ **Smart Triggers**: User action-based, perfectly timed  
✅ **Full Tracking**: Analytics and conversion metrics  
✅ **GDPR Compliant**: Privacy-focused, user-controlled  

**All emails are operational and ready to boost user engagement and conversions!** 