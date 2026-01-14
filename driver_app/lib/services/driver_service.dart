import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'storage_service.dart';

class DriverService {
  static FirebaseFirestore get _firestore {
    _ensureFirebaseInitialized();
    return FirebaseFirestore.instance;
  }
  
  static FirebaseAuth get _auth {
    _ensureFirebaseInitialized();
    return FirebaseAuth.instance;
  }

  static void _ensureFirebaseInitialized() {
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase not initialized. Call Firebase.initializeApp() first.');
    }
  }

  static String? get currentDriverId => _auth.currentUser?.uid;

  static Stream<DocumentSnapshot> getDriverProfile() {
    if (currentDriverId == null) throw Exception('No authenticated driver');
    return _firestore.collection('drivers').doc(currentDriverId).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data();
        final approvalStatus = data?['approvalStatus'] as String?;
        if (approvalStatus != null) {
          StorageService.setDriverApprovalStatus(approvalStatus);
        }
      }
      return doc;
    });
  }

  static Future<bool> isDriverApproved() async {
    // Check local cache first
    if (StorageService.isDriverApproved()) return true;
    
    // If not cached, check Firestore
    if (currentDriverId == null) return false;
    try {
      final doc = await _firestore.collection('drivers').doc(currentDriverId).get();
      if (doc.exists) {
        final data = doc.data();
        final approvalStatus = data?['approvalStatus'] as String? ?? 'pending';
        await StorageService.setDriverApprovalStatus(approvalStatus);
        return approvalStatus == 'approved';
      }
    } catch (e) {
      // If error, use cached value
      return StorageService.isDriverApproved();
    }
    return false;
  }

  static Future<void> updateDriverProfile(Map<String, dynamic> data) async {
    if (currentDriverId == null) throw Exception('No authenticated driver');
    
    // Add FCM token if not already included
    if (!data.containsKey('fcmToken')) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          data['fcmToken'] = token;
        }
      } catch (e) {
        // Continue without FCM token if there's an error
      }
    }
    
    await _firestore.collection('drivers').doc(currentDriverId).update(data);
  }

  static Future<void> saveFCMToken() async {
    if (currentDriverId == null) return;
    
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection('drivers').doc(currentDriverId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Silently handle FCM token errors
    }
  }

  static Future<void> updateDriverStatus(String status) async {
    if (currentDriverId == null) throw Exception('No authenticated driver');
    await _firestore.collection('drivers').doc(currentDriverId).update({
      'status': status,
      'lastStatusUpdate': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateDriverLocation(double latitude, double longitude) async {
    if (currentDriverId == null) throw Exception('No authenticated driver');
    await _firestore.collection('drivers').doc(currentDriverId).update({
      'location': GeoPoint(latitude, longitude),
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    });
  }
}