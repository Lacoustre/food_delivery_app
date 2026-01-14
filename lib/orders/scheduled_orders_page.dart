import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ScheduledOrdersPage extends StatelessWidget {
  const ScheduledOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Orders'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('Please log in to view scheduled orders'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('scheduled_orders')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('scheduledTime', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
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
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final orders = snapshot.data?.docs ?? [];

                if (orders.isEmpty) {
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
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index].data() as Map<String, dynamic>;
                    final scheduledTime = (order['scheduledTime'] as Timestamp)
                        .toDate();
                    final isUpcoming = scheduledTime.isAfter(DateTime.now());

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isUpcoming
                              ? Colors.green
                              : Colors.grey,
                          child: Icon(
                            isUpcoming ? Icons.schedule : Icons.history,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          'Order #${orders[index].id.substring(0, 8)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scheduled: ${DateFormat('MMM d, yyyy h:mm a').format(scheduledTime)}',
                            ),
                            Text(
                              'Total: \$${(order['total'] ?? 0).toStringAsFixed(2)}',
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
                                    _cancelScheduledOrder(
                                      context,
                                      orders[index].id,
                                    );
                                  }
                                },
                              )
                            : const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                        onTap: () => _showOrderDetails(context, order),
                      ),
                    );
                  },
                );
              },
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
        await FirebaseFirestore.instance
            .collection('scheduled_orders')
            .doc(orderId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled order cancelled')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cancelling order: $e')));
      }
    }
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
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
                'Scheduled Time: ${DateFormat('MMM d, yyyy h:mm a').format((order['scheduledTime'] as Timestamp).toDate())}',
              ),
              const SizedBox(height: 8),
              Text('Total: \$${(order['total'] ?? 0).toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              if (order['items'] != null) ...[
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...((order['items'] as List).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('• ${item['name']} x${item['quantity']}'),
                  ),
                )),
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
