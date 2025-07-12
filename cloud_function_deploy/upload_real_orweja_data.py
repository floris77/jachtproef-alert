#!/usr/bin/env python3
"""
Upload actual ORWEJA data from our working scraper to Firebase
Uses the real comprehensive analysis data we successfully scraped
"""

import os
import csv
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

def extract_real_orweja_data():
    """Extract real ORWEJA matches from our comprehensive analysis CSV"""
    matches = []
    
    # Use the most recent comprehensive analysis file
    csv_file = 'comprehensive_analysis_20250710_224722.csv'
    
    print(f"📄 Reading real ORWEJA data from: {csv_file}")
    
    try:
        with open(csv_file, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            
            processed_matches = set()  # Track unique matches to avoid duplicates
            
            for row in reader:
                # Extract match data from the comprehensive analysis
                date = row.get('date', '').strip()
                tier1_organizer = row.get('tier1_organizer', '').strip()
                tier2_organizer = row.get('tier2_organizer', '').strip()
                tier1_location = row.get('tier1_location', '').strip()
                tier2_location = row.get('tier2_location', '').strip()
                tier1_type = row.get('tier1_type', '').strip()
                tier2_type = row.get('tier2_type', '').strip()
                tier1_registration = row.get('tier1_registration_text', '').strip()
                tier2_registration = row.get('tier2_registration_text', '').strip()
                
                # Skip empty rows
                if not date or (not tier1_organizer and not tier2_organizer):
                    continue
                
                # Prefer Tier 2 data (more accurate) over Tier 1
                organizer = tier2_organizer if tier2_organizer else tier1_organizer
                location = tier2_location if tier2_location else tier1_location
                match_type = tier2_type if tier2_type else tier1_type
                registration_text = tier2_registration if tier2_registration else tier1_registration
                
                # Clean up the data
                organizer = organizer.replace('[email protected]', '').strip()
                if organizer.endswith(' '):
                    organizer = organizer.strip()
                
                # Create unique key to avoid duplicates
                unique_key = f"{date}_{organizer}_{match_type}"
                if unique_key in processed_matches:
                    continue
                processed_matches.add(unique_key)
                
                # Create match object
                match = {
                    'date': date,
                    'organizer': organizer,
                    'location': location,
                    'type': match_type,
                    'registration_text': registration_text.lower() if registration_text else 'inschrijven',
                    'source': 'orweja_real_data',
                    'created_at': datetime.now()
                }
                
                matches.append(match)
                
        print(f"✅ Extracted {len(matches)} real ORWEJA matches")
        return matches
        
    except FileNotFoundError:
        print(f"❌ Could not find {csv_file}")
        return []
    except Exception as e:
        print(f"❌ Error reading CSV file: {e}")
        return []

def upload_real_matches(db, matches):
    """Upload real ORWEJA matches to Firebase"""
    print("💾 Uploading real ORWEJA matches to Firestore...")
    
    # Clear existing matches first
    try:
        existing_matches = db.collection('matches').stream()
        for match in existing_matches:
            match.reference.delete()
        print("🗑️ Cleared existing sample matches")
    except Exception as e:
        print(f"⚠️ Error clearing existing matches: {e}")
    
    # Upload real matches
    success_count = 0
    error_count = 0
    
    for match in matches:
        try:
            # Add to Firestore
            doc_ref = db.collection('matches').add(match)
            print(f"➕ Added: {match['organizer'][:50]}... - {match['type']} - {match['date']}")
            success_count += 1
        except Exception as e:
            print(f"❌ Error uploading match {match.get('organizer', 'Unknown')}: {e}")
            error_count += 1
    
    print(f"✅ Successfully uploaded {success_count}/{len(matches)} real ORWEJA matches")
    if error_count > 0:
        print(f"❌ Failed to upload {error_count} matches")
    
    return success_count

def analyze_real_data(matches):
    """Analyze the real match type distribution"""
    type_counts = {}
    for match in matches:
        match_type = match.get('type', 'Unknown')
        type_counts[match_type] = type_counts.get(match_type, 0) + 1
    
    print(f"\n📊 Real ORWEJA Match Type Distribution:")
    for match_type, count in sorted(type_counts.items(), key=lambda x: x[1], reverse=True):
        print(f"  {match_type}: {count} matches")
    
    return type_counts

def main():
    """Main function"""
    print("🚀 Upload Real ORWEJA Data to Firebase...")
    print("=" * 50)
    
    # Initialize Firebase
    db = initialize_firebase_with_cli()
    if not db:
        print("❌ Could not initialize Firebase")
        return
    
    # Extract real ORWEJA data from CSV
    real_matches = extract_real_orweja_data()
    if not real_matches:
        print("❌ No real ORWEJA data found")
        return
    
    # Analyze the data before uploading
    type_counts = analyze_real_data(real_matches)
    
    # Upload to Firebase
    success_count = upload_real_matches(db, real_matches)
    
    if success_count > 0:
        print("🎉 Real ORWEJA data upload completed successfully!")
        print(f"✅ Your app now has {success_count} actual hunting matches from ORWEJA!")
        print("✅ All match types (PJP, TAP, SWT, etc.) should now show with real data!")
    else:
        print("❌ Upload failed")

if __name__ == "__main__":
    main() 