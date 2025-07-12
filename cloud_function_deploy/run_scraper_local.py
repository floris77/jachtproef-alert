#!/usr/bin/env python3
"""
Local runner for the JachtProef Alert scraper
"""

import os
import sys
from datetime import datetime

# Set up environment
os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = '/Users/florisvanderhart/Documents/jachtproef_alert/scraper-service-account.json'

# Import the main scraper functions
from main import (
    initialize_firebase,
    scrape_tier2_protected_calendars,
    upload_to_firebase,
    mark_past_matches_as_closed
)

def run_scraper():
    """Run the scraper locally"""
    print("🚀 Starting JachtProef Alert Scraper (Local)...")
    print("=" * 50)
    
    # Initialize Firebase
    firebase_available = initialize_firebase()
    
    if not firebase_available:
        print("❌ Firebase initialization failed - cannot proceed")
        return
    
    # Step 1: Scrape Tier 2 (protected calendars with hunt type data)
    print("📅 Scraping ORWEJA protected calendars...")
    tier2_matches = scrape_tier2_protected_calendars()
    
    if not tier2_matches:
        print("❌ No matches found in Tier 2")
        return
    
    print(f"✅ Found {len(tier2_matches)} matches from Tier 2")
    
    # Step 2: Upload to Firebase 
    print("💾 Uploading matches to Firebase...")
    upload_to_firebase(tier2_matches)
    
    # Step 3: Mark past matches as closed
    print("🔒 Marking past matches as closed...")
    mark_past_matches_as_closed()
    
    print("🎉 Scraper completed successfully!")
    
    # Print match type summary
    type_counts = {}
    for match in tier2_matches:
        match_type = match.get('type', 'Unknown')
        type_counts[match_type] = type_counts.get(match_type, 0) + 1
    
    print(f"\n📊 Match Types Found:")
    for match_type, count in sorted(type_counts.items()):
        print(f"  {match_type}: {count}")

if __name__ == "__main__":
    run_scraper() 