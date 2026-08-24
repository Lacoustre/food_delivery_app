import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Delivery pricing is pass-through: Uber quotes the delivery and the customer
/// is charged exactly that. There is no distance tier table and no driving
/// distance lookup any more — the `quote-delivery` edge function wraps Uber's
/// delivery_quotes endpoint.
///
/// This value is for display only. create-payment-intent re-quotes server-side,
/// so what is actually charged never depends on the client.
class DeliveryCalculator {
  DeliveryCalculator._();

  static void _logDebug(String message) {
    if (kDebugMode) debugPrint('🚚 $message');
  }

  static void _logError(String message, Object error) {
    if (kDebugMode) debugPrint('❌ $message: $error');
  }

  /// Ask Uber what it will cost to deliver to [address].
  ///
  /// [scheduledFor] is an ISO-8601 pickup time for scheduled orders; Uber
  /// accepts these up to 30 days out. Quotes expire after 15 minutes, so this
  /// is re-quoted at checkout and again at dispatch.
  static Future<DeliveryFeeResult> calculateDeliveryFee(
    String address, {
    String? scheduledFor,
    double? subtotal,
  }) async {
    if (address.trim().isEmpty) {
      return DeliveryFeeResult.unavailable('Enter a delivery address');
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'quote-delivery',
        body: {
          'dropoffAddress': address.trim(),
          if (scheduledFor != null) 'scheduledFor': scheduledFor,
          if (subtotal != null) 'subtotal': subtotal,
        },
      );

      final data = response.data;
      if (data is Map && data['error'] != null) {
        // Uber declining is a real answer — usually out of range or an
        // address it can't resolve. Don't invent a fee.
        return DeliveryFeeResult.unavailable(data['error'].toString());
      }
      if (data is! Map || data['fee'] is! num) {
        throw Exception('Malformed quote response');
      }

      final fee = (data['fee'] as num).toDouble();
      final eta = (data['durationMinutes'] as num?)?.toInt();
      _logDebug('Uber quote: \$${fee.toStringAsFixed(2)}'
          '${eta != null ? ', ~$eta min' : ''}');

      return DeliveryFeeResult(
        fee: double.parse(fee.toStringAsFixed(2)),
        isAvailable: true,
        etaMinutes: eta,
        quoteId: data['quoteId'] as String?,
      );
    } catch (e) {
      _logError('Delivery quote failed', e);
      return DeliveryFeeResult.error();
    }
  }
}

class DeliveryFeeResult {
  final double fee;
  final bool isAvailable;
  final int? etaMinutes;
  final String? quoteId;

  /// Why delivery isn't available, when [isAvailable] is false and this isn't
  /// an outright failure. Safe to show to the customer.
  final String? reason;

  final bool hasError;

  const DeliveryFeeResult({
    required this.fee,
    required this.isAvailable,
    this.etaMinutes,
    this.quoteId,
    this.reason,
    this.hasError = false,
  });

  factory DeliveryFeeResult.unavailable(String reason) => DeliveryFeeResult(
    fee: 0,
    isAvailable: false,
    reason: reason,
  );

  factory DeliveryFeeResult.error() => const DeliveryFeeResult(
    fee: 0,
    isAvailable: false,
    reason: 'Unable to price delivery right now. Please try again.',
    hasError: true,
  );

  @override
  String toString() =>
      'DeliveryFeeResult(fee: \$$fee, available: $isAvailable, '
      'eta: ${etaMinutes ?? "-"} min)';
}
