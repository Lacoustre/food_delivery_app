import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

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
          // Mark All as Read
          IconButton(
            tooltip: "Mark All as Read",
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              if (user == null) return;
              try {
                final coll = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications');

                final unread = await coll.where('read', isEqualTo: false).get();

                if (unread.docs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("All notifications are already read."),
                    ),
                  );
                  return;
                }

                final batch = FirebaseFirestore.instance.batch();
                for (final d in unread.docs) {
                  batch.update(d.reference, {'read': true});
                }
                await batch.commit();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("All notifications marked as read."),
                  ),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Failed to mark notifications as read."),
                  ),
                );
              }
            },
          ),
          // Clear All
          IconButton(
            tooltip: "Clear All",
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              if (user == null) return;
              try {
                final coll = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications');

                final snap = await coll.limit(1).get();
                if (snap.docs.isEmpty) {
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

                if (confirm != true) return;

                // Delete in batches to be safe
                const pageSize = 400;
                while (true) {
                  final page = await coll.limit(pageSize).get();
                  if (page.docs.isEmpty) break;
                  final batch = FirebaseFirestore.instance.batch();
                  for (final d in page.docs) {
                    batch.delete(d.reference);
                  }
                  await batch.commit();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All notifications cleared.")),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Failed to clear notifications."),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text("Please log in to see notifications."))
          : RefreshIndicator(
              onRefresh: () async =>
                  Future.delayed(const Duration(milliseconds: 400)),
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

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          "Failed to load notifications.\n${snapshot.error}",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _emptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final title = (data['title'] ?? 'No Title').toString();
                      final body = (data['body'] ?? 'No Message').toString();
                      final type = (data['type'] ?? 'General').toString();
                      final read = (data['read'] ?? false) == true;
                      final ts = data['timestamp'];
                      DateTime? timestamp;

                      if (ts is Timestamp) {
                        timestamp = ts.toDate();
                      } else if (ts is int) {
                        timestamp = DateTime.fromMillisecondsSinceEpoch(ts);
                      } // else leave null

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
                          try {
                            await doc.reference.delete();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Notification deleted."),
                              ),
                            );
                          } catch (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Failed to delete notification."),
                              ),
                            );
                          }
                        },
                        child: GestureDetector(
                          onTap: () async {
                            try {
                              if (!read) {
                                await doc.reference.update({'read': true});
                              }

                              if (type == 'order' ||
                                  type.toLowerCase().contains('order')) {
                                Navigator.pushNamed(context, '/orderHistory');
                              } else if (type == 'chat') {
                                Navigator.pushNamed(context, '/support');
                              } else {
                                _showNotificationBottomSheet(
                                  context,
                                  title,
                                  body,
                                  timestamp,
                                  type,
                                );
                              }
                            } catch (_) {
                              _showNotificationBottomSheet(
                                context,
                                title,
                                body,
                                timestamp,
                                type,
                              );
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: read ? Colors.grey[50] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: read
                                    ? Colors.grey[200]!
                                    : Colors.deepOrange.withOpacity(0.2),
                                width: read ? 1 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
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

  // --- UI helpers ---

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          const Text(
            "You're all caught up!",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  void _showNotificationBottomSheet(
    BuildContext context,
    String title,
    String body,
    DateTime? timestamp,
    String type,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForType(type),
                  color: _getTypeColor(type),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(body, style: const TextStyle(fontSize: 16)),
            if (timestamp != null) ...[
              const SizedBox(height: 16),
              Text(
                DateFormat('MMM d, y • h:mm a').format(timestamp),
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
