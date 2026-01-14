import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';

class RatePastOrdersPage extends StatelessWidget {
  const RatePastOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view your orders.")),
      );
    }

    // Top-level orders, owned by the user, completed flow, and not yet rated
    final query = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .where('status', whereIn: ['delivered', 'picked up', 'completed'])
        .where('rated', isEqualTo: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Past Orders'),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text("Error loading orders."));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No completed orders to rate at the moment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Client-side sort by createdAt desc (avoids composite index)
          docs.sort((a, b) {
            final ta =
                (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final tb =
                (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return tb.compareTo(ta);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final d = docs[i];
              final orderId = d.id;
              final orderNumber = d['orderNumber']?.toString() ?? orderId;
              final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
              final items =
                  (d['items'] as List?)?.cast<Map<String, dynamic>>() ??
                  const [];
              final itemsLabel = _itemsLabel(items);
              final total = (d['pricing']?['total'] as num?)?.toDouble();

              return ListTile(
                leading: const Icon(
                  Icons.receipt_long,
                  color: Colors.deepOrange,
                ),
                title: Text('Order #$orderNumber'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (createdAt != null)
                      Text(DateFormat('MMM d, y • h:mm a').format(createdAt)),
                    if (itemsLabel.isNotEmpty) Text(itemsLabel),
                    if (total != null)
                      Text(
                        'Total: ${NumberFormat.simpleCurrency().format(total)}',
                      ),
                  ],
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                  ),
                  onPressed: () => _showRatingDialog(
                    context,
                    orderId,
                    d.data() as Map<String, dynamic>,
                  ),
                  child: const Text('Rate'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _itemsLabel(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return '';
    final names = items
        .map((e) => (e['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    final first = names.take(2).join(', ');
    final more = names.length - 2;
    return more > 0 ? '$first +$more more' : first;
  }

  void _showRatingDialog(
    BuildContext context,
    String orderDocId,
    Map<String, dynamic> order,
  ) {
    double rating = 4.0;
    final controller = TextEditingController();
    bool busy = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Rate Your Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RatingBar.builder(
                initialRating: rating,
                minRating: 1,
                allowHalfRating: true,
                itemCount: 5,
                itemBuilder: (_, __) =>
                    const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (r) => rating = r,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Leave a comment (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
              onPressed: busy
                  ? null
                  : () async {
                      if (rating <= 0) return;
                      setState(() => busy = true);
                      try {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) throw 'Not signed in';

                        // Update order doc (top-level /orders/{orderDocId})
                        await FirebaseFirestore.instance
                            .collection('orders')
                            .doc(orderDocId)
                            .update({
                              'rated': true,
                              'rating': rating,
                              'review': controller.text.trim(),
                              'ratedAt': FieldValue.serverTimestamp(),
                            });

                        // Save to global reviews
                        final items =
                            (order['items'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            const [];
                        await FirebaseFirestore.instance
                            .collection('reviews')
                            .add({
                              'userId': uid,
                              'orderId': orderDocId,
                              'orderNumber': order['orderNumber'],
                              'items': items
                                  .map(
                                    (e) => {
                                      'name': e['name'],
                                      'id': e['id'],
                                      'price': e['price'],
                                    },
                                  )
                                  .toList(),
                              'rating': rating,
                              'review': controller.text.trim(),
                              'timestamp': FieldValue.serverTimestamp(),
                            });

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thanks for your feedback!'),
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() => busy = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
