import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:african_cuisine/orders/order_detail_page.dart';
import 'package:african_cuisine/services/order_adapter.dart';

class NotificationDetailPage extends StatelessWidget {
  final String title;
  final String body;
  final DateTime? timestamp;
  final String type;
  final String? orderId;

  const NotificationDetailPage({
    super.key,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = timestamp != null
        ? DateFormat('MMM d, yyyy h:mm a').format(timestamp!)
        : "Unknown time";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notification Detail"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(type.toUpperCase()),
                  backgroundColor: _getTypeColor(type),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(formattedDate, style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const Divider(height: 30),
            Text(body, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            if (orderId != null)
              ElevatedButton.icon(
                onPressed: () => _handleViewOrder(context),
                icon: const Icon(Icons.receipt),
                label: const Text("View Order"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                ),
              )
            else
              const Text(
                'No associated order for this notification.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleViewOrder(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Loading order..."),
          ],
        ),
      ),
    );

    try {
      final row = await Supabase.instance.client
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', orderId as String)
          .maybeSingle();

      Navigator.pop(context);

      if (row == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Order not found')));
        return;
      }

      final orderData = orderRowToLegacyMap(row);
      final status = orderData['status']?.toString().toLowerCase();

      // Navigate to order detail
      // (Make sure OrderDetailPage just needs the map)
      // ignore: use_build_context_synchronously
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(orderData: orderData),
        ),
      );

      // If delivered, show rating dialog
      if (status == 'delivered') {
        Future.delayed(const Duration(milliseconds: 500), () {
          _showRatingDialog(context, orderId!);
        });
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('⚠️ Failed to fetch order: $e')));
    }
  }

  void _showRatingDialog(BuildContext context, String orderId) {
    double rating = 0;
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Rate Your Order"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              allowHalfRating: true,
              direction: Axis.horizontal,
              itemCount: 5,
              itemSize: 30,
              itemBuilder: (_, __) =>
                  const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (newRating) => rating = newRating,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Leave a comment...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please log in to submit a review."),
                  ),
                );
                return;
              }

              // Same order_reviews table order_detail_page.dart uses —
              // this used to write to a separate orders/{id}/reviews
              // subcollection, a pre-existing duplicate storage path.
              try {
                await Supabase.instance.client.from('order_reviews').upsert({
                  'order_id': orderId,
                  'rating': rating,
                  'comment': controller.text,
                  'user_id': user.id,
                }, onConflict: 'order_id,user_id');

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Thanks for your feedback!")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to submit review: $e")),
                );
              }
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return Colors.green;
      case 'promo':
        return Colors.orange;
      case 'system':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
