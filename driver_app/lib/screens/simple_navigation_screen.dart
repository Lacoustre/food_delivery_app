import 'package:flutter/material.dart';
import '../services/navigation_service.dart';

class SimpleNavigationScreen extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const SimpleNavigationScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  Widget build(BuildContext context) {
    final customerName = orderData['payment']?['customerName'] ?? 
                        orderData['customerName'] ?? 
                        'Customer';
    final address = orderData['delivery']?['address'];
    final addressText = NavigationService.formatAddress(address);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${orderId.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Customer: $customerName'),
                    const SizedBox(height: 8),
                    Text('Address: $addressText'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Navigation Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await NavigationService.openNavigation(addressText);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to open navigation: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.navigation),
                label: const Text('Open Navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}