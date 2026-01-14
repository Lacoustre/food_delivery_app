import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationHandler {
  static Future<void> handleNewOrderAssignment(String orderId) async {
    // Subscribe to order updates
    await NotificationService.subscribeToOrderUpdates(orderId);
    
    // Show in-app notification if app is active
    // This would be called from your notification service when a new assignment arrives
  }
  
  static Future<void> handleOrderComplete(String orderId) async {
    // Unsubscribe from order updates
    await NotificationService.unsubscribeFromOrderUpdates(orderId);
  }
  
  static void showInAppNotification(BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to notifications screen
          },
        ),
      ),
    );
  }
}