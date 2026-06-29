# Trip Manager — Setup Guide

## 1. Prerequisites
- Flutter SDK >= 3.0.0
- Android Studio or VS Code with Flutter extension
- A Supabase account (free tier works)
- OpenWeatherMap API key (free)
- Google Maps API key (requires billing but has free quota)

---

## 2. Clone / Extract Project
Extract this zip into your projects folder, e.g.:
```
C:\Users\Abhay\Documents\trip_app\
```

---

## 3. Supabase Setup
//S@g@r08102304->db pass
1. Go to https://supabase.com and create a new project
2. Open **SQL Editor** in your Supabase dashboard
3. Paste and run the entire contents of `supabase_schema.sql`
4. Go to **Project Settings → API** and copy:
   - Project URL
   //https://sokmutpbprcdvfwvhlns.supabase.co/rest/v1/
   - anon/public key
   // eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNva211dHBicHJjZHZmd3ZobG5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwNjA2NTAsImV4cCI6MjA5NjYzNjY1MH0.5A81sWthSsk2-YRa2pZIg7Zac8Z5QQU6teNmLrHiEFY

---

## 4. API Keys
Edit `.env` in the project root and fill in your keys:
```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
OPENWEATHER_API_KEY=your_key_here
GOOGLE_MAPS_API_KEY=AIzaSyBkwNm8vWjtj_i4wSttd8v4m12l3jO098Y
```

---

## 5. Google Maps Platform Config

### Android
Open `android/app/src/main/AndroidManifest.xml` and add inside `<application>`:
```xml
<meta-data
  android:name="com.google.android.geo.API_KEY"
  android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

Also add these permissions before `<application>`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

Set `minSdkVersion` to 21 in `android/app/build.gradle`:
```gradle
minSdkVersion 21
```

### iOS
Open `ios/Runner/AppDelegate.swift` and add:
```swift
import GoogleMaps
// inside application(_:didFinishLaunchingWithOptions:)
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

In `ios/Runner/Info.plist` add:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Trip Manager needs your location for live tracking.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Trip Manager needs background location for active trips.</string>
```

---

## 6. Install Dependencies & Run
```bash
cd trip_app
flutter pub get
flutter run
```

---

## 7. Create Admin User
After running the app, sign up normally. Then in Supabase:
1. Go to **Table Editor → users**
2. Find your user row and change `role` from `user` to `admin`

---

## App Flow Summary
```
Login / Signup
    ↓
[Driver]                        [Admin]
Request Trip                    Dashboard (tabs: Pending/Approved/Rejected/Ongoing)
  → Auto-fetch weather+road         ↓
  → Status: Pending             Review & Decide screen
                                  → Re-fetch live conditions
[Driver]                          → Approve / Reject
Approved → Select Vehicle             ↓
→ Fill Declaration             [Driver sees: Approved]
→ Start Journey (GPS on)        Select Vehicle
→ End Trip                      → Fill Declaration
                                → Start Journey
                             [Admin]
                             Track Live (Google Maps)
```
