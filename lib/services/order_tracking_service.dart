import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderTrackingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get real-time order updates for customer
  static Stream<DocumentSnapshot> trackOrder(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots();
  }

  // Get customer's active orders
  static Stream<QuerySnapshot> getActiveOrders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .where('deliveryStatus', whereIn: ['pending', 'confirmed', 'preparing', 'ready for pickup', 'on the way'])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get order history for customer
  static Stream<QuerySnapshot> getOrderHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .where('deliveryStatus', whereIn: ['delivered', 'picked up', 'completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  // Get driver location if available
  static Stream<DocumentSnapshot?> getDriverLocation(String driverId) {
    if (driverId.isEmpty) return Stream.value(null);
    
    return _firestore
        .collection('driver_locations')
        .doc(driverId)
        .snapshots();
  }

  // Update customer location for delivery
  static Future<void> updateCustomerLocation(String orderId, double lat, double lng) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'customerLocation': {
          'latitude': lat,
          'longitude': lng,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      });
    } catch (e) {
      print('Error updating customer location: $e');
    }
  }

  // Send message to driver
  static Future<void> sendMessageToDriver(String orderId, String driverId, String message) async {
    try {
      await _firestore.collection('order_messages').add({
        'orderId': orderId,
        'driverId': driverId,
        'senderId': FirebaseAuth.instance.currentUser?.uid,
        'senderType': 'customer',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  // Get order messages
  static Stream<QuerySnapshot> getOrderMessages(String orderId) {
    return _firestore
        .collection('order_messages')
        .where('orderId', isEqualTo: orderId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Mark messages as read
  static Future<void> markMessagesAsRead(String orderId, String userId) async {
    try {
      final messages = await _firestore
          .collection('order_messages')
          .where('orderId', isEqualTo: orderId)
          .where('senderId', isNotEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
}