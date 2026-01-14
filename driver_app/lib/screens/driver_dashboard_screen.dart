import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/services.dart';
import '../services/driver_stats_service.dart';
import '../services/driver_location_service.dart';
import '../services/notification_service.dart';
import '../widgets/unread_messages_widget.dart';
import 'chat_screen.dart';
import 'driver_stats_screen.dart';
import 'delivery_confirmation_screen.dart';
import 'driver_notification_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  bool _isOnline = false;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadDriverStatus();
  }

  Future<void> _loadDriverStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _isOnline = doc.data()?['isActive'] ?? false;
        });
      }
    }
  }

  Future<void> _toggleOnlineStatus() async {
    setState(() => _updating = true);
    try {
      await DriverService.updateDriverProfile({'isActive': !_isOnline});
      setState(() => _isOnline = !_isOnline);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isOnline ? 'You are now online' : 'You are now offline'),
          backgroundColor: _isOnline ? Colors.green : Colors.grey,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        actions: [
          // Notification bell with badge
          StreamBuilder<int>(
            stream: NotificationService.getUnreadNotificationCount(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // Show notification icon without badge if there's an error
                return IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverNotificationScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.notifications),
                  tooltip: 'Notifications',
                );
              }
              
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DriverNotificationScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.notifications),
                    tooltip: 'Notifications',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
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
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DriverStatsScreen(driverId: user.uid),
              ),
            ),
            icon: const Icon(Icons.analytics),
            tooltip: 'My Stats',
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  _isOnline ? Icons.circle : Icons.circle_outlined,
                  color: _isOnline ? Colors.green : Colors.grey,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  _isOnline ? 'ONLINE' : 'OFFLINE',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Online/Offline Toggle
              _buildStatusCard(),
              const SizedBox(height: 20),
              
              // Unread Messages
              const UnreadMessagesWidget(),
              
              // Assigned Orders
              _buildAssignedOrders(user.uid),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: _isOnline 
                ? [const Color(0xFF2E7D32), const Color(0xFF4CAF50)]
                : [Colors.grey[400]!, Colors.grey[500]!],
          ),
        ),
        child: Column(
          children: [
            Icon(
              _isOnline ? Icons.online_prediction : Icons.offline_bolt,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _isOnline ? 'ONLINE' : 'OFFLINE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isOnline 
                  ? 'Ready to receive orders' 
                  : 'Tap to go online',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _updating ? null : _toggleOnlineStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _isOnline ? const Color(0xFF2E7D32) : Colors.grey[600],
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: _updating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isOnline ? 'Go Offline' : 'Go Online'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedOrders(String driverId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assigned Orders',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE65100),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('driverId', isEqualTo: driverId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Error: ${snapshot.error}'),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final allOrders = snapshot.data?.docs ?? [];
            // Filter on client side to avoid index requirement
            final orders = allOrders.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['deliveryStatus'] ?? 'pending';
              return ['confirmed', 'preparing', 'on the way'].contains(status);
            }).toList();

            if (orders.isEmpty) {
              return Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No assigned orders',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isOnline 
                            ? 'Orders will appear here when assigned'
                            : 'Go online to receive orders',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: orders.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _OrderCard(
                  orderId: doc.id,
                  orderData: data,
                  onStatusUpdate: _updateOrderStatus,
                  onShowDeliveryConfirmation: _showDeliveryConfirmation,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      // Always try to update directly since offline mode may not be available
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'deliveryStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'driver',
        if (newStatus == 'delivered') 'completedAt': FieldValue.serverTimestamp(),
      });

      // Handle location sharing based on status
      if (newStatus == 'on the way') {
        await DriverLocationService.startLocationSharing();
        await DriverLocationService.updateDriverStatus('delivering');
      } else if (newStatus == 'delivered') {
        await DriverLocationService.stopLocationSharing();
        await DriverLocationService.updateDriverStatus('online');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeliveryConfirmation(BuildContext context, String orderId, Map<String, dynamic> orderData) {
    final customerName = orderData['payment']?['customerName'] ?? 
                        orderData['customerName'] ?? 
                        'Customer';
    final address = orderData['delivery']?['address'];
    final addressText = address != null 
        ? '${address['street'] ?? ''}, ${address['city'] ?? ''}'
        : 'Address not available';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryConfirmationScreen(
          orderId: orderId,
          customerName: customerName,
          address: addressText,
          onConfirmed: () => _updateOrderStatus(orderId, 'delivered'),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final Function(String, String) onStatusUpdate;
  final Function(BuildContext, String, Map<String, dynamic>) onShowDeliveryConfirmation;

  const _OrderCard({
    required this.orderId,
    required this.orderData,
    required this.onStatusUpdate,
    required this.onShowDeliveryConfirmation,
  });

  @override
  Widget build(BuildContext context) {
    final status = orderData['deliveryStatus'] ?? 'pending';
    final customerName = orderData['payment']?['customerName'] ?? 
                        orderData['customerName'] ?? 
                        'Customer';
    final total = (orderData['pricing']?['total'] ?? orderData['total'] ?? 0.0).toDouble();
    final address = orderData['delivery']?['address'];
    final addressText = address != null 
        ? '${address['street'] ?? ''}, ${address['city'] ?? ''}'
        : 'Address not available';
    
    final items = orderData['items'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Order ID
            Text(
              'Order #${orderId.substring(0, 8).toUpperCase()}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Customer
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(customerName)),
                // Communication buttons
                SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _callCustomer(context, orderData),
                        icon: const Icon(Icons.phone, color: Color(0xFFE65100)),
                        tooltip: 'Call Customer',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        onPressed: () => _openChat(context, orderId, customerName, orderData),
                        icon: const Icon(Icons.chat, color: Color(0xFFE65100)),
                        tooltip: 'Chat with Customer',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(addressText),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _openNavigation(addressText),
                        child: const Text(
                          'Open Navigation',
                          style: TextStyle(
                            color: Color(0xFFE65100),
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Items
            if (items.isNotEmpty) ...[
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...items.take(3).map((item) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 2),
                child: Text(
                  '• ${item['name'] ?? item['mealName'] ?? 'Item'} x${item['quantity'] ?? 1}',
                  style: const TextStyle(fontSize: 14),
                ),
              )),
              if (items.length > 3)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    '... and ${items.length - 3} more items',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            _buildActionButtons(status, context),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(String status, BuildContext context) {
    switch (status) {
      case 'confirmed':
      case 'preparing':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => onStatusUpdate(orderId, 'on the way'),
            icon: const Icon(Icons.local_shipping),
            label: const Text('Mark as On the Way'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
      case 'on the way':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => onShowDeliveryConfirmation(context, orderId, orderData),
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirm Delivery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'preparing':
        return Colors.blue;
      case 'on the way':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _callCustomer(BuildContext context, Map<String, dynamic> orderData) async {
    final customerPhone = orderData['payment']?['customerPhone'] ?? 
                         orderData['customerPhone'];
    
    if (customerPhone != null && customerPhone.isNotEmpty) {
      final phoneUrl = 'tel:$customerPhone';
      if (await canLaunchUrl(Uri.parse(phoneUrl))) {
        await launchUrl(Uri.parse(phoneUrl));
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot make phone calls on this device'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer phone number not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _openChat(BuildContext context, String orderId, String customerName, Map<String, dynamic> orderData) {
    final customerId = orderData['userId'] ?? orderData['customerId'];
    
    if (customerId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            orderId: orderId,
            customerName: customerName,
            customerId: customerId,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot start chat: Customer ID not found'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _openNavigation(String address) async {
    try {
      await NavigationService.openNavigation(address);
    } catch (e) {
      // Handle error silently
    }
  }
}