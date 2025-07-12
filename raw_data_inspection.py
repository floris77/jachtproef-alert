#!/usr/bin/env python3
"""
Raw data inspection to verify field mappings and data structure
"""

import re
import json

def inspect_raw_data():
    """Inspect the raw scraper response to understand the actual data structure"""
    
    with open('scraper_response_FIXED.txt', 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("🔍 RAW DATA STRUCTURE INSPECTION")
    print("=" * 80)
    
    # Find tier1_data and tier2_data sections
    tier1_start = content.find('\\"tier1_data\\"')
    tier2_start = content.find('\\"tier2_data\\"')
    
    if tier1_start == -1 or tier2_start == -1:
        print("❌ Could not find tier1_data or tier2_data sections")
        return
    
    # Extract first few entries from each tier to inspect structure
    tier1_section = content[tier1_start:tier2_start]
    tier2_end = content.find('\\"has_match_data\\"', tier2_start)
    if tier2_end == -1:
        tier2_end = len(content)
    tier2_section = content[tier2_start:tier2_end]
    
    print("\n📊 TIER 1 DATA STRUCTURE:")
    print("=" * 50)
    
    # Find first 3 matches in Tier 1
    tier1_matches = re.findall(r'\\"date\\":\s*\\"([^"]*)\\"[^}]*?\\"organizer\\":\s*\\"([^"]*)\\"[^}]*?\\"location\\":\s*\\"([^"]*)\\"[^}]*?\\"type\\":\s*\\"([^"]*)\\"', tier1_section)
    
    for i, match in enumerate(tier1_matches[:5]):
        date, organizer, location, match_type = match
        print(f"\nTIER 1 MATCH {i+1}:")
        print(f"  Date: '{date}'")
        print(f"  Organizer: '{organizer}'")
        print(f"  Location: '{location}'")
        print(f"  Type: '{match_type}'")
        
        # Check for field mapping issues
        if not organizer.strip() and location.strip():
            print("  ⚠️  POTENTIAL FIELD MAPPING ISSUE: Empty organizer but location has data")
        
        if re.search(r'(MAP|KNJV|veldwedstrijd|TAP)', organizer):
            print("  ⚠️  POTENTIAL FIELD MAPPING ISSUE: Match type found in organizer field")
        
        if re.search(r'(Stichting|Vereniging|Club)', match_type):
            print("  ⚠️  POTENTIAL FIELD MAPPING ISSUE: Organization name found in type field")
    
    print("\n📊 TIER 2 DATA STRUCTURE:")
    print("=" * 50)
    
    # Find first 3 matches in Tier 2
    tier2_matches = re.findall(r'\\"date\\":\s*\\"([^"]*)\\"[^}]*?\\"organizer\\":\s*\\"([^"]*)\\"[^}]*?\\"location\\":\s*\\"([^"]*)\\"[^}]*?\\"type\\":\s*\\"([^"]*)\\"', tier2_section)
    
    for i, match in enumerate(tier2_matches[:5]):
        date, organizer, location, match_type = match
        print(f"\nTIER 2 MATCH {i+1}:")
        print(f"  Date: '{date}'")
        print(f"  Organizer: '{organizer}'")
        print(f"  Location: '{location}'")
        print(f"  Type: '{match_type}'")
    
    # Look for patterns that suggest field mapping issues
    print("\n🔍 FIELD MAPPING ANALYSIS:")
    print("=" * 50)
    
    # Count empty fields
    tier1_empty_organizers = sum(1 for match in tier1_matches if not match[1].strip())
    tier1_empty_locations = sum(1 for match in tier1_matches if not match[2].strip())
    tier1_empty_types = sum(1 for match in tier1_matches if not match[3].strip())
    
    tier2_empty_organizers = sum(1 for match in tier2_matches if not match[1].strip())
    tier2_empty_locations = sum(1 for match in tier2_matches if not match[2].strip())
    tier2_empty_types = sum(1 for match in tier2_matches if not match[3].strip())
    
    print(f"TIER 1 Empty Fields:")
    print(f"  Empty organizers: {tier1_empty_organizers}/{len(tier1_matches)} ({tier1_empty_organizers/len(tier1_matches)*100:.1f}%)")
    print(f"  Empty locations: {tier1_empty_locations}/{len(tier1_matches)} ({tier1_empty_locations/len(tier1_matches)*100:.1f}%)")
    print(f"  Empty types: {tier1_empty_types}/{len(tier1_matches)} ({tier1_empty_types/len(tier1_matches)*100:.1f}%)")
    
    print(f"\nTIER 2 Empty Fields:")
    print(f"  Empty organizers: {tier2_empty_organizers}/{len(tier2_matches)} ({tier2_empty_organizers/len(tier2_matches)*100:.1f}%)")
    print(f"  Empty locations: {tier2_empty_locations}/{len(tier2_matches)} ({tier2_empty_locations/len(tier2_matches)*100:.1f}%)")
    print(f"  Empty types: {tier2_empty_types}/{len(tier2_matches)} ({tier2_empty_types/len(tier2_matches)*100:.1f}%)")
    
    # Look for specific patterns that suggest field swapping
    print(f"\n🔍 FIELD CONTENT ANALYSIS:")
    print("=" * 50)
    
    # Check if organizer field contains match types
    tier1_types_in_organizer = sum(1 for match in tier1_matches if re.search(r'(MAP|KNJV|veldwedstrijd|TAP)', match[1]))
    print(f"Tier 1 matches with types in organizer field: {tier1_types_in_organizer}")
    
    # Check if type field contains organization names
    tier1_orgs_in_type = sum(1 for match in tier1_matches if re.search(r'(Stichting|Vereniging|Club)', match[3]))
    print(f"Tier 1 matches with organization names in type field: {tier1_orgs_in_type}")
    
    # Check if location field contains organization names
    tier1_orgs_in_location = sum(1 for match in tier1_matches if re.search(r'(Stichting|Vereniging|Club)', match[2]))
    print(f"Tier 1 matches with organization names in location field: {tier1_orgs_in_location}")
    
    # Sample some matches that might have field mapping issues
    print(f"\n🚨 SUSPICIOUS TIER 1 MATCHES:")
    print("=" * 50)
    
    suspicious_count = 0
    for i, match in enumerate(tier1_matches):
        date, organizer, location, match_type = match
        
        # Check for various field mapping issues
        issues = []
        
        if not organizer.strip() and location.strip():
            issues.append("Empty organizer, populated location")
        
        if re.search(r'(MAP|KNJV|veldwedstrijd|TAP)', organizer):
            issues.append("Match type in organizer field")
        
        if re.search(r'(Stichting|Vereniging|Club)', match_type):
            issues.append("Organization name in type field")
        
        if re.search(r'(Stichting|Vereniging|Club)', location) and not organizer.strip():
            issues.append("Organization name in location field, empty organizer")
        
        if issues and suspicious_count < 10:
            print(f"\nSUSPICIOUS MATCH {suspicious_count + 1}:")
            print(f"  Date: '{date}'")
            print(f"  Organizer: '{organizer}'")
            print(f"  Location: '{location}'")
            print(f"  Type: '{match_type}'")
            print(f"  Issues: {', '.join(issues)}")
            suspicious_count += 1
    
    print(f"\n🎯 RECOMMENDATION:")
    print("=" * 50)
    
    if tier1_empty_organizers > len(tier1_matches) * 0.3:
        print("❌ HIGH number of empty organizers in Tier 1 suggests field mapping issues")
    
    if tier1_types_in_organizer > 0:
        print("❌ Match types found in organizer field suggests field order is wrong")
    
    if tier1_orgs_in_type > 0:
        print("❌ Organization names found in type field suggests field order is wrong")
    
    if suspicious_count > 5:
        print("❌ Multiple suspicious patterns found - field mapping likely incorrect")
        print("💡 Recommend re-examining the HTML structure and fixing field extraction")
    else:
        print("✅ Field mapping appears mostly correct")

if __name__ == "__main__":
    inspect_raw_data() 