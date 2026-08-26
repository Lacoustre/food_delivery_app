import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';

class RatePastOrdersPage extends StatefulWidget {
  const RatePastOrdersPage({super.key});

  @override
  State<RatePastOrdersPage> createState() => _RatePastOrdersPageState();
}

class _RatePastOrdersPageState extends State<RatePastOrdersPage> {
  List<Map<String, dynamic>>? _orders;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUnratedOrders();
  }

  Future<void> _fetchUnratedOrders() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // "Rated" isn't a column here — an order counts as rated if it has a
      // matching order_reviews row (same convention as review_notification_
      // service.dart and order_detail_page.dart use), so embed and filter
      // client-side rather than relying on a boolean flag.
      final rows = await Supabase.instance.client
          .from('orders')
          .select('*, order_items(*), order_reviews(id)')
          .eq('user_id', user.id)
          .inFilter('status', ['delivered', 'picked up', 'completed'])
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _orders = rows
            .where((row) => (row['order_reviews'] as List).isEmpty)
            .toList();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view your orders.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Past Orders'),
        backgroundColor: Colors.deepOrange,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return const Center(child: Text("Error loading orders."));
    }
    if (_orders == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders!.isEmpty) {
      return const Center(
        child: Text(
          'No completed orders to rate at the moment.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders!.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, i) {
        final order = _orders![i];
        final orderId = order['id'] as String;
        final orderNumber = order['order_number']?.toString() ?? orderId;
        final createdAt = order['created_at'] != null
            ? DateTime.parse(order['created_at'] as String)
            : null;
        final items = (order['order_items'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            const [];
        final itemsLabel = _itemsLabel(items);
        final total = (order['total'] as num?)?.toDouble();

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
            onPressed: () => _showRatingDialog(context, orderId),
            child: const Text('Rate'),
          ),
        );
      },
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

  void _showRatingDialog(BuildContext context, String orderId) {
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
                itemBuilder: (_, _) =>
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
                        final uid = Supabase.instance.client.auth.currentUser?.id;
                        if (uid == null) throw 'Not signed in';

                        // Same order_reviews table every other review-writing
                        // screen uses — this used to write to a separate
                        // top-level `reviews` collection plus a `rated` flag
                        // on the order doc, a pre-existing third storage path.
                        await Supabase.instance.client.from('order_reviews').upsert({
                          'order_id': orderId,
                          'user_id': uid,
                          'rating': rating,
                          'comment': controller.text.trim(),
                        }, onConflict: 'order_id,user_id');

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thanks for your feedback!'),
                            ),
                          );
                        }
                        await _fetchUnratedOrders();
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
