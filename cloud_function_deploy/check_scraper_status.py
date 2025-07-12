#!/usr/bin/env python3
"""
Check Google Cloud Function scraper status
"""
import requests
import json
from datetime import datetime

def check_scraper_status():
    """Check if the scraper is running by calling the Cloud Function"""
    
    # Cloud Function URL (from documentation)
    function_url = "https://europe-west1-jachtproefalert.cloudfunctions.net/orweja-scraper"
    
    print("🔍 Checking scraper status...")
    print(f"📡 Calling: {function_url}")
    
    try:
        # Make a simple GET request to check if function is accessible
        response = requests.get(function_url, timeout=30)
        
        print(f"📊 Response Status: {response.status_code}")
        
        if response.status_code == 200:
            try:
                data = response.json()
                print("✅ Scraper function is accessible!")
                print(f"📋 Response: {json.dumps(data, indent=2)}")
            except json.JSONDecodeError:
                print("⚠️ Function responded but not with JSON")
                print(f"📄 Response text: {response.text[:200]}...")
        else:
            print(f"❌ Function returned status {response.status_code}")
            print(f"📄 Response: {response.text}")
            
    except requests.exceptions.Timeout:
        print("⏰ Function timed out (this might be normal if it's processing)")
    except requests.exceptions.ConnectionError:
        print("❌ Could not connect to function")
        print("   This could mean:")
        print("   - Function is not deployed")
        print("   - URL is incorrect")
        print("   - Network issue")
    except Exception as e:
        print(f"❌ Error checking scraper: {e}")

def check_cloud_scheduler():
    """Provide instructions for checking Cloud Scheduler"""
    print("\n📅 To check if the scraper is scheduled to run:")
    print("1. Go to Google Cloud Console")
    print("2. Navigate to: Cloud Scheduler")
    print("3. Look for job: 'orweja-scraper-job'")
    print("4. Check if it's enabled and running")
    print("5. View execution history")

def check_function_logs():
    """Provide instructions for checking function logs"""
    print("\n📋 To check scraper function logs:")
    print("1. Go to Google Cloud Console")
    print("2. Navigate to: Cloud Functions")
    print("3. Find function: 'orweja-scraper'")
    print("4. Click on 'Logs' tab")
    print("5. Look for recent executions")
    print("6. Check for any error messages")

if __name__ == "__main__":
    check_scraper_status()
    check_cloud_scheduler()
    check_function_logs()
    
    print("\n🎯 Summary:")
    print("- If function is accessible: Scraper is deployed")
    print("- If scheduler is enabled: Scraper runs every 24 hours")
    print("- If logs show recent activity: Scraper is working")
    print("- If no recent logs: Scraper may not be running") 