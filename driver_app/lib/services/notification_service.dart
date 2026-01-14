import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'push_notification_service.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentDriverId => _auth.currentUser?.uid;

  // Get driver notifications stream
  static Stream<QuerySnapshot> getDriverNotifications() {
    if (currentDriverId == null) {
      return Stream.empty();
    }
    return _firestore
        .collection('drivers')
        .doc(currentDriverId!)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .handleError((error) {
      print('Error getting driver notifications: $error');
      return <QuerySnapshot>[];
    });
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    if (currentDriverId == null) return;
    try {
      await _firestore
          .collection('drivers')
          .doc(currentDriverId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Create local notification (for internal use)
  static Future<void> createNotification({
    required String title,
    required String message,
    String? orderId,
  }) async {
    if (currentDriverId == null) return;
    try {
      await _firestore
          .collection('drivers')
          .doc(currentDriverId)
          .collection('notifications')
          .add({
        'title': title,
        'body': message,
        'data': orderId != null ? {'orderId': orderId} : {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Get unread notification count
  static Stream<int> getUnreadNotificationCount() {
    return PushNotificationService.getUnreadNotificationCount();
  }

  // Clear all notifications
  static Future<void> clearAllNotifications() async {
    await PushNotificationService.clearAllNotifications();
  }

  // Subscribe to order notifications
  static Future<void> subscribeToOrderUpdates(String orderId) async {
    await PushNotificationService.subscribeToOrderUpdates(orderId);
  }

  // Unsubscribe from order notifications
  static Future<void> unsubscribeFromOrderUpdates(String orderId) async {
    await PushNotificationService.unsubscribeFromOrderUpdates(orderId);
  }
}