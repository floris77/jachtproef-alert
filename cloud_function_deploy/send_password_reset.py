import os
import json
import resend
import functions_framework
from firebase_admin import auth, initialize_app

# Initialize Firebase Admin
try:
    initialize_app()
except ValueError:
    # App already initialized
    pass

# Configure Resend
resend.api_key = os.environ.get('RESEND_API_KEY')

@functions_framework.http
def send_password_reset(request):
    """Send password reset email via Resend for better deliverability"""
    
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
        
        email = request_json.get('email')
        reset_link = request_json.get('reset_link')
        
        if not email or not reset_link:
            return (json.dumps({'error': 'Missing email or reset_link'}), 400, {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            })
        
        # Build HTML email content
        html_content = _build_password_reset_html(reset_link)
        
        # Send email via Resend
        email_response = resend.Emails.send({
            "from": "JachtProef Alert <onboarding@resend.dev>",
            "reply_to": ["jachtproefalert@gmail.com"],
            "to": [email],
            "subject": "🔒 Wachtwoord resetten - JachtProef Alert",
            "html": html_content,
        })
        
        print(f"✅ Password reset email sent to {email}: {email_response}")
        
        return (json.dumps({
            'success': True,
            'message': f'Password reset email sent to {email}',
            'email_id': email_response.get('id')
        }), 200, {
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'application/json'
        })
        
    except Exception as e:
        print(f"❌ Error sending password reset email: {e}")
        return (json.dumps({'error': 'Failed to send password reset email'}), 500, {
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'application/json'
        })

def _build_password_reset_html(reset_link):
    """Build HTML content for password reset email"""
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Wachtwoord Resetten - JachtProef Alert</title>
    </head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 20px; background-color: #f6f8fa; line-height: 1.6;">
        <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
            <div style="text-align: center; margin-bottom: 32px;">
                <div style="width: 64px; height: 64px; background: linear-gradient(135deg, #FFA726, #FF9800); border-radius: 50%; margin: 0 auto 16px; display: flex; align-items: center; justify-content: center;">
                    <span style="font-size: 32px;">🔒</span>
                </div>
                <h1 style="color: #333; margin: 0; font-size: 24px; font-weight: 700;">Wachtwoord Resetten</h1>
                <p style="color: #666; font-size: 16px; margin: 8px 0;">Voor je JachtProef Alert account</p>
            </div>
            
            <p style="font-size: 16px; color: #555; margin-bottom: 24px;">Je hebt gevraagd om je wachtwoord te resetten. Klik op de knop hieronder om een nieuw wachtwoord in te stellen:</p>
            
            <div style="text-align: center; margin: 32px 0;">
                <a href="{reset_link}" style="display: inline-block; background: linear-gradient(135deg, #4CAF50, #45a049); color: white; padding: 16px 32px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; box-shadow: 0 2px 8px rgba(76, 175, 80, 0.3);">Wachtwoord Resetten</a>
            </div>
            
            <div style="background: #fff3cd; border: 1px solid #ffeaa7; padding: 16px; border-radius: 8px; margin: 24px 0;">
                <p style="margin: 0; font-size: 14px; color: #856404;"><strong>Belangrijk:</strong> Deze link is 24 uur geldig. Als je geen wachtwoord reset hebt aangevraagd, kun je deze email negeren.</p>
            </div>
            
            <p style="font-size: 14px; color: #666;">Problemen met de knop? Kopieer deze link naar je browser: <br><a href="{reset_link}" style="color: #0366d6; word-break: break-all;">{reset_link}</a></p>
            
            <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 32px 0;">
            
            <div style="text-align: center; color: #666; font-size: 14px;">
                <p style="margin: 8px 0;">Vragen? Stuur een email naar <a href="mailto:jachtproefalert@gmail.com" style="color: #0366d6;">jachtproefalert@gmail.com</a></p>
                <p style="margin: 8px 0;">© 2024 JachtProef Alert. Alle rechten voorbehouden.</p>
            </div>
        </div>
    </body>
    </html>
    """ 