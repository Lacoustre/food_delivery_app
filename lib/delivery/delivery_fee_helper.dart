import 'dart:math';
import 'package:flutter/foundation.dart';

class DeliveryCalculator {
  // Restaurant coordinates (Farmington Valley, CT)
  static const double restaurantLat = 41.8323;
  static const double restaurantLon = -72.500336;

  // Delivery configuration
  static const double maxDeliveryDistance = 12.0; // miles
  static const double baseFee = 3.99;
  static const double midTierRatePerMile = 0.50; // $0.50/mile beyond 3 miles
  static const double extendedTierBase = 7.49;
  static const double extendedTierRatePerMile =
      0.75; // $0.75/mile beyond 10 miles

  /// Enhanced distance calculation with validation
  static double calculateDistance(double customerLat, double customerLon) {
    _validateCoordinates(customerLat, customerLon);

    const R = 3958.8; // Earth radius in miles
    final dLat = _degToRad(customerLat - restaurantLat);
    final dLon = _degToRad(customerLon - restaurantLon);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(restaurantLat)) *
            cos(_degToRad(customerLat)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = R * c;

    if (kDebugMode) {
      debugPrint('''
      🗺️ Distance Calculation:
      Restaurant: ($restaurantLat, $restaurantLon)
      Customer: ($customerLat, $customerLon)
      Distance: ${distance.toStringAsFixed(2)} miles
      ''');
    }

    return distance;
  }

  static void _validateCoordinates(double lat, double lon) {
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      throw ArgumentError('Invalid coordinates ($lat, $lon)');
    }
  }

  static double _degToRad(double degree) => degree * pi / 180;

  /// Calculates delivery fee with detailed breakdown
  static DeliveryFeeResult calculateDeliveryFee(
    double customerLat,
    double customerLon,
  ) {
    try {
      final distance = calculateDistance(customerLat, customerLon);
      double fee = 0.0;
      String tier = '';

      if (distance >= maxDeliveryDistance) {
        tier = 'unavailable';
        if (kDebugMode) {
          debugPrint(
            '🚫 Delivery unavailable (${distance.toStringAsFixed(2)} miles)',
          );
        }
      } else if (distance <= 3) {
        fee = baseFee;
        tier = 'base';
        if (kDebugMode) {
          debugPrint('💰 Base fee: \$${fee.toStringAsFixed(2)} (≤3 miles)');
        }
      } else if (distance <= 10) {
        fee = baseFee + (distance - 3) * midTierRatePerMile;
        tier = 'mid';
        if (kDebugMode) {
          debugPrint(
            '💰 Mid-tier fee: \$${fee.toStringAsFixed(2)} (3-10 miles)',
          );
        }
      } else {
        fee = extendedTierBase + (distance - 10) * extendedTierRatePerMile;
        tier = 'extended';
        if (kDebugMode) {
          debugPrint(
            '💰 Extended fee: \$${fee.toStringAsFixed(2)} (10-12 miles)',
          );
        }
      }

      return DeliveryFeeResult(
        fee: fee,
        distance: distance,
        isAvailable: distance < maxDeliveryDistance,
        tier: tier,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Delivery calculation error: $e');
      }
      return DeliveryFeeResult.error();
    }
  }
}

class DeliveryFeeResult {
  final double fee;
  final double distance;
  final bool isAvailable;
  final String tier; // 'base', 'mid', 'extended', or 'unavailable'
  final bool hasError;

  DeliveryFeeResult({
    required this.fee,
    required this.distance,
    required this.isAvailable,
    required this.tier,
    this.hasError = false,
  });

  factory DeliveryFeeResult.error() => DeliveryFeeResult(
    fee: 0.0,
    distance: 0.0,
    isAvailable: false,
    tier: 'unavailable',
    hasError: true,
  );

  @override
  String toString() {
    return 'DeliveryFeeResult(\n'
        '  fee: \$${fee.toStringAsFixed(2)},\n'
        '  distance: ${distance.toStringAsFixed(2)} miles,\n'
        '  isAvailable: $isAvailable,\n'
        '  tier: $tier,\n'
        '  hasError: $hasError\n'
        ')';
  }
}
