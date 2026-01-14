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
import 'package:african_cuisine/services/email_service.dart';

class OrderDetailPage extends StatefulWidget {
  /// Preferred: open with an orderId and the page will live-stream the doc.
  final String? orderId;

  /// Backward-compat: you can still pass a full orderData map.
  final Map<String, dynamic>? orderData;

  const OrderDetailPage({super.key, this.orderId, this.orderData});

  /// Convenience named ctor if you only have the id
  const OrderDetailPage.byId(this.orderId, {super.key}) : orderData = null;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  // --- state ---
  final Completer<GoogleMapController> _mapController = Completer();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final TextEditingController _reviewController = TextEditingController();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderSub;
  Map<String, dynamic>? _order; // the live/merged order data we render
  String? _orderDocId; // actual Firestore doc id we resolved
  bool _isLiveLoading = false;

  // map bits
  LatLng? _deliveryLatLng;
  Set<Marker> _markers = {};
  bool _isLoadingLocation = false;
  String _locationError = '';

  // review bits
  double _rating = 0;
  bool _isSubmittingReview = false;

  // status flows
  final Map<String, List<String>> _statusFlows = const {
    'delivery': [
      'pending',
      'confirmed',
      'preparing',
      'on the way',
      'delivered',
      'completed',
    ],
    'pickup': [
      'pending',
      'confirmed',
      'preparing',
      'ready for pickup',
      'picked up',
      'completed',
    ],
  };

  // ------------ lifecycle ------------
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // 1) Resolve order data + doc id
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      _orderDocId = widget.orderId;
      _startOrderStream(_orderDocId!);
    } else if (widget.orderData != null) {
      _order = Map<String, dynamic>.from(widget.orderData!);
      _orderDocId = _extractDocId(_order!);
      if (_orderDocId != null) {
        _startOrderStream(_orderDocId!); // keep live updates if we can
      } else {
        setState(() {}); // render static map
      }
    }

    // 2) analytics
    _trackViewEvent();

    // 3) try geocoding/coords
    _getDeliveryLocation();
  }

  String? _extractDocId(Map<String, dynamic> data) {
    // Prefer canonical 'id', else some apps use orderNumber as doc id.
    final id = (data['id'] ?? '').toString();
    if (id.isNotEmpty) return id;
    final orderNumber = (data['orderNumber'] ?? '').toString();
    return orderNumber.isNotEmpty ? orderNumber : null;
  }

  void _startOrderStream(String docId) {
    setState(() => _isLiveLoading = true);
    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .doc(docId)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            setState(() {
              _isLiveLoading = false;
              if (snap.exists && snap.data() != null) {
                _order = snap.data()!;
                _orderDocId = snap.id;
              } else if (_order == null) {
                // no local data and remote not found
                _order = {};
              }
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _isLiveLoading = false);
          },
        );
  }

  Future<void> _trackViewEvent() async {
    try {
      await _analytics.logEvent(
        name: 'view_order_details',
        parameters: {
          'order_id':
              widget.orderId ??
              widget.orderData?['orderNumber'] ??
              widget.orderData?['id'] ??
              'unknown',
        },
      );
    } catch (_) {}
  }

  // ------------ delivery/map ------------
  Future<void> _getDeliveryLocation() async {
    final data = _order ?? widget.orderData ?? {};
    final delivery = data['delivery'] as Map<String, dynamic>?;

    // address could be String or Map { address, latitude, longitude }
    String? address;
    if (delivery?['address'] is String) {
      address = delivery?['address'] as String?;
    } else if (delivery?['address'] is Map) {
      address = (delivery?['address'] as Map)['address']?.toString();
    }

    double? lat = (delivery?['latitude'] as num?)?.toDouble();
    double? lng = (delivery?['longitude'] as num?)?.toDouble();

    if ((lat == null || lng == null) && delivery?['address'] is Map) {
      lat = ((delivery!['address'] as Map)['latitude'] as num?)?.toDouble();
      lng = ((delivery['address'] as Map)['longitude'] as num?)?.toDouble();
    }

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
      } else {
        setState(() {
          _locationError = 'Could not find that address.';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        _locationError = 'Could not find location: $e';
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
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: 15)),
    );
  }

  // ------------ actions ------------
  Future<void> _submitReview() async {
    final order = _order ?? widget.orderData ?? {};
    final oid = _orderDocId ?? _extractDocId(order);
    if (oid == null) return;

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
          .doc(oid)
          .set({
            'orderId': oid,
            'rating': _rating,
            'review': _reviewController.text,
            'createdAt': FieldValue.serverTimestamp(),
            'userId': FirebaseAuth.instance.currentUser?.uid,
          });

      await _analytics.logEvent(
        name: 'submit_order_review',
        parameters: {'order_id': oid, 'rating': _rating},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your feedback!')),
      );
      setState(() {
        _rating = 0;
        _reviewController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _cancelOrder() async {
    final order = _order ?? widget.orderData ?? {};
    final docId = _orderDocId ?? _extractDocId(order);
    if (docId == null) return;

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

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final orderUserId = (order['userId'] ?? '').toString();
      if (orderUserId != user.uid)
        throw Exception('You can only cancel your own orders');

      await FirebaseFirestore.instance.collection('orders').doc(docId).update({
        'deliveryStatus': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'customer',
        'cancellationReason': 'Customer requested cancellation',
      });

      setState(() {
        (_order ?? widget.orderData!)['deliveryStatus'] = 'cancelled';
      });

      await FirebaseFirestore.instance.collection('admin_notifications').add({
        'type': 'order_cancelled',
        'orderId': docId,
        'orderNumber': order['orderNumber'],
        'message':
            'Order #${order['orderNumber']} has been cancelled by customer',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      final userEmail = user.email;
      final userName = user.displayName ?? 'Customer';
      if (userEmail != null) {
        await EmailService.sendOrderCompletionEmail(
          orderId: docId,
          customerEmail: userEmail,
          customerName: userName,
          status: 'cancelled',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Order cancelled successfully. You will receive a confirmation email shortly.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to cancel order: $e')));
    }
  }

  // ------------ helpers ------------
  String _getDeliveryOption(Map<String, dynamic> data) {
    final orderType = data['orderType']?.toString().toLowerCase();
    final deliveryMethod = data['deliveryMethod']?.toString().toLowerCase();
    final deliveryOption = data['delivery']?['option']
        ?.toString()
        .toLowerCase();
    final switchedToPickup = data['switchedToPickup'] as bool? ?? false;
    if (orderType == 'pickup' ||
        deliveryMethod == 'pickup' ||
        deliveryOption == 'pickup' ||
        switchedToPickup) {
      return 'pickup';
    }
    return 'delivery';
  }

  String _formatStatusName(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'ready for pickup':
        return 'Ready for Pickup';
      case 'on the way':
        return 'On the Way';
      case 'delivered':
        return 'Delivered';
      case 'picked up':
        return 'Picked Up';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status
            .split(' ')
            .where((s) => s.isNotEmpty)
            .map((s) => s[0].toUpperCase() + s.substring(1))
            .join(' ');
    }
  }

  // ------------ UI ------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmall = MediaQuery.of(context).size.width < 600;

    // decide what to render
    if ((_order == null || _order!.isEmpty) && widget.orderId != null) {
      // loading remote doc
      return Scaffold(
        appBar: AppBar(title: const Text('Order Detail')),
        body: Center(
          child: _isLiveLoading
              ? const CircularProgressIndicator()
              : const Text('Order not found'),
        ),
      );
    }

    final data = _order ?? widget.orderData ?? {};
    final items = List<Map<String, dynamic>>.from(
      (data['items'] ?? []) as List,
    );
    final pricing = (data['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    final createdAt = (data['createdAt'] is Timestamp)
        ? (data['createdAt'] as Timestamp).toDate()
        : null;

    final status = (data['deliveryStatus'] ?? data['status'] ?? 'pending')
        .toString()
        .toLowerCase();

    final deliveryOption = _getDeliveryOption(data);
    final canCancel =
        status == 'pending' || status == 'confirmed' || status == 'preparing';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order #${data['orderNumber'] ?? _orderDocId ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmall ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderSummarySection(items, pricing, createdAt, theme),
            const SizedBox(height: 24),
            _buildDeliveryStatusSection(
              status,
              deliveryOption,
              theme,
              canCancel,
            ),
            const SizedBox(height: 24),
            _buildDeliveryMapSection(theme, data),
            const SizedBox(height: 24),
            _buildReorderSection(items, theme),
            const SizedBox(height: 24),
            _buildRatingSection(theme, status, data),
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
            _priceRow(
              'Subtotal',
              (pricing['subtotal'] as num?)?.toDouble() ?? 0.0,
            ),
            _priceRow(
              'Delivery Fee',
              (pricing['deliveryFee'] as num?)?.toDouble() ?? 0.0,
            ),
            _priceRow('Tax', (pricing['tax'] as num?)?.toDouble() ?? 0.0),
            _priceRow('Tip', (pricing['tip'] as num?)?.toDouble() ?? 0.0),
            const Divider(height: 24),
            _priceRow(
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
    final instructions = item['instructions']?.toString();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: item['image'] != null && item['image'].toString().isNotEmpty
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
        item['name'] ?? '',
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
          if (instructions != null && instructions.isNotEmpty) ...[
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
              ((item['price'] as num).toDouble()) *
                  ((item['quantity'] as int?) ?? 1),
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double amount, {bool isTotal = false}) {
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
    if (status == 'cancelled') {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order Status',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red[600], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Cancelled',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[800],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This order has been cancelled and will not be processed.',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final stages = _statusFlows[deliveryOption] ?? _statusFlows['delivery']!;
    final currentIndex = stages.indexWhere((s) => s == status.toLowerCase());
    final validIndex = currentIndex >= 0 ? currentIndex : 0;

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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Current Status: ${_formatStatusName(status)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (validIndex + 1) / stages.length,
              backgroundColor: Colors.grey[200],
              color: theme.primaryColor,
              minHeight: 8,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: stages.asMap().entries.map((e) {
                  final i = e.key;
                  final stage = e.value;
                  final isCompleted = i <= validIndex;
                  final isCurrent = i == validIndex;
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
                            _formatStatusName(stage),
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

  Widget _buildDeliveryMapSection(ThemeData theme, Map<String, dynamic> data) {
    final deliveryOption =
        data['delivery']?['option']?.toString() ?? 'Delivery';
    // address string or map
    String address = 'No address provided';
    final addressData = data['delivery']?['address'];
    if (addressData is String) {
      address = addressData;
    } else if (addressData is Map) {
      address = addressData['address']?.toString() ?? 'No address provided';
    }
    final driverPhone = data['driver']?['phone']?.toString();

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
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call Driver'),
                  onPressed: driverPhone != null
                      ? () => launchUrl(Uri.parse('tel:$driverPhone'))
                      : null,
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
      onMapCreated: (controller) => _mapController.complete(controller),
    );
  }

  Widget _buildReorderSection(
    List<Map<String, dynamic>> items,
    ThemeData theme,
  ) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
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
                final clearFirst = await showDialog<bool>(
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
                if (clearFirst == true) await cartProvider.clearCart();

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
                if (!mounted) return;
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

  Widget _buildRatingSection(
    ThemeData theme,
    String status,
    Map<String, dynamic> data,
  ) {
    final hasReview = data['review'] != null;
    final existingReview = hasReview
        ? (data['review'] as Map<String, dynamic>)
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
              if ((existingReview['review'] ?? '').toString().isNotEmpty)
                Text(
                  existingReview['review'].toString(),
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
      );
    }

    final isCompleted = [
      'delivered',
      'picked up',
      'completed',
    ].contains(status);
    if (!isCompleted) return const SizedBox();

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
                onRatingUpdate: (r) => setState(() => _rating = r),
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
