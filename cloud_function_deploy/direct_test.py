#!/usr/bin/env python3
"""
Direct test of Resend API to verify everything works
"""
import resend
import os

# Set your API key
resend.api_key = "re_8AvpZCWL_4jPJQY4v99Ypmc6jBhZNijoj"

print("🔄 Testing Resend API directly...")

try:
    # Send a simple test email to your address
    params = {
        "from": "onboarding@resend.dev",  # Using Resend's verified sender for now
        "reply_to": ["jachtproefalert@gmail.com"],  # Your new Gmail as reply-to
        "to": ["floris@nordrobe.com"],  # Using verified address for testing
        "subject": "🎉 JachtProef Alert Email Test - Updated Config",
        "html": """
        <h1>✅ Email System Working!</h1>
        <p>Congratulations! Your JachtProef Alert email system is working perfectly.</p>
        <p><strong>This confirms:</strong></p>
        <ul>
            <li>✅ Resend API key is valid</li>
            <li>✅ Python integration works</li>
            <li>✅ Email delivery is functional</li>
        </ul>
        <p>You're ready to integrate this into your Flutter app! 🚀</p>
        """,
    }

    email_result = resend.Emails.send(params)
    print(f"✅ Success! Email sent to floris@nordrobe.com")
    print(f"📧 Email ID: {email_result.get('id', 'unknown')}")
    print(f"🎯 Check your inbox at floris@nordrobe.com")
    print(f"📧 Reply-to is set to: jachtproefalert@gmail.com")
    print(f"⚠️  Note: Currently limited to verified email for testing")
    
except Exception as e:
    print(f"❌ Error: {e}") 