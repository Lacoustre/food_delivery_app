import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:african_cuisine/support/rate_orders_page.dart';

class ReviewNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check for orders that need review notifications
  static Future<void> checkForReviewNotifications(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get delivered orders from last 7 days that haven't been reviewed
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));

      final ordersQuery = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'delivered')
          .get();

      final unratedOrders = <QueryDocumentSnapshot>[];

      for (final orderDoc in ordersQuery.docs) {
        final data = orderDoc.data() as Map<String, dynamic>;
        final deliveredTime = (data['deliveredTime'] as Timestamp?)?.toDate();
        
        // Skip if no delivery time or outside our date range
        if (deliveredTime == null || 
            deliveredTime.isBefore(sevenDaysAgo) || 
            deliveredTime.isAfter(oneDayAgo)) continue;
        
        // Check if this order has been reviewed
        final reviewQuery = await _firestore
            .collection('order_reviews')
            .where('orderId', isEqualTo: orderDoc.id)
            .where('userId', isEqualTo: user.uid)
            .get();

        if (reviewQuery.docs.isEmpty) {
          unratedOrders.add(orderDoc);
        }
      }

      if (unratedOrders.isNotEmpty && context.mounted) {
        _showReviewPrompt(context, unratedOrders.length);
      }
    } catch (e) {
      print('Error checking review notifications: $e');
    }
  }

  static void _showReviewPrompt(BuildContext context, int orderCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.star_rate, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('Rate Your Experience'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have $orderCount recent order${orderCount > 1 ? 's' : ''} waiting for your review!',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your feedback helps us improve and helps other customers make better choices.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RatePastOrdersPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  // Create in-app notification for review reminder
  static Future<void> createReviewReminder(
    String orderId,
    String userId,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'type': 'review_reminder',
            'title': 'Rate Your Recent Order',
            'message':
                'How was your experience? Share your feedback to help us improve!',
            'orderId': orderId,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
            'actionType': 'rate_order',
          });
    } catch (e) {
      print('Error creating review reminder: $e');
    }
  }

  // Schedule review reminders for delivered orders
  static Future<void> scheduleReviewReminder(
    String orderId,
    String userId,
  ) async {
    // This would typically be handled by a cloud function
    // For now, we'll create the reminder immediately
    await Future.delayed(const Duration(seconds: 2));
    await createReviewReminder(orderId, userId);
  }
}
