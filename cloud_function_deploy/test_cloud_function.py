#!/usr/bin/env python3
"""
Test the deployed cloud function directly
"""
import requests
import json

def test_cloud_function():
    """Test our deployed subscription email function"""
    
    print("🔄 Testing deployed Cloud Function...")
    
    # Your function URL
    url = "https://us-central1-jachtproefalert.cloudfunctions.net/send-subscription-email"
    
    # Test data - using your email
    test_data = {
        "email": "floris@nordrobe.com",
        "subscription_type": "Monthly Premium",
        "amount": "3.99"
    }
    
    headers = {
        "Content-Type": "application/json"
    }
    
    print(f"📧 Sending test receipt to: {test_data['email']}")
    print(f"💰 Subscription: {test_data['subscription_type']} - €{test_data['amount']}")
    
    try:
        # Make the request
        response = requests.post(url, json=test_data, headers=headers)
        
        print(f"\n📊 Response Status: {response.status_code}")
        
        if response.status_code == 200:
            try:
                result = response.json()
                print("✅ SUCCESS! Cloud Function working!")
                print(f"   Message: {result.get('message', 'No message')}")
                print(f"   Email ID: {result.get('email_id', 'No ID')}")
                print(f"🎯 Check your inbox at floris@nordrobe.com for the subscription receipt!")
            except json.JSONDecodeError:
                print(f"✅ Request successful but response not JSON: {response.text}")
        else:
            print(f"❌ Error {response.status_code}: {response.text}")
            
    except Exception as e:
        print(f"❌ Request failed: {e}")

if __name__ == "__main__":
    test_cloud_function() 