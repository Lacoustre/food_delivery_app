import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NavigationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check location permissions
  static Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  // Get current location
  static Future<Position?> getCurrentLocation() async {
    try {
      if (!await checkLocationPermission()) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  // Open navigation in external app with coordinates or address
  static Future<void> openNavigation(String address, {double? latitude, double? longitude}) async {
    String navigationUrl;
    
    // If coordinates are provided, use them for more accurate navigation
    if (latitude != null && longitude != null) {
      navigationUrl = 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving';
    } else {
      // Fallback to address-based navigation
      final encodedAddress = Uri.encodeComponent(address);
      navigationUrl = 'https://www.google.com/maps/dir/?api=1&destination=$encodedAddress&travelmode=driving';
    }

    try {
      if (await canLaunchUrl(Uri.parse(navigationUrl))) {
        await launchUrl(Uri.parse(navigationUrl), mode: LaunchMode.externalApplication);
      } else {
        // Fallback to Apple Maps if Google Maps fails
        final appleMapsUrl = latitude != null && longitude != null
            ? 'https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d'
            : 'https://maps.apple.com/?daddr=${Uri.encodeComponent(address)}&dirflg=d';
        
        if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
          await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
        } else {
          throw Exception('No navigation app available');
        }
      }
    } catch (e) {
      throw Exception('Failed to open navigation: $e');
    }
  }

  // Update driver location (for admin tracking)
  static Future<void> updateDriverLocation(Position position) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('drivers').doc(user.uid).update({
        'currentLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail
    }
  }

  // Format address for display
  static String formatAddress(Map<String, dynamic>? address) {
    if (address == null) return 'Address not available';
    
    final parts = <String>[];
    if (address['street'] != null) parts.add(address['street']);
    if (address['city'] != null) parts.add(address['city']);
    if (address['state'] != null) parts.add(address['state']);
    if (address['zipCode'] != null) parts.add(address['zipCode']);
    
    return parts.join(', ');
  }
}