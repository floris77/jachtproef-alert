#!/usr/bin/env python3
"""
Tier 2 validation: Ensure perfect field mapping and consistency across all 3 protected calendars
"""

import re
from collections import defaultdict

def extract_tier2_data():
    """Extract and analyze Tier 2 data structure"""
    
    with open('scraper_response_FIXED.txt', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find tier2_data section
    tier2_start = content.find('\\"tier2_data\\"')
    tier2_end = content.find('\\"has_match_data\\"', tier2_start)
    
    if tier2_start == -1:
        print("❌ Could not find tier2_data section")
        return []
    
    if tier2_end == -1:
        tier2_end = len(content)
    
    tier2_section = content[tier2_start:tier2_end]
    
    # Extract matches with calendar type information
    matches = []
    
    # Look for calendar_type patterns to identify which calendar each match comes from
    date_splits = re.split(r'(?=\\"date\\")', tier2_section)
    
    for split in date_splits[1:]:
        date_match = re.search(r'\\"date\\":\s*\\"([^"]*)\\"', split)
        organizer_match = re.search(r'\\"organizer\\":\s*\\"([^"]*)\\"', split)
        location_match = re.search(r'\\"location\\":\s*\\"([^"]*)\\"', split)
        type_match = re.search(r'\\"type\\":\s*\\"([^"]*)\\"', split)
        calendar_type_match = re.search(r'\\"calendar_type\\":\s*\\"([^"]*)\\"', split)
        
        if date_match:
            match_data = {
                'date': date_match.group(1) if date_match else '',
                'organizer': organizer_match.group(1) if organizer_match else '',
                'location': location_match.group(1) if location_match else '',
                'type': type_match.group(1) if type_match else '',
                'calendar_type': calendar_type_match.group(1) if calendar_type_match else 'unknown'
            }
            matches.append(match_data)
    
    return matches

def clean_text(text):
    """Clean text by removing escape characters and normalizing whitespace"""
    if not text:
        return ""
    
    # Remove escape characters
    text = text.replace('\\', '')
    # Remove unicode artifacts
    text = re.sub(r'u00[a-fA-F0-9]{2}', '', text)
    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text)
    # Remove common parsing artifacts
    text = re.sub(r'Aanvang:.*$', '', text)
    # Remove email artifacts
    text = re.sub(r'\[email.*?protected\]', '', text)
    return text.strip()

def validate_tier2_field_mapping():
    """Validate Tier 2 field mappings and identify any issues"""
    
    print("🔍 TIER 2 FIELD MAPPING VALIDATION")
    print("=" * 80)
    
    matches = extract_tier2_data()
    
    if not matches:
        print("❌ No Tier 2 matches found")
        return
    
    print(f"📊 Total Tier 2 matches found: {len(matches)}")
    
    # Group by calendar type
    by_calendar = defaultdict(list)
    for match in matches:
        calendar_type = match.get('calendar_type', 'unknown')
        by_calendar[calendar_type].append(match)
    
    print(f"\n📊 BREAKDOWN BY CALENDAR:")
    print("=" * 50)
    for calendar_type, calendar_matches in by_calendar.items():
        print(f"{calendar_type}: {len(calendar_matches)} matches")
    
    # Analyze field quality for each calendar
    print(f"\n🔍 FIELD QUALITY ANALYSIS:")
    print("=" * 50)
    
    for calendar_type, calendar_matches in by_calendar.items():
        print(f"\n{calendar_type.upper()} CALENDAR:")
        
        # Count empty fields
        empty_organizers = sum(1 for m in calendar_matches if not clean_text(m['organizer']))
        empty_locations = sum(1 for m in calendar_matches if not clean_text(m['location']))
        empty_types = sum(1 for m in calendar_matches if not clean_text(m['type']))
        
        total = len(calendar_matches)
        print(f"  Empty organizers: {empty_organizers}/{total} ({empty_organizers/total*100:.1f}%)")
        print(f"  Empty locations: {empty_locations}/{total} ({empty_locations/total*100:.1f}%)")
        print(f"  Empty types: {empty_types}/{total} ({empty_types/total*100:.1f}%)")
        
        # Check for field mapping issues
        types_in_organizer = sum(1 for m in calendar_matches if re.search(r'(MAP|KNJV|veldwedstrijd|TAP|CAC|CACIT)', clean_text(m['organizer'])))
        orgs_in_type = sum(1 for m in calendar_matches if re.search(r'(Stichting|Vereniging|Club)', clean_text(m['type'])))
        
        print(f"  Match types in organizer field: {types_in_organizer}")
        print(f"  Organization names in type field: {orgs_in_type}")
        
        # Show sample matches
        print(f"  Sample matches:")
        for i, match in enumerate(calendar_matches[:3]):
            print(f"    {i+1}. {match['date']} | {clean_text(match['organizer'])[:50]}... | {clean_text(match['type'])[:30]}...")
    
    # Look for suspicious patterns
    print(f"\n🚨 SUSPICIOUS PATTERNS:")
    print("=" * 50)
    
    suspicious_matches = []
    
    for match in matches:
        issues = []
        
        organizer = clean_text(match['organizer'])
        location = clean_text(match['location'])
        match_type = clean_text(match['type'])
        
        # Check for field mapping issues
        if re.search(r'(MAP|KNJV|veldwedstrijd|TAP|CAC|CACIT)', organizer):
            issues.append("Match type in organizer field")
        
        if re.search(r'(Stichting|Vereniging|Club)', match_type):
            issues.append("Organization name in type field")
        
        # Check for empty critical fields
        if not organizer and not location:
            issues.append("Empty organizer and location")
        
        # Check for very short fields
        if len(organizer) < 3 and len(location) < 3:
            issues.append("Very short organizer and location")
        
        if issues:
            suspicious_matches.append({
                'match': match,
                'issues': issues
            })
    
    if suspicious_matches:
        print(f"Found {len(suspicious_matches)} suspicious matches:")
        for i, suspicious in enumerate(suspicious_matches[:10]):
            match = suspicious['match']
            issues = suspicious['issues']
            print(f"\n{i+1}. SUSPICIOUS ({match.get('calendar_type', 'unknown')} calendar):")
            print(f"   Date: {match['date']}")
            print(f"   Organizer: '{clean_text(match['organizer'])}'")
            print(f"   Location: '{clean_text(match['location'])}'")
            print(f"   Type: '{clean_text(match['type'])}'")
            print(f"   Issues: {', '.join(issues)}")
    else:
        print("✅ No suspicious patterns found in Tier 2 data")
    
    # Check for duplicates across calendars
    print(f"\n🔍 DUPLICATE DETECTION:")
    print("=" * 50)
    
    # Group by date to find potential duplicates
    by_date = defaultdict(list)
    for match in matches:
        by_date[match['date']].append(match)
    
    duplicates_found = []
    for date, date_matches in by_date.items():
        if len(date_matches) > 1:
            # Check if they're actually duplicates (same location/organizer)
            for i, match1 in enumerate(date_matches):
                for j, match2 in enumerate(date_matches[i+1:], i+1):
                    org1 = clean_text(match1['organizer'])
                    org2 = clean_text(match2['organizer'])
                    loc1 = clean_text(match1['location'])
                    loc2 = clean_text(match2['location'])
                    
                    # Check for high similarity
                    from difflib import SequenceMatcher
                    org_sim = SequenceMatcher(None, org1.lower(), org2.lower()).ratio()
                    loc_sim = SequenceMatcher(None, loc1.lower(), loc2.lower()).ratio()
                    
                    if org_sim > 0.8 or loc_sim > 0.8:
                        duplicates_found.append({
                            'date': date,
                            'match1': match1,
                            'match2': match2,
                            'org_similarity': org_sim,
                            'loc_similarity': loc_sim
                        })
    
    if duplicates_found:
        print(f"Found {len(duplicates_found)} potential duplicates:")
        for i, dup in enumerate(duplicates_found[:5]):
            print(f"\n{i+1}. DUPLICATE on {dup['date']}:")
            print(f"   Calendar 1 ({dup['match1'].get('calendar_type', 'unknown')}): {clean_text(dup['match1']['organizer'])}")
            print(f"   Calendar 2 ({dup['match2'].get('calendar_type', 'unknown')}): {clean_text(dup['match2']['organizer'])}")
            print(f"   Similarity: Org={dup['org_similarity']:.2f}, Loc={dup['loc_similarity']:.2f}")
    else:
        print("✅ No duplicates found across calendars")
    
    # Final recommendation
    print(f"\n🎯 TIER 2 VALIDATION SUMMARY:")
    print("=" * 50)
    
    total_issues = len(suspicious_matches)
    total_duplicates = len(duplicates_found)
    
    if total_issues == 0 and total_duplicates == 0:
        print("✅ TIER 2 DATA QUALITY: EXCELLENT")
        print("✅ Field mappings appear correct")
        print("✅ No duplicates detected")
        print("✅ Recommendation: Tier 2 is ready for production use")
    elif total_issues < 5 and total_duplicates < 3:
        print("⚠️  TIER 2 DATA QUALITY: GOOD")
        print(f"⚠️  Minor issues found: {total_issues} suspicious matches, {total_duplicates} duplicates")
        print("✅ Recommendation: Tier 2 is usable with minor cleanup")
    else:
        print("❌ TIER 2 DATA QUALITY: NEEDS ATTENTION")
        print(f"❌ Issues found: {total_issues} suspicious matches, {total_duplicates} duplicates")
        print("💡 Recommendation: Fix field mappings and duplicate handling")
    
    return matches, suspicious_matches, duplicates_found

if __name__ == "__main__":
    validate_tier2_field_mapping() 