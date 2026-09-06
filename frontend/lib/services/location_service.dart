import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

enum LocationStatus {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  success,
  error,
}

class LocationResult {
  final LocationStatus status;
  final Position? position;
  final String? errorMessage;

  LocationResult({
    required this.status,
    this.position,
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

  /// Gets real-time GPS location with full permission & service handling
  static Future<LocationResult> getLivePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          status: LocationStatus.serviceDisabled,
          errorMessage: 'Location Services (GPS) are turned off. Please enable GPS to get live weather & crop advice.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            status: LocationStatus.permissionDenied,
            errorMessage: 'Location permission was denied. Live GPS is needed for accurate weather & crop advice.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          status: LocationStatus.permissionDeniedForever,
          errorMessage: 'Location permissions are permanently denied. Please enable them in App Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return LocationResult(
        status: LocationStatus.success,
        position: position,
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

  /// Reverse geocode latitude & longitude to local City/District & State dynamically
  static Future<String?> getPlaceName(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = (p.locality != null && p.locality!.isNotEmpty)
            ? p.locality
            : (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty)
                ? p.subAdministrativeArea
                : (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
                    ? p.administrativeArea
                    : null;
        final state = p.administrativeArea;
        if (city != null && state != null && city != state) {
          return '$city, $state';
        } else if (city != null) {
          return city;
        } else if (state != null) {
          return state;
        }
      }
    } catch (_) {}
    return null;
  }
}

