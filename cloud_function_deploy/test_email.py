#!/usr/bin/env python3
"""
Test script for the subscription email function
"""
import requests
import json
import subprocess

def get_auth_token():
    """Get authentication token using gcloud"""
    try:
        gcloud_path = '/Users/florisvanderhart/Documents/jachtproef_alert/desktop/google-cloud-sdk/bin/gcloud'
        result = subprocess.run([gcloud_path, 'auth', 'print-access-token'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
        else:
            print(f"Error getting token: {result.stderr}")
            return None
    except Exception as e:
        print(f"Error getting token: {e}")
        return None

def test_subscription_email():
    """Test the subscription email function"""
    
    # Get authentication token
    token = get_auth_token()
    if not token:
        print("❌ Could not get authentication token")
        return
    
    # Function URL
    url = "https://us-central1-jachtproefalert.cloudfunctions.net/send-subscription-email"
    
    # Test data
    test_data = {
        "email": "floris@nordrobe.com",  # Using verified email for testing
        "subscription_type": "Monthly Premium",
        "amount": "3.99"
    }
    
    # Headers
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }
    
    print("🔄 Testing subscription email function...")
    print(f"📧 Test email: {test_data['email']}")
    
    try:
        response = requests.post(url, json=test_data, headers=headers)
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            result = response.json()
            if result.get('status') == 'success':
                print("✅ Email function test successful!")
                print(f"   Message: {result.get('message')}")
                print(f"   Email ID: {result.get('email_id')}")
            else:
                print(f"❌ Function returned error: {result}")
        else:
            print(f"❌ HTTP Error: {response.status_code}")
            print(f"   Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Request failed: {e}")

if __name__ == "__main__":
    test_subscription_email() 