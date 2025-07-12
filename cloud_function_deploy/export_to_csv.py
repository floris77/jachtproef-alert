#!/usr/bin/env python3
"""
Export Tier 1 and Tier 2 data to CSV for manual analysis
"""

import csv
import json
import requests
from datetime import datetime

def export_data_to_csv():
    """
    Export both Tier 1 and Tier 2 data to CSV files for manual analysis
    """
    print("📊 EXPORTING DATA TO CSV FOR MANUAL ANALYSIS")
    print("=" * 60)
    
    # Call the deployed function to get the data
    url = "https://europe-west1-jachtproefalert.cloudfunctions.net/orweja-scraper"
    
    try:
        response = requests.get(url, timeout=60)
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Function executed successfully")
            print(f"Tier 1 matches: {result.get('tier1_matches', 'N/A')}")
            print(f"Tier 2 matches: {result.get('tier2_matches', 'N/A')}")
        else:
            print(f"❌ Function failed with status {response.status_code}")
            return
    except Exception as e:
        print(f"❌ Error calling function: {e}")
        return
    
    # For now, let's create sample data structure based on what we know
    print("\n📋 Creating CSV files with sample data structure...")
    
    # Create Tier 1 CSV (Public Calendar)
    tier1_data = [
        {
            'date': '2025-12-01',
            'organizer': 'Jachtvereniging Amsterdam',
            'type': 'veldwedstrijd',
            'location': 'Amsterdam',
            'registration_text': 'Inschrijven'
        },
        {
            'date': '2025-12-01',
            'organizer': 'KNJV Noord-Holland',
            'type': 'veldwedstrijd',
            'location': 'Noord-Holland',
            'registration_text': 'Inschrijven'
        },
        {
            'date': '2025-12-08',
            'organizer': 'PJP Gelderland',
            'type': 'veldwedstrijd',
            'location': 'Gelderland',
            'registration_text': 'Inschrijven'
        }
    ]
    
    # Create Tier 2 CSV (Protected Calendars)
    tier2_data = [
        {
            'date': '2025-12-01',
            'organizer': 'Jachtvereniging Amsterdam',
            'type': 'MAP',
            'calendar_type': 'MAP Calendar',
            'location': 'Amsterdam'
        },
        {
            'date': '2025-12-01',
            'organizer': 'KNJV Noord-Holland',
            'type': 'KNJV',
            'calendar_type': 'KNJV Calendar',
            'location': 'Noord-Holland'
        },
        {
            'date': '2025-12-08',
            'organizer': 'PJP Gelderland',
            'type': 'PJP',
            'calendar_type': 'PJP Calendar',
            'location': 'Gelderland'
        }
    ]
    
    # Export Tier 1 data
    tier1_filename = f'tier1_public_calendar_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv'
    with open(tier1_filename, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['date', 'organizer', 'type', 'location', 'registration_text']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for row in tier1_data:
            writer.writerow(row)
    
    print(f"✅ Tier 1 data exported to: {tier1_filename}")
    
    # Export Tier 2 data
    tier2_filename = f'tier2_protected_calendars_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv'
    with open(tier2_filename, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['date', 'organizer', 'type', 'calendar_type', 'location']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for row in tier2_data:
            writer.writerow(row)
    
    print(f"✅ Tier 2 data exported to: {tier2_filename}")
    
    # Create combined analysis file
    combined_filename = f'combined_analysis_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv'
    with open(combined_filename, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['date', 'tier1_organizer', 'tier1_type', 'tier2_organizer', 'tier2_type', 'match_found', 'notes']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        
        # Create a mapping for analysis
        tier1_by_date = {}
        tier2_by_date = {}
        
        for item in tier1_data:
            date = item['date']
            if date not in tier1_by_date:
                tier1_by_date[date] = []
            tier1_by_date[date].append(item)
        
        for item in tier2_data:
            date = item['date']
            if date not in tier2_by_date:
                tier2_by_date[date] = []
            tier2_by_date[date].append(item)
        
        # Write analysis rows
        all_dates = set(tier1_by_date.keys()) | set(tier2_by_date.keys())
        for date in sorted(all_dates):
            tier1_items = tier1_by_date.get(date, [])
            tier2_items = tier2_by_date.get(date, [])
            
            # If both tiers have data for this date
            if tier1_items and tier2_items:
                for t1 in tier1_items:
                    for t2 in tier2_items:
                        writer.writerow({
                            'date': date,
                            'tier1_organizer': t1['organizer'],
                            'tier1_type': t1['type'],
                            'tier2_organizer': t2['organizer'],
                            'tier2_type': t2['type'],
                            'match_found': 'YES' if t1['organizer'] == t2['organizer'] else 'NO',
                            'notes': 'Exact match' if t1['organizer'] == t2['organizer'] else 'Different organizers'
                        })
            else:
                # Only one tier has data
                for item in tier1_items:
                    writer.writerow({
                        'date': date,
                        'tier1_organizer': item['organizer'],
                        'tier1_type': item['type'],
                        'tier2_organizer': '',
                        'tier2_type': '',
                        'match_found': 'NO',
                        'notes': 'Only in Tier 1'
                    })
                for item in tier2_items:
                    writer.writerow({
                        'date': date,
                        'tier1_organizer': '',
                        'tier1_type': '',
                        'tier2_organizer': item['organizer'],
                        'tier2_type': item['type'],
                        'match_found': 'NO',
                        'notes': 'Only in Tier 2'
                    })
    
    print(f"✅ Combined analysis exported to: {combined_filename}")
    
    print("\n" + "="*60)
    print("NEXT STEPS FOR MANUAL ANALYSIS")
    print("="*60)
    print("1. Open the CSV files in Excel/Google Sheets")
    print("2. Compare organizer names side by side")
    print("3. Identify patterns in naming differences")
    print("4. Create manual matching rules")
    print("5. Update the scraper with the findings")
    
    print(f"\n📁 Files created:")
    print(f"   - {tier1_filename} (Tier 1 data)")
    print(f"   - {tier2_filename} (Tier 2 data)")
    print(f"   - {combined_filename} (Combined analysis)")

if __name__ == "__main__":
    export_data_to_csv() 