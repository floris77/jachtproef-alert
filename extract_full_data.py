#!/usr/bin/env python3
"""
Extract full match data from the gcloud function response
"""

import json
import csv
import re
from datetime import datetime
from difflib import SequenceMatcher

def similarity(a, b):
    """Calculate similarity between two strings"""
    return SequenceMatcher(None, a, b).ratio()

def extract_json_from_large_response():
    """Extract JSON from the large gcloud response"""
    # Read the response from the terminal output (you'll need to save this to a file)
    # For now, let's create a new scraper call to get clean data
    return None

def create_comparison_csv_from_file():
    """Create CSV from saved response file"""
    # Let's run the scraper again with a simpler approach
    import subprocess
    
    print("Running scraper to get fresh data...")
    result = subprocess.run([
        'gcloud', 'functions', 'call', 'orweja-scraper', 
        '--region=europe-west1', '--data={"export_all_data": true}'
    ], capture_output=True, text=True)
    
    if result.returncode != 0:
        print("Error running scraper")
        return
    
    # Parse the response
    response_text = result.stdout
    
    # Extract the JSON from the response
    json_match = re.search(r'result: \'({.*})\'', response_text, re.DOTALL)
    if not json_match:
        print("Could not find JSON in response")
        return
    
    json_str = json_match.group(1)
    
    # Clean up the JSON string
    json_str = json_str.replace('\\"', '"')
    json_str = json_str.replace('\\u00a0', ' ')
    
    try:
        data = json.loads(json_str)
        
        tier1_matches = data.get('tier1_data', [])
        tier2_matches = data.get('tier2_data', [])
        
        print(f"Found {len(tier1_matches)} Tier 1 matches")
        print(f"Found {len(tier2_matches)} Tier 2 matches")
        
        # Create CSV
        output_file = f"/Users/florisvanderhart/Desktop/jachtproef_full_comparison_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        
        with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)
            
            # Write header
            writer.writerow([
                'Date',
                'Tier1_Organizer',
                'Tier1_Location', 
                'Tier1_Type',
                'Tier1_Registration',
                'Tier2_Organizer',
                'Tier2_Location',
                'Tier2_Type',
                'Tier2_Registration',
                'Tier2_Calendar_Type',
                'Similarity_Score',
                'Match_Status'
            ])
            
            matched_count = 0
            
            # Process each Tier 1 match
            for tier1_match in tier1_matches:
                best_tier2_match = None
                best_similarity = 0
                
                # Find best matching Tier 2 match
                for tier2_match in tier2_matches:
                    if tier1_match['date'] == tier2_match['date']:
                        # Calculate organizer similarity
                        org1 = tier1_match['organizer'].lower().strip()
                        org2 = tier2_match['organizer'].lower().strip()
                        
                        # Remove email addresses from tier2 organizer
                        org2 = re.sub(r'\[email.*?\]', '', org2).strip()
                        
                        org_similarity = similarity(org1, org2)
                        
                        if org_similarity > best_similarity:
                            best_similarity = org_similarity
                            best_tier2_match = tier2_match
                
                # Write row
                if best_tier2_match and best_similarity > 0.3:  # 30% threshold
                    matched_count += 1
                    writer.writerow([
                        tier1_match['date'],
                        tier1_match['organizer'],
                        tier1_match['location'],
                        tier1_match['type'],
                        tier1_match['registration_text'],
                        best_tier2_match['organizer'],
                        best_tier2_match['location'],
                        best_tier2_match['type'],
                        best_tier2_match['registration_text'],
                        best_tier2_match.get('calendar_type', ''),
                        f"{best_similarity:.2f}",
                        'MATCHED'
                    ])
                else:
                    writer.writerow([
                        tier1_match['date'],
                        tier1_match['organizer'],
                        tier1_match['location'],
                        tier1_match['type'],
                        tier1_match['registration_text'],
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        'NO_MATCH'
                    ])
        
        print(f"CSV created: {output_file}")
        print(f"Processed {len(tier1_matches)} Tier 1 matches and {len(tier2_matches)} Tier 2 matches")
        print(f"Successfully matched: {matched_count} matches")
        
    except Exception as e:
        print(f"Error parsing JSON: {e}")

if __name__ == "__main__":
    create_comparison_csv_from_file() 