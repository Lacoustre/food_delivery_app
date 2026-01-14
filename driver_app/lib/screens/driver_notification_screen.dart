import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import '../widgets/notification_widget.dart';

class DriverNotificationScreen extends StatelessWidget {
  const DriverNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<int>(
            stream: NotificationService.getUnreadNotificationCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '$unreadCount unread',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: const NotificationWidget(),
    );
  }
}

// Driver-specific notification tile
class DriverNotificationTile extends StatelessWidget {
  final String notificationId;
  final String title;
  final String body;
  final bool isRead;
  final Timestamp? createdAt;
  final Map<String, dynamic>? data;

  const DriverNotificationTile({
    super.key,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
    this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isRead ? 1 : 3,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isRead ? Colors.grey : Colors.orange,
          child: Icon(
            _getNotificationIcon(),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            if (data?['orderId'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Order: ${data!['orderId']}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(createdAt!),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        trailing: data?['orderId'] != null
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
        onTap: () {
          _markAsRead();
          if (data?['orderId'] != null) {
            _navigateToOrder(context);
          }
        },
      ),
    );
  }

  IconData _getNotificationIcon() {
    if (title.toLowerCase().contains('assignment')) {
      return Icons.assignment;
    } else if (title.toLowerCase().contains('pickup')) {
      return Icons.local_shipping;
    } else if (title.toLowerCase().contains('ready')) {
      return Icons.restaurant;
    }
    return Icons.notifications;
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _markAsRead() async {
    if (!isRead) {
      await NotificationService.markNotificationAsRead(notificationId);
    }
  }

  void _navigateToOrder(BuildContext context) {
    if (data?['orderId'] != null) {
      // Navigate to order details - implement based on your routing
      Navigator.pushNamed(
        context, 
        '/driver-order-details', 
        arguments: data!['orderId']
      );
    }
  }
}