import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'notification_detail_page.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            tooltip: "Mark All as Read",
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              if (user != null) {
                final allSnapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications')
                    .get();

                if (allSnapshot.docs.isEmpty) {
                  _showCustomDialog(
                    context,
                    title: "Nothing Here",
                    message: "You have no notifications to mark as read.",
                  );
                  return;
                }

                final unreadSnapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications')
                    .where('read', isEqualTo: false)
                    .get();

                if (unreadSnapshot.docs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("All notifications are already read."),
                    ),
                  );
                  return;
                }

                final batch = FirebaseFirestore.instance.batch();
                for (var doc in unreadSnapshot.docs) {
                  batch.update(doc.reference, {'read': true});
                }

                await batch.commit();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("All notifications marked as read."),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: "Clear All",
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              if (user != null) {
                final snapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications')
                    .get();

                if (snapshot.docs.isEmpty) {
                  _showCustomDialog(
                    context,
                    title: "Already Empty",
                    message: "There are no notifications to delete.",
                  );
                  return;
                }

                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Clear All Notifications"),
                    content: const Text(
                      "Are you sure you want to delete all notifications?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          "Delete All",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final batch = FirebaseFirestore.instance.batch();
                  for (var doc in snapshot.docs) {
                    batch.delete(doc.reference);
                  }
                  await batch.commit();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("All notifications cleared.")),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text("Please log in to see notifications."))
          : RefreshIndicator(
              onRefresh: () async =>
                  Future.delayed(const Duration(milliseconds: 500)),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView.builder(
                      itemCount: 6,
                      itemBuilder: (_, __) => _buildShimmerCard(),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off,
                            size: 100,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "You're all caught up!",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "You have no new notifications at the moment.",
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final notifications = snapshot.data!.docs;

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = notifications[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final title = data['title'] ?? 'No Title';
                      final body = data['body'] ?? 'No Message';
                      final type = data['type'] ?? 'General';
                      final orderId = data['orderId'];
                      final read = data['read'] ?? false;
                      final timestamp = (data['timestamp'] as Timestamp?)
                          ?.toDate();
                      final formattedDate = timestamp != null
                          ? DateFormat('MMM d, h:mm a').format(timestamp)
                          : "";

                      return Dismissible(
                        key: Key(doc.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          await doc.reference.delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Notification deleted."),
                              action: SnackBarAction(
                                label: "Undo",
                                onPressed: () async {
                                  await doc.reference.set(data);
                                },
                              ),
                            ),
                          );
                        },
                        child: GestureDetector(
                          onTap: () async {
                            await doc.reference.update({'read': true});
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NotificationDetailPage(
                                  title: title,
                                  body: body,
                                  timestamp: timestamp,
                                  type: type,
                                  orderId: orderId,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: read ? Colors.grey[100] : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Icon(
                                          _getIconForType(type),
                                          color: _getTypeColor(type),
                                          size: 28,
                                        ),
                                        if (!read)
                                          Positioned(
                                            top: -4,
                                            right: -4,
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            body,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getTypeColor(type),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        type.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _buildShimmerCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _showCustomDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return Icons.shopping_bag;
      case 'promo':
        return Icons.local_offer;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
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
