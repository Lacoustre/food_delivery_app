import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class EmailService {
  static Future<void> sendOrderConfirmationEmail({
    required String orderId,
    required String customerEmail,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double total,
    required String deliveryMethod,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: "us-central1")
          .httpsCallable('sendOrderConfirmationEmail');
      
      await callable.call({
        'orderId': orderId,
        'customerEmail': customerEmail,
        'customerName': customerName,
        'items': items,
        'total': total,
        'deliveryMethod': deliveryMethod,
      });
      
      debugPrint('✅ Order confirmation email sent for order: $orderId');
    } catch (e) {
      debugPrint('❌ Failed to send order confirmation email: $e');
    }
  }

  static Future<void> sendOrderCompletionEmail({
    required String orderId,
    required String customerEmail,
    required String customerName,
    required String status, // 'delivered' or 'picked up'
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: "us-central1")
          .httpsCallable('sendOrderCompletionEmail');
      
      await callable.call({
        'orderId': orderId,
        'customerEmail': customerEmail,
        'customerName': customerName,
        'status': status,
      });
      
      debugPrint('✅ Order completion email sent for order: $orderId');
    } catch (e) {
      debugPrint('❌ Failed to send order completion email: $e');
    }
  }
}