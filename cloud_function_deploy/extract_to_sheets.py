#!/usr/bin/env python3
"""
Extract scraped data from Firebase and create CSV for Google Sheets
"""

import csv
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import os

def extract_data_to_csv():
    """
    Extract data from Firebase and create CSV for Google Sheets analysis
    """
    print("📊 EXTRACTING DATA FROM FIREBASE")
    print("=" * 50)
    
    # Initialize Firebase (use the same credentials as the scraper)
    try:
        # Try to use existing app
        db = firestore.client()
    except:
        # Initialize if not already done
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
        db = firestore.client()
    
    # Get the latest matches from Firestore
    matches_ref = db.collection('matches')
    docs = matches_ref.order_by('date', direction=firestore.Query.DESCENDING).limit(200).stream()
    
    # Extract data
    tier1_data = []
    tier2_data = []
    
    for doc in docs:
        data = doc.to_dict()
        
        # Determine if this is Tier 1 or Tier 2 based on the data structure
        if 'source' in data and data['source'] == 'matched':
            # This is a matched entry (has Tier 2 type)
            tier1_data.append({
                'date': data.get('date', ''),
                'organizer': data.get('organizer', ''),
                'type': data.get('type', ''),  # This is the Tier 2 type
                'location': data.get('location', ''),
                'registration_text': data.get('registration_text', ''),
                'source': 'matched'
            })
        else:
            # This is likely a Tier 1 entry (generic type)
            tier1_data.append({
                'date': data.get('date', ''),
                'organizer': data.get('organizer', ''),
                'type': data.get('type', ''),
                'location': data.get('location', ''),
                'registration_text': data.get('registration_text', ''),
                'source': 'tier1_only'
            })
    
    print(f"📊 Found {len(tier1_data)} entries in Firebase")
    
    # Create comprehensive analysis CSV
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f'jachtproef_analysis_{timestamp}.csv'
    
    with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = [
            'date', 'organizer', 'type', 'location', 'registration_text', 
            'source', 'notes'
        ]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        
        for entry in tier1_data:
            notes = ""
            if entry['source'] == 'matched':
                notes = "Successfully matched with Tier 2 data"
            else:
                notes = "Only in Tier 1 (no Tier 2 match found)"
            
            writer.writerow({
                'date': entry['date'],
                'organizer': entry['organizer'],
                'type': entry['type'],
                'location': entry['location'],
                'registration_text': entry['registration_text'],
                'source': entry['source'],
                'notes': notes
            })
    
    print(f"✅ CSV file created: {filename}")
    print(f"📊 Total entries: {len(tier1_data)}")
    
    # Count statistics
    matched_count = sum(1 for entry in tier1_data if entry['source'] == 'matched')
    unmatched_count = sum(1 for entry in tier1_data if entry['source'] == 'tier1_only')
    
    print(f"📊 Successfully matched: {matched_count}")
    print(f"📊 Unmatched: {unmatched_count}")
    print(f"📊 Match rate: {(matched_count/len(tier1_data)*100):.1f}%")
    
    print("\n" + "="*50)
    print("GOOGLE SHEETS UPLOAD INSTRUCTIONS")
    print("="*50)
    print("1. Go to Google Sheets (sheets.google.com)")
    print("2. Create a new spreadsheet")
    print("3. Go to File > Import")
    print("4. Upload the CSV file: " + filename)
    print("5. Choose 'Replace current sheet'")
    print("6. Click 'Import data'")
    print("\nThe data will be organized with columns:")
    print("- date: When the match occurs")
    print("- organizer: Who is organizing")
    print("- type: Match type (specific if matched, generic if not)")
    print("- location: Where the match takes place")
    print("- registration_text: Registration status")
    print("- source: Whether it was matched or not")
    print("- notes: Additional information")
    
    return filename

if __name__ == "__main__":
    extract_data_to_csv() 