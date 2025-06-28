#!/usr/bin/env python3
"""
Test script to send an example welcome email using Resend API
"""
import resend

# Configure Resend API
resend.api_key = "re_8AvpZCWL_4jPJQY4v99Ypmc6jBhZNijoj"

def send_welcome_email_test():
    """Send test welcome email"""
    
    user_email = "floris@nordrobe.com"
    user_name = "Floris"
    
    # Generate welcome email content
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Welkom bij JachtProef Alert</title>
    </head>
    <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f8f9fa;">
        <div style="background: white; border-radius: 12px; padding: 32px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
            <!-- Header -->
            <div style="text-align: center; border-bottom: 2px solid #e9ecef; padding-bottom: 24px; margin-bottom: 32px;">
                <h1 style="color: #2E7D32; margin: 0; font-size: 32px; font-weight: bold;">🎯 JachtProef Alert</h1>
                <p style="color: #6c757d; margin: 8px 0 0 0; font-size: 18px;">Welkom bij de community!</p>
            </div>

            <!-- Welcome Message -->
            <div style="background: #e8f5e8; border: 2px solid #4caf50; border-radius: 8px; padding: 20px; margin-bottom: 24px; text-align: center;">
                <h2 style="margin: 0 0 8px 0; color: #2e7d32; font-size: 24px;">👋 Welkom, {user_name}!</h2>
                <p style="margin: 0; color: #2e7d32; font-size: 16px;">Je bent nu onderdeel van de JachtProef Alert gemeenschap</p>
            </div>

            <!-- Getting Started -->
            <div style="background: #f8f9fa; border-radius: 8px; padding: 24px; margin-bottom: 24px;">
                <h3 style="color: #2e7d32; margin: 0 0 16px 0; font-size: 20px;">🚀 Zo ga je van start:</h3>
                <div style="margin-bottom: 16px;">
                    <div style="display: flex; align-items: flex-start; margin-bottom: 12px;">
                        <span style="background: #2e7d32; color: white; border-radius: 50%; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold; margin-right: 12px; flex-shrink: 0;">1</span>
                        <span style="color: #333; font-size: 16px;"><strong>Stel je voorkeuren in</strong> - Ga naar Instellingen en kies welke proef types je wilt zien</span>
                    </div>
                    <div style="display: flex; align-items: flex-start; margin-bottom: 12px;">
                        <span style="background: #2e7d32; color: white; border-radius: 50%; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold; margin-right: 12px; flex-shrink: 0;">2</span>
                        <span style="color: #333; font-size: 16px;"><strong>Zoek interessante proeven</strong> - Blader door de lijst en gebruik filters om te zoeken</span>
                    </div>
                    <div style="display: flex; align-items: flex-start; margin-bottom: 12px;">
                        <span style="background: #2e7d32; color: white; border-radius: 50%; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold; margin-right: 12px; flex-shrink: 0;">3</span>
                        <span style="color: #333; font-size: 16px;"><strong>Schakel notificaties in</strong> - Volg proeven en ontvang meldingen wanneer inschrijving opent</span>
                    </div>
                    <div style="display: flex; align-items: flex-start;">
                        <span style="background: #2e7d32; color: white; border-radius: 50%; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold; margin-right: 12px; flex-shrink: 0;">4</span>
                        <span style="color: #333; font-size: 16px;"><strong>Schrijf je in via Orweja</strong> - Klik op de groene knop om naar het officiële inschrijfsysteem te gaan</span>
                    </div>
                </div>
            </div>

            <!-- Facebook Community -->
            <div style="background: linear-gradient(135deg, #1877f2, #42a5f5); border-radius: 8px; padding: 24px; margin-bottom: 24px; text-align: center;">
                <h3 style="color: white; margin: 0 0 12px 0; font-size: 20px;">📘 Word lid van onze Facebook groep!</h3>
                <p style="color: white; margin: 0 0 16px 0; font-size: 16px;">Krijg tips, stel vragen en deel ervaringen met andere gebruikers van JachtProef Alert</p>
                <a href="https://www.facebook.com/groups/698746552871835/" style="display: inline-block; background: white; color: #1877f2; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; font-size: 16px; box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);">
                    👥 Doe mee met de groep
                </a>
            </div>

            <!-- Features -->
            <div style="background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 8px; padding: 20px; margin-bottom: 24px;">
                <h3 style="color: #856404; margin: 0 0 16px 0; font-size: 18px;">🌟 Wat kun je allemaal:</h3>
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 12px;">
                    <div style="color: #856404; font-size: 14px;">
                        <span style="font-weight: bold;">📅</span> Alle jachtproeven op één plek<br>
                        <span style="font-weight: bold;">🔔</span> Slimme meldingen voor inschrijving<br>
                        <span style="font-weight: bold;">📍</span> Filter op locatie en proef type
                    </div>
                    <div style="color: #856404; font-size: 14px;">
                        <span style="font-weight: bold;">⭐</span> Favoriete proeven opslaan<br>
                        <span style="font-weight: bold;">📝</span> Notities toevoegen aan proeven<br>
                        <span style="font-weight: bold;">📲</span> Direct doorlinken naar Orweja
                    </div>
                </div>
            </div>

            <!-- Support -->
            <div style="background: #e3f2fd; border: 1px solid #bbdefb; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
                <h3 style="color: #1976d2; margin: 0 0 8px 0; font-size: 16px;">💬 Hulp nodig?</h3>
                <p style="color: #1976d2; margin: 0; font-size: 14px;">
                    Heb je vragen? Stuur een e-mail naar <a href="mailto:jachtproefalert@gmail.com" style="color: #1976d2;">jachtproefalert@gmail.com</a> of stel je vraag in onze Facebook groep!
                </p>
            </div>

            <!-- Footer -->
            <div style="text-align: center; border-top: 1px solid #e9ecef; padding-top: 24px; color: #6c757d;">
                <p style="margin: 0; font-size: 16px; font-weight: bold; color: #2e7d32;">Veel succes met het vinden van je volgende jachtproef!</p>
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
        "to": [user_email],
        "subject": "🎯 Welkom bij JachtProef Alert - Start je jachtproef avontuur!",
        "html": html_content,
    }

    try:
        email_result = resend.Emails.send(params)
        print(f"✅ Welcome email sent successfully!")
        print(f"📧 To: {user_email}")
        print(f"📧 Email ID: {email_result.get('id', 'unknown')}")
        print(f"🎯 Subject: {params['subject']}")
        print(f"📘 Facebook group included: https://www.facebook.com/groups/698746552871835/")
        return email_result.get('id')
    except Exception as e:
        print(f"❌ Error sending welcome email: {e}")
        return None

if __name__ == "__main__":
    print("🧪 Testing Welcome Email System")
    print("=" * 50)
    send_welcome_email_test() 