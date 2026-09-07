import os
import requests
import datetime
from typing import List, Optional
from app.models.schemas import MarketRatesResponse, MarketItem

class MarketService:
    @staticmethod
    def _get_location_from_coords(lat: Optional[float], lon: Optional[float]):
        """
        GPS (lat, lon) உதவியுடன் துல்லியமான State மற்றும் District-ஐ கண்டறிதல்
        """
        if lat is None or lon is None:
            return "Tamil Nadu", "Coimbatore"

        try:
            # OpenStreetMap Free Reverse Geocoding API
            geo_url = f"https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lon}&format=json"
            headers = {'User-Agent': 'SmartAgriApp/1.0'}
            
            response = requests.get(geo_url, headers=headers, timeout=5)
            if response.status_code == 200:
                address = response.json().get('address', {})
                
                state = address.get('state', 'Tamil Nadu')
                # District, State District அல்லது Town/City-ஐக் கண்டறிதல்
                district = (
                    address.get('state_district') or 
                    address.get('district') or 
                    address.get('county') or 
                    address.get('city') or 
                    "Coimbatore"
                )
                
                # 'District' என்ற சொல் கடைசியில் இருந்தால் நீக்குதல் (எ.கா: "Coimbatore District" -> "Coimbatore")
                district = district.replace(" District", "").strip()
                return state, district
        except Exception as e:
                print(f"Geocoding Error: {e}")

        return "Tamil Nadu", "Coimbatore"

    @staticmethod
    def get_live_market_rates(
        category: Optional[str] = None,
        query: Optional[str] = None,
        lat: Optional[float] = None,
        lon: Optional[float] = None,
        state: Optional[str] = None,
        district: Optional[str] = None
    ) -> MarketRatesResponse:
        
        today_str = datetime.date.today().strftime("%d %b %Y")
        
        # User Parameter அனுப்பாவிட்டால் GPS Coordinates மூலம் நேரடி ஊர் பெயர் கண்டறிதல்
        if lat and lon and not (state and district):
            detected_state, detected_district = MarketService._get_location_from_coords(lat, lon)
            user_state = state or detected_state
            user_district = district or detected_district
        else:
            user_state = state or "Tamil Nadu"
            user_district = district or "Coimbatore"

        api_key = os.getenv("AGMARKNET_API_KEY", "")
        commodities = []

        if api_key:
            try:
                url = "https://api.data.gov.in/resource/9ef7421f-0528-472d-a773-a6894f58b39f"
                params = {
                    "api-key": api_key,
                    "format": "json",
                    "limit": "200",
                    "filters[state]": user_state
                }

                response = requests.get(url, params=params, timeout=10)
                
                if response.status_code == 200:
                    data = response.json()
                    records = data.get("records", [])
                    
                    for item in records:
                        rec_district = item.get("district", "")
                        
                        # பயனர் இருக்கும் குறிப்பிட்ட மாவட்டத்தின் தரவை மட்டும் வடிகட்டுதல்
                        if user_district.lower() in rec_district.lower() or rec_district.lower() in user_district.lower():
                            commodities.append(
                                MarketItem(
                                    commodity=item.get("commodity", "Crop"),
                                    category=category or "General",
                                    mandi_name=f"{item.get('market', '')} ({rec_district})",
                                    state=item.get("state", user_state),
                                    unit="₹ / Quintal",
                                    modal_price=float(item.get("modal_price", 0)),
                                    min_price=float(item.get("min_price", 0)),
                                    max_price=float(item.get("max_price", 0)),
                                    price_trend="STABLE",
                                    price_change_24h_pct=0.0,
                                    last_updated=item.get("arrival_date", "Today")
                                )
                            )
            except Exception as e:
                print(f"Error fetching Agmarknet API data: {e}")

        # Category Search Filter
        if category and category.lower() != "all" and commodities:
            commodities = [c for c in commodities if c.category.lower() == category.lower()]

        # Query Search Filter
        if query and commodities:
            q = query.lower()
            commodities = [c for c in commodities if q in c.commodity.lower() or q in c.mandi_name.lower()]

        overview = (
            f"Live Agmarknet Mandi Index: Showing official real-time daily prices "
            f"for {user_district}, {user_state}."
        )

        return MarketRatesResponse(
            market_overview=overview,
            date=today_str,
            commodities=commodities
        )