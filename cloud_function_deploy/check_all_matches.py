import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
if not firebase_admin._apps:
    firebase_admin.initialize_app()
db = firestore.client()

def main():
    print("Fetching all matches from Firestore...")
    matches_ref = db.collection('matches')
    docs = list(matches_ref.stream())
    
    print(f"Total matches in Firestore: {len(docs)}")
    
    # Get all registration_text values
    reg_texts = []
    for doc in docs:
        data = doc.to_dict()
        reg_text = data.get('registration_text', '').strip()
        reg_texts.append(reg_text)
    
    # Count unique values
    unique_reg_texts = set(reg_texts)
    print(f"Unique registration_text values: {len(unique_reg_texts)}")
    
    # Show all unique values
    print("\nAll unique registration_text values:")
    for i, text in enumerate(sorted(unique_reg_texts), 1):
        count = reg_texts.count(text)
        print(f"{i:2d}. \"{text}\" (appears {count} times)")
    
    # Check for any empty or missing values
    empty_count = reg_texts.count('')
    print(f"\nEmpty registration_text values: {empty_count}")
    
    if empty_count > 0:
        print("Matches with empty registration_text:")
        for doc in docs:
            data = doc.to_dict()
            if not data.get('registration_text', '').strip():
                print(f"  {doc.id}: {data.get('organizer', 'Unknown')}")

if __name__ == "__main__":
    main() 