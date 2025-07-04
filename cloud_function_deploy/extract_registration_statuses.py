import firebase_admin
from firebase_admin import credentials, firestore
from collections import Counter
import json
import argparse
from datetime import datetime

# Initialize Firebase (assumes GOOGLE_APPLICATION_CREDENTIALS is set)
if not firebase_admin._apps:
    firebase_admin.initialize_app()
db = firestore.client()

def convert_timestamps(obj):
    """Convert Firestore timestamps to strings for JSON serialization"""
    if isinstance(obj, dict):
        return {k: convert_timestamps(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [convert_timestamps(item) for item in obj]
    elif hasattr(obj, 'timestamp'):  # Firestore timestamp
        return obj.isoformat()
    else:
        return obj

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--export_json', help='Export to JSON file')
    parser.add_argument('--stringify_timestamps', action='store_true', help='Convert timestamps to strings')
    args = parser.parse_args()
    
    print("Fetching all matches from Firestore...")
    matches_ref = db.collection('matches')
    docs = matches_ref.stream()
    
    all_matches = []
    statuses = []
    all_fields = set()
    
    for doc in docs:
        data = doc.to_dict()
        all_fields.update(data.keys())
        
        reg_text = (
            data.get('registration_text') or
            (data.get('registration', {}).get('text') if isinstance(data.get('registration'), dict) else None) or
            ''
        )
        reg_text = reg_text.strip().lower()
        if reg_text:
            statuses.append(reg_text)
        else:
            statuses.append('[EMPTY]')
        
        all_matches.append(data)
    
    unique_statuses = sorted(set(statuses))
    print(f"\nUnique registration_text values found ({len(unique_statuses)}):")
    for status in unique_statuses:
        print(f"- {status}")
    
    print("\nStatus counts:")
    for status, count in Counter(statuses).most_common():
        print(f"{status}: {count}")
    
    print(f"\nTotal matches: {len(all_matches)}")
    print(f"\nAll available fields ({len(all_fields)}):")
    for field in sorted(all_fields):
        print(f"- {field}")
    
    if args.export_json:
        if args.stringify_timestamps:
            all_matches = convert_timestamps(all_matches)
        
        with open(args.export_json, 'w', encoding='utf-8') as f:
            json.dump(all_matches, f, indent=2, ensure_ascii=False)
        print(f"\nExported {len(all_matches)} matches to {args.export_json}")
        
        # Show sample structure
        if all_matches:
            print(f"\nSample match structure (first match):")
            print(json.dumps(all_matches[0], indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main() 