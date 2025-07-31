import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:african_cuisine/provider/cart_provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const OrderDetailPage({super.key, required this.orderData});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  LatLng? _deliveryLatLng;
  Set<Marker> _markers = {};
  bool _isLoadingLocation = false;
  String _locationError = '';
  double _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmittingReview = false;
  Completer<GoogleMapController> _mapController = Completer();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Define different status flows for different order types
  final Map<String, List<String>> _statusFlows = {
    'delivery': ['received', 'preparing', 'out for delivery', 'delivered'],
    'pickup': ['received', 'preparing', 'ready for pickup', 'picked up'],
    'dine-in': ['received', 'preparing', 'ready', 'completed'],
  };

  @override
  void initState() {
    super.initState();
    _getDeliveryLocation();
    _precacheMapIcons();
    _trackViewEvent();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _trackViewEvent() async {
    await _analytics.logEvent(
      name: 'view_order_details',
      parameters: {'order_id': widget.orderData['id']},
    );
  }

  Future<void> _precacheMapIcons() async {
    // Load custom marker icons if needed
  }

  Future<void> _getDeliveryLocation() async {
    final delivery = widget.orderData['delivery'] as Map<String, dynamic>?;
    final address = delivery?['address'] as String?;
    final lat = delivery?['latitude'] as double?;
    final lng = delivery?['longitude'] as double?;

    if (lat != null && lng != null) {
      _updateMapLocation(LatLng(lat, lng), address ?? 'Delivery Location');
      return;
    }

    if (address == null || address.isEmpty) {
      setState(() => _locationError = 'No delivery address provided');
      return;
    }

    setState(() {
      _isLoadingLocation = true;
      _locationError = '';
    });

    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        _updateMapLocation(
          LatLng(locations.first.latitude, locations.first.longitude),
          address,
        );
      }
    } catch (e) {
      setState(() {
        _locationError = 'Could not find location: ${e.toString()}';
        _isLoadingLocation = false;
      });
    }
  }

  void _updateMapLocation(LatLng latLng, String address) {
    setState(() {
      _deliveryLatLng = latLng;
      _markers = {
        Marker(
          markerId: const MarkerId('delivery'),
          position: latLng,
          infoWindow: InfoWindow(title: 'Delivery Location', snippet: address),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
      _isLoadingLocation = false;
    });
    _animateToLocation(latLng);
  }

  Future<void> _animateToLocation(LatLng latLng) async {
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: 15)),
    );
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating')));
      return;
    }

    setState(() => _isSubmittingReview = true);

    try {
      await FirebaseFirestore.instance
          .collection('order_reviews')
          .doc(widget.orderData['id'])
          .set({
            'orderId': widget.orderData['id'],
            'rating': _rating,
            'review': _reviewController.text,
            'createdAt': FieldValue.serverTimestamp(),
            'userId': FirebaseAuth.instance.currentUser?.uid,
          });

      await _analytics.logEvent(
        name: 'submit_order_review',
        parameters: {'order_id': widget.orderData['id'], 'rating': _rating},
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your feedback!')),
      );
      setState(() {
        _rating = 0;
        _reviewController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
    } finally {
      setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderData['id'])
            .update({
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to cancel order: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final items = List<Map<String, dynamic>>.from(
      widget.orderData['items'] ?? [],
    );
    final status =
        widget.orderData['status']?.toString().toLowerCase() ?? 'received';
    final deliveryOption =
        widget.orderData['delivery']?['option']?.toLowerCase() ?? 'delivery';
    final orderDate = (widget.orderData['createdAt'] as Timestamp?)?.toDate();
    final pricing = widget.orderData['pricing'] as Map<String, dynamic>? ?? {};
    final canCancel = status == 'received' || status == 'preparing';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order #${widget.orderData['orderNumber'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderSummarySection(items, pricing, orderDate, theme),
            const SizedBox(height: 24),
            _buildDeliveryStatusSection(
              status,
              deliveryOption,
              theme,
              canCancel,
            ),
            const SizedBox(height: 24),
            _buildDeliveryMapSection(theme),
            const SizedBox(height: 24),
            _buildReorderSection(cartProvider, items, theme),
            const SizedBox(height: 24),
            _buildRatingSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummarySection(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> pricing,
    DateTime? orderDate,
    ThemeData theme,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Summary',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (orderDate != null)
                  Text(
                    DateFormat('MMM d, y • h:mm a').format(orderDate),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => _buildOrderItem(item)),
            const Divider(height: 24),
            _buildPriceRow(
              'Subtotal',
              (pricing['subtotal'] as num?)?.toDouble() ?? 0.0,
            ),
            _buildPriceRow(
              'Delivery Fee',
              (pricing['deliveryFee'] as num?)?.toDouble() ?? 0.0,
            ),
            _buildPriceRow('Tax', (pricing['tax'] as num?)?.toDouble() ?? 0.0),
            _buildPriceRow('Tip', (pricing['tip'] as num?)?.toDouble() ?? 0.0),
            const Divider(height: 24),
            _buildPriceRow(
              'Total',
              (pricing['total'] as num?)?.toDouble() ?? 0.0,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final rawExtras = item['extras'] ?? [];
    final extras = (rawExtras as List)
        .map((e) => e is Map ? e['name']?.toString() ?? '' : e.toString())
        .where((name) => name.isNotEmpty)
        .toList();

    final instructions = item['instructions'] as String?;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: item['image'] != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item['image'],
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.fastfood),
              ),
            )
          : const Icon(Icons.fastfood, size: 40),
      title: Text(
        item['name'],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Extras: ${extras.join(', ')}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (instructions?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(
              'Note: $instructions',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'x${item['quantity']}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            NumberFormat.simpleCurrency().format(
              (item['price'] as num).toDouble() * (item['quantity'] as int),
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                : null,
          ),
          Text(
            NumberFormat.simpleCurrency().format(amount),
            style: isTotal
                ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryStatusSection(
    String status,
    String deliveryOption,
    ThemeData theme,
    bool canCancel,
  ) {
    final stages = _statusFlows[deliveryOption] ?? _statusFlows['delivery']!;
    final currentIndex = stages.indexWhere((s) => s == status.toLowerCase());

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Status',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (canCancel)
                  TextButton(
                    onPressed: _cancelOrder,
                    child: const Text(
                      'Cancel Order',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (currentIndex + 1) / stages.length,
              backgroundColor: Colors.grey[200],
              color: theme.primaryColor,
              minHeight: 8,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: stages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stage = entry.value;
                  final isCompleted = index <= currentIndex;
                  final isCurrent = index == currentIndex;

                  return Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? theme.primaryColor
                                : Colors.grey[300],
                            border: isCurrent
                                ? Border.all(
                                    color: theme.primaryColor,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: isCompleted
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 80,
                          child: Text(
                            stage
                                .split(' ')
                                .map((s) => s[0].toUpperCase() + s.substring(1))
                                .join(' '),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryMapSection(ThemeData theme) {
    final deliveryOption =
        widget.orderData['delivery']?['option'] ?? 'Delivery';
    final address =
        widget.orderData['delivery']?['address'] ?? 'No address provided';
    final driverPhone = widget.orderData['driver']?['phone']?.toString();

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '$deliveryOption Location',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(address, style: theme.textTheme.bodySmall),
          ),
          Container(
            height: 200,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildMapWidget(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  onPressed: _getDeliveryLocation,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call Driver'),
                  onPressed: driverPhone != null
                      ? () => launchUrl(Uri.parse('tel:$driverPhone'))
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapWidget() {
    if (_isLoadingLocation) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            'Finding delivery location...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    if (_locationError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _locationError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _getDeliveryLocation,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    if (_deliveryLatLng == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('Location not available'),
          ],
        ),
      );
    }
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _deliveryLatLng!, zoom: 15),
      markers: _markers,
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      onMapCreated: (controller) {
        _mapController.complete(controller);
      },
    );
  }

  Widget _buildReorderSection(
    CartProvider cartProvider,
    List<Map<String, dynamic>> items,
    ThemeData theme,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.repeat),
              label: const Text('Reorder Items'),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reorder Items'),
                    content: const Text(
                      'Would you like to clear your current cart first?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Add to Existing'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear & Add'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  cartProvider.clearCart();
                }

                for (final item in items) {
                  cartProvider.addToCart({
                    'id': item['id'],
                    'name': item['name'],
                    'price': item['price'],
                    'image': item['image'] ?? '',
                    'category': item['category'] ?? '',
                    'quantity': item['quantity'] ?? 1,
                    'extras': item['extras'] ?? [],
                    'instructions': item['instructions'] ?? '',
                  });
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Items added to cart!')),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection(ThemeData theme) {
    final hasReview = widget.orderData['review'] != null;
    final existingReview = hasReview
        ? widget.orderData['review'] as Map<String, dynamic>
        : null;

    if (hasReview && existingReview != null) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Review',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  RatingBarIndicator(
                    rating: (existingReview['rating'] as num).toDouble(),
                    itemBuilder: (context, _) =>
                        const Icon(Icons.star, color: Colors.amber),
                    itemCount: 5,
                    itemSize: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    existingReview['rating'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (existingReview['review'] != null &&
                  existingReview['review'].toString().isNotEmpty)
                Text(
                  existingReview['review'].toString(),
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
      );
    }

    final isDelivered =
        widget.orderData['status']?.toString().toLowerCase() == 'delivered';
    if (!isDelivered) {
      return const SizedBox();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rate Your Experience',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) =>
                    const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (rating) => setState(() => _rating = rating),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reviewController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tell us about your experience...',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: theme.cardColor,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingReview ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmittingReview
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
