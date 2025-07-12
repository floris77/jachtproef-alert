#!/usr/bin/env python3
"""
Final honest analysis: Are there ANY truly unique matches in Tier 1?
Or is it all just data corruption and parsing errors?
"""

import re
from datetime import datetime
from difflib import SequenceMatcher

def similarity(a, b):
    """Calculate similarity between two strings"""
    if not a or not b:
        return 0
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()

def extract_and_clean_data():
    """Extract data and attempt to clean the field mapping issues"""
    
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
    
    # Extract matches with regex
    tier1_matches = re.findall(r'\\"date\\":\s*\\"([^"]*)\\"[^}]*?\\"organizer\\":\s*\\"([^"]*)\\"[^}]*?\\"location\\":\s*\\"([^"]*)\\"[^}]*?\\"type\\":\s*\\"([^"]*)\\"', tier1_section)
    tier2_matches = re.findall(r'\\"date\\":\s*\\"([^"]*)\\"[^}]*?\\"organizer\\":\s*\\"([^"]*)\\"[^}]*?\\"location\\":\s*\\"([^"]*)\\"[^}]*?\\"type\\":\s*\\"([^"]*)\\"', tier2_section)
    
    # Convert to dictionaries
    tier1_data = []
    for match in tier1_matches:
        date, organizer, location, match_type = match
        tier1_data.append({
            'date': date,
            'organizer': organizer,
            'location': location,
            'type': match_type,
            'source': 'tier1'
        })
    
    tier2_data = []
    for match in tier2_matches:
        date, organizer, location, match_type = match
        tier2_data.append({
            'date': date,
            'organizer': organizer,
            'location': location,
            'type': match_type,
            'source': 'tier2'
        })
    
    return tier1_data, tier2_data

def clean_text(text):
    """Clean text by removing escape characters and normalizing whitespace"""
    if not text:
        return ""
    
    # Remove escape characters
    text = text.replace('\\', '')
    # Remove unicode artifacts
    text = re.sub(r'u00[a-fA-F0-9]{2}', '', text)
    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text)
    # Remove common parsing artifacts
    text = re.sub(r'Aanvang:.*$', '', text)
    # Remove email artifacts
    text = re.sub(r'\[email.*?protected\]', '', text)
    return text.strip()

def is_corrupted_match(match):
    """Check if a match has obvious data corruption"""
    organizer = clean_text(match['organizer'])
    location = clean_text(match['location'])
    match_type = clean_text(match['type'])
    
    corruption_indicators = []
    
    # Check for empty critical fields
    if not organizer and not location:
        corruption_indicators.append("Empty organizer and location")
    
    # Check for field mapping issues
    if re.search(r'(MAP|KNJV|veldwedstrijd|TAP)', organizer):
        corruption_indicators.append("Match type in organizer field")
    
    if re.search(r'(Stichting|Vereniging|Club)', match_type):
        corruption_indicators.append("Organization name in type field")
    
    # Check for very short or meaningless data
    if len(organizer) < 3 and len(location) < 3:
        corruption_indicators.append("Very short organizer and location")
    
    # Check for common parsing artifacts
    if organizer in ['', ' ', '\\', '\\ '] or location in ['', ' ', '\\', '\\ ']:
        corruption_indicators.append("Parsing artifacts")
    
    # Check for malformed dates in location
    if re.search(r'\d{4}-\d{2}-\d{2}', location):
        corruption_indicators.append("Date found in location field")
    
    return len(corruption_indicators) > 0, corruption_indicators

def comprehensive_date_location_matching(t1_matches, t2_matches):
    """Match by date and location similarity - most reliable approach"""
    
    matches_found = []
    
    for t1_match in t1_matches:
        t1_date = t1_match['date']
        t1_location = clean_text(t1_match['location'])
        
        for t2_match in t2_matches:
            t2_date = t2_match['date']
            t2_location = clean_text(t2_match['location'])
            
            # Same date
            if t1_date == t2_date:
                # Check location similarity
                loc_sim = similarity(t1_location, t2_location)
                
                # Also check if locations contain same city names
                t1_words = set(word.lower() for word in t1_location.split() if len(word) > 3)
                t2_words = set(word.lower() for word in t2_location.split() if len(word) > 3)
                word_overlap = len(t1_words & t2_words)
                
                if loc_sim > 0.6 or word_overlap > 0:
                    matches_found.append({
                        'tier1': t1_match,
                        'tier2': t2_match,
                        'location_similarity': loc_sim,
                        'word_overlap': word_overlap,
                        'confidence': 'high' if loc_sim > 0.8 or word_overlap > 1 else 'medium'
                    })
    
    return matches_found

def final_honest_analysis():
    """Final honest analysis of the data"""
    
    print("🔍 FINAL HONEST ANALYSIS")
    print("=" * 80)
    print("Question: Are there ANY truly unique matches in Tier 1?")
    print("Or is it all just data corruption and parsing errors?")
    print("=" * 80)
    
    tier1_matches, tier2_matches = extract_and_clean_data()
    
    print(f"\n📊 RAW DATA COUNTS:")
    print(f"Tier 1 matches: {len(tier1_matches)}")
    print(f"Tier 2 matches: {len(tier2_matches)}")
    
    # Step 1: Identify corrupted matches
    print(f"\n🔍 STEP 1: IDENTIFYING CORRUPTED MATCHES")
    print("=" * 50)
    
    corrupted_t1_matches = []
    clean_t1_matches = []
    
    for match in tier1_matches:
        is_corrupted, issues = is_corrupted_match(match)
        if is_corrupted:
            corrupted_t1_matches.append({
                'match': match,
                'issues': issues
            })
        else:
            clean_t1_matches.append(match)
    
    print(f"Corrupted Tier 1 matches: {len(corrupted_t1_matches)}")
    print(f"Clean Tier 1 matches: {len(clean_t1_matches)}")
    
    # Show some corrupted examples
    print(f"\nSample corrupted matches:")
    for i, corrupted in enumerate(corrupted_t1_matches[:5]):
        match = corrupted['match']
        issues = corrupted['issues']
        print(f"{i+1}. {match['date']} | Issues: {', '.join(issues)}")
        print(f"   Organizer: '{clean_text(match['organizer'])}'")
        print(f"   Location: '{clean_text(match['location'])}'")
        print(f"   Type: '{clean_text(match['type'])}'")
    
    # Step 2: Match clean Tier 1 matches with Tier 2
    print(f"\n🔍 STEP 2: MATCHING CLEAN TIER 1 WITH TIER 2")
    print("=" * 50)
    
    found_matches = comprehensive_date_location_matching(clean_t1_matches, tier2_matches)
    
    print(f"Matches found between clean Tier 1 and Tier 2: {len(found_matches)}")
    
    # Step 3: Identify truly unique matches
    matched_t1_dates = set()
    for match in found_matches:
        matched_t1_dates.add(match['tier1']['date'] + "|" + clean_text(match['tier1']['location']))
    
    truly_unique = []
    for match in clean_t1_matches:
        match_key = match['date'] + "|" + clean_text(match['location'])
        if match_key not in matched_t1_dates:
            truly_unique.append(match)
    
    print(f"Truly unique Tier 1 matches: {len(truly_unique)}")
    
    # Step 4: Analyze the "unique" matches
    print(f"\n🔍 STEP 3: ANALYZING 'UNIQUE' MATCHES")
    print("=" * 50)
    
    if len(truly_unique) == 0:
        print("✅ NO TRULY UNIQUE MATCHES FOUND!")
        print("All clean Tier 1 matches have corresponding Tier 2 matches.")
        print("Conclusion: Tier 1 provides no additional unique content.")
    else:
        print(f"Found {len(truly_unique)} potentially unique matches:")
        
        for i, match in enumerate(truly_unique):
            print(f"\n{i+1}. UNIQUE MATCH:")
            print(f"   Date: {match['date']}")
            print(f"   Organizer: {clean_text(match['organizer'])}")
            print(f"   Location: {clean_text(match['location'])}")
            print(f"   Type: {clean_text(match['type'])}")
            
            # Double-check by looking for any Tier 2 matches on same date
            same_date_t2 = [t2 for t2 in tier2_matches if t2['date'] == match['date']]
            if same_date_t2:
                print(f"   ⚠️  Found {len(same_date_t2)} Tier 2 matches on same date:")
                for t2_match in same_date_t2:
                    print(f"      - {clean_text(t2_match['organizer'])} at {clean_text(t2_match['location'])}")
    
    # Step 5: Final summary
    print(f"\n🎯 FINAL HONEST CONCLUSION")
    print("=" * 50)
    
    total_t1 = len(tier1_matches)
    corrupted_count = len(corrupted_t1_matches)
    clean_count = len(clean_t1_matches)
    matched_count = len(found_matches)
    unique_count = len(truly_unique)
    
    print(f"Total Tier 1 matches: {total_t1}")
    print(f"├── Corrupted/parsing errors: {corrupted_count} ({corrupted_count/total_t1*100:.1f}%)")
    print(f"├── Clean matches: {clean_count} ({clean_count/total_t1*100:.1f}%)")
    print(f"    ├── Matched with Tier 2: {matched_count} ({matched_count/clean_count*100:.1f}% of clean)")
    print(f"    └── Truly unique: {unique_count} ({unique_count/clean_count*100:.1f}% of clean)")
    
    if unique_count == 0:
        print(f"\n✅ VERDICT: NO UNIQUE CONTENT IN TIER 1")
        print(f"Tier 1 is just a corrupted/incomplete version of Tier 2 data.")
        print(f"Recommendation: Use Tier 2 only.")
    else:
        print(f"\n⚠️  VERDICT: {unique_count} POTENTIALLY UNIQUE MATCHES")
        print(f"Need manual verification to confirm these are legitimate unique events.")
    
    return truly_unique, found_matches, corrupted_t1_matches

if __name__ == "__main__":
    final_honest_analysis() 