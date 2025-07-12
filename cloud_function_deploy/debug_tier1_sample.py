#!/usr/bin/env python3
"""
Debug script to examine Tier 1 data structure and show sample matches
"""

import requests
from bs4 import BeautifulSoup
from datetime import datetime

def scrape_tier1_sample():
    """Scrape Tier 1 and show sample data"""
    print("🔍 Tier 1: Scraping public calendar for sample data...")
    
    url = "https://my.orweja.nl/widget/kalender/"
    
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Save HTML for inspection
        with open("debug_tier1_public.html", 'w', encoding='utf-8') as f:
            f.write(str(soup))
        print("💾 Saved Tier 1 HTML to debug_tier1_public.html")
        
        # Look for tables
        tables = soup.find_all('table')
        print(f"📊 Found {len(tables)} tables")
        
        matches = []
        
        for i, table in enumerate(tables):
            print(f"\n📋 Table {i+1}:")
            rows = table.find_all('tr')
            print(f"   Rows: {len(rows)}")
            
            if rows:
                # Show first few rows
                for j, row in enumerate(rows[:5]):
                    cells = row.find_all(['td', 'th'])
                    cell_texts = [cell.get_text(strip=True) for cell in cells]
                    print(f"   Row {j+1}: {cell_texts}")
                    
                    # Parse as match if it has enough cells
                    if len(cells) >= 4:
                        try:
                            date_text = cells[0].get_text(strip=True)
                            organizer = cells[1].get_text(strip=True)
                            location = cells[2].get_text(strip=True)
                            reg_status = cells[3].get_text(strip=True)
                            match_type = cells[4].get_text(strip=True) if len(cells) > 4 else "KNJV"
                            
                            match_data = {
                                'date': date_text,
                                'organizer': organizer,
                                'location': location,
                                'registration_text': reg_status,
                                'type': match_type
                            }
                            matches.append(match_data)
                            
                        except Exception as e:
                            print(f"   ⚠️ Error parsing row {j+1}: {e}")
        
        print(f"\n📊 Parsed {len(matches)} matches from Tier 1")
        
        # Show sample matches
        print("\n📄 Sample matches:")
        for i, match in enumerate(matches[:10]):
            print(f"   {i+1}. {match['organizer']} - {match['date']} - {match['type']} - {match['registration_text']}")
        
        return matches
        
    except Exception as e:
        print(f"❌ Tier 1 scraping error: {e}")
        return []

if __name__ == "__main__":
    scrape_tier1_sample() 