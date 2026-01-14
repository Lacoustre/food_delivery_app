import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentDriverId => _auth.currentUser?.uid;

  static Stream<QuerySnapshot> getAvailableOrders() {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'confirmed')
        .where('driverId', isEqualTo: null)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getDriverOrders() {
    if (currentDriverId == null) throw Exception('No authenticated driver');
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: currentDriverId)
        .where('status', whereIn: ['assigned', 'picked_up', 'delivering'])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> acceptOrder(String orderId) async {
    if (currentDriverId == null) throw Exception('No authenticated driver');
    await _firestore.collection('orders').doc(orderId).update({
      'driverId': currentDriverId,
      'status': 'assigned',
      'assignedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateOrderStatus(String orderId, String status) async {
    if (currentDriverId == null) throw Exception('No authenticated driver');
    await _firestore.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markOrderPickedUp(String orderId) async {
    await updateOrderStatus(orderId, 'picked_up');
  }

  static Future<void> markOrderDelivered(String orderId) async {
    await updateOrderStatus(orderId, 'delivered');
  }
}