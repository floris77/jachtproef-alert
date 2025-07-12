#!/usr/bin/env python3
"""
Simple script to check current Firebase data and scraper status
"""
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import json

def check_firebase_data():
    """Check current Firebase data and scraper status"""
    try:
        # Initialize Firebase (assumes GOOGLE_APPLICATION_CREDENTIALS is set)
        if not firebase_admin._apps:
            firebase_admin.initialize_app()
        db = firestore.client()
        
        print("🔍 Checking Firebase data...")
        
        # Get all matches
        matches_ref = db.collection('matches')
        docs = list(matches_ref.stream())
        
        print(f"📊 Total matches in Firebase: {len(docs)}")
        
        if len(docs) == 0:
            print("❌ No matches found in Firebase!")
            print("   This could mean:")
            print("   - Scraper hasn't run yet")
            print("   - Scraper failed to run")
            print("   - Database permissions issue")
            return
        
        # Analyze registration statuses
        reg_statuses = {}
        recent_matches = []
        past_enrollment_matches = []
        
        for doc in docs:
            data = doc.data()
            
            # Get registration text
            reg_text = (
                data.get('registration_text') or
                (data.get('registration', {}).get('text') if isinstance(data.get('registration'), dict) else None) or
                ''
            ).strip().lower()
            
            # Count registration statuses
            reg_statuses[reg_text] = reg_statuses.get(reg_text, 0) + 1
            
            # Check for recent updates (last 24 hours)
            scraped_at = data.get('scraped_at')
            if scraped_at:
                if isinstance(scraped_at, datetime):
                    scraped_time = scraped_at
                else:
                    scraped_time = scraped_at.to_pydatetime()
                
                if scraped_time > datetime.now() - timedelta(hours=24):
                    recent_matches.append({
                        'organizer': data.get('organizer', 'Unknown'),
                        'date': data.get('date', 'Unknown'),
                        'scraped_at': scraped_time.isoformat(),
                        'reg_text': reg_text
                    })
            
            # Check for matches with past enrollment dates
            if reg_text.startswith('vanaf '):
                try:
                    # Parse enrollment date from "vanaf DD-MM-YYYY HH:MM"
                    date_time_str = reg_text[6:].strip()  # Remove 'vanaf '
                    parts = date_time_str.split()
                    if len(parts) >= 1:
                        date_part = parts[0]  # DD-MM-YYYY
                        date_components = date_part.split('-')
                        if len(date_components) == 3:
                            enrollment_date = datetime(
                                int(date_components[2]),  # Year
                                int(date_components[1]),  # Month
                                int(date_components[0])   # Day
                            )
                            
                            if enrollment_date < datetime.now():
                                past_enrollment_matches.append({
                                    'organizer': data.get('organizer', 'Unknown'),
                                    'date': data.get('date', 'Unknown'),
                                    'enrollment_date': enrollment_date.isoformat(),
                                    'reg_text': reg_text
                                })
                except Exception as e:
                    print(f"⚠️ Error parsing enrollment date: {e}")
        
        # Print results
        print(f"\n📈 Registration Status Distribution:")
        for status, count in sorted(reg_statuses.items()):
            print(f"   '{status}': {count} matches")
        
        print(f"\n🕒 Recent Updates (last 24 hours): {len(recent_matches)}")
        if recent_matches:
            print("   Recent matches:")
            for match in recent_matches[:5]:  # Show first 5
                print(f"   - {match['organizer']} ({match['date']}) - {match['reg_text']}")
            if len(recent_matches) > 5:
                print(f"   ... and {len(recent_matches) - 5} more")
        else:
            print("   ❌ No recent updates found!")
            print("   This suggests the scraper may not be running properly")
        
        print(f"\n⚠️ Matches with Past Enrollment Dates: {len(past_enrollment_matches)}")
        if past_enrollment_matches:
            print("   These should be updated by the scraper:")
            for match in past_enrollment_matches[:5]:  # Show first 5
                print(f"   - {match['organizer']} ({match['date']}) - Enrollment was {match['enrollment_date']}")
            if len(past_enrollment_matches) > 5:
                print(f"   ... and {len(past_enrollment_matches) - 5} more")
        
        # Check scraper status
        print(f"\n🔧 Scraper Status Analysis:")
        if len(recent_matches) > 0:
            print("   ✅ Scraper appears to be running (recent updates found)")
        else:
            print("   ❌ Scraper may not be running (no recent updates)")
        
        if len(past_enrollment_matches) > 0:
            print("   ⚠️ Some matches have outdated enrollment status")
            print("   This is normal if enrollment dates just passed")
        
        # Overall assessment
        print(f"\n📋 Overall Assessment:")
        if len(docs) > 0 and len(recent_matches) > 0:
            print("   ✅ Firebase has data and scraper is active")
        elif len(docs) > 0 and len(recent_matches) == 0:
            print("   ⚠️ Firebase has data but scraper may not be running")
        else:
            print("   ❌ Firebase has no data - scraper needs investigation")
        
    except Exception as e:
        print(f"❌ Error checking Firebase data: {e}")
        print("   Make sure you have proper Firebase credentials set up")

if __name__ == "__main__":
    check_firebase_data() 