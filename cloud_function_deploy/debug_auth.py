#!/usr/bin/env python3
"""
Debug ORWEJA authentication in detail
"""

import requests
from bs4 import BeautifulSoup
import json

# ORWEJA CREDENTIALS
ORWEJA_USERNAME = "Jacqueline vd Hart-Snelle"
ORWEJA_PASSWORD = "Jindi11Leia"

def debug_auth():
    """Debug ORWEJA authentication step by step"""
    print("🔐 Debugging ORWEJA authentication...")
    
    session = requests.Session()
    
    try:
        # Step 1: Get login page
        print("\n📄 Step 1: Getting login page...")
        login_url = "https://my.orweja.nl/login"
        response = session.get(login_url, timeout=30)
        print(f"   Status: {response.status_code}")
        print(f"   URL: {response.url}")
        
        # Save login page HTML
        with open("debug_login_page.html", 'w', encoding='utf-8') as f:
            f.write(str(response.content))
        print("   💾 Saved login page HTML")
        
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Step 2: Find login form
        print("\n📋 Step 2: Analyzing login form...")
        login_form = soup.find('form')
        if login_form:
            print(f"   Form action: {login_form.get('action', 'No action')}")
            print(f"   Form method: {login_form.get('method', 'No method')}")
            
            # Find all form inputs
            inputs = login_form.find_all('input')
            print(f"   Form inputs: {len(inputs)}")
            for inp in inputs:
                name = inp.get('name', 'No name')
                type_attr = inp.get('type', 'No type')
                value = inp.get('value', 'No value')
                print(f"     - {name} ({type_attr}): {value}")
        else:
            print("   ❌ No login form found!")
        
        # Step 3: Extract CSRF token
        print("\n🔑 Step 3: Extracting CSRF token...")
        csrf_token = soup.find('input', {'name': '_token'})
        if csrf_token:
            csrf_value = csrf_token['value']
            print(f"   CSRF token: {csrf_value[:20]}...")
        else:
            csrf_value = ''
            print("   ⚠️ No CSRF token found")
        
        # Step 4: Prepare login data
        print("\n📝 Step 4: Preparing login data...")
        login_data = {
            'email': ORWEJA_USERNAME,
            'password': ORWEJA_PASSWORD,
            '_token': csrf_value
        }
        print(f"   Login data: {login_data}")
        
        # Step 5: Submit login
        print("\n🚀 Step 5: Submitting login...")
        response = session.post(login_url, data=login_data, timeout=30, allow_redirects=True)
        print(f"   Status: {response.status_code}")
        print(f"   Final URL: {response.url}")
        print(f"   Content length: {len(response.content)}")
        
        # Save response HTML
        with open("debug_login_response.html", 'w', encoding='utf-8') as f:
            f.write(str(response.content))
        print("   💾 Saved login response HTML")
        
        # Step 6: Check if login was successful
        print("\n✅ Step 6: Checking login success...")
        
        # Try to access a protected page
        test_url = "https://my.orweja.nl/home/kalender/1"
        test_response = session.get(test_url, timeout=30)
        
        print(f"   Test URL: {test_url}")
        print(f"   Test status: {test_response.status_code}")
        print(f"   Test final URL: {test_response.url}")
        print(f"   Test content length: {len(test_response.content)}")
        
        # Save test response
        with open("debug_test_page.html", 'w', encoding='utf-8') as f:
            f.write(str(test_response.content))
        print("   💾 Saved test page HTML")
        
        # Check for login indicators
        if "login" in test_response.url.lower():
            print("   ❌ Still redirected to login page")
            return False
        elif len(test_response.content) < 10000:
            print("   ⚠️ Got small response - may not be logged in")
            return False
        else:
            print("   ✅ Appears to be logged in successfully")
            return True
            
    except Exception as e:
        print(f"❌ Authentication error: {e}")
        return False

if __name__ == "__main__":
    success = debug_auth()
    print(f"\n🎯 Authentication result: {'SUCCESS' if success else 'FAILED'}") 