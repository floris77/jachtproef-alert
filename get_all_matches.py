#!/usr/bin/env python3
"""
Script to fetch all matches from the ORWEJA scraper and create a CSV file
"""

import requests
import json
import csv
from datetime import datetime
import os

def call_scraper():
    """Call the ORWEJA scraper cloud function"""
    url = "https://europe-west1-jachtproefalert.cloudfunctions.net/orweja-scraper"
    
    payload = {
        "export_all_data": True,
        "skip_matching": True
    }
    
    print("🚀 Calling ORWEJA scraper...")
    response = requests.post(url, json=payload, timeout=300)
    
    if response.status_code == 200:
        return response.json()
    else:
        print(f"❌ Error calling scraper: {response.status_code}")
        print(response.text)
        return None

def create_csv_from_match_data(tier1_matches, tier2_matches):
    """Create CSV from match data"""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"/Users/florisvanderhart/Desktop/jachtproef_all_matches_{timestamp}.csv"
    
    print(f"📝 Creating CSV file: {filename}")
    
    with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.writer(csvfile)
        
        # Write header
        writer.writerow(['Tier', 'Date', 'Organizer', 'Location', 'Type', 'Registration_Text', 'Remarks', 'Calendar_Type', 'Source'])
        
        # Write Tier 1 matches
        for match in tier1_matches:
            writer.writerow([
                'Tier 1',
                match.get('date', ''),
                match.get('organizer', ''),
                match.get('location', ''),
                match.get('type', ''),
                match.get('registration_text', ''),
                match.get('remarks', ''),
                'Public',
                'ORWEJA Public Calendar'
            ])
        
        # Write Tier 2 matches
        for match in tier2_matches:
            writer.writerow([
                'Tier 2',
                match.get('date', ''),
                match.get('organizer', ''),
                match.get('location', ''),
                match.get('type', ''),
                match.get('registration_text', ''),
                match.get('remarks', ''),
                'Protected',
                f"ORWEJA {match.get('type', 'Unknown')} Calendar"
            ])
    
    print(f"✅ CSV file created successfully!")
    print(f"📊 File location: {filename}")
    print(f"📊 Total rows: {len(tier1_matches) + len(tier2_matches) + 1} (including header)")
    
    return filename

def create_csv_from_scraper_data():
    """Create CSV from scraper data"""
    # Call the scraper
    result = call_scraper()
    
    if not result:
        print("❌ Failed to get data from scraper")
        return
    
    print(f"✅ Scraper completed successfully!")
    print(f"📊 Found {result['tier1_matches']} Tier 1 matches")
    print(f"📊 Found {result['tier2_matches']} Tier 2 matches")
    print(f"📊 Total: {result['total_matches']} matches")
    
    # Check if we have match data
    if result.get('has_match_data'):
        print("\n🔄 Creating CSV file from match data...")
        
        tier1_data = result.get('tier1_data', [])
        tier2_data = result.get('tier2_data', [])
        
        filename = create_csv_from_match_data(tier1_data, tier2_data)
        
        print(f"\n🎉 All done! You can now open the CSV file:")
        print(f"   {filename}")
        print(f"\n💡 The file contains all {result['total_matches']} matches from both tiers:")
        print(f"   - Tier 1 (Public): {len(tier1_data)} matches")
        print(f"   - Tier 2 (Protected): {len(tier2_data)} matches")
        
    else:
        print("❌ No match data returned from scraper")

if __name__ == "__main__":
    create_csv_from_scraper_data() 