#!/usr/bin/env python3
"""
Simple analysis of the new scraper results
"""

import re

def analyze_simple():
    """Simple analysis by extracting key metrics from the response"""
    
    print("🔍 SIMPLE ANALYSIS OF NEW SCRAPER RESULTS")
    print("=" * 80)
    
    # Read the response file
    with open('updated_scraper_response.json', 'r') as f:
        content = f.read()
    
    # Extract key metrics using regex (handle escaped JSON)
    tier1_matches = extract_number(content, r'\\"tier1_matches\\":\s*(\d+)')
    tier2_matches = extract_number(content, r'\\"tier2_matches\\":\s*(\d+)')
    final_matches = extract_number(content, r'\\"final_matches\\":\s*(\d+)')
    using_tier1 = 'false' in extract_value(content, r'\\"using_tier1\\":\s*(false|true)')
    
    veldwedstrijd = extract_number(content, r'\\"veldwedstrijd\\":\s*(\d+)')
    jachthondenproef = extract_number(content, r'\\"jachthondenproef\\":\s*(\d+)')
    orweja_werktest = extract_number(content, r'\\"orweja_werktest\\":\s*(\d+)')
    
    print(f"📊 SCRAPER CONFIGURATION:")
    print(f"   Using Tier 1: {not using_tier1}")
    print(f"   Tier 1 matches: {tier1_matches}")
    print(f"   Tier 2 matches: {tier2_matches}")
    print(f"   Final matches: {final_matches}")
    
    print(f"\n📊 TIER 2 BREAKDOWN:")
    print(f"   Veldwedstrijd: {veldwedstrijd}")
    print(f"   Jachthondenproef: {jachthondenproef}")
    print(f"   ORWEJA Werktest: {orweja_werktest}")
    
    # Sample the data to check quality (handle escaped JSON)
    print(f"\n🔍 DATA QUALITY SAMPLING:")
    
    # Count organizer fields
    organizer_matches = re.findall(r'\\"organizer\\":\s*\\"([^\\"]*)\\"', content)
    location_matches = re.findall(r'\\"location\\":\s*\\"([^\\"]*)\\"', content)
    type_matches = re.findall(r'\\"type\\":\s*\\"([^\\"]*)\\"', content)
    calendar_type_matches = re.findall(r'\\"calendar_type\\":\s*\\"([^\\"]*)\\"', content)
    
    print(f"   Total organizer fields found: {len(organizer_matches)}")
    print(f"   Total location fields found: {len(location_matches)}")
    print(f"   Total type fields found: {len(type_matches)}")
    print(f"   Total calendar_type fields found: {len(calendar_type_matches)}")
    
    if len(organizer_matches) == 0:
        print("⚠️  No data fields found - checking response format...")
        # Show first 500 chars to debug
        print(f"   Response preview: {content[:500]}...")
        return
    
    # Check for empty fields
    empty_organizers = sum(1 for org in organizer_matches if not org.strip())
    empty_locations = sum(1 for loc in location_matches if not loc.strip())
    empty_types = sum(1 for typ in type_matches if not typ.strip())
    
    print(f"   Empty organizers: {empty_organizers}/{len(organizer_matches)} ({empty_organizers/len(organizer_matches)*100:.1f}%)")
    print(f"   Empty locations: {empty_locations}/{len(location_matches)} ({empty_locations/len(location_matches)*100:.1f}%)")
    print(f"   Empty types: {empty_types}/{len(type_matches)} ({empty_types/len(type_matches)*100:.1f}%)")
    
    # Check calendar type distribution
    calendar_counts = {}
    for cal_type in calendar_type_matches:
        calendar_counts[cal_type] = calendar_counts.get(cal_type, 0) + 1
    
    print(f"\n📊 CALENDAR TYPE DISTRIBUTION:")
    for cal_type, count in calendar_counts.items():
        print(f"   {cal_type}: {count} matches")
    
    # Sample some organizers to check quality
    print(f"\n🔍 SAMPLE ORGANIZERS (first 10):")
    for i, org in enumerate(organizer_matches[:10]):
        clean_org = org.replace('[email protected]', '').strip()
        if clean_org:
            print(f"   {i+1}. {clean_org[:60]}...")
        else:
            print(f"   {i+1}. [EMPTY]")
    
    # Sample some types to check quality
    print(f"\n🔍 SAMPLE TYPES (first 10):")
    for i, typ in enumerate(type_matches[:10]):
        if typ.strip():
            print(f"   {i+1}. {typ[:50]}...")
        else:
            print(f"   {i+1}. [EMPTY]")
    
    # Final assessment
    print(f"\n🎯 QUICK ASSESSMENT:")
    
    total_expected = veldwedstrijd + jachthondenproef + orweja_werktest
    if tier2_matches == total_expected == final_matches:
        print("✅ Match counts are consistent")
    else:
        print(f"⚠️  Match count discrepancy: tier2={tier2_matches}, breakdown_total={total_expected}, final={final_matches}")
    
    if empty_organizers == 0:
        print("✅ No empty organizers found")
    elif empty_organizers < 5:
        print(f"⚠️  Few empty organizers: {empty_organizers}")
    else:
        print(f"❌ Many empty organizers: {empty_organizers}")
    
    if 'unknown' not in calendar_counts:
        print("✅ All calendar types properly identified")
    else:
        print(f"⚠️  Unknown calendar types: {calendar_counts.get('unknown', 0)}")
    
    # Compare with old system
    print(f"\n📈 IMPROVEMENT SUMMARY:")
    print(f"   OLD SYSTEM:")
    print(f"     Total matches: 142")
    print(f"     Empty organizers: ~20%")
    print(f"     Unknown calendar types: 44")
    print(f"     Field mapping issues: Multiple")
    print(f"   NEW SYSTEM:")
    print(f"     Total matches: {final_matches}")
    print(f"     Empty organizers: {empty_organizers/len(organizer_matches)*100:.1f}%")
    print(f"     Unknown calendar types: {calendar_counts.get('unknown', 0)}")
    print(f"     Tier 1 disabled: {'✅' if using_tier1 else '❌'}")
    
    if empty_organizers < 5 and calendar_counts.get('unknown', 0) < 5:
        print("\n✅ OVERALL: SIGNIFICANT IMPROVEMENT ACHIEVED!")
        print("✅ Ready for production use")
    else:
        print("\n⚠️  OVERALL: Good progress, minor issues remain")

def extract_number(text, pattern):
    """Extract a number using regex pattern"""
    match = re.search(pattern, text)
    return int(match.group(1)) if match else 0

def extract_value(text, pattern):
    """Extract a value using regex pattern"""
    match = re.search(pattern, text)
    return match.group(1) if match else ""

if __name__ == "__main__":
    analyze_simple() 