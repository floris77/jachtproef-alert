#!/usr/bin/env python3
"""
Check what's actually stored in Firebase for PJP matches
"""

import firebase_admin
from firebase_admin import credentials, firestore
import json

def check_firebase_pjp():
    """Check what's actually stored in Firebase for PJP matches"""
    print("🔍 CHECKING FIREBASE FOR PJP MATCHES")
    print("=" * 50)
    
    # Initialize Firebase
    try:
        db = firestore.client()
    except:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
        db = firestore.client()
    
    # Get all matches from Firestore
    matches_ref = db.collection('matches')
    docs = matches_ref.stream()
    
    pjp_matches = []
    all_types = set()
    
    for doc in docs:
        data = doc.to_dict()
        match_type = data.get('type', '')
        all_types.add(match_type)
        
        # Check if this is a PJP match
        if 'pjp' in match_type.lower() or 'provinciale' in match_type.lower():
            pjp_matches.append({
                'id': doc.id,
                'type': match_type,
                'organizer': data.get('organizer', ''),
                'date': data.get('date', ''),
                'location': data.get('location', ''),
                'source': data.get('source', ''),
                'calendar_type': data.get('calendar_type', ''),
                'registration_text': data.get('registration_text', '')
            })
    
    print(f"📊 Total matches in Firebase: {len(list(docs))}")
    print(f"📊 PJP matches found: {len(pjp_matches)}")
    print(f"📊 All types found: {sorted(all_types)}")
    
    if pjp_matches:
        print("\n🎯 PJP MATCHES FOUND:")
        for match in pjp_matches:
            print(f"  • Type: '{match['type']}'")
            print(f"    Organizer: {match['organizer']}")
            print(f"    Date: {match['date']}")
            print(f"    Location: {match['location']}")
            print(f"    Source: {match['source']}")
            print(f"    Calendar Type: {match['calendar_type']}")
            print(f"    Registration: {match['registration_text']}")
            print()
    else:
        print("\n❌ NO PJP MATCHES FOUND IN FIREBASE")
        print("   This means the scraper didn't upload any PJP matches")
        print("   or they're stored with a different type value")
    
    print("\n🔍 ANALYSIS:")
    print(f"   • If PJP matches exist but type != 'PJP', then scraper normalization failed")
    print(f"   • If no PJP matches exist, then scraper didn't find/upload the October 31 match")
    print(f"   • Flutter app filters for 'PJP' (case-insensitive)")
    
    return pjp_matches

if __name__ == "__main__":
    check_firebase_pjp() 