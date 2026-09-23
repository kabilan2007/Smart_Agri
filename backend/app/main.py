import os
import threading
import time
from typing import Optional
from fastapi import FastAPI, UploadFile, File, Form, Query, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.models.schemas import (
    WeatherAlertsResponse,
    CropRecommendationRequest,
    CropRecommendationResponse,
    AgriChatRequest,
    AgriChatResponse,
    DiseaseDetectionResponse,
    MarketRatesResponse,
)
from app.services.weather_service import WeatherService
from app.services.crop_recommendation_service import CropRecommendationService
from app.services.gemini_service import GeminiService
from app.services.disease_detection_service import DiseaseDetectionService
from app.services.market_service import MarketService

app = FastAPI(
    title="Smart Agri - Intelligent AI Agricultural Engine",
    description="Full-stack AI backend powering modern agricultural solutions for young and progressive farmers.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Enable CORS for Mobile App connections
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----------------- Background Market Data Refresher -----------------
# Agmarknet's live API is slow/unreliable, so we don't make farmers wait on it
# per-request. Instead we pre-warm the cache on boot and refresh it every few
# hours in the background; user requests then always read from cache (fast),
# with a live retry only if the cache is completely empty.
MARKET_REFRESH_INTERVAL_SECONDS = 3 * 60 * 60  # 3 hours
MARKET_STATES_TO_PREFETCH = ["Tamil Nadu"]

def _background_market_refresher():
    while True:
        for state in MARKET_STATES_TO_PREFETCH:
            try:
                print(f"🔄 Background refresh: fetching Agmarknet data for {state}...")
                MarketService.get_live_market_rates(state=state, district=state)
                print(f"✅ Background refresh: {state} cache updated.")
            except Exception as e:
                print(f"⚠️  Background refresh failed for {state}: {e}")
        time.sleep(MARKET_REFRESH_INTERVAL_SECONDS)

@app.on_event("startup")
def start_background_market_refresher():
    thread = threading.Thread(target=_background_market_refresher, daemon=True)
    thread.start()

@app.get("/", tags=["General"])
async def root():
    return {
        "status": "online",
        "service": "Smart Agri AI Backend",
        "version": settings.APP_VERSION,
        "docs": "/docs",
        "endpoints": [
            "/api/weather-alerts",
            "/api/crop-recommendation",
            "/api/agri-chat",
            "/api/disease-detection",
            "/api/market-rates"
        ]
    }

@app.get("/health", tags=["General"])
async def health_check():
    return {"status": "healthy", "gemini_configured": bool(settings.GEMINI_API_KEY), "weather_configured": bool(settings.OPENWEATHER_API_KEY)}

# ----------------- 1. Weather & Risk Alerts -----------------
@app.get("/api/weather-alerts", response_model=WeatherAlertsResponse, tags=["Weather & Alerts"])
@app.get("/api/weather", response_model=WeatherAlertsResponse, tags=["Weather & Alerts"])
async def get_weather_alerts(
    lat: Optional[float] = Query(None, description="Farmer GPS Latitude"),
    lon: Optional[float] = Query(None, description="Farmer GPS Longitude"),
    latitude: Optional[float] = Query(None, description="Alias for Latitude"),
    longitude: Optional[float] = Query(None, description="Alias for Longitude")
):
    """
    Fetches real-time weather analytics, reverse geocoded city/district,
    and generates automated agricultural risk alerts (Heavy rain, Fungal risk, Heatwave, Wind damage).
    """
    try:
        final_lat = lat if lat is not None else (latitude if latitude is not None else 11.6643)
        final_lon = lon if lon is not None else (longitude if longitude is not None else 78.1460)
        response = await WeatherService.get_weather_and_alerts(final_lat, final_lon)
        return response
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch weather alerts: {str(e)}"
        )

# ----------------- 2. AI Crop Recommendation -----------------
@app.post("/api/crop-recommendation", response_model=CropRecommendationResponse, tags=["Crop Recommendation"])
async def recommend_crops(request: CropRecommendationRequest):
    """
    Recommends high-yielding, profitable crops based on detected Season,
    Soil Profile, and Water conditions with strict rule checks (e.g., avoiding water-guzzling crops in dry spells).
    """
    try:
        response = CropRecommendationService.recommend_crops(request)
        return response
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Crop recommendation failed: {str(e)}"
        )

# ----------------- 3. Universal Agri & Soil Chatbot (AI Doctor) -----------------
@app.post("/api/agri-chat", response_model=AgriChatResponse, tags=["AI Chatbot"])
@app.post("/api/ai-doctor", response_model=AgriChatResponse, tags=["AI Chatbot"])
async def agri_chat(request: AgriChatRequest):
    """
    24/7 Soil & Agricultural AI Assistant powered by Google Gemini.
    Provides expert advice on crop diagnosis, soil pH balancing, organic inputs (Panchagavya, Vermicompost),
    pest & disease IPM, irrigation, and government subsidies.
    """
    try:
        response = await GeminiService.chat(request)
        return response
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Chatbot failed: {str(e)}"
        )

# ----------------- 4. AI Plant Disease Detection -----------------
@app.post("/api/disease-detection", response_model=DiseaseDetectionResponse, tags=["Plant Disease Computer Vision"])
async def detect_plant_disease(
    file: UploadFile = File(..., description="Leaf or infected plant image")
):
    """
    Computer Vision model (Gemini Vision) that diagnoses leaf diseases,
    evaluates severity, and provides step-by-step organic remedies and chemical fungicides with exact dosages.
    """
    try:
        image_bytes = await file.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Empty image file received.")
            
        response = await DiseaseDetectionService.analyze_leaf_image(
            image_bytes=image_bytes,
            filename=file.filename
        )
        return response
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Disease detection failed: {str(e)}"
        )

# ----------------- 5. Live Market Rates (e-NAM / Agmarknet) -----------------
@app.get("/api/market-rates", response_model=MarketRatesResponse, tags=["Market Rates"])
@app.get("/api/mandi-rates", response_model=MarketRatesResponse, tags=["Market Rates"])
async def get_market_rates(
    category: Optional[str] = Query(None, description="Vegetables, Grains, Cash Crops, Pulses, Spices, or All"),
    query: Optional[str] = Query(None, description="Search term for crop or mandi"),
    lat: Optional[float] = Query(None, description="Farmer GPS Latitude"),
    lon: Optional[float] = Query(None, description="Farmer GPS Longitude"),
    latitude: Optional[float] = Query(None, description="Alias for Latitude"),
    longitude: Optional[float] = Query(None, description="Alias for Longitude"),
    state: Optional[str] = Query(None, description="Farmer State/Region"),
    district: Optional[str] = Query(None, description="Farmer District/City"),
    location_name: Optional[str] = Query(None, description="Farmer Location Name")
):
    """
    Real-time agricultural commodity prices, mandi rates, and daily price trends (UP/DOWN/STABLE).
    Prioritizes local district & state mandis based on live GPS coordinates.
    """
    try:
        final_lat = lat if lat is not None else latitude
        final_lon = lon if lon is not None else longitude
        final_district = district or location_name
        response = MarketService.get_live_market_rates(
            category=category,
            query=query,
            lat=final_lat,
            lon=final_lon,
            state=state,
            district=final_district
        )
        return response
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch market rates: {str(e)}"
        )