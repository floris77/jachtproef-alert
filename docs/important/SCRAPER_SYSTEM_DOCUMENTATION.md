# JachtProef Alert - Scraper System Documentation

## Project Overview

**JachtProef Alert** is a Flutter mobile app that helps hunters find and track hunting test events (jachtproeven) in the Netherlands. The app automatically scrapes data from the ORWEJA website and provides users with notifications about new tests, registration openings, and deadlines.

## Why We Need the Scraper System

### The Problem
- **Manual Process**: Hunters had to manually check multiple websites for hunting test opportunities
- **Missed Opportunities**: Tests fill up quickly, and registration windows are often short
- **Scattered Information**: Test information is spread across different organizers and websites
- **Time-Sensitive**: Registration often opens at specific times and closes when full

### The Solution
- **Automated Monitoring**: Scrape ORWEJA website every 24 hours for new tests
- **Centralized Database**: Store all test information in Firebase Firestore
- **Smart Notifications**: Alert users about new tests and registration openings
- **Better UX**: Clean, mobile-friendly interface with search and filtering

## System Architecture

```
ORWEJA Website → Cloud Function (Scraper) → Firebase Firestore → Flutter App → Users
```

### Components:
1. **ORWEJA Scraper** (Python Cloud Function)
2. **Firebase Firestore** (Database)
3. **Flutter App** (iOS/Android)
4. **Firebase Authentication** (User management)

## Two-Tier Scraping System

### Overview
The scraper uses a sophisticated two-tier approach to get accurate data:

1. **Public Calendar** (Initial Data)
2. **Protected Calendar** (Override Data)

### Tier 1: Public Calendar
- **URL**: `https://my.orweja.nl/widget/kalender/`
- **Access**: No authentication required
- **Data Quality**: Many matches are incorrectly labeled as "KNJV"
- **Purpose**: Get initial list of all matches with basic information

### Tier 2: Protected Calendar (The Key Innovation)
- **URLs**: 
  - `https://my.orweja.nl/home/kalender/0` (Veldwedstrijden)
  - `https://my.orweja.nl/home/kalender/1` (Jachthondenproeven - **SJP classifications**)
  - `https://my.orweja.nl/home/kalender/2` (ORWEJA Workingtests)
- **Access**: Requires authentication (`Jacqueline vd Hart-Snelle` / `Jindi11Leia`)
- **Data Quality**: Correct, authoritative classifications
- **Purpose**: Override incorrect public data with correct classifications

### The Matching Algorithm
The scraper matches entries between public and protected calendars using:
- **Date matching** (primary key)
- **Organizer name matching** (60% similarity threshold with word-based comparison)
- **Simplified approach**: Removed complex location matching to avoid conflicts

### Classification System
- **MAP**: Jachthondenproef (Basic hunting dog test)
- **SJP**: Standaard Jachthondenproef (Standard hunting dog test) - **Critical for retrievers**
- **PJP**: Puppy Jachthondenproef
- **TAP**: Test Aanleg Proef
- **KAP**: Kwaliteit Aanleg Proef
- **SWT**: Stabyhoun Werktest
- **OWT**: ORWEJA Werktest

## Current Status (As of Session End)

### ✅ Working Components
- **Cloud Function**: `orweja-scraper` deployed in `europe-west1`
- **Project**: `jachtproefalert` (no hyphen)
- **Authentication**: Working properly with Orweja credentials
- **Data Processing**: Successfully processes ~79 matches, corrects ~36-37 classifications
- **Flutter App**: Successfully building and running
- **User Authentication**: Firebase Auth working correctly

### ⏳ In Progress
- **Firestore Security Rules**: Deployed but propagating (2-5 minutes)
- **Database Access**: App shows permission error, waiting for rules to take effect

### 🔧 Technical Details
- **Function Timeout**: 540 seconds
- **Memory**: 256MB
- **Schedule**: Every 24 hours (automatic)
- **Credentials**: Stored in function environment

## Key Files in Project

### Cloud Function
- `orweja_scraper_cloud_function.py` - Main scraper logic (latest version)
- `requirements.txt` - Python dependencies

### Firebase Configuration
- `firestore.rules` - Database security rules
- `firestore.indexes.json` - Database indexes
- `firebase.json` - Firebase project configuration

### Flutter App
- `lib/main.dart` - App entry point, Firebase config
- `lib/screens/proeven_main_page.dart` - Main app interface
- `lib/screens/login_screen.dart` - Authentication (with keyboard improvements)

## Troubleshooting Guide

### Database Permission Errors
**Symptoms**: App shows "Database Toegang Probleem"
**Cause**: Firestore security rules not deployed or still propagating
**Solution**: 
1. Check Firebase Console → Firestore → Rules
2. Ensure rules allow `allow read: if request.auth != null;` for matches collection
3. Wait 2-5 minutes for propagation

### No Data in App
**Symptoms**: "Geen Proeven Gevonden"
**Possible Causes**:
1. Cloud Function hasn't run yet (runs every 24h)
2. Orweja credentials expired
3. Orweja website structure changed

**Debug Steps**:
1. Check Cloud Function logs in Google Cloud Console
2. Manually trigger function (if possible)
3. Verify Orweja credentials still work

### Classification Issues (e.g., Gieten MAP→SJP)
**Root Cause**: Matching algorithm incorrectly pairs database entries with protected calendar entries
**Solution**: The simplified date+organizer matching should resolve this
**Debug**: Check function logs for "GIETEN MATCH" debug output

## Future Development Notes

### Immediate Tasks (Next Session)
1. ✅ Verify Firestore rules are working (try "Opnieuw Proberen" button)
2. 🔍 Check if data is being populated (might need to wait for next 24h cycle)
3. 🧪 Test that Gieten match shows as SJP (not MAP)
4. 📱 Test keyboard behavior in login form

### Potential Improvements
- Add manual refresh trigger for Cloud Function
- Implement push notifications for new matches
- Add user preference filtering
- Implement calendar integration
- Add match detail pages with maps/directions

## Security Notes
- **Orweja Credentials**: Never commit to git, stored in Cloud Function environment
- **Firebase Keys**: Public keys in code are OK (client-side), private keys in Cloud Console
- **Firestore Rules**: Properly restrict write access to Cloud Functions only

## Contact & Credentials
- **ORWEJA Account**: Jacqueline vd Hart-Snelle / Jindi11Leia
- **Firebase Project**: jachtproefalert
- **Cloud Function**: europe-west1-jachtproefalert.cloudfunctions.net/orweja-scraper

---

**Last Updated**: Current development session
**Status**: Core functionality working, waiting for Firestore rules propagation 