import json
import resend
import os
from datetime import datetime, timedelta
from typing import Dict, Any

# Configure Resend with API key
resend.api_key = os.environ.get('RESEND_API_KEY', 're_8AvpZCWL_4jPJQY4v99Ypmc6jBhZNijoj')

def send_match_notification(request):
    """
    Cloud Function to send match-specific email notifications
    """
    # Handle CORS preflight
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)

    # CORS headers for actual request
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    }

    try:
        if request.method != 'POST':
            return json.dumps({'error': 'Only POST method allowed'}), 405, headers

        # Parse request data
        request_json = request.get_json(silent=True)
        if not request_json:
            return json.dumps({'error': 'No JSON data provided'}), 400, headers

        # Extract required fields
        user_email = request_json.get('email')
        match_title = request_json.get('matchTitle')
        match_location = request_json.get('matchLocation')
        match_date = request_json.get('matchDate')
        notification_type = request_json.get('notificationType')
        match_key = request_json.get('matchKey')

        # Validate required fields
        if not all([user_email, match_title, match_location, match_date, notification_type]):
            return json.dumps({'error': 'Missing required fields'}), 400, headers

        # Generate email content based on notification type
        subject, html_content = _generate_email_content(
            notification_type, match_title, match_location, match_date
        )

        # Send email
        params = {
            "from": "JachtProef Alert <onboarding@resend.dev>",
            "reply_to": ["jachtproefalert@gmail.com"],
            "to": [user_email],
            "subject": subject,
            "html": html_content,
        }

        email_result = resend.Emails.send(params)
        
        return json.dumps({
            'success': True,
            'message': f'Match notification sent successfully',
            'email_id': email_result.get('id', 'unknown'),
            'notification_type': notification_type
        }), 200, headers

    except Exception as e:
        print(f"Error sending match notification: {str(e)}")
        return json.dumps({
            'error': 'Failed to send notification',
            'details': str(e)
        }), 500, headers

def _generate_email_content(notification_type: str, match_title: str, match_location: str, match_date: str) -> tuple[str, str]:
    """Generate email subject and HTML content based on notification type"""
    
    if notification_type == 'enrollment_opening':
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
                    <div style="display: flex; align-items: center; margin-bottom: 12px;">
                        <span style="color: #6c757d; font-size: 16px;">📍 <strong>Locatie:</strong> {match_location}</span>
                    </div>
                    <div style="display: flex; align-items: center;">
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
    
    elif notification_type == 'enrollment_closing':
        subject = f"⏰ Inschrijving sluit binnenkort: {match_title}"
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Inschrijving Sluit Binnenkort</title>
        </head>
        <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f8f9fa;">
            <div style="background: white; border-radius: 12px; padding: 32px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                <!-- Header -->
                <div style="text-align: center; border-bottom: 2px solid #e9ecef; padding-bottom: 24px; margin-bottom: 32px;">
                    <h1 style="color: #ff6b35; margin: 0; font-size: 28px; font-weight: bold;">⏰ JachtProef Alert</h1>
                    <p style="color: #6c757d; margin: 8px 0 0 0; font-size: 16px;">Laatste kans om in te schrijven!</p>
                </div>

                <!-- Urgent Alert Badge -->
                <div style="background: #ffeccc; border: 2px solid #ff6b35; border-radius: 8px; padding: 16px; margin-bottom: 24px; text-align: center;">
                    <p style="margin: 0; color: #cc4400; font-weight: bold; font-size: 18px;">🚨 Inschrijving sluit binnenkort!</p>
                </div>

                <!-- Match Details -->
                <div style="background: #f8f9fa; border-radius: 8px; padding: 24px; margin-bottom: 24px;">
                    <h2 style="color: #ff6b35; margin: 0 0 16px 0; font-size: 22px;">{match_title}</h2>
                    <div style="display: flex; align-items: center; margin-bottom: 12px;">
                        <span style="color: #6c757d; font-size: 16px;">📍 <strong>Locatie:</strong> {match_location}</span>
                    </div>
                    <div style="display: flex; align-items: center;">
                        <span style="color: #6c757d; font-size: 16px;">📅 <strong>Datum:</strong> {match_date}</span>
                    </div>
                </div>

                <!-- Action Button -->
                <div style="text-align: center; margin: 32px 0;">
                    <a href="https://jachtproefalert.app" style="display: inline-block; background: #ff6b35; color: white; padding: 16px 32px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; box-shadow: 0 2px 4px rgba(255, 107, 53, 0.3);">
                        🏃‍♂️ Schrijf je nu in!
                    </a>
                </div>

                <!-- Footer -->
                <div style="text-align: center; border-top: 1px solid #e9ecef; padding-top: 24px; color: #6c757d;">
                    <p style="margin: 0; font-size: 14px;">Deze urgente melding is verzonden omdat je notificaties hebt ingeschakeld voor deze proef.</p>
                    <p style="margin: 8px 0 0 0; font-size: 12px;">JachtProef Alert - Mis nooit meer een jachtproef!</p>
                </div>
            </div>
        </body>
        </html>
        """
    
    elif notification_type == 'match_reminder':
        subject = f"📅 Herinnering: {match_title} is vandaag/morgen"
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
                    <p style="margin: 0; color: #1976d2; font-weight: bold; font-size: 18px;">🎯 Vergeet niet: je proef is vandaag/morgen!</p>
                </div>

                <!-- Match Details -->
                <div style="background: #f8f9fa; border-radius: 8px; padding: 24px; margin-bottom: 24px;">
                    <h2 style="color: #1976d2; margin: 0 0 16px 0; font-size: 22px;">{match_title}</h2>
                    <div style="display: flex; align-items: center; margin-bottom: 12px;">
                        <span style="color: #6c757d; font-size: 16px;">📍 <strong>Locatie:</strong> {match_location}</span>
                    </div>
                    <div style="display: flex; align-items: center;">
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
    
    else:
        # Default notification
        subject = f"🎯 Update voor: {match_title}"
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <h1 style="color: #2E7D32;">🎯 JachtProef Alert</h1>
                <h2>{match_title}</h2>
                <p><strong>Locatie:</strong> {match_location}</p>
                <p><strong>Datum:</strong> {match_date}</p>
                <p>Er is een update voor deze proef waarop je notificaties hebt ingeschakeld.</p>
            </div>
        </body>
        </html>
        """

    return subject, html_content 