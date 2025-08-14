import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class BackgroundLocationService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.busnap/location_service',
  );

  static StreamSubscription<Position>? _locationSubscription;
  static bool _isTracking = false;
  static Function(LatLng)? _onLocationUpdate;
  static Function(double)? _onDistanceUpdate;

  static LatLng? _destinationLatLng;
  static final Set<int> _alertedThresholds = {};

  /// Initialize the background location service
  static Future<void> initialize() async {
    // Simple initialization without WorkManager
    debugPrint('BackgroundLocationService initialized');
  }

  /// Start background location tracking
  static Future<bool> startBackgroundTracking({
    required LatLng destination,
    required Function(LatLng) onLocationUpdate,
    required Function(double) onDistanceUpdate,
  }) async {
    try {
      // Check permissions
      final locationPermission = await Permission.location.status;
      final backgroundPermission = await Permission.locationAlways.status;

      if (!locationPermission.isGranted) {
        final result = await Permission.location.request();
        if (!result.isGranted) return false;
      }

      if (!backgroundPermission.isGranted) {
        final result = await Permission.locationAlways.request();
        if (!result.isGranted) return false;
      }

      // Store callback functions
      _onLocationUpdate = onLocationUpdate;
      _onDistanceUpdate = onDistanceUpdate;
      _destinationLatLng = destination;
      _alertedThresholds.clear();

      // Start native Android service
      await _channel.invokeMethod('startBackgroundTracking');

      // Start Flutter location stream as backup
      await _startLocationStream();

      _isTracking = true;
      return true;
    } catch (e) {
      debugPrint('Error starting background tracking: $e');
      return false;
    }
  }

  /// Stop background location tracking
  static Future<void> stopBackgroundTracking() async {
    try {
      await _channel.invokeMethod('stopBackgroundTracking');
      await _stopLocationStream();
      _isTracking = false;
      _onLocationUpdate = null;
      _onDistanceUpdate = null;
    } catch (e) {
      debugPrint('Error stopping background tracking: $e');
    }
  }

  /// Start location stream for continuous updates
  static Future<void> _startLocationStream() async {
    _locationSubscription?.cancel();

    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // 10 meters
            timeLimit: Duration(seconds: 30),
          ),
        ).listen(
          (Position position) {
            if (!_isTracking) return;

            final latLng = LatLng(position.latitude, position.longitude);
            _onLocationUpdate?.call(latLng);

            // Calculate distance to destination
            if (_destinationLatLng != null) {
              _calculateDistanceToDestination(latLng);
            }
          },
          onError: (error) {
            debugPrint('Location stream error: $error');
          },
        );
  }

  /// Stop location stream
  static Future<void> _stopLocationStream() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  /// Calculate distance to destination and check thresholds
  static void _calculateDistanceToDestination(LatLng currentLocation) {
    if (_destinationLatLng == null) return;

    final distance =
        Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          _destinationLatLng!.latitude,
          _destinationLatLng!.longitude,
        ) /
        1000; // Convert to kilometers

    _onDistanceUpdate?.call(distance);

    // Check alert thresholds (5km, 2km, 1km)
    for (final threshold in [5, 2, 1]) {
      if (distance <= threshold && !_alertedThresholds.contains(threshold)) {
        _alertedThresholds.add(threshold);
        _triggerAlert(threshold, distance);
      }
    }
  }

  /// Trigger alert for distance threshold
  static void _triggerAlert(int threshold, double currentDistance) {
    // This will be handled by the main app through the callback
    debugPrint(
      'Alert triggered: $threshold km threshold reached. Current distance: ${currentDistance.toStringAsFixed(2)} km',
    );
  }

  /// Check if tracking is active
  static bool get isTracking => _isTracking;

  /// Get current alerted thresholds
  static Set<int> get alertedThresholds => Set.from(_alertedThresholds);
}
