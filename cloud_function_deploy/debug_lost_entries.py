#!/usr/bin/env python3
"""
Debug script to identify the exact entries lost between scraper count (162) and CSV export (142)
"""

import csv
import json
from collections import defaultdict
import requests
from bs4 import BeautifulSoup
import re
from datetime import datetime

def normalize_org(org):
    """Normalize organization name for comparison"""
    if not org:
        return ""
    
    # Convert to lowercase and remove common variations
    normalized = org.lower()
    
    # Remove email addresses and domains
    normalized = re.sub(r'\[email.*?protected\]', '', normalized)
    normalized = re.sub(r'@.*?\.(nl|com|org)', '', normalized)
    
    # Remove common prefixes/suffixes
    normalized = re.sub(r'\b(stichting|vereniging|club|nederland|nederlandse)\b', '', normalized)
    
    # Remove special characters and extra spaces
    normalized = re.sub(r'[^\w\s]', ' ', normalized)
    normalized = re.sub(r'\s+', ' ', normalized).strip()
    
    return normalized

def parse_date(date_text):
    """Parse date from various formats"""
    try:
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
        
        print(f"⚠️ Could not parse date: '{date_text}'")
        return None
        
    except Exception as e:
        print(f"⚠️ Date parsing error for '{date_text}': {e}")
        return None

def scrape_raw_tier1():
    """Scrape Tier 1 data and capture EVERYTHING before any filtering"""
    print("🔍 SCRAPING RAW TIER 1 DATA (NO FILTERING)")
    print("=" * 50)
    
    url = "https://my.orweja.nl/widget/kalender/"
    raw_entries = []
    valid_entries = []
    invalid_entries = []
    
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Find all table rows
        table = soup.find('table')
        if not table:
            print("❌ No table found")
            return [], [], []
            
        rows = table.find_all('tr')[1:]  # Skip header
        
        for i, row in enumerate(rows):
            cells = row.find_all('td')
            if len(cells) < 7:
                invalid_entries.append({
                    'index': i,
                    'reason': f'Not enough columns ({len(cells)}/7)',
                    'raw_data': [cell.get_text(strip=True) for cell in cells]
                })
                continue
            
            try:
                # Extract all data without any filtering
                date_text = cells[0].get_text(strip=True)
                match_type = cells[1].get_text(strip=True)
                organizer = cells[2].get_text(strip=True)
                location = cells[3].get_text(strip=True)
                contact = cells[4].get_text(strip=True)
                remarks = cells[5].get_text(strip=True)
                reg_status = cells[6].get_text(strip=True)
                
                # Parse date
                parsed_date = parse_date(date_text)
                
                raw_entry = {
                    'index': i,
                    'date_text': date_text,
                    'parsed_date': parsed_date,
                    'organizer': organizer,
                    'location': location,
                    'match_type': match_type,
                    'contact': contact,
                    'remarks': remarks,
                    'reg_status': reg_status,
                    'has_organizer': bool(organizer.strip()),
                    'has_location': bool(location.strip()),
                    'has_valid_date': parsed_date is not None
                }
                
                raw_entries.append(raw_entry)
                
                # Apply the same filtering logic as the real scraper
                if not organizer.strip() and not location.strip():
                    invalid_entries.append({
                        'index': i,
                        'reason': 'Empty organizer AND location',
                        'raw_data': raw_entry
                    })
                elif parsed_date is None:
                    invalid_entries.append({
                        'index': i,
                        'reason': 'Invalid date',
                        'raw_data': raw_entry
                    })
                else:
                    # This would be included in final data
                    valid_entries.append({
                        'date': parsed_date,
                        'organizer': organizer,
                        'location': location,
                        'registration_text': reg_status,
                        'type': match_type,
                        'source': 'tier1'
                    })
                
            except Exception as e:
                invalid_entries.append({
                    'index': i,
                    'reason': f'Parsing error: {e}',
                    'raw_data': [cell.get_text(strip=True) for cell in cells]
                })
    
    except Exception as e:
        print(f"❌ Error scraping: {e}")
        return [], [], []
    
    print(f"📊 Raw entries found: {len(raw_entries)}")
    print(f"📊 Valid entries: {len(valid_entries)}")
    print(f"📊 Invalid entries: {len(invalid_entries)}")
    
    return raw_entries, valid_entries, invalid_entries

def scrape_raw_tier2():
    """Scrape Tier 2 data with same logic"""
    print("\n🔍 SCRAPING RAW TIER 2 DATA")
    print("=" * 50)
    
    # This would need ORWEJA authentication - for now just return empty
    # since we're focusing on Tier 1 data loss
    return [], [], []

def analyze_lost_entries():
    """Main analysis function"""
    print("🕵️ DEBUGGING LOST ENTRIES")
    print("=" * 60)
    
    # Get raw data
    raw_tier1, valid_tier1, invalid_tier1 = scrape_raw_tier1()
    
    # Load existing CSV data for comparison
    csv_tier1_entries = set()
    try:
        with open('cloud_function_deploy/comprehensive_analysis_20250710_192149.csv', 'r') as f:
            reader = csv.reader(f)
            header = next(reader)
            
            for row in reader:
                if len(row) >= 6 and row[1].strip():  # Has tier1 organizer
                    date = row[0]
                    organizer = row[1]
                    csv_tier1_entries.add(f"{date}|{organizer}")
    except FileNotFoundError:
        print("❌ Could not find existing CSV file")
        return
    
    print(f"\n📊 COMPARISON RESULTS:")
    print(f"  Raw Tier 1 entries scraped: {len(raw_tier1)}")
    print(f"  Valid after filtering: {len(valid_tier1)}")
    print(f"  Invalid/filtered out: {len(invalid_tier1)}")
    print(f"  CSV Tier 1 entries: {len(csv_tier1_entries)}")
    
    # Show the invalid entries that were filtered out
    print(f"\n❌ ENTRIES FILTERED OUT ({len(invalid_tier1)}):")
    print("-" * 50)
    
    for i, entry in enumerate(invalid_tier1[:20]):  # Show first 20
        print(f"  {i+1}. Row {entry['index']}: {entry['reason']}")
        if isinstance(entry['raw_data'], dict):
            print(f"     Organizer: '{entry['raw_data']['organizer']}'")
            print(f"     Location: '{entry['raw_data']['location']}'")
            print(f"     Date: '{entry['raw_data']['date_text']}'")
        else:
            print(f"     Data: {entry['raw_data']}")
        print()
    
    # Check for duplicates in valid entries
    valid_unique_keys = set()
    duplicates = []
    
    for entry in valid_tier1:
        key = f"{entry['date']}|{entry['organizer']}"
        if key in valid_unique_keys:
            duplicates.append(entry)
        else:
            valid_unique_keys.add(key)
    
    if duplicates:
        print(f"\n🔄 DUPLICATE ENTRIES FOUND ({len(duplicates)}):")
        print("-" * 50)
        for i, dup in enumerate(duplicates[:10]):
            print(f"  {i+1}. {dup['organizer']} on {dup['date']}")
    
    print(f"\n✅ FINAL ANALYSIS:")
    print(f"  Expected total: {len(raw_tier1)}")
    print(f"  After filtering: {len(valid_tier1)}")
    print(f"  After deduplication: {len(valid_unique_keys)}")
    print(f"  Actual difference: {len(raw_tier1) - len(valid_unique_keys)}")

if __name__ == "__main__":
    analyze_lost_entries() 