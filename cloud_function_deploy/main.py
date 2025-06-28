#!/usr/bin/env python3
"""
JachtProef Alert Scraper System - Main Cloud Function (2024-06)

ARCHITECTURE OVERVIEW:
- This is the main Cloud Function deployed as 'orweja-scraper' in the 'jachtproefalert' Google Cloud project.
- The function is located in the europe-west1 region and is triggered via HTTP POST requests.
- A Google Cloud Scheduler job named 'orweja-scraper-job' (also in europe-west1) triggers the scraper every 5 minutes.
- The function is protected: only the Cloud Scheduler service account and the App Engine default service account can invoke it (see IAM policy).
- The scraper fetches match data from the ORWEJA website, parses it, and writes/upserts it into the Firestore 'matches' collection in the 'jachtproefalert' Firebase project.
- The Flutter app reads match data directly from Firestore (no API is used).

TROUBLESHOOTING:
- If matches are missing in the app, check the Cloud Function logs, Scheduler job status, and Firestore 'matches' collection in the 'jachtproefalert' project.
- If the function is not running, verify IAM permissions and that the Scheduler job uses POST.
- If the code here is a placeholder, the real code may only exist in the deployed function or another backup.
"""
import requests
from bs4 import BeautifulSoup
import json
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import re
import os
import functions_framework

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

@functions_framework.http
def main(request):
    """
    Main Cloud Function for Orweja scraper
    This function scrapes the ORWEJA website and updates Firestore with match data
    """
    try:
        print("🚀 Starting Orweja scraper...")
        
        # Scrape matches from ORWEJA
        new_matches = scrape_orweja_matches()
        
        if new_matches:
            print(f"📊 Found {len(new_matches)} matches")
            
            # Upload to Firestore
            uploaded_count = upload_matches_to_firestore(new_matches)
            print(f"💾 Uploaded {uploaded_count} matches to Firestore")
            
            # Call the cleanup function
            mark_missing_matches_as_closed(new_matches)
            print("🧹 Cleanup completed")
            
            return {
                'status': 'success',
                'matches_found': len(new_matches),
                'uploaded': uploaded_count,
                'timestamp': datetime.now().isoformat()
            }
        else:
            print("📭 No new matches found")
            return {
                'status': 'success',
                'matches_found': 0,
                'message': 'No new matches found',
                'timestamp': datetime.now().isoformat()
            }
            
    except Exception as e:
        print(f"❌ Scraper error: {e}")
        return {
            'status': 'error',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }

def scrape_orweja_matches():
    """
    Scrape matches from the ORWEJA website
    This is a placeholder - replace with actual scraping logic
    """
    try:
        print("🔍 Scraping ORWEJA website...")
        
        # TODO: Implement actual scraping logic here
        # For now, return test data to verify the function works
        
        test_matches = [
            {
                'date': '2025-07-15',
                'organizer': 'Test Jachtvereniging',
                'location': 'Amsterdam',
                'type': 'SJP',
                'registration_text': 'Inschrijven',
                'scraped_at': datetime.now(),
                'source': 'orweja'
            },
            {
                'date': '2025-07-20',
                'organizer': 'Test Jachtclub',
                'location': 'Rotterdam',
                'type': 'MAP',
                'registration_text': 'vanaf 1 juli 10:00',
                'scraped_at': datetime.now(),
                'source': 'orweja'
            }
        ]
        
        print(f"✅ Scraped {len(test_matches)} test matches")
        return test_matches
        
    except Exception as e:
        print(f"❌ Error scraping ORWEJA: {e}")
        return []

def upload_matches_to_firestore(matches):
    """
    Upload matches to Firestore, updating existing ones if they exist
    """
    try:
        uploaded = 0
        for match in matches:
            # Build a unique key for the match (organizer + date + location)
            organizer = match.get('organizer', '').strip()
            date = match.get('date', '').strip()
            location = match.get('location', '').strip()
            
            # Query for existing match
            query = db.collection('matches') \
                .where('organizer', '==', organizer) \
                .where('date', '==', date) \
                .where('location', '==', location)
            
            docs = list(query.stream())
            
            if docs:
                # Update existing match
                doc_ref = docs[0].reference
                existing = docs[0].to_dict()
                
                # Only update Orweja fields, preserve user fields
                orweja_fields = ['registration_text', 'date', 'organizer', 'location', 'type', 'scraped_at', 'source']
                update_data = {k: v for k, v in match.items() if k in orweja_fields}
                update_data['last_updated'] = datetime.now()
                
                doc_ref.update(update_data)
                print(f"🔄 Updated existing match: {organizer} - {date}")
            else:
                # Add new match
                match['created_at'] = datetime.now()
                match['last_updated'] = datetime.now()
                db.collection('matches').add(match)
                print(f"➕ Added new match: {organizer} - {date}")
            
            uploaded += 1
        
        return uploaded
        
    except Exception as e:
        print(f"❌ Error uploading to Firestore: {e}")
        return 0

def mark_missing_matches_as_closed(scraped_matches):
    """
    Mark matches in Firestore as closed if they are not present in the latest scrape
    """
    try:
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
        
        for doc in docs:
            data = doc.to_dict()
            organizer = data.get('organizer', '').strip().lower()
            date = data.get('date', '').strip()
            location = data.get('location', '').strip().lower()
            key = f"{organizer}|{date}|{location}"
            
            reg_text = (data.get('registration_text') or data.get('registration', {}).get('text') or '').lower().strip()
            
            if key not in scraped_keys and reg_text not in ['niet mogelijk', 'niet meer mogelijk']:
                # Mark as closed
                update_data = {
                    'registration_text': 'niet meer mogelijk',
                    'last_updated': datetime.now()
                }
                
                if 'registration' in data and isinstance(data['registration'], dict):
                    update_data['registration'] = dict(data['registration'])
                    update_data['registration']['text'] = 'niet meer mogelijk'
                
                matches_ref.document(doc.id).update(update_data)
                updated += 1
                print(f"🚫 Marked match as closed: {organizer} - {date}")
        
        print(f"🧹 Marked {updated} missing matches as closed")
        
    except Exception as e:
        print(f"❌ Error marking matches as closed: {e}")

if __name__ == "__main__":
    print("🔧 Running scraper locally for testing...")
    matches = scrape_orweja_matches()
    uploaded = upload_matches_to_firestore(matches)
    print(f"✅ Test completed: {uploaded} matches processed")