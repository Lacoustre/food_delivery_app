import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class OrderTrackingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get real-time order updates for customer
  static Stream<List<Map<String, dynamic>>> trackOrder(String orderId) {
    return Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId);
  }

  // Get customer's active orders
  static Stream<List<Map<String, dynamic>>> getActiveOrders() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const Stream.empty();

    return Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at')
        .map((rows) => rows
            .where((row) => [
                  'pending',
                  'confirmed',
                  'preparing',
                  'ready for pickup',
                  'on the way',
                ].contains(row['status']))
            .toList());
  }

  // Get order history for customer
  static Stream<List<Map<String, dynamic>>> getOrderHistory() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const Stream.empty();

    return Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at')
        .map((rows) => rows
            .where((row) => [
                  'delivered',
                  'picked up',
                  'completed',
                  'cancelled',
                ].contains(row['status']))
            .take(20)
            .toList());
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