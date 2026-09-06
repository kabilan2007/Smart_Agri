from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field

# ----------------- Weather & Alert Schemas -----------------
class WeatherAlertItem(BaseModel):
    level: str = Field(..., description="Alert severity: critical, warning, advisory, or safe")
    title: str
    message: str
    action_required: str
    icon: str = "alert"

class WeatherForecastDay(BaseModel):
    date: str
    day_name: str
    temp_min: float
    temp_max: float
    condition: str
    rain_probability_pct: int
    rainfall_mm: float
    icon: str

class WeatherAlertsResponse(BaseModel):
    city: str
    district: Optional[str] = None
    state: Optional[str] = None
    country: str = "India"
    temperature: float
    temp_feels_like: float
    humidity: int
    wind_speed_kmh: float
    condition: str
    description: str
    icon: str
    is_rain_expected_24h: bool
    total_rain_forecast_3days_mm: float
    alerts: List[WeatherAlertItem]
    forecast: List[WeatherForecastDay]

# ----------------- Crop Recommendation Schemas -----------------
class CropRecommendationRequest(BaseModel):
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    location_name: Optional[str] = "Salem, Tamil Nadu"
    soil_type: str = Field(..., description="Red, Black, Alluvial, Clay, Laterite, Sandy, Loamy")
    season: Optional[str] = None # Auto-detected if not provided: Kharif, Rabi, Zaid
    month: Optional[int] = None
    water_source: Optional[str] = "Borewell / Canal" # Borewell, Canal, Rainfed, Drip
    land_area_acres: Optional[float] = 1.0
    language: Optional[str] = "en" # en, ta, ml, te, kn, hi, zh

class RecommendedCrop(BaseModel):
    crop_name: str
    scientific_name: Optional[str] = ""
    variety_recommendations: List[str]
    suitability_score: int # e.g. 95%
    growth_duration_days: int # e.g. 90-120
    expected_yield_per_acre: str
    estimated_profit_per_acre_inr: str
    water_requirement: str # Low, Medium, High
    irrigation_schedule: str
    fertilizer_plan: Dict[str, str] # Basal, vegetative, flowering
    strict_warning: Optional[str] = None # e.g. "Avoid if rainfall < 400mm"
    why_recommended: str

class CropRecommendationResponse(BaseModel):
    detected_season: str
    soil_analyzed: str
    location: str
    weather_summary: str
    best_crops: List[RecommendedCrop]
    crops_to_avoid: List[Dict[str, str]] # [{'crop': 'Rice', 'reason': 'High water deficit expected'}]
    general_soil_advice: str

# ----------------- Agri AI Chatbot Schemas -----------------
class ChatMessage(BaseModel):
    role: str = Field(..., description="user or assistant")
    content: str

class AgriChatRequest(BaseModel):
    message: str
    language: str = "en" # en, ta, ml, te, kn, hi, zh
    history: Optional[List[ChatMessage]] = []
    farmer_context: Optional[Dict[str, Any]] = None # {"location": "Erode", "crop": "Turmeric", "soil": "Red"}

class AgriChatResponse(BaseModel):
    reply: str
    language: str
    suggested_followups: List[str]
    key_takeaways: Optional[List[str]] = []
    related_govt_schemes: Optional[List[str]] = []

# ----------------- Plant Disease Detection Schemas -----------------
class DiseaseDetectionResponse(BaseModel):
    plant_name: str
    disease_identified: str
    is_healthy: bool
    confidence_score_pct: float
    severity_level: str # Mild, Moderate, Severe, Critical
    symptoms: List[str]
    causes: List[str]
    organic_remedies: List[str] # Panchagavya, Neem oil, Trichoderma
    chemical_treatments: List[str] # Fungicides with exact dosage (e.g. Copper Oxychloride 2g/L)
    preventive_measures: List[str]
    visual_alert_color: str # #4CAF50, #FF9800, #F44336

# ----------------- Market Rates Schemas -----------------
class MarketItem(BaseModel):
    commodity: str
    category: str # Vegetables, Grains, Cash Crops, Pulses, Spices
    mandi_name: str
    state: str
    unit: str = "₹ / Quintal"
    modal_price: float
    min_price: float
    max_price: float
    price_trend: str # UP, DOWN, STABLE
    price_change_24h_pct: float
    last_updated: str

class MarketRatesResponse(BaseModel):
    market_overview: str
    date: str
    commodities: List[MarketItem]
