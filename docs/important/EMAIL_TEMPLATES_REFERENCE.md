# 📧 Email Templates Quick Reference

## 🎯 Active Email Templates in JachtProef Alert

This document shows the exact email content currently being sent to users.

---

## 1. 👋 Welcome Email

**Trigger**: New user registration  
**Subject**: `🎯 Welkom bij JachtProef Alert!`  
**Cloud Function**: `send-welcome-email`

### Content Overview:
- Welcome message with user's name
- App introduction and value proposition  
- Premium feature highlights
- 14-day free trial offer
- Professional hunting-themed design

### Key Elements:
- **Header**: JachtProef Alert branding
- **Personal Greeting**: "Welkom [Name]!"
- **Features List**: Premium benefits
- **CTA Button**: "Start je Premium proefperiode"
- **Footer**: Contact and unsubscribe info

---

## 2. 💳 Subscription Receipt Email

**Trigger**: Successful subscription purchase  
**Subject**: `✅ Je JachtProef Alert Premium is actief!`  
**Cloud Function**: `send-subscription-email`

### Content Overview:
- Subscription confirmation
- Payment amount and plan details
- Billing information
- Access confirmation
- Next steps guidance

### Dynamic Content:
- **Plan Type**: "Monthly Premium" or "Yearly Premium"
- **Amount**: "€3.99" or "€29.99"
- **User Email**: Billing confirmation
- **Activation Status**: Immediate access confirmed

---

## 3. ⏰ Plan Abandonment Recovery Email

**Trigger**: User visits plan selection but doesn't purchase within 24 hours  
**Subject**: `🎯 Vergeten je Premium abonnement te activeren? 14 dagen gratis wacht nog steeds!`  
**Cloud Function**: `send-plan-abandonment-email`

### Content Breakdown:

#### **Header Section**:
```
🎯 JachtProef Alert
Je Premium toegang wacht op je!
```

#### **Personal Message**:
```
⏰ Hoi [User Name]!
Je was net bezig met het kiezen van een Premium plan...
```

#### **Benefits Section**:
```
🌟 Met Premium krijg je:
• Onbeperkte notificaties - Nooit meer een jachtproef missen
• Email alerts - Krijg meldingen ook per email  
• Prioritaire ondersteuning - Hulp wanneer je het nodig hebt
• Vroege toegang - Nieuwe functies als eerste proberen
• Geen advertenties - Ononderbroken focus op jachtproeven
```

#### **Pricing Display**:
```
🎁 Nog steeds 14 dagen gratis!
Start vandaag je proefperiode en betaal pas na 2 weken

📅 Maandelijks: €3,99/maand (Na 14 dagen gratis)
📈 Jaarlijks: €29,99/jaar (Bespaar 37% • Na 14 dagen gratis) [BESTE DEAL]
```

#### **Call to Action**:
```
🚀 Start je 14 dagen gratis proefperiode
(Deep link: jachtproefalert://plan-selection)

+ App Store fallback links:
📱 Download voor iOS | 🤖 Download voor Android
```

#### **Reassurance**:
```
✨ Geen verplichtingen - Opzeggen kan altijd in je App Store of Google Play instellingen
```

#### **Social Proof**:
```
🏆 Meer dan 1.000+ jagers gebruiken al JachtProef Alert Premium
```

---

## 4. 🎯 Match Notification Emails

**Trigger**: User-enabled match notifications  
**Cloud Function**: `send-match-notification`

### A. Enrollment Opening Email

**Subject**: `🎯 Inschrijving geopend: [Match Name]`

**Content Structure**:
- **Alert Badge**: "⏰ Je kunt je nu inschrijven!"
- **Match Details**: Name, location, date
- **CTA**: "📱 Open JachtProef Alert App" (Deep link: jachtproefalert://open)
- **App Store Fallback**: iOS & Android download links
- **Tips Section**: Enrollment guidance
- **Footer**: Notification preference reminder

### B. Match Reminder Email

**Subject**: `📅 Herinnering: [Match Name] is binnenkort`

**Content Structure**:
- **Reminder Badge**: "🎯 Vergeet niet: je proef is binnenkort!"
- **Match Details**: Name, location, date
- **CTA**: "📱 Open App voor Details" (Deep link: jachtproefalert://open)
- **Checklist**: Final preparation items
- **Success Message**: "Veel succes met je jachtproef!"

---

## 📊 Email Specifications

### **Common Design Elements**

| Element | Specification |
|---------|---------------|
| **Font Family** | 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif |
| **Max Width** | 600px |
| **Brand Color** | #2E7D32 (Green) |
| **Accent Colors** | Blue (#1976d2), Orange (#ff9800), Yellow (#ffc107) |
| **Border Radius** | 8px-12px |
| **Responsive** | ✅ Mobile-optimized |

### **Standard Email Structure**

```
┌─────────────────────────────────┐
│ 🎯 JachtProef Alert Header      │ 
├─────────────────────────────────┤
│ Personal/Alert Message          │
├─────────────────────────────────┤
│ Main Content (varies by type)   │
├─────────────────────────────────┤
│ Call-to-Action Button          │
├─────────────────────────────────┤
│ Additional Info/Reassurance     │
├─────────────────────────────────┤
│ Footer (Contact/Unsubscribe)    │
└─────────────────────────────────┘
```

### **Email Metadata**

| Property | Value |
|----------|-------|
| **From** | `JachtProef Alert <onboarding@resend.dev>` |
| **Reply-To** | `jachtproefalert@gmail.com` |
| **Encoding** | UTF-8 |
| **Content-Type** | text/html |
| **Viewport** | width=device-width, initial-scale=1.0 |

---

## 🔧 Template Customization

### **Variables Used**

#### Plan Abandonment Email:
- `{user_name}` - User's display name (default: "daar")
- `{user_email}` - Recipient email address

#### Subscription Receipt Email:
- `{user_email}` - Billing email
- `{subscription_type}` - "Monthly Premium" or "Yearly Premium"  
- `{amount}` - "3.99" or "29.99"

#### Match Notification Email:
- `{match_title}` - Name of hunting match
- `{match_location}` - Location of match
- `{match_date}` - Date of match
- `{notification_type}` - "enrollment_opening" or "match_reminder"

### **Responsive Breakpoints**

```css
/* Mobile-first approach */
@media screen and (max-width: 600px) {
  .email-container { padding: 16px !important; }
  .header-text { font-size: 24px !important; }
  .button { padding: 14px 24px !important; }
}
```

---

## 🔗 Deep Link Configuration

### **Supported Deep Links**

| Deep Link | Purpose | Email Usage |
|-----------|---------|-------------|
| `jachtproefalert://open` | Open app home | Match notifications |
| `jachtproefalert://plan-selection` | Direct to plan selection | Plan abandonment email |
| `jachtproefalert://plans` | Alternative plan route | Alternative CTAs |
| `jachtproefalert://matches` | Direct to matches | Future match emails |

### **Fallback Strategy**

When users don't have the app installed, emails include App Store links:
- **iOS**: `https://apps.apple.com/app/jachtproef-alert/id6475935640`
- **Android**: `https://play.google.com/store/apps/details?id=com.nordrobe.jachtproef_alert`

### **Technical Implementation**

**Android Configuration** (`android/app/src/main/AndroidManifest.xml`):
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="jachtproefalert" />
</intent-filter>
```

**iOS Configuration** (`ios/Runner/Info.plist`):
```xml
<dict>
    <key>CFBundleURLName</key>
    <string>Email Deep Links</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>jachtproefalert</string>
    </array>
</dict>
```

**Flutter Service**: `lib/services/deep_link_service.dart`
- Handles incoming deep links
- Routes users to appropriate screens
- Provides fallback navigation

---

## 🧪 Testing Commands

### **Test Each Email Type**

```bash
# Test plan abandonment email
cd cloud_function_deploy
python3 test_plan_abandonment.py

# Test other emails (manual triggers needed)
# Visit Firebase Console → Functions → Test
```

### **Check Email Status**

```bash
# Monitor Resend dashboard
# Visit: https://resend.com/dashboard

# Check Firebase logs  
# Visit: Firebase Console → Functions → Logs
```

---

## 📞 Quick Support

### **Email Issues**
- **Not Delivered**: Check Resend dashboard for bounce/spam reports
- **Wrong Content**: Modify templates in `cloud_function_deploy/main.py`
- **Timing Issues**: Adjust delays in Flutter services

### **Template Updates**
1. Edit HTML in cloud function
2. Redeploy cloud function  
3. Test with test scripts
4. Monitor delivery in Resend dashboard

**All email templates are live and operational!** 🚀 