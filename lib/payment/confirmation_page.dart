import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vibration/vibration.dart';

class ConfirmationPage extends StatefulWidget {
  final String orderId;
  final bool isScheduled;
  const ConfirmationPage({
    super.key,
    required this.orderId,
    this.isScheduled = false,
  });

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  late StreamSubscription<DocumentSnapshot> _orderSubscription;
  Map<String, dynamic>? _orderData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToOrderUpdates();
  }

  void _listenToOrderUpdates() {
    final collection = widget.isScheduled ? 'scheduled_orders' : 'orders';

    _orderSubscription = FirebaseFirestore.instance
        .collection(collection)
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
          if (mounted && snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;

            final previousStatus = _orderData?['status'];
            final newStatus = data['status'];

            // If the status has changed, show toast + vibrate
            if (previousStatus != null && previousStatus != newStatus) {
              // Flutter toast
              Fluttertoast.showToast(
                msg: "🔄 Order status: ${_capitalize(newStatus)}",
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.TOP,
                backgroundColor: Colors.deepOrange,
                textColor: Colors.white,
                fontSize: 14.0,
              );

              // Vibration (if supported)
              Vibration.hasVibrator().then((hasVibrator) {
                if (hasVibrator) {
                  Vibration.vibrate(duration: 300);
                }
              });
            }

            setState(() {
              _orderData = data;
              _isLoading = false;
            });
          }
        });
  }

  // Helper to capitalize first letter
  String _capitalize(String? value) {
    if (value == null || value.isEmpty) return '';
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  void dispose() {
    _orderSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFFDF1EC),
      appBar: AppBar(
        title: const Text('Order Confirmation'),
        backgroundColor: isDark ? Colors.black : Colors.deepOrange,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildConfirmationContent(isDark),
    );
  }

  Widget _buildConfirmationContent(bool isDark) {
    final status =
        (_orderData?['status'] ??
                (widget.isScheduled ? 'scheduled' : 'received'))
            .toString();
    final eta = widget.isScheduled
        ? 'Scheduled for ${_formatScheduledTime()}'
        : (_orderData?['eta']?.toString() ?? 'Being prepared');
    final note = (_orderData?['note'] ?? '').toString();
    final orderNumber = _orderData?['orderNumber']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 100,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            widget.isScheduled
                ? 'Order Scheduled Successfully!'
                : 'Thank you for your order!',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Order #$orderNumber',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.isScheduled ? eta : 'Estimated Ready Time: $eta',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Status: ${status[0].toUpperCase()}${status.substring(1)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              note,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: _getProgressValue(status),
            color: Colors.deepOrange,
            backgroundColor: Colors.grey[300],
            minHeight: 6,
          ),
          const SizedBox(height: 24),
          _buildActionButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.receipt_long),
          label: const Text('View Full Order Details'),
          onPressed: () {
            if (_orderData != null) {
              Navigator.pushNamed(
                context,
                '/orderDetails',
                arguments: _orderData,
              );
            }
          },
          style: _buttonStyle(isDark),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.repeat),
          label: const Text('Reorder'),
          onPressed: () {
            Navigator.pushNamed(context, '/reorder', arguments: widget.orderId);
          },
          style: _buttonStyle(isDark),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.support_agent),
          label: const Text('Contact Restaurant'),
          onPressed: () {
            Navigator.pushNamed(context, '/callSupport'); // updated route
          },
          style: _buttonStyle(isDark, background: Colors.black),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.home),
          label: const Text('Back to Home'),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
          },
          style: _buttonStyle(isDark),
        ),
      ],
    );
  }

  String _formatScheduledTime() {
    if (_orderData?['scheduledTime'] != null) {
      final scheduledTime = (_orderData!['scheduledTime'] as Timestamp)
          .toDate();
      return '${scheduledTime.day}/${scheduledTime.month}/${scheduledTime.year} at ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}';
    }
    return 'Soon';
  }

  static double _getProgressValue(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return 0.1;
      case 'pending':
      case 'received':
        return 0.2;
      case 'confirmed':
        return 0.35;
      case 'preparing':
        return 0.55;
      case 'ready':
      case 'ready for pickup':
        return 0.75;
      case 'on the way':
      case 'out for delivery':
        return 0.9;
      case 'delivered':
      case 'picked up':
      case 'completed':
        return 1.0;
      default:
        return 0.2;
    }
  }

  ButtonStyle _buttonStyle(bool isDark, {Color? background}) {
    return ElevatedButton.styleFrom(
      backgroundColor: background ?? Colors.deepOrange,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
    );
  }
}
