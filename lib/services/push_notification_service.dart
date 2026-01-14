import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  static Future<void> sendOrderStatusNotification({
    required String orderId,
    required String userId,
    required String status,
    required String title,
    required String body,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: "us-central1")
          .httpsCallable('sendPushNotification');
      
      await callable.call({
        'userId': userId,
        'title': title,
        'body': body,
        'data': {
          'type': 'order',
          'orderId': orderId,
          'status': status,
        },
      });
      
      debugPrint('✅ Push notification sent for order: $orderId');
    } catch (e) {
      debugPrint('❌ Failed to send push notification: $e');
    }
  }

  static Future<void> sendOrderReceivedNotification({
    required String orderId,
    required String userId,
  }) async {
    await sendOrderStatusNotification(
      orderId: orderId,
      userId: userId,
      status: 'received',
      title: '📥 Order Received!',
      body: 'We received your order #$orderId and will confirm it shortly.',
    );
  }

  static Future<void> sendOrderConfirmationNotification({
    required String orderId,
    required String userId,
  }) async {
    await sendOrderStatusNotification(
      orderId: orderId,
      userId: userId,
      status: 'confirmed',
      title: '🎉 Order Confirmed!',
      body: 'Your order #$orderId has been confirmed and is being prepared.',
    );
  }

  static Future<void> sendOrderReadyNotification({
    required String orderId,
    required String userId,
    required bool isDelivery,
  }) async {
    final title = isDelivery ? '🚚 Order Ready for Delivery!' : '📦 Order Ready for Pickup!';
    final body = isDelivery 
        ? 'Your order #$orderId is on the way!'
        : 'Your order #$orderId is ready for pickup!';
    
    await sendOrderStatusNotification(
      orderId: orderId,
      userId: userId,
      status: isDelivery ? 'on the way' : 'ready for pickup',
      title: title,
      body: body,
    );
  }

  static Future<void> sendOrderCompletedNotification({
    required String orderId,
    required String userId,
    required bool isDelivery,
  }) async {
    final title = isDelivery ? '✅ Order Delivered!' : '✅ Order Completed!';
    final body = isDelivery 
        ? 'Your order #$orderId has been delivered. Enjoy your meal!'
        : 'Thank you for picking up order #$orderId. Enjoy your meal!';
    
    await sendOrderStatusNotification(
      orderId: orderId,
      userId: userId,
      status: isDelivery ? 'delivered' : 'picked up',
      title: title,
      body: body,
    );
  }

  static Future<void> sendReviewPromptNotification({
    required String orderId,
    required String userId,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: "us-central1")
          .httpsCallable('sendPushNotification');
      
      await callable.call({
        'userId': userId,
        'title': '⭐ How was your meal?',
        'body': 'Please rate your experience with order #$orderId',
        'data': {
          'type': 'review',
          'orderId': orderId,
        },
      });
      
      debugPrint('✅ Review prompt sent for order: $orderId');
    } catch (e) {
      debugPrint('❌ Failed to send review prompt: $e');
    }
  }

  static Future<void> testNotification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await sendOrderStatusNotification(
      orderId: 'TEST123',
      userId: user.uid,
      status: 'test',
      title: '🧪 Test Notification',
      body: 'This is a test notification to verify push notifications are working.',
    );
  }
}