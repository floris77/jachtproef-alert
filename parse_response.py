#!/usr/bin/env python3
"""
Parse the saved scraper response and create comparison CSV
"""

import json
import csv
import re
from datetime import datetime
from difflib import SequenceMatcher

def similarity(a, b):
    """Calculate similarity between two strings"""
    return SequenceMatcher(None, a, b).ratio()

def parse_response_file():
    """Parse the scraper response file"""
    with open('scraper_response.txt', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract the JSON from the response - it's between result: " and the final "
    start_marker = 'result: "'
    end_marker = '"\n'
    
    start_idx = content.find(start_marker)
    if start_idx == -1:
        print("Could not find result start marker")
        return None, None
    
    start_idx += len(start_marker)
    
    # Find the end - look for the last quote before a newline
    end_idx = content.rfind(end_marker)
    if end_idx == -1:
        print("Could not find result end marker")
        return None, None
    
    json_str = content[start_idx:end_idx]
    
    # Clean up the JSON string - handle line continuations and escaping
    json_str = json_str.replace('\\\n  ', '')  # Remove line continuations
    json_str = json_str.replace('\\"', '"')     # Unescape quotes
    
    # Handle backslashes in the middle of strings (not escape sequences)
    json_str = re.sub(r'\\(?!["\\/bfnrtu])', '', json_str)  # Remove invalid backslashes
    
    # Handle unicode escapes
    json_str = json_str.replace('\\u00a0', ' ') # Non-breaking space
    json_str = json_str.replace('\\u00e2', 'â')
    json_str = json_str.replace('\\u00fc', 'ü')
    json_str = json_str.replace('\\u00eb', 'ë')
    json_str = json_str.replace('\\u00ef', 'ï')
    json_str = json_str.replace('\\u00f6', 'ö')
    
    try:
        data = json.loads(json_str)
        tier1_matches = data.get('tier1_data', [])
        tier2_matches = data.get('tier2_data', [])
        
        print(f"Successfully parsed {len(tier1_matches)} Tier 1 matches")
        print(f"Successfully parsed {len(tier2_matches)} Tier 2 matches")
        
        return tier1_matches, tier2_matches
        
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}")
        # Save the cleaned JSON for debugging
        with open('debug_json.txt', 'w') as f:
            f.write(json_str[:2000])
        print("Saved first 2000 chars to debug_json.txt")
        return None, None

def create_comparison_csv():
    """Create CSV comparing Tier 1 and Tier 2 matches"""
    tier1_matches, tier2_matches = parse_response_file()
    
    if not tier1_matches or not tier2_matches:
        print("Failed to parse data")
        return
    
    # Create CSV
    output_file = f"/Users/florisvanderhart/Desktop/jachtproef_comparison_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    
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
                    
                    # Calculate similarity
                    org_similarity = similarity(org1, org2)
                    
                    # Also check location similarity for better matching
                    loc1 = tier1_match['location'].lower().strip()
                    loc2 = tier2_match['location'].lower().strip()
                    loc_similarity = similarity(loc1, loc2)
                    
                    # Combined similarity (weighted towards organizer)
                    combined_similarity = (org_similarity * 0.7) + (loc_similarity * 0.3)
                    
                    if combined_similarity > best_similarity:
                        best_similarity = combined_similarity
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
    print(f"Match rate: {matched_count/len(tier1_matches)*100:.1f}%")

if __name__ == "__main__":
    create_comparison_csv() 