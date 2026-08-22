import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:african_cuisine/support/rate_orders_page.dart';

/// Shows while an unread review_reminder row exists in the Supabase
/// user_notifications table (streamed live, filtered client-side — the
/// realtime stream builder supports one filter).
class ReviewReminderBanner extends StatelessWidget {
  const ReviewReminderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('user_notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id),
      builder: (context, snapshot) {
        final reminders = (snapshot.data ?? [])
            .where((r) =>
                r['type'] == 'review_reminder' && r['read'] != true)
            .toList();
        if (reminders.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade100, Colors.orange.shade50],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.star_rate,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rate Your Experience',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share your feedback on recent orders',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RatePastOrdersPage(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Rate Now'),
              ),
              IconButton(
                onPressed: () =>
                    _dismissNotification(reminders.first['id'] as String),
                icon: const Icon(Icons.close, size: 20),
                color: Colors.grey[600],
              ),
            ],
          ),
        );
      },
    );
  }

  void _dismissNotification(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('user_notifications')
          .update({'read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Error dismissing notification: $e');
    }
  }
}
