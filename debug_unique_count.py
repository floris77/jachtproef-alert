#!/usr/bin/env python3
"""
Debug why unique match count increased after KNJV corrections
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

def debug_unique_count_logic():
    """Debug the unique count calculation"""
    tier1_matches, tier2_matches = extract_matches_from_fixed_response()
    
    print(f"Starting analysis:")
    print(f"Tier 1 matches: {len(tier1_matches)}")
    print(f"Tier 2 matches: {len(tier2_matches)}")
    
    # Step 1: Find KNJV matches
    knjv_matches = [match for match in tier1_matches if match['type'] == 'KNJV']
    print(f"\nStep 1 - KNJV matches in Tier 1: {len(knjv_matches)}")
    
    # Step 2: Find correctable KNJV matches
    correctable_matches = []
    for knjv_match in knjv_matches:
        best_score = 0
        best_match = None
        
        for t2_match in tier2_matches:
            if knjv_match['date'] == t2_match['date']:
                loc_sim = similarity(knjv_match['location'], t2_match['location'])
                org_sim = similarity(knjv_match['organizer'], t2_match['organizer'])
                combined_score = (loc_sim * 0.7) + (org_sim * 0.3)
                
                if combined_score > best_score:
                    best_score = combined_score
                    best_match = t2_match
        
        if best_score > 0.5:
            correctable_matches.append({
                'knjv_match': knjv_match,
                'tier2_match': best_match,
                'score': best_score
            })
    
    print(f"Step 2 - Correctable KNJV matches: {len(correctable_matches)}")
    
    # Step 3: Calculate original unique matches (before KNJV correction)
    original_unique = []
    for t1_match in tier1_matches:
        has_match = False
        for t2_match in tier2_matches:
            if t1_match['date'] == t2_match['date']:
                org_sim = similarity(t1_match['organizer'], t2_match['organizer'])
                if org_sim > 0.6:
                    has_match = True
                    break
        
        if not has_match:
            original_unique.append(t1_match)
    
    print(f"Step 3 - Original unique Tier 1 matches: {len(original_unique)}")
    
    # Step 4: Calculate unique matches AFTER KNJV correction
    # Remove correctable KNJV matches from consideration
    correctable_knjv_set = set()
    for correction in correctable_matches:
        knjv = correction['knjv_match']
        # Create unique identifier for the match
        match_id = f"{knjv['date']}|{knjv['organizer']}|{knjv['location']}"
        correctable_knjv_set.add(match_id)
    
    print(f"Step 4 - Correctable KNJV matches to exclude: {len(correctable_knjv_set)}")
    
    # Find unique matches excluding correctable KNJV
    unique_after_correction = []
    for t1_match in tier1_matches:
        # Check if this is a correctable KNJV match
        match_id = f"{t1_match['date']}|{t1_match['organizer']}|{t1_match['location']}"
        if match_id in correctable_knjv_set:
            print(f"  Excluding correctable KNJV: {t1_match['date']} | {t1_match['organizer']}")
            continue  # Skip this match as it's correctable
        
        # Check if it has a match in Tier 2
        has_match = False
        for t2_match in tier2_matches:
            if t1_match['date'] == t2_match['date']:
                org_sim = similarity(t1_match['organizer'], t2_match['organizer'])
                if org_sim > 0.6:
                    has_match = True
                    break
        
        if not has_match:
            unique_after_correction.append(t1_match)
    
    print(f"Step 5 - Unique matches after KNJV correction: {len(unique_after_correction)}")
    
    # Debug: Show the math
    print(f"\n🔍 DEBUGGING THE MATH:")
    print("=" * 50)
    print(f"Original Tier 1 matches: {len(tier1_matches)}")
    print(f"Original unique matches: {len(original_unique)}")
    print(f"KNJV matches: {len(knjv_matches)}")
    print(f"Correctable KNJV: {len(correctable_matches)}")
    print(f"Expected reduction: {len(correctable_matches)}")
    print(f"Expected unique after correction: {len(original_unique)} - {len(correctable_matches)} = {len(original_unique) - len(correctable_matches)}")
    print(f"Actual unique after correction: {len(unique_after_correction)}")
    print(f"Difference: {len(unique_after_correction) - (len(original_unique) - len(correctable_matches))}")
    
    # Find what's causing the discrepancy
    print(f"\n🔍 ANALYZING THE DISCREPANCY:")
    print("=" * 50)
    
    # Check if correctable KNJV matches were actually in the original unique list
    correctable_knjv_in_original_unique = 0
    for correction in correctable_matches:
        knjv = correction['knjv_match']
        match_id = f"{knjv['date']}|{knjv['organizer']}|{knjv['location']}"
        
        for orig_unique in original_unique:
            orig_id = f"{orig_unique['date']}|{orig_unique['organizer']}|{orig_unique['location']}"
            if match_id == orig_id:
                correctable_knjv_in_original_unique += 1
                break
    
    print(f"Correctable KNJV matches that were in original unique list: {correctable_knjv_in_original_unique}")
    print(f"This should equal the reduction we expect: {len(correctable_matches)}")
    
    if correctable_knjv_in_original_unique != len(correctable_matches):
        print(f"⚠️ ISSUE: Some correctable KNJV matches were NOT in the original unique list!")
        print("This means they already had matches in Tier 2, so correcting them doesn't reduce unique count.")

if __name__ == "__main__":
    debug_unique_count_logic() 