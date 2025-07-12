#!/usr/bin/env python3
"""
Debug script to examine Tier 2 (protected calendar) HTML structure
"""

import requests
from bs4 import BeautifulSoup
import json

# ORWEJA CREDENTIALS
ORWEJA_USERNAME = "Jacqueline vd Hart-Snelle"
ORWEJA_PASSWORD = "Jindi11Leia"

def authenticate_orweja():
    """Authenticate with ORWEJA"""
    print("🔐 Authenticating with ORWEJA...")
    
    session = requests.Session()
    
    try:
        # Get login page
        login_url = "https://my.orweja.nl/login"
        response = session.get(login_url, timeout=30)
        response.raise_for_status()
        
        # Extract CSRF token if needed
        soup = BeautifulSoup(response.content, 'html.parser')
        csrf_token = soup.find('input', {'name': '_token'})
        csrf_value = csrf_token['value'] if csrf_token else ''
        
        # Login data
        login_data = {
            'email': ORWEJA_USERNAME,
            'password': ORWEJA_PASSWORD,
            '_token': csrf_value
        }
        
        # Submit login
        response = session.post(login_url, data=login_data, timeout=30)
        
        if response.status_code == 200:
            print("✅ ORWEJA authentication successful")
            return session
        else:
            print(f"❌ ORWEJA authentication failed: {response.status_code}")
            return None
            
    except Exception as e:
        print(f"❌ ORWEJA authentication error: {e}")
        return None

def debug_protected_calendar(url, calendar_name):
    """Debug a specific protected calendar page"""
    print(f"\n🔍 Debugging: {calendar_name}")
    print(f"URL: {url}")
    
    session = authenticate_orweja()
    if not session:
        return
    
    try:
        response = session.get(url, timeout=30)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.content, 'html.parser')
        
        print(f"📄 Response status: {response.status_code}")
        print(f"📄 Content length: {len(response.content)} characters")
        
        # Look for tables
        tables = soup.find_all('table')
        print(f"📊 Found {len(tables)} tables")
        
        for i, table in enumerate(tables):
            print(f"\n📋 Table {i+1}:")
            rows = table.find_all('tr')
            print(f"   Rows: {len(rows)}")
            
            if rows:
                # Show first few rows
                for j, row in enumerate(rows[:3]):
                    cells = row.find_all(['td', 'th'])
                    cell_texts = [cell.get_text(strip=True) for cell in cells]
                    print(f"   Row {j+1}: {cell_texts}")
        
        # Look for other potential containers
        divs = soup.find_all('div', class_=lambda x: x and ('match' in x.lower() or 'event' in x.lower() or 'calendar' in x.lower()))
        print(f"\n📋 Found {len(divs)} divs with match/event/calendar classes")
        
        # Look for any elements with dates
        date_elements = soup.find_all(text=re.compile(r'\d{1,2}-\d{1,2}-\d{4}'))
        print(f"📅 Found {len(date_elements)} elements with date patterns")
        
        # Save HTML for manual inspection
        with open(f"debug_{calendar_name.lower().replace(' ', '_')}.html", 'w', encoding='utf-8') as f:
            f.write(str(soup))
        print(f"💾 Saved HTML to debug_{calendar_name.lower().replace(' ', '_')}.html")
        
    except Exception as e:
        print(f"❌ Error debugging {calendar_name}: {e}")

def main():
    """Debug all protected calendars"""
    print("🚀 Starting Tier 2 Debug...")
    
    protected_urls = [
        ("https://my.orweja.nl/home/kalender/0", "Veldwedstrijd"),
        ("https://my.orweja.nl/home/kalender/1", "Jachthondenproef"),
        ("https://my.orweja.nl/home/kalender/2", "ORWEJA Werktest")
    ]
    
    for url, calendar_name in protected_urls:
        debug_protected_calendar(url, calendar_name)

if __name__ == "__main__":
    import re
    main() 