#!/usr/bin/env python3
"""
Test the plan abandonment email functionality
"""
import resend
import json

# Configure Resend API key
resend.api_key = "re_8AvpZCWL_4jPJQY4v99Ypmc6jBhZNijoj"

def test_plan_abandonment_email():
    """Test sending a plan abandonment email"""
    
    print("🧪 Testing Plan Abandonment Email")
    print("=" * 50)
    
    # Test email details
    test_email = "floris@nordrobe.com"
    test_name = "Floris"
    
    try:
        # Generate plan abandonment email content
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Vergeten je Premium abonnement te activeren?</title>
        </head>
        <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f8f9fa;">
            <div style="background: white; border-radius: 12px; padding: 32px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                <!-- Header -->
                <div style="text-align: center; border-bottom: 2px solid #e9ecef; padding-bottom: 24px; margin-bottom: 32px;">
                    <h1 style="color: #2E7D32; margin: 0; font-size: 28px; font-weight: bold;">🎯 JachtProef Alert</h1>
                    <p style="color: #6c757d; margin: 8px 0 0 0; font-size: 16px;">Je Premium toegang wacht op je!</p>
                </div>

                <!-- Personal Message -->
                <div style="background: #fff3cd; border: 2px solid #ffc107; border-radius: 8px; padding: 20px; margin-bottom: 24px; text-align: center;">
                    <h2 style="margin: 0 0 8px 0; color: #856404; font-size: 20px;">⏰ Hoi {test_name}!</h2>
                    <p style="margin: 0; color: #856404; font-size: 16px;">Je was net bezig met het kiezen van een Premium plan...</p>
                </div>

                <!-- What they're missing -->
                <div style="background: #f8f9fa; border-radius: 8px; padding: 24px; margin-bottom: 24px;">
                    <h3 style="color: #2e7d32; margin: 0 0 16px 0; font-size: 18px;">🌟 Met Premium krijg je:</h3>
                    <ul style="color: #6c757d; margin: 0; padding-left: 20px; line-height: 1.8;">
                        <li><strong>Onbeperkte notificaties</strong> - Nooit meer een jachtproef missen</li>
                        <li><strong>Email alerts</strong> - Krijg meldingen ook per email</li>
                        <li><strong>Prioritaire ondersteuning</strong> - Hulp wanneer je het nodig hebt</li>
                        <li><strong>Vroege toegang</strong> - Nieuwe functies als eerste proberen</li>
                        <li><strong>Geen advertenties</strong> - Ononderbroken focus op jachtproeven</li>
                    </ul>
                </div>

                <!-- Special offer -->
                <div style="background: linear-gradient(135deg, #e8f5e8 0%, #f1f8e9 100%); border: 2px solid #4caf50; border-radius: 12px; padding: 24px; margin-bottom: 24px; text-align: center;">
                    <h3 style="margin: 0 0 12px 0; color: #2e7d32; font-size: 22px;">🎁 Nog steeds 14 dagen gratis!</h3>
                    <p style="margin: 0 0 16px 0; color: #2e7d32; font-size: 16px;">Start vandaag je proefperiode en betaal pas na 2 weken</p>
                    <div style="margin-bottom: 16px;">
                        <div style="background: white; border-radius: 8px; padding: 16px; margin-bottom: 12px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                            <div style="font-size: 18px; font-weight: bold; color: #2e7d32;">📅 Maandelijks</div>
                            <div style="font-size: 24px; font-weight: bold; color: #2e7d32; margin: 4px 0;">€3,99/maand</div>
                            <div style="font-size: 14px; color: #6c757d;">Na 14 dagen gratis</div>
                        </div>
                        <div style="background: white; border: 2px solid #4caf50; border-radius: 8px; padding: 16px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                            <div style="background: #4caf50; color: white; font-size: 12px; font-weight: bold; border-radius: 4px; padding: 4px 8px; display: inline-block; margin-bottom: 8px;">BESTE DEAL</div>
                            <div style="font-size: 18px; font-weight: bold; color: #2e7d32;">📈 Jaarlijks</div>
                            <div style="font-size: 24px; font-weight: bold; color: #2e7d32; margin: 4px 0;">€29,99/jaar</div>
                            <div style="font-size: 14px; color: #6c757d;">Bespaar 37% • Na 14 dagen gratis</div>
                        </div>
                    </div>
                </div>

                <!-- Action Button -->
                <div style="text-align: center; margin: 32px 0;">
                    <div style="margin-bottom: 16px;">
                        <a href="jachtproefalert://plan-selection" style="display: inline-block; background: linear-gradient(135deg, #2e7d32 0%, #4caf50 100%); color: white; padding: 18px 36px; text-decoration: none; border-radius: 12px; font-weight: bold; font-size: 18px; box-shadow: 0 4px 8px rgba(46, 125, 50, 0.3);">
                            🚀 Start je 14 dagen gratis proefperiode
                        </a>
                    </div>
                    <div style="font-size: 13px; color: #6c757d; text-align: center; margin-top: 12px;">
                        <p style="margin: 4px 0;">App nog niet geïnstalleerd?</p>
                        <a href="https://apps.apple.com/app/jachtproef-alert/id6475935640" style="color: #2e7d32; text-decoration: none; margin: 0 8px; font-weight: 500;">📱 Download voor iOS</a> | 
                        <a href="https://play.google.com/store/apps/details?id=com.nordrobe.jachtproef_alert" style="color: #2e7d32; text-decoration: none; margin: 0 8px; font-weight: 500;">🤖 Download voor Android</a>
                    </div>
                </div>

                <!-- Reassurance -->
                <div style="background: #e3f2fd; border: 1px solid #bbdefb; border-radius: 8px; padding: 16px; margin-bottom: 24px; text-align: center;">
                    <p style="margin: 0; color: #1976d2; font-size: 14px;">
                        ✨ <strong>Geen verplichtingen</strong> - Opzeggen kan altijd in je App Store of Google Play instellingen
                    </p>
                </div>

                <!-- Social proof -->
                <div style="text-align: center; margin-bottom: 24px;">
                    <p style="color: #6c757d; font-size: 14px; margin: 0;">
                        🏆 <strong>Meer dan 1.000+ jagers</strong> gebruiken al JachtProef Alert Premium
                    </p>
                </div>

                <!-- Footer -->
                <div style="text-align: center; border-top: 1px solid #e9ecef; padding-top: 24px; color: #6c757d;">
                    <p style="margin: 0; font-size: 14px;">Deze herinnering is eenmalig verzonden omdat je interesse hebt getoond in Premium.</p>
                    <p style="margin: 8px 0 0 0; font-size: 12px;">JachtProef Alert - Mis nooit meer een jachtproef!</p>
                </div>
            </div>
        </body>
        </html>
        """

        # Send email
        params = {
            "from": "JachtProef Alert <onboarding@resend.dev>",
            "reply_to": ["jachtproefalert@gmail.com"],
            "to": [test_email],
            "subject": "🎯 Vergeten je Premium abonnement te activeren? 14 dagen gratis wacht nog steeds!",
            "html": html_content,
        }

        email_result = resend.Emails.send(params)
        
        print(f"✅ Plan abandonment email sent successfully!")
        print(f"📧 To: {test_email}")
        print(f"📧 Email ID: {email_result.get('id', 'unknown')}")
        print(f"🎯 Subject: {params['subject']}")
        
        # Show key features of the email
        print(f"\n🌟 Email Features:")
        print(f"   ⏰ Personal greeting with user name")
        print(f"   💰 Clear pricing (€3,99/month, €29,99/year)")
        print(f"   🎁 14-day free trial emphasis")
        print(f"   ✨ No-obligation messaging")
        print(f"   🏆 Social proof (1,000+ users)")
        print(f"   📱 Mobile-responsive design")
        
        return email_result.get('id')
        
    except Exception as e:
        print(f"❌ Error sending plan abandonment email: {e}")
        return None

if __name__ == "__main__":
    print("🧪 Testing Plan Abandonment Email System")
    print("=" * 60)
    result = test_plan_abandonment_email()
    
    if result:
        print(f"\n🎉 SUCCESS: Plan abandonment email system is working!")
        print(f"📧 Check your email at floris@nordrobe.com")
        print(f"\n💡 This email would be sent to users who:")
        print(f"   1. Visit the plan selection screen")
        print(f"   2. Don't complete their subscription within 24 hours")
        print(f"   3. Haven't received an abandonment email before")
    else:
        print(f"\n❌ FAILED: Plan abandonment email system needs debugging") 