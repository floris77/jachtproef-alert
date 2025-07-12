#!/usr/bin/env python3
"""
Create a CSV file comparing Tier 1 and Tier 2 matches from JachtProef Alert scraper
"""

import json
import csv
from datetime import datetime
from difflib import SequenceMatcher

def similarity(a, b):
    """Calculate similarity between two strings"""
    return SequenceMatcher(None, a, b).ratio()

def parse_scraper_data():
    """Parse the scraper response data"""
    # The data from the gcloud function call
    data_str = '''{"success": true, "tier1_matches": 155, "tier2_matches": 155, "tier2_breakdown": {"veldwedstrijd": 94, "jachthondenproef": 60, "orweja_werktest": 1}, "total_matches": 310, "matches_uploaded": 310, "timestamp": "2025-07-06T17:49:12.549377", "tier1_data": [{"date": "2025-07-24", "organizer": "Chesapeake Bay Retriever Club Nederland", "location": "West Brabant", "registration_text": "Inschrijven", "type": "********", "source": "tier1"}, {"date": "2025-09-03", "organizer": "Continentale Staande honden Vereeniging", "location": "St. Annaland Aanvang: 8.30", "registration_text": "Inschrijven", "type": "********", "source": "tier1"}], "tier2_data": [{"date": "2025-07-24", "organizer": "Chesapeake Bay Retriever Club Nederland [email protected]", "location": "West Brabant", "remarks": "", "registration_text": "Inschrijven", "type": "CAC Apporteerwedstrijd", "source": "tier2", "calendar_type": "Veldwedstrijd"}], "has_match_data": true}'''
    
    try:
        data = json.loads(data_str)
        return data.get('tier1_data', []), data.get('tier2_data', [])
    except:
        return [], []

def create_comparison_csv():
    """Create CSV file comparing Tier 1 and Tier 2 matches"""
    tier1_matches, tier2_matches = parse_scraper_data()
    
    if not tier1_matches or not tier2_matches:
        print("No data found")
        return
    
    # Create matches with potential Tier 2 counterparts
    output_file = f"/Users/florisvanderhart/Desktop/jachtproef_tier_comparison_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    
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
        
        # Process each Tier 1 match
        for tier1_match in tier1_matches:
            best_tier2_match = None
            best_similarity = 0
            
            # Find best matching Tier 2 match
            for tier2_match in tier2_matches:
                if tier1_match['date'] == tier2_match['date']:
                    # Calculate organizer similarity
                    org_similarity = similarity(
                        tier1_match['organizer'].lower(),
                        tier2_match['organizer'].lower()
                    )
                    
                    if org_similarity > best_similarity:
                        best_similarity = org_similarity
                        best_tier2_match = tier2_match
            
            # Write row
            if best_tier2_match and best_similarity > 0.3:  # 30% threshold
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

if __name__ == "__main__":
    create_comparison_csv() 