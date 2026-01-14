import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:african_cuisine/services/email_service.dart';
import 'package:african_cuisine/services/push_notification_service.dart';
import 'package:african_cuisine/services/review_notification_service.dart';

class OrderStatusService {
  static final OrderStatusService _instance = OrderStatusService._internal();
  factory OrderStatusService() => _instance;
  OrderStatusService._internal();

  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  final Set<String> _processedOrders = {};

  void startListening() {
    // Listen to auth state changes and restart listener accordingly
    FirebaseAuth.instance.authStateChanges().listen((user) {
      stopListening(); // Stop any existing listener
      
      if (user == null) return;
      
      try {
        _ordersSubscription = FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user.uid)
            .snapshots()
            .listen(
              _handleOrderStatusChange,
              onError: (error) {
                debugPrint('Order status listener error: $error');
              },
            );
      } catch (e) {
        debugPrint('Failed to start order status listener: $e');
      }
    });
  }

  void stopListening() {
    _ordersSubscription?.cancel();
    _processedOrders.clear();
  }

  void _handleOrderStatusChange(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.modified || 
          change.type == DocumentChangeType.added) {
        final orderData = change.doc.data() as Map<String, dynamic>;
        final orderId = orderData['orderNumber'] as String;
        final status = (orderData['status'] ?? orderData['deliveryStatus'] ?? '').toString().toLowerCase();
        final userId = orderData['userId'] as String;
        
        // Create unique key for order+status to avoid duplicate notifications
        final notificationKey = '${orderId}_$status';
        
        // Only process each order status change once
        if (!_processedOrders.contains(notificationKey)) {
          _processedOrders.add(notificationKey);
          _sendStatusNotification(orderData, status, userId, orderId);
        }
      }
    }
  }

  void _sendStatusNotification(Map<String, dynamic> orderData, String status, String userId, String orderId) {
    try {
      final isDelivery = (orderData['deliveryMethod'] ?? orderData['orderType'] ?? '').toString().toLowerCase() == 'delivery';
      
      switch (status) {
        case 'confirmed':
          PushNotificationService.sendOrderConfirmationNotification(
            orderId: orderId,
            userId: userId,
          );
          break;
        case 'on the way':
        case 'out for delivery':
          PushNotificationService.sendOrderReadyNotification(
            orderId: orderId,
            userId: userId,
            isDelivery: true,
          );
          break;
        case 'ready for pickup':
          PushNotificationService.sendOrderReadyNotification(
            orderId: orderId,
            userId: userId,
            isDelivery: false,
          );
          break;
        case 'delivered':
        case 'picked up':
        case 'completed':
          _sendCompletionNotifications(orderData, status, userId, orderId, isDelivery);
          break;
        case 'cancelled':
          PushNotificationService.sendOrderStatusNotification(
            orderId: orderId,
            userId: userId,
            status: 'cancelled',
            title: '❌ Order Cancelled',
            body: 'Your order #$orderId has been cancelled.',
          );
          break;
      }
    } catch (e) {
      debugPrint('Error sending status notification: $e');
    }
  }
  void _sendCompletionNotifications(Map<String, dynamic> orderData, String status, String userId, String orderId, bool isDelivery) {
    try {
      final customerEmail = orderData['payment']?['customerEmail'] ?? 
                           orderData['customerEmail'] ?? '';
      final customerName = orderData['payment']?['customerName'] ?? 
                          orderData['customerName'] ?? 'Customer';

      // Send email notification
      if (customerEmail.isNotEmpty) {
        EmailService.sendOrderCompletionEmail(
          orderId: orderId,
          customerEmail: customerEmail,
          customerName: customerName,
          status: status,
        );
      }
      
      // Send push notification
      PushNotificationService.sendOrderCompletedNotification(
        orderId: orderId,
        userId: userId,
        isDelivery: isDelivery,
      );
      
      // Schedule review reminder
      ReviewNotificationService.scheduleReviewReminder(orderId, userId);
    } catch (e) {
      debugPrint('Error sending completion notifications: $e');
    }
  }
  
  void _scheduleReviewPrompt(Map<String, dynamic> orderData) {
    Timer(const Duration(minutes: 30), () {
      _sendReviewPromptNotification(orderData);
    });
  }
  
  void _sendReviewPromptNotification(Map<String, dynamic> orderData) {
    try {
      final orderId = orderData['orderNumber'] as String;
      final userId = orderData['userId'] as String;
      
      PushNotificationService.sendReviewPromptNotification(
        orderId: orderId,
        userId: userId,
      );
    } catch (e) {
      debugPrint('Error sending review prompt: $e');
    }
  }
}