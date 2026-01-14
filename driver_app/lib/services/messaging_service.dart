import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send message
  static Future<void> sendMessage({
    required String orderId,
    required String message,
    required String receiverId,
    required String receiverType, // 'customer' or 'driver'
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final messageData = {
      'orderId': orderId,
      'senderId': user.uid,
      'senderType': 'driver',
      'receiverId': receiverId,
      'receiverType': receiverType,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    await _firestore
        .collection('messages')
        .add(messageData);

    // Update order with last message info
    await _firestore
        .collection('orders')
        .doc(orderId)
        .update({
      'lastMessage': message,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': 'driver',
    });
  }

  // Get messages for an order
  static Stream<QuerySnapshot> getOrderMessages(String orderId) {
    return _firestore
        .collection('messages')
        .where('orderId', isEqualTo: orderId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Mark messages as read
  static Future<void> markMessagesAsRead(String orderId, String userId) async {
    final messages = await _firestore
        .collection('messages')
        .where('orderId', isEqualTo: orderId)
        .where('receiverId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // Get unread message count for driver
  static Stream<int> getUnreadMessageCount(String driverId) {
    return _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: driverId)
        .where('receiverType', isEqualTo: 'driver')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}