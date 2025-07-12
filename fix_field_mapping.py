#!/usr/bin/env python3
"""
Fix the field mapping in the extracted match data
"""

import csv
import re
from datetime import datetime

def extract_all_matches():
    """Extract all matches from the response file with corrected field mapping"""
    with open('scraper_response.txt', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find tier1_data and tier2_data sections
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
    
    # Parse matches from each section with corrected mapping
    tier1_matches = parse_tier1_matches(tier1_section)
    tier2_matches = parse_tier2_matches(tier2_section)
    
    return tier1_matches, tier2_matches

def parse_tier1_matches(section):
    """Parse Tier 1 matches with corrected field mapping"""
    matches = []
    
    # Split by date patterns
    date_splits = re.split(r'(?=\\"date\\")', section)
    print(f"Tier 1 - Date splits: {len(date_splits)}")
    
    for i, split in enumerate(date_splits[1:]):  # Skip first empty split
        # Extract data from this split
        date_match = re.search(r'\\"date\\":\s*\\\s*\\"([^"]*)\\"', split, re.DOTALL)
        if not date_match:
            date_match = re.search(r'\\"date\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        
        # For Tier 1, the fields are misaligned:
        # - "organizer" field actually contains the TYPE
        # - "location" field actually contains the ORGANIZER  
        # - "registration_text" field actually contains the LOCATION
        # - "type" field contains asterisks (placeholder)
        
        raw_organizer = re.search(r'\\"organizer\\":\s*\\"([^"]*)\\"', split, re.DOTALL)  # This is actually TYPE
        raw_location = re.search(r'\\"location\\":\s*\\"([^"]*)\\"', split, re.DOTALL)    # This is actually ORGANIZER
        raw_registration = re.search(r'\\"registration_text\\":\s*\\"([^"]*)\\"', split, re.DOTALL)  # This is actually LOCATION
        raw_type = re.search(r'\\"type\\":\s*\\"([^"]*)\\"', split, re.DOTALL)  # This is placeholder asterisks
        
        if date_match:
            match_data = {
                'date': date_match.group(1) if date_match else '',
                'organizer': raw_location.group(1) if raw_location else '',  # CORRECTED: location -> organizer
                'location': raw_registration.group(1) if raw_registration else '',  # CORRECTED: registration -> location
                'type': raw_organizer.group(1) if raw_organizer else '',  # CORRECTED: organizer -> type
                'registration': '',  # Empty for Tier 1
                'calendar_type': 'Tier1'
            }
            matches.append(match_data)
    
    print(f"Tier 1 - Successfully parsed {len(matches)} matches")
    return matches

def parse_tier2_matches(section):
    """Parse Tier 2 matches (these seem to have correct mapping already)"""
    matches = []
    
    # Split by date patterns
    date_splits = re.split(r'(?=\\"date\\")', section)
    print(f"Tier 2 - Date splits: {len(date_splits)}")
    
    for i, split in enumerate(date_splits[1:]):  # Skip first empty split
        # Extract data from this split
        date_match = re.search(r'\\"date\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        organizer_match = re.search(r'\\"organizer\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        location_match = re.search(r'\\"location\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        type_match = re.search(r'\\"type\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        registration_match = re.search(r'\\"registration_text\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        calendar_type_match = re.search(r'\\"calendar_type\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        
        if date_match:
            match_data = {
                'date': date_match.group(1) if date_match else '',
                'organizer': organizer_match.group(1) if organizer_match else '',
                'location': location_match.group(1) if location_match else '',
                'type': type_match.group(1) if type_match else '',
                'registration': registration_match.group(1) if registration_match else '',
                'calendar_type': calendar_type_match.group(1) if calendar_type_match else 'Tier2'
            }
            matches.append(match_data)
    
    print(f"Tier 2 - Successfully parsed {len(matches)} matches")
    return matches

def create_fixed_csv():
    """Create CSV with corrected field mapping"""
    tier1_matches, tier2_matches = extract_all_matches()
    
    print(f"Tier 1 matches: {len(tier1_matches)}")
    print(f"Tier 2 matches: {len(tier2_matches)}")
    
    # Create CSV file
    csv_filename = f"/Users/florisvanderhart/Desktop/FIXED_all_matches_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    
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
    
    print(f"FIXED CSV file created: {csv_filename}")
    print(f"Total matches exported: {len(tier1_matches) + len(tier2_matches)}")

if __name__ == "__main__":
    create_fixed_csv() 