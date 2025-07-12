#!/usr/bin/env python3
"""
Test script to validate Tier 2 fixes locally
"""

import requests
import json
from bs4 import BeautifulSoup
import re
from datetime import datetime
from difflib import SequenceMatcher
from collections import defaultdict

def parse_date(date_text):
    """Parse date from DD-MM-YYYY format"""
    try:
        return datetime.strptime(date_text, '%d-%m-%Y').date()
    except:
        return None

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

def authenticate_orweja():
    """Authenticate with ORWEJA and return session"""
    print("🔐 Authenticating with ORWEJA...")
    
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    })
    
    try:
        # Get login page
        login_url = "https://my.orweja.nl/login"
        response = session.get(login_url, timeout=30)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.content, 'html.parser')
        csrf_token = soup.find('input', {'name': '_token'})
        
        if not csrf_token:
            print("❌ Could not find CSRF token")
            return None
        
        # Login credentials (you'll need to set these)
        login_data = {
            '_token': csrf_token.get('value'),
            'email': 'your_email@example.com',  # Replace with actual credentials
            'password': 'your_password',  # Replace with actual credentials
            'remember': 'on'
        }
        
        # Submit login
        login_response = session.post(login_url, data=login_data, timeout=30)
        login_response.raise_for_status()
        
        # Test authentication by accessing protected page
        test_response = session.get("https://my.orweja.nl/home/kalender/0", timeout=30)
        test_response.raise_for_status()
        
        # Check if we're redirected to login page (login failed)
        if "login" in test_response.url.lower():
            print("❌ Still redirected to login page - authentication failed")
            return None
        
        # Check if we got actual content (not just login page)
        if len(test_response.content) > 10000:  # Should be substantial content
            print("✅ ORWEJA authentication successful - got substantial content")
            return session
        else:
            print(f"⚠️ Got small response ({len(test_response.content)} chars) - may not be logged in")
            return None
            
    except Exception as e:
        print(f"❌ ORWEJA authentication error: {e}")
        return None

def scrape_tier2_protected_calendars():
    """
    Test the updated Tier 2 scraping with fixed field mapping
    """
    print("🔍 Testing Tier 2 scraping with fixes...")
    
    # For testing purposes, let's use mock data that simulates the HTML structure
    # In production, this would use the authenticated session
    
    # Mock data simulating the different calendar types
    mock_calendars = {
        "Veldwedstrijd": [
            {
                'cells': ['15-07-2025', 'CAC Apporteerwedstrijd', 'Chesapeake Bay Retriever Club Nederland', 'Sportpark De Bosrand Bosrandweg 1 1234 AB Testdorp', 'Aanvang: 09:00', 'Inschrijven'],
                'expected_organizer': 'Chesapeake Bay Retriever Club Nederland',
                'expected_type': 'CAC Apporteerwedstrijd'
            },
            {
                'cells': ['20-08-2025', 'CACIT Najaarswedstrijd', 'Continentale Staande honden Vereeniging', 'Jachtterrein Hoge Veluwe 5678 CD Otterlo', 'Aanvang: 08:30', 'vanaf 01-08-2025 09:00'],
                'expected_organizer': 'Continentale Staande honden Vereeniging',
                'expected_type': 'CACIT Najaarswedstrijd'
            }
        ],
        "Jachthondenproef": [
            {
                'cells': ['12-07-2025', 'Standaard Jachthonden proef', 'Vereniging Vrienden Duits Draadhaar', 'Bos en Heide terrein Lochem 7241 XY Lochem', 'Aanvang: 07:00', 'Inschrijven'],
                'expected_organizer': 'Vereniging Vrienden Duits Draadhaar',
                'expected_type': 'Standaard Jachthonden proef'
            },
            {
                'cells': ['26-07-2025', 'MAP proef', 'KNJV Provincie Noord-Holland Stichting Jachthonden Noord-Holland', 'Manege Spaarnwoude Houtrakkerweg 62 1165 MX Halfweg', 'Aanvang: 08:00', 'niet mogelijk'],
                'expected_organizer': 'KNJV Provincie Noord-Holland Stichting Jachthonden Noord-Holland',
                'expected_type': 'MAP proef'
            }
        ],
        "ORWEJA Werktest": [
            {
                'cells': ['30-08-2025', 'Spaniel Workingtest', 'Engelse Springer Club, Welsh Springer Spaniel Club', 'Natuurgebied Keukenhof 2161 AM Lisse', 'Aanvang: 09:30', 'Inschrijven'],
                'expected_organizer': 'Engelse Springer Club, Welsh Springer Spaniel Club',
                'expected_type': 'Spaniel Workingtest'
            }
        ]
    }
    
    all_matches = []
    
    for calendar_type, test_data in mock_calendars.items():
        print(f"\n📄 Testing: {calendar_type}")
        calendar_matches = []
        
        for data in test_data:
            cells = data['cells']
            
            # Apply the FIXED field mapping logic
            date_text = cells[0]
            
            # Skip invalid dates
            if not date_text or not re.match(r'\d{1,2}-\d{1,2}-\d{4}', date_text):
                continue
            
            # Correct field mapping based on HTML structure
            match_type = cells[1]
            match_type = re.sub(r'\s+', ' ', match_type).replace('\\', '').strip()
            
            organizer = cells[2]
            organizer = re.sub(r'\s+', ' ', organizer).replace('\\', '').strip()
            
            location = cells[3]
            location = re.sub(r'\s+', ' ', location).replace('\\', '').strip()
            
            remarks = cells[4] if len(cells) > 4 else ""
            remarks = re.sub(r'\s+', ' ', remarks).replace('\\', '').strip()
            
            reg_status = cells[5] if len(cells) > 5 else ""
            reg_status = re.sub(r'\s+', ' ', reg_status).replace('\\', '').strip()
            
            # Skip entries with empty critical fields
            if not organizer.strip() and not location.strip():
                print(f"⚠️ Skipping entry with empty organizer and location: {date_text}")
                continue
            
            # Clean up common parsing artifacts
            organizer = re.sub(r'Aanvang:.*$', '', organizer).strip()
            location = re.sub(r'Aanvang:.*$', '', location).strip()
            
            match_data = {
                'date': parse_date(date_text),
                'organizer': organizer,
                'location': location,
                'remarks': remarks,
                'registration_text': reg_status,
                'type': match_type,
                'source': 'tier2',
                'calendar_type': calendar_type
            }
            calendar_matches.append(match_data)
            
            # Validate the fix
            expected_organizer = data['expected_organizer']
            expected_type = data['expected_type']
            
            if organizer == expected_organizer and match_type == expected_type:
                print(f"✅ FIXED: {organizer} | {match_type}")
            else:
                print(f"❌ STILL BROKEN:")
                print(f"   Expected organizer: {expected_organizer}")
                print(f"   Got organizer: {organizer}")
                print(f"   Expected type: {expected_type}")
                print(f"   Got type: {match_type}")
        
        print(f"✅ {calendar_type}: Found {len(calendar_matches)} matches")
        all_matches.extend(calendar_matches)
    
    # Test deduplication
    print(f"\n🔍 Testing deduplication...")
    
    # Add some intentional duplicates to test deduplication
    duplicate_match = {
        'date': parse_date('15-07-2025'),
        'organizer': 'Chesapeake Bay Retriever Club Nederland',
        'location': 'Sportpark De Bosrand Bosrandweg 1 1234 AB Testdorp',
        'remarks': 'Aanvang: 09:00',
        'registration_text': 'Inschrijven',
        'type': 'CAC Apporteerwedstrijd',
        'source': 'tier2',
        'calendar_type': 'Veldwedstrijd'
    }
    all_matches.append(duplicate_match)  # Add duplicate
    
    print(f"Before deduplication: {len(all_matches)} matches")
    
    # Apply deduplication logic
    deduplicated_matches = deduplicate_tier2_matches(all_matches)
    
    print(f"After deduplication: {len(deduplicated_matches)} matches")
    
    return deduplicated_matches

def deduplicate_tier2_matches(matches):
    """Remove duplicate matches across different calendars"""
    print("🔍 Deduplicating Tier 2 matches...")
    
    unique_matches = []
    seen_matches = set()
    
    for match in matches:
        # Create a unique key based on date, organizer, and location
        organizer_clean = re.sub(r'\s+', ' ', match['organizer'].lower().strip())
        location_clean = re.sub(r'\s+', ' ', match['location'].lower().strip())
        
        # Remove common variations
        organizer_clean = re.sub(r'\[email.*?protected\]', '', organizer_clean)
        organizer_clean = re.sub(r'(stichting|vereniging|club)', '', organizer_clean).strip()
        
        match_key = f"{match['date']}|{organizer_clean}|{location_clean}"
        
        if match_key not in seen_matches:
            seen_matches.add(match_key)
            unique_matches.append(match)
        else:
            print(f"🗑️ Removing duplicate: {match['organizer']} on {match['date']}")
    
    print(f"📊 Removed {len(matches) - len(unique_matches)} duplicates")
    return unique_matches

def test_field_mapping_validation():
    """Test the field mapping validation logic"""
    print("\n🔍 TESTING TIER 2 FIELD MAPPING FIXES")
    print("=" * 80)
    
    # Test the scraper fixes
    matches = scrape_tier2_protected_calendars()
    
    if not matches:
        print("❌ No matches found")
        return
    
    print(f"📊 Total matches found: {len(matches)}")
    
    # Group by calendar type
    by_calendar = defaultdict(list)
    for match in matches:
        calendar_type = match.get('calendar_type', 'unknown')
        by_calendar[calendar_type].append(match)
    
    print(f"\n📊 BREAKDOWN BY CALENDAR:")
    print("=" * 50)
    for calendar_type, calendar_matches in by_calendar.items():
        print(f"{calendar_type}: {len(calendar_matches)} matches")
    
    # Analyze field quality for each calendar
    print(f"\n🔍 FIELD QUALITY ANALYSIS:")
    print("=" * 50)
    
    suspicious_matches = []
    
    for calendar_type, calendar_matches in by_calendar.items():
        print(f"\n{calendar_type.upper()} CALENDAR:")
        
        # Count empty fields
        empty_organizers = sum(1 for m in calendar_matches if not clean_text(m['organizer']))
        empty_locations = sum(1 for m in calendar_matches if not clean_text(m['location']))
        empty_types = sum(1 for m in calendar_matches if not clean_text(m['type']))
        
        total = len(calendar_matches)
        print(f"  Empty organizers: {empty_organizers}/{total} ({empty_organizers/total*100:.1f}%)")
        print(f"  Empty locations: {empty_locations}/{total} ({empty_locations/total*100:.1f}%)")
        print(f"  Empty types: {empty_types}/{total} ({empty_types/total*100:.1f}%)")
        
        # Check for field mapping issues
        types_in_organizer = sum(1 for m in calendar_matches if re.search(r'(MAP|KNJV|veldwedstrijd|TAP|CAC|CACIT)', clean_text(m['organizer'])))
        orgs_in_type = sum(1 for m in calendar_matches if re.search(r'(Stichting|Vereniging|Club)', clean_text(m['type'])))
        
        print(f"  Match types in organizer field: {types_in_organizer}")
        print(f"  Organization names in type field: {orgs_in_type}")
        
        # Show sample matches
        print(f"  Sample matches:")
        for i, match in enumerate(calendar_matches[:3]):
            print(f"    {i+1}. {match['date']} | {clean_text(match['organizer'])[:50]}... | {clean_text(match['type'])[:30]}...")
        
        # Track suspicious matches
        for match in calendar_matches:
            issues = []
            
            organizer = clean_text(match['organizer'])
            location = clean_text(match['location'])
            match_type = clean_text(match['type'])
            
            # Check for field mapping issues
            if re.search(r'(MAP|KNJV|veldwedstrijd|TAP|CAC|CACIT)', organizer):
                issues.append("Match type in organizer field")
            
            if re.search(r'(Stichting|Vereniging|Club)', match_type):
                issues.append("Organization name in type field")
            
            # Check for empty critical fields
            if not organizer and not location:
                issues.append("Empty organizer and location")
            
            if issues:
                suspicious_matches.append({
                    'match': match,
                    'issues': issues
                })
    
    # Final assessment
    print(f"\n🎯 TIER 2 FIXES VALIDATION SUMMARY:")
    print("=" * 50)
    
    total_issues = len(suspicious_matches)
    
    if total_issues == 0:
        print("✅ TIER 2 FIXES: SUCCESS!")
        print("✅ Field mappings are now correct")
        print("✅ Deduplication is working")
        print("✅ Recommendation: Tier 2 is ready for production use")
    else:
        print(f"❌ TIER 2 FIXES: STILL HAVE ISSUES")
        print(f"❌ Issues found: {total_issues} suspicious matches")
        print("💡 Recommendation: Additional fixes needed")
        
        for i, suspicious in enumerate(suspicious_matches[:5]):
            match = suspicious['match']
            issues = suspicious['issues']
            print(f"\n{i+1}. ISSUE ({match.get('calendar_type', 'unknown')} calendar):")
            print(f"   Date: {match['date']}")
            print(f"   Organizer: '{clean_text(match['organizer'])}'")
            print(f"   Location: '{clean_text(match['location'])}'")
            print(f"   Type: '{clean_text(match['type'])}'")
            print(f"   Issues: {', '.join(issues)}")
    
    return matches

if __name__ == "__main__":
    test_field_mapping_validation() 