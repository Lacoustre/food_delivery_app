import 'dart:async';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';

/// Cross-platform location utilities with safe permission handling and
/// production-ready defaults.
class LocationService {
  /// Checks that the device’s location service is ON and permission is granted.
  /// If [requestIfDenied] is true, will prompt the user when possible.
  static Future<bool> checkPermissions({bool requestIfDenied = true}) async {
    // 1) Ensure service is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // 2) Check/request permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied && requestIfDenied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Opens the OS location settings screen for the user.
  /// Returns true if the settings page could be opened.
  static Future<bool> openLocationSettings() =>
      Geolocator.openLocationSettings();

  /// Opens the app settings so the user can manually grant permission if it’s
  /// permanently denied. Returns true if the settings page could be opened.
  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Gets the current position with a sane timeout and a fallback to the last
  /// known position if the fresh lookup fails.
  ///
  /// Returns `null` if service is off, permissions are missing, or nothing can be
  /// obtained (even last known).
  static Future<Position?> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 12),
    bool useLastKnownOnTimeout = true,
    bool requestIfDenied = true,
  }) async {
    if (!await checkPermissions(requestIfDenied: requestIfDenied)) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout,
      );
    } on TimeoutException catch (_) {
      if (useLastKnownOnTimeout) {
        return Geolocator.getLastKnownPosition();
      }
      return null;
    } on LocationServiceDisabledException {
      // Service switched off during the call.
      return null;
    } catch (_) {
      // Any other platform/geolocator exception → graceful fallback
      return useLastKnownOnTimeout ? Geolocator.getLastKnownPosition() : null;
    }
  }

  /// Subscribes to continuous location updates.
  ///
  /// - [accuracy]: desired accuracy for updates.
  /// - [distanceFilter]: minimum distance (meters) between updates.
  /// - [interval]: (Android only) minimum time between updates.
  /// - [useForegroundServiceOnAndroid]: if true, shows a persistent
  ///   notification so updates continue reliably in the background.
  ///
  /// NOTE: You still need to ensure permissions/service via [checkPermissions]
  /// before listening to this stream.
  static Stream<Position> getLocationStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
    Duration? interval,
    bool useForegroundServiceOnAndroid = false,
  }) {
    // Choose platform-specific settings for best control.
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: interval,
        // Foreground service keeps tracking alive in background if enabled.
        foregroundNotificationConfig: useForegroundServiceOnAndroid
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Location active',
                notificationText: 'Tracking your location for deliveries',
                enableWakeLock: true,
              )
            : null,
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        // Set to true if you want updates when the app is in the background
        // AND you’ve added the proper background modes in Xcode.
        showBackgroundLocationIndicator: false,
        pauseLocationUpdatesAutomatically: true,
      );
    } else {
      // Fallback for other platforms
      settings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );
    }

    return Geolocator.getPositionStream(locationSettings: settings);
  }

  /// Returns the straight-line distance in **meters** between two lat/lng pairs.
  static double calculateDistanceMeters(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Returns the straight-line distance in **kilometers** between two points.
  static double calculateDistanceKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return calculateDistanceMeters(startLat, startLng, endLat, endLng) / 1000.0;
  }

  /// Convenience: quick “am I allowed and ready?” check that differentiates
  /// common failure reasons.
  static Future<LocationReadiness> readiness() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationReadiness.serviceDisabled;
    }

    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.denied:
        return LocationReadiness.permissionDenied;
      case LocationPermission.deniedForever:
        return LocationReadiness.permissionPermanentlyDenied;
      default:
        return LocationReadiness.ok;
    }
  }
}

/// High-level readiness outcomes for UX decisions (show prompts, etc).
enum LocationReadiness {
  ok,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
}
