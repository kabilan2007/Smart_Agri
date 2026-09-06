import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';
import '../models/crop_recommendation_model.dart';
import '../models/chat_message_model.dart';
import '../models/disease_detection_model.dart';
import '../models/market_rate_model.dart';

class ApiService {
  // Remote Render URL or local dev server
  // Change to http://10.0.2.2:8000 for Android Emulator or http://localhost:8000 for web/desktop
  static const String _baseUrl = 'https://smart-agri-backend-6efw.onrender.com';

  // Global dynamic location variables updated by LocationProvider/GPS
  static double? currentLatitude;
  static double? currentLongitude;
  static String? currentState;
  static String? currentDistrict;
  static String? currentCity;
  static String? currentPlaceName;

  /// Updates globally shared GPS & region coordinates for subsequent API calls
  static void updateGlobalLocation({
    required double lat,
    required double lon,
    String? state,
    String? district,
    String? city,
    String? placeName,
  }) {
    currentLatitude = lat;
    currentLongitude = lon;
    if (state != null && state.isNotEmpty) currentState = state;
    if (district != null && district.isNotEmpty) currentDistrict = district;
    if (city != null && city.isNotEmpty) currentCity = city;
    if (placeName != null && placeName.isNotEmpty) currentPlaceName = placeName;
  }

  static Uri _uri(String path, [Map<String, String>? queryParams]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ---------- 1. Weather & Agricultural Risk Alerts ----------
  static Future<WeatherAlertsResponse?> getWeatherAlerts({
    double? lat,
    double? lon,
    String? state,
    String? district,
  }) async {
    final effectiveLat = lat ?? currentLatitude;
    final effectiveLon = lon ?? currentLongitude;
    if (effectiveLat == null || effectiveLon == null) return null;

    final params = <String, String>{
      'lat': effectiveLat.toString(),
      'lon': effectiveLon.toString(),
      'latitude': effectiveLat.toString(),
      'longitude': effectiveLon.toString(),
    };
    if (district != null && district.isNotEmpty) {
      params['district'] = district;
    } else if (currentDistrict != null && currentDistrict!.isNotEmpty) {
      params['district'] = currentDistrict!;
    }
    if (state != null && state.isNotEmpty) {
      params['state'] = state;
    } else if (currentState != null && currentState!.isNotEmpty) {
      params['state'] = currentState!;
    }

    try {
      final response = await http
          .get(_uri('/api/weather-alerts', params), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return WeatherAlertsResponse.fromJson(data);
      }
    } catch (e) {
      // Return null on error so UI shows skeleton/fallback
    }
    return null;
  }

  /// Alias for getWeatherAlerts
  static Future<WeatherAlertsResponse?> fetchWeather({
    double? lat,
    double? lon,
    String? state,
    String? district,
  }) =>
      getWeatherAlerts(lat: lat, lon: lon, state: state, district: district);

  // ---------- 2. Crop Recommendation ----------
  static Future<CropRecommendationResponse?> getCropRecommendation({
    double? lat,
    double? lon,
    required String soilType,
    String? locationName,
    String? state,
    String? district,
    String waterSource = 'Borewell / Canal',
    String language = 'en',
  }) async {
    final effectiveLat = lat ?? currentLatitude ?? 11.0168;
    final effectiveLon = lon ?? currentLongitude ?? 76.9558;
    final effectiveLocName =
        locationName ?? currentPlaceName ?? currentCity ?? currentDistrict;

    try {
      final body = json.encode({
        'latitude': effectiveLat,
        'longitude': effectiveLon,
        'location_name': effectiveLocName,
        'state': state ?? currentState,
        'district': district ?? currentDistrict,
        'soil_type': soilType,
        'water_source': waterSource,
        'language': language,
      });
      final response = await http
          .post(_uri('/api/crop-recommendation'),
              headers: _headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return CropRecommendationResponse.fromJson(data);
      }
    } catch (e) {
      // silent fail
    }
    return null;
  }

  // ---------- 3. Agri AI Chatbot (AI Doctor) ----------
  static Future<AgriChatResponseModel?> sendChatMessage({
    required String message,
    required String language,
    required List<ChatMessageModel> history,
    Map<String, dynamic>? farmerContext,
  }) async {
    try {
      final historyJson = history
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final dynamicFarmerContext = <String, dynamic>{
        'latitude': currentLatitude,
        'longitude': currentLongitude,
        'state': currentState,
        'district': currentDistrict,
        'city': currentCity,
        'place_name': currentPlaceName,
        ...?farmerContext,
      };

      final body = json.encode({
        'message': message,
        'user_query': message,
        'prompt': message,
        'query': message,
        'language': language,
        'history': historyJson,
        'farmer_context': dynamicFarmerContext,
      });

      final response = await http
          .post(_uri('/api/agri-chat'), headers: _headers, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return AgriChatResponseModel.fromJson(data);
      }
    } catch (e) {
      // silent fail
    }
    return null;
  }

  // ---------- 4. Plant Disease Detection ----------
  static Future<DiseaseDetectionResponse?> detectDisease(File imageFile) async {
    try {
      final request =
          http.MultipartRequest('POST', _uri('/api/disease-detection'));
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return DiseaseDetectionResponse.fromJson(data);
      }
    } catch (e) {
      // silent fail
    }
    return null;
  }

  // ---------- 5. Market Rates (Dynamic Mandi Rates) ----------
  static Future<MarketRatesResponse?> getMarketRates({
    String? category,
    String? query,
    double? lat,
    double? lon,
    String? state,
    String? district,
    String? locationName,
  }) async {
    final effectiveLat = lat ?? currentLatitude;
    final effectiveLon = lon ?? currentLongitude;
    final effectiveState = state ?? currentState;
    final effectiveDistrict = district ?? currentDistrict;
    final effectiveLocName = locationName ?? currentPlaceName ?? currentCity;

    try {
      final params = <String, String>{};
      if (category != null && category != 'All') params['category'] = category;
      if (query != null && query.isNotEmpty) params['query'] = query;
      if (effectiveLat != null) {
        params['lat'] = effectiveLat.toString();
        params['latitude'] = effectiveLat.toString();
      }
      if (effectiveLon != null) {
        params['lon'] = effectiveLon.toString();
        params['longitude'] = effectiveLon.toString();
      }
      if (effectiveState != null && effectiveState.isNotEmpty) {
        params['state'] = effectiveState;
      }
      if (effectiveDistrict != null && effectiveDistrict.isNotEmpty) {
        params['district'] = effectiveDistrict;
      }
      if (effectiveLocName != null && effectiveLocName.isNotEmpty) {
        params['location_name'] = effectiveLocName;
      }

      final response = await http
          .get(_uri('/api/market-rates', params.isEmpty ? null : params),
              headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return MarketRatesResponse.fromJson(data);
      }
    } catch (e) {
      // silent fail
    }
    return null;
  }

  /// Alias for getMarketRates
  static Future<MarketRatesResponse?> fetchMandiRates({
    String? category,
    String? query,
    double? lat,
    double? lon,
    String? state,
    String? district,
    String? locationName,
  }) =>
      getMarketRates(
        category: category,
        query: query,
        lat: lat,
        lon: lon,
        state: state,
        district: district,
        locationName: locationName,
      );
}

/// Weather Repository for clean domain separation
class WeatherRepository {
  Future<WeatherAlertsResponse?> fetchWeather({
    double? lat,
    double? lon,
    String? state,
    String? district,
  }) {
    return ApiService.getWeatherAlerts(
      lat: lat,
      lon: lon,
      state: state,
      district: district,
    );
  }
}

/// Market Rates Repository for clean domain separation
class MarketRepository {
  Future<MarketRatesResponse?> fetchMandiRates({
    String? category,
    String? query,
    double? lat,
    double? lon,
    String? state,
    String? district,
    String? locationName,
  }) {
    return ApiService.getMarketRates(
      category: category,
      query: query,
      lat: lat,
      lon: lon,
      state: state,
      district: district,
      locationName: locationName,
    );
  }
}
