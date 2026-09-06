import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'api_service.dart';

enum LocationStatus {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  success,
  error,
}

class LocationDetails {
  final double latitude;
  final double longitude;
  final String? city;
  final String? district;
  final String? state;
  final String? country;
  final String? placeName;

  LocationDetails({
    required this.latitude,
    required this.longitude,
    this.city,
    this.district,
    this.state,
    this.country,
    this.placeName,
  });

  @override
  String toString() =>
      'LocationDetails(lat: $latitude, lon: $longitude, city: $city, district: $district, state: $state)';
}

class LocationResult {
  final LocationStatus status;
  final Position? position;
  final LocationDetails? details;
  final String? errorMessage;

  LocationResult({
    required this.status,
    this.position,
    this.details,
    this.errorMessage,
  });

  bool get isSuccess => status == LocationStatus.success && position != null;
}

class LocationService {
  /// Checks whether location service (GPS) is enabled on the device
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Opens system location settings so the user can turn GPS on
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Opens app settings if permission was denied forever
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Requests location permission
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Reverse geocode coordinates to structured LocationDetails
  static Future<LocationDetails?> getDetailedLocation(
      double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = (p.locality != null && p.locality!.isNotEmpty)
            ? p.locality
            : (p.subLocality != null && p.subLocality!.isNotEmpty)
                ? p.subLocality
                : null;
        final district = (p.subAdministrativeArea != null &&
                p.subAdministrativeArea!.isNotEmpty)
            ? p.subAdministrativeArea
            : city;
        final state = p.administrativeArea;
        final country = p.country;

        final displayCity = city ?? district ?? state;
        String? formattedPlace;
        if (displayCity != null && state != null && displayCity != state) {
          formattedPlace = '$displayCity, $state';
        } else if (displayCity != null) {
          formattedPlace = displayCity;
        } else if (state != null) {
          formattedPlace = state;
        }

        return LocationDetails(
          latitude: lat,
          longitude: lon,
          city: city,
          district: district,
          state: state,
          country: country,
          placeName: formattedPlace,
        );
      }
    } catch (_) {}

    return LocationDetails(
      latitude: lat,
      longitude: lon,
    );
  }

  /// Reverse geocode latitude & longitude to local City/District & State string
  static Future<String?> getPlaceName(double lat, double lon) async {
    final details = await getDetailedLocation(lat, lon);
    return details?.placeName;
  }

  /// Gets real-time GPS location with full permission & service handling
  static Future<LocationResult> getLivePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          status: LocationStatus.serviceDisabled,
          errorMessage:
              'Location Services (GPS) are turned off. Please enable GPS to get live weather & crop advice.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            status: LocationStatus.permissionDenied,
            errorMessage:
                'Location permission was denied. Live GPS is needed for accurate weather & crop advice.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          status: LocationStatus.permissionDeniedForever,
          errorMessage:
              'Location permissions are permanently denied. Please enable them in App Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final details =
          await getDetailedLocation(position.latitude, position.longitude);

      return LocationResult(
        status: LocationStatus.success,
        position: position,
        details: details,
      );
    } catch (e) {
      return LocationResult(
        status: LocationStatus.error,
        errorMessage: 'Failed to acquire GPS location: $e',
      );
    }
  }

  /// Helper for quick position query
  static Future<Position?> getCurrentPosition() async {
    final result = await getLivePosition();
    return result.position;
  }
}

/// Global State Management for Device Location
class LocationProvider extends ChangeNotifier {
  double? _currentLatitude;
  double? _currentLongitude;
  String? _currentState;
  String? _currentDistrict;
  String? _currentCity;
  String? _placeName;
  bool _isLocating = false;
  LocationResult? _lastResult;

  double? get currentLatitude => _currentLatitude;
  double? get currentLongitude => _currentLongitude;
  String? get currentState => _currentState;
  String? get currentDistrict => _currentDistrict;
  String? get currentCity => _currentCity;
  String? get placeName => _placeName;
  bool get isLocating => _isLocating;
  LocationResult? get lastResult => _lastResult;
  bool get hasLocation =>
      _currentLatitude != null && _currentLongitude != null;

  LocationProvider() {
    // Initial fetch on provider initialization
    fetchLiveLocation();
  }

  /// Fetches real-time GPS location and updates global state
  Future<LocationResult> fetchLiveLocation({bool force = false}) async {
    if (_isLocating) return _lastResult ?? LocationResult(status: LocationStatus.error);

    _isLocating = true;
    notifyListeners();

    final result = await LocationService.getLivePosition();
    _lastResult = result;
    _isLocating = false;

    if (result.isSuccess && result.position != null) {
      _currentLatitude = result.position!.latitude;
      _currentLongitude = result.position!.longitude;

      if (result.details != null) {
        _currentCity = result.details!.city;
        _currentDistrict = result.details!.district;
        _currentState = result.details!.state;
        _placeName = result.details!.placeName;
      }

      // Synchronize with ApiService global storage
      ApiService.updateGlobalLocation(
        lat: _currentLatitude!,
        lon: _currentLongitude!,
        state: _currentState,
        district: _currentDistrict,
        city: _currentCity,
        placeName: _placeName,
      );
    }

    notifyListeners();
    return result;
  }

  /// Manually update location attributes if needed
  void updateLocation({
    required double latitude,
    required double longitude,
    String? state,
    String? district,
    String? city,
    String? placeName,
  }) {
    _currentLatitude = latitude;
    _currentLongitude = longitude;
    _currentState = state;
    _currentDistrict = district;
    _currentCity = city;
    _placeName = placeName;

    ApiService.updateGlobalLocation(
      lat: latitude,
      lon: longitude,
      state: state,
      district: district,
      city: city,
      placeName: placeName,
    );

    notifyListeners();
  }
}

