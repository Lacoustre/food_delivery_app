import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class NotificationWidget extends StatelessWidget {
  const NotificationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => _clearAllNotifications(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: NotificationService.getDriverNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final data = notification.data() as Map<String, dynamic>;
              
              return NotificationTile(
                notificationId: notification.id,
                title: data['title'] ?? 'Notification',
                body: data['body'] ?? data['message'] ?? '',
                isRead: data['read'] ?? false,
                createdAt: data['createdAt'] as Timestamp?,
                orderId: data['data']?['orderId'] ?? data['orderId'],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _clearAllNotifications(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NotificationService.clearAllNotifications();
    }
  }
}

class NotificationTile extends StatelessWidget {
  final String notificationId;
  final String title;
  final String body;
  final bool isRead;
  final Timestamp? createdAt;
  final String? orderId;

  const NotificationTile({
    super.key,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
    this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isRead ? Colors.grey : Theme.of(context).primaryColor,
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
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(createdAt!),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        trailing: orderId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                onPressed: () => _navigateToOrder(context),
              )
            : null,
        onTap: () => _markAsRead(),
      ),
    );
  }

  IconData _getNotificationIcon() {
    if (title.toLowerCase().contains('order')) {
      return Icons.shopping_bag;
    } else if (title.toLowerCase().contains('delivery')) {
      return Icons.local_shipping;
    } else if (title.toLowerCase().contains('message')) {
      return Icons.message;
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
    if (orderId != null) {
      // Navigate to order details
      // This should be implemented based on your navigation structure
      Navigator.pushNamed(context, '/order-details', arguments: orderId);
    }
  }
}

// Notification badge widget for showing unread count
class NotificationBadge extends StatelessWidget {
  final Widget child;

  const NotificationBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.getUnreadNotificationCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return Stack(
          children: [
            child,
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}