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
                district = (
                    address.get('state_district') or 
                    address.get('district') or 
                    address.get('county') or 
                    address.get('city') or 
                    "Tamil Nadu"
                )
                
                district = district.replace(" District", "").replace(" District", "").strip()
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
        
        # GPS மூலம் பயனரின் சொந்த மாவட்டத்தைக் கண்டறிதல்
        if lat and lon and not (state and district):
            detected_state, detected_district = MarketService._get_location_from_coords(lat, lon)
            user_state = state or detected_state
            user_district = district or detected_district
        else:
            user_state = state or "Tamil Nadu"
            user_district = district or "Coimbatore"

        # மாவட்டப் பெயரின் முதல் வார்த்தை (எ.கா: "Tiruchirappalli South" -> "Tiruchirappalli")
        clean_district = user_district.split()[0] if user_district else ""

        api_key = os.getenv("AGMARKNET_API_KEY", "")
        district_commodities = []
        state_commodities = []

        if api_key:
            try:
                url = "https://api.data.gov.in/resource/9ef7421f-0528-472d-a773-a6894f58b39f"
                params = {
                    "api-key": api_key,
                    "format": "json",
                    "limit": "300",
                    "filters[state]": user_state
                }

                response = requests.get(url, params=params, timeout=10)
                
                if response.status_code == 200:
                    data = response.json()
                    records = data.get("records", [])
                    
                    for item in records:
                        rec_district = item.get("district", "")
                        market_item = MarketItem(
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
                        
                        # பயனர் இருக்கும் குறிப்பிட்ட மாவட்டத்தின் மண்டித் தரவை மட்டும் சேகரித்தல்
                        if clean_district and (clean_district.lower() in rec_district.lower() or rec_district.lower() in clean_district.lower()):
                            district_commodities.append(market_item)
                        else:
                            state_commodities.append(market_item)
            except Exception as e:
                print(f"Error fetching Agmarknet API data: {e}")

        # 1. சொந்த மாவட்டத் தரவு இருந்தால் அதை மட்டுமே காட்டும்.
        # 2. சொந்த மாவட்டத்தில் மண்டி இல்லையெனில்/தரவு வரவில்லை எனில் பக்கத்து/மாநிலத்தின் பிற மண்டிகளைக் காட்டும்.
        final_commodities = district_commodities if district_commodities else state_commodities

        # Category Filter
        if category and category.lower() != "all" and final_commodities:
            final_commodities = [c for c in final_commodities if c.category.lower() == category.lower()]

        # Query Search Filter
        if query and final_commodities:
            q = query.lower()
            final_commodities = [c for c in final_commodities if q in c.commodity.lower() or q in c.mandi_name.lower()]

        overview = (
            f"Live Agmarknet Mandi Index: Showing official real-time daily prices "
            f"for {user_district}, {user_state}."
        )

        return MarketRatesResponse(
            market_overview=overview,
            date=today_str,
            commodities=final_commodities
        )