import os
import requests
import datetime
import threading
import time
from typing import Optional

from app.models.schemas import MarketRatesResponse, MarketItem


class MarketService:
    """
    Agmarknet market-rate service.

    Flow:
        GPS coordinates
            ↓
        District / State
            ↓
        Cached Agmarknet records
            ↓
        District mandi records
            ↓
        Real modal/min/max prices
    """

    # ---------------------------------------------------------
    # CONFIGURATION
    # ---------------------------------------------------------

    AGMARKNET_URL = (
        "https://api.data.gov.in/resource/"
        "9ef84268-d588-465a-a308-a864a43d0070"
    )

    # Cache is kept for 12 hours.
    # This prevents every mobile request from hitting Agmarknet.
    _CACHE_MAX_AGE_HOURS = 12

    # Number of records requested from Agmarknet.
    _API_LIMIT = 300

    # Agmarknet can be slow.
    _API_TIMEOUT_SECONDS = 15

    # Nominatim reverse-geocoding timeout.
    _GEO_TIMEOUT_SECONDS = 5

    # In-memory cache:
    # {
    #   "Tamil Nadu": {
    #       "records": [...],
    #       "fetched_at": datetime
    #   }
    # }
    _cache = {}

    # Prevent two requests from simultaneously fetching Agmarknet.
    _refresh_lock = threading.Lock()

    # ---------------------------------------------------------
    # TEXT NORMALIZATION
    # ---------------------------------------------------------

    @staticmethod
    def _normalize_name(value: Optional[str]) -> str:
        """
        Normalize district/state/market names for matching.

        Example:
            "Coimbatore District" -> "coimbatore"
            "COIMBATORE"          -> "coimbatore"
        """

        if not value:
            return ""

        value = str(value).strip().lower()

        replacements = [
            " district",
            " dist.",
            " dist",
        ]

        for item in replacements:
            if value.endswith(item):
                value = value[: -len(item)]

        # Remove extra spaces
        value = " ".join(value.split())

        return value

    # ---------------------------------------------------------
    # LOCATION FROM GPS
    # ---------------------------------------------------------

    @staticmethod
    def _get_location_from_coords(
        lat: Optional[float],
        lon: Optional[float]
    ):
        """
        Reverse geocode GPS coordinates using OpenStreetMap Nominatim.

        Returns:
            (state, district)
        """

        if lat is None or lon is None:
            return "Tamil Nadu", "Coimbatore"

        try:
            geo_url = "https://nominatim.openstreetmap.org/reverse"

            params = {
                "lat": lat,
                "lon": lon,
                "format": "json",
                "zoom": 10,
                "addressdetails": 1,
            }

            headers = {
                "User-Agent": "SmartAgriAppMobile/1.0"
            }

            response = requests.get(
                geo_url,
                params=params,
                headers=headers,
                timeout=MarketService._GEO_TIMEOUT_SECONDS
            )

            if response.status_code != 200:
                print(
                    f"⚠️ Nominatim returned "
                    f"{response.status_code}"
                )
                return "Tamil Nadu", "Coimbatore"

            data = response.json()
            address = data.get("address", {})

            state = (
                address.get("state")
                or "Tamil Nadu"
            )

            district = (
                address.get("state_district")
                or address.get("district")
                or address.get("county")
                or address.get("city_district")
                or address.get("city")
                or "Coimbatore"
            )

            district = (
                str(district)
                .replace(" District", "")
                .replace(" district", "")
                .strip()
            )

            print(
                f"📍 GPS location detected: "
                f"{district}, {state}"
            )

            return str(state).strip(), district

        except Exception as e:
            print(f"⚠️ Geocoding error: {e}")

            return "Tamil Nadu", "Coimbatore"

    # ---------------------------------------------------------
    # CACHE HELPERS
    # ---------------------------------------------------------

    @staticmethod
    def _get_cached_entry(state: str):
        return MarketService._cache.get(state)

    @staticmethod
    def _cache_age_hours(state: str) -> Optional[float]:

        entry = MarketService._get_cached_entry(state)

        if not entry:
            return None

        fetched_at = entry.get("fetched_at")

        if not fetched_at:
            return None

        age = datetime.datetime.now() - fetched_at

        return age.total_seconds() / 3600

    @staticmethod
    def _get_cached_records(
        state: str,
        allow_stale: bool = False
    ):
        """
        Return cached records.

        Normal requests use only cache newer than 12 hours.

        If allow_stale=True, stale cache is returned as a
        fallback when Agmarknet is temporarily unavailable.
        """

        entry = MarketService._get_cached_entry(state)

        if not entry:
            return []

        records = entry.get("records", [])
        fetched_at = entry.get("fetched_at")

        if not fetched_at:
            return []

        age = datetime.datetime.now() - fetched_at
        age_hours = age.total_seconds() / 3600

        if age_hours <= MarketService._CACHE_MAX_AGE_HOURS:
            print(
                f"ℹ️ Using cached Agmarknet data for "
                f"{state} "
                f"({int(age.total_seconds() // 60)} min old)"
            )

            return records

        if allow_stale:
            print(
                f"⚠️ Using stale Agmarknet cache for "
                f"{state} "
                f"({int(age_hours)} hours old)"
            )

            return records

        return []

    # ---------------------------------------------------------
    # SAVE CACHE
    # ---------------------------------------------------------

    @staticmethod
    def _save_cache(
        state: str,
        records: list
    ):
        MarketService._cache[state] = {
            "records": records,
            "fetched_at": datetime.datetime.now()
        }

        print(
            f"💾 Agmarknet cache updated: "
            f"{state} - {len(records)} records"
        )

    # ---------------------------------------------------------
    # FETCH AGMARKNET
    # ---------------------------------------------------------

    @staticmethod
    def _fetch_agmarknet_data(
        state: str
    ):
        """
        Fetch market records from data.gov.in / Agmarknet.

        This function is called only when cache needs refreshing.
        """

        api_key = os.getenv(
            "AGMARKNET_API_KEY",
            ""
        ).strip()

        if not api_key:
            print(
                "❌ AGMARKNET_API_KEY is missing."
            )

            return []

        params = {
            "api-key": api_key,
            "format": "json",
            "limit": str(
                MarketService._API_LIMIT
            ),
            "filters[state]": state,
        }

        try:

            print(
                f"🌐 Fetching Agmarknet data "
                f"for {state}..."
            )

            response = requests.get(
                MarketService.AGMARKNET_URL,
                params=params,
                timeout=MarketService._API_TIMEOUT_SECONDS
            )

            print(
                f"📡 Agmarknet HTTP status: "
                f"{response.status_code}"
            )

            if response.status_code != 200:

                print(
                    "⚠️ Agmarknet API error: "
                    f"{response.text[:500]}"
                )

                return []

            data = response.json()

            records = data.get(
                "records",
                []
            )

            if not isinstance(records, list):
                print(
                    "⚠️ Agmarknet returned invalid "
                    "records format."
                )

                return []

            print(
                f"✅ Agmarknet returned "
                f"{len(records)} records"
            )

            if records:
                MarketService._save_cache(
                    state,
                    records
                )

            return records

        except requests.exceptions.Timeout:

            print(
                "⏱️ Agmarknet request timed out."
            )

            return []

        except requests.exceptions.RequestException as e:

            print(
                f"❌ Agmarknet network error: {e}"
            )

            return []

        except Exception as e:

            print(
                f"❌ Agmarknet parsing/error: {e}"
            )

            return []

    # ---------------------------------------------------------
    # GET RECORDS
    # ---------------------------------------------------------

    @staticmethod
    def _get_records(
        state: str
    ):
        """
        Cache-first strategy.

        1. Fresh cache -> return immediately.
        2. No fresh cache -> fetch Agmarknet.
        3. If API fails -> stale cache.
        """

        # -------------------------------------------------
        # 1. Fresh cache
        # -------------------------------------------------

        cached_records = MarketService._get_cached_records(
            state
        )

        if cached_records:
            return cached_records

        # -------------------------------------------------
        # 2. Refresh lock
        # -------------------------------------------------

        acquired = MarketService._refresh_lock.acquire(
            timeout=1
        )

        if acquired:

            try:

                # Another request may have populated
                # cache while we waited.

                cached_records = (
                    MarketService._get_cached_records(
                        state
                    )
                )

                if cached_records:
                    return cached_records

                # -------------------------------------------------
                # 3. Fetch live Agmarknet data
                # -------------------------------------------------

                records = (
                    MarketService._fetch_agmarknet_data(
                        state
                    )
                )

                if records:
                    return records

                # -------------------------------------------------
                # 4. Stale cache fallback
                # -------------------------------------------------

                return MarketService._get_cached_records(
                    state,
                    allow_stale=True
                )

            finally:

                MarketService._refresh_lock.release()

        # -------------------------------------------------
        # Lock wasn't acquired.
        # Use existing stale cache if available.
        # -------------------------------------------------

        return MarketService._get_cached_records(
            state,
            allow_stale=True
        )

    # ---------------------------------------------------------
    # CONVERT AGMARKNET RECORD -> MarketItem
    # ---------------------------------------------------------

    @staticmethod
    def _record_to_market_item(
        item: dict,
        user_state: str,
        user_district: str
    ) -> MarketItem:

        commodity = str(
            item.get(
                "commodity",
                "Crop"
            )
        ).strip()

        market = str(
            item.get(
                "market",
                "Mandi"
            )
        ).strip()

        district = str(
            item.get(
                "district",
                user_district
            )
        ).strip()

        state = str(
            item.get(
                "state",
                user_state
            )
        ).strip()

        # ---------------------------------------------
        # Prices
        # ---------------------------------------------

        try:
            modal_price = float(
                item.get(
                    "modal_price",
                    0
                )
            )
        except (ValueError, TypeError):
            modal_price = 0.0

        try:
            min_price = float(
                item.get(
                    "min_price",
                    0
                )
            )
        except (ValueError, TypeError):
            min_price = 0.0

        try:
            max_price = float(
                item.get(
                    "max_price",
                    0
                )
            )
        except (ValueError, TypeError):
            max_price = 0.0

        # ---------------------------------------------
        # Date
        # ---------------------------------------------

        arrival_date = (
            item.get("arrival_date")
            or item.get("price_date")
            or datetime.date.today().strftime(
                "%d %b %Y"
            )
        )

        # ---------------------------------------------
        # Category
        #
        # We don't invent a category from the API.
        # Keep "General" unless the app sends a category.
        # ---------------------------------------------

        category = "General"

        return MarketItem(
            commodity=commodity,
            category=category,
            mandi_name=f"{market} ({district})",
            state=state,
            unit="₹ / Quintal",
            modal_price=modal_price,
            min_price=min_price,
            max_price=max_price,
            price_trend="STABLE",
            price_change_24h_pct=0.0,
            last_updated=str(arrival_date),
        )

    # ---------------------------------------------------------
    # MAIN MARKET FUNCTION
    # ---------------------------------------------------------

    @staticmethod
    def get_live_market_rates(
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

        # -------------------------------------------------
        # LOCATION
        # -------------------------------------------------

        if lat is not None and lon is not None:

            detected_state, detected_district = (
                MarketService._get_location_from_coords(
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

        else:

            user_state = (
                state
                or "Tamil Nadu"
            )

            user_district = (
                district
                or "Coimbatore"
            )

        user_state = str(
            user_state
        ).strip()

        user_district = str(
            user_district
        ).strip()

        normalized_district = (
            MarketService._normalize_name(
                user_district
            )
        )

        print(
            f"📍 Market request location: "
            f"{user_district}, {user_state}"
        )

        # -------------------------------------------------
        # GET RECORDS
        # -------------------------------------------------

        records = MarketService._get_records(
            user_state
        )

        if not records:

            return MarketRatesResponse(
                market_overview=(
                    f"No Agmarknet market data is "
                    f"currently available for "
                    f"{user_district}, {user_state}."
                ),
                date=today_str,
                commodities=[]
            )

        # -------------------------------------------------
        # DISTRICT FILTER
        # -------------------------------------------------

        district_records = []

        for item in records:

            record_district = (
                MarketService._normalize_name(
                    item.get(
                        "district",
                        ""
                    )
                )
            )

            if not record_district:
                continue

            # Exact district match
            if (
                record_district
                == normalized_district
            ):
                district_records.append(item)
                continue

            # Contains match
            if (
                normalized_district
                and (
                    normalized_district
                    in record_district
                    or
                    record_district
                    in normalized_district
                )
            ):
                district_records.append(item)

        # -------------------------------------------------
        # IMPORTANT:
        # Don't silently show another district's price.
        # User specifically wants local/district data.
        # -------------------------------------------------

        if not district_records:

            print(
                f"⚠️ No matching Agmarknet records "
                f"found for district: "
                f"{user_district}"
            )

            return MarketRatesResponse(
                market_overview=(
                    f"Agmarknet data for "
                    f"{user_district}, "
                    f"{user_state} is not available "
                    f"in the current dataset."
                ),
                date=today_str,
                commodities=[]
            )

        # -------------------------------------------------
        # CONVERT RECORDS
        # -------------------------------------------------

        commodities = []

        for item in district_records:

            try:

                market_item = (
                    MarketService._record_to_market_item(
                        item,
                        user_state,
                        user_district
                    )
                )

                commodities.append(
                    market_item
                )

            except Exception as e:

                print(
                    f"⚠️ Skipping invalid "
                    f"market record: {e}"
                )

        # -------------------------------------------------
        # CATEGORY FILTER
        # -------------------------------------------------

        # Your current API doesn't provide a reliable
        # category field in the Agmarknet response,
        # so don't incorrectly remove records based
        # on category.

        if (
            category
            and category.lower() != "all"
        ):

            # If query is used, it will still work.
            # Category filtering is intentionally not
            # applied because source category isn't
            # available reliably.
            pass

        # -------------------------------------------------
        # SEARCH FILTER
        # -------------------------------------------------

        if query and query.strip():

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

        # -------------------------------------------------
        # REMOVE DUPLICATES
        # -------------------------------------------------

        unique = {}

        for item in commodities:

            key = (
                item.commodity.lower(),
                item.mandi_name.lower()
            )

            unique[key] = item

        commodities = list(
            unique.values()
        )

        # -------------------------------------------------
        # SORT BY MANDI + COMMODITY
        # -------------------------------------------------

        commodities.sort(
            key=lambda x: (
                x.mandi_name.lower(),
                x.commodity.lower()
            )
        )

        # -------------------------------------------------
        # CACHE AGE
        # -------------------------------------------------

        cache_age = (
            MarketService._cache_age_hours(
                user_state
            )
        )

        if cache_age is None:
            source_text = "Agmarknet"
        else:
            source_text = (
                f"Agmarknet data "
                f"(cache {int(cache_age * 60)} min old)"
            )

        overview = (
            f"{source_text}: "
            f"{len(commodities)} market records "
            f"for {user_district}, "
            f"{user_state}."
        )

        return MarketRatesResponse(
            market_overview=overview,
            date=today_str,
            commodities=commodities
        )

    # ---------------------------------------------------------
    # BACKGROUND REFRESH
    # ---------------------------------------------------------

    @staticmethod
    def refresh_state_cache(
        state: str
    ):

        print(
            f"🔄 Background refresh started "
            f"for {state}"
        )

        records = (
            MarketService._fetch_agmarknet_data(
                state
            )
        )

        if records:

            print(
                f"✅ Background refresh completed "
                f"for {state}: "
                f"{len(records)} records"
            )

            return True

        print(
            f"⚠️ Background refresh failed "
            f"for {state}"
        )

        return False