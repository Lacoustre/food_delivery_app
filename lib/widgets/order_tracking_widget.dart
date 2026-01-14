import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/order_tracking_service.dart';

class OrderTrackingWidget extends StatelessWidget {
  final String orderId;
  final VoidCallback? onChatPressed;

  const OrderTrackingWidget({
    Key? key,
    required this.orderId,
    this.onChatPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: OrderTrackingService.trackOrder(orderId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orderData = snapshot.data!.data() as Map<String, dynamic>?;
        if (orderData == null) {
          return const Center(child: Text('Order not found'));
        }

        final status = orderData['deliveryStatus'] ?? 'pending';
        final driverId = orderData['driverId'];
        final driverName = orderData['driverName'];

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Order #${orderId.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 16),

                // Progress Indicator
                _buildProgressIndicator(status),
                const SizedBox(height: 16),

                // Driver Info (if assigned)
                if (driverId != null && driverName != null) ...[
                  _buildDriverInfo(driverId, driverName),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                _buildActionButtons(context, status, driverId),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.schedule;
        break;
      case 'confirmed':
        color = Colors.blue;
        icon = Icons.check_circle_outline;
        break;
      case 'preparing':
        color = Colors.amber;
        icon = Icons.restaurant;
        break;
      case 'ready for pickup':
      case 'ready':
        color = Colors.green;
        icon = Icons.done;
        break;
      case 'on the way':
        color = Colors.purple;
        icon = Icons.local_shipping;
        break;
      case 'delivered':
      case 'picked up':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            _formatStatus(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(String status) {
    final steps = [
      'pending',
      'confirmed',
      'preparing',
      'ready for pickup',
      'delivered'
    ];

    final currentIndex = steps.indexOf(status.toLowerCase());
    
    return Column(
      children: [
        Row(
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isActive = index <= currentIndex;
            final isLast = index == steps.length - 1;

            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? Colors.orange : Colors.grey[300],
                    ),
                    child: Icon(
                      isActive ? Icons.check : Icons.circle,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isActive ? Colors.orange : Colors.grey[300],
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isActive = index <= currentIndex;

            return Expanded(
              child: Text(
                _formatStatus(step),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.orange : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDriverInfo(String driverId, String driverName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: Text(
              driverName[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Driver',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  driverName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onChatPressed,
            icon: const Icon(Icons.chat, color: Colors.blue),
            tooltip: 'Chat with driver',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String status, String? driverId) {
    return Row(
      children: [
        if (status.toLowerCase() == 'delivered' || status.toLowerCase() == 'picked up')
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showRatingDialog(context),
              icon: const Icon(Icons.star),
              label: const Text('Rate Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        if (driverId != null && status.toLowerCase() != 'delivered' && status.toLowerCase() != 'picked up') ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _callDriver(context),
              icon: const Icon(Icons.phone),
              label: const Text('Call Driver'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onChatPressed,
              icon: const Icon(Icons.chat),
              label: const Text('Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatStatus(String status) {
    return status
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  void _showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Your Order'),
        content: const Text('How was your experience?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to rating screen
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  void _callDriver(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Driver contact feature coming soon!'),
      ),
    );
  }
}