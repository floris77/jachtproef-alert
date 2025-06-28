#!/usr/bin/env python3
"""
Resend Email Service for JachtProef Alert
Modern alternative to SendGrid with better free tier
"""
import os
import resend
import json
from datetime import datetime

class JachtProefEmailService:
    def __init__(self):
        # Get Resend API key from environment variable
        self.api_key = os.environ.get('RESEND_API_KEY')
        if not self.api_key:
            raise ValueError("RESEND_API_KEY environment variable not set")
        
        resend.api_key = self.api_key
        self.from_email = "JachtProef Alert <noreply@jachtproefalert.nl>"
        
    def send_exam_alert(self, to_email, exam_matches):
        """Send email alert about new exam matches"""
        try:
            html_content = self._build_exam_alert_html(exam_matches)
            
            params = {
                "from": self.from_email,
                "to": [to_email],
                "subject": f"🎯 {len(exam_matches)} nieuwe jachtproeven beschikbaar!",
                "html": html_content,
            }
            
            email = resend.Emails.send(params)
            print(f"📧 Exam alert sent to {to_email}: {email}")
            return True
            
        except Exception as e:
            print(f"❌ Error sending exam alert to {to_email}: {e}")
            return False
    
    def send_subscription_receipt(self, to_email, subscription_type, amount, trial_days=14):
        """Send subscription confirmation receipt"""
        try:
            html_content = self._build_subscription_receipt_html(subscription_type, amount, trial_days)
            
            params = {
                "from": self.from_email,
                "to": [to_email],
                "subject": "✅ Abonnement bevestiging - JachtProef Alert Premium",
                "html": html_content,
            }
            
            email = resend.Emails.send(params)
            print(f"🧾 Receipt sent to {to_email}: {email}")
            return True
            
        except Exception as e:
            print(f"❌ Error sending receipt to {to_email}: {e}")
            return False
    
    def send_weekly_digest(self, to_email, weekly_matches, user_preferences=None):
        """Send weekly digest of exam matches"""
        try:
            html_content = self._build_weekly_digest_html(weekly_matches, user_preferences)
            
            params = {
                "from": self.from_email,
                "to": [to_email],
                "subject": f"📊 Weekoverzicht: {len(weekly_matches)} jachtproeven deze week",
                "html": html_content,
            }
            
            email = resend.Emails.send(params)
            print(f"📊 Weekly digest sent to {to_email}: {email}")
            return True
            
        except Exception as e:
            print(f"❌ Error sending digest to {to_email}: {e}")
            return False
    
    def send_password_reset(self, to_email, reset_link):
        """Send password reset email"""
        try:
            html_content = self._build_password_reset_html(reset_link)
            
            params = {
                "from": self.from_email,
                "to": [to_email],
                "subject": "🔒 Wachtwoord resetten - JachtProef Alert",
                "html": html_content,
            }
            
            email = resend.Emails.send(params)
            print(f"🔒 Password reset sent to {to_email}: {email}")
            return True
            
        except Exception as e:
            print(f"❌ Error sending password reset to {to_email}: {e}")
            return False
    
    def _build_exam_alert_html(self, matches):
        """Build HTML content for exam alert"""
        matches_html = ""
        for match in matches:
            matches_html += f"""
            <div style="border: 1px solid #e0e0e0; border-radius: 8px; padding: 16px; margin: 12px 0; background: white; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
                <div style="color: #2E7D32; font-weight: bold; margin-bottom: 8px; font-size: 14px;">📅 {match.get('date', 'Datum onbekend')}</div>
                <div style="font-size: 16px; font-weight: bold; margin-bottom: 6px; color: #333;">{match.get('organizer', 'Organisator onbekend')}</div>
                <div style="color: #666; margin-bottom: 4px; font-size: 14px;">📍 {match.get('location', 'Locatie onbekend')}</div>
                <div style="color: #2E7D32; font-weight: 500;">🎯 {match.get('type', 'Type onbekend')}</div>
            </div>
            """
        
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Nieuwe Jachtproeven Beschikbaar!</title>
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 20px; background-color: #f6f8fa; line-height: 1.6;">
            <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
                <div style="background: linear-gradient(135deg, #2E7D32 0%, #4CAF50 100%); color: white; padding: 24px; text-align: center;">
                    <h1 style="margin: 0; font-size: 28px; font-weight: 700;">🎯 Nieuwe Jachtproeven!</h1>
                    <p style="margin: 12px 0 0 0; font-size: 16px; opacity: 0.9;">{len(matches)} nieuwe examens gevonden op {datetime.now().strftime('%d-%m-%Y')}</p>
                </div>
                
                <div style="padding: 24px;">
                    <p style="font-size: 16px; color: #333; margin-bottom: 8px;">Hallo,</p>
                    <p style="font-size: 16px; color: #666; margin-bottom: 20px;">Er zijn nieuwe jachtproeven beschikbaar die overeenkomen met jouw voorkeuren:</p>
                    
                    {matches_html}
                    
                    <div style="text-align: center; margin-top: 32px;">
                        <a href="https://apps.apple.com/app/jachtproef-alert" style="display: inline-block; background: linear-gradient(135deg, #2E7D32 0%, #4CAF50 100%); color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px;">Open JachtProef Alert</a>
                    </div>
                </div>
                
                <div style="background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px; border-top: 1px solid #e1e4e8;">
                    <p style="margin: 0 0 8px 0; font-weight: 600;">JachtProef Alert - Mis nooit een jachtproef!</p>
                    <p style="margin: 0;"><a href="#" style="color: #0366d6; text-decoration: none;">Uitschrijven</a> | <a href="#" style="color: #0366d6; text-decoration: none;">Voorkeuren wijzigen</a></p>
                </div>
            </div>
        </body>
        </html>
        """
    
    def _build_subscription_receipt_html(self, subscription_type, amount, trial_days):
        """Build HTML content for subscription receipt"""
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>Abonnement Bevestiging</title>
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 20px; background-color: #f6f8fa; line-height: 1.6;">
            <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
                <div style="text-align: center; margin-bottom: 32px;">
                    <div style="width: 64px; height: 64px; background: linear-gradient(135deg, #2E7D32 0%, #4CAF50 100%); border-radius: 50%; margin: 0 auto 16px; display: flex; align-items: center; justify-content: center;">
                        <span style="font-size: 32px;">✅</span>
                    </div>
                    <h1 style="color: #2E7D32; margin: 0; font-size: 24px; font-weight: 700;">Abonnement Bevestigd</h1>
                    <p style="color: #2E7D32; font-size: 18px; font-weight: 600; margin: 8px 0;">Welkom bij JachtProef Alert Premium!</p>
                </div>
                
                <div style="background: #f6f8fa; padding: 24px; border-radius: 8px; margin: 24px 0; border-left: 4px solid #2E7D32;">
                    <h3 style="margin-top: 0; color: #333; font-size: 18px;">Abonnement Details:</h3>
                    <div style="display: grid; gap: 8px;">
                        <p style="margin: 0;"><strong>Type:</strong> {subscription_type}</p>
                        <p style="margin: 0;"><strong>Prijs:</strong> €{amount}/maand</p>
                        <p style="margin: 0;"><strong>Gratis proefperiode:</strong> {trial_days} dagen</p>
                        <p style="margin: 0;"><strong>Status:</strong> <span style="color: #2E7D32; font-weight: 600;">Actief</span></p>
                    </div>
                </div>
                
                <div style="background: #e8f5e8; padding: 20px; border-radius: 8px; margin: 24px 0;">
                    <h4 style="margin-top: 0; color: #2E7D32;">🎉 Premium Voordelen Geactiveerd:</h4>
                    <ul style="margin: 0; padding-left: 20px; color: #555;">
                        <li>Onbeperkte push notificaties</li>
                        <li>Email alerts voor nieuwe examens</li>
                        <li>Weekelijkse digest emails</li>
                        <li>Prioritaire klantenservice</li>
                        <li>Vroege toegang tot nieuwe features</li>
                    </ul>
                </div>
                
                <p style="font-size: 16px; color: #555;">Je hebt nu toegang tot alle premium functies van JachtProef Alert. Geniet van de verbeterde ervaring!</p>
                
                <p style="font-size: 14px; color: #666;">Vragen over je abonnement? Stuur een email naar <a href="mailto:support@jachtproefalert.nl" style="color: #0366d6;">support@jachtproefalert.nl</a></p>
                
                <div style="text-align: center; margin-top: 32px;">
                    <a href="https://apps.apple.com/app/jachtproef-alert" style="display: inline-block; background: linear-gradient(135deg, #2E7D32 0%, #4CAF50 100%); color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: 600;">Open JachtProef Alert</a>
                </div>
            </div>
        </body>
        </html>
        """
    
    def _build_weekly_digest_html(self, matches, user_preferences):
        """Build HTML content for weekly digest"""
        matches_html = ""
        for i, match in enumerate(matches):
            row_color = "#f8f9fa" if i % 2 == 0 else "white"
            matches_html += f"""
            <tr style="background: {row_color};">
                <td style="padding: 12px; border-bottom: 1px solid #e1e4e8; font-size: 14px;">{match.get('date', 'Datum onbekend')}</td>
                <td style="padding: 12px; border-bottom: 1px solid #e1e4e8; font-weight: 600; font-size: 14px;">{match.get('organizer', 'Organisator onbekend')}</td>
                <td style="padding: 12px; border-bottom: 1px solid #e1e4e8; color: #666; font-size: 14px;">{match.get('location', 'Locatie onbekend')}</td>
                <td style="padding: 12px; border-bottom: 1px solid #e1e4e8; font-size: 14px;">
                    <span style="background: #e8f5e8; color: #2E7D32; padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: 500;">{match.get('type', 'Type onbekend')}</span>
                </td>
            </tr>
            """
        
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>Weekoverzicht Jachtproeven</title>
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 20px; background-color: #f6f8fa; line-height: 1.6;">
            <div style="max-width: 700px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
                <div style="background: linear-gradient(135deg, #2E7D32 0%, #4CAF50 100%); color: white; padding: 24px; text-align: center;">
                    <h1 style="margin: 0; font-size: 28px; font-weight: 700;">📊 Weekoverzicht</h1>
                    <p style="margin: 12px 0 0 0; font-size: 16px; opacity: 0.9;">{len(matches)} jachtproeven beschikbaar deze week</p>
                </div>
                
                <div style="padding: 24px;">
                    <p style="font-size: 16px; color: #333; margin-bottom: 8px;">Hallo,</p>
                    <p style="font-size: 16px; color: #666; margin-bottom: 24px;">Hier is je weekoverzicht van alle beschikbare jachtproeven:</p>
                    
                    <div style="overflow-x: auto;">
                        <table style="width: 100%; border-collapse: collapse; margin: 20px 0; border-radius: 8px; overflow: hidden; border: 1px solid #e1e4e8;">
                            <thead>
                                <tr style="background: #2E7D32; color: white;">
                                    <th style="padding: 16px 12px; text-align: left; font-weight: 600; font-size: 14px;">Datum</th>
                                    <th style="padding: 16px 12px; text-align: left; font-weight: 600; font-size: 14px;">Organisator</th>
                                    <th style="padding: 16px 12px; text-align: left; font-weight: 600; font-size: 14px;">Locatie</th>
                                    <th style="padding: 16px 12px; text-align: left; font-weight: 600; font-size: 14px;">Type</th>
                                </tr>
                            </thead>
                            <tbody>
                                {matches_html}
                            </tbody>
                        </table>
                    </div>
                    
                    <div style="text-align: center; margin-top: 32px;">
                        <a href="https://apps.apple.com/app/jachtproef-alert" style="display: inline-block; background: linear-gradient(135deg, #2E7D32 0%, #4CAF50 100%); color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: 600;">Open JachtProef Alert</a>
                    </div>
                </div>
                
                <div style="background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px; border-top: 1px solid #e1e4e8;">
                    <p style="margin: 0 0 8px 0; font-weight: 600;">JachtProef Alert - Mis nooit een jachtproef!</p>
                    <p style="margin: 0;"><a href="#" style="color: #0366d6; text-decoration: none;">Uitschrijven</a> | <a href="#" style="color: #0366d6; text-decoration: none;">Voorkeuren wijzigen</a></p>
                </div>
            </div>
        </body>
        </html>
        """
    
    def _build_password_reset_html(self, reset_link):
        """Build HTML content for password reset"""
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>Wachtwoord Resetten</title>
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 20px; background-color: #f6f8fa; line-height: 1.6;">
            <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
                <div style="text-align: center; margin-bottom: 32px;">
                    <div style="width: 64px; height: 64px; background: #FFA726; border-radius: 50%; margin: 0 auto 16px; display: flex; align-items: center; justify-content: center;">
                        <span style="font-size: 32px;">🔒</span>
                    </div>
                    <h1 style="color: #333; margin: 0; font-size: 24px; font-weight: 700;">Wachtwoord Resetten</h1>
                    <p style="color: #666; font-size: 16px; margin: 8px 0;">Voor je JachtProef Alert account</p>
                </div>
                
                <p style="font-size: 16px; color: #555; margin-bottom: 24px;">Je hebt gevraagd om je wachtwoord te resetten. Klik op de knop hieronder om een nieuw wachtwoord in te stellen:</p>
                
                <div style="text-align: center; margin: 32px 0;">
                    <a href="{reset_link}" style="display: inline-block; background: #FFA726; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px;">Nieuw Wachtwoord Instellen</a>
                </div>
                
                <div style="background: #fff3cd; border: 1px solid #ffeaa7; padding: 16px; border-radius: 8px; margin: 24px 0;">
                    <p style="margin: 0; font-size: 14px; color: #856404;"><strong>Belangrijk:</strong> Deze link is 24 uur geldig. Als je geen wachtwoord reset hebt aangevraagd, kun je deze email negeren.</p>
                </div>
                
                <p style="font-size: 14px; color: #666;">Problemen met de knop? Kopieer deze link naar je browser: <br><a href="{reset_link}" style="color: #0366d6; word-break: break-all;">{reset_link}</a></p>
                
                <p style="font-size: 14px; color: #666; margin-top: 32px;">Vragen? Stuur een email naar <a href="mailto:support@jachtproefalert.nl" style="color: #0366d6;">support@jachtproefalert.nl</a></p>
            </div>
        </body>
        </html>
        """ 