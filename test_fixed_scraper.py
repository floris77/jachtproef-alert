#!/usr/bin/env python3
"""
Test the fixed scraper data to verify field mapping is correct
"""

import csv
import re
from datetime import datetime

def test_fixed_scraper():
    """Test the fixed scraper response"""
    with open('scraper_response_FIXED.txt', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract a few sample matches to verify field mapping
    tier1_start = content.find('\\"tier1_data\\"')
    if tier1_start == -1:
        print("Could not find tier1_data")
        return
    
    # Extract first few matches to test
    tier1_section = content[tier1_start:tier1_start+5000]  # First 5000 chars
    
    # Find individual matches
    date_splits = re.split(r'(?=\\"date\\")', tier1_section)
    
    print("Testing fixed scraper field mapping:")
    print("=" * 50)
    
    for i, split in enumerate(date_splits[1:6]):  # Test first 5 matches
        date_match = re.search(r'\\"date\\":\s*\\"([^"]*)\\"', split)
        organizer_match = re.search(r'\\"organizer\\":\s*\\"([^"]*)\\"', split)
        location_match = re.search(r'\\"location\\":\s*\\"([^"]*)\\"', split)
        type_match = re.search(r'\\"type\\":\s*\\"([^"]*)\\"', split)
        
        if date_match:
            print(f"\nMatch {i+1}:")
            print(f"  Date: {date_match.group(1) if date_match else 'N/A'}")
            print(f"  Organizer: {organizer_match.group(1) if organizer_match else 'N/A'}")
            print(f"  Location: {location_match.group(1) if location_match else 'N/A'}")
            print(f"  Type: {type_match.group(1) if type_match else 'N/A'}")
            
            # Check if this looks correct now
            organizer = organizer_match.group(1) if organizer_match else ''
            type_field = type_match.group(1) if type_match else ''
            
            # The organizer should now be actual organization names, not types like "MAP"
            if organizer in ['MAP', 'KNJV', 'TAP', 'veldwedstrijd']:
                print(f"  ⚠️  WARNING: Organizer still looks like a type: {organizer}")
            else:
                print(f"  ✅ Organizer looks correct: {organizer}")
                
            # The type should now be types like "MAP", "KNJV", etc.
            if type_field in ['MAP', 'KNJV', 'TAP', 'veldwedstrijd']:
                print(f"  ✅ Type looks correct: {type_field}")
            else:
                print(f"  ⚠️  Type may need review: {type_field}")

if __name__ == "__main__":
    test_fixed_scraper() 