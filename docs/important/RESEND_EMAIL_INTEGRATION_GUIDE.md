# JachtProef Alert - Resend Email Integration Guide

## ✅ Current Status

### Email Service Deployed
- **Cloud Function URL**: `https://us-central1-jachtproefalert.cloudfunctions.net/send-subscription-email`
- **Status**: ✅ Successfully deployed and functional
- **API Key**: Configured with environment variable `RESEND_API_KEY`
- **Authentication**: Secured (requires Firebase Auth token)

### Email Configuration
- **From Address**: `JachtProef Alert <onboarding@resend.dev>` (Resend's verified sender)
- **Reply-To**: `jachtproefalert@gmail.com` (Your new Gmail address)
- **Current Limitation**: Can only send to verified addresses in testing mode

## 🔧 Email Setup Details

### Current Configuration (Testing Mode)
```python
params = {
    "from": "JachtProef Alert <onboarding@resend.dev>",
    "reply_to": ["jachtproefalert@gmail.com"],
    "to": [user_email],  # Currently limited to floris@nordrobe.com
    "subject": "✅ Abonnement bevestiging - JachtProef Alert Premium",
    "html": html_content,
}
```

### Production Requirements
To send emails to all users (not just testing addresses), you need to:

1. **Verify Domain**: Go to [resend.com/domains](https://resend.com/domains)
2. **Add Domain**: Add `jachtproefalert.nl` or similar domain you own
3. **DNS Setup**: Configure DNS records as provided by Resend
4. **Update From Address**: Change from `onboarding@resend.dev` to `noreply@jachtproefalert.nl`

## 📱 Flutter App Integration

### Step 1: Add HTTP Package
Ensure your `pubspec.yaml` includes:
```yaml
dependencies:
  http: ^1.1.0
```

### Step 2: Update Payment Service
Add this method to your payment service:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

// Add to your PaymentService class
Future<void> sendSubscriptionEmail({
  required String userEmail,
  required String subscriptionType,
  required String amount,
}) async {
  try {
    // Get Firebase Auth token
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No authenticated user for email sending');
      return;
    }
    
    final idToken = await user.getIdToken();
    
    // Cloud function URL
    const functionUrl = 'https://us-central1-jachtproefalert.cloudfunctions.net/send-subscription-email';
    
    // Prepare request
    final response = await http.post(
      Uri.parse(functionUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: json.encode({
        'email': userEmail,
        'subscription_type': subscriptionType,
        'amount': amount,
      }),
    );
    
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      print('✅ Subscription email sent: ${result['message']}');
      print('📧 Email ID: ${result['email_id']}');
    } else {
      print('❌ Failed to send subscription email: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Error sending subscription email: $e');
  }
}
```

### Step 3: Call After Successful Purchase
In your subscription success handler:

```dart
// After successful subscription purchase
await sendSubscriptionEmail(
  userEmail: userEmail, // User's email address
  subscriptionType: isMonthly ? 'Monthly Premium' : 'Yearly Premium',
  amount: isMonthly ? '3.99' : '39.99',
);
```

## 🔍 Testing

### Direct API Test
```bash
cd cloud_function_deploy
python3 direct_test.py
```

### Cloud Function Test
```bash
cd cloud_function_deploy
python3 test_email.py
```

## ⚠️ Important Notes

### Current Limitations
1. **Testing Mode**: Can only send to `floris@nordrobe.com` (verified address)
2. **Domain Verification**: Need to verify your own domain for production
3. **Gmail Reply-To**: Users will see replies go to `jachtproefalert@gmail.com`

### Security
- Cloud function requires Firebase authentication
- API key is securely stored as environment variable
- CORS headers configured for web requests

### Email Template
- Professional Dutch language template
- Includes subscription details and trial information
- Mobile-friendly HTML design
- Branded with JachtProef Alert styling

## 🚀 Next Steps

### For Production (Recommended)
1. **Purchase Domain**: Get `jachtproefalert.nl` or similar
2. **Verify Domain**: Add to Resend dashboard
3. **Update Configuration**: Change from address to use your domain
4. **Test with Real Users**: Verify email delivery works

### For Testing (Current)
- Email system is ready to use with verified addresses
- Integration code is prepared for Flutter app
- Reply-to is set to your new Gmail address

## 📞 Support

If you encounter issues:
1. Check Firebase Auth token validity
2. Verify cloud function deployment status
3. Monitor cloud function logs in Google Cloud Console
4. Test direct Resend API integration

---

**Last Updated**: June 10, 2025  
**Cloud Function**: ✅ Deployed and functional  
**Integration**: ✅ Ready for Flutter app 