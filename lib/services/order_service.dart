import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Cancel an order securely through Cloud Functions
  static Future<void> cancelOrder(String orderId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final callable = _functions.httpsCallable('cancelOrder');
      await callable.call({
        'orderId': orderId,
        'userId': user.uid,
        'reason': 'User requested cancellation',
      });

      debugPrint('✅ Order cancelled successfully via Cloud Function');
    } catch (e) {
      debugPrint('❌ Failed to cancel order: $e');
      rethrow;
    }
  }
}