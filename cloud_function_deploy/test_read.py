#!/usr/bin/env python3
"""
Simple test to read from Firestore and see what's there
"""
import firebase_admin
from firebase_admin import credentials, firestore
import functions_framework

@functions_framework.http
def test_read(request):
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