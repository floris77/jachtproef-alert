#!/usr/bin/env python3
"""
Test script to send example match notification emails
"""
import requests
import json

def test_match_emails():
    """Send example match notification emails"""
    
    # Cloud function URL
    url = "https://us-central1-jachtproefalert.cloudfunctions.net/send-match-notification"
    
    # Test data for enrollment opening email
    enrollment_data = {
        "email": "floris@nordrobe.com",
        "matchTitle": "Nederlandse Labrador Vereniging",
        "matchLocation": "Lelystad, Flevoland", 
        "matchDate": "15 juni 2025",
        "notificationType": "enrollment_opening",
        "matchKey": "test_match_001"
    }
    
    # Test data for match reminder email
    reminder_data = {
        "email": "floris@nordrobe.com",
        "matchTitle": "KNJV Provincie Gelderland",
        "matchLocation": "Barneveld, Gelderland",
        "matchDate": "22 juni 2025", 
        "notificationType": "match_reminder",
        "matchKey": "test_match_002"
    }
    
    print("🧪 Testing Match Notification Emails")
    print("=" * 50)
    
    # Send enrollment opening email
    print("\n📧 Sending enrollment opening email...")
    try:
        response = requests.post(url, json=enrollment_data, headers={'Content-Type': 'application/json'})
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Enrollment email sent successfully!")
            print(f"   Email ID: {result.get('email_id', 'unknown')}")
        else:
            print(f"❌ Failed to send enrollment email: {response.status_code}")
            print(f"   Response: {response.text}")
    except Exception as e:
        print(f"❌ Error sending enrollment email: {e}")
    
    # Send match reminder email
    print("\n📧 Sending match reminder email...")
    try:
        response = requests.post(url, json=reminder_data, headers={'Content-Type': 'application/json'})
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Reminder email sent successfully!")
            print(f"   Email ID: {result.get('email_id', 'unknown')}")
        else:
            print(f"❌ Failed to send reminder email: {response.status_code}")
            print(f"   Response: {response.text}")
    except Exception as e:
        print(f"❌ Error sending reminder email: {e}")
    
    print(f"\n🎯 Check your inbox at floris@nordrobe.com")
    print(f"📧 You should receive 2 test emails:")
    print(f"   1. 🎯 Inschrijving geopend: Nederlandse Labrador Vereniging")
    print(f"   2. 📅 Herinnering: KNJV Provincie Gelderland is binnenkort")

if __name__ == "__main__":
    test_match_emails() 