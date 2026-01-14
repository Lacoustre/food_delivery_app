import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:african_cuisine/orders/order_detail_page.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final List<DocumentSnapshot> _orders = [];
  final int _limit = 10;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isFilterLoading = false;
  double _totalSpent = 0.0;
  DocumentSnapshot? _lastDoc;
  String _selectedStatus = 'All';
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _fetchOrders(refresh: true);
    _trackScreenView();
  }

  Future<void> _trackScreenView() async {
    try {
      await _analytics.logEvent(
        name: 'view_order_history',
        parameters: {'status_filter': _selectedStatus},
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> _fetchOrders({bool refresh = false}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _isLoading) return;

    if (!refresh && !_hasMore) return;

    setState(() {
      _isLoading = true;
      if (refresh) _isFilterLoading = true;
    });

    try {
      if (refresh) {
        _orders.clear();
        _totalSpent = 0.0;
        _hasMore = true;
        _lastDoc = null;
      }

      Query query = FirebaseFirestore.instance
          .collection("orders")
          .where("userId", isEqualTo: userId)
          .orderBy("createdAt", descending: true)
          .limit(_limit);

      if (_selectedStatus == 'Completed') {
        query = query.where("deliveryStatus", whereIn: ["delivered", "picked up", "completed"]);
      } else if (_selectedStatus == 'Cancelled') {
        query = query.where("deliveryStatus", isEqualTo: "cancelled");
      } else if (_selectedStatus == 'Pending') {
        query = query.where("deliveryStatus", whereIn: ["pending", "confirmed", "preparing"]);
      }

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
        _orders.addAll(snapshot.docs);

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final pricing = data['pricing'] as Map<String, dynamic>?;
          final amount = (pricing?['total'] ?? 0.0) as num;
          _totalSpent += amount.toDouble();
        }

        if (snapshot.docs.length < _limit) {
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load orders: $e")));
    } finally {
      setState(() {
        _isLoading = false;
        _isFilterLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    _lastDoc = null;
    _hasMore = true;
    await _fetchOrders(refresh: true);
    try {
      await _analytics.logEvent(name: 'refresh_order_history');
    } catch (_) {}
  }

  void _onStatusSelected(String status) async {
    setState(() {
      _selectedStatus = status;
      _isFilterLoading = true;
    });

    try {
      await _analytics.logEvent(
        name: 'filter_order_history',
        parameters: {'status': status},
      );
    } catch (_) {}

    await _fetchOrders(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Order History"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          if (_isFilterLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: Colors.deepOrange,
            ),
          if (_orders.isEmpty && !_isLoading) _buildEmptyState(),
          if (_orders.isNotEmpty) _buildSummaryBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _orders.length + 1,
                itemBuilder: (context, index) {
                  if (index < _orders.length) {
                    final data = _orders[index].data() as Map<String, dynamic>;
                    return _buildOrderCard(context, data, _orders[index].id);
                  } else if (_hasMore && _orders.isNotEmpty) {
                    return _buildLoadMoreButton();
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft,
      child: Text(
        "Total Spent: ${NumberFormat.simpleCurrency().format(_totalSpent)}",
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.green,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _selectedStatus == 'All'
                  ? 'No orders yet'
                  : _selectedStatus == 'Completed'
                      ? 'No completed orders'
                      : _selectedStatus == 'Pending'
                          ? 'No pending orders'
                          : 'No cancelled orders',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedStatus == 'All'
                  ? 'Your order history will appear here'
                  : _selectedStatus == 'Completed'
                      ? 'Delivered orders will appear here'
                      : _selectedStatus == 'Pending'
                          ? 'Orders being processed will appear here'
                          : 'Cancelled orders will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            if (_selectedStatus != 'All')
              TextButton(
                onPressed: () => _onStatusSelected('All'),
                child: const Text('View all orders'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final statuses = [
      'All',
      'Pending',
      'Completed',
      'Cancelled',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: statuses.map((status) {
          final isSelected = _selectedStatus == status;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(status),
              selected: isSelected,
              onSelected: (_) => _onStatusSelected(status),
              selectedColor: Colors.deepOrange,
              backgroundColor: Colors.grey.shade200,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _fetchOrders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Load More Orders"),
              ),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    Map<String, dynamic> data,
    String orderId,
  ) {
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final formattedDate = DateFormat('MMM d, y • h:mm a').format(createdAt);
    final pricing = data['pricing'] as Map<String, dynamic>?;
    final total = (pricing?['total'] ?? 0.0) as num;
    final deliveryStatus = data['deliveryStatus']?.toString() ?? 'Unknown';

    final rawItems = data['items'];
    final items = rawItems is List ? rawItems : <dynamic>[];
    final itemCount = items.fold<int>(0, (sum, item) {
      final quantity = (item is Map && item['quantity'] != null)
          ? (item['quantity'] as num).toInt()
          : 1;
      return sum + quantity;
    });

    final isRecent = DateTime.now().difference(createdAt).inMinutes < 10;
    final (statusColor, statusIcon) = _getStatusProperties(deliveryStatus);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () {
          try {
            _analytics.logEvent(
              name: 'view_order_details',
              parameters: {'order_id': orderId},
            );
          } catch (_) {}
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailPage(orderData: data)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Order #${data['orderNumber'] ?? orderId.substring(0, 8).toUpperCase()}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRecent)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "NEW",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          NumberFormat.simpleCurrency().format(total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          deliveryStatus,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "$itemCount item${itemCount == 1 ? '' : 's'}",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, IconData) _getStatusProperties(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return (Colors.orange, Icons.schedule);
      case 'confirmed':
        return (Colors.indigo, Icons.check);
      case 'preparing':
        return (Colors.blue, Icons.restaurant);
      case 'ready for pickup':
        return (Colors.purple, Icons.notifications);
      case 'on the way':
      case 'out for delivery':
        return (Colors.orange, Icons.delivery_dining);
      case 'delivered':
      case 'picked up':
      case 'completed':
        return (Colors.green, Icons.check_circle);
      case 'cancelled':
        return (Colors.red, Icons.cancel);
      default:
        return (Colors.grey, Icons.help_outline);
    }
  }
}
