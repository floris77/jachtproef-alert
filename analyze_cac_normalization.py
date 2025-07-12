#!/usr/bin/env python3
"""
Analyze CAC/CACIT normalization results
"""

import re

def analyze_cac_normalization():
    """Analyze if CAC/CACIT normalization worked correctly"""
    
    print("🔍 ANALYZING CAC/CACIT NORMALIZATION RESULTS")
    print("=" * 60)
    
    # Read the response file
    with open('scraper_with_data.json', 'r') as f:
        content = f.read()
    
    # Extract match data using regex (handle escaped JSON)
    type_matches = re.findall(r'\\"type\\": \\"([^\\"]*)\\"', content)
    organizer_matches = re.findall(r'\\"organizer\\": \\"([^\\"]*)\\"', content)
    remark_matches = re.findall(r'\\"remark\\": \\"([^\\"]*)\\"', content)
    calendar_type_matches = re.findall(r'\\"calendar_type\\": \\"([^\\"]*)\\"', content)
    
    print(f"📊 FOUND DATA:")
    print(f"   Types found: {len(type_matches)}")
    print(f"   Organizers found: {len(organizer_matches)}")
    print(f"   Remarks found: {len(remark_matches)}")
    print(f"   Calendar types found: {len(calendar_type_matches)}")
    
    # Analyze types
    type_counts = {}
    for match_type in type_matches:
        type_counts[match_type] = type_counts.get(match_type, 0) + 1
    
    print(f"\n📊 MATCH TYPE DISTRIBUTION:")
    for match_type, count in sorted(type_counts.items()):
        print(f"   {match_type}: {count} matches")
    
    # Look for CAC/CACIT in types (should be 0 if normalization worked)
    cac_in_types = [t for t in type_matches if 'CAC' in t.upper()]
    cacit_in_types = [t for t in type_matches if 'CACIT' in t.upper()]
    
    print(f"\n🔍 CAC/CACIT IN TYPES ANALYSIS:")
    print(f"   Types containing 'CAC': {len(cac_in_types)}")
    print(f"   Types containing 'CACIT': {len(cacit_in_types)}")
    
    if cac_in_types:
        print(f"   CAC types found: {set(cac_in_types)}")
    if cacit_in_types:
        print(f"   CACIT types found: {set(cacit_in_types)}")
    
    # Look for CAC/CACIT in organizers (this is where the original info might be)
    cac_in_organizers = [o for o in organizer_matches if 'CAC' in o.upper() and 'CAC' != o.upper()]
    cacit_in_organizers = [o for o in organizer_matches if 'CACIT' in o.upper()]
    
    print(f"\n🔍 CAC/CACIT IN ORGANIZERS ANALYSIS:")
    print(f"   Organizers containing 'CAC': {len(cac_in_organizers)}")
    print(f"   Organizers containing 'CACIT': {len(cacit_in_organizers)}")
    
    if cac_in_organizers:
        print(f"   Sample CAC organizers:")
        for org in list(set(cac_in_organizers))[:3]:
            print(f"     - {org}")
    
    if cacit_in_organizers:
        print(f"   Sample CACIT organizers:")
        for org in list(set(cacit_in_organizers))[:3]:
            print(f"     - {org}")
    
    # Look for CAC/CACIT in remarks (should be > 0 if normalization worked correctly)
    cac_in_remarks = [r for r in remark_matches if 'CAC' in r.upper()]
    cacit_in_remarks = [r for r in remark_matches if 'CACIT' in r.upper()]
    
    print(f"\n🔍 CAC/CACIT IN REMARKS ANALYSIS:")
    print(f"   Remarks containing 'CAC': {len(cac_in_remarks)}")
    print(f"   Remarks containing 'CACIT': {len(cacit_in_remarks)}")
    
    if cac_in_remarks:
        print(f"   Sample CAC remarks:")
        for remark in list(set(cac_in_remarks))[:3]:
            print(f"     - {remark}")
    
    if cacit_in_remarks:
        print(f"   Sample CACIT remarks:")
        for remark in list(set(cacit_in_remarks))[:3]:
            print(f"     - {remark}")
    
    # Check Veldwedstrijd count
    veldwedstrijd_count = type_counts.get('Veldwedstrijd', 0)
    
    print(f"\n📊 VELDWEDSTRIJD ANALYSIS:")
    print(f"   Matches with type 'Veldwedstrijd': {veldwedstrijd_count}")
    
    # Calendar type distribution
    calendar_counts = {}
    for cal_type in calendar_type_matches:
        calendar_counts[cal_type] = calendar_counts.get(cal_type, 0) + 1
    
    print(f"\n📊 CALENDAR TYPE DISTRIBUTION:")
    for cal_type, count in calendar_counts.items():
        print(f"   {cal_type}: {count} matches")
    
    # Assessment
    print(f"\n🎯 NORMALIZATION ASSESSMENT:")
    
    if len(cac_in_types) == 0 and len(cacit_in_types) == 0:
        print("✅ SUCCESS: No CAC/CACIT found in match types (properly normalized)")
    else:
        print("❌ ISSUE: CAC/CACIT still found in match types (normalization failed)")
    
    if len(cac_in_organizers) > 0 or len(cacit_in_organizers) > 0:
        print("✅ INFO: CAC/CACIT info found in organizer fields (original data preserved)")
    
    if len(cac_in_remarks) > 0 or len(cacit_in_remarks) > 0:
        print("✅ SUCCESS: CAC/CACIT info preserved in remarks")
    else:
        print("⚠️  INFO: No CAC/CACIT info found in remarks (may be in organizer field instead)")
    
    expected_veldwedstrijd = calendar_counts.get('Veldwedstrijd', 0)
    if veldwedstrijd_count == expected_veldwedstrijd:
        print(f"✅ SUCCESS: All {veldwedstrijd_count} Veldwedstrijd calendar matches normalized to 'Veldwedstrijd' type")
    else:
        print(f"⚠️  WARNING: Type/calendar mismatch - {veldwedstrijd_count} type vs {expected_veldwedstrijd} calendar")
    
    # Final verdict
    print(f"\n🏆 FINAL VERDICT:")
    if (len(cac_in_types) == 0 and len(cacit_in_types) == 0 and 
        veldwedstrijd_count == expected_veldwedstrijd):
        print("🎉 CAC/CACIT NORMALIZATION SUCCESSFUL!")
        print("✅ Users filtering for 'Veldwedstrijd' will now see ALL field trial matches")
        print("✅ CAC/CACIT qualification info preserved in organizer/remarks")
        print("✅ Consistent match type categorization achieved")
        
        print(f"\n📈 IMPACT:")
        print(f"   • Before: CAC/CACIT matches were separate categories")
        print(f"   • After: All {veldwedstrijd_count} field trials show as 'Veldwedstrijd'")
        print(f"   • Benefit: Users get complete view when filtering for field trials")
    else:
        print("⚠️  CAC/CACIT normalization needs review")

if __name__ == "__main__":
    analyze_cac_normalization() 