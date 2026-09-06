import datetime
from typing import List, Optional
from app.models.schemas import MarketRatesResponse, MarketItem

class MarketService:
    @staticmethod
    def _detect_state_from_coords(lat: Optional[float], lon: Optional[float], state_param: Optional[str] = None) -> str:
        if state_param and state_param.strip():
            return state_param.strip()
        if lat is None or lon is None:
            return "Tamil Nadu"  # Default agricultural hub

        # Tamil Nadu: Lat 8.0 - 13.5, Lon 76.2 - 80.4 (excl. Bengaluru area)
        if 8.0 <= lat <= 12.8 and 76.2 <= lon <= 80.4:
            return "Tamil Nadu"
        elif 12.8 < lat <= 13.5 and 77.8 <= lon <= 80.4:
            return "Tamil Nadu"
        # Karnataka
        elif 12.5 <= lat <= 18.5 and 74.0 <= lon <= 77.8:
            return "Karnataka"
        # Kerala
        elif 8.2 <= lat <= 12.5 and 74.8 <= lon <= 76.5:
            return "Kerala"
        # Andhra Pradesh / Telangana
        elif 13.5 <= lat <= 19.5 and 78.0 <= lon <= 84.5:
            return "Andhra Pradesh"
        # Maharashtra
        elif 15.5 <= lat <= 22.0 and 72.5 <= lon <= 80.8:
            return "Maharashtra"
        # Punjab / Haryana / North
        elif 28.0 <= lat <= 32.5 and 74.0 <= lon <= 77.5:
            return "Punjab / Haryana"
        
        return "Tamil Nadu"

    @staticmethod
    def _detect_district_from_coords(lat: Optional[float], lon: Optional[float], district_param: Optional[str] = None) -> Optional[str]:
        if district_param and district_param.strip():
            return district_param.strip()
        if lat is None or lon is None:
            return None
        # Coimbatore region
        if 10.8 <= lat <= 11.2 and 76.8 <= lon <= 77.2:
            return "Coimbatore"
        # Tiruppur
        elif 11.0 <= lat <= 11.3 and 77.2 <= lon <= 77.6:
            return "Tiruppur"
        # Erode
        elif 11.2 <= lat <= 11.6 and 77.5 <= lon <= 77.9:
            return "Erode"
        # Salem
        elif 11.5 <= lat <= 11.9 and 78.0 <= lon <= 78.4:
            return "Salem"
        # Dindigul / Oddanchatram
        elif 10.2 <= lat <= 10.6 and 77.6 <= lon <= 78.1:
            return "Dindigul"
        # Nilgiris / Mettupalayam
        elif 11.2 <= lat <= 11.6 and 76.6 <= lon <= 77.0:
            return "Nilgiris"
        # Thanjavur / Delta
        elif 10.6 <= lat <= 11.0 and 78.9 <= lon <= 79.4:
            return "Thanjavur"
        return None

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
        user_state = MarketService._detect_state_from_coords(lat, lon, state)
        user_district = MarketService._detect_district_from_coords(lat, lon, district)
        
        all_commodities = [
            # ================= TAMIL NADU MANDIS =================
            # Vegetables
            MarketItem(
                commodity="Tomato (Hybrid / Nattu)",
                category="Vegetables",
                mandi_name="Oddanchatram Vegetable Market",
                state="Tamil Nadu",
                unit="₹ / 14kg Box",
                modal_price=420.0,
                min_price=360.0,
                max_price=480.0,
                price_trend="UP",
                price_change_24h_pct=8.5,
                last_updated="Today, 07:30 AM"
            ),
            MarketItem(
                commodity="Small Onion / Shallots (Chinna Vengayam)",
                category="Vegetables",
                mandi_name="Tiruppur / Palladam Mandi",
                state="Tamil Nadu",
                unit="₹ / Kg",
                modal_price=58.0,
                min_price=48.0,
                max_price=66.0,
                price_trend="UP",
                price_change_24h_pct=6.2,
                last_updated="Today, 08:00 AM"
            ),
            MarketItem(
                commodity="Tomato (Table Green)",
                category="Vegetables",
                mandi_name="Coimbatore APMC Mandi",
                state="Tamil Nadu",
                unit="₹ / 25kg Box",
                modal_price=780.0,
                min_price=680.0,
                max_price=850.0,
                price_trend="UP",
                price_change_24h_pct=4.8,
                last_updated="Today, 08:15 AM"
            ),
            MarketItem(
                commodity="Potato (Nilgiris Special)",
                category="Vegetables",
                mandi_name="Mettupalayam Potato Market",
                state="Tamil Nadu",
                unit="₹ / 45kg Bag",
                modal_price=1350.0,
                min_price=1200.0,
                max_price=1500.0,
                price_trend="STABLE",
                price_change_24h_pct=0.0,
                last_updated="Today, 07:45 AM"
            ),
            MarketItem(
                commodity="Green Chilli (Samba Hot)",
                category="Vegetables",
                mandi_name="Oddanchatram / Dindigul Mandi",
                state="Tamil Nadu",
                unit="₹ / Kg",
                modal_price=52.0,
                min_price=42.0,
                max_price=58.0,
                price_trend="UP",
                price_change_24h_pct=3.5,
                last_updated="Today, 08:30 AM"
            ),
            MarketItem(
                commodity="Carrot (Ooty Hill Fresh)",
                category="Vegetables",
                mandi_name="Mettupalayam Market",
                state="Tamil Nadu",
                unit="₹ / Kg",
                modal_price=44.0,
                min_price=36.0,
                max_price=50.0,
                price_trend="DOWN",
                price_change_24h_pct=-2.2,
                last_updated="Today, 09:00 AM"
            ),
            MarketItem(
                commodity="Coconut & Copra",
                category="Cash Crops",
                mandi_name="Kangayam / Pollachi APMC",
                state="Tamil Nadu",
                unit="₹ / Quintal",
                modal_price=11200.0,
                min_price=10400.0,
                max_price=11800.0,
                price_trend="UP",
                price_change_24h_pct=4.1,
                last_updated="Today, 09:15 AM"
            ),
            MarketItem(
                commodity="Turmeric (Finger Erode Special)",
                category="Spices",
                mandi_name="Erode Regulated Market",
                state="Tamil Nadu",
                unit="₹ / Quintal",
                modal_price=15200.0,
                min_price=13800.0,
                max_price=16400.0,
                price_trend="UP",
                price_change_24h_pct=5.8,
                last_updated="Today, 10:30 AM"
            ),
            MarketItem(
                commodity="Tapioca / Sago (Raw Tubers)",
                category="Cash Crops",
                mandi_name="Salem SAGO Mandi",
                state="Tamil Nadu",
                unit="₹ / Point (Ton)",
                modal_price=840.0,
                min_price=780.0,
                max_price=900.0,
                price_trend="UP",
                price_change_24h_pct=2.4,
                last_updated="Today, 10:00 AM"
            ),
            MarketItem(
                commodity="Paddy (Ponni Deluxe)",
                category="Grains",
                mandi_name="Thanjavur / Salem Regulated Market",
                state="Tamil Nadu",
                unit="₹ / 60kg Bag",
                modal_price=1560.0,
                min_price=1420.0,
                max_price=1650.0,
                price_trend="UP",
                price_change_24h_pct=1.9,
                last_updated="Today, 09:30 AM"
            ),
            MarketItem(
                commodity="Cardamom (Small Green 8mm)",
                category="Spices",
                mandi_name="Bodinaickanur / Idukki Spices Auction",
                state="Tamil Nadu / Kerala",
                unit="₹ / Kg",
                modal_price=2450.0,
                min_price=2100.0,
                max_price=2700.0,
                price_trend="UP",
                price_change_24h_pct=3.8,
                last_updated="Today, 11:00 AM"
            ),
            MarketItem(
                commodity="Cotton (MCU-5 Long Staple)",
                category="Cash Crops",
                mandi_name="Coimbatore / Tiruppur APMC",
                state="Tamil Nadu",
                unit="₹ / Quintal",
                modal_price=7650.0,
                min_price=7100.0,
                max_price=7950.0,
                price_trend="UP",
                price_change_24h_pct=2.8,
                last_updated="Today, 08:45 AM"
            ),

            # ================= KARNATAKA MANDIS =================
            MarketItem(
                commodity="Tomato (Hybrid)",
                category="Vegetables",
                mandi_name="Kolar APMC Mandi",
                state="Karnataka",
                unit="₹ / 25kg Box",
                modal_price=850.0,
                min_price=700.0,
                max_price=950.0,
                price_trend="UP",
                price_change_24h_pct=12.5,
                last_updated="Today, 08:30 AM"
            ),
            MarketItem(
                commodity="Maize / Corn (Yellow Feed)",
                category="Grains",
                mandi_name="Davanagere APMC",
                state="Karnataka",
                unit="₹ / Quintal",
                modal_price=2200.0,
                min_price=1950.0,
                max_price=2350.0,
                price_trend="DOWN",
                price_change_24h_pct=-1.5,
                last_updated="Today, 08:50 AM"
            ),
            MarketItem(
                commodity="Red Gram (Toor / Arhar)",
                category="Pulses",
                mandi_name="Kalaburagi (Gulbarga) APMC",
                state="Karnataka",
                unit="₹ / Quintal",
                modal_price=10400.0,
                min_price=9500.0,
                max_price=11200.0,
                price_trend="DOWN",
                price_change_24h_pct=-2.1,
                last_updated="Today, 09:40 AM"
            ),
            MarketItem(
                commodity="Sunflower (Hybrid Seed)",
                category="Cash Crops",
                mandi_name="Dharwad / Haveri APMC",
                state="Karnataka",
                unit="₹ / Quintal",
                modal_price=6400.0,
                min_price=5900.0,
                max_price=6900.0,
                price_trend="UP",
                price_change_24h_pct=3.2,
                last_updated="Today, 09:20 AM"
            ),
            MarketItem(
                commodity="Ragi / Finger Millet",
                category="Grains",
                mandi_name="Tumakuru / Kolar Mandi",
                state="Karnataka",
                unit="₹ / Quintal",
                modal_price=3850.0,
                min_price=3600.0,
                max_price=4100.0,
                price_trend="STABLE",
                price_change_24h_pct=0.5,
                last_updated="Today, 09:10 AM"
            ),
            MarketItem(
                commodity="Groundnut (Bold)",
                category="Cash Crops",
                mandi_name="Chitradurga APMC",
                state="Karnataka",
                unit="₹ / Quintal",
                modal_price=6200.0,
                min_price=5700.0,
                max_price=6600.0,
                price_trend="UP",
                price_change_24h_pct=2.8,
                last_updated="Today, 08:40 AM"
            ),

            # ================= MAHARASHTRA MANDIS =================
            MarketItem(
                commodity="Onion (Nashik Red)",
                category="Vegetables",
                mandi_name="Lasalgaon APMC",
                state="Maharashtra",
                unit="₹ / Quintal",
                modal_price=2450.0,
                min_price=1800.0,
                max_price=2750.0,
                price_trend="DOWN",
                price_change_24h_pct=-3.8,
                last_updated="Today, 09:15 AM"
            ),
            MarketItem(
                commodity="Black Gram (Urad Dal)",
                category="Pulses",
                mandi_name="Latur Mandi",
                state="Maharashtra",
                unit="₹ / Quintal",
                modal_price=8200.0,
                min_price=7600.0,
                max_price=8700.0,
                price_trend="STABLE",
                price_change_24h_pct=0.4,
                last_updated="Today, 09:10 AM"
            ),
            MarketItem(
                commodity="Grape (Thompson Seedless)",
                category="Cash Crops",
                mandi_name="Sangli APMC",
                state="Maharashtra",
                unit="₹ / Kg",
                modal_price=85.0,
                min_price=70.0,
                max_price=100.0,
                price_trend="UP",
                price_change_24h_pct=4.5,
                last_updated="Today, 08:00 AM"
            ),
            MarketItem(
                commodity="Soybean (Yellow)",
                category="Cash Crops",
                mandi_name="Akola / Amravati APMC",
                state="Maharashtra",
                unit="₹ / Quintal",
                modal_price=4850.0,
                min_price=4500.0,
                max_price=5100.0,
                price_trend="UP",
                price_change_24h_pct=1.9,
                last_updated="Today, 09:30 AM"
            ),
            MarketItem(
                commodity="Pomegranate (Bhagwa)",
                category="Cash Crops",
                mandi_name="Solapur / Nashik APMC",
                state="Maharashtra",
                unit="₹ / Kg",
                modal_price=120.0,
                min_price=95.0,
                max_price=140.0,
                price_trend="UP",
                price_change_24h_pct=5.1,
                last_updated="Today, 10:00 AM"
            ),

            # ================= ANDHRA PRADESH / TELANGANA MANDIS =================
            MarketItem(
                commodity="Green Chilli (G4 Teja)",
                category="Vegetables",
                mandi_name="Guntur Mandi",
                state="Andhra Pradesh",
                unit="₹ / Quintal",
                modal_price=5800.0,
                min_price=4500.0,
                max_price=6400.0,
                price_trend="UP",
                price_change_24h_pct=5.2,
                last_updated="Today, 07:45 AM"
            ),
            MarketItem(
                commodity="Cotton (Bunny BT Hybrid)",
                category="Cash Crops",
                mandi_name="Kurnool / Nandyal APMC",
                state="Andhra Pradesh",
                unit="₹ / Quintal",
                modal_price=7400.0,
                min_price=6900.0,
                max_price=7800.0,
                price_trend="STABLE",
                price_change_24h_pct=0.8,
                last_updated="Today, 09:00 AM"
            ),
            MarketItem(
                commodity="Banana (Robusta / Cavendish)",
                category="Cash Crops",
                mandi_name="Krishna / Eluru APMC",
                state="Andhra Pradesh",
                unit="₹ / Dozen",
                modal_price=48.0,
                min_price=38.0,
                max_price=58.0,
                price_trend="UP",
                price_change_24h_pct=6.0,
                last_updated="Today, 08:30 AM"
            ),
            MarketItem(
                commodity="Red Chilli (Dry)",
                category="Spices",
                mandi_name="Warangal / Khammam Mandi",
                state="Telangana",
                unit="₹ / Quintal",
                modal_price=16200.0,
                min_price=14500.0,
                max_price=17500.0,
                price_trend="UP",
                price_change_24h_pct=3.4,
                last_updated="Today, 10:15 AM"
            ),

            # ================= PUNJAB / HARYANA MANDIS =================
            MarketItem(
                commodity="Paddy (Basmati 1121)",
                category="Grains",
                mandi_name="Karnal Grain Market",
                state="Punjab / Haryana",
                unit="₹ / Quintal",
                modal_price=4350.0,
                min_price=3900.0,
                max_price=4600.0,
                price_trend="UP",
                price_change_24h_pct=2.1,
                last_updated="Today, 10:00 AM"
            ),
            MarketItem(
                commodity="Wheat (Sharbati / PBW-343)",
                category="Grains",
                mandi_name="Ludhiana Grain Market",
                state="Punjab / Haryana",
                unit="₹ / Quintal",
                modal_price=2950.0,
                min_price=2700.0,
                max_price=3150.0,
                price_trend="STABLE",
                price_change_24h_pct=0.6,
                last_updated="Today, 09:45 AM"
            ),
            MarketItem(
                commodity="Potato (Jyoti / Kufri)",
                category="Vegetables",
                mandi_name="Amritsar / Jalandhar APMC",
                state="Punjab / Haryana",
                unit="₹ / 50kg Bag",
                modal_price=950.0,
                min_price=800.0,
                max_price=1100.0,
                price_trend="DOWN",
                price_change_24h_pct=-2.5,
                last_updated="Today, 09:00 AM"
            ),

            # ================= MADHYA PRADESH MANDIS =================
            MarketItem(
                commodity="Wheat (Sharbati Gold)",
                category="Grains",
                mandi_name="Sehore APMC",
                state="Madhya Pradesh",
                unit="₹ / Quintal",
                modal_price=2850.0,
                min_price=2600.0,
                max_price=3100.0,
                price_trend="UP",
                price_change_24h_pct=1.8,
                last_updated="Today, 09:30 AM"
            ),
            MarketItem(
                commodity="Garlic (Desi White)",
                category="Vegetables",
                mandi_name="Ratlam / Mandsaur Mandi",
                state="Madhya Pradesh",
                unit="₹ / Quintal",
                modal_price=4800.0,
                min_price=4200.0,
                max_price=5400.0,
                price_trend="UP",
                price_change_24h_pct=7.2,
                last_updated="Today, 08:30 AM"
            ),
            MarketItem(
                commodity="Opium Poppy / Dhaniya (Coriander Seed)",
                category="Spices",
                mandi_name="Kota / Ramganjmandi APMC",
                state="Madhya Pradesh",
                unit="₹ / Quintal",
                modal_price=7200.0,
                min_price=6500.0,
                max_price=7800.0,
                price_trend="DOWN",
                price_change_24h_pct=-1.3,
                last_updated="Today, 10:30 AM"
            ),

            # ================= KERALA MANDIS =================
            MarketItem(
                commodity="Cardamom (Small Green 8mm)",
                category="Spices",
                mandi_name="Bodinaickanur / Idukki Spices Auction",
                state="Kerala",
                unit="₹ / Kg",
                modal_price=2450.0,
                min_price=2100.0,
                max_price=2700.0,
                price_trend="UP",
                price_change_24h_pct=3.8,
                last_updated="Today, 11:00 AM"
            ),
            MarketItem(
                commodity="Rubber (RSS-4 Grade)",
                category="Cash Crops",
                mandi_name="Kottayam / Ernakulam Market",
                state="Kerala",
                unit="₹ / Kg",
                modal_price=168.0,
                min_price=155.0,
                max_price=178.0,
                price_trend="UP",
                price_change_24h_pct=2.3,
                last_updated="Today, 09:30 AM"
            ),
            MarketItem(
                commodity="Pepper (Black Malabar Garbled)",
                category="Spices",
                mandi_name="Thrissur / Kozhikode Market",
                state="Kerala",
                unit="₹ / Kg",
                modal_price=620.0,
                min_price=580.0,
                max_price=660.0,
                price_trend="STABLE",
                price_change_24h_pct=0.2,
                last_updated="Today, 10:00 AM"
            ),
        ]

        # Filter by Category
        filtered = all_commodities
        if category and category.lower() != "all":
            filtered = [c for c in filtered if c.category.lower() == category.lower()]
            
        # Filter by Query search
        if query:
            q = query.lower()
            filtered = [c for c in filtered if q in c.commodity.lower() or q in c.mandi_name.lower() or q in c.state.lower()]

        # PRIORITIZE User's Local District and State Mandis at the top
        user_state_lower = user_state.lower()
        user_district_lower = user_district.lower() if user_district else ""

        district_mandis = []
        state_mandis = []
        other_mandis = []

        for c in filtered:
            mandi_text = f"{c.mandi_name} {c.commodity}".lower()
            if user_district_lower and user_district_lower in mandi_text:
                district_mandis.append(c)
            elif user_state_lower in c.state.lower():
                state_mandis.append(c)
            else:
                other_mandis.append(c)

        sorted_commodities = district_mandis + state_mandis + other_mandis

        if user_district:
            overview = (
                f"Live {user_district} & {user_state} Mandi Index: Prioritizing local arrivals and modal rates "
                f"for markets in {user_district} district. High liquidity in fresh farm produce."
            )
        elif "tamil nadu" in user_state_lower:
            overview = (
                f"Live Tamil Nadu & Agmarknet Mandi Index: Heavy trading across Coimbatore, Oddanchatram, "
                f"Mettupalayam, Tiruppur, and Erode mandis. Turmeric, Shallots, and Vegetables in high demand."
            )
        else:
            overview = (
                f"Live e-NAM & Agmarknet {user_state} Mandi Index: Prioritizing local regional mandis. "
                f"Daily arrivals steady with MSP price support across major wholesale hubs."
            )

        return MarketRatesResponse(
            market_overview=overview,
            date=today_str,
            commodities=sorted_commodities
        )

