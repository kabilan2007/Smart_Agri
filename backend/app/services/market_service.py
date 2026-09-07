import os
import requests
import datetime
from typing import List, Optional
from app.models.schemas import MarketRatesResponse, MarketItem

class MarketService:
    @staticmethod
    def _get_location_from_coords(lat: Optional[float], lon: Optional[float]):
        if lat is None or lon is None:
            return "Tamil Nadu", "Coimbatore"
        try:
            geo_url = f"https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lon}&format=json"
            headers = {'User-Agent': 'SmartAgriAppMobile/1.0'}
            response = requests.get(geo_url, headers=headers, timeout=5)
            if response.status_code == 200:
                address = response.json().get('address', {})
                state = address.get('state', 'Tamil Nadu')
                district = (
                    address.get('state_district') or 
                    address.get('district') or 
                    address.get('county') or 
                    address.get('city') or 
                    "Coimbatore"
                )
                return state, str(district).replace(" District", "").strip()
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
        
        if lat is not None and lon is not None and not (state and district):
            detected_state, detected_district = MarketService._get_location_from_coords(lat, lon)
            user_state = state or detected_state
            user_district = district or detected_district
        else:
            user_state = state or "Tamil Nadu"
            user_district = district or "Coimbatore"

        clean_district = user_district.split()[0] if user_district else "Coimbatore"
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
                # மெதுவான API-க்காக Timeout 20 விநாடிகளாக உயர்த்தப்பட்டுள்ளது
                response = requests.get(url, params=params, timeout=20)
                
                if response.status_code == 200:
                    records = response.json().get("records", [])
                    for item in records:
                        rec_district = str(item.get("district", ""))
                        try:
                            m_price = float(item.get("modal_price", 0))
                            min_p = float(item.get("min_price", 0))
                            max_p = float(item.get("max_price", 0))
                        except (ValueError, TypeError):
                            m_price, min_p, max_p = 0.0, 0.0, 0.0

                        market_item = MarketItem(
                            commodity=item.get("commodity", "Crop"),
                            category=category or "General",
                            mandi_name=f"{item.get('market', 'Mandi')} ({rec_district or user_district})",
                            state=item.get("state", user_state),
                            unit="₹ / Quintal",
                            modal_price=m_price,
                            min_price=min_p,
                            max_price=max_p,
                            price_trend="STABLE",
                            price_change_24h_pct=0.0,
                            last_updated=item.get("arrival_date", today_str)
                        )

                        # மாவட்டத் தரவு பொருந்துகிறதா என்று சரிபார்த்தல்
                        if clean_district.lower() in rec_district.lower() or rec_district.lower() in clean_district.lower():
                            district_commodities.append(market_item)
                        else:
                            state_commodities.append(market_item)
            except Exception as e:
                print(f"Error fetching Agmarknet API data: {e}")

        # மாவட்டத் தரவு இருந்தால் அது, இல்லையெனில் தமிழ்நாட்டின் பிற மாவட்டத் தரவுகள்
        final_commodities = district_commodities if district_commodities else state_commodities

        # Category Filter
        if category and category.lower() != "all" and final_commodities:
            final_commodities = [c for c in final_commodities if str(c.category).lower() == category.lower()]

        # Query Filter
        if query and final_commodities:
            q = query.lower()
            final_commodities = [c for c in final_commodities if q in str(c.commodity).lower() or q in str(c.mandi_name).lower()]

        overview = f"Live Agmarknet Mandi Index: Showing real-time market rates for {user_district}, {user_state}."

        return MarketRatesResponse(
            market_overview=overview,
            date=today_str,
            commodities=final_commodities
        )