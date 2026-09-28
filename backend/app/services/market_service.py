import os
import datetime
from typing import Dict, List, Optional, Tuple

import requests

from app.models.schemas import (
    MarketRatesResponse,
    MarketItem,
)


class MarketService:

    # =====================================================
    # AGMARKNET / DATA.GOV.IN
    # =====================================================

    AGMARKNET_URL = (
        "https://api.data.gov.in/resource/"
        "9ef84268-d588-465a-a308-a864a43d0070"
    )

    API_TIMEOUT = 20
    API_LIMIT = 500

    # In-memory cache.
    #
    # Example:
    # {
    #     "Tamil Nadu": {
    #         "records": [...],
    #         "updated_at": ...
    #     }
    # }
    _state_cache: Dict[str, Dict] = {}


    # =====================================================
    # LOCATION HELPERS
    # =====================================================

    @staticmethod
    def _clean_location_name(value: Optional[str]) -> str:

        if not value:
            return ""

        value = str(value).strip()

        value = (
            value
            .replace(" District", "")
            .replace(" district", "")
            .strip()
        )

        return value


    @staticmethod
    def _normalise_text(value: Optional[str]) -> str:

        if not value:
            return ""

        return (
            str(value)
            .strip()
            .lower()
            .replace(" district", "")
            .replace(" dist.", "")
            .replace(" dist", "")
            .strip()
        )


    @staticmethod
    def _district_matches(
        requested_district: Optional[str],
        record_district: Optional[str]
    ) -> bool:

        requested = MarketService._normalise_text(
            requested_district
        )

        record = MarketService._normalise_text(
            record_district
        )

        if not requested or not record:
            return False

        if requested == record:
            return True

        if requested in record:
            return True

        if record in requested:
            return True

        return False


    @staticmethod
    def _state_matches(
        requested_state: Optional[str],
        record_state: Optional[str]
    ) -> bool:

        requested = MarketService._normalise_text(
            requested_state
        )

        record = MarketService._normalise_text(
            record_state
        )

        if not requested or not record:
            return False

        if requested == record:
            return True

        if requested in record:
            return True

        if record in requested:
            return True

        return False


    @staticmethod
    def _get_location_from_coords(
        lat: Optional[float],
        lon: Optional[float]
    ) -> Tuple[Optional[str], Optional[str], Optional[str]]:

        """
        Reverse geocodes GPS coordinates.

        Returns:

            state,
            district,
            locality

        No fake/default location is returned here.
        """

        if lat is None or lon is None:
            return None, None, None

        try:

            geo_url = (
                "https://nominatim.openstreetmap.org/reverse"
            )

            params = {
                "lat": lat,
                "lon": lon,
                "format": "json",
                "zoom": 12,
                "addressdetails": 1
            }

            headers = {
                "User-Agent": (
                    "SmartAgriApp/1.0 "
                    "(agmarknet-market-service)"
                )
            }

            response = requests.get(
                geo_url,
                params=params,
                headers=headers,
                timeout=10
            )

            if response.status_code != 200:

                print(
                    "⚠️ Reverse geocoding failed: "
                    f"HTTP {response.status_code}"
                )

                return None, None, None

            data = response.json()

            address = data.get(
                "address",
                {}
            )

            state = (
                address.get("state")
                or address.get("region")
            )

            district = (
                address.get("state_district")
                or address.get("district")
                or address.get("county")
            )

            locality = (
                address.get("town")
                or address.get("city")
                or address.get("municipality")
                or address.get("village")
                or address.get("suburb")
                or address.get("city_district")
            )

            state = MarketService._clean_location_name(
                state
            )

            district = MarketService._clean_location_name(
                district
            )

            locality = MarketService._clean_location_name(
                locality
            )

            print(
                "📍 GPS reverse geocode: "
                f"state={state}, "
                f"district={district}, "
                f"locality={locality}"
            )

            return (
                state or None,
                district or None,
                locality or None
            )

        except Exception as e:

            print(
                f"⚠️ Reverse geocoding error: {e}"
            )

            return None, None, None


    # =====================================================
    # CATEGORY
    # =====================================================

    @staticmethod
    def _detect_category(
        commodity: str
    ) -> str:

        commodity_lower = (
            str(commodity or "")
            .strip()
            .lower()
        )

        vegetables = {
            "tomato",
            "onion",
            "potato",
            "brinjal",
            "eggplant",
            "cabbage",
            "cauliflower",
            "carrot",
            "beetroot",
            "beans",
            "green chilli",
            "chilli green",
            "okra",
            "ladies finger",
            "bhindi",
            "drumstick",
            "cucumber",
            "bottle gourd",
            "bitter gourd",
            "ridge gourd",
            "pumpkin",
            "ash gourd",
            "snake gourd",
            "garlic",
            "ginger",
            "peas",
            "spinach",
            "amaranth",
        }

        pulses = {
            "tur",
            "tur dal",
            "arhar",
            "gram",
            "bengal gram",
            "black gram",
            "urad",
            "green gram",
            "moong",
            "lentil",
            "masoor",
            "horse gram",
            "cowpea",
        }

        spices = {
            "chilli",
            "red chilli",
            "dry chilli",
            "coriander",
            "cumin",
            "turmeric",
            "pepper",
            "cardamom",
            "clove",
            "nutmeg",
            "fenugreek",
        }

        cash_crops = {
            "cotton",
            "sugarcane",
            "tobacco",
            "groundnut",
            "castor seed",
            "sunflower",
            "sesamum",
            "sesame",
            "copra",
        }

        grains = {
            "rice",
            "paddy",
            "wheat",
            "maize",
            "jowar",
            "sorghum",
            "bajra",
            "ragi",
            "millets",
            "barley",
        }

        if commodity_lower in vegetables:
            return "Vegetables"

        if commodity_lower in pulses:
            return "Pulses"

        if commodity_lower in spices:
            return "Spices"

        if commodity_lower in cash_crops:
            return "Cash Crops"

        if commodity_lower in grains:
            return "Grains"

        # Partial matching
        if any(
            item in commodity_lower
            for item in vegetables
        ):
            return "Vegetables"

        if any(
            item in commodity_lower
            for item in pulses
        ):
            return "Pulses"

        if any(
            item in commodity_lower
            for item in spices
        ):
            return "Spices"

        if any(
            item in commodity_lower
            for item in cash_crops
        ):
            return "Cash Crops"

        if any(
            item in commodity_lower
            for item in grains
        ):
            return "Grains"

        return "General"


    # =====================================================
    # PRICE PARSING
    # =====================================================

    @staticmethod
    def _safe_float(
        value
    ) -> float:

        try:

            if value is None:
                return 0.0

            value = str(value).strip()

            if not value:
                return 0.0

            return float(
                value.replace(",", "")
            )

        except (
            ValueError,
            TypeError
        ):

            return 0.0


    # =====================================================
    # AGMARKNET FETCH
    # =====================================================

    @staticmethod
    def _fetch_agmarknet_records(
        state: str,
        district: Optional[str] = None
    ) -> List[dict]:

        """
        Fetch actual Agmarknet records.

        If district is provided, the API request is
        district-scoped and the returned records are
        STRICTLY checked again before use.
        """

        api_key = (
            os.getenv(
                "AGMARKNET_API_KEY",
                ""
            )
            .strip()
        )

        if not api_key:

            print(
                "❌ AGMARKNET_API_KEY is not configured."
            )

            return []

        clean_state = (
            MarketService._clean_location_name(
                state
            )
        )

        clean_district = (
            MarketService._clean_location_name(
                district
            )
            if district
            else ""
        )

        if not clean_state:

            print(
                "❌ Cannot fetch Agmarknet: "
                "state is empty."
            )

            return []

        params = {
            "api-key": api_key,
            "format": "json",
            "limit": MarketService.API_LIMIT,
            "filters[state.keyword]": clean_state,
        }

        # IMPORTANT:
        #
        # If district is known, request ONLY that district.
        # We do NOT fallback to another district.
        if clean_district:

            params[
                "filters[district]"
            ] = clean_district

        print(
            "🌐 Agmarknet request: "
            f"state={clean_state}, "
            f"district={clean_district or 'ALL'}"
        )

        try:

            response = requests.get(
                MarketService.AGMARKNET_URL,
                params=params,
                timeout=MarketService.API_TIMEOUT
            )

            print(
                "📡 Agmarknet HTTP status: "
                f"{response.status_code}"
            )

            if response.status_code != 200:

                print(
                    "❌ Agmarknet API returned "
                    f"HTTP {response.status_code}: "
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
                    "⚠️ Agmarknet response does not "
                    "contain a valid records list."
                )

                return []

            # -------------------------------------------------
            # Strict state/district validation
            # -------------------------------------------------

            filtered_records = []

            for record in records:

                record_state = record.get(
                    "state"
                )

                record_district = record.get(
                    "district"
                )

                if not MarketService._state_matches(
                    clean_state,
                    record_state
                ):
                    continue

                if clean_district:

                    if not MarketService._district_matches(
                        clean_district,
                        record_district
                    ):
                        continue

                filtered_records.append(
                    record
                )

            print(
                "✅ Agmarknet records received: "
                f"{len(records)}"
            )

            print(
                "✅ Agmarknet records after "
                "strict location filtering: "
                f"{len(filtered_records)}"
            )

            return filtered_records

        except requests.Timeout:

            print(
                "⏱️ Agmarknet request timed out "
                f"after {MarketService.API_TIMEOUT}s."
            )

            return []

        except requests.RequestException as e:

            print(
                f"❌ Agmarknet network error: {e}"
            )

            return []

        except ValueError as e:

            print(
                f"❌ Agmarknet JSON parsing error: {e}"
            )

            return []

        except Exception as e:

            print(
                f"❌ Agmarknet unexpected error: {e}"
            )

            return []


    # =====================================================
    # STATE CACHE
    # =====================================================

    @staticmethod
    def refresh_state_cache(
        state: str
    ) -> bool:

        """
        Background refresher.

        This downloads actual Agmarknet data for the state
        and stores it in memory.

        IMPORTANT:
        This cache is NOT used as a fallback to another
        district. Endpoint filtering remains strict.
        """

        clean_state = (
            MarketService._clean_location_name(
                state
            )
        )

        if not clean_state:

            return False

        print(
            "🔄 Refreshing Agmarknet state cache: "
            f"{clean_state}"
        )

        records = (
            MarketService._fetch_agmarknet_records(
                state=clean_state,
                district=None
            )
        )

        if not records:

            print(
                "⚠️ No state cache data received for "
                f"{clean_state}"
            )

            return False

        MarketService._state_cache[
            clean_state.lower()
        ] = {
            "records": records,
            "updated_at": datetime.datetime.utcnow()
        }

        print(
            "✅ State cache refreshed: "
            f"{clean_state} "
            f"({len(records)} records)"
        )

        return True


    @staticmethod
    def _get_cached_district_records(
        state: str,
        district: str
    ) -> List[dict]:

        cache = MarketService._state_cache.get(
            state.lower()
        )

        if not cache:
            return []

        records = cache.get(
            "records",
            []
        )

        result = []

        for record in records:

            record_state = record.get(
                "state"
            )

            record_district = record.get(
                "district"
            )

            if not MarketService._state_matches(
                state,
                record_state
            ):
                continue

            if not MarketService._district_matches(
                district,
                record_district
            ):
                continue

            result.append(
                record
            )

        return result


    # =====================================================
    # RECORD → MARKET ITEM
    # =====================================================

    @staticmethod
    def _record_to_market_item(
        record: dict,
        requested_category: Optional[str],
        user_state: str,
        user_district: str,
        today_str: str
    ) -> Optional[MarketItem]:

        commodity = str(
            record.get(
                "commodity",
                ""
            )
        ).strip()

        market = str(
            record.get(
                "market",
                ""
            )
        ).strip()

        record_state = str(
            record.get(
                "state",
                user_state
            )
        ).strip()

        record_district = str(
            record.get(
                "district",
                user_district
            )
        ).strip()

        if not commodity or not market:

            return None

        modal_price = MarketService._safe_float(
            record.get(
                "modal_price"
            )
        )

        min_price = MarketService._safe_float(
            record.get(
                "min_price"
            )
        )

        max_price = MarketService._safe_float(
            record.get(
                "max_price"
            )
        )

        arrival_date = str(
            record.get(
                "arrival_date",
                ""
            )
        ).strip()

        detected_category = (
            MarketService._detect_category(
                commodity
            )
        )

        # If category is supplied, only matching
        # actual commodities are returned.
        if (
            requested_category
            and requested_category.strip().lower()
            != "all"
        ):

            if (
                detected_category.lower()
                != requested_category.strip().lower()
            ):

                return None

        return MarketItem(
            commodity=commodity,

            category=detected_category,

            mandi_name=(
                f"{market} "
                f"({record_district})"
            ),

            state=record_state,

            unit="₹ / Quintal",

            modal_price=modal_price,

            min_price=min_price,

            max_price=max_price,

            # Agmarknet record itself does not provide
            # a reliable 24-hour percentage change.
            # Therefore we do NOT invent one.
            price_trend="STABLE",

            price_change_24h_pct=0.0,

            last_updated=(
                arrival_date
                if arrival_date
                else today_str
            )
        )


    # =====================================================
    # MAIN MARKET METHOD
    # =====================================================

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

        """
        Fetch actual Agmarknet mandi prices based on
        the farmer's real location.

        Priority:

        1. Explicit state/district from request
        2. GPS reverse geocoding
        3. No fake/default location

        IMPORTANT:

        If district is known, only that district's
        records are returned.

        There is NO fallback to another district.
        """

        today_str = (
            datetime.date.today()
            .strftime("%d %b %Y")
        )

        # =================================================
        # RESOLVE LOCATION
        # =================================================

        detected_state = None
        detected_district = None
        detected_locality = None

        if lat is not None and lon is not None:

            (
                detected_state,
                detected_district,
                detected_locality
            ) = (
                MarketService._get_location_from_coords(
                    lat,
                    lon
                )
            )

        user_state = (
            MarketService._clean_location_name(
                state
            )
            if state
            else ""
        )

        user_district = (
            MarketService._clean_location_name(
                district
            )
            if district
            else ""
        )

        user_location_name = (
            MarketService._clean_location_name(
                location_name
            )
            if location_name
            else ""
        )

        if not user_state:

            user_state = (
                detected_state
                or ""
            )

        if not user_district:

            user_district = (
                detected_district
                or ""
            )

        # location_name is useful as a local
        # market priority/search term.
        #
        # It is NOT blindly treated as a district.
        if not user_location_name:

            user_location_name = (
                detected_locality
                or ""
            )

        # =================================================
        # NO LOCATION = NO FAKE MARKET DATA
        # =================================================

        if not user_state or not user_district:

            print(
                "❌ Market location could not be resolved."
            )

            return MarketRatesResponse(
                market_overview=(
                    "Market prices unavailable: "
                    "farmer location/state/district "
                    "could not be determined."
                ),
                date=today_str,
                commodities=[]
            )

        print(
            "📍 Market location resolved: "
            f"{user_location_name or user_district}, "
            f"{user_district}, "
            f"{user_state}"
        )

        # =================================================
        # FIRST: TRY EXACT DISTRICT API REQUEST
        # =================================================

        records = (
            MarketService._fetch_agmarknet_records(
                state=user_state,
                district=user_district
            )
        )

        # =================================================
        # SECOND: USE STATE CACHE ONLY FOR SAME DISTRICT
        # =================================================

        if not records:

            cached_records = (
                MarketService._get_cached_district_records(
                    state=user_state,
                    district=user_district
                )
            )

            if cached_records:

                print(
                    "💾 Using cached Agmarknet records "
                    f"for {user_district}, {user_state}"
                )

                records = cached_records

        # =================================================
        # NO CROSS-DISTRICT FALLBACK
        # =================================================

        if not records:

            print(
                "❌ No Agmarknet data found for "
                f"{user_district}, {user_state}"
            )

            return MarketRatesResponse(
                market_overview=(
                    "No Agmarknet mandi price records "
                    "were found for "
                    f"{user_district}, {user_state}."
                ),
                date=today_str,
                commodities=[]
            )

        # =================================================
        # CONVERT RECORDS
        # =================================================

        commodities: List[MarketItem] = []

        for record in records:

            market_item = (
                MarketService._record_to_market_item(
                    record=record,
                    requested_category=category,
                    user_state=user_state,
                    user_district=user_district,
                    today_str=today_str
                )
            )

            if market_item is None:
                continue

            commodities.append(
                market_item
            )

        # =================================================
        # QUERY FILTER
        # =================================================

        if query and commodities:

            q = (
                query
                .strip()
                .lower()
            )

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

        # =================================================
        # LOCATION NAME PRIORITY
        # =================================================

        if (
            user_location_name
            and commodities
        ):

            location_query = (
                user_location_name
                .strip()
                .lower()
            )

            matching_location_items = [
                item
                for item in commodities
                if location_query
                in str(
                    item.mandi_name
                ).lower()
            ]

            if matching_location_items:

                other_items = [
                    item
                    for item in commodities
                    if item not in matching_location_items
                ]

                commodities = (
                    matching_location_items
                    + other_items
                )

        # =================================================
        # FINAL RESPONSE
        # =================================================

        overview = (
            "Agmarknet mandi prices for "
            f"{user_district}, {user_state}. "
            "Only actual records from the "
            "requested district are shown."
        )

        return MarketRatesResponse(
            market_overview=overview,
            date=today_str,
            commodities=commodities
        )