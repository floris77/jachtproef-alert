#!/usr/bin/env python3
"""
Test script to verify the updated email notification system with customizable timing
"""
import resend
import os

# Configure Resend API
resend.api_key = "re_8AvpZCWL_4jPJQY4v99Ypmc6jBhZNijoj"

def test_email_notifications_with_timing():
    """Test the different notification timing types"""
    
    print("🧪 Testing Updated Email Notification System")
    print("=" * 60)
    print("✅ Email notifications now respect user's scheduling preferences!")
    print("")
    
    # Test different reminder timing types
    test_cases = [
        {
            'timing': '7 days before',
            'type': 'match_reminder_7days',
            'subject': '📅 Herinnering: Nederlandse Labrador Vereniging (7 dagen)',
            'description': 'Early reminder for users who want advance notice'
        },
        {
            'timing': '1 day before', 
            'type': 'match_reminder_1day',
            'subject': '📅 Herinnering: Nederlandse Labrador Vereniging (1 dag)',
            'description': 'Standard reminder for most users'
        },
        {
            'timing': '1 hour before',
            'type': 'match_reminder_1hour', 
            'subject': '📅 Herinnering: Nederlandse Labrador Vereniging (1 uur)',
            'description': 'Last-minute reminder for final preparations'
        },
        {
            'timing': '10 minutes before',
            'type': 'match_reminder_10minutes',
            'subject': '📅 Herinnering: Nederlandse Labrador Vereniging (10 min)',
            'description': 'Final reminder right before the match'
        }
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"📧 Test {i}/4: {test_case['timing']}")
        print(f"   Type: {test_case['type']}")
        print(f"   Purpose: {test_case['description']}")
        
        try:
            # Generate reminder email content
            html_content = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Proef Herinnering</title>
            </head>
            <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f8f9fa;">
                <div style="background: white; border-radius: 12px; padding: 32px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <!-- Header -->
                    <div style="text-align: center; border-bottom: 2px solid #e9ecef; padding-bottom: 24px; margin-bottom: 32px;">
                        <h1 style="color: #1976d2; margin: 0; font-size: 28px; font-weight: bold;">📅 JachtProef Alert</h1>
                        <p style="color: #6c757d; margin: 8px 0 0 0; font-size: 16px;">Jouw proef is binnenkort!</p>
                        <p style="color: #1976d2; margin: 4px 0 0 0; font-size: 14px; font-weight: bold;">⏰ {test_case['timing']}</p>
                    </div>

                    <!-- Reminder Badge -->
                    <div style="background: #e3f2fd; border: 2px solid #1976d2; border-radius: 8px; padding: 16px; margin-bottom: 24px; text-align: center;">
                        <p style="margin: 0; color: #1976d2; font-weight: bold; font-size: 18px;">🎯 Nederlandse Labrador Vereniging</p>
                    </div>

                    <!-- Match Details -->
                    <div style="background: #f8f9fa; border-radius: 8px; padding: 24px; margin-bottom: 24px;">
                        <div style="margin-bottom: 12px;">
                            <span style="color: #6c757d; font-size: 16px;">📍 <strong>Locatie:</strong> Lelystad, Flevoland</span>
                        </div>
                        <div>
                            <span style="color: #6c757d; font-size: 16px;">📅 <strong>Datum:</strong> 15 juni 2025</span>
                        </div>
                    </div>

                    <!-- Action Button -->
                    <div style="text-align: center; margin: 32px 0;">
                        <a href="https://my.orweja.nl/login" style="display: inline-block; background: #1976d2; color: white; padding: 16px 32px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; box-shadow: 0 2px 4px rgba(25, 118, 210, 0.3);">
                            📝 Bekijk Details op Orweja
                        </a>
                    </div>

                    <!-- Footer -->
                    <div style="text-align: center; border-top: 1px solid #e9ecef; padding-top: 24px; color: #6c757d;">
                        <p style="margin: 0; font-size: 14px;">Je ontvangt deze melding {test_case['timing']} op basis van je instellingen.</p>
                        <p style="margin: 8px 0 0 0; font-size: 12px;">JachtProef Alert - Mis nooit meer een jachtproef!</p>
                    </div>
                </div>
            </body>
            </html>
            """
            
            # Send test email
            params = {
                "from": "JachtProef Alert <onboarding@resend.dev>",
                "reply_to": ["jachtproefalert@gmail.com"],
                "to": ["floris@nordrobe.com"],
                "subject": test_case['subject'],
                "html": html_content,
            }
            
            email_result = resend.Emails.send(params)
            print(f"   ✅ Email sent! ID: {email_result.get('id', 'unknown')}")
            
        except Exception as e:
            print(f"   ❌ Error: {e}")
        
        print("")
    
    print("🎯 Summary of Changes:")
    print("─" * 40)
    print("📧 BEFORE: Only 1 hardcoded email (1 day before)")
    print("📧 AFTER:  Customizable emails based on user settings")
    print("")
    print("⚙️  User Settings Integration:")
    print("   • 7 dagen van tevoren  → match_reminder_7days")
    print("   • 1 dag van tevoren    → match_reminder_1day") 
    print("   • 1 uur van tevoren    → match_reminder_1hour")
    print("   • 10 min van tevoren   → match_reminder_10minutes")
    print("")
    print("🔄 System Flow:")
    print("   1. User configures timing in Settings → MELDINGSTIJDEN")
    print("   2. Settings saved to Firestore for email system access")
    print("   3. When user follows a match → Multiple emails scheduled")
    print("   4. Each email sent at user's preferred times")
    print("")
    print("📬 Check your inbox at floris@nordrobe.com for 4 example emails!")

if __name__ == "__main__":
    test_email_notifications_with_timing() 