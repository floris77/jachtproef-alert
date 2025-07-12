#!/usr/bin/env python3
"""
Analyze the remaining 29 "unique" matches after filtering out obvious parsing errors
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

def clean_text(text):
    """Clean text by removing escape characters and normalizing whitespace"""
    if not text:
        return ""
    
    # Remove escape characters
    text = text.replace('\\', '')
    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text)
    # Remove common parsing artifacts
    text = re.sub(r'Aanvang:.*$', '', text)
    return text.strip()

def is_problematic_match(match):
    """Check if a match has data quality issues"""
    organizer = clean_text(match['organizer'])
    location = clean_text(match['location'])
    match_type = clean_text(match['type'])
    
    # Check for empty critical fields
    if not organizer and not location:
        return True, "Empty organizer and location"
    
    # Check for very short or meaningless data
    if len(organizer) < 3 and len(location) < 3:
        return True, "Very short organizer and location"
    
    # Check for common parsing artifacts
    if organizer in ['', ' ', '\\', '\\ '] or location in ['', ' ', '\\', '\\ ']:
        return True, "Parsing artifacts in organizer/location"
    
    # Check for malformed dates in location (common parsing error)
    if re.search(r'\d{4}-\d{2}-\d{2}', location):
        return True, "Date found in location field"
    
    return False, ""

def analyze_remaining_matches():
    """Analyze what the remaining matches actually are"""
    tier1_matches, tier2_matches = extract_matches_from_fixed_response()
    
    print(f"📊 Starting with {len(tier1_matches)} Tier 1 matches vs {len(tier2_matches)} Tier 2 matches")
    print("=" * 80)
    
    # First, filter out correctable KNJV matches
    knjv_matches = [match for match in tier1_matches if clean_text(match['type']) == 'KNJV']
    correctable_knjv_set = set()
    
    for knjv_match in knjv_matches:
        best_score = 0
        for t2_match in tier2_matches:
            if knjv_match['date'] == t2_match['date']:
                loc_sim = similarity(clean_text(knjv_match['location']), clean_text(t2_match['location']))
                org_sim = similarity(clean_text(knjv_match['organizer']), clean_text(t2_match['organizer']))
                combined_score = (loc_sim * 0.7) + (org_sim * 0.3)
                if combined_score > best_score:
                    best_score = combined_score
        
        if best_score > 0.5:
            match_id = f"{knjv_match['date']}|{knjv_match['organizer']}|{knjv_match['location']}"
            correctable_knjv_set.add(match_id)
    
    print(f"🔧 Found {len(correctable_knjv_set)} correctable KNJV matches")
    
    # Now categorize all Tier 1 matches
    problematic_matches = []
    clean_unique_matches = []
    matched_pairs = []
    
    for t1_match in tier1_matches:
        # Skip correctable KNJV matches
        match_id = f"{t1_match['date']}|{t1_match['organizer']}|{t1_match['location']}"
        if match_id in correctable_knjv_set:
            continue
        
        # Check if this match has data quality issues
        is_problematic, reason = is_problematic_match(t1_match)
        if is_problematic:
            problematic_matches.append({
                'match': t1_match,
                'reason': reason
            })
            continue
        
        # Find best match in Tier 2
        best_match = None
        best_similarity = 0
        
        for t2_match in tier2_matches:
            if t1_match['date'] == t2_match['date']:
                org_sim = similarity(clean_text(t1_match['organizer']), clean_text(t2_match['organizer']))
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
            clean_unique_matches.append({
                'match': t1_match,
                'best_tier2_match': best_match,
                'best_similarity': best_similarity
            })
    
    print(f"\n📊 ANALYSIS RESULTS:")
    print(f"Correctable KNJV matches: {len(correctable_knjv_set)}")
    print(f"Problematic matches (data quality issues): {len(problematic_matches)}")
    print(f"Clean matched pairs: {len(matched_pairs)}")
    print(f"Clean unique matches: {len(clean_unique_matches)}")
    print(f"Total accounted for: {len(correctable_knjv_set) + len(problematic_matches) + len(matched_pairs) + len(clean_unique_matches)}")
    
    # Show problematic matches
    print(f"\n🚨 PROBLEMATIC MATCHES (first 20):")
    print("=" * 80)
    
    for i, prob in enumerate(problematic_matches[:20]):
        match = prob['match']
        reason = prob['reason']
        print(f"\n{i+1}. PROBLEMATIC ({reason}):")
        print(f"   Date: {match['date']}")
        print(f"   Organizer: '{match['organizer']}'")
        print(f"   Location: '{match['location']}'")
        print(f"   Type: '{match['type']}'")
    
    # Show the clean unique matches - these are the real ones to investigate
    print(f"\n✨ CLEAN UNIQUE MATCHES (these are the real ones):")
    print("=" * 80)
    
    for i, unique in enumerate(clean_unique_matches):
        t1 = unique['match']
        t2 = unique['best_tier2_match']
        sim = unique['best_similarity']
        
        print(f"\n{i+1}. CLEAN UNIQUE:")
        print(f"   Date: {t1['date']}")
        print(f"   Organizer: {clean_text(t1['organizer'])}")
        print(f"   Location: {clean_text(t1['location'])}")
        print(f"   Type: {clean_text(t1['type'])}")
        
        if t2:
            print(f"   Best Tier 2 candidate (sim: {sim:.2f}):")
            print(f"   → Organizer: {clean_text(t2['organizer'])}")
            print(f"   → Type: {clean_text(t2['type'])}")
        else:
            print(f"   No Tier 2 match found for this date")
    
    # Analyze the clean unique matches
    print(f"\n📊 CLEAN UNIQUE MATCH TYPES:")
    print("=" * 80)
    
    type_counts = {}
    for unique in clean_unique_matches:
        match_type = clean_text(unique['match']['type'])
        type_counts[match_type] = type_counts.get(match_type, 0) + 1
    
    for match_type, count in sorted(type_counts.items(), key=lambda x: x[1], reverse=True):
        print(f"{match_type}: {count} matches")
    
    print(f"\n🎯 SUMMARY:")
    print(f"Out of {len(tier1_matches)} Tier 1 matches:")
    print(f"- {len(correctable_knjv_set)} are correctable KNJV matches")
    print(f"- {len(problematic_matches)} have data quality issues")
    print(f"- {len(matched_pairs)} match cleanly with Tier 2")
    print(f"- {len(clean_unique_matches)} are genuinely unique and clean")
    
    return clean_unique_matches

if __name__ == "__main__":
    analyze_remaining_matches() 