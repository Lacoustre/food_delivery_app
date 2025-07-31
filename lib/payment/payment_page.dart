import 'dart:io';
import 'package:african_cuisine/orders/order_number_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:african_cuisine/provider/cart_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:african_cuisine/payment/confirmation_page.dart';
import 'package:african_cuisine/delivery/delivery_fee_provider.dart';

// ===== CONSTANTS =====
class PaymentConstants {
  static const double taxRate = 0.0735;
  static const double minimumPaymentAmount = 0.50;
  static const double maxDeliveryDistance = 15.0;
  static const double maxTipAmount = 999.99;
  static const int paymentIntentTimeoutSeconds = 30;
  static const int maxRetryAttempts = 3;
  static const String merchantName = 'Taste of African Cuisine';
  static const String merchantCountryCode = 'US';
  static const String defaultCurrency = 'USD';

  static const List<String> validOrderStatuses = [
    'received',
    'preparing',
    'out for delivery',
    'delivered',
    'cancelled',
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
    };
  }
}

// ===== SERVICES =====
class PaymentService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  // ignore: unused_field
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String orderId,
    required String customerName,
    required String itemsDescription,
  }) async {
    debugPrint('🚀 PaymentService.createPaymentIntent called');
    debugPrint('   Amount: \$${amount.toStringAsFixed(2)}');
    debugPrint('   Order ID: $orderId');
    debugPrint('   Customer: $customerName');

    try {
      // Authentication check
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No authenticated user found');
        throw const PaymentException(
          'User not authenticated',
          code: 'unauthenticated',
        );
      }

      debugPrint('✅ User authenticated: ${user.uid}');
      debugPrint('   Email: ${user.email}');
      debugPrint('   Display Name: ${user.displayName}');

      // Token refresh
      try {
        final token = await user.getIdToken(true);
        debugPrint('✅ Token refreshed, length: ${token!.length}');
      } catch (tokenError) {
        debugPrint('❌ Token refresh failed: $tokenError');
        throw PaymentException(
          'Authentication token refresh failed',
          code: 'unauthenticated',
          originalError: tokenError,
        );
      }

      // Prepare function call
      final callable = _functions.httpsCallable('createPaymentIntent');

      final requestData = {
        'amount': amount, // Send as dollars
        'orderId': orderId.trim(),
        'customerName':
            (customerName.isNotEmpty
                    ? customerName
                    : user.displayName ?? user.email ?? 'Customer')
                .trim(),
        'currency': PaymentConstants.defaultCurrency.toLowerCase(),
      };

      debugPrint('📤 Calling Cloud Function with data:');
      debugPrint('   ${requestData.toString()}');

      // Make the call with timeout
      final response = await callable
          .call(requestData)
          .timeout(
            const Duration(
              seconds: PaymentConstants.paymentIntentTimeoutSeconds,
            ),
            onTimeout: () {
              debugPrint('⏰ Cloud Function call timed out');
              throw const PaymentException(
                'Payment request timed out',
                code: 'deadline-exceeded',
              );
            },
          );

      debugPrint('📦 Cloud Function response received');
      debugPrint('   Response type: ${response.runtimeType}');
      debugPrint('   Response data type: ${response.data.runtimeType}');

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
        'amount': amount,
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Firebase Functions Exception:');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Details: ${e.details}');

      // Log additional details if available
      if (e.details != null) {
        debugPrint('   Details type: ${e.details.runtimeType}');
        if (e.details is Map) {
          final details = e.details as Map;
          for (final entry in details.entries) {
            debugPrint('     ${entry.key}: ${entry.value}');
          }
        }
      }

      throw PaymentException(
        _getFirebaseFunctionErrorMessage(e),
        code: e.code,
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

  static String _getFirebaseFunctionErrorMessage(FirebaseFunctionsException e) {
    debugPrint('🔍 Processing Firebase Function error: ${e.code}');

    switch (e.code) {
      case 'invalid-argument':
        return 'Invalid payment details: ${e.message ?? "Please check your information"}';
      case 'permission-denied':
        return 'Payment authorization failed. Please try again.';
      case 'deadline-exceeded':
        return 'Payment request timed out. Please try again.';
      case 'unavailable':
        return 'Payment service is temporarily unavailable. Please try again later.';
      case 'unauthenticated':
        return 'Please sign in to complete your payment.';
      case 'internal':
        // Try to extract more specific error from details
        if (e.details != null && e.details is Map) {
          final details = e.details as Map;
          if (details.containsKey('stripeError')) {
            return 'Payment error: ${e.message ?? "Card processing failed"}';
          }
        }
        return 'Payment service error: ${e.message ?? "Please try again"}';
      case 'not-found':
        return 'Payment service configuration error. Please contact support.';
      case 'already-exists':
        return 'Duplicate payment request. Please try with a new order.';
      case 'resource-exhausted':
        return 'Payment service is busy. Please try again in a moment.';
      case 'failed-precondition':
        return 'Payment cannot be processed at this time.';
      case 'aborted':
        return 'Payment was interrupted. Please try again.';
      case 'out-of-range':
        return 'Payment amount is out of acceptable range.';
      case 'unimplemented':
        return 'Payment method not supported.';
      case 'data-loss':
        return 'Payment data error. Please try again.';
      default:
        debugPrint('⚠️ Unknown Firebase Function error code: ${e.code}');
        return e.message ?? 'Payment service error occurred. Please try again.';
    }
  }

  // Rest of your existing saveOrder method...
  static Future<void> saveOrder(OrderData orderData) async {
    debugPrint('💾 Saving order: ${orderData.orderNumber}');

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No authenticated user for order save');
        throw const PaymentException(
          'User not authenticated',
          code: 'unauthenticated',
        );
      }

      if (orderData.userId != currentUser.uid) {
        debugPrint('❌ User ID mismatch in order save');
        debugPrint('   Order userId: ${orderData.userId}');
        debugPrint('   Auth UID: ${currentUser.uid}');
        throw const PaymentException('User ID mismatch');
      }

      // Refresh token before calling function
      await currentUser.getIdToken(true);
      debugPrint('✅ Token refreshed for order save');

      final callable = _functions.httpsCallable('createOrder');
      final response = await callable.call(orderData.toFirestore());

      debugPrint('✅ Order saved successfully: ${response.data}');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Error saving order via Cloud Function:');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Message: ${e.message}');

      if (e.code == 'unauthenticated') {
        await FirebaseAuth.instance.signOut();
      }

      throw PaymentException(
        _getFirebaseFunctionErrorMessage(e),
        code: e.code,
        originalError: e,
      );
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
        'timestamp': FieldValue.serverTimestamp(),
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _customTipController.removeListener(_onCustomTipChanged);
    _customTipController.dispose();
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
    final tax = subtotal * PaymentConstants.taxRate;

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
    debugPrint('🚀 === PAYMENT FLOW STARTED ===');
    debugPrint('💰 Payment totals:');
    debugPrint('   Subtotal: \$${totals.subtotal.toStringAsFixed(2)}');
    debugPrint('   Tax: \$${totals.tax.toStringAsFixed(2)}');
    debugPrint('   Tip: \$${totals.tip.toStringAsFixed(2)}');
    debugPrint('   Delivery: \$${totals.deliveryFee.toStringAsFixed(2)}');
    debugPrint('   TOTAL: \$${totals.total.toStringAsFixed(2)}');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ No authenticated user');
      throw const PaymentException('User not authenticated');
    }

    debugPrint('👤 User details:');
    debugPrint('   UID: ${user.uid}');
    debugPrint('   Email: ${user.email ?? 'No email'}');
    debugPrint('   Display Name: ${user.displayName ?? 'No display name'}');
    debugPrint('   Email Verified: ${user.emailVerified}');

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final orderId = OrderNumberGenerator.generate();

    debugPrint('🛒 Cart details:');
    debugPrint('   Items count: ${cartProvider.items.length}');
    debugPrint('   Order ID: $orderId');

    try {
      // Create payment intent
      debugPrint('💳 === CREATING PAYMENT INTENT ===');
      final paymentIntent = await PaymentService.createPaymentIntent(
        amount: totals.total,
        orderId: orderId,
        customerName: user.displayName ?? user.email ?? 'Customer',
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
      debugPrint('   Amount: ${paymentIntent['amount']}');

      // Initialize payment sheet
      debugPrint('📱 === INITIALIZING PAYMENT SHEET ===');
      await _initializePaymentSheet(paymentIntent);
      debugPrint('✅ Payment sheet initialized');

      // Present payment sheet
      debugPrint('📱 === PRESENTING PAYMENT SHEET ===');
      await Stripe.instance.presentPaymentSheet();
      debugPrint('✅ Payment sheet completed successfully');

      // Save order
      debugPrint('💾 === SAVING ORDER ===');
      final orderData = await _createOrderData(user.uid, orderId, totals);
      await PaymentService.saveOrder(orderData);
      debugPrint('✅ Order saved successfully');

      // Cleanup and navigation
      cartProvider.clearCart();
      setState(() => _paymentState = PaymentState.completed);

      _showSuccessSnack("Payment successful!");

      if (mounted) {
        debugPrint('🎉 === PAYMENT COMPLETED - NAVIGATING ===');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ConfirmationPage(orderId: orderId)),
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
    PaymentTotals totals,
  ) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final deliveryProvider = Provider.of<DeliveryFeeProvider>(
      context,
      listen: false,
    );
    final nowIso = DateTime.now().toIso8601String();

    final items = cartProvider.items
        .map(
          (item) => {
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
            'image': item.image,
            'category': item.category,
            'extras': item.extras,
            'instructions': item.instructions,
          },
        )
        .toList();

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
      payment: {
        'method': _selectedPaymentMethod!.displayName,
        'methodId': _selectedPaymentMethod!.id,
        'status': 'completed',
        'processedAt': nowIso,
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
      'timestamp': FieldValue.serverTimestamp(),
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
                testEnv: true,
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
        'internal', // Internal server error (might be temporary)
        'resource-exhausted', // Rate limiting
        'aborted', // Request was aborted
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
                'Tax (${(PaymentConstants.taxRate * 100).toStringAsFixed(2)}%)',
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDeliveryOptions(deliveryProvider),
                const SizedBox(height: 20),
                _buildOrderSummary(isDark, totals),
                const SizedBox(height: 20),
                _buildTipSelector(isDark),
                const SizedBox(height: 20),
                _buildPaymentMethodsSection(isDark),
                const SizedBox(height: 20),
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
              "Tax (${(PaymentConstants.taxRate * 100).toStringAsFixed(2)}%)",
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
            height: 50,
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

  Widget _buildPayButton(double total) {
    final deliveryProvider = Provider.of<DeliveryFeeProvider>(
      context,
      listen: false,
    );
    final isDisabled =
        _isProcessing ||
        total < PaymentConstants.minimumPaymentAmount ||
        _selectedPaymentMethod == null ||
        (deliveryProvider.deliveryOption == DeliveryOption.delivery &&
            !deliveryProvider.deliveryAvailable);

    return SizedBox(
      width: double.infinity,
      height: 56,
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
                "Pay \$${total.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
