import os
import time
import datetime
from typing import List, Optional, Tuple

import requests

from app.models.schemas import (
    MarketRatesResponse,
    MarketItem,
)


class MarketService:

    # =========================================================
    # AGMARKNET
    # =========================================================

    AGMARKNET_URL = (
        "https://api.data.gov.in/resource/"
        "9ef84268-d588-465a-a308-a864a43d0070"
    )

    API_TIMEOUT = 12
    API_LIMIT = 100

    # If Agmarknet is unreachable, don't keep hammering it.
    CIRCUIT_OPEN_SECONDS = 120

    _agmarknet_block_until = 0.0

    # =========================================================
    # LOCATION NORMALIZATION
    # =========================================================

    # Localities that can be returned by reverse geocoding
    # while the actual Agmarknet district is Coimbatore.
    LOCALITY_TO_DISTRICT = {
        "seerapalayam": "Coimbatore",
        "sulurp": "Coimbatore",
        "sulur": "Coimbatore",
        "kinathukadavu": "Coimbatore",
        "pollachi": "Coimbatore",
        "annur": "Coimbatore",
        "mettupalayam": "Coimbatore",
        "madukkarai": "Coimbatore",
        "perur": "Coimbatore",
        "kuniyamuthur": "Coimbatore",
        "saravanampatti": "Coimbatore",
        "singanallur": "Coimbatore",
        "gandhipuram": "Coimbatore",
    }

    # =========================================================
    # TEXT HELPERS
    # =========================================================

    @staticmethod
    def _clean_text(value: Optional[str]) -> str:

        if not value:
            return ""

        value = str(value).strip()

        value = (
            value.replace(" District", "")
            .replace(" district", "")
            .strip()
        )

        return value

    @staticmethod
    def _same_name(a: str, b: str) -> bool:

        a = MarketService._clean_text(a).lower()
        b = MarketService._clean_text(b).lower()

        if not a or not b:
            return False

        return (
            a == b
            or a in b
            or b in a
        )

    # =========================================================
    # LOCATION RESOLUTION
    # =========================================================

    @staticmethod
    def _normalize_district(
        district: Optional[str],
        location_name: Optional[str] = None
    ) -> str:

        district_clean = MarketService._clean_text(district)
        location_clean = MarketService._clean_text(location_name)

        # If the supplied district is already a known district,
        # keep it.
        known_districts = {
            "coimbatore",
            "chennai",
            "madurai",
            "salem",
            "erode",
            "tiruppur",
            "namakkal",
            "karur",
            "trichy",
            "tiruchirappalli",
            "thanjavur",
            "dindigul",
            "vellore",
            "kallakurichi",
            "cuddalore",
            "villupuram",
            "dharmapuri",
            "krishnagiri",
            "the nilgiris",
            "nilgiris",
            "tirunelveli",
            "thoothukudi",
            "virudhunagar",
            "sivaganga",
            "ramanathapuram",
            "pudukkottai",
            "ariyalur",
            "perambalur",
            "ranipet",
            "tirupathur",
            "tenkasi",
            "mayiladuthurai",
            "nagapattinam",
        }

        if district_clean.lower() in known_districts:

            if district_clean.lower() == "trichy":
                return "Tiruchirappalli"

            if district_clean.lower() == "nilgiris":
                return "The Nilgiris"

            return district_clean

        # Try locality mapping.
        for locality, mapped_district in (
            MarketService.LOCALITY_TO_DISTRICT.items()
        ):

            if (
                locality == district_clean.lower()
                or locality == location_clean.lower()
            ):
                return mapped_district

            if (
                locality in district_clean.lower()
                or locality in location_clean.lower()
            ):
                return mapped_district

        # If nothing matched, keep supplied value.
        if district_clean:
            return district_clean

        # Safe default for this application.
        return "Coimbatore"

    # =========================================================
    # REVERSE GEOCODING
    # =========================================================

    @staticmethod
    def _get_location_from_coords(
        lat: Optional[float],
        lon: Optional[float]
    ) -> Tuple[str, str]:

        if lat is None or lon is None:

            return (
                "Tamil Nadu",
                "Coimbatore"
            )

        try:

            geo_url = (
                "https://nominatim.openstreetmap.org/reverse"
            )

            params = {
                "lat": lat,
                "lon": lon,
                "format": "json",
                "zoom": 10,
                "addressdetails": 1,
            }

            headers = {
                "User-Agent": (
                    "SmartAgriApp/1.0 "
                    "(agriculture-market-service)"
                )
            }

            response = requests.get(
                geo_url,
                params=params,
                headers=headers,
                timeout=4
            )

            if response.status_code == 429:

                print(
                    "⚠️ Reverse geocoding rate-limited (429). "
                    "Using application location fallback."
                )

                return (
                    "Tamil Nadu",
                    "Coimbatore"
                )

            if response.status_code != 200:

                print(
                    "⚠️ Reverse geocoding returned "
                    f"HTTP {response.status_code}"
                )

                return (
                    "Tamil Nadu",
                    "Coimbatore"
                )

            address = (
                response.json()
                .get("address", {})
            )

            state = (
                address.get("state")
                or "Tamil Nadu"
            )

            district = (
                address.get("state_district")
                or address.get("district")
                or address.get("county")
                or ""
            )

            # IMPORTANT:
            # city/town/locality must NOT automatically become
            # the Agmarknet district.
            if not district:

                district = (
                    address.get("city")
                    or address.get("town")
                    or address.get("municipality")
                    or ""
                )

            district = MarketService._normalize_district(
                district=district,
                location_name=(
                    address.get("village")
                    or address.get("town")
                    or address.get("city")
                    or address.get("suburb")
                    or ""
                )
            )

            return (
                str(state).strip(),
                district
            )

        except Exception as e:

            print(
                f"⚠️ Reverse geocoding failed: {e}"
            )

            return (
                "Tamil Nadu",
                "Coimbatore"
            )

    # =========================================================
    # API REQUEST
    # =========================================================

    @staticmethod
    def _fetch_agmarknet(
        state: str,
        district: str
    ) -> List[dict]:

        api_key = (
            os.getenv(
                "AGMARKNET_API_KEY",
                ""
            )
            .strip()
        )

        if not api_key:

            print(
                "⚠️ AGMARKNET_API_KEY is not configured."
            )

            return []

        # Circuit breaker.
        if (
            time.time()
            < MarketService._agmarknet_block_until
        ):

            print(
                "⏳ Agmarknet temporarily skipped "
                "because previous request timed out."
            )

            return []

        params = {
            "api-key": api_key,
            "format": "json",
            "offset": "0",
            "limit": str(
                MarketService.API_LIMIT
            ),

            # Agmarknet uses the exposed keyword field
            # for state and normal field for district.
            "filters[state.keyword]": state,
            "filters[district]": district,

            "fields": (
                "state,"
                "district,"
                "market,"
                "commodity,"
                "variety,"
                "grade,"
                "arrival_date,"
                "min_price,"
                "max_price,"
                "modal_price"
            ),
        }

        try:

            print(
                "🌾 Agmarknet request: "
                f"state={state}, "
                f"district={district}"
            )

            response = requests.get(
                MarketService.AGMARKNET_URL,
                params=params,
                timeout=MarketService.API_TIMEOUT
            )

            if response.status_code != 200:

                print(
                    "⚠️ Agmarknet HTTP error: "
                    f"{response.status_code}"
                )

                return []

            payload = response.json()

            records = payload.get(
                "records",
                []
            )

            if not isinstance(records, list):

                return []

            print(
                "✅ Agmarknet returned "
                f"{len(records)} records for "
                f"{district}"
            )

            return records

        except requests.Timeout:

            MarketService._agmarknet_block_until = (
                time.time()
                + MarketService.CIRCUIT_OPEN_SECONDS
            )

            print(
                "⏱️ Agmarknet request timed out. "
                f"Skipping API for "
                f"{MarketService.CIRCUIT_OPEN_SECONDS}s."
            )

            return []

        except requests.RequestException as e:

            print(
                f"⚠️ Agmarknet network error: {e}"
            )

            return []

        except Exception as e:

            print(
                f"⚠️ Agmarknet parsing error: {e}"
            )

            return []

    # =========================================================
    # CATEGORY
    # =========================================================

    @staticmethod
    def _detect_category(
        commodity: str
    ) -> str:

        value = (
            commodity or ""
        ).lower()

        vegetables = {
            "tomato",
            "onion",
            "potato",
            "brinjal",
            "carrot",
            "beans",
            "cabbage",
            "cauliflower",
            "drumstick",
            "ladies finger",
            "okra",
            "bhindi",
            "chilli",
            "green chilli",
            "coconut",
        }

        grains = {
            "rice",
            "paddy",
            "wheat",
            "maize",
            "corn",
            "ragi",
            "jowar",
            "sorghum",
            "bajra",
            "millet",
        }

        pulses = {
            "gram",
            "chickpea",
            "tur",
            "arhar",
            "urad",
            "moong",
            "green gram",
            "black gram",
            "dal",
        }

        spices = {
            "pepper",
            "cardamom",
            "turmeric",
            "cumin",
            "coriander",
            "dry chilli",
        }

        cash_crops = {
            "cotton",
            "sugarcane",
            "groundnut",
            "gingelly",
            "sesamum",
            "sunflower",
        }

        if value in vegetables:
            return "Vegetables"

        if value in grains:
            return "Grains"

        if value in pulses:
            return "Pulses"

        if value in spices:
            return "Spices"

        if value in cash_crops:
            return "Cash Crops"

        return "General"

    # =========================================================
    # FLOAT
    # =========================================================

    @staticmethod
    def _to_float(value) -> float:

        try:

            return float(
                str(value)
                .replace(",", "")
                .strip()
            )

        except (
            ValueError,
            TypeError
        ):

            return 0.0

    # =========================================================
    # BUILD MARKET ITEMS
    # =========================================================

    @staticmethod
    def _build_market_items(
        records: List[dict],
        user_state: str,
        user_district: str
    ) -> List[MarketItem]:

        commodities = []

        for item in records:

            record_district = MarketService._clean_text(
                item.get("district", "")
            )

            # NEVER allow another district to enter
            # this response.
            if not MarketService._same_name(
                record_district,
                user_district
            ):

                continue

            commodity_name = (
                str(
                    item.get(
                        "commodity",
                        "Crop"
                    )
                ).strip()
            )

            detected_category = (
                MarketService._detect_category(
                    commodity_name
                )
            )

            market_name = (
                str(
                    item.get(
                        "market",
                        "Mandi"
                    )
                ).strip()
            )

            modal_price = MarketService._to_float(
                item.get("modal_price")
            )

            min_price = MarketService._to_float(
                item.get("min_price")
            )

            max_price = MarketService._to_float(
                item.get("max_price")
            )

            commodities.append(
                MarketItem(
                    commodity=commodity_name,

                    category=detected_category,

                    mandi_name=(
                        f"{market_name} "
                        f"({user_district})"
                    ),

                    state=str(
                        item.get(
                            "state",
                            user_state
                        )
                    ),

                    unit="₹ / Quintal",

                    modal_price=modal_price,

                    min_price=min_price,

                    max_price=max_price,

                    # Source does not provide a reliable
                    # 24-hour percentage change here.
                    price_trend="STABLE",

                    price_change_24h_pct=0.0,

                    last_updated=str(
                        item.get(
                            "arrival_date",
                            datetime.date.today()
                            .strftime("%d %b %Y")
                        )
                    )
                )
            )

        return commodities

    # =========================================================
    # MAIN METHOD
    # =========================================================

    @staticmethod
    def get_live_market_rates(
        category: Optional[str] = None,
        query: Optional[str] = None,
        lat: Optional[float] = None,
        lon: Optional[float] = None,
        state: Optional[str] = None,
        district: Optional[str] = None,
        location_name: Optional[str] = None
    ) -> MarketRatesResponse:

        today_str = (
            datetime.date.today()
            .strftime("%d %b %Y")
        )

        # -----------------------------------------------------
        # Resolve location
        # -----------------------------------------------------

        if state and district:

            user_state = (
                MarketService._clean_text(state)
            )

            user_district = (
                MarketService._normalize_district(
                    district=district,
                    location_name=location_name
                )
            )

        elif lat is not None and lon is not None:

            detected_state, detected_district = (
                MarketService._get_location_from_coords(
                    lat,
                    lon
                )
            )

            user_state = (
                MarketService._clean_text(
                    state or detected_state
                )
            )

            user_district = (
                MarketService._normalize_district(
                    district=district or detected_district,
                    location_name=location_name
                )
            )

        else:

            user_state = (
                MarketService._clean_text(
                    state or "Tamil Nadu"
                )
            )

            user_district = (
                MarketService._normalize_district(
                    district=district,
                    location_name=location_name
                )
            )

        if not user_state:

            user_state = "Tamil Nadu"

        if not user_district:

            user_district = "Coimbatore"

        print(
            "📍 Market location resolved: "
            f"{location_name or user_district}, "
            f"{user_district}, "
            f"{user_state}"
        )

        # -----------------------------------------------------
        # Fetch ONLY requested district
        # -----------------------------------------------------

        records = MarketService._fetch_agmarknet(
            state=user_state,
            district=user_district
        )

        commodities = (
            MarketService._build_market_items(
                records=records,
                user_state=user_state,
                user_district=user_district
            )
        )

        # -----------------------------------------------------
        # Category filter
        # -----------------------------------------------------

        if (
            category
            and category.lower() != "all"
        ):

            requested_category = (
                category.lower().strip()
            )

            commodities = [
                item
                for item in commodities
                if (
                    str(
                        item.category
                    ).lower()
                    == requested_category
                )
            ]

        # -----------------------------------------------------
        # Search filter
        # -----------------------------------------------------

        if query:

            q = query.lower().strip()

            commodities = [
                item
                for item in commodities
                if (
                    q in str(
                        item.commodity
                    ).lower()
                    or
                    q in str(
                        item.mandi_name
                    ).lower()
                )
            ]

        # -----------------------------------------------------
        # Overview
        # -----------------------------------------------------

        if commodities:

            overview = (
                "Live Agmarknet Mandi Index: "
                f"Showing {len(commodities)} "
                f"market records for "
                f"{user_district}, "
                f"{user_state}."
            )

        else:

            overview = (
                "No Agmarknet mandi price records "
                f"were returned for "
                f"{user_district}, "
                f"{user_state}. "
                "No other district data was substituted."
            )

        return MarketRatesResponse(
            market_overview=overview,
            date=today_str,
            commodities=commodities
        )

    # =========================================================
    # BACKGROUND REFRESH COMPATIBILITY
    # =========================================================

    @staticmethod
    def refresh_state_cache(
        state: str
    ) -> None:

        """
        Kept for compatibility with main.py's existing
        background refresher.

        We intentionally do NOT download the entire state
        every few hours. The live endpoint makes a
        district-specific request instead.
        """

        print(
            "ℹ️ Background state refresh skipped for "
            f"{state}; district-specific live requests "
            "are used instead."
        )