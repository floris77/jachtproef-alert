#!/usr/bin/env python3
"""
Simple extraction of match data from response file
"""

import csv
import re
from datetime import datetime
from difflib import SequenceMatcher

def similarity(a, b):
    """Calculate similarity between two strings"""
    return SequenceMatcher(None, a, b).ratio()

def extract_matches_from_file():
    """Extract matches using regex patterns"""
    with open('scraper_response.txt', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract Tier 1 matches - handle escaped quotes
    tier1_pattern = r'\\"tier1_data\\": \[(.*?)\], \\"tier2_data\\"'
    tier1_match = re.search(tier1_pattern, content, re.DOTALL)
    
    if not tier1_match:
        print("Could not find tier1_data")
        return [], []
    
    tier1_content = tier1_match.group(1)
    
    # Extract Tier 2 matches  
    tier2_pattern = r'\\"tier2_data\\": \[(.*?)\], \\"has_match_data\\"'
    tier2_match = re.search(tier2_pattern, content, re.DOTALL)
    
    if not tier2_match:
        print("Could not find tier2_data")
        return [], []
    
    tier2_content = tier2_match.group(1)
    
    # Parse individual matches using simpler patterns (handle escaped quotes)
    tier1_matches = []
    tier2_matches = []
    
    # Extract tier1 matches - handle escaped format
    match_pattern = r'\{\\"date\\": \\"([^"]+)\\", \\"organizer\\": \\"([^"]+)\\", \\"location\\": \\"([^"]*?)\\", \\"registration_text\\": \\"([^"]*?)\\", \\"type\\": \\"([^"]+)\\", \\"source\\": \\"([^"]+)\\"\}'
    
    for match in re.finditer(match_pattern, tier1_content):
        tier1_matches.append({
            'date': match.group(1),
            'organizer': match.group(2),
            'location': match.group(3),
            'registration_text': match.group(4),
            'type': match.group(5),
            'source': match.group(6)
        })
    
    # Extract tier2 matches (with additional fields) - handle escaped format
    tier2_pattern = r'\{\\"date\\": \\"([^"]+)\\", \\"organizer\\": \\"([^"]*?)\\", \\"location\\": \\"([^"]*?)\\", \\"remarks\\": \\"([^"]*?)\\", \\"registration_text\\": \\"([^"]*?)\\", \\"type\\": \\"([^"]+)\\", \\"source\\": \\"([^"]+)\\", \\"calendar_type\\": \\"([^"]+)\\"\}'
    
    for match in re.finditer(tier2_pattern, tier2_content):
        tier2_matches.append({
            'date': match.group(1),
            'organizer': match.group(2),
            'location': match.group(3),
            'remarks': match.group(4),
            'registration_text': match.group(5),
            'type': match.group(6),
            'source': match.group(7),
            'calendar_type': match.group(8)
        })
    
    print(f"Extracted {len(tier1_matches)} Tier 1 matches")
    print(f"Extracted {len(tier2_matches)} Tier 2 matches")
    
    return tier1_matches, tier2_matches

def create_comparison_csv():
    """Create CSV comparing Tier 1 and Tier 2 matches"""
    tier1_matches, tier2_matches = extract_matches_from_file()
    
    if not tier1_matches or not tier2_matches:
        print("Failed to extract data")
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