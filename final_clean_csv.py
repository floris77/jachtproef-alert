#!/usr/bin/env python3
"""
Create a final clean CSV with better data cleaning
"""

import csv
import re
from datetime import datetime

def clean_field(text):
    """Clean up field data by removing line breaks and extra spaces"""
    if not text:
        return ""
    
    # Remove line breaks and extra whitespace
    text = re.sub(r'\\n|\\r|\n|\r', ' ', text)
    text = re.sub(r'\s+', ' ', text)
    text = text.strip()
    
    # Remove escaped characters
    text = text.replace('\\"', '"')
    text = text.replace('\\\\', '\\')
    
    # Remove "i.s.m:" patterns (collaboration indicators)
    text = re.sub(r'i\.s\.m:\s*', '', text)
    
    return text

def extract_and_clean_matches():
    """Extract all matches with better cleaning"""
    with open('scraper_response.txt', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find tier1_data and tier2_data sections
    tier1_start = content.find('\\"tier1_data\\"')
    tier2_start = content.find('\\"tier2_data\\"')
    
    if tier1_start == -1 or tier2_start == -1:
        print("Could not find tier1_data or tier2_data sections")
        return [], []
    
    # Extract sections
    tier1_section = content[tier1_start:tier2_start]
    tier2_end = content.find('\\"has_match_data\\"', tier2_start)
    if tier2_end == -1:
        tier2_end = len(content)
    tier2_section = content[tier2_start:tier2_end]
    
    print(f"Tier 1 section length: {len(tier1_section)}")
    print(f"Tier 2 section length: {len(tier2_section)}")
    
    # Parse matches
    tier1_matches = parse_tier1_clean(tier1_section)
    tier2_matches = parse_tier2_clean(tier2_section)
    
    return tier1_matches, tier2_matches

def parse_tier1_clean(section):
    """Parse Tier 1 matches with better cleaning"""
    matches = []
    
    date_splits = re.split(r'(?=\\"date\\")', section)
    print(f"Tier 1 - Date splits: {len(date_splits)}")
    
    for i, split in enumerate(date_splits[1:]):
        # Extract raw data
        date_match = re.search(r'\\"date\\":\s*\\\s*\\"([^"]*)\\"', split, re.DOTALL)
        if not date_match:
            date_match = re.search(r'\\"date\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        
        # For Tier 1: organizer=TYPE, location=ORGANIZER, registration=LOCATION
        raw_type = re.search(r'\\"organizer\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        raw_organizer = re.search(r'\\"location\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        raw_location = re.search(r'\\"registration_text\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        
        if date_match:
            # Clean and extract data
            date_str = clean_field(date_match.group(1))
            type_str = clean_field(raw_type.group(1) if raw_type else '')
            organizer_str = clean_field(raw_organizer.group(1) if raw_organizer else '')
            location_str = clean_field(raw_location.group(1) if raw_location else '')
            
            # Skip if type is just asterisks
            if type_str == '********':
                type_str = ''
            
            match_data = {
                'date': date_str,
                'organizer': organizer_str,
                'location': location_str,
                'type': type_str,
                'registration': '',
                'calendar_type': 'Tier1'
            }
            matches.append(match_data)
    
    print(f"Tier 1 - Successfully parsed {len(matches)} matches")
    return matches

def parse_tier2_clean(section):
    """Parse Tier 2 matches with better cleaning"""
    matches = []
    
    date_splits = re.split(r'(?=\\"date\\")', section)
    print(f"Tier 2 - Date splits: {len(date_splits)}")
    
    for i, split in enumerate(date_splits[1:]):
        # Extract data
        date_match = re.search(r'\\"date\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        organizer_match = re.search(r'\\"organizer\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        location_match = re.search(r'\\"location\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        type_match = re.search(r'\\"type\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        registration_match = re.search(r'\\"registration_text\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        calendar_type_match = re.search(r'\\"calendar_type\\":\s*\\"([^"]*)\\"', split, re.DOTALL)
        
        if date_match:
            match_data = {
                'date': clean_field(date_match.group(1)),
                'organizer': clean_field(organizer_match.group(1) if organizer_match else ''),
                'location': clean_field(location_match.group(1) if location_match else ''),
                'type': clean_field(type_match.group(1) if type_match else ''),
                'registration': clean_field(registration_match.group(1) if registration_match else ''),
                'calendar_type': clean_field(calendar_type_match.group(1) if calendar_type_match else 'Tier2')
            }
            matches.append(match_data)
    
    print(f"Tier 2 - Successfully parsed {len(matches)} matches")
    return matches

def create_final_csv():
    """Create final clean CSV"""
    tier1_matches, tier2_matches = extract_and_clean_matches()
    
    print(f"Tier 1 matches: {len(tier1_matches)}")
    print(f"Tier 2 matches: {len(tier2_matches)}")
    
    # Create CSV file
    csv_filename = f"/Users/florisvanderhart/Desktop/FINAL_CLEAN_matches_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    
    with open(csv_filename, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['Source', 'Date', 'Organizer', 'Location', 'Type', 'Registration', 'Calendar_Type']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        writer.writeheader()
        
        # Write all matches
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
    
    print(f"FINAL CLEAN CSV file created: {csv_filename}")
    print(f"Total matches exported: {len(tier1_matches) + len(tier2_matches)}")
    
    # Show sample of cleaned data
    print("\nSample Tier 1 matches:")
    for i, match in enumerate(tier1_matches[:5]):
        print(f"{i+1}. {match['date']} | {match['organizer']} | {match['type']}")
    
    print("\nSample Tier 2 matches:")
    for i, match in enumerate(tier2_matches[:5]):
        print(f"{i+1}. {match['date']} | {match['organizer']} | {match['type']}")

if __name__ == "__main__":
    create_final_csv() 