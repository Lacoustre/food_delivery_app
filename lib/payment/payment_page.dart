import 'dart:async';
import 'dart:io';
import 'package:african_cuisine/orders/order_number_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:african_cuisine/provider/cart_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:african_cuisine/payment/confirmation_page.dart';
import 'package:african_cuisine/delivery/delivery_fee_provider.dart';
import 'package:african_cuisine/services/email_service.dart';
import 'package:african_cuisine/services/push_notification_service.dart';
import 'package:intl/intl.dart';

// ===== CONSTANTS =====
class PaymentConstants {
  static const double defaultTaxRate = 0.0635; // Default CT tax rate
  static const double minimumPaymentAmount = 0.50;
  static const double maxDeliveryDistance = 15.0;
  static const double maxTipAmount = 999.99;
  static const int paymentIntentTimeoutSeconds = 30;
  static const int maxRetryAttempts = 1;
  static const String merchantName = 'Taste of African Cuisine';
  static const String merchantCountryCode = 'US';
  static const String defaultCurrency = 'USD';

  static const List<String> validOrderStatuses = [
    'received',
    'confirmed',
    'preparing',
    'ready for pickup',
    'picked up',
    'on the way',
    'delivered',
    'cancelled',
    'completed',
  ];

  static const List<double> defaultTipOptions = [0.0, 5.0, 10.0, 15.0, 20.0];
}

// ===== ENUMS =====
enum PaymentMethod {
  card('card', 'Credit/Debit Card', Icons.credit_card),
  applePay('apple_pay', 'Apple Pay', Icons.phone_iphone),
  googlePay('google_pay', 'Google Pay', Icons.payment);

  const PaymentMethod(this.id, this.displayName, this.icon);
  final String id;
  final String displayName;
  final IconData icon;

  bool get isWalletPayment => this == applePay || this == googlePay;
}

enum DeliveryOption {
  delivery('Delivery', Icons.delivery_dining),
  pickup('Pickup', Icons.store);

  const DeliveryOption(this.displayName, this.icon);
  final String displayName;
  final IconData icon;
}

enum PaymentState { idle, validating, processing, completed, failed, cancelled }

// ===== EXCEPTIONS =====
class PaymentException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const PaymentException(this.message, {this.code, this.originalError});

  @override
  String toString() =>
      'PaymentException: $message${code != null ? ' (Code: $code)' : ''}';
}

class LocationException implements Exception {
  final String message;
  final Object? originalError;

  const LocationException(this.message, {this.originalError});

  @override
  String toString() => 'LocationException: $message';
}

// ===== DATA MODELS =====
class PaymentTotals {
  final double subtotal;
  final double tax;
  final double tip;
  final double deliveryFee;
  final double total;

  const PaymentTotals({
    required this.subtotal,
    required this.tax,
    required this.tip,
    required this.deliveryFee,
    required this.total,
  });

  PaymentTotals copyWith({
    double? subtotal,
    double? tax,
    double? tip,
    double? deliveryFee,
    double? total,
  }) {
    return PaymentTotals(
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      tip: tip ?? this.tip,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      total: total ?? this.total,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subtotal': subtotal,
      'tax': tax,
      'tip': tip,
      'deliveryFee': deliveryFee,
      'total': total,
    };
  }
}

class OrderData {
  final String orderNumber;
  final String userId;
  final List<Map<String, dynamic>> items;
  final PaymentTotals pricing;
  final Map<String, dynamic> delivery;
  final Map<String, dynamic> payment;
  final String status;
  final Map<String, dynamic> statusHistory;
  final String createdAt;
  final String updatedAt;
  final String? orderType;
  final String? deliveryMethod;
  final double distanceMiles;

  const OrderData({
    required this.orderNumber,
    required this.userId,
    required this.items,
    required this.pricing,
    required this.delivery,
    required this.payment,
    required this.status,
    required this.statusHistory,
    required this.createdAt,
    required this.updatedAt,
    this.orderType,
    this.deliveryMethod,
    this.distanceMiles = 0,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'orderNumber': orderNumber,
      'userId': userId,
      'items': items,
      'pricing': pricing.toMap(),
      'delivery': delivery,
      'payment': payment,
      'status': status,
      'statusHistory': statusHistory,
      'eta': null,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'distanceMiles': distanceMiles,
      if (orderType != null) 'orderType': orderType,
      if (deliveryMethod != null) 'deliveryMethod': deliveryMethod,
    };
  }
}

// ===== SERVICES =====
class PaymentService {
  static Future<Map<String, dynamic>> createPaymentIntent({
    required List<Map<String, dynamic>> items,
    required String orderType,
    required double distanceMiles,
    required double tipAmount,
    required String orderId,
    required String customerName,
    required String itemsDescription,
  }) async {
    debugPrint('🚀 PaymentService.createPaymentIntent called');
    debugPrint('   Order ID: $orderId');
    debugPrint('   Customer: $customerName');

    try {
      // Authentication check — the Edge Function verifies the caller's
      // Supabase session, not Firebase's, since that's what it runs on.
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      if (supabaseUser == null) {
        debugPrint('❌ No authenticated Supabase user found');
        throw const PaymentException(
          'User not authenticated',
          code: 'unauthenticated',
        );
      }

      debugPrint('✅ Supabase user authenticated: ${supabaseUser.id}');
      debugPrint('   Email: ${supabaseUser.email}');

      final requestData = {
        'items': items,
        'orderType': orderType,
        'distanceMiles': distanceMiles,
        'tipAmount': tipAmount,
        'orderId': orderId.trim(),
        'customerName':
            (customerName.isNotEmpty
                    ? customerName
                    : supabaseUser.email ?? 'Customer')
                .trim(),
        'currency': PaymentConstants.defaultCurrency.toLowerCase(),
      };

      debugPrint('📤 Calling create-payment-intent Edge Function with data:');
      debugPrint('   ${requestData.toString()}');

      final response = await Supabase.instance.client.functions
          .invoke('create-payment-intent', body: requestData)
          .timeout(
            const Duration(
              seconds: PaymentConstants.paymentIntentTimeoutSeconds,
            ),
            onTimeout: () {
              debugPrint('⏰ Edge Function call timed out');
              throw const PaymentException(
                'Payment request timed out',
                code: 'deadline-exceeded',
              );
            },
          );

      debugPrint('📦 Edge Function response received');
      debugPrint('   Status: ${response.status}');

      final data = response.data;
      if (data == null) {
        debugPrint('❌ Null response data');
        throw const PaymentException('Empty response from payment service');
      }

      debugPrint('📋 Response data contents:');
      if (data is Map) {
        for (final entry in data.entries) {
          debugPrint('   ${entry.key}: ${entry.value?.toString() ?? 'null'}');
        }
      } else {
        debugPrint('   Data: $data');
      }

      final responseMap = data as Map<String, dynamic>;
      if (responseMap['error'] != null) {
        throw PaymentException(responseMap['error'].toString());
      }
      final clientSecret = responseMap['client_secret'];

      if (clientSecret == null || clientSecret.toString().isEmpty) {
        debugPrint('❌ Missing or empty client_secret in response');
        debugPrint('   Available keys: ${responseMap.keys.toList()}');
        throw const PaymentException(
          'Invalid payment intent response - missing client secret',
        );
      }

      debugPrint('✅ Payment intent created successfully');
      debugPrint('   Client secret length: ${clientSecret.toString().length}');

      return {
        'client_secret': clientSecret.toString(),
        'orderId': orderId,
        // Server-validated totals — this is what was actually charged.
        'subtotal': (responseMap['subtotal'] as num?)?.toDouble() ?? 0.0,
        'deliveryFee': (responseMap['deliveryFee'] as num?)?.toDouble() ?? 0.0,
        'tax': (responseMap['tax'] as num?)?.toDouble() ?? 0.0,
        'tip': (responseMap['tip'] as num?)?.toDouble() ?? 0.0,
        'total': (responseMap['total'] as num?)?.toDouble() ?? 0.0,
        'items': responseMap['items'],
      };
    } on FunctionException catch (e) {
      debugPrint('❌ Supabase Function Exception:');
      debugPrint('   Status: ${e.status}');
      debugPrint('   Details: ${e.details}');

      String message = 'Payment request failed';
      final details = e.details;
      if (details is Map && details['error'] != null) {
        message = details['error'].toString();
      } else if (details != null) {
        message = details.toString();
      }

      throw PaymentException(
        message,
        code: e.status.toString(),
        originalError: e,
      );
    } on PaymentException {
      // Re-throw PaymentException as-is
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected error in createPaymentIntent:');
      debugPrint('   Error type: ${e.runtimeType}');
      debugPrint('   Error: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');

      throw PaymentException(
        'Unexpected error creating payment intent: ${e.toString()}',
        originalError: e,
      );
    }
  }

  // Saves the order via the create-order Edge Function, which re-validates
  // items/pricing server-side rather than trusting orderData wholesale.
  // Also used for scheduled orders (pass scheduledFor).
  static Future<Map<String, dynamic>> saveOrder(
    OrderData orderData, {
    String? scheduledFor,
  }) async {
    debugPrint('💾 Saving order: ${orderData.orderNumber}');

    try {
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      if (supabaseUser == null) {
        debugPrint('❌ No authenticated Supabase user for order save');
        throw const PaymentException(
          'User not authenticated',
          code: 'unauthenticated',
        );
      }

      final deliveryAddressField = orderData.delivery['address'];
      final deliveryAddress = deliveryAddressField is Map
          ? deliveryAddressField['address'] as String?
          : deliveryAddressField as String?;

      final requestData = {
        'items': orderData.items
            .map((item) => {
                  'id': item['id'],
                  'name': item['name'],
                  'quantity': item['quantity'],
                  'notes': item['instructions'],
                })
            .toList(),
        'orderType': orderData.orderType ?? 'pickup',
        'distanceMiles': orderData.distanceMiles,
        'tipAmount': orderData.pricing.tip,
        'deliveryAddress': deliveryAddress,
        'paymentMethod': 'card',
        if (scheduledFor != null) 'scheduledFor': scheduledFor,
      };

      final response = await Supabase.instance.client.functions.invoke(
        'create-order',
        body: requestData,
      );

      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw PaymentException(data['error'].toString());
      }

      debugPrint('✅ Order saved successfully: $data');
      return data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      debugPrint('❌ Error saving order via Edge Function:');
      debugPrint('   Status: ${e.status}');
      debugPrint('   Details: ${e.details}');

      String message = 'Failed to save order';
      final details = e.details;
      if (details is Map && details['error'] != null) {
        message = details['error'].toString();
      } else if (details != null) {
        message = details.toString();
      }

      throw PaymentException(message, code: e.status.toString(), originalError: e);
    } on PaymentException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected error saving order: $e');
      throw PaymentException('Unexpected error saving order', originalError: e);
    }
  }
}

class LocationService {
  static Future<Map<String, dynamic>?> getCurrentDeliveryAddress() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestResult = await Geolocator.requestPermission();
        if (requestResult == LocationPermission.denied) {
          throw const LocationException('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw const LocationException('Location permission permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final address = await _getAddressFromCoordinates(position);

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
        'address': address,
      };
    } catch (e) {
      throw LocationException(
        'Failed to get current location',
        originalError: e,
      );
    }
  }

  static Future<String> _getAddressFromCoordinates(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final addressParts = [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.postalCode,
        ].where((part) => part != null && part.isNotEmpty);

        return addressParts.join(', ');
      }

      return 'Address unavailable';
    } catch (e) {
      debugPrint('Geocoding failed: $e');
      return 'Address unavailable';
    }
  }
}

// ===== MAIN PAYMENT PAGE =====
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> with WidgetsBindingObserver {
  // State management
  PaymentState _paymentState = PaymentState.idle;
  PaymentMethod? _selectedPaymentMethod;
  double _selectedTip = 0.0;
  bool _isCustomTip = false;
  int _retryCount = 0;
  final List<double> _tipOptions = PaymentConstants.defaultTipOptions;
  double _taxRate = PaymentConstants.defaultTaxRate;
  bool _isScheduledOrder = false;
  DateTime? _scheduledTime;
  bool _isRestaurantOpen = true;

  // Cached settings
  Map<String, dynamic>? _cachedSettings;
  DateTime? _lastSettingsFetch;
  StreamSubscription<List<Map<String, dynamic>>>? _restaurantStatusSubscription;

  // Controllers
  final TextEditingController _customTipController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Computed properties
  bool get _isProcessing => _paymentState == PaymentState.processing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _customTipController.addListener(_onCustomTipChanged);
    _loadSettings();
    _listenToRestaurantStatus();
  }

  void _listenToRestaurantStatus() {
    _restaurantStatusSubscription = Supabase.instance.client
        .from('settings')
        .stream(primaryKey: ['key'])
        .eq('key', 'restaurant')
        .listen((rows) {
          if (rows.isNotEmpty && mounted) {
            final value = rows.first['value'] as Map<String, dynamic>?;
            setState(() {
              _isRestaurantOpen = value?['isOpen'] ?? true;
            });
          }
        });
  }

  Future<void> _loadSettings() async {
    // Use cached settings if available and recent (5 minutes)
    if (_cachedSettings != null &&
        _lastSettingsFetch != null &&
        DateTime.now().difference(_lastSettingsFetch!).inMinutes < 5) {
      _taxRate =
          (_cachedSettings!['taxRate'] ?? PaymentConstants.defaultTaxRate) /
          100;
      return;
    }

    try {
      final row = await Supabase.instance.client
          .from('settings')
          .select('value')
          .eq('key', 'restaurant')
          .maybeSingle();

      if (row != null && mounted) {
        _cachedSettings = (row['value'] as Map<String, dynamic>?) ?? {};
        _lastSettingsFetch = DateTime.now();
        setState(() {
          _taxRate =
              (_cachedSettings!['taxRate'] ??
                  PaymentConstants.defaultTaxRate * 100) /
              100;
        });
      }
    } catch (e) {
      debugPrint('Error fetching payment settings: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _customTipController.removeListener(_onCustomTipChanged);
    _customTipController.dispose();
    _restaurantStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _paymentState == PaymentState.processing) {
      // Handle app resuming during payment
      _resetPaymentState();
    }
  }

  void _onCustomTipChanged() {
    if (mounted) setState(() {});
  }

  void _resetPaymentState() {
    if (mounted) {
      setState(() {
        _paymentState = PaymentState.idle;
        _retryCount = 0;
      });
    }
  }

  // ===== CALCULATION METHODS =====
  PaymentTotals _calculateTotals() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final deliveryProvider = Provider.of<DeliveryFeeProvider>(
      context,
      listen: false,
    );

    final subtotal = cartProvider.totalPrice;
    final tax = subtotal * _taxRate;

    final tipAmount = _isCustomTip && _customTipController.text.isNotEmpty
        ? double.tryParse(_customTipController.text) ?? 0.0
        : subtotal * (_selectedTip / 100);

    final deliveryFee =
        deliveryProvider.deliveryOption == DeliveryOption.delivery
        ? deliveryProvider.deliveryFee
        : 0.0;

    final total = subtotal + tax + tipAmount + deliveryFee;

    return PaymentTotals(
      subtotal: subtotal,
      tax: tax,
      tip: tipAmount,
      deliveryFee: deliveryFee,
      total: total,
    );
  }

  // ===== VALIDATION METHODS =====
  bool _validatePaymentForm() {
    // First validate the form fields
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return false;
    }

    // Check if payment method is selected
    if (_selectedPaymentMethod == null) {
      _showErrorSnack("Please select a payment method");
      return false;
    }

    final totals = _calculateTotals();

    // Check minimum payment amount
    if (totals.total < PaymentConstants.minimumPaymentAmount) {
      _showErrorSnack(
        "Minimum payment amount is \$${PaymentConstants.minimumPaymentAmount.toStringAsFixed(2)}",
      );
      return false;
    }

    // Additional validation for delivery if needed
    final deliveryProvider = Provider.of<DeliveryFeeProvider>(
      context,
      listen: false,
    );
    if (deliveryProvider.deliveryOption == DeliveryOption.delivery &&
        !deliveryProvider.deliveryAvailable) {
      _showErrorSnack("Delivery is not available for your location");
      return false;
    }

    return true;
  }

  String? _validateCustomTip(String? value) {
    if (!_isCustomTip || value == null || value.isEmpty) return null;

    final tip = double.tryParse(value);
    if (tip == null) return 'Please enter a valid amount';
    if (tip < 0) return 'Tip cannot be negative';
    if (tip > PaymentConstants.maxTipAmount) {
      return 'Maximum tip is \$${PaymentConstants.maxTipAmount.toStringAsFixed(2)}';
    }

    return null;
  }

  // ===== PAYMENT PROCESSING =====
  Future<void> _processPayment() async {
    if (!_validatePaymentForm()) return;

    final totals = _calculateTotals();
    final confirmed = await _showPaymentConfirmationDialog(totals);
    if (!confirmed) return;

    setState(() => _paymentState = PaymentState.processing);

    try {
      await _executePaymentFlow(totals);
    } catch (e) {
      await _handlePaymentError(e);
    }
  }

  Future<void> _executePaymentFlow(PaymentTotals totals) async {
    // Handle scheduled orders (either manually scheduled or restaurant closed)
    if ((_isScheduledOrder || !_isRestaurantOpen) && _scheduledTime != null) {
      await _processScheduledOrderPayment(totals);
      return;
    }

    debugPrint('🚀 === PAYMENT FLOW STARTED ===');
    debugPrint('💰 Payment totals:');
    debugPrint('   Subtotal: \$${totals.subtotal.toStringAsFixed(2)}');
    debugPrint('   Tax: \$${totals.tax.toStringAsFixed(2)}');
    debugPrint('   Tip: \$${totals.tip.toStringAsFixed(2)}');
    debugPrint('   Delivery: \$${totals.deliveryFee.toStringAsFixed(2)}');
    debugPrint('   TOTAL: \$${totals.total.toStringAsFixed(2)}');

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('❌ No authenticated user');
      throw const PaymentException('User not authenticated');
    }

    debugPrint('👤 User details:');
    debugPrint('   UID: ${user.id}');
    debugPrint('   Email: ${user.email ?? 'No email'}');

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final deliveryProvider = Provider.of<DeliveryFeeProvider>(
      context,
      listen: false,
    );
    final orderId = OrderNumberGenerator.generate();

    debugPrint('🛒 Cart details:');
    debugPrint('   Items count: ${cartProvider.items.length}');
    debugPrint('   Order ID: $orderId');

    try {
      // Create payment intent — the server recomputes the real total from
      // authoritative meal prices; it never trusts a client-supplied amount.
      debugPrint('💳 === CREATING PAYMENT INTENT ===');
      final paymentIntent = await PaymentService.createPaymentIntent(
        items: cartProvider.items
            .map((item) => {'id': item.id, 'name': item.name, 'quantity': item.quantity})
            .toList(),
        orderType: deliveryProvider.deliveryOption == DeliveryOption.delivery
            ? 'delivery'
            : 'pickup',
        distanceMiles: deliveryProvider.deliveryDistance,
        tipAmount: totals.tip,
        orderId: orderId,
        customerName: user.email ?? 'Customer',
        itemsDescription: cartProvider.items
            .map((item) => '${item.name} x${item.quantity}')
            .join(', '),
      );

      debugPrint('✅ Payment intent received:');
      debugPrint(
        '   Client secret exists: ${paymentIntent['client_secret'] != null}',
      );
      debugPrint(
        '   Client secret length: ${paymentIntent['client_secret']?.length ?? 0}',
      );
      debugPrint('   Total: ${paymentIntent['total']}');

      // Initialize payment sheet
      debugPrint('📱 === INITIALIZING PAYMENT SHEET ===');
      await _initializePaymentSheet(paymentIntent);
      debugPrint('✅ Payment sheet initialized');

      // Present payment sheet
      debugPrint('📱 === PRESENTING PAYMENT SHEET ===');
      await Stripe.instance.presentPaymentSheet();
      debugPrint('✅ Payment sheet completed successfully');

      // Save order — built from the server-validated totals/items returned
      // above, not the raw client-computed ones, so what gets fulfilled
      // always matches what was actually charged.
      debugPrint('💾 === SAVING ORDER ===');
      final validatedTotals = PaymentTotals(
        subtotal: paymentIntent['subtotal'] as double,
        tax: paymentIntent['tax'] as double,
        tip: paymentIntent['tip'] as double,
        deliveryFee: paymentIntent['deliveryFee'] as double,
        total: paymentIntent['total'] as double,
      );
      final orderData = await _createOrderData(
        user.id,
        orderId,
        validatedTotals,
        validatedItems: paymentIntent['items'] as List<dynamic>?,
      );
      await PaymentService.saveOrder(orderData);
      debugPrint('✅ Order saved successfully');

      // Send push notification only (skip email for now)
      try {
        await PushNotificationService.sendOrderReceivedNotification(
          orderId: orderId,
          userId: user.id,
        );
      } catch (e) {
        debugPrint('Push notification failed: $e');
        // Continue without notification - don't block order completion
      }

      // Cleanup and navigation
      cartProvider.clearCart();
      setState(() => _paymentState = PaymentState.completed);

      _showSuccessSnack("Payment successful!");

      if (mounted) {
        debugPrint('🎉 === PAYMENT COMPLETED - NAVIGATING ===');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ConfirmationPage(orderId: orderId, isScheduled: false),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ === PAYMENT FLOW ERROR ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');

      if (e is PaymentException) {
        debugPrint('Payment exception details:');
        debugPrint('   Code: ${e.code}');
        debugPrint('   Original error: ${e.originalError}');
      }

      if (e is StripeException) {
        debugPrint('Stripe exception details:');
        debugPrint('   Error code: ${e.error.code}');
        debugPrint('   Error message: ${e.error.message}');
        debugPrint('   Error type: ${e.error.type}');
      }

      debugPrint('Stack trace:');
      debugPrint(stackTrace.toString());

      setState(() => _paymentState = PaymentState.failed);
      rethrow;
    }
  }

  Future<OrderData> _createOrderData(
    String userId,
    String orderId,
    PaymentTotals totals, {
    List<dynamic>? validatedItems,
  }) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final deliveryProvider = Provider.of<DeliveryFeeProvider>(
      context,
      listen: false,
    );
    final nowIso = DateTime.now().toIso8601String();
    final user = Supabase.instance.client.auth.currentUser!;
    final customerName = await _customerDisplayName(user);

    // Merge server-validated id/name/price (authoritative) with the
    // client's display-only fields (image/category/extras/instructions),
    // matched by position — the same order sent to createPaymentIntent.
    final cartItems = cartProvider.items;
    final items = List.generate(cartItems.length, (i) {
      final item = cartItems[i];
      final validated = validatedItems != null && i < validatedItems.length
          ? validatedItems[i] as Map<String, dynamic>
          : null;
      return {
        'id': validated?['id'] ?? item.id,
        'name': validated?['name'] ?? item.name,
        'price': validated != null
            ? (validated['price'] as num).toDouble()
            : item.price,
        'quantity': item.quantity,
        'image': item.image,
        'category': item.category,
        'extras': item.extras,
        'instructions': item.instructions,
      };
    });

    Map<String, dynamic>? deliveryAddress;
    if (deliveryProvider.deliveryOption == DeliveryOption.delivery) {
      try {
        deliveryAddress = deliveryProvider.deliveryLocation != null
            ? await _getDeliveryAddressFromProvider(deliveryProvider)
            : await LocationService.getCurrentDeliveryAddress();
      } catch (e) {
        debugPrint('Failed to get delivery address: $e');
      }
    }

    return OrderData(
      orderNumber: orderId,
      userId: userId,
      items: items,
      pricing: totals,
      delivery: {
        'option': deliveryProvider.deliveryOption.displayName,
        'fee': deliveryProvider.deliveryOption == DeliveryOption.delivery
            ? deliveryProvider.deliveryFee
            : 0.0,
        'address': deliveryAddress,
      },
      orderType: deliveryProvider.deliveryOption.displayName.toLowerCase(),
      deliveryMethod: deliveryProvider.deliveryOption.displayName.toLowerCase(),
      distanceMiles: deliveryProvider.deliveryDistance,
      payment: {
        'method': _selectedPaymentMethod!.displayName,
        'methodId': _selectedPaymentMethod!.id,
        'status': 'completed',
        'processedAt': nowIso,
        'customerName': customerName,
        'customerEmail': user.email ?? '',
      },
      status: 'received',
      statusHistory: {'received': nowIso},
      createdAt: nowIso,
      updatedAt: nowIso,
    );
  }

  Future<Map<String, dynamic>> _getDeliveryAddressFromProvider(
    DeliveryFeeProvider provider,
  ) async {
    final pos = provider.deliveryLocation!;
    final position = Position(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      floor: null,
      isMocked: false,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );

    final address = await LocationService._getAddressFromCoordinates(position);

    return {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'timestamp': DateTime.now().toIso8601String(),
      'address': address,
    };
  }

  Future<void> _initializePaymentSheet(
    Map<String, dynamic> paymentIntent,
  ) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: paymentIntent['client_secret'],
        merchantDisplayName: PaymentConstants.merchantName,
        style: Theme.of(context).brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        applePay:
            Platform.isIOS && _selectedPaymentMethod == PaymentMethod.applePay
            ? const PaymentSheetApplePay(
                merchantCountryCode: PaymentConstants.merchantCountryCode,
              )
            : null,
        googlePay:
            Platform.isAndroid &&
                _selectedPaymentMethod == PaymentMethod.googlePay
            ? const PaymentSheetGooglePay(
                merchantCountryCode: PaymentConstants.merchantCountryCode,
                testEnv: false,
              )
            : null,
      ),
    );
  }

  bool _shouldRetryPayment(Object error) {
    debugPrint('🔍 Checking if error should be retried: ${error.runtimeType}');

    // Don't retry user-cancelled payments
    if (error is StripeException) {
      final code = error.error.code;
      debugPrint('   Stripe error code: $code');

      // Don't retry these Stripe errors
      if (code == FailureCode.Canceled || code == FailureCode.Failed) {
        debugPrint('   ❌ Not retrying: User cancelled or card failed');
        return false;
      }

      // Retry timeout errors
      if (code == FailureCode.Timeout) {
        debugPrint('   ✅ Will retry: Timeout error');
        return true;
      }

      return false;
    }

    // Retry certain PaymentException codes
    if (error is PaymentException) {
      debugPrint('   Payment exception code: ${error.code}');

      final retryableCodes = [
        'unavailable', // Service temporarily unavailable
        'deadline-exceeded', // Request timed out
      ];

      final shouldRetry =
          error.code != null && retryableCodes.contains(error.code);
      debugPrint(
        '   ${shouldRetry ? '✅ Will retry' : '❌ Not retrying'}: ${error.code}',
      );
      return shouldRetry;
    }

    // Don't retry unknown error types
    debugPrint('   ❌ Not retrying: Unknown error type');
    return false;
  }

  // ===== ERROR HANDLING =====
  Future<void> _handlePaymentError(Object error) async {
    debugPrint('🔥 === HANDLING PAYMENT ERROR ===');
    debugPrint('Error: $error');
    debugPrint('Error type: ${error.runtimeType}');

    if (error is StripeException) {
      debugPrint('🔴 Stripe Error Details:');
      debugPrint('   Code: ${error.error.code}');
      debugPrint('   Message: ${error.error.message}');
      debugPrint('   Type: ${error.error.type}');
      debugPrint('   Decline code: ${error.error.declineCode}');
      _handleStripeError(error);
    } else if (error is PaymentException) {
      debugPrint('🔴 Payment Exception Details:');
      debugPrint('   Message: ${error.message}');
      debugPrint('   Code: ${error.code}');
      debugPrint('   Original error: ${error.originalError}');
      _showErrorSnack(error.message);
    } else {
      debugPrint('🔴 Unknown Error Type: ${error.runtimeType}');
      _showErrorSnack('An unexpected error occurred. Please try again.');
    }

    // Retry logic
    if (_shouldRetryPayment(error) &&
        _retryCount < PaymentConstants.maxRetryAttempts) {
      _retryCount++;
      debugPrint(
        '🔄 Retrying payment (attempt $_retryCount/${PaymentConstants.maxRetryAttempts})',
      );
      await Future.delayed(Duration(seconds: _retryCount * 2));
      if (mounted) {
        setState(() => _paymentState = PaymentState.idle);
        await _processPayment();
      }
    } else {
      debugPrint('❌ Max retries reached or non-retryable error');
      _resetPaymentState();
    }
  }

  void _handleStripeError(StripeException e) {
    final code = e.error.code;
    final message = e.error.message;

    setState(() => _paymentState = PaymentState.cancelled);

    switch (code) {
      case FailureCode.Canceled:
        _showInfoSnack("Payment was cancelled");
        break;
      case FailureCode.Failed:
        _showErrorSnack("Payment failed: ${message ?? 'Unknown error'}");
        break;
      case FailureCode.Timeout:
        _showErrorSnack("Payment timed out. Please try again.");
        break;
      default:
        _showErrorSnack("Payment error: ${message ?? 'Unknown error'}");
    }
  }

  // ===== UI FEEDBACK =====
  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _showSuccessSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ===== DIALOG METHODS =====
  Future<bool> _showPaymentConfirmationDialog(PaymentTotals totals) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('Confirm Payment'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfirmationInfoRow(
                'Payment Method',
                _selectedPaymentMethod!.displayName,
                _selectedPaymentMethod!.icon,
              ),
              _buildConfirmationInfoRow(
                'Delivery Option',
                Provider.of<DeliveryFeeProvider>(
                  context,
                  listen: false,
                ).deliveryOption.displayName,
                Provider.of<DeliveryFeeProvider>(
                  context,
                  listen: false,
                ).deliveryOption.icon,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildConfirmationRow('Subtotal', totals.subtotal),
              _buildConfirmationRow(
                'Tax (${(_taxRate * 100).toStringAsFixed(2)}%)',
                totals.tax,
              ),
              _buildConfirmationRow('Tip', totals.tip),
              if (totals.deliveryFee > 0)
                _buildConfirmationRow('Delivery Fee', totals.deliveryFee),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _buildConfirmationRow('Total', totals.total, isTotal: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget _buildConfirmationInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationRow(
    String label,
    double amount, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
            '\$${amount.toStringAsFixed(2)}',
            style: isTotal
                ? const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.deepOrange,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CartProvider, DeliveryFeeProvider>(
      builder: (context, cartProvider, deliveryProvider, child) {
        final totals = _calculateTotals();
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: isDark ? Colors.black : const Color(0xFFFDF1EC),
          appBar: AppBar(
            backgroundColor: isDark ? Colors.black : Colors.deepOrange,
            title: const Text("Payment", style: TextStyle(color: Colors.white)),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isRestaurantOpen) _buildRestaurantClosedBanner(),
                if (!_isRestaurantOpen)
                  SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                _buildDeliveryOptions(deliveryProvider),
                SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                _buildScheduleSection(isDark),
                SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                _buildOrderSummary(isDark, totals),
                SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                _buildTipSelector(isDark),
                SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                _buildPaymentMethodsSection(isDark),
                SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                _buildPayButton(totals.total),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeliveryOptions(DeliveryFeeProvider deliveryProvider) {
    final bool isDeliveryAvailable = deliveryProvider.deliveryWithinRange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Delivery Option",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: DeliveryOption.values.map((option) {
              final bool isSelected = deliveryProvider.deliveryOption == option;
              final bool isDisabled =
                  option == DeliveryOption.delivery && !isDeliveryAvailable;

              return Expanded(
                child: GestureDetector(
                  onTap: isDisabled
                      ? null
                      : () {
                          deliveryProvider.setDeliveryOption(option);
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.deepOrange : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.deepOrange
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          option.icon,
                          color: isSelected
                              ? Colors.white
                              : isDisabled
                              ? Colors.grey
                              : Colors.black87,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          option.displayName,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isDisabled
                                ? Colors.grey
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (deliveryProvider.deliveryOption == DeliveryOption.delivery)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (deliveryProvider.deliveryLocation != null)
                  Text(
                    'To: ${deliveryProvider.deliveryAddress ?? 'Your Address'}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Delivery Fee: \$${deliveryProvider.deliveryFee.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          if (!isDeliveryAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: const [
                  Icon(Icons.warning, color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "You're too far for delivery. Please choose Pickup.",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(bool isDark, PaymentTotals totals) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Order Summary",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow("Subtotal", totals.subtotal),
            _buildSummaryRow(
              "Tax (${(_taxRate * 100).toStringAsFixed(2)}%)",
              totals.tax,
            ),
            _buildSummaryRow("Tip", totals.tip),
            if (Provider.of<DeliveryFeeProvider>(
                  context,
                  listen: false,
                ).deliveryOption ==
                DeliveryOption.delivery)
              _buildSummaryRow("Delivery Fee", totals.deliveryFee),
            const Divider(height: 24),
            _buildSummaryRow("Total", totals.total, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                : null,
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: isTotal
                ? const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTipSelector(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Rider Tip",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.06,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tipOptions.length + 1,
              itemBuilder: (context, index) {
                if (index == _tipOptions.length) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Custom'),
                      selected: _isCustomTip,
                      onSelected: (selected) {
                        setState(() {
                          _isCustomTip = selected;
                          if (selected) {
                            _selectedTip = 0.0;
                          } else {
                            _customTipController.clear();
                          }
                        });
                      },
                      selectedColor: Colors.deepOrange.withOpacity(0.2),
                      backgroundColor: isDark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      labelStyle: TextStyle(
                        color: _isCustomTip
                            ? Colors.deepOrange
                            : isDark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  );
                }

                final tip = _tipOptions[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tip == 0 ? 'No tip' : '${tip.toInt()}%'),
                    selected: !_isCustomTip && _selectedTip == tip,
                    onSelected: (selected) {
                      setState(() {
                        _isCustomTip = false;
                        _selectedTip = selected ? tip : 0.0;
                        _customTipController.clear();
                      });
                    },
                    selectedColor: Colors.deepOrange.withOpacity(0.2),
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    labelStyle: TextStyle(
                      color: !_isCustomTip && _selectedTip == tip
                          ? Colors.deepOrange
                          : isDark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isCustomTip) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _customTipController,
              validator: _validateCustomTip,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: 'Enter custom tip amount (\$)',
                hintText: '0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
              ),
              onChanged: (value) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Payment Method",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildPaymentMethodOption(PaymentMethod.card, isDark),
              const SizedBox(height: 12),
              if (Platform.isIOS)
                _buildPaymentMethodOption(PaymentMethod.applePay, isDark),
              if (Platform.isAndroid)
                _buildPaymentMethodOption(PaymentMethod.googlePay, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption(PaymentMethod method, bool isDark) {
    final isSelected = _selectedPaymentMethod == method;

    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepOrange.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.deepOrange : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              method.icon,
              color: isSelected
                  ? Colors.deepOrange
                  : isDark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                method.displayName,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.deepOrange),
          ],
        ),
      ),
    );
  }

  Future<String> _customerDisplayName(User user) async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();
      final name = profile?['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return user.email?.split('@').first.split(RegExp(r'[._]')).first ??
        'Customer';
  }

  Future<void> _processScheduledOrderPayment(PaymentTotals totals) async {
    debugPrint('🚀 === SCHEDULED ORDER PAYMENT FLOW STARTED ===');

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw const PaymentException('User not authenticated');
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final deliveryProvider = Provider.of<DeliveryFeeProvider>(
      context,
      listen: false,
    );
    final orderId = OrderNumberGenerator.generate();

    try {
      // Create payment intent for scheduled order — server recomputes the
      // real total from authoritative meal prices, same as regular orders.
      debugPrint('💳 Creating payment intent for scheduled order');
      final paymentIntent = await PaymentService.createPaymentIntent(
        items: cartProvider.items
            .map((item) => {'id': item.id, 'name': item.name, 'quantity': item.quantity})
            .toList(),
        orderType: deliveryProvider.deliveryOption == DeliveryOption.delivery
            ? 'delivery'
            : 'pickup',
        distanceMiles: deliveryProvider.deliveryDistance,
        tipAmount: totals.tip,
        orderId: orderId,
        customerName: user.email ?? 'Customer',
        itemsDescription: cartProvider.items
            .map((item) => '${item.name} x${item.quantity}')
            .join(', '),
      );

      // Initialize and present payment sheet
      await _initializePaymentSheet(paymentIntent);
      await Stripe.instance.presentPaymentSheet();

      debugPrint('✅ Payment completed for scheduled order');

      // Save as scheduled order — built from the server-validated
      // totals/items, not the raw client-computed ones.
      final validatedTotals = PaymentTotals(
        subtotal: paymentIntent['subtotal'] as double,
        tax: paymentIntent['tax'] as double,
        tip: paymentIntent['tip'] as double,
        deliveryFee: paymentIntent['deliveryFee'] as double,
        total: paymentIntent['total'] as double,
      );
      await _saveScheduledOrderWithPayment(
        user.id,
        orderId,
        validatedTotals,
        validatedItems: paymentIntent['items'] as List<dynamic>?,
      );

      cartProvider.clearCart();
      setState(() => _paymentState = PaymentState.completed);

      _showSuccessSnack('Scheduled order payment successful!');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ConfirmationPage(orderId: orderId, isScheduled: true),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Scheduled order payment failed: $e');
      setState(() => _paymentState = PaymentState.failed);
      rethrow;
    }
  }

  Future<void> _saveScheduledOrderWithPayment(
    String userId,
    String orderId,
    PaymentTotals totals, {
    List<dynamic>? validatedItems,
  }) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final deliveryProvider = Provider.of<DeliveryFeeProvider>(
      context,
      listen: false,
    );
    final nowIso = DateTime.now().toIso8601String();

    final cartItems = cartProvider.items;
    final items = List.generate(cartItems.length, (i) {
      final item = cartItems[i];
      final validated = validatedItems != null && i < validatedItems.length
          ? validatedItems[i] as Map<String, dynamic>
          : null;
      return {
        'id': validated?['id'] ?? item.id,
        'name': validated?['name'] ?? item.name,
        'price': validated != null
            ? (validated['price'] as num).toDouble()
            : item.price,
        'quantity': item.quantity,
        'image': item.image,
        'category': item.category,
        'extras': item.extras,
        'instructions': item.instructions,
      };
    });

    Map<String, dynamic>? deliveryAddress;
    if (deliveryProvider.deliveryOption == DeliveryOption.delivery) {
      try {
        deliveryAddress = deliveryProvider.deliveryLocation != null
            ? await _getDeliveryAddressFromProvider(deliveryProvider)
            : await LocationService.getCurrentDeliveryAddress();
      } catch (e) {
        debugPrint('Failed to get delivery address: $e');
      }
    }

    final user = Supabase.instance.client.auth.currentUser!;
    final customerName = await _customerDisplayName(user);

    final orderData = OrderData(
      orderNumber: orderId,
      userId: userId,
      items: items,
      pricing: totals,
      delivery: {
        'option': deliveryProvider.deliveryOption.displayName,
        'fee': deliveryProvider.deliveryOption == DeliveryOption.delivery
            ? deliveryProvider.deliveryFee
            : 0.0,
        'address': deliveryAddress,
      },
      orderType: deliveryProvider.deliveryOption.displayName.toLowerCase(),
      deliveryMethod: deliveryProvider.deliveryOption.displayName.toLowerCase(),
      distanceMiles: deliveryProvider.deliveryDistance,
      payment: {
        'method': _selectedPaymentMethod!.displayName,
        'methodId': _selectedPaymentMethod!.id,
        'status': 'completed',
        'processedAt': nowIso,
        'customerName': customerName,
        'customerEmail': user.email ?? '',
      },
      status: 'scheduled',
      statusHistory: {'scheduled': nowIso},
      createdAt: nowIso,
      updatedAt: nowIso,
    );

    // Same create-order Edge Function as regular orders, just with
    // scheduledFor set — re-validates items/pricing server-side either way.
    try {
      await PaymentService.saveOrder(
        orderData,
        scheduledFor: _scheduledTime!.toIso8601String(),
      );
      debugPrint('✅ Scheduled order saved successfully');
    } catch (e) {
      debugPrint('❌ Failed to save scheduled order: $e');
      throw PaymentException(
        'Failed to save scheduled order',
        originalError: e,
      );
    }
  }

  Widget _buildScheduleSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.deepOrange),
              const SizedBox(width: 8),
              const Text(
                'Schedule Order',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Switch(
                value: _isScheduledOrder || !_isRestaurantOpen,
                onChanged: _isRestaurantOpen
                    ? (value) {
                        setState(() {
                          _isScheduledOrder = value;
                          if (!value) _scheduledTime = null;
                        });
                      }
                    : null,
                activeColor: Colors.deepOrange,
              ),
            ],
          ),
          if (!_isRestaurantOpen) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Text(
                '🏪 Restaurant is currently closed. Orders will be scheduled automatically.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (_isScheduledOrder || !_isRestaurantOpen) ...[
            const SizedBox(height: 12),
            const Text(
              'Select when you want your order to be prepared:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectScheduledTime(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Text(
                      _scheduledTime != null
                          ? DateFormat(
                              'MMM d, yyyy h:mm a',
                            ).format(_scheduledTime!)
                          : 'Select date and time',
                      style: TextStyle(
                        color: _scheduledTime != null ? null : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectScheduledTime() async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: tomorrow,
      firstDate: tomorrow,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 12, minute: 0),
      );

      if (time != null && mounted) {
        setState(() {
          _scheduledTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Widget _buildRestaurantClosedBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.store_mall_directory_outlined,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restaurant Closed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'We are currently closed. Your order will be scheduled for when we reopen.',
                  style: TextStyle(fontSize: 14, color: Colors.red),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Business Hours: Tue-Sat 11:00 AM - 8:00 PM',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton(double total) {
    final deliveryProvider = Provider.of<DeliveryFeeProvider>(
      context,
      listen: false,
    );
    final isDisabled =
        _isProcessing ||
        total < PaymentConstants.minimumPaymentAmount ||
        _selectedPaymentMethod == null ||
        ((_isScheduledOrder || !_isRestaurantOpen) && _scheduledTime == null) ||
        (deliveryProvider.deliveryOption == DeliveryOption.delivery &&
            !deliveryProvider.deliveryAvailable);

    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.07,
      child: ElevatedButton(
        onPressed: isDisabled ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          disabledBackgroundColor: Colors.grey[400],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                (_isScheduledOrder || !_isRestaurantOpen)
                    ? "Schedule Order"
                    : "Pay \$${total.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
