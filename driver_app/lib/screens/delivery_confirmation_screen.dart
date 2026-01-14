import 'package:flutter/material.dart';
import '../services/delivery_photo_service.dart';

class DeliveryConfirmationScreen extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String address;
  final VoidCallback onConfirmed;

  const DeliveryConfirmationScreen({
    Key? key,
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.onConfirmed,
  }) : super(key: key);

  @override
  _DeliveryConfirmationScreenState createState() => _DeliveryConfirmationScreenState();
}

class _DeliveryConfirmationScreenState extends State<DeliveryConfirmationScreen> {
  String? _photoUrl;
  bool _takingPhoto = false;
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Delivery'),
        backgroundColor: Colors.green,
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
                      'Order #${widget.orderId.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(widget.customerName),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(widget.address)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Photo Section
            const Text(
              'Delivery Proof',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take a photo to confirm delivery',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Photo Display/Capture
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _photoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _photoUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.error, color: Colors.red),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No photo taken',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Take Photo Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _takingPhoto ? null : _takePhoto,
                icon: _takingPhoto
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(_photoUrl != null ? 'Retake Photo' : 'Take Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const Spacer(),

            // Confirm Delivery Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_photoUrl != null && !_confirming) ? _confirmDelivery : null,
                icon: _confirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: const Text('Confirm Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _photoUrl != null ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Skip Photo Button (optional)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _confirming ? null : _confirmWithoutPhoto,
                child: const Text('Confirm Without Photo'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    setState(() => _takingPhoto = true);
    
    try {
      final photoUrl = await DeliveryPhotoService.takeDeliveryPhoto(widget.orderId);
      
      if (photoUrl != null) {
        setState(() => _photoUrl = photoUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo captured successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture photo'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _takingPhoto = false);
    }
  }

  Future<void> _confirmDelivery() async {
    setState(() => _confirming = true);
    
    try {
      // Simulate delivery confirmation
      await Future.delayed(const Duration(seconds: 1));
      
      widget.onConfirmed();
      Navigator.pop(context, true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery confirmed with photo proof'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming delivery: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _confirming = false);
    }
  }

  Future<void> _confirmWithoutPhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Without Photo?'),
        content: const Text('Are you sure you want to confirm delivery without taking a photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onConfirmed();
      Navigator.pop(context, true);
    }
  }
}