#!/usr/bin/env python3
"""
Direct test script to send example match notification emails using Resend API
"""
import resend
import os

# Configure Resend API
resend.api_key = "re_8AvpZCWL_4jPJQY4v99Ypmc6jBhZNijoj"

def generate_enrollment_email():
    """Generate enrollment opening email content"""
    match_title = "Nederlandse Labrador Vereniging"
    match_location = "Lelystad, Flevoland"
    match_date = "15 juni 2025"
    
    subject = f"🎯 Inschrijving geopend: {match_title}"
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Inschrijving Geopend</title>
    </head>
    <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f8f9fa;">
        <div style="background: white; border-radius: 12px; padding: 32px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
            <!-- Header -->
            <div style="text-align: center; border-bottom: 2px solid #e9ecef; padding-bottom: 24px; margin-bottom: 32px;">
                <h1 style="color: #2E7D32; margin: 0; font-size: 28px; font-weight: bold;">🎯 JachtProef Alert</h1>
                <p style="color: #6c757d; margin: 8px 0 0 0; font-size: 16px;">Inschrijving is nu geopend!</p>
            </div>

            <!-- Alert Badge -->
            <div style="background: #e8f5e8; border: 2px solid #4caf50; border-radius: 8px; padding: 16px; margin-bottom: 24px; text-align: center;">
                <p style="margin: 0; color: #2e7d32; font-weight: bold; font-size: 18px;">⏰ Je kunt je nu inschrijven!</p>
            </div>

            <!-- Match Details -->
            <div style="background: #f8f9fa; border-radius: 8px; padding: 24px; margin-bottom: 24px;">
                <h2 style="color: #2e7d32; margin: 0 0 16px 0; font-size: 22px;">{match_title}</h2>
                <div style="margin-bottom: 12px;">
                    <span style="color: #6c757d; font-size: 16px;">📍 <strong>Locatie:</strong> {match_location}</span>
                </div>
                <div>
                    <span style="color: #6c757d; font-size: 16px;">📅 <strong>Datum:</strong> {match_date}</span>
                </div>
            </div>

                         <!-- Action Button -->
             <div style="text-align: center; margin: 32px 0;">
                 <a href="https://my.orweja.nl/login" style="display: inline-block; background: #2e7d32; color: white; padding: 16px 32px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; box-shadow: 0 2px 4px rgba(46, 125, 50, 0.3);">
                     📝 Inschrijven via Orweja
                 </a>
             </div>

            <!-- Tips -->
            <div style="background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
                <h3 style="color: #856404; margin: 0 0 12px 0; font-size: 16px;">💡 Tips voor inschrijving:</h3>
                <ul style="color: #856404; margin: 0; padding-left: 20px;">
                    <li>Controleer de inschrijfvoorwaarden</li>
                    <li>Zorg dat je alle benodigde documenten hebt</li>
                    <li>Schrijf je snel in - plekken zijn vaak beperkt</li>
                </ul>
            </div>

            <!-- Footer -->
            <div style="text-align: center; border-top: 1px solid #e9ecef; padding-top: 24px; color: #6c757d;">
                <p style="margin: 0; font-size: 14px;">Deze melding is verzonden omdat je notificaties hebt ingeschakeld voor deze proef.</p>
                <p style="margin: 8px 0 0 0; font-size: 12px;">JachtProef Alert - Mis nooit meer een jachtproef!</p>
            </div>
        </div>
    </body>
    </html>
    """
    return subject, html_content

def generate_reminder_email():
    """Generate match reminder email content"""
    match_title = "KNJV Provincie Gelderland"
    match_location = "Barneveld, Gelderland"
    match_date = "22 juni 2025"
    
    subject = f"📅 Herinnering: {match_title} is binnenkort"
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
            </div>

            <!-- Reminder Badge -->
            <div style="background: #e3f2fd; border: 2px solid #1976d2; border-radius: 8px; padding: 16px; margin-bottom: 24px; text-align: center;">
                <p style="margin: 0; color: #1976d2; font-weight: bold; font-size: 18px;">🎯 Vergeet niet: je proef is binnenkort!</p>
            </div>

            <!-- Match Details -->
            <div style="background: #f8f9fa; border-radius: 8px; padding: 24px; margin-bottom: 24px;">
                <h2 style="color: #1976d2; margin: 0 0 16px 0; font-size: 22px;">{match_title}</h2>
                <div style="margin-bottom: 12px;">
                    <span style="color: #6c757d; font-size: 16px;">📍 <strong>Locatie:</strong> {match_location}</span>
                </div>
                <div>
                    <span style="color: #6c757d; font-size: 16px;">📅 <strong>Datum:</strong> {match_date}</span>
                </div>
            </div>

            <!-- Checklist -->
            <div style="background: #e8f5e8; border: 1px solid #4caf50; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
                <h3 style="color: #2e7d32; margin: 0 0 12px 0; font-size: 16px;">✅ Laatste controle:</h3>
                <ul style="color: #2e7d32; margin: 0; padding-left: 20px;">
                    <li>Heb je alle benodigde documenten?</li>
                    <li>Weet je de exacte locatie en tijd?</li>
                    <li>Is je hond in goede conditie?</li>
                    <li>Heb je contact informatie van de organisator?</li>
                </ul>
            </div>

            <!-- Footer -->
            <div style="text-align: center; border-top: 1px solid #e9ecef; padding-top: 24px; color: #6c757d;">
                <p style="margin: 0; font-size: 14px;">Veel succes met je jachtproef!</p>
                <p style="margin: 8px 0 0 0; font-size: 12px;">JachtProef Alert - Mis nooit meer een jachtproef!</p>
            </div>
        </div>
    </body>
    </html>
    """
    return subject, html_content

def send_test_emails():
    """Send both test emails"""
    print("🧪 Sending Example Match Notification Emails")
    print("=" * 50)
    
    # Send enrollment opening email
    print("\n📧 Sending enrollment opening email...")
    try:
        subject, html_content = generate_enrollment_email()
        
        params = {
            "from": "JachtProef Alert <onboarding@resend.dev>",
            "reply_to": ["jachtproefalert@gmail.com"],
            "to": ["floris@nordrobe.com"],
            "subject": subject,
            "html": html_content,
        }
        
        email_result = resend.Emails.send(params)
        print(f"✅ Enrollment email sent successfully!")
        print(f"   Subject: {subject}")
        print(f"   Email ID: {email_result.get('id', 'unknown')}")
        
    except Exception as e:
        print(f"❌ Error sending enrollment email: {e}")
    
    # Send match reminder email
    print("\n📧 Sending match reminder email...")
    try:
        subject, html_content = generate_reminder_email()
        
        params = {
            "from": "JachtProef Alert <onboarding@resend.dev>",
            "reply_to": ["jachtproefalert@gmail.com"],
            "to": ["floris@nordrobe.com"],
            "subject": subject,
            "html": html_content,
        }
        
        email_result = resend.Emails.send(params)
        print(f"✅ Reminder email sent successfully!")
        print(f"   Subject: {subject}")
        print(f"   Email ID: {email_result.get('id', 'unknown')}")
        
    except Exception as e:
        print(f"❌ Error sending reminder email: {e}")
    
    print(f"\n🎯 Check your inbox at floris@nordrobe.com")
    print(f"📧 You should receive 2 example emails:")
    print(f"   1. 🎯 Inschrijving geopend: Nederlandse Labrador Vereniging")
    print(f"   2. 📅 Herinnering: KNJV Provincie Gelderland is binnenkort")
    print(f"\n💡 These show exactly what users will receive when they follow specific matches!")

if __name__ == "__main__":
    send_test_emails() 