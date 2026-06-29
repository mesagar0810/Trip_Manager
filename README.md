# trip_manager

A premium, modern Flutter web and mobile application designed to manage, approve, and track driver journeys in real-time. Built with a robust backend using Supabase, advanced mapping via Google Maps API, real-time telemetry, and role-based access control.
---
## 🚀 Key Features
### 👨‍✈️ Driver / User Experience
- **Login / Signup**: Secure account creation and login with session persistence.
- **Weather-Aware Trip Requests**: Drivers can request trips between locations. The app automatically fetches current weather conditions at the source and destination via OpenWeatherMap.
- **Smart Autocomplete Suggestions**: Built-in autocomplete for source/destination searches. Custom registered places (e.g., remote villages) are prioritized at the top of suggestions with a special pin icon (`📍 Name`).
- **Vehicle Selection**: Drivers select a vehicle for approved trips and can register new vehicles on the fly if needed.
- **Safety Self-Declaration**: Mandatory health and safety declaration form submission before starting a trip.
- **Journey Tracking**:
  - Location tracking triggers automatically once a journey starts.
  - Coordinates are synchronized to Supabase every **1 km** of movement.
  - A periodic **10-minute backup timer** ensures telemetry is posted even if stationary or if the mobile browser freezes JavaScript stream execution.
  - **Background Sharing**: Telemetry runs continuously in the background and only stops when the driver explicitly ends the trip.
### 👑 Admin Management & Live Control Room
- **Trip Review Console**: Admins review requested trips with full details, weather status, and planned routes before choosing to approve or reject them.
- **Live Tracking Control Center**:
  - Interactive Google Map showcasing the real-time position of all ongoing journeys.
  - **Premium Custom Visual Markers**: Custom-drawn, high-DPI teardrop pins for Start (`S`, Green) and End (`E`, Red) coordinates with 3D gradients and drop shadows.
  - **Compass-Oriented Driver Dot**: A pulsing radar-style driver dot featuring a glowing blue accuracy beam (cone of light) and a white chevron arrow that dynamically rotates based on the driver's heading of travel.
  - **Smart Route Segments**: Renders the historical traveled path as a solid dark-blue line, and the remaining optimized route (from the driver's current position to the destination) as a light-blue dashed line without overlapping the traveled path.
- **Driver Management**: Deactivate, reactivate, and oversee driver profiles.
- **Vehicle Management**: Register, view, and inspect all fleet vehicles.
- **Custom Location Manager**: Register remote villages or coordinates with custom display names to skip Google Geocoding errors and guarantee seamless routing.
---
## 🛠 Tech Stack
- **Frontend**: Flutter SDK (Cross-platform Web/Mobile)
- **Backend & Database**: Supabase (PostgreSQL, Realtime Streams, Auth, Row-Level Security)
- **Routing & State**: GoRouter (declarative routing with role guards)
- **APIs & SDKs**:
  - Google Maps Flutter SDK (Interactive Maps)
  - Google Maps JavaScript SDK (CORS-safe autocomplete and directions on Web via JS Interop)
  - OpenWeatherMap API (Weather metadata)
---
## 📦 Directory Structure
```
lib/
├── main.dart                 # Application entry point & session auto-login initializer
├── models/                   # Dart data models (Trip, TripLog, Vehicle, User)
├── screens/
│   ├── auth/                 # Login and Signup screens
│   ├── user/                 # User/Driver screens (Home, Request Trip, Journey, Vehicle Select)
│   └── admin/                # Admin screens (Dashboard, Review, Manage Drivers/Vehicles/Locations, Live Track)
├── services/                 # Supabase interop, Geolocator configuration, Weather fetches
├── theme/                    # App color tokens and premium dark/light theme definitions
└── utils/                    # App router config, helper functions, and constants
```
---
## 🔑 Environment Setup
Create a `.env` file in the root of the project with the following properties:
```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-supabase-anonymous-key
OPENWEATHER_API_KEY=your-open-weather-map-api-key
GOOGLE_MAPS_API_KEY=your-google-maps-api-key
```
---
## 🗄 Database Schema
The PostgreSQL database setup involves running the schema files in your Supabase SQL Editor:
1. **[supabase_schema.sql](file:///Users/sagarchaudhary/Downloads/trip_app/supabase_schema.sql)**: Sets up tables for `users`, `trips`, `trip_logs`, and `location_history`. Defines basic status enums and trigger functions.
2. **[supabase_locations_schema.sql](file:///Users/sagarchaudhary/Downloads/trip_app/supabase_locations_schema.sql)**: Creates the custom `locations` table allowing admins to save specific coordinate zones (such as rural villages) with display names. Includes Row Level Security (RLS) configurations.
3. **[supabase_vehicles_policy.sql](file:///Users/sagarchaudhary/Downloads/trip_app/supabase_vehicles_policy.sql)**: Configures RLS rules for the `vehicles` table, granting drivers the ability to insert vehicles during trip setup.
---
## 🛡 Security & Role-Based Routing
The app enforces strict role-based access controls (RBAC) via GoRouter guards defined in [app_router.dart](file:///Users/sagarchaudhary/Downloads/trip_app/lib/utils/app_router.dart):
* **Authentication Guard**: Unauthenticated users are strictly locked to the `/login` or `/signup` routes.
* **Admin-Route Protection**: Accessing any path starting with `/admin` is restricted to users with the `admin` role. Non-admin users are automatically redirected back to `/home`.
* **User-Route Protection**: Admins are prevented from loading user-specific screen layouts to prevent state anomalies and are automatically redirected back to the `/admin` dashboard.
* **Auto-Login Role-Bypass**: Users who open the app with persistent login sessions are automatically forwarded to `/admin` or `/home` depending on their role.
---
## 🔧 Installation & Build
### 1. Install dependencies
```bash
flutter pub get
```
### 2. Run Locally (Development)
```bash
flutter run
```
### 3. Build Release for Web
```bash
flutter build web --release
```
### 4. Deploy Web App to Vercel
```bash
cd build/web
npx vercel --prod --yes
```
