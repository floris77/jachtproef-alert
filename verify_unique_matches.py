#!/usr/bin/env python3
"""
Comprehensive verification of the 25 "unique" matches
Using multiple matching strategies to prove if they're truly unique
"""

import csv
import re
from datetime import datetime, timedelta
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

def extract_location_keywords(location):
    """Extract key location words for matching"""
    location = clean_text(location)
    # Remove common address parts
    location = re.sub(r'\d{4}\s*[A-Z]{2}', '', location)  # Remove postal codes
    location = re.sub(r'\d+', '', location)  # Remove house numbers
    # Split into words and filter meaningful ones
    words = [word for word in location.split() if len(word) > 3]
    return words

def extract_organizer_keywords(organizer):
    """Extract key organizer words for matching"""
    organizer = clean_text(organizer)
    # Remove common words
    common_words = ['stichting', 'vereniging', 'club', 'nederlandse', 'provincie', 'i.s.m', 'afd']
    words = organizer.lower().split()
    keywords = [word for word in words if word not in common_words and len(word) > 3]
    return keywords

def comprehensive_match_check(t1_match, t2_matches):
    """Comprehensive matching using multiple strategies"""
    results = []
    
    t1_date = t1_match['date']
    t1_org_clean = clean_text(t1_match['organizer'])
    t1_loc_clean = clean_text(t1_match['location'])
    t1_type_clean = clean_text(t1_match['type'])
    
    for t2_match in t2_matches:
        t2_date = t2_match['date']
        t2_org_clean = clean_text(t2_match['organizer'])
        t2_loc_clean = clean_text(t2_match['location'])
        t2_type_clean = clean_text(t2_match['type'])
        
        # Strategy 1: Exact date match + organizer similarity
        if t1_date == t2_date:
            org_sim = similarity(t1_org_clean, t2_org_clean)
            loc_sim = similarity(t1_loc_clean, t2_loc_clean)
            
            results.append({
                'strategy': 'Same Date + Organizer',
                'tier2_match': t2_match,
                'org_similarity': org_sim,
                'loc_similarity': loc_sim,
                'combined_score': (org_sim * 0.7) + (loc_sim * 0.3),
                'details': f"Org: {org_sim:.2f}, Loc: {loc_sim:.2f}"
            })
        
        # Strategy 2: Date range (±1 day) + high organizer similarity
        try:
            date1 = datetime.strptime(t1_date, '%Y-%m-%d')
            date2 = datetime.strptime(t2_date, '%Y-%m-%d')
            date_diff = abs((date1 - date2).days)
            
            if date_diff <= 1:
                org_sim = similarity(t1_org_clean, t2_org_clean)
                if org_sim > 0.7:
                    results.append({
                        'strategy': 'Date Range (±1) + High Org Sim',
                        'tier2_match': t2_match,
                        'org_similarity': org_sim,
                        'loc_similarity': similarity(t1_loc_clean, t2_loc_clean),
                        'combined_score': org_sim,
                        'details': f"Date diff: {date_diff} days, Org: {org_sim:.2f}"
                    })
        except:
            pass
        
        # Strategy 3: Keyword matching
        if t1_date == t2_date:
            t1_org_keywords = extract_organizer_keywords(t1_org_clean)
            t2_org_keywords = extract_organizer_keywords(t2_org_clean)
            t1_loc_keywords = extract_location_keywords(t1_loc_clean)
            t2_loc_keywords = extract_location_keywords(t2_loc_clean)
            
            # Check for keyword overlap
            org_overlap = len(set(t1_org_keywords) & set(t2_org_keywords))
            loc_overlap = len(set(t1_loc_keywords) & set(t2_loc_keywords))
            
            if org_overlap > 0 or loc_overlap > 0:
                keyword_score = (org_overlap * 0.7) + (loc_overlap * 0.3)
                results.append({
                    'strategy': 'Keyword Matching',
                    'tier2_match': t2_match,
                    'org_similarity': org_overlap,
                    'loc_similarity': loc_overlap,
                    'combined_score': keyword_score,
                    'details': f"Org keywords: {org_overlap}, Loc keywords: {loc_overlap}"
                })
        
        # Strategy 4: Location-focused matching (for cases where organizer is different but location is same)
        if t1_date == t2_date:
            loc_sim = similarity(t1_loc_clean, t2_loc_clean)
            if loc_sim > 0.8:  # Very high location similarity
                results.append({
                    'strategy': 'High Location Similarity',
                    'tier2_match': t2_match,
                    'org_similarity': similarity(t1_org_clean, t2_org_clean),
                    'loc_similarity': loc_sim,
                    'combined_score': loc_sim,
                    'details': f"Location match: {loc_sim:.2f}"
                })
    
    # Sort by combined score
    results.sort(key=lambda x: x['combined_score'], reverse=True)
    return results

def verify_unique_matches():
    """Verify if the 25 unique matches are truly unique"""
    tier1_matches, tier2_matches = extract_matches_from_fixed_response()
    
    print(f"🔍 COMPREHENSIVE VERIFICATION OF 25 'UNIQUE' MATCHES")
    print("=" * 80)
    
    # Get the 25 clean unique matches using same logic as before
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
    
    def is_problematic_match(match):
        organizer = clean_text(match['organizer'])
        location = clean_text(match['location'])
        
        if not organizer and not location:
            return True
        if len(organizer) < 3 and len(location) < 3:
            return True
        if organizer in ['', ' ', '\\', '\\ '] or location in ['', ' ', '\\', '\\ ']:
            return True
        if re.search(r'\d{4}-\d{2}-\d{2}', location):
            return True
        return False
    
    clean_unique_matches = []
    
    for t1_match in tier1_matches:
        # Skip correctable KNJV matches
        match_id = f"{t1_match['date']}|{t1_match['organizer']}|{t1_match['location']}"
        if match_id in correctable_knjv_set:
            continue
        
        # Skip problematic matches
        if is_problematic_match(t1_match):
            continue
        
        # Check if it matches with Tier 2 using basic algorithm
        best_match = None
        best_similarity = 0
        
        for t2_match in tier2_matches:
            if t1_match['date'] == t2_match['date']:
                org_sim = similarity(clean_text(t1_match['organizer']), clean_text(t2_match['organizer']))
                if org_sim > best_similarity:
                    best_similarity = org_sim
                    best_match = t2_match
        
        if best_similarity <= 0.6:  # Originally considered "unique"
            clean_unique_matches.append(t1_match)
    
    print(f"Found {len(clean_unique_matches)} matches to verify")
    
    # Now verify each one comprehensively
    truly_unique = []
    false_positives = []
    
    for i, t1_match in enumerate(clean_unique_matches):
        print(f"\n{'='*60}")
        print(f"VERIFYING MATCH {i+1}/25:")
        print(f"Date: {t1_match['date']}")
        print(f"Organizer: {clean_text(t1_match['organizer'])}")
        print(f"Location: {clean_text(t1_match['location'])}")
        print(f"Type: {clean_text(t1_match['type'])}")
        
        # Run comprehensive matching
        match_results = comprehensive_match_check(t1_match, tier2_matches)
        
        if not match_results:
            print("❌ NO POTENTIAL MATCHES FOUND - TRULY UNIQUE")
            truly_unique.append(t1_match)
        else:
            print(f"🔍 Found {len(match_results)} potential matches:")
            
            best_match = match_results[0]
            print(f"\nBEST MATCH:")
            print(f"Strategy: {best_match['strategy']}")
            print(f"Score: {best_match['combined_score']:.2f}")
            print(f"Details: {best_match['details']}")
            print(f"T2 Organizer: {clean_text(best_match['tier2_match']['organizer'])}")
            print(f"T2 Location: {clean_text(best_match['tier2_match']['location'])}")
            print(f"T2 Type: {clean_text(best_match['tier2_match']['type'])}")
            
            # Decision threshold
            if best_match['combined_score'] > 0.7:
                print("✅ LIKELY MATCH FOUND - FALSE POSITIVE")
                false_positives.append({
                    'tier1': t1_match,
                    'tier2': best_match['tier2_match'],
                    'score': best_match['combined_score'],
                    'strategy': best_match['strategy']
                })
            else:
                print("❌ NO STRONG MATCH - LIKELY UNIQUE")
                truly_unique.append(t1_match)
    
    print(f"\n{'='*80}")
    print(f"🎯 FINAL VERIFICATION RESULTS:")
    print(f"{'='*80}")
    print(f"Total matches verified: {len(clean_unique_matches)}")
    print(f"Truly unique matches: {len(truly_unique)}")
    print(f"False positives (actually matched): {len(false_positives)}")
    
    if false_positives:
        print(f"\n🚨 FALSE POSITIVES FOUND:")
        for i, fp in enumerate(false_positives):
            print(f"\n{i+1}. FALSE POSITIVE (Score: {fp['score']:.2f}, Strategy: {fp['strategy']}):")
            print(f"   T1: {fp['tier1']['date']} | {clean_text(fp['tier1']['organizer'])}")
            print(f"   T2: {fp['tier2']['date']} | {clean_text(fp['tier2']['organizer'])}")
    
    print(f"\n📊 PROOF OF UNIQUENESS:")
    print(f"Original claim: 25 unique matches")
    print(f"After comprehensive verification: {len(truly_unique)} truly unique matches")
    print(f"Accuracy of original analysis: {(len(truly_unique)/len(clean_unique_matches)*100):.1f}%")
    
    return truly_unique, false_positives

if __name__ == "__main__":
    verify_unique_matches() 