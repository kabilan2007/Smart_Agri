import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';
import '../models/crop_recommendation_model.dart';
import '../models/chat_message_model.dart';
import '../models/disease_detection_model.dart';
import '../models/market_rate_model.dart';

class ApiService {
  // Change this to your local machine IP when testing on a physical device
  // Android Emulator: http://10.0.2.2:8000
  // iOS Simulator: http://localhost:8000
  // Physical Device (same WiFi): http://<YOUR_LOCAL_IP>:8000
  static const String _baseUrl = 'https://smart-agri-backend-6efw.onrender.com';

  static Uri _uri(String path, [Map<String, String>? queryParams]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ---------- 1. Weather Alerts ----------
  static Future<WeatherAlertsResponse?> getWeatherAlerts({
    required double lat,
    required double lon,
  }) async {
    try {
      final response = await http
          .get(
            _uri('/api/weather-alerts', {
              'lat': lat.toString(),
              'lon': lon.toString(),
            }),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return WeatherAlertsResponse.fromJson(data);
      }
    } catch (e) {
      // Returns null on error; UI shows skeleton/fallback
    }
    return null;
  }

  // ---------- 2. Crop Recommendation ----------
  static Future<CropRecommendationResponse?> getCropRecommendation({
    required double lat,
    required double lon,
    required String soilType,
    String? locationName,
    String waterSource = 'Borewell / Canal',
    String language = 'en',
  }) async {
    try {
      final body = json.encode({
        'latitude': lat,
        'longitude': lon,
        'location_name': locationName,
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

  // ---------- 3. Agri AI Chatbot ----------
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

      final body = json.encode({
        'message': message,
        'language': language,
        'history': historyJson,
        'farmer_context': farmerContext ?? {},
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

  // ---------- 5. Market Rates ----------
  static Future<MarketRatesResponse?> getMarketRates({
    String? category,
    String? query,
    double? lat,
    double? lon,
    String? state,
    String? district,
  }) async {
    try {
      final params = <String, String>{};
      if (category != null && category != 'All') params['category'] = category;
      if (query != null && query.isNotEmpty) params['query'] = query;
      if (lat != null) params['lat'] = lat.toString();
      if (lon != null) params['lon'] = lon.toString();
      if (state != null && state.isNotEmpty) params['state'] = state;
      if (district != null && district.isNotEmpty) params['district'] = district;

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
}
