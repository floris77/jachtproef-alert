#!/usr/bin/env python3
"""
Extract ALL matches from both tiers - no matching, just data dump
"""

import csv
import re
from datetime import datetime

def extract_all_matches():
    """Extract all matches from the response file"""
    with open('scraper_response.txt', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # The JSON is escaped with backslashes - let's find the actual data sections
    # Look for tier1_data and tier2_data sections
    
    # Find tier1_data section
    tier1_start = content.find('\\"tier1_data\\"')
    tier2_start = content.find('\\"tier2_data\\"')
    
    if tier1_start == -1 or tier2_start == -1:
        print("Could not find tier1_data or tier2_data sections")
        return [], []
    
    # Extract tier1 section (from tier1_data to tier2_data)
    tier1_section = content[tier1_start:tier2_start]
    
    # Extract tier2 section (from tier2_data to end of data)
    tier2_end = content.find('\\"has_match_data\\"', tier2_start)
    if tier2_end == -1:
        tier2_end = len(content)
    tier2_section = content[tier2_start:tier2_end]
    
    print(f"Tier 1 section length: {len(tier1_section)}")
    print(f"Tier 2 section length: {len(tier2_section)}")
    
    # Parse matches from each section
    tier1_matches = parse_matches_from_section(tier1_section, "Tier 1")
    tier2_matches = parse_matches_from_section(tier2_section, "Tier 2")
    
    return tier1_matches, tier2_matches

def parse_matches_from_section(section, tier_name):
    """Parse individual matches from a section"""
    matches = []
    
    # Split by date patterns - this seems to work best
    date_splits = re.split(r'(?=\\"date\\")', section)
    print(f"{tier_name} - Date splits: {len(date_splits)}")
    
    # Process each split (skip the first one as it's before the first date)
    for i, split in enumerate(date_splits[1:]):  # Skip first empty split
        # Extract data from this split
        date_match = re.search(r'\\"date\\":\s*\\\s*\\"([^"]*)\\"', split, re.DOTALL)
        if not date_match:
            # Try the normal pattern without the backslash-space
            date_match = re.search(r'\\"date\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        
        organizer_match = re.search(r'\\"organizer\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        location_match = re.search(r'\\"location\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        type_match = re.search(r'\\"type\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        registration_match = re.search(r'\\"registration_text\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        calendar_type_match = re.search(r'\\"calendar_type\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        
        # Be more lenient - only require date
        if date_match:
            match_data = {
                'date': date_match.group(1) if date_match else '',
                'organizer': organizer_match.group(1) if organizer_match else '',
                'location': location_match.group(1) if location_match else '',
                'type': type_match.group(1) if type_match else '',
                'registration': registration_match.group(1) if registration_match else '',
                'calendar_type': calendar_type_match.group(1) if calendar_type_match else ''
            }
            matches.append(match_data)
        else:
            # Debug: show splits that don't have dates
            if i < 5:  # Only show first 5 for debugging
                print(f"No date found in split {i}: {split[:100]}...")
    
    print(f"{tier_name} - Successfully parsed {len(matches)} matches")
    return matches

def create_complete_csv():
    """Create CSV with all matches from both tiers"""
    tier1_matches, tier2_matches = extract_all_matches()
    
    print(f"Tier 1 matches: {len(tier1_matches)}")
    print(f"Tier 2 matches: {len(tier2_matches)}")
    
    # Create CSV file
    csv_filename = f"/Users/florisvanderhart/Desktop/all_matches_dump_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    
    with open(csv_filename, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['Source', 'Date', 'Organizer', 'Location', 'Type', 'Registration', 'Calendar_Type']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        writer.writeheader()
        
        # Write all Tier 1 matches
        for match in tier1_matches:
            writer.writerow({
                'Source': 'Tier 1',
                'Date': match['date'],
                'Organizer': match['organizer'],
                'Location': match['location'],
                'Type': match['type'],
                'Registration': match['registration'],
                'Calendar_Type': match['calendar_type']
            })
        
        # Write all Tier 2 matches
        for match in tier2_matches:
            writer.writerow({
                'Source': 'Tier 2',
                'Date': match['date'],
                'Organizer': match['organizer'],
                'Location': match['location'],
                'Type': match['type'],
                'Registration': match['registration'],
                'Calendar_Type': match['calendar_type']
            })
    
    print(f"CSV file created: {csv_filename}")
    print(f"Total matches exported: {len(tier1_matches) + len(tier2_matches)}")

if __name__ == "__main__":
    create_complete_csv() 