import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:intl/intl.dart';
import 'package:african_cuisine/services/order_adapter.dart';

class ScheduledOrdersPage extends StatefulWidget {
  const ScheduledOrdersPage({super.key});

  @override
  State<ScheduledOrdersPage> createState() => _ScheduledOrdersPageState();
}

class _ScheduledOrdersPageState extends State<ScheduledOrdersPage> {
  List<Map<String, dynamic>>? _orders;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchScheduledOrders();
  }

  Future<void> _fetchScheduledOrders() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _orders = []);
      return;
    }

    try {
      // Scheduled orders live in the same `orders` table (scheduled_for
      // set), not a separate collection — matches the create-order Edge
      // Function's write side.
      final rows = await Supabase.instance.client
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id', userId)
          .not('scheduled_for', 'is', null)
          .order('scheduled_for', ascending: true);

      if (!mounted) return;
      setState(() {
        _orders = rows.map(orderRowToLegacyMap).toList();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Orders'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('Please log in to view scheduled orders'))
          : RefreshIndicator(
              onRefresh: _fetchScheduledOrders,
              child: _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildEmptyState();
    }

    if (_orders == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orders!.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders!.length,
      itemBuilder: (context, index) {
        final order = _orders![index];
        final scheduledTimeRaw = order['scheduledTime'] as String?;
        final scheduledTime = scheduledTimeRaw != null
            ? DateTime.parse(scheduledTimeRaw)
            : DateTime.now();
        final isUpcoming = scheduledTime.isAfter(DateTime.now());
        final pricing = order['pricing'] as Map<String, dynamic>;
        final total = (pricing['total'] ?? 0.0) as num;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isUpcoming ? Colors.green : Colors.grey,
              child: Icon(
                isUpcoming ? Icons.schedule : Icons.history,
                color: Colors.white,
              ),
            ),
            title: Text(
              'Order #${order['orderNumber'] ?? (order['id'] as String).substring(0, 8)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scheduled: ${DateFormat('MMM d, yyyy h:mm a').format(scheduledTime)}',
                ),
                Text(
                  'Total: \$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
            trailing: isUpcoming
                ? PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Text('Cancel Order'),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'cancel') {
                        _cancelScheduledOrder(context, order['id'] as String);
                      }
                    },
                  )
                : const Icon(Icons.check_circle, color: Colors.green),
            onTap: () => _showOrderDetails(context, order),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Scheduled Orders',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can schedule orders for future delivery\nwhen placing an order.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _cancelScheduledOrder(BuildContext context, String orderId) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Scheduled Order'),
        content: const Text(
          'Are you sure you want to cancel this scheduled order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      try {
        await Supabase.instance.client
            .from('orders')
            .update({
              'status': 'cancelled',
              'cancelled_at': DateTime.now().toIso8601String(),
              'cancelled_by': 'customer',
              'cancellation_reason': 'Customer cancelled scheduled order',
            })
            .eq('id', orderId);

        await _fetchScheduledOrders();

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled order cancelled')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cancelling order: $e')));
      }
    }
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    final scheduledTimeRaw = order['scheduledTime'] as String?;
    final scheduledTime = scheduledTimeRaw != null
        ? DateTime.parse(scheduledTimeRaw)
        : DateTime.now();
    final pricing = order['pricing'] as Map<String, dynamic>;
    final total = (pricing['total'] ?? 0.0) as num;
    final items = order['items'] as List<dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Order Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scheduled Time: ${DateFormat('MMM d, yyyy h:mm a').format(scheduledTime)}',
              ),
              const SizedBox(height: 8),
              Text('Total: \$${total.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              if (items.isNotEmpty) ...[
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('• ${item['name']} x${item['quantity']}'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
