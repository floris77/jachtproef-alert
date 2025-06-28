# 📧 Resend Email Setup Guide - Better Alternative to SendGrid!

## 🎉 Why Resend is Better

### **✅ Advantages over SendGrid:**
- **3,000 free emails/month** (vs SendGrid's 100/day)
- **No phone verification** required
- **Simpler API** and setup
- **Better developer experience**
- **Excellent deliverability rates**
- **Modern dashboard**

## 🚀 Quick Setup (10 minutes)

### **Step 1: Create Resend Account**
1. Go to: https://resend.com/
2. Click **"Sign Up"** 
3. Enter email and password (no phone required!)
4. Verify your email address
5. You're in! 🎉

### **Step 2: Get API Key**
1. In Resend dashboard: **"API Keys"** tab
2. Click **"Create API Key"**
3. **Name**: `JachtProef Alert Production`
4. **Permission**: `Sending access`
5. Click **"Add"**
6. **COPY THE KEY** (starts with `re_...`)

### **Step 3: Deploy Cloud Functions**

Navigate to your project directory and deploy:

```bash
cd /Users/florisvanderhart/Documents/jachtproef_alert/cloud_function_deploy

# Deploy main scraper with email
gcloud functions deploy scraper-with-email \
  --runtime python39 \
  --trigger-http \
  --entry-point scraper_with_email \
  --source . \
  --set-env-vars RESEND_API_KEY=re_your_api_key_here

# Deploy subscription email function  
gcloud functions deploy send-subscription-email \
  --runtime python39 \
  --trigger-http \
  --entry-point send_subscription_email \
  --source . \
  --set-env-vars RESEND_API_KEY=re_your_api_key_here

# Deploy weekly digest function
gcloud functions deploy send-weekly-digest \
  --runtime python39 \
  --trigger-http \
  --entry-point send_weekly_digest \
  --source . \
  --set-env-vars RESEND_API_KEY=re_your_api_key_here
```

## 🔧 Test Your Setup

### **Test Subscription Receipt Email**
```bash
curl -X POST https://your-region-your-project.cloudfunctions.net/send-subscription-email \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your-test-email@gmail.com",
    "subscription_type": "Monthly Premium",
    "amount": "3.99"
  }'
```

### **Expected Response:**
```json
{
  "status": "success",
  "message": "Receipt sent to your-test-email@gmail.com"
}
```

## 📱 Flutter App Integration

Add this to your payment service:

```dart
// After successful subscription purchase
Future<void> sendSubscriptionReceipt(String email, String subscriptionType, String amount) async {
  try {
    final response = await http.post(
      Uri.parse('https://your-region-your-project.cloudfunctions.net/send-subscription-email'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'subscription_type': subscriptionType,
        'amount': amount,
      }),
    );
    
    if (response.statusCode == 200) {
      print('📧 Receipt email sent successfully');
    }
  } catch (e) {
    print('❌ Error sending receipt: $e');
  }
}

// Usage in your payment flow
if (subscriptionPurchaseSuccessful) {
  await sendSubscriptionReceipt(
    userEmail,
    subscription == 'monthly' ? 'Monthly Premium' : 'Yearly Premium',
    subscription == 'monthly' ? '3.99' : '29.99'
  );
}
```

## 📊 Email Types Available

### **1. 🧾 Subscription Receipts**
- **When**: After successful payment
- **Purpose**: Payment confirmation & welcome
- **Design**: Professional receipt with premium benefits

### **2. 🎯 Exam Alerts**  
- **When**: New matching exams found
- **Purpose**: Instant notifications
- **Design**: Clean list of new exam opportunities

### **3. 📊 Weekly Digest**
- **When**: Every Sunday (scheduled)
- **Purpose**: Summary of week's exams
- **Design**: Table format with all available exams

### **4. 🔒 Password Reset**
- **When**: User requests password reset
- **Purpose**: Account security
- **Design**: Secure reset link with clear instructions

## 💰 Pricing Comparison

| Service | Free Tier | Paid Plans |
|---------|-----------|------------|
| **Resend** ✅ | **3,000/month** | $20/month (50k) |
| SendGrid | 100/day | $15/month (40k) |
| Mailgun | 5,000 (3 months) | $35/month (50k) |
| Postmark | 100/month | $10/month (10k) |

**Resend wins!** 🏆

## 📈 Usage Estimates for Your App

### **Current Scale (Estimated):**
- **10 paying users**: ~40 emails/month
- **100 users with email alerts**: ~400 emails/month  
- **500 weekly digest subscribers**: ~2,000 emails/month

**Total: ~2,500 emails/month** - Comfortably within free tier! 

### **When to Upgrade:**
- **1,000+ weekly subscribers**: Consider paid plan
- **Multiple daily alerts**: Monitor usage
- **Advanced features needed**: Domain authentication, analytics

## 🔍 Monitoring Your Emails

### **Resend Dashboard Shows:**
- ✅ Delivery status
- ✅ Open rates
- ✅ Click tracking
- ✅ Bounce/spam reports
- ✅ Real-time analytics

### **Your Firestore Logs:**
Check `email_logs` collection for:
- Email addresses
- Send timestamps
- Email types
- Success/failure status

## 🎯 Launch Strategy

### **Week 1: Start Small**
1. **Deploy subscription receipts** (immediate value)
2. **Test with your own purchases**
3. **Monitor delivery rates**

### **Week 2-3: Add Alerts**
1. **Enable exam alert emails**
2. **Test with existing users**
3. **Gather user feedback**

### **Week 4+: Weekly Digests**
1. **Launch weekly digest feature**
2. **A/B test email content**
3. **Optimize engagement rates**

## 🔒 Security & Best Practices

### **✅ What's Already Included:**
- API key in environment variables
- Email validation
- Error handling & logging
- Professional email templates
- Mobile-responsive design

### **📝 TODO for Production:**
1. **Domain authentication** (improves deliverability)
2. **Unsubscribe links** (legal requirement)
3. **Email preferences** in app settings
4. **Rate limiting** (if needed)

## 🚨 Troubleshooting

### **Common Issues:**

**1. "Invalid API key" error:**
- Double-check the API key starts with `re_`
- Ensure environment variable is set correctly
- Restart cloud function after updating env vars

**2. Emails not received:**
- Check spam folder
- Verify email address is correct
- Check Resend dashboard for delivery status

**3. Cloud function timeout:**
- Default timeout is 60 seconds (should be enough)
- Monitor function logs in Google Cloud Console

## 📞 Support

### **Resend Support:**
- **Docs**: https://resend.com/docs
- **Status**: https://status.resend.com/
- **Support**: Very responsive email support

### **Your Implementation:**
- Monitor `email_logs` collection in Firestore
- Check Cloud Function logs for errors
- Test with multiple email providers (Gmail, Outlook, etc.)

---

## 🎉 Ready to Launch!

**Your email system is now:**
- ✅ **Professional** looking emails  
- ✅ **Reliable** delivery (Resend has great reputation)
- ✅ **Scalable** (3,000 free emails/month)
- ✅ **Easy to monitor** (dashboard + Firestore logs)

**Start with subscription receipts - users expect and value these the most!** 

---

### **Alternative Options (if Resend doesn't work):**

## 🔄 Backup Option 1: Mailgun
- **Free**: 5,000 emails for 3 months
- **Setup**: Similar to Resend
- **API**: Well-documented
- **Cost**: $35/month after trial

## 🔄 Backup Option 2: Amazon SES  
- **Free**: 62,000 emails/month (if sent from EC2)
- **Cost**: $0.10 per 1,000 emails
- **Setup**: More complex (AWS console)
- **Best for**: High volume

## 🔄 Backup Option 3: Postmark
- **Free**: 100 emails/month
- **Strengths**: Excellent deliverability
- **Cost**: $10/month for 10,000 emails
- **Best for**: Transactional emails

**Resend is still the best choice for your use case!** 🚀 