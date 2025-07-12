#!/usr/bin/env python3
"""
Compare backup Firebase data with new data after scraper replacement
This helps verify that the new scraper is working correctly
"""
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import json
import os
import sys

def load_backup_data(backup_filename):
    """Load backup data from JSON file"""
    try:
        with open(backup_filename, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Error loading backup file {backup_filename}: {e}")
        return None

def get_current_firebase_data():
    """Get current Firebase data"""
    try:
        if not firebase_admin._apps:
            firebase_admin.initialize_app()
        db = firestore.client()
        
        matches_ref = db.collection('matches')
        docs = list(matches_ref.stream())
        
        current_data = {
            'total_matches': len(docs),
            'matches': []
        }
        
        for doc in docs:
            data = doc.data()
            match_data = {
                'id': doc.id,
                'data': data
            }
            current_data['matches'].append(match_data)
        
        return current_data
    except Exception as e:
        print(f"❌ Error getting current Firebase data: {e}")
        return None

def compare_data(backup_data, current_data):
    """Compare backup data with current data"""
    print("🔍 Comparing backup data with current Firebase data...")
    print(f"📊 Backup: {backup_data['total_matches']} matches")
    print(f"📊 Current: {current_data['total_matches']} matches")
    
    # Count differences
    backup_count = backup_data['total_matches']
    current_count = current_data['total_matches']
    difference = current_count - backup_count
    
    print(f"\n📈 Match Count Changes:")
    print(f"   Difference: {difference:+d} matches")
    if difference > 0:
        print(f"   ✅ New scraper found {difference} more matches")
    elif difference < 0:
        print(f"   ⚠️ New scraper found {abs(difference)} fewer matches")
    else:
        print(f"   ➡️ Same number of matches")
    
    # Compare registration status distribution
    print(f"\n📋 Registration Status Comparison:")
    
    # Count registration statuses in backup
    backup_reg_statuses = {}
    for match in backup_data['matches']:
        data = match['data']
        reg_text = (
            data.get('registration_text') or
            (data.get('registration', {}).get('text') if isinstance(data.get('registration'), dict) else None) or
            ''
        ).strip().lower()
        backup_reg_statuses[reg_text] = backup_reg_statuses.get(reg_text, 0) + 1
    
    # Count registration statuses in current data
    current_reg_statuses = {}
    for match in current_data['matches']:
        data = match['data']
        reg_text = (
            data.get('registration_text') or
            (data.get('registration', {}).get('text') if isinstance(data.get('registration'), dict) else None) or
            ''
        ).strip().lower()
        current_reg_statuses[reg_text] = current_reg_statuses.get(reg_text, 0) + 1
    
    # Show status distribution
    all_statuses = set(backup_reg_statuses.keys()) | set(current_reg_statuses.keys())
    
    print(f"   Status Distribution:")
    for status in sorted(all_statuses):
        backup_count = backup_reg_statuses.get(status, 0)
        current_count = current_reg_statuses.get(status, 0)
        diff = current_count - backup_count
        print(f"     '{status}': {backup_count} → {current_count} ({diff:+d})")
    
    # Check for new match types (Tier 2 improvements)
    print(f"\n🎯 Match Type Analysis:")
    
    backup_types = set()
    current_types = set()
    
    for match in backup_data['matches']:
        match_type = match['data'].get('type', '').strip()
        if match_type:
            backup_types.add(match_type)
    
    for match in current_data['matches']:
        match_type = match['data'].get('type', '').strip()
        if match_type:
            current_types.add(match_type)
    
    new_types = current_types - backup_types
    removed_types = backup_types - current_types
    
    print(f"   Total unique types - Backup: {len(backup_types)}, Current: {len(current_types)}")
    
    if new_types:
        print(f"   ✅ New match types found: {', '.join(sorted(new_types))}")
    if removed_types:
        print(f"   ⚠️ Removed match types: {', '.join(sorted(removed_types))}")
    if not new_types and not removed_types:
        print(f"   ➡️ Same match types")
    
    # Check for KNJV → specific type improvements
    print(f"\n🔍 Tier 2 Improvements Check:")
    knjv_improvements = 0
    for match in current_data['matches']:
        data = match['data']
        current_type = data.get('type', '').strip()
        if current_type and current_type != 'KNJV' and 'KNJV' not in current_type:
            # This might be a Tier 2 improvement
            knjv_improvements += 1
    
    print(f"   Matches with specific types (not KNJV): {knjv_improvements}")
    print(f"   Percentage with specific types: {(knjv_improvements/current_data['total_matches']*100):.1f}%")
    
    # Overall assessment
    print(f"\n📊 Overall Assessment:")
    if current_count >= backup_count:
        print(f"   ✅ New scraper is working (found {current_count} matches)")
    else:
        print(f"   ⚠️ New scraper found fewer matches - investigate")
    
    if new_types:
        print(f"   ✅ Tier 2 system is working (found new specific types)")
    else:
        print(f"   ⚠️ No new specific types found - check Tier 2 scraping")
    
    if knjv_improvements > 0:
        print(f"   ✅ Specific match types are being assigned")
    else:
        print(f"   ⚠️ All matches still have generic types")

def main():
    """Main comparison function"""
    if len(sys.argv) != 2:
        print("Usage: python3 compare_backup_vs_new_data.py <backup_filename>")
        print("Example: python3 compare_backup_vs_new_data.py firebase_backup_20250106_143022.json")
        return
    
    backup_filename = sys.argv[1]
    
    if not os.path.exists(backup_filename):
        print(f"❌ Backup file not found: {backup_filename}")
        return
    
    print(f"📁 Loading backup from: {backup_filename}")
    backup_data = load_backup_data(backup_filename)
    if not backup_data:
        return
    
    print(f"🔍 Getting current Firebase data...")
    current_data = get_current_firebase_data()
    if not current_data:
        return
    
    compare_data(backup_data, current_data)

if __name__ == "__main__":
    main() 