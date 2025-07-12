#!/usr/bin/env python3
"""
Analyze if Tier 1 has any unique matches not found in Tier 2
"""

import csv
import re
from datetime import datetime
from difflib import SequenceMatcher

def similarity(a, b):
    """Calculate similarity between two strings"""
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

def find_tier1_unique_matches():
    """Find matches that exist in Tier 1 but not in Tier 2"""
    tier1_matches, tier2_matches = extract_matches_from_fixed_response()
    
    print(f"\nAnalyzing coverage:")
    print(f"Tier 1 matches: {len(tier1_matches)}")
    print(f"Tier 2 matches: {len(tier2_matches)}")
    
    # Find Tier 1 matches that don't have a close match in Tier 2
    tier1_unique = []
    tier1_matched = []
    
    for t1_match in tier1_matches:
        best_match = None
        best_similarity = 0
        
        for t2_match in tier2_matches:
            # Check if dates match
            if t1_match['date'] == t2_match['date']:
                # Calculate organizer similarity
                org_sim = similarity(t1_match['organizer'], t2_match['organizer'])
                
                if org_sim > best_similarity:
                    best_similarity = org_sim
                    best_match = t2_match
        
        # Consider it a match if similarity > 0.6
        if best_similarity > 0.6:
            tier1_matched.append({
                'tier1': t1_match,
                'tier2': best_match,
                'similarity': best_similarity
            })
        else:
            tier1_unique.append(t1_match)
    
    print(f"\nResults:")
    print(f"Tier 1 matches with Tier 2 counterparts: {len(tier1_matched)}")
    print(f"Tier 1 unique matches (no Tier 2 counterpart): {len(tier1_unique)}")
    
    # Show unique Tier 1 matches
    if tier1_unique:
        print(f"\n🔍 UNIQUE TIER 1 MATCHES (not found in Tier 2):")
        print("=" * 60)
        for i, match in enumerate(tier1_unique[:20]):  # Show first 20
            print(f"{i+1}. {match['date']} | {match['organizer']} | {match['type']}")
    else:
        print(f"\n✅ NO UNIQUE TIER 1 MATCHES - All Tier 1 matches have Tier 2 counterparts!")
    
    # Show some examples of matched pairs
    print(f"\n📋 SAMPLE MATCHED PAIRS:")
    print("=" * 60)
    for i, pair in enumerate(tier1_matched[:5]):
        print(f"\nPair {i+1} (Similarity: {pair['similarity']:.2f}):")
        print(f"  Tier 1: {pair['tier1']['date']} | {pair['tier1']['organizer']} | {pair['tier1']['type']}")
        print(f"  Tier 2: {pair['tier2']['date']} | {pair['tier2']['organizer']} | {pair['tier2']['type']}")
    
    # Analyze Tier 2 coverage by calendar type
    print(f"\n📊 TIER 2 BREAKDOWN BY CALENDAR TYPE:")
    print("=" * 60)
    calendar_counts = {}
    for match in tier2_matches:
        cal_type = match.get('calendar_type', 'Unknown')
        calendar_counts[cal_type] = calendar_counts.get(cal_type, 0) + 1
    
    for cal_type, count in calendar_counts.items():
        print(f"{cal_type}: {count} matches")
    
    # Final recommendation
    print(f"\n🎯 RECOMMENDATION:")
    print("=" * 60)
    if len(tier1_unique) == 0:
        print("✅ You can SOLELY rely on Tier 2 for scraping!")
        print("   All Tier 1 matches have counterparts in Tier 2.")
        print("   Tier 2 provides more detailed match types.")
    elif len(tier1_unique) < 10:
        print("⚠️  Tier 2 covers most matches, but there are a few unique Tier 1 matches.")
        print(f"   Consider keeping both, or investigate the {len(tier1_unique)} unique matches.")
    else:
        print("❌ Tier 1 has significant unique content - keep both tiers.")
        print(f"   {len(tier1_unique)} matches are only available in Tier 1.")

if __name__ == "__main__":
    find_tier1_unique_matches() 