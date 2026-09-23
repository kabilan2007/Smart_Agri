import os
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseSettings):
    APP_NAME: str = "Smart Agri Backend API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = os.getenv("DEBUG", "True").lower() in ("true", "1", "yes")
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    
    # API Keys
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    OPENWEATHER_API_KEY: str = os.getenv("OPENWEATHER_API_KEY", "")
    AGMARKNET_API_KEY: str = os.getenv("AGMARKNET_API_KEY", "")
    
    # Defaults & Endpoints
    OPENWEATHER_CURRENT_URL: str = "https://api.openweathermap.org/data/2.5/weather"
    OPENWEATHER_FORECAST_URL: str = "https://api.openweathermap.org/data/2.5/forecast"
    OPENWEATHER_GEOCODE_URL: str = "http://api.openweathermap.org/geo/1.0/reverse"
    
    class Config:
        case_sensitive = True

settings = Settings()