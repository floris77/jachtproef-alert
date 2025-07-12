#!/usr/bin/env python3
"""
Backup current Firebase data before replacing the scraper
This creates a timestamped backup file for comparison later
"""
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import json
import os

def backup_firebase_data():
    """Backup all current Firebase match data to a timestamped file"""
    try:
        # Initialize Firebase (assumes GOOGLE_APPLICATION_CREDENTIALS is set)
        if not firebase_admin._apps:
            firebase_admin.initialize_app()
        db = firestore.client()
        
        print("🔍 Backing up current Firebase data...")
        
        # Get all matches
        matches_ref = db.collection('matches')
        docs = list(matches_ref.stream())
        
        print(f"📊 Found {len(docs)} matches to backup")
        
        if len(docs) == 0:
            print("❌ No matches found in Firebase to backup!")
            return
        
        # Prepare backup data
        backup_data = {
            'backup_timestamp': datetime.now().isoformat(),
            'total_matches': len(docs),
            'backup_note': 'Backup before replacing scraper with new Tier 1 + Tier 2 system',
            'matches': []
        }
        
        # Extract match data
        for doc in docs:
            data = doc.data()
            match_data = {
                'id': doc.id,
                'data': data,
                'backup_timestamp': datetime.now().isoformat()
            }
            backup_data['matches'].append(match_data)
        
        # Create timestamped filename
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"firebase_backup_{timestamp}.json"
        
        # Save to file
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(backup_data, f, indent=2, ensure_ascii=False, default=str)
        
        print(f"✅ Backup saved to: {filename}")
        print(f"📁 File size: {os.path.getsize(filename) / 1024:.1f} KB")
        
        # Also create a summary file
        summary_filename = f"firebase_backup_summary_{timestamp}.txt"
        with open(summary_filename, 'w', encoding='utf-8') as f:
            f.write(f"Firebase Data Backup Summary\n")
            f.write(f"============================\n")
            f.write(f"Backup timestamp: {backup_data['backup_timestamp']}\n")
            f.write(f"Total matches: {len(docs)}\n")
            f.write(f"Backup note: {backup_data['backup_note']}\n\n")
            
            # Registration status summary
            reg_statuses = {}
            for match in backup_data['matches']:
                data = match['data']
                reg_text = (
                    data.get('registration_text') or
                    (data.get('registration', {}).get('text') if isinstance(data.get('registration'), dict) else None) or
                    ''
                ).strip().lower()
                reg_statuses[reg_text] = reg_statuses.get(reg_text, 0) + 1
            
            f.write("Registration Status Distribution:\n")
            for status, count in sorted(reg_statuses.items()):
                f.write(f"  '{status}': {count} matches\n")
            
            f.write(f"\nSample matches (first 10):\n")
            for i, match in enumerate(backup_data['matches'][:10]):
                data = match['data']
                f.write(f"  {i+1}. {data.get('organizer', 'Unknown')} - {data.get('date', 'Unknown')} - {data.get('type', 'Unknown')}\n")
        
        print(f"📋 Summary saved to: {summary_filename}")
        
        # Print quick summary
        print(f"\n📊 Backup Summary:")
        print(f"   Total matches: {len(docs)}")
        print(f"   Registration statuses: {len(reg_statuses)} different types")
        print(f"   Files created: {filename}, {summary_filename}")
        print(f"\n💾 You can now safely replace the scraper!")
        print(f"   After the new scraper runs, you can compare the data using these backup files.")
        
    except Exception as e:
        print(f"❌ Error backing up Firebase data: {e}")
        print("   Make sure you have proper Firebase credentials set up")

if __name__ == "__main__":
    backup_firebase_data() 