#!/usr/bin/env python3
"""
Analyze KNJV matches that can be corrected with Tier 2 specific match types
Match on date + location similarity instead of organizer
"""

import csv
import re
from datetime import datetime
from difflib import SequenceMatcher

def similarity(a, b):
    """Calculate similarity between two strings"""
    if not a or not b:
        return 0
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()

def extract_matches_from_fixed_response():
    """Extract matches from the fixed scraper response"""
    with open('scraper_response_FIXED.txt', 'r', encoding='utf-8') as f:
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
    
    # Parse matches
    tier1_matches = parse_matches_from_section(tier1_section, "Tier 1")
    tier2_matches = parse_matches_from_section(tier2_section, "Tier 2")
    
    return tier1_matches, tier2_matches

def parse_matches_from_section(section, tier_name):
    """Parse matches from a section"""
    matches = []
    
    date_splits = re.split(r'(?=\\"date\\")', section)
    
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
                'calendar_type': calendar_type_match.group(1) if calendar_type_match else tier_name
            }
            matches.append(match_data)
    
    print(f"{tier_name}: Found {len(matches)} matches")
    return matches

def analyze_knjv_corrections():
    """Analyze how many KNJV matches can be corrected with Tier 2 data"""
    tier1_matches, tier2_matches = extract_matches_from_fixed_response()
    
    print(f"\nAnalyzing KNJV corrections using date + location matching:")
    print(f"Tier 1 matches: {len(tier1_matches)}")
    print(f"Tier 2 matches: {len(tier2_matches)}")
    
    # Filter KNJV matches from Tier 1
    knjv_matches = [match for match in tier1_matches if match['type'] == 'KNJV']
    print(f"KNJV matches in Tier 1: {len(knjv_matches)}")
    
    # Find KNJV matches that can be corrected with Tier 2 data
    correctable_matches = []
    uncorrectable_knjv = []
    
    for knjv_match in knjv_matches:
        best_match = None
        best_score = 0
        
        for t2_match in tier2_matches:
            # Check if dates match exactly
            if knjv_match['date'] == t2_match['date']:
                # Calculate location similarity
                loc_sim = similarity(knjv_match['location'], t2_match['location'])
                
                # Also check organizer similarity as secondary factor
                org_sim = similarity(knjv_match['organizer'], t2_match['organizer'])
                
                # Combined score: location is primary, organizer is secondary
                combined_score = (loc_sim * 0.7) + (org_sim * 0.3)
                
                if combined_score > best_score:
                    best_score = combined_score
                    best_match = t2_match
        
        # Consider it correctable if score > 0.5
        if best_score > 0.5:
            correctable_matches.append({
                'knjv_match': knjv_match,
                'tier2_match': best_match,
                'score': best_score,
                'location_sim': similarity(knjv_match['location'], best_match['location']),
                'organizer_sim': similarity(knjv_match['organizer'], best_match['organizer'])
            })
        else:
            uncorrectable_knjv.append(knjv_match)
    
    print(f"\n📊 KNJV CORRECTION RESULTS:")
    print("=" * 60)
    print(f"✅ CORRECTABLE KNJV matches: {len(correctable_matches)}")
    print(f"❌ UNCORRECTABLE KNJV matches: {len(uncorrectable_knjv)}")
    print(f"📈 Correction rate: {len(correctable_matches)/len(knjv_matches)*100:.1f}%")
    
    # Show examples of correctable matches
    print(f"\n🔧 SAMPLE KNJV CORRECTIONS:")
    print("=" * 60)
    for i, correction in enumerate(correctable_matches[:10]):
        knjv = correction['knjv_match']
        t2 = correction['tier2_match']
        print(f"\nCorrection {i+1} (Score: {correction['score']:.2f}):")
        print(f"  KNJV: {knjv['date']} | {knjv['organizer']} | {knjv['type']}")
        print(f"  →  T2: {t2['date']} | {t2['organizer']} | {t2['type']}")
        print(f"      Location sim: {correction['location_sim']:.2f} | Organizer sim: {correction['organizer_sim']:.2f}")
    
    # Show uncorrectable KNJV matches
    if uncorrectable_knjv:
        print(f"\n❌ UNCORRECTABLE KNJV MATCHES:")
        print("=" * 60)
        for i, match in enumerate(uncorrectable_knjv[:10]):
            print(f"{i+1}. {match['date']} | {match['organizer']} | {match['location']}")
    
    # Now recalculate unique matches after KNJV corrections
    print(f"\n🔄 RECALCULATING UNIQUE MATCHES AFTER KNJV CORRECTIONS:")
    print("=" * 60)
    
    # Remove correctable KNJV matches from tier1_unique calculation
    correctable_knjv_dates_orgs = set()
    for correction in correctable_matches:
        knjv = correction['knjv_match']
        correctable_knjv_dates_orgs.add((knjv['date'], knjv['organizer']))
    
    # Find truly unique Tier 1 matches (excluding correctable KNJV)
    tier1_truly_unique = []
    for t1_match in tier1_matches:
        # Skip if this is a correctable KNJV match
        if (t1_match['date'], t1_match['organizer']) in correctable_knjv_dates_orgs:
            continue
            
        # Check if it has a match in Tier 2
        has_match = False
        for t2_match in tier2_matches:
            if t1_match['date'] == t2_match['date']:
                org_sim = similarity(t1_match['organizer'], t2_match['organizer'])
                if org_sim > 0.6:
                    has_match = True
                    break
        
        if not has_match:
            tier1_truly_unique.append(t1_match)
    
    print(f"Original Tier 1 unique matches: {len([m for m in tier1_matches if m not in [c['knjv_match'] for c in correctable_matches]])}")
    print(f"After KNJV corrections, truly unique Tier 1 matches: {len(tier1_truly_unique)}")
    print(f"Reduction in unique matches: {len(knjv_matches) - len(tier1_truly_unique)}")
    
    # Final recommendation
    print(f"\n🎯 UPDATED RECOMMENDATION:")
    print("=" * 60)
    total_correctable = len(correctable_matches)
    remaining_unique = len(tier1_truly_unique)
    
    if remaining_unique <= 5:
        print("✅ After KNJV corrections, you can ALMOST rely solely on Tier 2!")
        print(f"   Only {remaining_unique} truly unique Tier 1 matches remain.")
        print(f"   {total_correctable} KNJV matches can be corrected with Tier 2 data.")
    elif remaining_unique <= 15:
        print("⚠️  After KNJV corrections, Tier 2 covers most content.")
        print(f"   {total_correctable} KNJV matches correctable, {remaining_unique} unique matches remain.")
    else:
        print("❌ Even after KNJV corrections, significant unique Tier 1 content remains.")
        print(f"   {total_correctable} KNJV matches correctable, but {remaining_unique} unique matches remain.")

if __name__ == "__main__":
    analyze_knjv_corrections() 