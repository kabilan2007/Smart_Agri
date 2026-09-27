import os
import time
import datetime
import threading
from typing import List, Optional, Dict, Any

import requests

from app.models.schemas import MarketRatesResponse, MarketItem


class MarketService:
    """
    REAL Agmarknet market-price service.

    Rules:
    1. No dummy/sample market prices.
    2. No hardcoded Onion/Tomato/etc. prices.
    3. Uses user's GPS -> State/District.
    4. Fetches prices from Government of India Agmarknet API.
    5. Never falls back to another district.
    6. If Agmarknet has no data, commodities=[].
    """

    # Government of India Agmarknet resource
    AGMARKNET_URL = (
        "https://api.data.gov.in/resource/"
        "9ef84268-d588-465a-a308-a864a43d0070"
    )

    # Cache settings
    CACHE_MAX_AGE_SECONDS = 6 * 60 * 60
    STALE_CACHE_MAX_AGE_SECONDS = 24 * 60 * 60

    # Keep Render request short
    API_TIMEOUT_SECONDS = 8
    GEO_TIMEOUT_SECONDS = 4

    # data.gov.in allows pagination.
    API_LIMIT = 100

    _cache: Dict[str, Dict[str, Any]] = {}
    _cache_lock = threading.Lock()

    # ---------------------------------------------------------
    # TEXT NORMALIZATION
    # ---------------------------------------------------------

    @staticmethod
    def _normalize_name(value: Optional[str]) -> str:
        if not value:
            return ""

        value = str(value).strip().lower()

        replacements = [
            " district",
            " dist.",
            " dist",
        ]

        for suffix in replacements:
            if value.endswith(suffix):
                value = value[: -len(suffix)].strip()

        return " ".join(value.split())

    # ---------------------------------------------------------
    # API KEY
    # ---------------------------------------------------------

    @staticmethod
    def _get_api_key() -> str:
        return os.getenv("AGMARKNET_API_KEY", "").strip()

    # ---------------------------------------------------------
    # GPS -> LOCATION
    # ---------------------------------------------------------

    @staticmethod
    def _get_location_from_coords(
        lat: Optional[float],
        lon: Optional[float]
    ):
        """
        Convert farmer GPS coordinates into State + District.
        """

        if lat is None or lon is None:
            return None, None

        try:
            response = requests.get(
                "https://nominatim.openstreetmap.org/reverse",
                params={
                    "lat": lat,
                    "lon": lon,
                    "format": "json",
                    "zoom": 10,
                    "addressdetails": 1,
                },
                headers={
                    "User-Agent": "SmartAgriAppMobile/1.0"
                },
                timeout=MarketService.GEO_TIMEOUT_SECONDS,
            )

            if response.status_code != 200:
                print(
                    f"⚠️ Reverse geocoding HTTP "
                    f"{response.status_code}"
                )
                return None, None

            data = response.json()
            address = data.get("address", {})

            state = (
                address.get("state")
                or address.get("state_district")
            )

            district = (
                address.get("state_district")
                or address.get("district")
                or address.get("county")
            )

            if not state or not district:
                print(
                    "⚠️ GPS location did not contain "
                    "state/district"
                )
                return None, None

            district = str(district)

            for suffix in [
                " District",
                " district",
                " Dist",
                " dist",
            ]:
                if district.endswith(suffix):
                    district = district[
                        :-len(suffix)
                    ].strip()

            print(
                f"📍 GPS location detected: "
                f"{district}, {state}"
            )

            return (
                str(state).strip(),
                district.strip()
            )

        except requests.Timeout:
            print("⏱️ Reverse geocoding timed out")
            return None, None

        except Exception as e:
            print(
                f"❌ Reverse geocoding error: {e}"
            )
            return None, None

    # ---------------------------------------------------------
    # CACHE KEY
    # ---------------------------------------------------------

    @classmethod
    def _cache_key(
        cls,
        state: str,
        district: str
    ) -> str:
        return (
            f"{cls._normalize_name(state)}:"
            f"{cls._normalize_name(district)}"
        )

    # ---------------------------------------------------------
    # READ CACHE
    # ---------------------------------------------------------

    @classmethod
    def _get_cached_records(
        cls,
        state: str,
        district: str,
        allow_stale: bool = False
    ) -> Optional[List[dict]]:

        key = cls._cache_key(
            state,
            district
        )

        with cls._cache_lock:
            cached = cls._cache.get(key)

        if not cached:
            return None

        age = time.time() - cached["timestamp"]

        if age <= cls.CACHE_MAX_AGE_SECONDS:
            print(
                f"✅ Fresh cache used: "
                f"{district}, {state}"
            )
            return cached["records"]

        if (
            allow_stale
            and age <= cls.STALE_CACHE_MAX_AGE_SECONDS
        ):
            print(
                f"⚠️ Stale cache used: "
                f"{district}, {state}"
            )
            return cached["records"]

        return None

    # ---------------------------------------------------------
    # SAVE CACHE
    # ---------------------------------------------------------

    @classmethod
    def _save_cache(
        cls,
        state: str,
        district: str,
        records: List[dict]
    ):

        key = cls._cache_key(
            state,
            district
        )

        with cls._cache_lock:
            cls._cache[key] = {
                "timestamp": time.time(),
                "records": records,
            }

        print(
            f"💾 Cache saved: "
            f"{district}, {state} "
            f"({len(records)} records)"
        )

    # ---------------------------------------------------------
    # FETCH REAL AGMARKNET DATA
    # ---------------------------------------------------------

    @classmethod
    def _fetch_agmarknet_data(
        cls,
        state: str,
        district: str
    ) -> Optional[List[dict]]:

        api_key = cls._get_api_key()

        if not api_key:
            print(
                "❌ AGMARKNET_API_KEY is missing"
            )
            return None

        print(
            f"🌐 Agmarknet request: "
            f"{district}, {state}"
        )

        try:

            params = {
                "api-key": api_key,
                "format": "json",
                "limit": str(cls.API_LIMIT),

                # Official Agmarknet filters
                "filters[state.keyword]": state,
                "filters[district]": district,

                # Only actual source fields
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

            started = time.time()

            response = requests.get(
                cls.AGMARKNET_URL,
                params=params,
                timeout=cls.API_TIMEOUT_SECONDS,
            )

            elapsed = time.time() - started

            print(
                f"📡 Agmarknet HTTP "
                f"{response.status_code} "
                f"in {elapsed:.2f}s"
            )

            if response.status_code != 200:
                print(
                    f"❌ Agmarknet HTTP error: "
                    f"{response.status_code}"
                )
                return None

            data = response.json()

            records = data.get("records", [])

            if not isinstance(records, list):
                print(
                    "❌ Agmarknet returned "
                    "invalid records"
                )
                return None

            print(
                f"✅ Real Agmarknet records: "
                f"{len(records)}"
            )

            cls._save_cache(
                state,
                district,
                records
            )

            return records

        except requests.Timeout:
            print(
                f"⏱️ Agmarknet timeout after "
                f"{cls.API_TIMEOUT_SECONDS}s"
            )
            return None

        except requests.RequestException as e:
            print(
                f"❌ Agmarknet network error: {e}"
            )
            return None

        except ValueError as e:
            print(
                f"❌ Agmarknet JSON error: {e}"
            )
            return None

        except Exception as e:
            print(
                f"❌ Agmarknet unexpected error: {e}"
            )
            return None

    # ---------------------------------------------------------
    # CATEGORY
    # ---------------------------------------------------------

    @staticmethod
    def _get_category(
        commodity: str
    ) -> str:

        name = commodity.lower()

        vegetables = [
            "tomato",
            "onion",
            "potato",
            "brinjal",
            "eggplant",
            "carrot",
            "beans",
            "cabbage",
            "cauliflower",
            "cucumber",
            "drumstick",
            "ladies finger",
            "okra",
            "green chilli",
            "chilli",
            "bitter gourd",
            "bottle gourd",
            "pumpkin",
            "beetroot",
            "radish",
            "garlic",
            "ginger",
        ]

        grains = [
            "paddy",
            "rice",
            "wheat",
            "maize",
            "corn",
            "ragi",
            "jowar",
            "sorghum",
            "bajra",
            "millet",
        ]

        pulses = [
            "tur",
            "arhar",
            "red gram",
            "toor",
            "urad",
            "black gram",
            "moong",
            "green gram",
            "chana",
            "gram",
            "horse gram",
            "cowpea",
        ]

        spices = [
            "turmeric",
            "pepper",
            "cumin",
            "coriander",
            "cardamom",
            "clove",
            "fenugreek",
        ]

        cash_crops = [
            "cotton",
            "sugarcane",
            "groundnut",
            "coconut",
            "copra",
            "tobacco",
            "rubber",
            "tapioca",
            "castor",
        ]

        if any(x in name for x in vegetables):
            return "Vegetables"

        if any(x in name for x in grains):
            return "Grains"

        if any(x in name for x in pulses):
            return "Pulses"

        if any(x in name for x in spices):
            return "Spices"

        if any(x in name for x in cash_crops):
            return "Cash Crops"

        return "General"

    # ---------------------------------------------------------
    # AGMARKNET RECORD -> MarketItem
    # ---------------------------------------------------------

    @classmethod
    def _record_to_market_item(
        cls,
        record: dict
    ) -> Optional[MarketItem]:

        commodity = str(
            record.get("commodity") or ""
        ).strip()

        market = str(
            record.get("market") or ""
        ).strip()

        state = str(
            record.get("state") or ""
        ).strip()

        district = str(
            record.get("district") or ""
        ).strip()

        arrival_date = str(
            record.get("arrival_date") or ""
        ).strip()

        # No source commodity/market = reject
        if not commodity or not market:
            return None

        # No arrival date = reject
        if not arrival_date:
            return None

        try:
            modal_price = float(
                record.get("modal_price")
            )

            min_price = float(
                record.get("min_price")
            )

            max_price = float(
                record.get("max_price")
            )

        except (TypeError, ValueError):
            return None

        # Never display invalid price
        if (
            modal_price <= 0
            or min_price <= 0
            or max_price <= 0
        ):
            return None

        return MarketItem(
            commodity=commodity,

            # Category is only a UI classification
            # based on the REAL commodity name.
            category=cls._get_category(
                commodity
            ),

            # Real mandi + real district
            mandi_name=(
                f"{market} ({district})"
                if district
                else market
            ),

            state=state,

            # Agmarknet daily prices are ₹/quintal
            unit="₹ / Quintal",

            # REAL API values
            modal_price=modal_price,
            min_price=min_price,
            max_price=max_price,

            # API doesn't provide a trustworthy
            # 24-hour percentage in this response.
            price_trend="STABLE",
            price_change_24h_pct=0.0,

            # REAL Agmarknet arrival date
            last_updated=arrival_date,
        )

    # ---------------------------------------------------------
    # MAIN METHOD
    # ---------------------------------------------------------

    @classmethod
    def get_live_market_rates(
        cls,
        category: Optional[str] = None,
        query: Optional[str] = None,
        lat: Optional[float] = None,
        lon: Optional[float] = None,
        state: Optional[str] = None,
        district: Optional[str] = None
    ) -> MarketRatesResponse:

        today_str = datetime.date.today().strftime(
            "%d %b %Y"
        )

        # -----------------------------------------------------
        # LOCATION
        # -----------------------------------------------------

        detected_state = None
        detected_district = None

        if lat is not None and lon is not None:

            detected_state, detected_district = (
                cls._get_location_from_coords(
                    lat,
                    lon
                )
            )

        user_state = (
            state
            or detected_state
        )

        user_district = (
            district
            or detected_district
        )

        # IMPORTANT:
        # Do NOT silently use Coimbatore/Tamil Nadu.
        # If GPS/location is unavailable, return no data.
        if not user_state or not user_district:

            print(
                "⚠️ Cannot determine farmer "
                "state/district"
            )

            return MarketRatesResponse(
                market_overview=(
                    "Farmer location could not be "
                    "identified. Market prices were "
                    "not displayed."
                ),
                date=today_str,
                commodities=[]
            )

        user_state = str(
            user_state
        ).strip()

        user_district = str(
            user_district
        ).strip()

        print(
            f"📍 Market location: "
            f"{user_district}, {user_state}"
        )

        # -----------------------------------------------------
        # CACHE FIRST
        # -----------------------------------------------------

        records = cls._get_cached_records(
            user_state,
            user_district
        )

        # -----------------------------------------------------
        # FETCH REAL DATA
        # -----------------------------------------------------

        if records is None:

            records = cls._fetch_agmarknet_data(
                user_state,
                user_district
            )

        # -----------------------------------------------------
        # STALE CACHE ONLY FOR SAME DISTRICT
        # -----------------------------------------------------

        if records is None:

            records = cls._get_cached_records(
                user_state,
                user_district,
                allow_stale=True
            )

        # -----------------------------------------------------
        # NO DATA
        # -----------------------------------------------------

        if not records:

            print(
                f"⚠️ No Agmarknet data for "
                f"{user_district}, {user_state}"
            )

            return MarketRatesResponse(
                market_overview=(
                    f"No Agmarknet market data is "
                    f"currently available for "
                    f"{user_district}, {user_state}."
                ),
                date=today_str,
                commodities=[]
            )

        # -----------------------------------------------------
        # STRICT DISTRICT CHECK
        # -----------------------------------------------------

        requested_district = (
            cls._normalize_name(
                user_district
            )
        )

        commodities: List[MarketItem] = []

        for record in records:

            record_district = (
                str(
                    record.get("district") or ""
                ).strip()
            )

            normalized_record_district = (
                cls._normalize_name(
                    record_district
                )
            )

            # NEVER show another district.
            if (
                requested_district
                != normalized_record_district
            ):
                continue

            item = cls._record_to_market_item(
                record
            )

            if item:
                commodities.append(item)

        # -----------------------------------------------------
        # CATEGORY FILTER
        # -----------------------------------------------------

        if (
            category
            and category.lower() != "all"
        ):

            requested_category = (
                category.strip().lower()
            )

            commodities = [
                item
                for item in commodities
                if item.category.lower()
                == requested_category
            ]

        # -----------------------------------------------------
        # SEARCH FILTER
        # -----------------------------------------------------

        if query:

            q = query.strip().lower()

            commodities = [
                item
                for item in commodities
                if (
                    q in item.commodity.lower()
                    or
                    q in item.mandi_name.lower()
                )
            ]

        # -----------------------------------------------------
        # REMOVE DUPLICATES
        # -----------------------------------------------------

        unique = {}

        for item in commodities:

            key = (
                item.commodity.lower(),
                item.mandi_name.lower(),
                item.last_updated,
                item.modal_price,
            )

            unique[key] = item

        commodities = list(
            unique.values()
        )

        # -----------------------------------------------------
        # SORT
        # -----------------------------------------------------

        commodities.sort(
            key=lambda x: (
                x.commodity.lower(),
                x.mandi_name.lower()
            )
        )

        print(
            f"📊 Returning "
            f"{len(commodities)} REAL Agmarknet "
            f"records for "
            f"{user_district}, {user_state}"
        )

        return MarketRatesResponse(
            market_overview=(
                f"Agmarknet market prices for "
                f"{user_district}, {user_state}. "
                f"Prices shown are from the latest "
                f"available mandi records."
            ),
            date=today_str,
            commodities=commodities
        )

    # ---------------------------------------------------------
    # BACKGROUND REFRESH
    # ---------------------------------------------------------

    @classmethod
    def refresh_state_cache(
        cls,
        state: str = "Tamil Nadu"
    ):
        """
        Deliberately does nothing.

        We DO NOT fetch the entire Tamil Nadu dataset
        in the background because that was causing the
        Render timeout.

        Real data is fetched for the user's district
        when /api/market-rates is requested.
        """

        print(
            f"ℹ️ Agmarknet background refresh skipped "
            f"for whole state: {state}"
        )