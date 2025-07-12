#!/usr/bin/env python3
"""
Final parser to extract JSON from gcloud result
"""

import json
import csv
from datetime import datetime
import re

def extract_and_parse():
    """Extract and parse the JSON from scraper result"""
    
    with open('scraper_result.json', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract the JSON part using regex
    match = re.search(r'result: "(.+)"$', content, re.DOTALL)
    if not match:
        print("❌ Could not find result in file")
        return None
    
    json_str = match.group(1)
    
    # Clean up the JSON string
    # Remove line continuation backslashes and the following newlines
    json_str = re.sub(r'\\\\\n\s*', '', json_str)
    
    # Fix escaped quotes
    json_str = json_str.replace('\\"', '"')
    
    # Remove any remaining backslashes before spaces
    json_str = re.sub(r'\\(\s)', r'\1', json_str)
    
    # Remove control characters (like newlines) within string values
    json_str = re.sub(r'(?<!\\)\n', '', json_str)
    json_str = re.sub(r'(?<!\\)\r', '', json_str)
    json_str = re.sub(r'(?<!\\)\t', ' ', json_str)
    
    try:
        data = json.loads(json_str)
        return data
    except json.JSONDecodeError as e:
        print(f"❌ Error parsing JSON: {e}")
        print(f"Problematic area: {json_str[max(0, e.pos-50):e.pos+50]}")
        return None

def create_csv(data):
    """Create CSV from parsed data"""
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"/Users/florisvanderhart/Desktop/jachtproef_all_matches_{timestamp}.csv"
    
    print(f"📝 Creating CSV file: {filename}")
    
    with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.writer(csvfile)
        
        # Write header
        writer.writerow(['Tier', 'Date', 'Organizer', 'Location', 'Type', 'Registration_Text', 'Remarks', 'Calendar_Type', 'Source'])
        
        # Write Tier 1 matches
        tier1_data = data.get('tier1_data', [])
        for match in tier1_data:
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
        tier2_data = data.get('tier2_data', [])
        for match in tier2_data:
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
    print(f"📊 Total rows: {len(tier1_data) + len(tier2_data) + 1} (including header)")
    
    return filename

if __name__ == "__main__":
    data = extract_and_parse()
    if data:
        print(f"✅ Successfully parsed scraper result!")
        print(f"📊 Found {data['tier1_matches']} Tier 1 matches")
        print(f"📊 Found {data['tier2_matches']} Tier 2 matches")
        print(f"📊 Total: {data['total_matches']} matches")
        
        filename = create_csv(data)
        
        print(f"\n🎉 All done! You can now open the CSV file:")
        print(f"   {filename}")
        print(f"\n💡 The file contains all {data['total_matches']} matches from both tiers:")
        print(f"   - Tier 1 (Public): {len(data.get('tier1_data', []))} matches")
        print(f"   - Tier 2 (Protected): {len(data.get('tier2_data', []))} matches")
    else:
        print("❌ Failed to parse scraper result") 