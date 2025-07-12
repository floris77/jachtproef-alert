#!/usr/bin/env python3
"""
JachtProef Alert - Working ORWEJA Scraper
Implements the two-tier scraping system as documented

Tier 1: Public calendar (all matches, basic info)
Tier 2: Protected calendar (authenticated, specific types)
"""

import requests
from bs4 import BeautifulSoup
import json
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import re
import os
from difflib import SequenceMatcher
import time
import html
import unicodedata
import csv

# ORWEJA CREDENTIALS for protected calendar access
ORWEJA_USERNAME = "Jacqueline vd Hart-Snelle"
ORWEJA_PASSWORD = "Jindi11Leia"

# Initialize Firebase (for testing, we'll handle this separately)
db = None

def initialize_firebase():
    """Initialize Firebase connection"""
    global db
    try:
        if not firebase_admin._apps:
            firebase_admin.initialize_app()
        db = firestore.client()
        print("✅ Firebase initialized successfully")
        return True
    except Exception as e:
        print(f"❌ Firebase initialization error: {e}")
        return False

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
    
    # Handle exact matches after normalization
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

def scrape_tier1_public_calendar():
    """
    Tier 1: Scrape public calendar for all matches
    URL: https://my.orweja.nl/widget/kalender/
    """
    print("🔍 Tier 1: Scraping public calendar...")
    
    url = "https://my.orweja.nl/widget/kalender/"
    
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.content, 'html.parser')
        
        matches = []
        
        # Find match entries (adjust selectors based on actual HTML structure)
        match_entries = soup.find_all('tr')  # Adjust selector as needed
        
        for entry in match_entries:
            try:
                # Extract match data (adjust based on actual HTML structure)
                cells = entry.find_all('td')
                if len(cells) < 7:  # Need at least 7 columns
                    continue
                
                # Parse date (column 0)
                date_text = cells[0].get_text(strip=True)
                match_date = parse_date(date_text)
                
                # Parse type (column 1) - often just "KNJV"
                match_type = cells[1].get_text(strip=True)
                
                # Parse organizer (column 2)
                organizer = cells[2].get_text(strip=True)
                
                # Parse location (column 3)
                location = cells[3].get_text(strip=True)
                
                # Parse contact (column 4) - skip this
                contact = cells[4].get_text(strip=True)
                
                # Parse remarks (column 5) - skip this
                remarks = cells[5].get_text(strip=True)
                
                # Parse registration status (column 6)
                reg_status = cells[6].get_text(strip=True)
                
                match_data = {
                    'date': match_date,
                    'organizer': organizer,
                    'location': location,
                    'registration_text': reg_status,
                    'type': match_type,
                    'source': 'tier1'
                }
                
                matches.append(match_data)
                
            except Exception as e:
                print(f"⚠️ Error parsing match entry: {e}")
                continue
        
        print(f"📊 Tier 1: Found {len(matches)} matches")
        return matches
        
    except Exception as e:
        print(f"❌ Tier 1 scraping error: {e}")
        return []

def scrape_tier2_protected_calendars():
    """
    Tier 2: Scrape protected calendars for specific types
    URLs: 
    - https://my.orweja.nl/home/kalender/0 (Veldwedstrijden)
    - https://my.orweja.nl/home/kalender/1 (Jachthondenproeven - SJP, MAP, etc.)
    - https://my.orweja.nl/home/kalender/2 (ORWEJA Workingtests)
    """
    print("🔍 Tier 2: Scraping protected calendars...")
    
    session = authenticate_orweja()
    if not session:
        print("❌ Failed to authenticate with ORWEJA")
        return []
    
    protected_matches = []
    
    protected_urls = [
        ("https://my.orweja.nl/home/kalender/0", "Veldwedstrijd"),
        ("https://my.orweja.nl/home/kalender/1", "Jachthondenproef"),
        ("https://my.orweja.nl/home/kalender/2", "ORWEJA Werktest")
    ]
    
    for url, calendar_type in protected_urls:
        try:
            print(f"📄 Scraping: {calendar_type}")
            response = session.get(url, timeout=30)
            response.raise_for_status()
            soup = BeautifulSoup(response.content, 'html.parser')
            # Find the table with class 'table-hover'
            table = soup.find('table', class_='table-hover')
            if not table:
                print(f"❌ No table found for {calendar_type}")
                continue
            tbody = table.find('tbody')
            if not tbody:
                print(f"❌ No tbody found for {calendar_type}")
                continue
            rows = tbody.find_all('tr', class_='kalrow')
            for row in rows:
                cells = row.find_all('td')
                if len(cells) < 6:
                    continue  # Not enough columns
                date_text = cells[0].get_text(strip=True)
                match_type = cells[1].get_text(strip=True)
                organizer = cells[2].get_text(" ", strip=True)
                location = cells[3].get_text(" ", strip=True)
                remarks = cells[4].get_text(" ", strip=True)
                reg_status = cells[5].get_text(strip=True)
                
                # NORMALIZE MATCH TYPES: Convert to standardized types and acronyms
                normalized_type = match_type
                
                if calendar_type == 'Veldwedstrijd':
                    # For Veldwedstrijd calendar, normalize CAC/CACIT to "Veldwedstrijd"
                    if match_type.upper().startswith('CACIT') or 'CACIT' in match_type.upper():
                        normalized_type = 'Veldwedstrijd'
                    elif match_type.upper().startswith('CAC') or 'CAC' in match_type.upper():
                        normalized_type = 'Veldwedstrijd'
                    else:
                        normalized_type = 'Veldwedstrijd'
                elif calendar_type == 'Jachthondenproef':
                    # Convert long names to acronyms for Jachthondenproef calendar
                    if 'standaard jachthonden' in match_type.lower() or 'standaard jachthondenproef' in match_type.lower():
                        normalized_type = 'SJP'
                    elif 'middelgrote apporteur' in match_type.lower() or 'map' in match_type.lower():
                        normalized_type = 'MAP'
                    elif 'praktijk jacht' in match_type.lower() or 'pjp' in match_type.lower() or 'provinciale jachthonden' in match_type.lower():
                        normalized_type = 'PJP'
                    elif 'terrier apporteur' in match_type.lower() or 'team apporteer' in match_type.lower() or 'tap' in match_type.lower():
                        normalized_type = 'TAP'
                    elif 'kleine apporteur' in match_type.lower() or 'kap' in match_type.lower():
                        normalized_type = 'KAP'
                    elif 'stöberhunde' in match_type.lower() or 'swt' in match_type.lower() or 'spaniël workingtest' in match_type.lower():
                        normalized_type = 'SWT'
                    elif 'orweja werktest' in match_type.lower() or 'owt' in match_type.lower():
                        normalized_type = 'OWT'
                    # If no specific match, keep original but clean it
                    else:
                        normalized_type = match_type
                
                match_data = {
                    'date': parse_date(date_text),
                    'organizer': organizer,
                    'location': location,
                    'remarks': remarks,
                    'registration_text': reg_status,
                    'type': normalized_type,
                    'source': 'tier2',
                    'calendar_type': calendar_type
                }
                protected_matches.append(match_data)
        except Exception as e:
            print(f"❌ Error scraping {calendar_type}: {e}")
            continue
    print(f"📊 Tier 2: Found {len(protected_matches)} matches")
    return protected_matches

def authenticate_orweja():
    """Authenticate with ORWEJA for protected calendar access"""
    print("🔐 Authenticating with ORWEJA...")
    
    session = requests.Session()
    
    try:
        # Get login page
        login_url = "https://my.orweja.nl/login"
        response = session.get(login_url, timeout=30)
        response.raise_for_status()
        
        # Parse login form to get correct field names
        soup = BeautifulSoup(response.content, 'html.parser')
        login_form = soup.find('form')
        
        if not login_form:
            print("❌ No login form found")
            return None
        
        # Find form inputs to get correct field names
        inputs = login_form.find_all('input')
        username_field = None
        password_field = None
        
        for inp in inputs:
            name = inp.get('name', '')
            type_attr = inp.get('type', '')
            if type_attr == 'text':
                username_field = name
            elif type_attr == 'password':
                password_field = name
        
        if not username_field or not password_field:
            print(f"❌ Could not find username/password fields. Found: username={username_field}, password={password_field}")
            return None
        
        print(f"🔑 Using field names: {username_field}, {password_field}")
        
        # Login data with correct field names
        login_data = {
            username_field: ORWEJA_USERNAME,
            password_field: ORWEJA_PASSWORD
        }
        
        # Submit login
        response = session.post(login_url, data=login_data, timeout=30, allow_redirects=True)
        
        print(f"📊 Login response status: {response.status_code}")
        
        # Check if login was successful by trying to access a protected page
        test_url = "https://my.orweja.nl/home/kalender/1"
        test_response = session.get(test_url, timeout=30)
        
        print(f"📊 Test protected page status: {test_response.status_code}")
        
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

def parse_date(date_text):
    """Parse date from various formats"""
    try:
        # Common Dutch date formats
        formats = [
            '%d-%m-%Y',  # 12-07-2025
            '%Y-%m-%d',  # 2025-07-12
            '%d/%m/%Y',  # 12/07/2025
            '%Y/%m/%d',  # 2025/07/12
            '%d-%m-%y',  # 12-07-25
            '%d/%m/%y',  # 12/07/25
        ]
        
        date_text = date_text.strip()
        
        for fmt in formats:
            try:
                parsed_date = datetime.strptime(date_text, fmt)
                return parsed_date
            except ValueError:
                continue
        
        # If no format matches, return as string
        print(f"⚠️ Could not parse date: '{date_text}'")
        return date_text
        
    except Exception as e:
        print(f"⚠️ Date parsing error for '{date_text}': {e}")
        return date_text

def match_tier1_tier2(tier1_matches, tier2_matches):
    """
    Match Tier 1 and Tier 2 entries using date and organizer similarity
    """
    print("🔗 Matching Tier 1 and Tier 2 entries...")
    
    # Debug: Print sample data from both tiers
    print(f"🔍 Sample Tier 1 dates: {[str(m['date']) for m in tier1_matches[:5]]}")
    print(f"🔍 Sample Tier 2 dates: {[str(m['date']) for m in tier2_matches[:5]]}")
    print(f"🔍 Sample Tier 1 organizers: {[m['organizer'][:50] for m in tier1_matches[:3]]}")
    print(f"🔍 Sample Tier 2 organizers: {[m['organizer'][:50] for m in tier2_matches[:3]]}")
    
    matched_matches = []
    unmatched_tier1 = []
    total_date_matches = 0
    total_comparisons = 0
    debug_samples = 0
    
    for tier1_match in tier1_matches:
        best_match = None
        best_similarity = 0
        norm_t1_org = normalize_org(tier1_match['organizer'])
        date_matches = 0
        
        for tier2_match in tier2_matches:
            # Check date similarity
            if tier1_match['date'] == tier2_match['date']:
                date_matches += 1
                total_date_matches += 1
                norm_t2_org = normalize_org(tier2_match['organizer'])
                org_similarity = similarity(norm_t1_org, norm_t2_org)
                total_comparisons += 1
                
                # Debug: Show first few comparisons
                if debug_samples < 5:
                    print(f"  🔍 Compare: '{norm_t1_org[:30]}' <-> '{norm_t2_org[:30]}' = {org_similarity:.3f}")
                    debug_samples += 1
                
                if org_similarity > 0.5 and org_similarity > best_similarity:  # Keep 50% threshold
                    best_match = tier2_match
                    best_similarity = org_similarity
        
        if best_match:
            combined_match = {
                'date': tier1_match['date'],
                'organizer': tier1_match['organizer'],
                'location': tier1_match['location'],
                'registration_text': tier1_match['registration_text'],
                'type': best_match['type'],  # Use Tier 2 specific type
                'source': 'matched',
                'tier2_calendar_type': best_match.get('calendar_type', '')
            }
            matched_matches.append(combined_match)
            print(f"  ✅ Matched: {tier1_match['organizer'][:30]} -> {best_match['type']} (sim={best_similarity:.3f})")
        else:
            unmatched_tier1.append(tier1_match)
            if len(unmatched_tier1) <= 3:  # Only show first few unmatched
                print(f"  ❌ No match: {tier1_match['organizer'][:30]} ({tier1_match['type']})")
    
    final_matches = matched_matches + unmatched_tier1
    
    print(f"\n📊 Matching Summary:")
    print(f"   - Total Tier 1 matches: {len(tier1_matches)}")
    print(f"   - Total Tier 2 matches: {len(tier2_matches)}")
    print(f"   - Date matches found: {total_date_matches}")
    print(f"   - Organizer comparisons made: {total_comparisons}")
    print(f"   - Successfully matched: {len(matched_matches)}")
    print(f"   - Unmatched Tier 1: {len(unmatched_tier1)}")
    print(f"   - Final total: {len(final_matches)}")
    
    return final_matches

def upload_to_firebase(matches):
    """Upload matches to Firebase Firestore"""
    if not db:
        print("❌ Firebase not initialized")
        return 0
    
    try:
        uploaded_count = 0
        
        for match in matches:
            try:
                # Create document ID from date and organizer
                doc_id = f"{match['date'].strftime('%Y-%m-%d')}_{match['organizer'].replace(' ', '_')}"
                
                # Add metadata
                match['scraped_at'] = datetime.now()
                match['last_updated'] = datetime.now()
                
                # Upload to Firestore
                db.collection('matches').document(doc_id).set(match, merge=True)
                uploaded_count += 1
                
                print(f"💾 Uploaded: {match['organizer']} ({match['date'].strftime('%Y-%m-%d')})")
                
            except Exception as e:
                print(f"❌ Error uploading match {match.get('organizer', 'Unknown')}: {e}")
                continue
        
        print(f"✅ Successfully uploaded {uploaded_count} matches to Firebase")
        return uploaded_count
        
    except Exception as e:
        print(f"❌ Firebase upload error: {e}")
        return 0

def compare_tier1_tier2_side_by_side(tier1_matches, tier2_matches):
    """
    Compare Tier 1 and Tier 2 matches side by side to identify differences
    """
    print("🔍 COMPARISON ANALYSIS")
    print("=" * 50)
    
    # Show sample data in compact format
    print("TIER 1 SAMPLE:")
    for i, match in enumerate(tier1_matches[:3]):
        print(f"  {i+1}. {match['date']} | {match['organizer'][:30]} | {match['type']}")
    
    print("\nTIER 2 SAMPLE:")
    for i, match in enumerate(tier2_matches[:3]):
        print(f"  {i+1}. {match['date']} | {match['organizer'][:30]} | {match['type']}")
    
    # Check for overlapping dates
    tier1_dates = set(str(m['date']) for m in tier1_matches[:10])
    tier2_dates = set(str(m['date']) for m in tier2_matches[:10])
    overlapping = tier1_dates & tier2_dates
    
    print(f"\nOVERLAPPING DATES: {len(overlapping)} out of 10")
    if overlapping:
        sample_date = list(overlapping)[0]
        t1_orgs = [m['organizer'] for m in tier1_matches[:10] if str(m['date']) == sample_date]
        t2_orgs = [m['organizer'] for m in tier2_matches[:10] if str(m['date']) == sample_date]
        print(f"SAMPLE DATE {sample_date}:")
        print(f"  T1: {t1_orgs[:2]}")
        print(f"  T2: {t2_orgs[:2]}")
        
        # Show one similarity calculation
        if t1_orgs and t2_orgs:
            norm_t1 = normalize_org(t1_orgs[0])
            norm_t2 = normalize_org(t2_orgs[0])
            sim = similarity(norm_t1, norm_t2)
            print(f"  SIMILARITY: '{norm_t1[:20]}' <-> '{norm_t2[:20]}' = {sim:.3f}")
    
    print("=" * 50)

def test_normalization():
    """
    Test the normalization function with real-world examples
    """
    print("🧪 TESTING NORMALIZATION")
    print("=" * 50)
    
    test_cases = [
        ("Jachtvereniging Amsterdam", "Jachtvereniging Amsterdam"),
        ("KNJV Noord-Holland", "KNJV Noord-Holland"),
        ("PJP Gelderland", "PJP Gelderland"),
        ("Stichting Jachtvereniging", "Jachtvereniging"),
        ("&nbsp;Jachtvereniging&nbsp;", "Jachtvereniging"),
        ("Jachtvereniging (Amsterdam)", "Jachtvereniging Amsterdam"),
        ("KNJV Noord-Holland", "KNJV Noord Holland"),
        ("PJP-Gelderland", "PJP Gelderland"),
    ]
    
    for i, (org1, org2) in enumerate(test_cases):
        norm1 = normalize_org(org1)
        norm2 = normalize_org(org2)
        sim = similarity(org1, org2)
        status = "✅" if sim > 0.5 else "❌"
        print(f"{status} Test {i+1}: '{org1}' <-> '{org2}'")
        print(f"     Normalized: '{norm1}' <-> '{norm2}' = {sim:.3f}")
        print()

def save_sample_data(tier1_matches, tier2_matches):
    """
    Save sample data to a file for analysis
    """
    sample_data = {
        'tier1_sample': tier1_matches[:10],
        'tier2_sample': tier2_matches[:10],
        'tier1_dates': [str(m['date']) for m in tier1_matches[:10]],
        'tier2_dates': [str(m['date']) for m in tier2_matches[:10]],
        'overlapping_dates': list(set(str(m['date']) for m in tier1_matches[:10]) & set(str(m['date']) for m in tier2_matches[:10]))
    }
    
    with open('/tmp/sample_data.json', 'w') as f:
        json.dump(sample_data, f, indent=2, default=str)
    
    print(f"💾 Sample data saved to /tmp/sample_data.json")
    print(f"📊 Overlapping dates: {len(sample_data['overlapping_dates'])}")

def export_real_data_to_csv(tier1_matches, tier2_matches):
    """
    Export the actual scraped data to a single comprehensive CSV file for manual analysis
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    # Create a single comprehensive analysis file
    combined_filename = f'comprehensive_analysis_{timestamp}.csv'
    with open(combined_filename, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = [
            'date', 
            'tier1_organizer', 'tier1_type', 'tier1_location', 'tier1_registration',
            'tier2_organizer', 'tier2_type', 'tier2_calendar_type', 'tier2_location',
            'match_found', 'similarity_score', 'normalized_tier1', 'normalized_tier2', 'notes'
        ]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        
        # Create mappings by date
        tier1_by_date = {}
        tier2_by_date = {}
        
        for match in tier1_matches:
            date = str(match['date'])
            if date not in tier1_by_date:
                tier1_by_date[date] = []
            tier1_by_date[date].append(match)
        
        for match in tier2_matches:
            date = str(match['date'])
            if date not in tier2_by_date:
                tier2_by_date[date] = []
            tier2_by_date[date].append(match)
        
        # Write comprehensive analysis rows
        all_dates = set(tier1_by_date.keys()) | set(tier2_by_date.keys())
        for date in sorted(all_dates):
            tier1_items = tier1_by_date.get(date, [])
            tier2_items = tier2_by_date.get(date, [])
            
            # If both tiers have data for this date
            if tier1_items and tier2_items:
                for t1 in tier1_items:
                    for t2 in tier2_items:
                        norm_t1 = normalize_org(t1['organizer'])
                        norm_t2 = normalize_org(t2['organizer'])
                        sim = similarity(t1['organizer'], t2['organizer'])
                        
                        writer.writerow({
                            'date': date,
                            'tier1_organizer': t1['organizer'],
                            'tier1_type': t1['type'],
                            'tier1_location': t1.get('location', ''),
                            'tier1_registration': t1.get('registration_text', ''),
                            'tier2_organizer': t2['organizer'],
                            'tier2_type': t2['type'],
                            'tier2_calendar_type': t2.get('calendar_type', ''),
                            'tier2_location': t2.get('location', ''),
                            'match_found': 'YES' if sim > 0.5 else 'NO',
                            'similarity_score': f'{sim:.3f}',
                            'normalized_tier1': norm_t1,
                            'normalized_tier2': norm_t2,
                            'notes': 'Potential match' if sim > 0.3 else 'Low similarity'
                        })
            else:
                # Only one tier has data
                for item in tier1_items:
                    writer.writerow({
                        'date': date,
                        'tier1_organizer': item['organizer'],
                        'tier1_type': item['type'],
                        'tier1_location': item.get('location', ''),
                        'tier1_registration': item.get('registration_text', ''),
                        'tier2_organizer': '',
                        'tier2_type': '',
                        'tier2_calendar_type': '',
                        'tier2_location': '',
                        'match_found': 'NO',
                        'similarity_score': '',
                        'normalized_tier1': normalize_org(item['organizer']),
                        'normalized_tier2': '',
                        'notes': 'Only in Tier 1 (Public Calendar)'
                    })
                for item in tier2_items:
                    writer.writerow({
                        'date': date,
                        'tier1_organizer': '',
                        'tier1_type': '',
                        'tier1_location': '',
                        'tier1_registration': '',
                        'tier2_organizer': item['organizer'],
                        'tier2_type': item['type'],
                        'tier2_calendar_type': item.get('calendar_type', ''),
                        'tier2_location': item.get('location', ''),
                        'match_found': 'NO',
                        'similarity_score': '',
                        'normalized_tier1': '',
                        'normalized_tier2': normalize_org(item['organizer']),
                        'notes': 'Only in Tier 2 (Protected Calendars)'
                    })
    
    print(f"💾 Comprehensive analysis exported to: {combined_filename}")
    print(f"📊 Total entries: {len(tier1_matches) + len(tier2_matches)}")
    print(f"📊 Tier 1 entries: {len(tier1_matches)}")
    print(f"📊 Tier 2 entries: {len(tier2_matches)}")
    print(f"📊 Unique dates: {len(all_dates)}")
    
    # Also create a summary file
    summary_filename = f'summary_{timestamp}.csv'
    with open(summary_filename, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['metric', 'value', 'description']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        
        writer.writerow({'metric': 'Total Tier 1', 'value': len(tier1_matches), 'description': 'Public calendar entries'})
        writer.writerow({'metric': 'Total Tier 2', 'value': len(tier2_matches), 'description': 'Protected calendar entries'})
        writer.writerow({'metric': 'Unique Dates', 'value': len(all_dates), 'description': 'Total unique dates found'})
        
        # Count potential matches
        potential_matches = 0
        for date in all_dates:
            tier1_items = tier1_by_date.get(date, [])
            tier2_items = tier2_by_date.get(date, [])
            if tier1_items and tier2_items:
                for t1 in tier1_items:
                    for t2 in tier2_items:
                        sim = similarity(t1['organizer'], t2['organizer'])
                        if sim > 0.5:
                            potential_matches += 1
        
        writer.writerow({'metric': 'Potential Matches', 'value': potential_matches, 'description': 'Entries with >50% similarity'})
        writer.writerow({'metric': 'Match Rate', 'value': f'{(potential_matches/len(tier1_matches)*100):.1f}%', 'description': 'Percentage of Tier 1 that could match'})
    
    print(f"💾 Summary exported to: {summary_filename}")
    print(f"📁 Total files created: 2")
    
    print("\n" + "="*60)
    print("MANUAL ANALYSIS INSTRUCTIONS")
    print("="*60)
    print("1. Open the comprehensive_analysis CSV in Excel/Google Sheets")
    print("2. Sort by 'date' column to group entries by date")
    print("3. Look for rows where both Tier 1 and Tier 2 have data")
    print("4. Compare 'tier1_organizer' vs 'tier2_organizer' columns")
    print("5. Check 'normalized_tier1' vs 'normalized_tier2' for text differences")
    print("6. Use 'similarity_score' to identify potential matches")
    print("7. Create filtering rules based on patterns you find")

def main():
    """
    Main scraper function
    """
    print("🚀 Starting JachtProef Alert Scraper...")
    print("=" * 50)
    
    # Test normalization first
    test_normalization()
    
    # Initialize Firebase (optional for testing)
    firebase_available = initialize_firebase()
    
    # Step 1: Scrape Tier 1 (public calendar)
    tier1_matches = scrape_tier1_public_calendar()
    
    if not tier1_matches:
        print("❌ No matches found in Tier 1")
        return
    
    # Step 2: Scrape Tier 2 (protected calendars)
    tier2_matches = scrape_tier2_protected_calendars()
    
    # Step 3: Export data to CSV for manual analysis
    export_real_data_to_csv(tier1_matches, tier2_matches)
    
    # Step 4: Save sample data for analysis
    save_sample_data(tier1_matches, tier2_matches)
    
    # Step 5: Side-by-side comparison
    compare_tier1_tier2_side_by_side(tier1_matches, tier2_matches)
    
    # Step 6: Match Tier 1 and Tier 2
    final_matches = match_tier1_tier2(tier1_matches, tier2_matches)
    
    # Step 7: Upload to Firebase
    if firebase_available and final_matches:
        upload_to_firebase(final_matches)
    
    print("✅ Scraper completed successfully!")
    return {
        'status': 'success',
        'matches_found': len(final_matches),
        'tier1_matches': len(tier1_matches),
        'tier2_matches': len(tier2_matches)
    }

if __name__ == "__main__":
    main() 