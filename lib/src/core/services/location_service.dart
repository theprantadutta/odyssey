import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Result class for location operations
class LocationResult {
  final double? latitude;
  final double? longitude;
  final LocationError? error;

  const LocationResult({
    this.latitude,
    this.longitude,
    this.error,
  });

  const LocationResult.success({
    required double latitude,
    required double longitude,
  })  : latitude = latitude,
        longitude = longitude,
        error = null;

  const LocationResult.failure(LocationError error)
      : latitude = null,
        longitude = null,
        error = error;

  bool get isSuccess => latitude != null && longitude != null && error == null;
}

/// Possible location errors
enum LocationError {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

/// Extension to get user-friendly error messages
extension LocationErrorMessage on LocationError {
  String get message {
    switch (this) {
      case LocationError.serviceDisabled:
        return 'Please enable Location Services in your device settings';
      case LocationError.permissionDenied:
        return 'Location permission is required to get GPS coordinates';
      case LocationError.permissionDeniedForever:
        return 'Location permission was denied. Please enable it in Settings.';
      case LocationError.timeout:
        return 'Could not get location. Please try again or enter manually.';
      case LocationError.unknown:
        return 'Something went wrong. Please try again.';
    }
  }

  bool get canOpenSettings {
    return this == LocationError.serviceDisabled ||
        this == LocationError.permissionDeniedForever;
  }
}

/// Singleton service for GPS location functionality
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Check if location services are enabled on the device
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Open device location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings (for permission denied forever)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Get current position with full permission handling
  /// This is the main method to use from UI
  Future<LocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 15),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      // 1. Check if location services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult.failure(LocationError.serviceDisabled);
      }

      // 2. Check current permission
      LocationPermission permission = await checkPermission();

      // 3. Request permission if denied
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult.failure(LocationError.permissionDenied);
        }
      }

      // 4. Handle permanently denied
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(
            LocationError.permissionDeniedForever);
      }

      // 5. Get position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );

      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on LocationServiceDisabledException {
      return const LocationResult.failure(LocationError.serviceDisabled);
    } on PermissionDeniedException {
      return const LocationResult.failure(LocationError.permissionDenied);
    } on TimeoutException {
      return const LocationResult.failure(LocationError.timeout);
    } catch (e) {
      return const LocationResult.failure(LocationError.unknown);
    }
  }
}
