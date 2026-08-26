import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter/material.dart';
import 'package:african_cuisine/support/rate_orders_page.dart';

class ReviewNotificationService {

  // Check for orders that need review notifications
  static Future<void> checkForReviewNotifications(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Get delivered orders from last 7 days that haven't been reviewed
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));

      final orders = await Supabase.instance.client
          .from('orders')
          .select('id, updated_at')
          .eq('user_id', user.id)
          .eq('status', 'delivered');

      final unratedOrders = <Map<String, dynamic>>[];

      for (final order in orders) {
        // No separate "delivered at" timestamp column — updated_at is the
        // closest equivalent (it's bumped whenever status changes).
        final deliveredTime = order['updated_at'] != null
            ? DateTime.parse(order['updated_at'] as String)
            : null;

        if (deliveredTime == null ||
            deliveredTime.isBefore(sevenDaysAgo) ||
            deliveredTime.isAfter(oneDayAgo)) {
          continue;
        }

        final review = await Supabase.instance.client
            .from('order_reviews')
            .select('id')
            .eq('order_id', order['id'])
            .eq('user_id', user.id)
            .maybeSingle();

        if (review == null) {
          unratedOrders.add(order);
        }
      }

      if (unratedOrders.isNotEmpty && context.mounted) {
        _showReviewPrompt(context, unratedOrders.length);
      }
    } catch (e) {
      debugPrint('Error checking review notifications: $e');
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

  // Create in-app notification for review reminder (Supabase
  // user_notifications — the same table the notification page streams)
  static Future<void> createReviewReminder(
    String orderId,
    String userId,
  ) async {
    try {
      await Supabase.instance.client.from('user_notifications').insert({
        'user_id': userId,
        'type': 'review_reminder',
        'title': 'Rate Your Recent Order',
        'body':
            'How was your experience? Share your feedback to help us improve!',
        'read': false,
      });
    } catch (e) {
      debugPrint('Error creating review reminder: $e');
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
