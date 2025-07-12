#!/usr/bin/env python3
"""
Local analysis script to compare Tier 1 and Tier 2 data
"""

import requests
import json
from datetime import datetime

def analyze_scraper_data():
    """Analyze the data from the deployed scraper"""
    
    print("🔍 DATA STRUCTURE ANALYSIS")
    print("="*60)
    
    # Let's create a simple test with sample data
    print("SAMPLE COMPARISON TEST:")
    print("-" * 40)
    
    # Sample Tier 1 data (what we expect from public calendar)
    sample_tier1 = [
        {"date": "2025-12-01", "organizer": "Jachtvereniging Amsterdam", "type": "veldwedstrijd"},
        {"date": "2025-12-01", "organizer": "KNJV Noord-Holland", "type": "veldwedstrijd"},
        {"date": "2025-12-08", "organizer": "PJP Gelderland", "type": "veldwedstrijd"}
    ]
    
    # Sample Tier 2 data (what we expect from protected calendars)
    sample_tier2 = [
        {"date": "2025-12-01", "organizer": "Jachtvereniging Amsterdam", "type": "MAP"},
        {"date": "2025-12-01", "organizer": "KNJV Noord-Holland", "type": "KNJV"},
        {"date": "2025-12-08", "organizer": "PJP Gelderland", "type": "PJP"}
    ]
    
    print("TIER 1 SAMPLE (Public Calendar):")
    for i, match in enumerate(sample_tier1):
        print(f"  {i+1}. {match['date']} | {match['organizer']} | {match['type']}")
    
    print("\nTIER 2 SAMPLE (Protected Calendars):")
    for i, match in enumerate(sample_tier2):
        print(f"  {i+1}. {match['date']} | {match['organizer']} | {match['type']}")
    
    # Test similarity function
    def similarity(s1, s2):
        """Simple similarity function"""
        if not s1 or not s2:
            return 0
        s1, s2 = s1.lower(), s2.lower()
        if s1 == s2:
            return 1.0
        # Simple character-based similarity
        common = sum(1 for c in s1 if c in s2)
        total = max(len(s1), len(s2))
        return common / total if total > 0 else 0
    
    print("\nSIMILARITY TEST (50% threshold):")
    print("-" * 40)
    matches_found = 0
    for t1 in sample_tier1:
        for t2 in sample_tier2:
            if t1['date'] == t2['date']:
                sim = similarity(t1['organizer'], t2['organizer'])
                status = "✅ MATCH" if sim > 0.5 else "❌ NO MATCH"
                print(f"{status} '{t1['organizer']}' <-> '{t2['organizer']}' = {sim:.3f}")
                if sim > 0.5:
                    matches_found += 1
    
    print(f"\nMatches found: {matches_found}/{len(sample_tier1)}")
    
    print("\n" + "="*60)
    print("POTENTIAL ISSUES IDENTIFIED")
    print("="*60)
    print("1. HTML encoding differences in organizer names")
    print("2. Extra whitespace or special characters")
    print("3. Abbreviations vs full names")
    print("4. Similarity threshold too high (50%)")
    print("5. Different text normalization between tiers")
    
    print("\nRECOMMENDED FIXES")
    print("="*60)
    print("1. Lower similarity threshold to 30%")
    print("2. Improve text normalization (remove HTML, extra spaces)")
    print("3. Add fuzzy matching algorithms")
    print("4. Handle common abbreviations")
    print("5. Add manual override for critical matches")

if __name__ == "__main__":
    analyze_scraper_data() 