#!/usr/bin/env python3
"""
JachtProef Alert - Welcome Email Cloud Function

This function sends welcome emails to new users when they register.
Deployed as: send-welcome-email
URL: https://us-central1-jachtproefalert.cloudfunctions.net/send-welcome-email
"""

import os
import json
import resend
import functions_framework
from firebase_admin import auth, initialize_app
from datetime import datetime

# Initialize Firebase Admin
try:
    initialize_app()
except ValueError:
    # App already initialized
    pass

# Configure Resend
resend.api_key = os.environ.get('RESEND_API_KEY', 're_8AvpZCWL_4jPJQY4v99Ypmc6jBhZNijoj')

@functions_framework.http
def send_welcome_email(request):
    """Send welcome email to new user via Resend"""
    
    # Handle CORS
    if request.method == 'OPTIONS':
        return ('', 200, {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        })
    
    # Verify Firebase Auth token
    try:
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return (json.dumps({'error': 'No valid authorization token'}), 401, {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            })
        
        token = auth_header.split('Bearer ')[1]
        decoded_token = auth.verify_id_token(token)
        user_id = decoded_token['uid']
        
    except Exception as e:
        return (json.dumps({'error': 'Invalid authorization token'}), 401, {
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'application/json'
        })
    
    try:
        # Parse request data
        request_json = request.get_json(silent=True)
        if not request_json:
            return (json.dumps({'error': 'No JSON data provided'}), 400, {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            })
        
        user_email = request_json.get('email')
        user_name = request_json.get('name')
        
        if not user_email or not user_name:
            return (json.dumps({'error': 'Missing email or name'}), 400, {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            })
        
        # Build HTML email content
        html_content = _build_welcome_email_html(user_name)
        
        # Send email via Resend
        email_response = resend.Emails.send({
            "from": "JachtProef Alert <onboarding@resend.dev>",
            "reply_to": ["jachtproefalert@gmail.com"],
            "to": [user_email],
            "subject": "🎯 Welkom bij JachtProef Alert!",
            "html": html_content,
        })
        
        print(f"✅ Welcome email sent to {user_email}: {email_response}")
        
        return (json.dumps({
            'success': True,
            'message': f'Welcome email sent to {user_email}',
            'email_id': email_response.get('id')
        }), 200, {
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'application/json'
        })
        
    except Exception as e:
        print(f"❌ Error sending welcome email: {e}")
        return (json.dumps({'error': 'Failed to send welcome email'}), 500, {
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'application/json'
        })

def _build_welcome_email_html(user_name):
    """Build the welcome email HTML content"""
    
    return f"""
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
                <p style="margin: 0; color: #2e7d32; font-size: 16px;">Je bent nu onderdeel van de grootste jachtproef community van Nederland!</p>
            </div>

            <!-- What You Get -->
            <div style="margin-bottom: 24px;">
                <h3 style="color: #2e7d32; margin-bottom: 16px;">🌟 Wat krijg je met JachtProef Alert?</h3>
                <ul style="padding-left: 20px; margin: 0;">
                    <li style="margin-bottom: 8px;"><strong>Onbeperkte notificaties</strong> - Nooit meer een jachtproef missen</li>
                    <li style="margin-bottom: 8px;"><strong>Email alerts</strong> - Krijg meldingen ook per email</li>
                    <li style="margin-bottom: 8px;"><strong>Persoonlijke agenda</strong> - Bewaar je favoriete proeven</li>
                    <li style="margin-bottom: 8px;"><strong>Community updates</strong> - Blijf op de hoogte van het laatste nieuws</li>
                    <li style="margin-bottom: 8px;"><strong>14 dagen gratis proefperiode</strong> - Test alle premium features</li>
                </ul>
            </div>

            <!-- CTA Button -->
            <div style="text-align: center; margin-bottom: 32px;">
                <a href="https://play.google.com/store/apps/details?id=com.jachtproef.alert" 
                   style="display: inline-block; background: #2E7D32; color: white; padding: 16px 32px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px;">
                    🚀 Start je Premium proefperiode
                </a>
            </div>

            <!-- Community Section -->
            <div style="background: #f8f9fa; border-radius: 8px; padding: 20px; margin-bottom: 24px;">
                <h3 style="color: #2e7d32; margin-top: 0; margin-bottom: 12px;">👥 Word lid van onze community</h3>
                <p style="margin: 0 0 12px 0;">Sluit je aan bij onze Facebook groep voor tips, vragen en updates:</p>
                <a href="https://www.facebook.com/groups/698746552871835/" 
                   style="color: #2E7D32; text-decoration: none; font-weight: bold;">
                    📘 JachtProef Alert Community
                </a>
            </div>

            <!-- Footer -->
            <div style="text-align: center; border-top: 1px solid #e9ecef; padding-top: 24px; color: #6c757d; font-size: 14px;">
                <p style="margin: 0 0 8px 0;">Heb je vragen? Neem contact op via <a href="mailto:jachtproefalert@gmail.com" style="color: #2E7D32;">jachtproefalert@gmail.com</a></p>
                <p style="margin: 0;">© 2024 JachtProef Alert. Alle rechten voorbehouden.</p>
            </div>
        </div>
    </body>
    </html>
    """

if __name__ == "__main__":
    # Test the function locally
    print("🧪 Testing Welcome Email Function")
    print("=" * 50)
    
    # Simulate a test request
    class MockRequest:
        def __init__(self):
            self.method = 'POST'
            self.headers = {'Authorization': 'Bearer test-token'}
        
        def get_json(self, silent=True):
            return {
                'email': 'test@example.com',
                'name': 'Test User'
            }
    
    # Test the function
    try:
        result = send_welcome_email(MockRequest())
        print(f"✅ Test completed: {result}")
    except Exception as e:
        print(f"❌ Test failed: {e}") 