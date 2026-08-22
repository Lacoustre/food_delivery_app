/// Converts a Supabase `orders` row (with an embedded `order_items` list,
/// from a `select('*, order_items(*)')` query) into the same map shape the
/// old Firestore order docs had, so existing display code across the app
/// doesn't need to change — only the fetch layer does.
///
/// Driver location/messaging fields are intentionally NOT reconstructed
/// here — that system stays on Firestore untouched pending the drivers vs.
/// Uber Direct decision.
Map<String, dynamic> orderRowToLegacyMap(Map<String, dynamic> order) {
  final rawItems = order['order_items'] as List<dynamic>? ?? [];
  final items = rawItems.map((i) {
    final item = i as Map<String, dynamic>;
    return {
      'id': item['meal_id'],
      'name': item['name'],
      'price': (item['unit_price'] as num?)?.toDouble() ?? 0.0,
      'quantity': item['quantity'] ?? 1,
      'instructions': item['notes'] ?? '',
      'extras': const [],
    };
  }).toList();

  final orderType = order['order_type'] as String? ?? 'pickup';
  final status = order['status'] as String? ?? 'pending';

  return {
    'id': order['id'],
    'orderNumber': order['order_number'],
    'userId': order['user_id'],
    'items': items,
    'pricing': {
      'subtotal': (order['subtotal'] as num?)?.toDouble() ?? 0.0,
      'tax': (order['tax'] as num?)?.toDouble() ?? 0.0,
      'tip': (order['tip'] as num?)?.toDouble() ?? 0.0,
      'deliveryFee': (order['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      'total': (order['total'] as num?)?.toDouble() ?? 0.0,
    },
    'delivery': {
      'option': orderType == 'delivery' ? 'Delivery' : 'Pickup',
      'fee': (order['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      'address': order['delivery_address'],
    },
    'orderType': orderType,
    'deliveryMethod': orderType,
    'payment': {
      'method': order['payment_method'] ?? 'card',
      'status': 'completed',
    },
    'status': status,
    'deliveryStatus': status,
    // Driver assignment display-only (name), not live tracking — driver
    // location/messaging stays on Firestore, untouched, for now.
    'driver': order['driver_name'] != null ? {'name': order['driver_name']} : null,
    // Uber Direct handoff — when set, the detail page shows Uber's live
    // tracking link instead of the in-house driver UI.
    'deliveryProvider': order['delivery_provider'],
    'uberTrackingUrl': order['uber_tracking_url'],
    'uberDeliveryStatus': order['uber_delivery_status'],
    'switchedToPickup': false,
    'scheduledTime': order['scheduled_for'],
    'createdAt': order['created_at'] != null
        ? DateTime.parse(order['created_at'] as String)
        : DateTime.now(),
  };
}
