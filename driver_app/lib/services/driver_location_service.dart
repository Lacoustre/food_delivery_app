import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class DriverLocationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<Position>? _locationSubscription;
  static bool _isSharing = false;

  // Start sharing location when driver is on delivery
  static Future<void> startLocationSharing() async {
    if (_isSharing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied');
      }

      _isSharing = true;

      // Start location updates
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        _updateDriverLocation(user.uid, position);
      });

    } catch (e) {
      print('Error starting location sharing: $e');
      _isSharing = false;
    }
  }

  // Stop sharing location
  static Future<void> stopLocationSharing() async {
    if (!_isSharing) return;

    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _isSharing = false;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Remove location from Firestore
      await _firestore.collection('driver_locations').doc(user.uid).delete();
    }
  }

  // Update driver location in Firestore
  static Future<void> _updateDriverLocation(String driverId, Position position) async {
    try {
      await _firestore.collection('driver_locations').doc(driverId).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': FieldValue.serverTimestamp(),
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating driver location: $e');
    }
  }

  // Get current location once
  static Future<Position?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // Calculate distance between two points
  static double calculateDistance(
    double startLat, double startLng,
    double endLat, double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  // Get driver location stream for customers
  static Stream<DocumentSnapshot> getDriverLocationStream(String driverId) {
    return _firestore.collection('driver_locations').doc(driverId).snapshots();
  }

  // Check if driver is sharing location
  static bool get isSharing => _isSharing;

  // Update driver status (online/offline/delivering)
  static Future<void> updateDriverStatus(String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('drivers').doc(user.uid).update({
        'status': status,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });

      // Start/stop location sharing based on status
      if (status == 'delivering') {
        await startLocationSharing();
      } else {
        await stopLocationSharing();
      }
    } catch (e) {
      print('Error updating driver status: $e');
    }
  }
}