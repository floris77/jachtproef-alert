#!/usr/bin/env python3
"""
JachtProef Alert - ORWEJA Scraper Cloud Function
Deployed version with real ORWEJA scraping (not test data)
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
import functions_framework
import csv
import io
from google.cloud import storage

# ORWEJA CREDENTIALS for protected calendar access
ORWEJA_USERNAME = "Jacqueline vd Hart-Snelle"
ORWEJA_PASSWORD = "Jindi11Leia"

# Initialize Firebase
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

def similarity(a, b):
    """Calculate similarity between two strings"""
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()

def parse_date(date_text):
    """Parse date from various formats"""
    try:
        # Handle DD-MM-YYYY format (ORWEJA format)
        if re.match(r'\d{1,2}-\d{1,2}-\d{4}', date_text):
            return datetime.strptime(date_text, '%d-%m-%Y').date()
        # Handle DD-MM-YYYY format with leading zeros
        elif re.match(r'\d{2}-\d{2}-\d{4}', date_text):
            return datetime.strptime(date_text, '%d-%m-%Y').date()
        # Handle other formats as needed
        return datetime.now().date()
    except Exception as e:
        print(f"⚠️ Error parsing date '{date_text}': {e}")
        return datetime.now().date()

# ====================================================================
# ARCHIVED: Tier 1 Scraper (No longer used - July 2025)
# ====================================================================
# We switched to using only Tier 2 (protected calendars) because:
# 1. Tier 2 provides more accurate and detailed data
# 2. Tier 1 had column mapping issues and inconsistent data
# 3. Tier 2 includes proper registration status and enrollment dates
# 
# This function is kept for historical reference but is not called
# ====================================================================

def scrape_tier1_public_calendar_ARCHIVED():
    """
    ARCHIVED: Tier 1 scraper - no longer used
    
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
        
        # Find match entries - look for table rows
        match_entries = soup.find_all('tr')
        
        for entry in match_entries:
            try:
                # Extract match data
                cells = entry.find_all('td')
                if len(cells) < 4:  # Need at least 4 columns
                    continue
                
                # Parse date (column 0)
                date_text = cells[0].get_text(strip=True)
                if not date_text or not re.match(r'\d{1,2}-\d{1,2}-\d{4}', date_text):
                    continue  # Skip invalid dates
                
                match_date = parse_date(date_text)
                
                # FIXED FIELD MAPPING - Clean text extraction
                # Column 1: Match type (MAP, KNJV, etc.)
                match_type = cells[1].get_text(separator=' ', strip=True)
                match_type = re.sub(r'\s+', ' ', match_type)  # Clean multiple spaces
                match_type = match_type.replace('\\', '').strip()  # Remove escape chars
                
                # Column 2: Organizer
                organizer = cells[2].get_text(separator=' ', strip=True)
                organizer = re.sub(r'\s+', ' ', organizer)  # Clean multiple spaces
                organizer = organizer.replace('\\', '').strip()  # Remove escape chars
                
                # Column 3: Location
                location = cells[3].get_text(separator=' ', strip=True)
                location = re.sub(r'\s+', ' ', location)  # Clean multiple spaces
                location = location.replace('\\', '').strip()  # Remove escape chars
                
                # Parse registration status (column 5 - last column with registration text)
                reg_status = ""
                if len(cells) > 5:
                    reg_status = cells[5].get_text(separator=' ', strip=True)
                    reg_status = re.sub(r'\s+', ' ', reg_status)  # Clean multiple spaces
                    reg_status = reg_status.replace('\\', '').strip()  # Remove escape chars
                
                # Skip entries with empty critical fields
                if not organizer.strip() and not location.strip():
                    print(f"⚠️ Skipping entry with empty organizer and location: {date_text}")
                    continue
                
                # Clean up common parsing artifacts
                organizer = re.sub(r'Aanvang:.*$', '', organizer).strip()
                location = re.sub(r'Aanvang:.*$', '', location).strip()
                
                match_data = {
                    'date': match_date,
                    'organizer': organizer,
                    'location': location,
                    'registration_text': reg_status.lower() if reg_status else 'inschrijven',
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
            if type_attr == 'text' or type_attr == 'email':
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

def scrape_tier2_protected_calendars():
    """Scrape the three protected calendars with authentication"""
    print("🔐 Starting Tier 2 scraping (protected calendars)...")
    
    # Login first
    session = authenticate_orweja()
    if not session:
        print("❌ Authentication failed - cannot access protected calendars")
        return []
    
    all_matches = []
    
    # Calendar definitions with corrected field mappings
    calendars = [
        {
            'name': 'Veldwedstrijd',
            'url': 'https://my.orweja.nl/home/kalender/0',
            'calendar_type': 'Veldwedstrijd'
        },
        {
            'name': 'Jachthondenproef', 
            'url': 'https://my.orweja.nl/home/kalender/1',
            'calendar_type': 'Jachthondenproef'
        },
        {
            'name': 'ORWEJA Werktest',
            'url': 'https://my.orweja.nl/home/kalender/2', 
            'calendar_type': 'ORWEJA Werktest'
        }
    ]
    
    for calendar in calendars:
        print(f"📅 Scraping {calendar['name']} calendar...")
        
        try:
            response = session.get(calendar['url'])
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Find the calendar table
            calendar_table = soup.find('table', {'class': 'table'})
            if not calendar_table:
                print(f"⚠️ No calendar table found for {calendar['name']}")
                continue
            
            # Find all match rows (skip header)
            match_rows = calendar_table.find_all('tr')[1:]  # Skip header row
            
            for row in match_rows:
                try:
                    cells = row.find_all('td')
                    if len(cells) < 4:
                        continue
                    
                    # CORRECTED FIELD MAPPING based on actual ORWEJA structure
                    # Column 0: Date
                    date_text = cells[0].get_text(strip=True)
                    if not date_text or not re.match(r'\d{1,2}-\d{1,2}-\d{4}', date_text):
                        continue
                    
                    match_date = parse_date(date_text)
                    if not match_date:
                        continue
                    
                    # Column 1: Match type/details (CAC, CACIT, etc.)
                    match_type = cells[1].get_text(strip=True)
                    if not match_type:
                        continue
                    
                    # Column 2: Organizer 
                    organizer = cells[2].get_text(strip=True)
                    # Clean organizer text
                    organizer = re.sub(r'\[email[^\]]*protected\]', '', organizer)
                    organizer = re.sub(r'\[email[^\]]*\]', '', organizer)
                    organizer = re.sub(r'\s+', ' ', organizer).strip()
                    
                    # Column 3: Location
                    location = cells[3].get_text(strip=True)
                    # Clean location text
                    location = re.sub(r'\[email[^\]]*protected\]', '', location)
                    location = re.sub(r'\[email[^\]]*\]', '', location)
                    location = re.sub(r'Aanvang:\s*\d{1,2}[:.]\d{2}', '', location)
                    location = re.sub(r'\s+', ' ', location).strip()
                    
                    # Column 5: Registration status and URL (6th column - "Inschrijven")
                    registration_text = ""
                    registration_url = ""
                    if len(cells) > 5:
                        reg_cell = cells[5]
                        registration_text = reg_cell.get_text(strip=True)
                        
                        # Look for enrollment link in this cell
                        link = reg_cell.find('a')
                        if link and link.get('href'):
                            href = link.get('href')
                            # Convert relative URLs to absolute URLs
                            if href.startswith('/'):
                                registration_url = f"https://my.orweja.nl{href}"
                            elif href.startswith('http'):
                                registration_url = href
                            else:
                                registration_url = f"https://my.orweja.nl/{href}"
                    
                    # Column 4: Remarks/Notes ("Opmerking")
                    remarks_from_column = ""
                    if len(cells) > 4:
                        remarks_from_column = cells[4].get_text(strip=True)
                        # Clean remarks text
                        remarks_from_column = re.sub(r'\[email[^\]]*protected\]', '', remarks_from_column)
                        remarks_from_column = re.sub(r'\[email[^\]]*\]', '', remarks_from_column)
                        remarks_from_column = re.sub(r'\s+', ' ', remarks_from_column).strip()
                    
                    # Combine remarks from column 4 with any additional columns
                    general_remarks = ""
                    if remarks_from_column and remarks_from_column not in ['', ' ', '-']:
                        general_remarks = remarks_from_column
                    
                    # Column 6+: Check for any additional remarks/notes in remaining columns
                    if len(cells) > 6:
                        for i in range(6, len(cells)):
                            cell_text = cells[i].get_text(strip=True)
                            # Clean cell text
                            cell_text = re.sub(r'\[email[^\]]*protected\]', '', cell_text)
                            cell_text = re.sub(r'\[email[^\]]*\]', '', cell_text)
                            cell_text = re.sub(r'\s+', ' ', cell_text).strip()
                            
                            # Skip if this is actually registration status (not a real remark)
                            if cell_text.lower() in ['inschrijven', 'niet mogelijk', 'niet meer mogelijk']:
                                continue
                            if cell_text.lower().startswith('vanaf '):
                                continue
                            
                            if cell_text and cell_text not in ['', ' ', '-']:
                                if general_remarks:
                                    general_remarks += f" | {cell_text}"
                                else:
                                    general_remarks = cell_text
                    
                    # NORMALIZE MATCH TYPES: Convert to standardized types and acronyms
                    normalized_type = match_type
                    match_details = None
                    
                    if calendar['calendar_type'] == 'Veldwedstrijd':
                        # For Veldwedstrijd calendar, normalize CAC/CACIT to "Veldwedstrijd"
                        if match_type.upper().startswith('CACIT') or 'CACIT' in match_type.upper():
                            normalized_type = 'Veldwedstrijd'  
                            match_details = f"Internationale kwalificatie: {match_type}"
                        elif match_type.upper().startswith('CAC') or 'CAC' in match_type.upper():
                            normalized_type = 'Veldwedstrijd'
                            match_details = f"Kwalificatie: {match_type}"
                        else:
                            normalized_type = 'Veldwedstrijd'
                    elif calendar['calendar_type'] == 'Jachthondenproef':
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
                    
                    # Create match record
                    match_data = {
                        'date': match_date,
                        'organizer': organizer,
                        'location': location,
                        'type': normalized_type,
                        'registration_text': registration_text.lower() if registration_text else 'inschrijven',
                        'calendar_type': calendar['calendar_type'],
                        'source': 'tier2'
                    }
                    
                    # Add registration URL if we found one
                    if registration_url:
                        match_data['registration_url'] = registration_url
                    
                    # Combine general remarks with qualification details
                    combined_remarks = ""
                    if general_remarks:
                        combined_remarks = general_remarks
                    if match_details:
                        if combined_remarks:
                            combined_remarks += f" | {match_details}"
                        else:
                            combined_remarks = match_details
                    
                    # Add combined remarks if we have any
                    if combined_remarks:
                        match_data['remark'] = combined_remarks
                    
                    all_matches.append(match_data)
                    
                except Exception as e:
                    print(f"⚠️ Error parsing row in {calendar['name']}: {e}")
                    continue
            
            print(f"✅ Found {len([m for m in all_matches if m['calendar_type'] == calendar['calendar_type']])} matches in {calendar['name']}")
            
        except Exception as e:
            print(f"❌ Error scraping {calendar['name']}: {e}")
            continue
    
    print(f"📊 Tier 2 total: {len(all_matches)} matches")
    
    # Remove duplicates based on date + organizer + location
    unique_matches = []
    seen_keys = set()
    
    for match in all_matches:
        key = f"{match['date']}_{match['organizer']}_{match['location']}"
        if key not in seen_keys:
            unique_matches.append(match)
            seen_keys.add(key)
    
    print(f"📊 After deduplication: {len(unique_matches)} unique matches")
    return unique_matches

# ====================================================================
# ARCHIVED: Tier 1/Tier 2 Matching Logic (No longer used - July 2025)
# ====================================================================
# This function was used to combine Tier 1 and Tier 2 data, but since
# we now only use Tier 2, this matching logic is no longer needed.
# ====================================================================

def match_tier1_tier2_ARCHIVED(tier1_matches, tier2_matches):
    """
    ARCHIVED: Tier 1/Tier 2 matching logic - no longer used
    
    Match Tier 1 and Tier 2 entries using date and organizer similarity
    """
    print("🔗 Matching Tier 1 and Tier 2 entries...")
    
    matched_matches = []
    unmatched_tier1 = []
    
    for tier1_match in tier1_matches:
        best_match = None
        best_similarity = 0
        
        for tier2_match in tier2_matches:
            # Check date similarity
            if tier1_match['date'] == tier2_match['date']:
                # Check organizer similarity
                org_similarity = similarity(tier1_match['organizer'], tier2_match['organizer'])
                
                if org_similarity > 0.5 and org_similarity > best_similarity:  # Lowered to 50% threshold
                    best_match = tier2_match
                    best_similarity = org_similarity
                    print(f"🔍 Potential match: {tier1_match['organizer'][:30]}... vs {tier2_match['organizer'][:30]}... (similarity: {org_similarity:.2f})")
        
        if best_match:
            # Use Tier 2 data but keep Tier 1 registration status if Tier 2 doesn't have it
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
            print(f"✅ Matched: {tier1_match['organizer']} -> {best_match['type']}")
        else:
            # Keep Tier 1 data as-is
            unmatched_tier1.append(tier1_match)
            print(f"⚠️ No Tier 2 match for: {tier1_match['organizer']}")
    
    # Add unmatched Tier 1 matches
    final_matches = matched_matches + unmatched_tier1
    
    print(f"📊 Matching results:")
    print(f"   - Matched: {len(matched_matches)}")
    print(f"   - Unmatched Tier 1: {len(unmatched_tier1)}")
    print(f"   - Total: {len(final_matches)}")
    
    return final_matches

def upload_to_firebase(matches):
    """Upload matches to Firebase Firestore"""
    if not db:
        print("❌ Firebase not initialized")
        return
    
    print("💾 Uploading matches to Firestore...")
    
    # Clear existing matches
    try:
        existing_matches = db.collection('matches').stream()
        for match in existing_matches:
            match.reference.delete()
        print("🗑️ Cleared existing matches")
    except Exception as e:
        print(f"⚠️ Error clearing existing matches: {e}")
    
    # Upload new matches
    for match in matches:
        try:
            # Convert date to string for Firestore
            match_data = match.copy()
            if hasattr(match_data['date'], 'isoformat'):
                match_data['date'] = match_data['date'].isoformat()
            elif isinstance(match_data['date'], str):
                # Already a string, keep as is
                pass
            else:
                # Convert to string if it's a date object
                match_data['date'] = str(match_data['date'])
            
            # Add timestamp
            match_data['created_at'] = datetime.now()
            
            # Add to Firestore
            db.collection('matches').add(match_data)
            print(f"➕ Added new match: {match['organizer']} - {match['date']}")
            
        except Exception as e:
            print(f"❌ Error uploading match {match.get('organizer', 'Unknown')}: {e}")
    
    print(f"💾 Uploaded {len(matches)} matches to Firestore")

def mark_past_matches_as_closed():
    """Mark matches with past dates as closed"""
    if not db:
        return
    
    try:
        today = datetime.now().date()
        
        # Get all matches
        matches_ref = db.collection('matches').stream()
        
        for match_doc in matches_ref:
            match_data = match_doc.to_dict()
            
            # Check if match date is in the past
            if 'date' in match_data:
                try:
                    if isinstance(match_data['date'], str):
                        match_date = datetime.strptime(match_data['date'], '%Y-%m-%d').date()
                    else:
                        match_date = match_data['date']
                    
                    if match_date < today:
                        # Update registration status to closed
                        match_doc.reference.update({
                            'registration_text': 'niet meer mogelijk',
                            'updated_at': datetime.now()
                        })
                        print(f"🔒 Marked past match as closed: {match_data.get('organizer', 'Unknown')}")
                        
                except Exception as e:
                    print(f"⚠️ Error processing match date: {e}")
                    
    except Exception as e:
        print(f"❌ Error marking matches as closed: {e}")

def export_matches_to_csv(tier1_matches, tier2_matches):
    """Export matches to CSV format (Tier 2 only since July 2025)"""
    output = io.StringIO()
    writer = csv.writer(output)
    
    # Write header
    writer.writerow(['Date', 'Organizer', 'Location', 'Type', 'Registration_Text', 'Remarks', 'Calendar_Type', 'Source'])
    
    # Write Tier 2 matches (our only data source)
    for match in tier2_matches:
        writer.writerow([
            match.get('date', ''),
            match.get('organizer', ''),
            match.get('location', ''),
            match.get('type', ''),
            match.get('registration_text', ''),
            match.get('remark', ''),  # Note: Tier 2 uses 'remark' not 'remarks'
            match.get('calendar_type', ''),
            f"ORWEJA {match.get('calendar_type', 'Unknown')} Calendar"
        ])
    
    return output.getvalue()

def convert_dates_to_strings(matches):
    """Convert date objects to strings for JSON serialization"""
    converted_matches = []
    for match in matches:
        converted_match = match.copy()
        if 'date' in converted_match and hasattr(converted_match['date'], 'isoformat'):
            converted_match['date'] = converted_match['date'].isoformat()
        elif 'date' in converted_match and hasattr(converted_match['date'], 'strftime'):
            converted_match['date'] = converted_match['date'].strftime('%Y-%m-%d')
        converted_matches.append(converted_match)
    return converted_matches

def upload_csv_to_storage(csv_data, filename):
    """Upload CSV data to Google Cloud Storage"""
    try:
        # Initialize storage client
        client = storage.Client()
        bucket_name = 'jachtproef-alert-exports'
        bucket = client.bucket(bucket_name)
        
        # Create blob
        blob = bucket.blob(filename)
        
        # Upload CSV data
        blob.upload_from_string(csv_data, content_type='text/csv')
        
        # Generate a signed URL (valid for 1 hour)
        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(hours=1),
            method="GET"
        )
        
        return signed_url
        
    except Exception as e:
        print(f"❌ Error uploading to storage: {e}")
        return None

@functions_framework.http
def main(request):
    """Main scraper function - Cloud Function entry point"""
    print("🚀 Starting JachtProef Alert Scraper...")
    print("=" * 50)
    
    # Check if CSV export is requested
    request_json = request.get_json(silent=True) or {}
    export_csv = request_json.get('export_all_data', False)
    
    # Initialize Firebase
    firebase_available = initialize_firebase()
    
    # Step 1: Scrape Tier 2 (protected calendars) - Our only data source
    tier2_matches = scrape_tier2_protected_calendars()
    
    if not tier2_matches:
        print("❌ No matches found in Tier 2")
        return json.dumps({"error": "No matches found in Tier 2"}), 200
    
    # Use Tier 2 matches as our final data source
    print("✅ Using Tier 2 only - cleaner and more accurate data source")
    final_matches = tier2_matches
    
    # Step 2: Upload to Firebase (if available and not just exporting)
    if firebase_available and final_matches and not export_csv:
        upload_to_firebase(final_matches)
        mark_past_matches_as_closed()
    
    # Step 3: Export to CSV if requested
    csv_content = None
    if export_csv:
        csv_content = export_matches_to_csv([], tier2_matches)  # Empty Tier 1 list
        print("📊 Preparing match data for export...")
    
    print("=" * 50)
    print("🎉 Scraper completed successfully!")
    print(f"📊 Tier 2 matches: {len(tier2_matches)}")
    print(f"📊 Final matches: {len(final_matches)}")
    print("=" * 50)
    
    # Return success response
    result = {
        'success': True,
        'tier2_matches': len(tier2_matches),
        'tier2_breakdown': {
            'veldwedstrijd': len([m for m in tier2_matches if m.get('calendar_type') == 'Veldwedstrijd']),
            'jachthondenproef': len([m for m in tier2_matches if m.get('calendar_type') == 'Jachthondenproef']),
            'orweja_werktest': len([m for m in tier2_matches if m.get('calendar_type') == 'ORWEJA Werktest'])
        },
        'final_matches': len(final_matches),
        'matches_uploaded': len(final_matches),
        'scraper_version': 'tier2_only',
        'timestamp': datetime.now().isoformat()
    }
    
    # If CSV export is requested, include the actual match data
    if export_csv:
        # Convert dates to strings for JSON serialization
        tier2_data_serializable = convert_dates_to_strings(tier2_matches)
        
        result["tier2_data"] = tier2_data_serializable
        result["has_match_data"] = True
    
    return json.dumps(result), 200 