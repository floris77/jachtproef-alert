#!/usr/bin/env python3
"""
JachtProef Alert Scraper System - Documentation (2024-06)

ARCHITECTURE OVERVIEW:
- The production scraper is deployed as a Google Cloud Function named 'orweja-scraper' in the 'jachtproefalert' Google Cloud project.
- The function is located in the europe-west1 region and is triggered via HTTP POST requests.
- A Google Cloud Scheduler job named 'orweja-scraper-job' (also in europe-west1) triggers the scraper every 5 minutes.
- The function is protected: only the Cloud Scheduler service account and the App Engine default service account can invoke it (see IAM policy).
- The scraper fetches match data from the ORWEJA website, parses it, and writes/upserts it into the Firestore 'matches' collection in the 'jachtproefalert' Firebase project.
- The Flutter app reads match data directly from Firestore (no API is used).
- The source code for the deployed function may differ from this file; always check the Google Cloud Console for the live version.

TROUBLESHOOTING:
- If matches are missing in the app, check the Cloud Function logs, Scheduler job status, and Firestore 'matches' collection in the 'jachtproefalert' project.
- If the function is not running, verify IAM permissions and that the Scheduler job uses POST.
- If the code here is a placeholder, the real code may only exist in the deployed function or another backup.

Enhanced Orweja scraper with SendGrid email integration
"""
import requests
from bs4 import BeautifulSoup
import json
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import re
import os

# Import our Resend email service
from resend_service import JachtProefEmailService

# ORWEJA CREDENTIALS for protected calendar access
ORWEJA_USERNAME = "Jacqueline vd Hart-Snelle"
ORWEJA_PASSWORD = "Jindi11Leia"

# Initialize Firebase with default credentials (Cloud Function environment)
try:
    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    db = firestore.client()
except Exception as e:
    print(f"Firebase initialization error: {e}")
    db = None

def scraper_with_email(request):
    """Enhanced scraper that sends email notifications"""
    try:
        # Initialize email service
        email_service = JachtProefEmailService()
        
        # Your existing scraper logic (simplified here)
        new_matches = scrape_orweja_matches()
        
        if new_matches:
            # Upload to Firestore
            uploaded_count = upload_matches_to_firestore(new_matches)
            
            # Send email notifications
            send_email_notifications(email_service, new_matches)
                
            # Call the cleanup function
            mark_missing_matches_as_closed(new_matches)
            
            return {
                'status': 'success',
                'matches_found': len(new_matches),
                'uploaded': uploaded_count,
                'emails_sent': True
            }
        else:
            return {
                'status': 'success',
                'matches_found': 0,
                'message': 'No new matches found'
            }
            
    except Exception as e:
        print(f"❌ Scraper error: {e}")
        return {
            'status': 'error',
            'error': str(e)
        }

@functions_framework.http
def send_subscription_email(request):
    """Cloud function to send subscription receipt emails"""
    try:
        # Parse request data
        request_json = request.get_json(silent=True)
        if not request_json:
            return {'error': 'No JSON data provided'}, 400
        
        user_email = request_json.get('email')
        subscription_type = request_json.get('subscription_type')  # "Monthly Premium" or "Yearly Premium"
        amount = request_json.get('amount')  # "3.99" or "29.99"
        
        if not all([user_email, subscription_type, amount]):
            return {'error': 'Missing required fields: email, subscription_type, amount'}, 400
        
        # Initialize email service and send receipt
        email_service = JachtProefEmailService()
        success = email_service.send_subscription_receipt(user_email, subscription_type, amount)
        
        if success:
            # Log to Firestore
            log_email_sent(user_email, 'subscription_receipt', {
                'subscription_type': subscription_type,
                'amount': amount
            })
            
            return {
                'status': 'success',
                'message': f'Receipt sent to {user_email}'
            }
        else:
            return {'error': 'Failed to send email'}, 500
            
    except Exception as e:
        print(f"❌ Subscription email error: {e}")
        return {'error': str(e)}, 500

@functions_framework.http
def send_weekly_digest(request):
    """Send weekly digest emails to all subscribed users"""
    try:
        email_service = JachtProefEmailService()
        
        # Get matches from the last week
        one_week_ago = datetime.now() - timedelta(days=7)
        matches_ref = db.collection('matches').where('scraped_at', '>=', one_week_ago)
        recent_matches = [doc.to_dict() for doc in matches_ref.stream()]
        
        if not recent_matches:
            return {
                'status': 'success',
                'message': 'No matches found for weekly digest'
            }
        
        # Get users who want weekly digests
        users_ref = db.collection('users').where('weekly_digest', '==', True)
        digest_users = users_ref.stream()
        
        emails_sent = 0
        for user_doc in digest_users:
            user_data = user_doc.to_dict()
            user_email = user_data.get('email')
            
            if user_email:
                # Filter matches for this user's preferences
                user_matches = filter_matches_for_user(recent_matches, user_data)
                
                if user_matches:
                    success = email_service.send_weekly_digest(
                        user_email, 
                        user_matches, 
                        user_data
                    )
                    if success:
                        emails_sent += 1
                        log_email_sent(user_email, 'weekly_digest', {
                            'matches_count': len(user_matches)
                        })
        
        return {
            'status': 'success',
            'emails_sent': emails_sent,
            'matches_included': len(recent_matches)
        }
        
    except Exception as e:
        print(f"❌ Weekly digest error: {e}")
        return {'error': str(e)}, 500

def send_email_notifications(email_service, new_matches):
    """Send email notifications to users who have email alerts enabled"""
    try:
        # Get users who want immediate email alerts
        users_ref = db.collection('users').where('email_alerts', '==', True)
        alert_users = users_ref.stream()
        
        for user_doc in alert_users:
            user_data = user_doc.to_dict()
            user_email = user_data.get('email')
            
            if user_email:
                # Filter matches for this user's preferences
                user_matches = filter_matches_for_user(new_matches, user_data)
                
                if user_matches:
                    success = email_service.send_exam_alert(user_email, user_matches)
                    if success:
                        log_email_sent(user_email, 'exam_alert', {
                            'matches_count': len(user_matches)
                        })
    
    except Exception as e:
        print(f"❌ Email notification error: {e}")

def filter_matches_for_user(matches, user_preferences):
    """Filter matches based on user's preferences"""
    # For now, return all matches
    # TODO: Add filtering based on user preferences like:
    # - Preferred locations
    # - Preferred exam types
    # - Distance from user location
    return matches

def log_email_sent(email, email_type, metadata=None):
    """Log email sending to Firestore for tracking"""
    try:
        db.collection('email_logs').add({
            'email': email,
            'type': email_type,
            'sent_at': datetime.now(),
            'metadata': metadata or {}
        })
    except Exception as e:
        print(f"❌ Error logging email: {e}")

def scrape_orweja_matches():
    """Your existing scraping logic - simplified placeholder"""
    # This should contain your existing scraper logic
    # For now, returning a sample match
    return [
        {
            'date': '2024-06-15',
            'organizer': 'Test Vereniging',
            'location': 'Amsterdam',
            'type': 'SJP',
            'scraped_at': datetime.now()
        }
    ]

def upload_matches_to_firestore(matches):
    """Upsert matches in Firestore based on organizer, date, and location. Only update Orweja-sourced fields."""
    try:
        uploaded = 0
        for match in matches:
            # Build a unique key for the match (organizer + date + location)
            organizer = match.get('organizer', '').strip().lower()
            date = match.get('date', '').strip()
            location = match.get('location', '').strip().lower()
            # Query for existing match
            query = db.collection('matches') \
                .where('organizer', '==', match.get('organizer')) \
                .where('date', '==', match.get('date')) \
                .where('location', '==', match.get('location'))
            docs = list(query.stream())
            if docs:
                # Update only Orweja fields, preserve user fields
                doc_ref = docs[0].reference
                existing = docs[0].to_dict()
                # Only update Orweja fields (add more as needed)
                orweja_fields = ['registration_text', 'date', 'organizer', 'location', 'type', 'scraped_at']
                update_data = {k: v for k, v in match.items() if k in orweja_fields}
                doc_ref.update(update_data)
            else:
                db.collection('matches').add(match)
            uploaded += 1
        return uploaded
    except Exception as e:
        print(f"❌ Upload error: {e}")
        return 0 

def cleanup_past_matches():
    """Mark all past matches as closed if not already marked."""
    import datetime
    now = datetime.datetime.now()
    matches_ref = db.collection('matches')
    # Query all matches with a date in the past
    docs = matches_ref.where('date', '<', now).stream()
    updated = 0
    for doc in docs:
        data = doc.to_dict()
        reg_text = (data.get('registration_text') or data.get('registration', {}).get('text') or '').lower().strip()
        if reg_text not in ['niet mogelijk', 'niet meer mogelijk']:
            # Update registration text to 'niet meer mogelijk'
            matches_ref.document(doc.id).update({
                'registration_text': 'niet meer mogelijk',
                'registration': {'text': 'niet meer mogelijk'},
                'last_updated': now
            })
            updated += 1
    print(f'[Cleanup] Marked {updated} past matches as closed.')

def mark_missing_matches_as_closed(scraped_matches):
    """Mark matches in Firestore as closed if they are not present in the latest scrape."""
    # Build a set of unique keys for all scraped matches
    scraped_keys = set()
    for match in scraped_matches:
        organizer = match.get('organizer', '').strip().lower()
        date = match.get('date', '').strip()
        location = match.get('location', '').strip().lower()
        scraped_keys.add(f"{organizer}|{date}|{location}")

    # Fetch all matches from Firestore
    matches_ref = db.collection('matches')
    docs = matches_ref.stream()
    updated = 0
    now = datetime.datetime.now()
    for doc in docs:
        data = doc.to_dict()
        organizer = data.get('organizer', '').strip().lower()
        date = data.get('date', '').strip()
        location = data.get('location', '').strip().lower()
        key = f"{organizer}|{date}|{location}"
        reg_text = (data.get('registration_text') or data.get('registration', {}).get('text') or '').lower().strip()
        if key not in scraped_keys and reg_text not in ['niet mogelijk', 'niet meer mogelijk']:
            # Only update Orweja-sourced fields
            update_data = {}
            if 'registration_text' in data:
                update_data['registration_text'] = 'niet meer mogelijk'
            if 'registration' in data and isinstance(data['registration'], dict):
                update_data['registration'] = dict(data['registration'])
                update_data['registration']['text'] = 'niet meer mogelijk'
            if update_data:
                update_data['last_updated'] = now
                matches_ref.document(doc.id).update(update_data)
                updated += 1
    print(f"[Cleanup] Marked {updated} missing matches as closed.")

if __name__ == "__main__":
    print("[Manual Run] Scraping Orweja and updating Firestore...")
    matches = scrape_orweja_matches()
    uploaded = upload_matches_to_firestore(matches)
    print(f"[Manual Run] Uploaded or updated {uploaded} matches.")
    cleanup_past_matches() 