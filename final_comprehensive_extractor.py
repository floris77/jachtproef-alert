#!/usr/bin/env python3
"""
Final comprehensive extractor that handles mixed escaping
"""

import re
import csv
from datetime import datetime

def extract_all_matches():
    """Extract all matches from both tiers"""
    
    with open('raw_json.txt', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find tier1_data section
    tier1_section = re.search(r'\\\"tier1_data\\\":\s*\[(.*?)\],\s*\\\"tier2_data\\\"', content, re.DOTALL)
    tier1_matches = []
    
    if tier1_section:
        tier1_content = tier1_section.group(1)
        # Extract individual tier1 matches
        tier1_objects = re.findall(r'\{[^}]*\\\"source\\\":\s*\\\"tier1\\\"[^}]*\}', tier1_content, re.DOTALL)
        
        for match_obj in tier1_objects:
            match_data = extract_tier1_fields(match_obj)
            if match_data:
                tier1_matches.append(match_data)
    
    # Find tier2_data section (mixed escaping)
    tier2_section = re.search(r'\],\s*\\\"tier2_data\\\":\s*\[(.*?)\]', content, re.DOTALL)
    tier2_matches = []
    
    if tier2_section:
        tier2_content = tier2_section.group(1)
        # Extract individual tier2 matches (different escaping pattern)
        tier2_objects = re.findall(r'\{[^}]*\"source\":\s*\"tier2\"[^}]*\}', tier2_content, re.DOTALL)
        
        for match_obj in tier2_objects:
            match_data = extract_tier2_fields(match_obj)
            if match_data:
                tier2_matches.append(match_data)
    
    print(f"✅ Found {len(tier1_matches)} Tier 1 matches")
    print(f"✅ Found {len(tier2_matches)} Tier 2 matches")
    
    return tier1_matches, tier2_matches

def extract_tier1_fields(match_obj):
    """Extract fields from a tier1 match object (fully escaped)"""
    
    # Extract all relevant fields with escaped quotes
    date_match = re.search(r'\\\"date\\\":\s*\\\"([^\\]*)\\\"', match_obj)
    organizer_match = re.search(r'\\\"organizer\\\":\s*\\\"([^\\]*)\\\"', match_obj)
    location_match = re.search(r'\\\"location\\\":\s*\\\"([^\\]*)\\\"', match_obj)
    registration_match = re.search(r'\\\"registration_text\\\":\s*\\\"([^\\]*)\\\"', match_obj)
    type_match = re.search(r'\\\"type\\\":\s*\\\"([^\\]*)\\\"', match_obj)
    
    if all([date_match, organizer_match, location_match, registration_match, type_match]):
        return {
            'date': date_match.group(1),
            'organizer': organizer_match.group(1),
            'location': location_match.group(1),
            'registration_text': registration_match.group(1),
            'type': type_match.group(1),
            'remarks': '',
            'calendar_type': ''
        }
    
    return None

def extract_tier2_fields(match_obj):
    """Extract fields from a tier2 match object (mixed escaping)"""
    
    # Extract all relevant fields with mixed escaping
    date_match = re.search(r'\"date\":\s*\"([^\"]*)\"', match_obj)
    organizer_match = re.search(r'\"organizer\":\s*\"([^\"]*)\"', match_obj)
    location_match = re.search(r'\"location\":\s*\"([^\"]*)\"', match_obj)
    registration_match = re.search(r'\"registration_text\":\s*\"([^\"]*)\"', match_obj)
    type_match = re.search(r'\"type\":\s*\"([^\"]*)\"', match_obj)
    
    # Optional fields
    remarks_match = re.search(r'\"remarks\":\s*\"([^\"]*)\"', match_obj)
    calendar_type_match = re.search(r'\"calendar_type\":\s*\"([^\"]*)\"', match_obj)
    
    if all([date_match, organizer_match, location_match, registration_match, type_match]):
        return {
            'date': date_match.group(1),
            'organizer': organizer_match.group(1),
            'location': location_match.group(1),
            'registration_text': registration_match.group(1),
            'type': type_match.group(1),
            'remarks': remarks_match.group(1) if remarks_match else '',
            'calendar_type': calendar_type_match.group(1) if calendar_type_match else ''
        }
    
    return None

def create_final_csv(tier1_matches, tier2_matches):
    """Create CSV from all extracted matches"""
    
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
                match['date'],
                match['organizer'],
                match['location'],
                match['type'],
                match['registration_text'],
                match['remarks'],
                'Public',
                'ORWEJA Public Calendar'
            ])
        
        # Write Tier 2 matches
        for match in tier2_matches:
            writer.writerow([
                'Tier 2',
                match['date'],
                match['organizer'],
                match['location'],
                match['type'],
                match['registration_text'],
                match['remarks'],
                'Protected',
                f"ORWEJA {match['calendar_type']} Calendar"
            ])
    
    print(f"✅ CSV file created successfully!")
    print(f"📊 File location: {filename}")
    print(f"📊 Total rows: {len(tier1_matches) + len(tier2_matches) + 1} (including header)")
    
    return filename

if __name__ == "__main__":
    tier1_matches, tier2_matches = extract_all_matches()
    
    if tier1_matches or tier2_matches:
        filename = create_final_csv(tier1_matches, tier2_matches)
        
        print(f"\n🎉 All done! You can now open the CSV file:")
        print(f"   {filename}")
        print(f"\n💡 The file contains all {len(tier1_matches) + len(tier2_matches)} matches from both tiers:")
        print(f"   - Tier 1 (Public): {len(tier1_matches)} matches")
        print(f"   - Tier 2 (Protected): {len(tier2_matches)} matches")
        
        # Show some sample data
        if tier1_matches:
            print(f"\n📋 Sample Tier 1 match:")
            print(f"   Date: {tier1_matches[0]['date']}")
            print(f"   Organizer: {tier1_matches[0]['organizer']}")
            print(f"   Type: {tier1_matches[0]['type']}")
        
        if tier2_matches:
            print(f"\n📋 Sample Tier 2 match:")
            print(f"   Date: {tier2_matches[0]['date']}")
            print(f"   Organizer: {tier2_matches[0]['organizer']}")
            print(f"   Type: {tier2_matches[0]['type']}")
    else:
        print("❌ No matches found") 