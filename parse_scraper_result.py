#!/usr/bin/env python3
"""
Parse the scraper result and create a CSV file
"""

import json
import csv
from datetime import datetime
import re

def parse_scraper_result():
    """Parse the scraper result file and create CSV"""
    
    # Read the result file
    with open('scraper_result.json', 'r') as f:
        content = f.read()
    
    # Extract the result JSON from the gcloud response
    # The format is: result: "{json_data}" but it's split across lines with backslashes
    
    # Find the line that starts with "result:"
    lines = content.split('\n')
    result_lines = []
    in_result = False
    
    for line in lines:
        if line.startswith('result:'):
            in_result = True
            # Remove "result: " and the opening quote
            json_part = line.replace('result: "', '')
            result_lines.append(json_part)
        elif in_result:
            result_lines.append(line)
    
    # Join all lines and clean up
    json_str = ''.join(result_lines)
    
    # Remove backslashes used for line continuation
    json_str = json_str.replace('\\\n', '').replace('\\  ', ' ')
    
    # Fix escaped quotes
    json_str = json_str.replace('\\"', '"').replace('\\\\', '\\')
    
    # Remove the trailing quote if present
    if json_str.endswith('"'):
        json_str = json_str[:-1]
    
    # Parse the JSON
    try:
        data = json.loads(json_str)
    except json.JSONDecodeError as e:
        print(f"❌ Error parsing JSON: {e}")
        print(f"First 200 chars of JSON: {json_str[:200]}")
        return
    
    print(f"✅ Successfully parsed scraper result!")
    print(f"📊 Found {data['tier1_matches']} Tier 1 matches")
    print(f"📊 Found {data['tier2_matches']} Tier 2 matches")
    print(f"📊 Total: {data['total_matches']} matches")
    
    # Create CSV file
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
    
    print(f"\n🎉 All done! You can now open the CSV file:")
    print(f"   {filename}")
    print(f"\n💡 The file contains all {data['total_matches']} matches from both tiers:")
    print(f"   - Tier 1 (Public): {len(tier1_data)} matches")
    print(f"   - Tier 2 (Protected): {len(tier2_data)} matches")

if __name__ == "__main__":
    parse_scraper_result() 