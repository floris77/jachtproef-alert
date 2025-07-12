#!/usr/bin/env python3
"""
Flexible extractor that handles varied field order and line breaks
"""

import re
import csv
from datetime import datetime

def extract_matches_flexible():
    """Extract matches using a more flexible approach"""
    
    with open('raw_json.txt', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all match objects (between { and })
    match_pattern = r'\{[^}]*\\\"source\\\":\s*\\\"(tier[12])\\\"\s*[^}]*\}'
    all_matches = re.findall(match_pattern, content, re.DOTALL)
    
    print(f"Found {len(all_matches)} total matches")
    
    # Now extract individual matches more carefully
    tier1_matches = []
    tier2_matches = []
    
    # Split content into individual match objects
    match_objects = re.findall(r'\{[^}]*\\\"source\\\":\s*\\\"tier[12]\\\"\s*[^}]*\}', content, re.DOTALL)
    
    for match_obj in match_objects:
        # Extract fields from each match object
        date_match = re.search(r'\\\"date\\\":\s*\\\"([^\\]*)\\\"', match_obj)
        organizer_match = re.search(r'\\\"organizer\\\":\s*\\\"([^\\]*)\\\"', match_obj)
        location_match = re.search(r'\\\"location\\\":\s*\\\"([^\\]*)\\\"', match_obj)
        registration_match = re.search(r'\\\"registration_text\\\":\s*\\\"([^\\]*)\\\"', match_obj)
        type_match = re.search(r'\\\"type\\\":\s*\\\"([^\\]*)\\\"', match_obj)
        source_match = re.search(r'\\\"source\\\":\s*\\\"(tier[12])\\\"', match_obj)
        
        if all([date_match, organizer_match, location_match, registration_match, type_match, source_match]):
            match_data = (
                date_match.group(1),
                organizer_match.group(1),
                location_match.group(1),
                registration_match.group(1),
                type_match.group(1)
            )
            
            if source_match.group(1) == 'tier1':
                tier1_matches.append(match_data)
            else:
                tier2_matches.append(match_data)
    
    print(f"✅ Found {len(tier1_matches)} Tier 1 matches")
    print(f"✅ Found {len(tier2_matches)} Tier 2 matches")
    
    return tier1_matches, tier2_matches

def create_csv_flexible(tier1_matches, tier2_matches):
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
    tier1_matches, tier2_matches = extract_matches_flexible()
    
    if tier1_matches or tier2_matches:
        filename = create_csv_flexible(tier1_matches, tier2_matches)
        
        print(f"\n🎉 All done! You can now open the CSV file:")
        print(f"   {filename}")
        print(f"\n💡 The file contains all {len(tier1_matches) + len(tier2_matches)} matches from both tiers:")
        print(f"   - Tier 1 (Public): {len(tier1_matches)} matches")
        print(f"   - Tier 2 (Protected): {len(tier2_matches)} matches")
    else:
        print("❌ No matches found") 