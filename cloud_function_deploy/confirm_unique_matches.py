#!/usr/bin/env python3
"""
Confirm unique, valid matches in Tier 1 (public calendar)
"""

import requests
from bs4 import BeautifulSoup
from datetime import datetime

def parse_date(date_text):
    formats = [
        '%d-%m-%Y', '%Y-%m-%d', '%d/%m/%Y', '%Y/%m/%d'
    ]
    for fmt in formats:
        try:
            return datetime.strptime(date_text.strip(), fmt)
        except Exception:
            continue
    return date_text

def confirm_unique_matches():
    url = "https://my.orweja.nl/widget/kalender/"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    response = requests.get(url, headers=headers, timeout=30)
    response.raise_for_status()
    soup = BeautifulSoup(response.content, 'html.parser')
    matches = []
    seen = set()
    for entry in soup.find_all('tr'):
        cells = entry.find_all('td')
        if len(cells) < 7:
            continue
        # Skip header row
        if cells[0].get_text(strip=True).lower() == 'datum':
            continue
        date_text = cells[0].get_text(strip=True)
        match_type = cells[1].get_text(strip=True)
        organizer = cells[2].get_text(strip=True)
        location = cells[3].get_text(strip=True)
        reg_status = cells[6].get_text(strip=True)
        # Use a tuple of (date, organizer, location) as a unique key
        key = (date_text, organizer, location)
        if key in seen:
            continue
        seen.add(key)
        matches.append({
            'date': date_text,
            'organizer': organizer,
            'location': location,
            'registration_text': reg_status,
            'type': match_type
        })
    print(f"✅ Unique, valid matches found: {len(matches)}")
    print("\nSample matches:")
    for i, match in enumerate(matches[:10]):
        print(f"  {i+1}. {match['date']} | {match['organizer']} | {match['location']} | {match['type']} | {match['registration_text']}")
    if len(matches) > 10:
        print(f"  ... and {len(matches)-10} more")
if __name__ == "__main__":
    confirm_unique_matches() 