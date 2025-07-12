#!/usr/bin/env python3
"""
Upload working data using Firebase CLI authentication
"""

import os
import sys
import json
from datetime import datetime
import firebase_admin
from firebase_admin import firestore

def initialize_firebase_with_cli():
    """Initialize Firebase using CLI authentication"""
    try:
        # Remove any existing GOOGLE_APPLICATION_CREDENTIALS
        if 'GOOGLE_APPLICATION_CREDENTIALS' in os.environ:
            del os.environ['GOOGLE_APPLICATION_CREDENTIALS']
        
        if not firebase_admin._apps:
            # Initialize without explicit credentials (uses CLI auth)
            firebase_admin.initialize_app()
        
        db = firestore.client()
        print("✅ Firebase initialized successfully with CLI auth")
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

def upload_matches(db, matches):
    """Upload matches to Firebase"""
    print("💾 Uploading sample matches to Firestore...")
    
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

def main():
    """Main function"""
    print("🚀 Upload Working Data via Firebase CLI...")
    print("=" * 50)
    
    # Initialize Firebase
    db = initialize_firebase_with_cli()
    if not db:
        print("❌ Could not initialize Firebase")
        return
    
    # Create sample data with all match types
    sample_matches = create_sample_working_data()
    print(f"📊 Created {len(sample_matches)} sample matches with all types")
    
    # Upload to Firebase
    success_count = upload_matches(db, sample_matches)
    
    if success_count > 0:
        print("🎉 Upload completed successfully!")
        print(f"✅ Your app should now show all match types including PJP, TAP, SWT!")
        
        # Show what was uploaded
        print("\n📋 Match Types Uploaded:")
        type_counts = {}
        for match in sample_matches:
            match_type = match['type']
            type_counts[match_type] = type_counts.get(match_type, 0) + 1
        
        for match_type, count in sorted(type_counts.items()):
            print(f"  {match_type}: {count} match(es)")
    else:
        print("❌ Upload failed")

if __name__ == "__main__":
    main() 