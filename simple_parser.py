#!/usr/bin/env python3
"""
Simple parser to extract JSON from gcloud result
"""

import json
import csv
from datetime import datetime
import codecs

def extract_and_parse():
    """Extract and parse the JSON from scraper result"""
    
    with open('scraper_result.json', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find the start of the JSON
    start_marker = 'result: "'
    start_pos = content.find(start_marker)
    if start_pos == -1:
        print("❌ Could not find result marker")
        return None
    
    # Start after the marker
    start_pos += len(start_marker)
    
    # Find the end - look for the last quote on a line by itself or with minimal content
    # The JSON ends when we see a quote followed by newline or end of content
    json_part = content[start_pos:]
    
    # Remove the trailing quote and any whitespace
    if json_part.endswith('"\n'):
        json_part = json_part[:-2]
    elif json_part.endswith('"'):
        json_part = json_part[:-1]
    
    # Clean up the JSON - remove line continuation backslashes
    json_part = json_part.replace('\\\n', '').replace('\\  ', ' ')
    
    # Decode the JSON string (it's double-encoded)
    try:
        # First, decode the escaped string
        decoded = codecs.decode(json_part, 'unicode_escape')
        # Then parse the JSON
        data = json.loads(decoded)
        return data
    except Exception as e:
        print(f"❌ Error decoding JSON: {e}")
        # Try direct parsing
        try:
            data = json.loads(json_part)
            return data
        except Exception as e2:
            print(f"❌ Error parsing JSON directly: {e2}")
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