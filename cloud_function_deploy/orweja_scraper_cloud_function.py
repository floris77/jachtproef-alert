#!/usr/bin/env python3
"""
Enhanced Orweja scraper for Google Cloud Functions
Uses default authentication instead of service account key
Fixes issue where retriever clubs are incorrectly classified as MAP instead of SJP
Includes multi-URL scraping with protected calendar override system
"""
import requests
from bs4 import BeautifulSoup
import json
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import functions_framework

# ORWEJA CREDENTIALS for protected calendar access
ORWEJA_USERNAME = "Jacqueline vd Hart-Snelle"
ORWEJA_PASSWORD = "Jindi11Leia"

# Initialize Firebase with default credentials for the correct project
try:
    # Use default credentials when running in Cloud Functions
    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    db = firestore.client()
except Exception as e:
    print(f"Firebase initialization error: {e}")
    db = None

@functions_framework.http
def test_read(request):
    """Simple test to read from Firestore and see what's there"""
    try:
        # Initialize Firebase
        if not firebase_admin._apps:
            firebase_admin.initialize_app()
        db = firestore.client()
        
        # Try to read from matches collection
        matches_ref = db.collection('matches')
        docs = matches_ref.limit(5).stream()
        
        matches = []
        for doc in docs:
            data = doc.to_dict()
            matches.append({
                'id': doc.id,
                'organizer': data.get('organizer', 'Unknown'),
                'location': data.get('location', 'Unknown'),
                'type': data.get('type', 'Unknown'),
                'date': str(data.get('date', 'Unknown'))
            })
        
        return {
            'status': 'success',
            'count': len(matches),
            'matches': matches
        }
        
    except Exception as e:
        return {
            'status': 'error',
            'error': str(e)
        }

# ... existing code ... 