#!/usr/bin/env python3
"""
Extract the real Tier 2 data from the scraper response
"""

import json
import re

def extract_tier2_data():
    """Extract tier2_data from the scraper response"""
    
    # The full response from the scraper (truncated in display but contains all data)
    response_text = """{"success": true, "tier1_matches": 0, "tier2_matches": 151, "tier2_breakdown": {"veldwedstrijd": 90, "jachthondenproef": 60, "orweja_werktest": 1}, "final_matches": 151, "matches_uploaded": 151, "using_tier1": false, "timestamp": "2025-07-06T19:49:01.713981", "tier1_data": [], "tier2_data": [{"date": "2025-07-24", "organizer": "Chesapeake Bay Retriever Club Nederland [email protected]", "location": "West Brabant", "remarks": "", "registration_text": "Inschrijven", "type": "CAC Apporteerwedstrijd", "source": "tier2", "calendar_type": "Veldwedstrijd"}, {"date": "2025-09-03", "organizer": "Continentale Staande honden Vereeniging [email protected]", "location": "St. Annaland", "remarks": "Selectie wedstrijd WK Continentale", "registration_text": "Inschrijven", "type": "CACIT Najaarswedstrijd Continentaal I koppel", "source": "tier2", "calendar_type": "Veldwedstrijd"}, {"date": "2025-09-03", "organizer": "Vereniging De Weimarse Staande Hond [email protected]", "location": "Budel", "remarks": "Alleen inschrijven met een staande hond (rasgroep 7) de hond moet tenminste een van de aantekeningen ZW D, ZW E, ZW F bezitten", "registration_text": "Inschrijven", "type": "CAC Zweetspoorproef C", "source": "tier2", "calendar_type": "Veldwedstrijd"}], "has_match_data": true}"""
    
    # Since the response was truncated in the terminal output, let's analyze what we can see
    # and run the scraper again to get the full data
    
    print("🔍 EXTRACTING REAL TIER 2 DATA")
    print("=" * 50)
    
    # Parse what we have
    try:
        data = json.loads(response_text)
        tier2_data = data.get('tier2_data', [])
        
        print(f"📊 CURRENT DATA SAMPLE:")
        print(f"   Total matches in response: {len(tier2_data)}")
        print(f"   Expected matches: {data.get('tier2_matches', 0)}")
        
        if len(tier2_data) < data.get('tier2_matches', 0):
            print("⚠️  Response was truncated - need to get full data")
            
            # Let's run the scraper again to get the complete data
            print("\n🚀 Running scraper again to get complete data...")
            
        else:
            print("✅ Have complete data - analyzing...")
            analyze_tier2_data(tier2_data)
            
    except json.JSONDecodeError as e:
        print(f"❌ Failed to parse JSON: {e}")

def analyze_tier2_data(tier2_data):
    """Analyze the Tier 2 data quality"""
    
    from collections import defaultdict
    
    print(f"\n🔍 TIER 2 DATA ANALYSIS:")
    print(f"   Total matches: {len(tier2_data)}")
    
    # Group by calendar type
    by_calendar = defaultdict(list)
    for match in tier2_data:
        calendar_type = match.get('calendar_type', 'unknown')
        by_calendar[calendar_type].append(match)
    
    print(f"\n📊 BREAKDOWN BY CALENDAR:")
    for calendar_type, matches in by_calendar.items():
        print(f"   {calendar_type}: {len(matches)} matches")
    
    # Check data quality
    total_issues = 0
    for calendar_type, matches in by_calendar.items():
        print(f"\n   {calendar_type.upper()} QUALITY:")
        
        empty_organizers = sum(1 for m in matches if not clean_text(m.get('organizer', '')))
        empty_locations = sum(1 for m in matches if not clean_text(m.get('location', '')))
        empty_types = sum(1 for m in matches if not clean_text(m.get('type', '')))
        
        print(f"     Empty organizers: {empty_organizers}/{len(matches)} ({empty_organizers/len(matches)*100:.1f}%)")
        print(f"     Empty locations: {empty_locations}/{len(matches)} ({empty_locations/len(matches)*100:.1f}%)")
        print(f"     Empty types: {empty_types}/{len(matches)} ({empty_types/len(matches)*100:.1f}%)")
        
        # Check field mapping
        types_in_organizer = sum(1 for m in matches if re.search(r'(MAP|KNJV|veldwedstrijd|TAP|CAC|CACIT)', clean_text(m.get('organizer', ''))))
        print(f"     Match types in organizer: {types_in_organizer}")
        
        total_issues += empty_organizers + empty_locations + empty_types + types_in_organizer
        
        # Show samples
        print(f"     Sample matches:")
        for i, match in enumerate(matches[:2]):
            org = clean_text(match.get('organizer', ''))[:35]
            typ = clean_text(match.get('type', ''))[:20]
            print(f"       {i+1}. {org}... | {typ}...")
    
    print(f"\n🎯 SUMMARY:")
    print(f"   Total quality issues: {total_issues}")
    
    if total_issues < 10:
        print("✅ EXCELLENT: Data quality is very good!")
    elif total_issues < 30:
        print("⚠️  GOOD: Minor issues found")
    else:
        print("❌ NEEDS WORK: Significant issues remain")

def clean_text(text):
    """Clean text by removing escape characters and normalizing whitespace"""
    if not text:
        return ""
    
    # Remove escape characters and email artifacts
    text = text.replace('\\', '')
    text = re.sub(r'\[email.*?protected\]', '', text)
    text = re.sub(r'u00[a-fA-F0-9]{2}', '', text)
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

if __name__ == "__main__":
    extract_tier2_data() 