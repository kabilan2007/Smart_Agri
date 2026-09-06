# Smart Agri 🌱 — Full-Stack AI Agricultural Assistant

> **An intelligent, voice-enabled AI farming companion for young & modern farmers**

Built with **Flutter** (Frontend) + **Python FastAPI** (Backend) + **Google Gemini AI** + **OpenWeatherMap**

---

## 📁 Project Structure

```
Smart_Agri/
├── backend/                         # Python FastAPI AI Backend
│   ├── app/
│   │   ├── __init__.py
│   │   ├── config.py                # Environment settings & API keys
│   │   ├── main.py                  # FastAPI app with all API routes
│   │   ├── models/
│   │   │   └── schemas.py           # Pydantic request/response schemas
│   │   └── services/
│   │       ├── weather_service.py   # OpenWeatherMap + GPS alert engine
│   │       ├── crop_recommendation_service.py  # Season/Soil AI advisor
│   │       ├── gemini_service.py    # Gemini AI Agri Chatbot
│   │       ├── disease_detection_service.py    # Gemini Vision leaf scanner
│   │       └── market_service.py   # e-NAM / Agmarknet market rates
│   ├── .env.example                 # Environment variable template
│   ├── requirements.txt             # Python dependencies
│   └── run.py                       # Start server script
│
└── frontend/                        # Flutter Mobile App (Android & iOS)
    ├── lib/
    │   ├── main.dart                # App entry point, Splash Screen, Providers
    │   ├── constants/
    │   │   ├── colors.dart          # Emerald green agricultural color palette
    │   │   └── theme.dart           # Material 3 light/dark theme definitions
    │   ├── models/                  # Dart strongly-typed API models
    │   │   ├── weather_model.dart
    │   │   ├── crop_recommendation_model.dart
    │   │   ├── chat_message_model.dart
    │   │   ├── disease_detection_model.dart
    │   │   └── market_rate_model.dart
    │   ├── services/
    │   │   ├── api_service.dart     # HTTP client for all backend API calls
    │   │   ├── localization_service.dart  # 7-language multilingual service
    │   │   ├── location_service.dart      # GPS location with permission handling
    │   │   └── tts_stt_service.dart       # Voice input/output service
    │   └── screens/
    │       ├── dashboard_screen.dart      # Main home: Weather, Quick Actions, Crops
    │       ├── ai_chat_screen.dart        # Gemini AI 24/7 Agri Chatbot
    │       ├── disease_detection_screen.dart  # Plant disease CV scanner
    │       ├── crop_recommendation_screen.dart # Soil/season crop advisor
    │       └── market_rates_screen.dart   # Live mandi price index
    └── pubspec.yaml                 # Flutter dependencies
```

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version |
|------|---------|
| Python | ≥ 3.10 |
| Flutter SDK | ≥ 3.19.0 |
| Android Studio / Xcode | Latest |
| Google Gemini API Key | [Get here](https://aistudio.google.com/) |
| OpenWeatherMap API Key | [Get here](https://openweathermap.org/api) |

---

## 🐍 Backend Setup (Python FastAPI)

### Step 1 — Create & Activate Virtual Environment

```bash
cd Smart_Agri/backend

# Windows
python -m venv venv
venv\Scripts\activate

# macOS / Linux
python3 -m venv venv
source venv/bin/activate
```

### Step 2 — Install Dependencies

```bash
pip install -r requirements.txt
```

### Step 3 — Configure API Keys

```bash
# Copy the template
copy .env.example .env     # Windows
cp .env.example .env       # macOS/Linux
```

Open `.env` and fill in your API keys:

```env
GEMINI_API_KEY=your_actual_gemini_api_key_here
OPENWEATHER_API_KEY=your_actual_openweather_api_key_here
```

### Step 4 — Run the Backend Server

```bash
python run.py
```

You'll see:
```
🌱 Starting Smart Agri Backend API on http://0.0.0.0:8000
📖 Swagger Interactive Documentation: http://localhost:8000/docs
```

### 🧪 Test the Backend (Swagger UI)

Open your browser at **http://localhost:8000/docs** to interactively test all 5 API endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/weather-alerts` | GET | GPS-based weather + actionable risk alerts |
| `/api/crop-recommendation` | POST | Season + Soil AI crop advisor |
| `/api/agri-chat` | POST | Gemini-powered 24/7 Agriculture AI Chatbot |
| `/api/disease-detection` | POST | Plant disease detection from leaf image |
| `/api/market-rates` | GET | Live e-NAM/Agmarknet commodity prices |

---

## 📱 Frontend Setup (Flutter)

### Step 1 — Install Flutter Dependencies

```bash
cd Smart_Agri/frontend
flutter pub get
```

### Step 2 — Configure Backend URL

Open [`lib/services/api_service.dart`](frontend/lib/services/api_service.dart) and update `_baseUrl`:

```dart
// Android Emulator → uses 10.0.2.2 to reach host localhost
static const String _baseUrl = 'http://10.0.2.2:8000';

// iOS Simulator
static const String _baseUrl = 'http://localhost:8000';

// Physical Device (ensure same WiFi network as laptop)
static const String _baseUrl = 'http://192.168.1.XXX:8000';  // your laptop's local IP
```

> **Find your local IP on Windows:** Run `ipconfig` in Command Prompt → look for **IPv4 Address** under your Wi-Fi adapter.

### Step 3 — Add Android Permissions

In `frontend/android/app/src/main/AndroidManifest.xml`, ensure these permissions exist inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

### Step 4 — Add iOS Permissions

In `frontend/ios/Runner/Info.plist`, add:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Smart Agri needs your location to provide localized weather alerts and crop recommendations.</string>
<key>NSCameraUsageDescription</key>
<string>Smart Agri uses your camera to scan plant leaves for disease detection.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Smart Agri can access your photo library to analyze plant images.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Smart Agri uses voice recognition for hands-free agricultural queries.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Smart Agri uses the microphone for voice input to the AI assistant.</string>
```

### Step 5 — Run the App

```bash
# List connected devices
flutter devices

# Run on Android emulator
flutter run -d emulator-5554

# Run on connected physical device
flutter run -d <device-id>

# Run on iOS simulator (macOS only)
flutter run -d iPhone
```

---

## 🌟 Core Features

### 1. 🛰️ GPS Weather Alert System
- Auto-fetches device GPS coordinates
- Reverse geocodes to City/District using OpenWeatherMap
- 5-day weather forecast with rain probability per day
- **Smart Agri Alerts**: Heavy Rain (halt fertilizer), Fungal Risk (high humidity), Wind Damage (stake tall crops), Heat Wave (mulch & drip irrigation timing)

### 2. 🌿 AI Crop Recommendation Engine
- Detects current **Indian agricultural season** (Kharif/Rabi/Zaid) automatically
- **Soil x Season x Water x Location Matrix** with 6 soil types
- Strict yield/profitability ranking with cost-benefit analysis
- Expandable crop cards with variety list, fertilizer plan, irrigation schedule
- **Crops to Avoid** with agronomic reasoning

### 3. 🤖 24/7 Agri AI Chatbot
- **Gemini 1.5 Flash** with specialized agricultural system prompt
- Expert guidance: Soil pH, Panchagavya, Vermicompost, Jeevamrutham preparation
- Exact chemical dosage (e.g., `Tricyclazole 75% WP @ 0.6g/L`)
- Government schemes: PM-KISAN, KCC, PMFBY, Drip Irrigation subsidy
- Voice input (STT) + TTS audio output in 7 languages
- Markdown-rendered responses with follow-up prompt chips

### 4. 🌍 7-Language Multilingual Support
| Language | Code | Flag |
|----------|------|------|
| English | en | 🇬🇧 |
| Tamil | ta | 🇮🇳 |
| Hindi | hi | 🇮🇳 |
| Telugu | te | 🇮🇳 |
| Kannada | kn | 🇮🇳 |
| Malayalam | ml | 🇮🇳 |
| Chinese | zh | 🇨🇳 |

### 5. 🔬 Plant Disease AI Scanner
- Camera or Gallery leaf photo upload
- **Gemini Vision API** diagnosis with confidence score
- Disease name, severity level (Mild/Moderate/Severe/Critical)
- 4 tabbed views: Symptoms, Organic Remedies, Chemical Treatments, Prevention
- TTS audio diagnosis playback

### 6. 📊 Live Market Rates (e-NAM / Agmarknet)
- 12+ commodities: Vegetables, Grains, Pulses, Spices, Cash Crops
- Daily price trend indicators (↑ UP / ↓ DOWN / → STABLE)
- 24h % price change, min/max/modal price
- Searchable and category-filterable

---

## 🎨 UI Design Highlights

- **Emerald Forest Green** primary palette with glassmorphic cards
- **Material 3** design system with custom `Outfit` Google Font
- Full **Dark Mode** support
- `flutter_animate` micro-animations (fade-in, slide, shimmer loading)
- Weather condition emoji mapping
- Animated splash screen with language badge display
- Voice recording waveform animation in chat

---

## 📦 Key Dependencies

### Python Backend
| Package | Purpose |
|---------|---------|
| `fastapi` | High-performance async REST API framework |
| `uvicorn` | ASGI server |
| `google-generativeai` | Gemini Pro / Flash / Vision API |
| `httpx` | Async HTTP client for OpenWeatherMap |
| `pydantic` | Data validation and schema generation |
| `pillow` | Image processing for disease detection |

### Flutter Frontend
| Package | Purpose |
|---------|---------|
| `provider` | Lightweight state management |
| `http` | HTTP client for API communication |
| `geolocator` | GPS positioning |
| `flutter_tts` | Text-to-Speech in 7 languages |
| `speech_to_text` | Voice input recognition |
| `image_picker` | Camera / gallery access |
| `google_fonts` | Outfit / Roboto typography |
| `flutter_animate` | Beautiful micro-animations |
| `flutter_markdown` | Rendered markdown in chat responses |

---

## 🔧 Troubleshooting

### Backend won't start?
```bash
# Ensure virtual env is activated and all deps installed
pip install -r requirements.txt
python -c "import fastapi, uvicorn, pydantic_settings; print('All OK')"
```

### Flutter can't connect to backend?
1. Ensure backend is running on port 8000
2. For Android Emulator, confirm `_baseUrl = 'http://10.0.2.2:8000'`
3. On physical device, ensure phone & laptop are on the **same WiFi network**
4. Temporarily disable Windows Firewall or add Python to allowed apps

### Voice not working on Android?
- Grant Microphone permission manually in Settings → Apps → Smart Agri → Permissions

---

## 🏆 Architecture Summary

```
[Flutter App]
    ↕ HTTP/REST
[FastAPI Backend :8000]
    ├── OpenWeatherMap API (Weather & GPS Geocoding)
    ├── Google Gemini Flash 1.5 (AI Chat + Vision)
    └── Static Rule Engine (Crop Matrix + Market)
```

---

*Built with ❤️ for Indian Farmers — Smart Agri empowers every farmer with the intelligence of a seasoned agronomist.*
