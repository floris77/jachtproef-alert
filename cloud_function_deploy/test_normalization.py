#!/usr/bin/env python3
"""
Test script for normalization improvements
"""

import re
import html
import unicodedata

def normalize_org(org):
    """
    Comprehensive text normalization for organizer names
    """
    if not org:
        return ""
    
    # Convert to string if needed
    org = str(org)
    
    # Remove HTML entities (like &nbsp;, &amp;, etc.)
    org = html.unescape(org)
    
    # Remove HTML tags
    org = re.sub(r'<[^>]+>', '', org)
    
    # Normalize unicode characters (handle accents, etc.)
    org = unicodedata.normalize('NFKC', org)
    
    # Remove extra whitespace and normalize
    org = re.sub(r'\s+', ' ', org)
    org = org.strip()
    
    # Convert to lowercase for comparison
    org = org.lower()
    
    # Remove common punctuation that might interfere
    org = re.sub(r'[^\w\s]', '', org)
    
    # Remove extra spaces again after punctuation removal
    org = re.sub(r'\s+', ' ', org)
    org = org.strip()
    
    return org

def similarity(s1, s2):
    """
    Improved similarity function with better text handling
    """
    if not s1 or not s2:
        return 0
    
    # Normalize both strings
    s1 = normalize_org(s1)
    s2 = normalize_org(s2)
    
    if s1 == s2:
        return 1.0
    
    # Handle common abbreviations and variations
    s1_clean = re.sub(r'\b(stichting|vereniging|jachtvereniging)\b', '', s1)
    s2_clean = re.sub(r'\b(stichting|vereniging|jachtvereniging)\b', '', s2)
    
    if s1_clean.strip() == s2_clean.strip():
        return 0.95
    
    # Simple character-based similarity for remaining cases
    common = sum(1 for c in s1 if c in s2)
    total = max(len(s1), len(s2))
    return common / total if total > 0 else 0

def test_normalization():
    """
    Test the normalization function with real-world examples
    """
    print("🧪 TESTING NORMALIZATION IMPROVEMENTS")
    print("=" * 60)
    
    test_cases = [
        ("Jachtvereniging Amsterdam", "Jachtvereniging Amsterdam"),
        ("KNJV Noord-Holland", "KNJV Noord-Holland"),
        ("PJP Gelderland", "PJP Gelderland"),
        ("Stichting Jachtvereniging", "Jachtvereniging"),
        ("&nbsp;Jachtvereniging&nbsp;", "Jachtvereniging"),
        ("Jachtvereniging (Amsterdam)", "Jachtvereniging Amsterdam"),
        ("KNJV Noord-Holland", "KNJV Noord Holland"),
        ("PJP-Gelderland", "PJP Gelderland"),
        ("Jachtvereniging Amsterdam", "Jachtvereniging Amsterdam"),
        ("KNJV Noord-Holland", "KNJV Noord-Holland"),
        ("PJP Gelderland", "PJP Gelderland"),
    ]
    
    successful_tests = 0
    total_tests = len(test_cases)
    
    for i, (org1, org2) in enumerate(test_cases):
        norm1 = normalize_org(org1)
        norm2 = normalize_org(org2)
        sim = similarity(org1, org2)
        status = "✅" if sim > 0.5 else "❌"
        if sim > 0.5:
            successful_tests += 1
        
        print(f"{status} Test {i+1}: '{org1}' <-> '{org2}'")
        print(f"     Normalized: '{norm1}' <-> '{norm2}' = {sim:.3f}")
        print()
    
    print(f"📊 RESULTS: {successful_tests}/{total_tests} tests passed")
    print(f"Success rate: {(successful_tests/total_tests)*100:.1f}%")
    
    print("\n" + "="*60)
    print("IMPROVEMENTS MADE")
    print("="*60)
    print("1. ✅ HTML entity decoding (&nbsp;, &amp;, etc.)")
    print("2. ✅ HTML tag removal")
    print("3. ✅ Unicode normalization (accents, etc.)")
    print("4. ✅ Whitespace normalization")
    print("5. ✅ Punctuation removal")
    print("6. ✅ Common abbreviation handling")
    print("7. ✅ Case-insensitive comparison")
    
    print("\nNEXT STEPS")
    print("="*60)
    print("1. Deploy to test with real scraped data")
    print("2. Monitor matching success rate")
    print("3. Add more specific abbreviation rules if needed")
    print("4. Consider fuzzy matching for edge cases")

if __name__ == "__main__":
    test_normalization() 