#!/usr/bin/env python3
"""
Show the actual unique matches to debug what's really happening
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
    
    return matches

def show_unique_matches_detail():
    """Show detailed breakdown of what's considered unique"""
    tier1_matches, tier2_matches = extract_matches_from_fixed_response()
    
    print(f"Analyzing {len(tier1_matches)} Tier 1 matches vs {len(tier2_matches)} Tier 2 matches")
    print("=" * 80)
    
    # Find correctable KNJV matches first
    knjv_matches = [match for match in tier1_matches if match['type'] == 'KNJV']
    correctable_knjv_set = set()
    
    for knjv_match in knjv_matches:
        best_score = 0
        for t2_match in tier2_matches:
            if knjv_match['date'] == t2_match['date']:
                loc_sim = similarity(knjv_match['location'], t2_match['location'])
                org_sim = similarity(knjv_match['organizer'], t2_match['organizer'])
                combined_score = (loc_sim * 0.7) + (org_sim * 0.3)
                if combined_score > best_score:
                    best_score = combined_score
        
        if best_score > 0.5:
            match_id = f"{knjv_match['date']}|{knjv_match['organizer']}|{knjv_match['location']}"
            correctable_knjv_set.add(match_id)
    
    # Now find all unique matches
    unique_matches = []
    matched_pairs = []
    
    for i, t1_match in enumerate(tier1_matches):
        # Skip correctable KNJV matches
        match_id = f"{t1_match['date']}|{t1_match['organizer']}|{t1_match['location']}"
        if match_id in correctable_knjv_set:
            continue
        
        # Find best match in Tier 2
        best_match = None
        best_similarity = 0
        
        for t2_match in tier2_matches:
            if t1_match['date'] == t2_match['date']:
                org_sim = similarity(t1_match['organizer'], t2_match['organizer'])
                if org_sim > best_similarity:
                    best_similarity = org_sim
                    best_match = t2_match
        
        if best_similarity > 0.6:
            matched_pairs.append({
                'tier1': t1_match,
                'tier2': best_match,
                'similarity': best_similarity
            })
        else:
            unique_matches.append({
                'match': t1_match,
                'best_tier2_match': best_match,
                'best_similarity': best_similarity
            })
    
    print(f"RESULTS:")
    print(f"Matched pairs: {len(matched_pairs)}")
    print(f"Unique Tier 1 matches: {len(unique_matches)}")
    print(f"Correctable KNJV excluded: {len(correctable_knjv_set)}")
    
    # Show sample of unique matches with their best Tier 2 candidates
    print(f"\n🔍 SAMPLE UNIQUE TIER 1 MATCHES (first 20):")
    print("=" * 80)
    
    for i, unique in enumerate(unique_matches[:20]):
        t1 = unique['match']
        t2 = unique['best_tier2_match']
        sim = unique['best_similarity']
        
        print(f"\n{i+1}. UNIQUE TIER 1:")
        print(f"   Date: {t1['date']}")
        print(f"   Organizer: {t1['organizer']}")
        print(f"   Location: {t1['location']}")
        print(f"   Type: {t1['type']}")
        
        if t2:
            print(f"   Best Tier 2 candidate (sim: {sim:.2f}):")
            print(f"   → Date: {t2['date']}")
            print(f"   → Organizer: {t2['organizer']}")
            print(f"   → Type: {t2['type']}")
        else:
            print(f"   No Tier 2 match found for this date")
    
    # Show some matched pairs for comparison
    print(f"\n✅ SAMPLE MATCHED PAIRS (first 10):")
    print("=" * 80)
    
    for i, pair in enumerate(matched_pairs[:10]):
        t1 = pair['tier1']
        t2 = pair['tier2']
        sim = pair['similarity']
        
        print(f"\n{i+1}. MATCHED PAIR (sim: {sim:.2f}):")
        print(f"   T1: {t1['date']} | {t1['organizer']} | {t1['type']}")
        print(f"   T2: {t2['date']} | {t2['organizer']} | {t2['type']}")
    
    # Analyze the types of unique matches
    print(f"\n📊 BREAKDOWN OF UNIQUE MATCH TYPES:")
    print("=" * 80)
    
    type_counts = {}
    for unique in unique_matches:
        match_type = unique['match']['type']
        type_counts[match_type] = type_counts.get(match_type, 0) + 1
    
    for match_type, count in sorted(type_counts.items(), key=lambda x: x[1], reverse=True):
        print(f"{match_type}: {count} matches")
    
    # Look for patterns in the unique matches
    print(f"\n🔍 ANALYZING PATTERNS IN UNIQUE MATCHES:")
    print("=" * 80)
    
    empty_organizers = sum(1 for u in unique_matches if not u['match']['organizer'].strip())
    print(f"Matches with empty organizers: {empty_organizers}")
    
    # Check for specific problematic patterns
    problematic_patterns = 0
    for unique in unique_matches:
        organizer = unique['match']['organizer'].strip()
        if not organizer or organizer in ['', ' ', '\\', '\\ ']:
            problematic_patterns += 1
    
    print(f"Matches with problematic organizer data: {problematic_patterns}")

if __name__ == "__main__":
    show_unique_matches_detail() 