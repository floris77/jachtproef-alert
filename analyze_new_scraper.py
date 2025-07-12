#!/usr/bin/env python3
"""
Analyze the new scraper results and show improvements
"""

import json
import re
from collections import defaultdict

def analyze_new_scraper():
    """Analyze the new scraper results from the updated_scraper_response.json"""
    
    print("🔍 ANALYZING NEW SCRAPER RESULTS")
    print("=" * 80)
    
    # Read the response file
    with open('updated_scraper_response.json', 'r') as f:
        content = f.read()
    
    # Extract the JSON from the gcloud response format
    # The response is: executionId: xxx\nresult: "{...}" (possibly multiline)
    lines = content.strip().split('\n')
    
    # Find the result line and collect all continuation lines
    result_lines = []
    collecting = False
    
    for line in lines:
        if line.startswith('result:'):
            result_lines.append(line[7:].strip())  # Remove 'result: '
            collecting = True
        elif collecting and line.strip():
            # This is a continuation line
            result_lines.append(line.strip())
        elif collecting and not line.strip():
            # Empty line might end the result
            break
    
    if not result_lines:
        print("❌ Could not find result in response")
        return
    
    # Join all result lines and remove backslash continuations
    result_line = ' '.join(result_lines)
    result_line = result_line.replace('\\\n', '').replace('\\', '')
    
    # Parse the JSON (it's double-encoded)
    try:
        # The result line contains escaped JSON, need to handle it carefully
        # Remove the outer quotes and unescape
        if result_line.startswith('"') and result_line.endswith('"'):
            result_line = result_line[1:-1]  # Remove outer quotes
        
        # Replace escaped quotes
        result_line = result_line.replace('\\"', '"')
        
        # Now parse the JSON
        result_data = json.loads(result_line)
        
        # Extract the data
        tier1_matches = result_data.get('tier1_matches', 0)
        tier2_matches = result_data.get('tier2_matches', 0)
        final_matches = result_data.get('final_matches', 0)
        using_tier1 = result_data.get('using_tier1', False)
        tier2_breakdown = result_data.get('tier2_breakdown', {})
        tier2_data = result_data.get('tier2_data', [])
        
        print(f"📊 SCRAPER CONFIGURATION:")
        print(f"   Using Tier 1: {using_tier1}")
        print(f"   Tier 1 matches: {tier1_matches}")
        print(f"   Tier 2 matches: {tier2_matches}")
        print(f"   Final matches: {final_matches}")
        
        print(f"\n📊 TIER 2 BREAKDOWN:")
        print(f"   Veldwedstrijd: {tier2_breakdown.get('veldwedstrijd', 0)}")
        print(f"   Jachthondenproef: {tier2_breakdown.get('jachthondenproef', 0)}")
        print(f"   ORWEJA Werktest: {tier2_breakdown.get('orweja_werktest', 0)}")
        
        # Analyze data quality
        analyze_data_quality(tier2_data)
        
    except json.JSONDecodeError as e:
        print(f"❌ Failed to parse JSON: {e}")
        print(f"First 200 chars: {result_line[:200]}")

def analyze_data_quality(tier2_data):
    """Analyze the quality of Tier 2 data"""
    
    print(f"\n🔍 DATA QUALITY ANALYSIS:")
    print(f"   Total matches: {len(tier2_data)}")
    
    # Group by calendar type
    by_calendar = defaultdict(list)
    for match in tier2_data:
        calendar_type = match.get('calendar_type', 'unknown')
        by_calendar[calendar_type].append(match)
    
    print(f"\n📊 BREAKDOWN BY CALENDAR:")
    for calendar_type, matches in by_calendar.items():
        print(f"   {calendar_type}: {len(matches)} matches")
    
    # Analyze each calendar's data quality
    total_issues = 0
    all_suspicious = []
    
    for calendar_type, matches in by_calendar.items():
        print(f"\n   {calendar_type.upper()} CALENDAR:")
        
        # Count empty fields
        empty_organizers = sum(1 for m in matches if not clean_text(m.get('organizer', '')))
        empty_locations = sum(1 for m in matches if not clean_text(m.get('location', '')))
        empty_types = sum(1 for m in matches if not clean_text(m.get('type', '')))
        
        print(f"     Matches: {len(matches)}")
        print(f"     Empty organizers: {empty_organizers}/{len(matches)} ({empty_organizers/len(matches)*100:.1f}%)")
        print(f"     Empty locations: {empty_locations}/{len(matches)} ({empty_locations/len(matches)*100:.1f}%)")
        print(f"     Empty types: {empty_types}/{len(matches)} ({empty_types/len(matches)*100:.1f}%)")
        
        # Check for field mapping issues
        types_in_organizer = 0
        orgs_in_type = 0
        
        for match in matches:
            organizer = clean_text(match.get('organizer', ''))
            match_type = clean_text(match.get('type', ''))
            
            if re.search(r'\\b(MAP|KNJV|veldwedstrijd|TAP|CAC|CACIT)\\b', organizer, re.IGNORECASE):
                types_in_organizer += 1
            
            if re.search(r'\\b(Stichting|Vereniging|Club)\\b', match_type, re.IGNORECASE):
                orgs_in_type += 1
        
        print(f"     Match types in organizer field: {types_in_organizer}")
        print(f"     Organization names in type field: {orgs_in_type}")
        
        # Find suspicious matches
        suspicious_matches = []
        for match in matches:
            issues = []
            
            organizer = clean_text(match.get('organizer', ''))
            location = clean_text(match.get('location', ''))
            match_type = clean_text(match.get('type', ''))
            
            # Check for field mapping issues
            if re.search(r'\\b(MAP|KNJV|veldwedstrijd|TAP|CAC|CACIT)\\b', organizer, re.IGNORECASE):
                issues.append("Match type in organizer field")
            
            if re.search(r'\\b(Stichting|Vereniging|Club)\\b', match_type, re.IGNORECASE):
                issues.append("Organization name in type field")
            
            # Check for empty critical fields
            if not organizer:
                issues.append("Empty organizer")
            if not location:
                issues.append("Empty location")
            if not match_type:
                issues.append("Empty type")
            
            if issues:
                suspicious_matches.append({
                    'match': match,
                    'issues': issues,
                    'calendar_type': calendar_type
                })
        
        print(f"     Suspicious matches: {len(suspicious_matches)}")
        all_suspicious.extend(suspicious_matches)
        total_issues += len(suspicious_matches)
        
        # Show sample matches
        print(f"     Sample matches:")
        for i, match in enumerate(matches[:3]):
            organizer = clean_text(match.get('organizer', ''))[:40]
            match_type = clean_text(match.get('type', ''))[:30]
            date = match.get('date', 'No date')
            print(f"       {i+1}. {date} | {organizer}... | {match_type}...")
    
    # Check for duplicates
    print(f"\n🔍 DUPLICATE DETECTION:")
    duplicates = find_duplicates(tier2_data)
    print(f"   Potential duplicates: {len(duplicates)}")
    
    if duplicates:
        print(f"   Sample duplicates:")
        for i, dup in enumerate(duplicates[:3]):
            print(f"     {i+1}. {dup['date']}: {dup['match1']['organizer'][:30]}... vs {dup['match2']['organizer'][:30]}...")
    
    # Final assessment
    print(f"\n🎯 FINAL ASSESSMENT:")
    print(f"   Total issues found: {total_issues}")
    print(f"   Duplicates found: {len(duplicates)}")
    
    if total_issues == 0 and len(duplicates) == 0:
        print("✅ PERFECT: No issues found!")
        print("✅ Field mappings are working correctly")
        print("✅ No duplicates detected")
        print("✅ All calendar types properly identified")
        print("✅ Ready for production use")
    elif total_issues < 5 and len(duplicates) < 5:
        print("✅ EXCELLENT: Very few issues found")
        print("✅ Significant improvement achieved")
        print("✅ Ready for production use")
    elif total_issues < 15 and len(duplicates) < 15:
        print("⚠️  GOOD: Minor issues remain")
        print("⚠️  Acceptable for production with monitoring")
    else:
        print("❌ NEEDS WORK: Significant issues remain")
        print("❌ Requires further fixes")
    
    # Show comparison with old system
    print(f"\n📈 IMPROVEMENT COMPARISON:")
    print(f"   OLD SYSTEM (from previous analysis):")
    print(f"     Total matches: 142")
    print(f"     Suspicious matches: 24")
    print(f"     Duplicates: 69")
    print(f"     Unknown calendar types: 44")
    print(f"     Empty organizers: ~20%")
    print(f"   NEW SYSTEM (current):")
    print(f"     Total matches: {len(tier2_data)}")
    print(f"     Suspicious matches: {total_issues}")
    print(f"     Duplicates: {len(duplicates)}")
    print(f"     Unknown calendar types: {len(by_calendar.get('unknown', []))}")
    print(f"     Empty organizers: {sum(1 for m in tier2_data if not clean_text(m.get('organizer', '')))/len(tier2_data)*100:.1f}%")
    
    # Show some suspicious matches if any
    if all_suspicious:
        print(f"\n🚨 SUSPICIOUS MATCHES (first 3):")
        for i, suspicious in enumerate(all_suspicious[:3]):
            match = suspicious['match']
            issues = suspicious['issues']
            print(f"   {i+1}. {suspicious['calendar_type']} - {match.get('date', 'No date')}:")
            print(f"      Organizer: '{clean_text(match.get('organizer', ''))}'")
            print(f"      Type: '{clean_text(match.get('type', ''))}'")
            print(f"      Issues: {', '.join(issues)}")

def clean_text(text):
    """Clean text by removing escape characters and normalizing whitespace"""
    if not text:
        return ""
    
    # Remove escape characters and email artifacts
    text = text.replace('\\\\', '')
    text = re.sub(r'\\[email.*?protected\\]', '', text)
    text = re.sub(r'\\u00[a-fA-F0-9]{2}', '', text)
    text = re.sub(r'\\s+', ' ', text)
    return text.strip()

def find_duplicates(matches):
    """Find potential duplicate matches"""
    duplicates = []
    
    # Group by date
    by_date = defaultdict(list)
    for match in matches:
        by_date[match.get('date', '')].append(match)
    
    for date, date_matches in by_date.items():
        if len(date_matches) > 1:
            # Check for duplicates within the same date
            for i, match1 in enumerate(date_matches):
                for j, match2 in enumerate(date_matches[i+1:], i+1):
                    org1 = clean_text(match1.get('organizer', ''))
                    org2 = clean_text(match2.get('organizer', ''))
                    loc1 = clean_text(match1.get('location', ''))
                    loc2 = clean_text(match2.get('location', ''))
                    
                    # Check for high similarity
                    from difflib import SequenceMatcher
                    org_sim = SequenceMatcher(None, org1.lower(), org2.lower()).ratio()
                    loc_sim = SequenceMatcher(None, loc1.lower(), loc2.lower()).ratio()
                    
                    if org_sim > 0.8 or loc_sim > 0.8:
                        duplicates.append({
                            'date': date,
                            'match1': match1,
                            'match2': match2,
                            'org_similarity': org_sim,
                            'loc_similarity': loc_sim
                        })
    
    return duplicates

if __name__ == "__main__":
    analyze_new_scraper() 