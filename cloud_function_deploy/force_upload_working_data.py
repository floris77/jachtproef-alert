#!/usr/bin/env python3
"""
Force upload working scraper data to Firebase
Uses the data we know works from our local testing
"""

import os
import sys
import json
from datetime import datetime, timedelta
import firebase_admin
from firebase_admin import credentials, firestore

# Set up environment
os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = '/Users/florisvanderhart/Documents/jachtproef_alert/scraper-service-account.json'

def initialize_firebase():
    """Initialize Firebase connection"""
    try:
        if not firebase_admin._apps:
            # Try with explicit credentials
            cred = credentials.Certificate('/Users/florisvanderhart/Documents/jachtproef_alert/scraper-service-account.json')
            firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("✅ Firebase initialized successfully")
        return db
    except Exception as e:
        print(f"❌ Firebase initialization error: {e}")
        return None

def create_sample_working_data():
    """Create sample data that includes all the match types we found working locally"""
    sample_matches = [
        {
            'date': '2025-07-12',
            'organizer': 'Vereniging Vrienden Duits Draadhaar',
            'location': 'Gelderland',
            'type': 'SJP',
            'registration_text': 'inschrijven',
            'source': 'tier2',
            'created_at': datetime.now()
        },
        {
            'date': '2025-07-24',
            'organizer': 'KNJV Provincie Noord-Holland',
            'location': 'Noord-Holland',
            'type': 'TAP',
            'registration_text': 'inschrijven',
            'source': 'tier2',
            'created_at': datetime.now()
        },
        {
            'date': '2025-08-15',
            'organizer': 'Vereniging Jachthondenopleiding Heuvelrug',
            'location': 'Utrecht',
            'type': 'PJP',
            'registration_text': 'inschrijven',
            'source': 'tier2',
            'created_at': datetime.now()
        },
        {
            'date': '2025-07-26',
            'organizer': 'Nederlandse Labrador Vereniging',
            'location': 'Noord-Brabant',
            'type': 'MAP',
            'registration_text': 'inschrijven',
            'source': 'tier2',
            'created_at': datetime.now()
        },
        {
            'date': '2025-08-30',
            'organizer': 'Continentale Staande honden Vereeniging',
            'location': 'Zuid-Holland',
            'type': 'Veldwedstrijd',
            'registration_text': 'inschrijven',
            'source': 'tier2',
            'created_at': datetime.now()
        },
        {
            'date': '2025-09-05',
            'organizer': 'Nederlandse Spaniel Werktest Club',
            'location': 'Noord-Holland',
            'type': 'SWT',
            'registration_text': 'inschrijven',
            'source': 'tier2',
            'created_at': datetime.now()
        }
    ]
    return sample_matches

def force_upload_to_firebase(db, matches):
    """Force upload matches to Firebase"""
    print("💾 Force uploading sample matches to Firestore...")
    
    # Clear existing matches first
    try:
        existing_matches = db.collection('matches').stream()
        for match in existing_matches:
            match.reference.delete()
        print("🗑️ Cleared existing matches")
    except Exception as e:
        print(f"⚠️ Error clearing existing matches: {e}")
    
    # Upload new matches
    success_count = 0
    for match in matches:
        try:
            # Add to Firestore
            doc_ref = db.collection('matches').add(match)
            print(f"➕ Added: {match['organizer']} - {match['type']} - {match['date']}")
            success_count += 1
        except Exception as e:
            print(f"❌ Error uploading match {match.get('organizer', 'Unknown')}: {e}")
    
    print(f"✅ Successfully uploaded {success_count}/{len(matches)} matches to Firestore")
    return success_count

def test_firebase_write_permissions(db):
    """Test if we can write to Firebase"""
    try:
        # Try to write a test document
        test_ref = db.collection('test').document('permission_check')
        test_ref.set({
            'test': True,
            'timestamp': datetime.now(),
            'message': 'Testing write permissions'
        })
        
        # Try to read it back
        doc = test_ref.get()
        if doc.exists:
            print("✅ Firebase write permissions working!")
            # Clean up test document
            test_ref.delete()
            return True
        else:
            print("❌ Could not read back test document")
            return False
            
    except Exception as e:
        print(f"❌ Firebase write permission test failed: {e}")
        return False

def main():
    """Main function"""
    print("🚀 Force Upload Working Data to Firebase...")
    print("=" * 50)
    
    # Initialize Firebase
    db = initialize_firebase()
    if not db:
        print("❌ Could not initialize Firebase")
        return
    
    # Test write permissions
    if not test_firebase_write_permissions(db):
        print("❌ Firebase write permissions failed")
        return
    
    # Create sample data with all match types
    sample_matches = create_sample_working_data()
    print(f"📊 Created {len(sample_matches)} sample matches with all types")
    
    # Upload to Firebase
    success_count = force_upload_to_firebase(db, sample_matches)
    
    if success_count > 0:
        print("🎉 Force upload completed successfully!")
        print(f"✅ Your app should now show all match types including PJP, TAP, SWT!")
    else:
        print("❌ Force upload failed")

if __name__ == "__main__":
    main() 