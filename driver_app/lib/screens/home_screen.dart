// lib/screens/home_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_screen.dart';
import '../widgets/status_card.dart';
import '../widgets/unread_messages_widget.dart';
import '../services/services.dart';
import 'chat_screen.dart';
import 'driver_profile_screen.dart';
import 'driver_stats_screen.dart';

// NEW: pages
import 'settings_screen.dart';
import 'help_support_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DriverDashboardTab(),
    OrdersTab(),
    EarningsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: const Color(0xFFE65100),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_outlined),
              activeIcon: Icon(Icons.local_shipping),
              label: 'My Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.payments_outlined),
              activeIcon: Icon(Icons.payments),
              label: 'Earnings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Driver Dashboard Tab =====================
class DriverDashboardTab extends StatefulWidget {
  const DriverDashboardTab({super.key});

  @override
  State<DriverDashboardTab> createState() => _DriverDashboardTabState();
}

class _DriverDashboardTabState extends State<DriverDashboardTab> {
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
      if (doc.exists && mounted) {
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOnline ? 'You are now online' : 'You are now offline'),
            backgroundColor: _isOnline ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'deliveryStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'driver',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8E1), Colors.white],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await _loadDriverStatus();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE65100), Color(0xFFFFB300)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Icon(
                            Icons.delivery_dining,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Driver Dashboard',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE65100),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isOnline ? 'Ready for orders' : 'Currently offline',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isOnline ? Colors.green : Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isOnline ? 'ONLINE' : 'OFFLINE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Online/Offline Toggle Card
                  Card(
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
                  ),
                  const SizedBox(height: 20),

                  // Unread Messages
                  const UnreadMessagesWidget(),

                  // Assigned Orders
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
                        .where('driverId', isEqualTo: user.uid)
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
                          return _DriverOrderCard(
                            orderId: doc.id,
                            orderData: data,
                            onStatusUpdate: _updateOrderStatus,
                            onCallCustomer: _callCustomer,
                            onOpenChat: _openChat,
                            onOpenNavigation: _openNavigation,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

  void _openNavigation(String address, Map<String, dynamic>? deliveryAddress) async {
    try {
      double? latitude;
      double? longitude;
      
      // Extract coordinates if available
      if (deliveryAddress != null) {
        if (deliveryAddress['coordinates'] != null) {
          latitude = deliveryAddress['coordinates']['latitude']?.toDouble();
          longitude = deliveryAddress['coordinates']['longitude']?.toDouble();
        } else {
          latitude = deliveryAddress['latitude']?.toDouble();
          longitude = deliveryAddress['longitude']?.toDouble();
        }
      }
      
      await NavigationService.openNavigation(
        address, 
        latitude: latitude, 
        longitude: longitude
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open navigation: $e')),
      );
    }
  }
}

class _DriverOrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final Function(String, String) onStatusUpdate;
  final Function(BuildContext, Map<String, dynamic>) onCallCustomer;
  final Function(BuildContext, String, String, Map<String, dynamic>) onOpenChat;
  final Function(String, Map<String, dynamic>?) onOpenNavigation;

  const _DriverOrderCard({
    required this.orderId,
    required this.orderData,
    required this.onStatusUpdate,
    required this.onCallCustomer,
    required this.onOpenChat,
    required this.onOpenNavigation,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => onCallCustomer(context, orderData),
                      icon: const Icon(Icons.phone, color: Color(0xFFE65100)),
                      tooltip: 'Call Customer',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      onPressed: () => onOpenChat(context, orderId, customerName, orderData),
                      icon: const Icon(Icons.chat, color: Color(0xFFE65100)),
                      tooltip: 'Chat with Customer',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

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
                        onTap: () => onOpenNavigation(addressText, address),
                        child: const Text(
                          'Open Navigation',
                          style: TextStyle(
                            color: Color(0xFFE65100),
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Items (first 2)
            if (items.isNotEmpty) ...[
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...items.take(2).map((item) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 2),
                child: Text(
                  '• ${item['name'] ?? item['mealName'] ?? 'Item'} x${item['quantity'] ?? 1}',
                  style: const TextStyle(fontSize: 14),
                ),
              )),
              if (items.length > 2)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    '... and ${items.length - 2} more items',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            _buildActionButtons(status),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(String status) {
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
            onPressed: () => onStatusUpdate(orderId, 'delivered'),
            icon: const Icon(Icons.check_circle),
            label: const Text('Mark as Delivered'),
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
}

// ===================== Dashboard =====================
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _toggling = false;

  Future<void> _toggleOnline(bool next) async {
    setState(() => _toggling = true);
    try {
      await DriverService.updateDriverStatus(next ? 'online' : 'offline');
      await DriverService.updateDriverProfile({
        'isActive': next,
        if (next) 'lastActiveAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next
                  ? 'You are now online and ready to receive orders'
                  : 'You are now offline',
            ),
            backgroundColor: next ? Colors.green : Colors.grey,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    if (user == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Not signed in', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8E1), Colors.white],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: DriverService.getDriverProfile(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text('Error: ${snap.error}'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => setState(() {}),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final data = snap.data?.data() as Map<String, dynamic>?;
                    final isActive = data?['isActive'] == true;
                    final approval =
                        (data?['approvalStatus'] as String?) ?? 'pending';
                    final driverName =
                        data?['name'] ?? user.displayName ?? 'Driver';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE65100),
                                      Color(0xFFFFB300),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFE65100,
                                      ).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.delivery_dining,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back!',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      driverName,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFE65100),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.green : Colors.grey,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isActive ? 'ONLINE' : 'OFFLINE',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Status Card
                        Card(
                          elevation: 6,
                          shadowColor: Colors.black.withOpacity(0.1),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: isActive
                                    ? [
                                        const Color(0xFF2E7D32),
                                        const Color(0xFF4CAF50),
                                      ]
                                    : [Colors.grey[400]!, Colors.grey[500]!],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          isActive
                                              ? Icons.online_prediction
                                              : Icons.offline_bolt,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isActive ? 'ONLINE' : 'OFFLINE',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _getStatusMessage(
                                                approval,
                                                isActive,
                                              ),
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.9,
                                                ),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _toggling
                                          ? Container(
                                              width: 50,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.3,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Switch.adaptive(
                                              value: isActive,
                                              onChanged:
                                                  (approval == 'approved' &&
                                                      !_toggling)
                                                  ? _toggleOnline
                                                  : null,
                                              activeColor: Colors.white,
                                              activeTrackColor: Colors.white
                                                  .withOpacity(0.3),
                                              inactiveThumbColor: Colors.white
                                                  .withOpacity(0.7),
                                              inactiveTrackColor: Colors.white
                                                  .withOpacity(0.2),
                                            ),
                                    ],
                                  ),
                                  if (approval != 'approved') ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.info_outline,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _getApprovalMessage(approval),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Quick Access Button to Dashboard
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 24),
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/dashboard'),
                            icon: const Icon(Icons.dashboard),
                            label: const Text('Driver Dashboard'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE65100),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        // Quick stats
                        _QuickStats(driverId: user.uid),

                        const SizedBox(height: 24),

                        // Recent activity
                        _RecentActivity(driverId: user.uid),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusMessage(String approval, bool isActive) {
    if (approval != 'approved') {
      return 'Account status: ${approval.toUpperCase()}';
    }
    return isActive ? 'Ready to receive orders' : 'Tap switch to go online';
  }

  String _getApprovalMessage(String approval) {
    switch (approval) {
      case 'pending':
        return 'Your account is under review. You\'ll be notified once approved.';
      case 'rejected':
        return 'Account approval was rejected. Please contact support.';
      case 'suspended':
        return 'Your account is temporarily suspended. Contact support.';
      default:
        return 'Account status: $approval';
    }
  }
}

// ===================== Quick Stats =====================
class _QuickStats extends StatelessWidget {
  final String driverId;
  const _QuickStats({required this.driverId});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final now = DateTime.now();

    final pendingQ = fs
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('driverStatus', whereIn: ['assigned', 'accepted', 'picked_up'])
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();

    final deliveredTodayQ = fs
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('driverStatus', isEqualTo: 'delivered')
        .where(
          'deliveredAt',
          isGreaterThanOrEqualTo: DateTime(now.year, now.month, now.day),
        )
        .orderBy('deliveredAt', descending: true)
        .snapshots();

    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );

    final weeklyEarningsQ = fs
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('driverStatus', isEqualTo: 'delivered')
        .where('deliveredAt', isGreaterThanOrEqualTo: weekStartDate)
        .orderBy('deliveredAt', descending: true)
        .snapshots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Stats',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE65100),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: pendingQ,
                builder: (_, s) {
                  if (s.hasError) {
                    return const StatusCard(
                      title: 'Active Orders',
                      value: 'Error',
                      icon: Icons.error,
                      color: Colors.red,
                    );
                  }
                  return StatusCard(
                    title: 'Active Orders',
                    value: s.hasData ? s.data!.size.toString() : '—',
                    icon: Icons.assignment_turned_in,
                    color: const Color(0xFFE65100),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: deliveredTodayQ,
                builder: (_, s) {
                  if (s.hasError) {
                    return const StatusCard(
                      title: 'Today',
                      value: 'Error',
                      icon: Icons.error,
                      color: Colors.red,
                    );
                  }
                  return StatusCard(
                    title: 'Delivered Today',
                    value: s.hasData ? s.data!.size.toString() : '—',
                    icon: Icons.check_circle,
                    color: const Color(0xFF2E7D32),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: weeklyEarningsQ,
          builder: (_, s) {
            if (s.hasError) {
              return const StatusCard(
                title: 'This Week',
                value: 'Error',
                icon: Icons.error,
                color: Colors.red,
              );
            }

            double weeklyTotal = 0;
            if (s.hasData) {
              for (var doc in s.data!.docs) {
                final data = doc.data();
                final totalNum =
                    (data['pricing']?['total'] as num? ??
                    data['total'] as num? ??
                    0);
                weeklyTotal += totalNum.toDouble();
              }
            }

            return StatusCard(
              title: 'This Week',
              value: s.hasData ? '\$${weeklyTotal.toStringAsFixed(2)}' : '—',
              icon: Icons.monetization_on,
              color: const Color(0xFF1976D2),
            );
          },
        ),
      ],
    );
  }
}

// ===================== Recent Activity =====================
class _RecentActivity extends StatelessWidget {
  final String driverId;
  const _RecentActivity({required this.driverId});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: fs
          .collection('orders')
          .where('driverId', isEqualTo: driverId)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data();
                  final status = (data['driverStatus'] ?? 'unknown').toString();
                  final orderId = doc.id.substring(0, 8);
                  final ts = data['updatedAt'] as Timestamp?;
                  final dt = ts?.toDate();

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(status).withOpacity(0.1),
                      child: Icon(
                        _getStatusIcon(status),
                        color: _getStatusColor(status),
                        size: 20,
                      ),
                    ),
                    title: Text('Order #$orderId'),
                    subtitle: Text('Status: ${status.toUpperCase()}'),
                    trailing: dt != null
                        ? Text(
                            _formatTime(dt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          )
                        : const SizedBox.shrink(),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return Colors.blue;
      case 'accepted':
        return Colors.orange;
      case 'picked_up':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return Icons.assignment;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'picked_up':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

// ===================== Orders Tab (Enhanced) =====================
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final _auth = FirebaseAuth.instance;
  String _filter = 'active';
  bool _busy = false;

  Future<void> _updateDriverStatus(String orderId, String next) async {
    setState(() => _busy = true);
    try {
      if (next == 'delivered') {
        await OrderService.markOrderDelivered(orderId);
      } else if (next == 'picked_up') {
        await OrderService.markOrderPickedUp(orderId);
      } else {
        await OrderService.updateOrderStatus(orderId, next);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${next.replaceAll('_', ' ')}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Query<Map<String, dynamic>> _baseQuery(String uid) {
    final col = FirebaseFirestore.instance.collection('orders');
    switch (_filter) {
      case 'delivered':
        return col
            .where('driverId', isEqualTo: uid)
            .where('driverStatus', isEqualTo: 'delivered')
            .orderBy('deliveredAt', descending: true)
            .limit(50);
      case 'all':
        return col
            .where('driverId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(100);
      default: // active
        return col
            .where('driverId', isEqualTo: uid)
            .where(
              'driverStatus',
              whereIn: const ['assigned', 'accepted', 'picked_up'],
            )
            .orderBy('createdAt', descending: true)
            .limit(20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Not signed in', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFE65100),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _chip('active', 'Active', Icons.assignment_turned_in),
                const SizedBox(width: 8),
                _chip('delivered', 'Delivered', Icons.check_circle),
                const SizedBox(width: 8),
                _chip('all', 'All', Icons.list),
              ],
            ),
          ),

          if (_busy)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFFE65100),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB300)),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery(user.uid).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Error: ${snap.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getEmptyIcon(),
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getEmptyMessage(),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final o = docs[i].data();
                      final id = docs[i].id;
                      final status =
                          (o['driverStatus'] as String?) ?? 'unknown';
                      final totalNum =
                          (o['pricing']?['total'] as num? ??
                                  o['total'] as num? ??
                                  0)
                              .toDouble();
                      final addr =
                          (o['deliveryAddress']?['line1'] ??
                                  'Address not available')
                              .toString();
                      final customerName =
                          (o['customer']?['name'] ?? 'Customer').toString();
                      final createdAt = o['createdAt'] as Timestamp?;
                      final deliveredAt = o['deliveredAt'] as Timestamp?;

                      return _OrderCard(
                        orderId: id,
                        status: status,
                        total: totalNum,
                        address: addr,
                        customerName: customerName,
                        createdAt: createdAt?.toDate(),
                        deliveredAt: deliveredAt?.toDate(),
                        onStatusUpdate: _updateDriverStatus,
                        isUpdating: _busy,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String key, String label, IconData icon) {
    final selected = _filter == key;
    return Expanded(
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 18,
          color: selected ? const Color(0xFFE65100) : Colors.grey,
        ),
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = key),
        selectedColor: const Color(0xFFE65100).withOpacity(0.15),
        backgroundColor: Colors.grey[100],
        labelStyle: TextStyle(
          color: selected ? const Color(0xFFE65100) : Colors.grey[700],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  IconData _getEmptyIcon() {
    switch (_filter) {
      case 'active':
        return Icons.assignment_outlined;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.inbox_outlined;
    }
  }

  String _getEmptyMessage() {
    switch (_filter) {
      case 'active':
        return 'No active orders';
      case 'delivered':
        return 'No delivered orders';
      case 'cancelled':
        return 'No cancelled orders';
      default:
        return 'No orders found';
    }
  }
}

// ===================== Enhanced Order Card =====================
class _OrderCard extends StatelessWidget {
  final String orderId;
  final String status;
  final double total;
  final String address;
  final String customerName;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final Function(String, String) onStatusUpdate;
  final bool isUpdating;

  const _OrderCard({
    required this.orderId,
    required this.status,
    required this.total,
    required this.address,
    required this.customerName,
    this.createdAt,
    this.deliveredAt,
    required this.onStatusUpdate,
    required this.isUpdating,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getStatusColor(status).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(status).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Order info
              Row(
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Order #${orderId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Customer info
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customerName,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Timestamp
              if (createdAt != null || deliveredAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      _getTimeText(),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Action buttons
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (isUpdating) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    switch (status) {
      case 'assigned':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onStatusUpdate(orderId, 'accepted'),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Accept Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
      case 'accepted':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onStatusUpdate(orderId, 'picked_up'),
                icon: const Icon(Icons.local_shipping, size: 18),
                label: const Text('Mark Picked Up'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
      case 'picked_up':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onStatusUpdate(orderId, 'delivered'),
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Mark Delivered'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _getTimeText() {
    if (deliveredAt != null) {
      return 'Delivered: ${_formatDateTime(deliveredAt!)}';
    } else if (createdAt != null) {
      return 'Created: ${_formatDateTime(createdAt!)}';
    }
    return '';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays == 0) {
      return 'Today ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:$minute $period';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return Colors.blue;
      case 'accepted':
        return Colors.orange;
      case 'picked_up':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return Icons.assignment;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'picked_up':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
}

// ===================== Enhanced Earnings Tab =====================
class EarningsTab extends StatefulWidget {
  const EarningsTab({super.key});

  @override
  State<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<EarningsTab> {
  String _period = 'week';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Not signed in', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFE65100),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _periodChip('today', 'Today'),
                  _periodChip('week', 'Week'),
                  _periodChip('month', 'Month'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Earnings summary
            _EarningsSummary(driverId: user.uid, period: _period),

            const SizedBox(height: 24),

            // Recent deliveries
            const Text(
              'Recent Deliveries',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 12),
            _RecentDeliveries(driverId: user.uid),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String key, String label) {
    final selected = _period == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _period = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? const Color(0xFFE65100) : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}

class _EarningsSummary extends StatelessWidget {
  final String driverId;
  final String period;

  const _EarningsSummary({required this.driverId, required this.period});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getEarningsQuery(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Error loading earnings'),
            ),
          );
        }

        double totalEarnings = 0;
        int deliveryCount = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data();
            final totalNum =
                (data['pricing']?['total'] as num? ??
                        data['total'] as num? ??
                        0)
                    .toDouble();
            totalEarnings += totalNum;
            deliveryCount++;
          }
        }

        final avgPerDelivery = deliveryCount > 0
            ? totalEarnings / deliveryCount
            : 0.0;

        return Column(
          children: [
            // Main earnings card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFFB300)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE65100).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Total Earnings',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${totalEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPeriodLabel(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: StatusCard(
                    title: 'Deliveries',
                    value: deliveryCount.toString(),
                    icon: Icons.local_shipping,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatusCard(
                    title: 'Avg/Delivery',
                    value: '\$${avgPerDelivery.toStringAsFixed(2)}',
                    icon: Icons.monetization_on,
                    color: const Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getEarningsQuery() {
    final fs = FirebaseFirestore.instance;
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    return fs
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('driverStatus', isEqualTo: 'delivered')
        .where('deliveredAt', isGreaterThanOrEqualTo: startDate)
        .orderBy('deliveredAt', descending: true)
        .snapshots();
  }

  String _getPeriodLabel() {
    switch (period) {
      case 'today':
        return 'Today';
      case 'week':
        return 'This Week';
      case 'month':
        return 'This Month';
      default:
        return '';
    }
  }
}

class _RecentDeliveries extends StatelessWidget {
  final String driverId;

  const _RecentDeliveries({required this.driverId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: driverId)
          .where('driverStatus', isEqualTo: 'delivered')
          .orderBy('deliveredAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Error loading recent deliveries');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No deliveries yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data();
              final totalNum =
                  (data['pricing']?['total'] as num? ??
                          data['total'] as num? ??
                          0)
                      .toDouble();
              final address =
                  (data['deliveryAddress']?['line1'] ?? 'Unknown address')
                      .toString();
              final deliveredAt = (data['deliveredAt'] as Timestamp?)?.toDate();
              final orderId = doc.id.substring(0, 8).toUpperCase();

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Order #$orderId',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (deliveredAt != null)
                      Text(
                        _formatDeliveryTime(deliveredAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                  ],
                ),
                trailing: Text(
                  '\$${totalNum.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFFE65100),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _formatDeliveryTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inHours < 24) {
      if (difference.inHours < 1) return '${difference.inMinutes}m ago';
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}

// ===================== Profile Tab =====================
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _uploading = false;

  Future<void> _pickAndUpload(ImageSource source) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;

      setState(() => _uploading = true);

      final file = File(picked.path);

      // IMPORTANT: path matches Storage rules (profile_pictures/{uid}/{file})
      final storageRef = FirebaseStorage.instance.ref(
        'profile_pictures/${user.uid}/profile.jpg',
      );

      await storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=3600',
        ),
      );
      final url = await storageRef.getDownloadURL();

      // Update Firestore + Auth profile
      await FirebaseFirestore.instance.collection('drivers').doc(user.uid).set({
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user.updatePhotoURL(url);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {}); // refresh UI
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showPhotoPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Not signed in', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFE65100),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Phone linking',
            icon: const Icon(Icons.link),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
          if (_uploading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('drivers')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final joinDate = data?['createdAt'] as Timestamp?;
          final rating = (data?['rating'] as num?)?.toDouble() ?? 0.0;
          final totalDeliveries =
              (data?['totalDeliveries'] as num?)?.toInt() ?? 0;
          final photoUrl = (data?['photoUrl'] as String?) ?? user.photoURL;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile header with avatar + change button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE65100), Color(0xFFFFB300)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE65100).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.white.withOpacity(0.25),
                            backgroundImage:
                                (photoUrl != null && photoUrl.isNotEmpty)
                                ? NetworkImage(photoUrl)
                                : null,
                            child: (photoUrl == null || photoUrl.isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 42,
                                  )
                                : null,
                          ),
                          InkWell(
                            onTap: _uploading ? null : _showPhotoPicker,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName ??
                            (data?['name'] as String?) ??
                            'Driver',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Driver stats
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatItem(
                              icon: Icons.star,
                              label: 'Rating',
                              value: rating > 0
                                  ? rating.toStringAsFixed(1)
                                  : 'N/A',
                              color: Colors.amber,
                            ),
                          ),
                          Expanded(
                            child: _StatItem(
                              icon: Icons.local_shipping,
                              label: 'Deliveries',
                              value: totalDeliveries.toString(),
                              color: const Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ),
                      if (joinDate != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Joined ${_formatJoinDate(joinDate.toDate())}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Menu items -> open real pages
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _MenuItem(
                        icon: Icons.person,
                        title: 'Edit Profile',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DriverProfileScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuItem(
                        icon: Icons.analytics,
                        title: 'My Stats',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DriverStatsScreen(driverId: user.uid),
                            ),
                          );
                        },
                      ),
                      _MenuItem(
                        icon: Icons.link,
                        title: 'Phone Linking',
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                      ),
                      _MenuItem(
                        icon: Icons.settings,
                        title: 'Settings',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuItem(
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HelpSupportScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuItem(
                        icon: Icons.info_outline,
                        title: 'About',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuItem(
                        icon: Icons.logout,
                        title: 'Logout',
                        color: Colors.red,
                        onTap: () => _showLogoutDialog(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatJoinDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle =
        (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
          color: Colors.grey,
          fontSize: 12,
        );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: labelStyle),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}
