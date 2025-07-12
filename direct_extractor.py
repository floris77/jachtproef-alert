#!/usr/bin/env python3
"""
Direct extractor that uses regex to extract match data
"""

import re
import csv
from datetime import datetime

def extract_matches_direct():
    """Extract matches directly using regex patterns"""
    
    with open('raw_json.txt', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all tier1 matches (with escaped quotes)
    tier1_pattern = r'\{\\\"date\\\":\s*\\\"([^\\]*)\\\",.*?\\\"organizer\\\":\s*\\\"([^\\]*)\\\",.*?\\\"location\\\":\s*\\\"([^\\]*)\\\",.*?\\\"registration_text\\\":\s*\\\"([^\\]*)\\\",.*?\\\"type\\\":\s*\\\"([^\\]*)\\\",.*?\\\"source\\\":\s*\\\"tier1\\\"'
    tier1_matches = re.findall(tier1_pattern, content, re.DOTALL)
    
    # Find all tier2 matches (with escaped quotes)
    tier2_pattern = r'\{\\\"date\\\":\s*\\\"([^\\]*)\\\",.*?\\\"organizer\\\":\s*\\\"([^\\]*)\\\",.*?\\\"location\\\":\s*\\\"([^\\]*)\\\",.*?\\\"registration_text\\\":\s*\\\"([^\\]*)\\\",.*?\\\"type\\\":\s*\\\"([^\\]*)\\\",.*?\\\"source\\\":\s*\\\"tier2\\\"'
    tier2_matches = re.findall(tier2_pattern, content, re.DOTALL)
    
    print(f"✅ Found {len(tier1_matches)} Tier 1 matches")
    print(f"✅ Found {len(tier2_matches)} Tier 2 matches")
    
    return tier1_matches, tier2_matches

def create_csv_direct(tier1_matches, tier2_matches):
    """Create CSV from extracted matches"""
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"/Users/florisvanderhart/Desktop/jachtproef_all_matches_{timestamp}.csv"
    
    print(f"📝 Creating CSV file: {filename}")
    
    with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.writer(csvfile)
        
        # Write header
        writer.writerow(['Tier', 'Date', 'Organizer', 'Location', 'Type', 'Registration_Text', 'Remarks', 'Calendar_Type', 'Source'])
        
        # Write Tier 1 matches
        for match in tier1_matches:
            date, organizer, location, registration_text, match_type = match
            writer.writerow([
                'Tier 1',
                date,
                organizer,
                location,
                match_type,
                registration_text,
                '',  # remarks
                'Public',
                'ORWEJA Public Calendar'
            ])
        
        # Write Tier 2 matches
        for match in tier2_matches:
            date, organizer, location, registration_text, match_type = match
            writer.writerow([
                'Tier 2',
                date,
                organizer,
                location,
                match_type,
                registration_text,
                '',  # remarks
                'Protected',
                f"ORWEJA {match_type} Calendar"
            ])
    
    print(f"✅ CSV file created successfully!")
    print(f"📊 File location: {filename}")
    print(f"📊 Total rows: {len(tier1_matches) + len(tier2_matches) + 1} (including header)")
    
    return filename

if __name__ == "__main__":
    tier1_matches, tier2_matches = extract_matches_direct()
    
    if tier1_matches or tier2_matches:
        filename = create_csv_direct(tier1_matches, tier2_matches)
        
        print(f"\n🎉 All done! You can now open the CSV file:")
        print(f"   {filename}")
        print(f"\n💡 The file contains all {len(tier1_matches) + len(tier2_matches)} matches from both tiers:")
        print(f"   - Tier 1 (Public): {len(tier1_matches)} matches")
        print(f"   - Tier 2 (Protected): {len(tier2_matches)} matches")
    else:
        print("❌ No matches found") 