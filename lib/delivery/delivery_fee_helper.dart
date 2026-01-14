import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryCalculator {
  DeliveryCalculator._();

  static const double _restaurantLat = 41.82457;
  static const double _restaurantLon = -72.4978;

  /// Default delivery configuration
  static const double _defaultMaxDistance = 15.0; // miles
  static const double _defaultBaseFee = 3.99;
  static const double _midTierRatePerMile = 0.50;
  static const double _extendedTierBase = 7.49;
  static const double _extendedTierRatePerMile = 0.75;

  /// Distance tier thresholds
  static const double _baseTierMaxDistance = 3.0;
  static const double _midTierMaxDistance = 10.0;

  /// Cache duration for Firestore settings
  static const Duration _cacheExpiration = Duration(minutes: 5);

  /// Earth radius in miles for Haversine formula
  static const double _earthRadiusMiles = 3958.8;

  static Map<String, dynamic>? _cachedSettings;
  static DateTime? _lastFetch;

  static Future<DeliveryFeeResult> calculateDeliveryFee(
    double customerLat,
    double customerLon,
  ) async {
    try {
      final settings = await _getDeliverySettings();
      final distance = await _getDrivingDistance(
        customerLat: customerLat,
        customerLon: customerLon,
      );

      final maxDistance = (settings['deliveryRadius'] ?? _defaultMaxDistance)
          .toDouble();
      final baseFee = (settings['deliveryFee'] ?? _defaultBaseFee).toDouble();

      _logDebug('Distance: $distance mi, Max: $maxDistance mi, Available: ${distance < maxDistance}');

      if (distance >= maxDistance) {
        return DeliveryFeeResult(
          fee: 0.0,
          distance: distance,
          isAvailable: false,
          tier: DeliveryTier.unavailable,
        );
      }

      final (fee, tier) = _calculateFee(distance, baseFee);

      return DeliveryFeeResult(
        fee: double.parse(fee.toStringAsFixed(2)),
        distance: distance,
        isAvailable: true,
        tier: tier,
      );
    } catch (e) {
      _logError('Delivery calculation failed', e);
      return DeliveryFeeResult.error();
    }
  }

  static Future<double> _getDrivingDistance({
    required double customerLat,
    required double customerLon,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('getDrivingDistance');

      final result = await callable.call({
        'customerLat': customerLat,
        'customerLon': customerLon,
      });

      if (result.data == null || result.data['distanceMiles'] == null) {
        throw Exception('Invalid response from cloud function');
      }

      final miles = (result.data['distanceMiles'] as num).toDouble();
      _logDebug('Driving distance: ${miles.toStringAsFixed(2)} mi');

      return miles;
    } catch (e) {
      _logError('Cloud distance failed, using fallback', e);
      return _calculateStraightLineDistance(customerLat, customerLon);
    }
  }

  static double _calculateStraightLineDistance(
    double customerLat,
    double customerLon,
  ) {
    final lat1Rad = _toRadians(_restaurantLat);
    final lat2Rad = _toRadians(customerLat);
    final dLatRad = _toRadians(customerLat - _restaurantLat);
    final dLonRad = _toRadians(customerLon - _restaurantLon);

    final a =
        sin(dLatRad / 2) * sin(dLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLonRad / 2) * sin(dLonRad / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = _earthRadiusMiles * c;

    _logDebug('Straight-line distance: ${distance.toStringAsFixed(2)} mi');
    return distance;
  }

  static (double fee, DeliveryTier tier) _calculateFee(
    double distance,
    double baseFee,
  ) {
    if (distance <= _baseTierMaxDistance) {
      return (baseFee, DeliveryTier.base);
    } else if (distance <= _midTierMaxDistance) {
      final fee =
          baseFee + (distance - _baseTierMaxDistance) * _midTierRatePerMile;
      return (fee, DeliveryTier.mid);
    } else {
      final fee =
          _extendedTierBase +
          (distance - _midTierMaxDistance) * _extendedTierRatePerMile;
      return (fee, DeliveryTier.extended);
    }
  }

  static Future<Map<String, dynamic>> _getDeliverySettings() async {
    if (_isCacheValid()) {
      return _cachedSettings!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('restaurant')
          .get();

      if (doc.exists && doc.data() != null) {
        _cachedSettings = doc.data()!;
        _lastFetch = DateTime.now();
        return _cachedSettings!;
      }
    } catch (e) {
      _logError('Firestore settings fetch failed', e);
    }

    // Return defaults if Firestore unavailable
    return {
      'deliveryRadius': _defaultMaxDistance,
      'deliveryFee': _defaultBaseFee,
    };
  }

  /// Checks if cached settings are still valid
  static bool _isCacheValid() {
    return _cachedSettings != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheExpiration;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  static void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('DeliveryCalculator: $message');
    }
  }

  static void _logError(String message, Object error) {
    debugPrint('DeliveryCalculator: $message - $error');
  }

  static void clearCache() {
    _cachedSettings = null;
    _lastFetch = null;
    _logDebug('Cache cleared');
  }
}

class DeliveryFeeResult {
  final double fee;
  final double distance;
  final bool isAvailable;
  final DeliveryTier tier;
  final bool hasError;

  const DeliveryFeeResult({
    required this.fee,
    required this.distance,
    required this.isAvailable,
    required this.tier,
    this.hasError = false,
  });

  factory DeliveryFeeResult.error() => const DeliveryFeeResult(
    fee: 0,
    distance: 0,
    isAvailable: false,
    tier: DeliveryTier.unavailable,
    hasError: true,
  );

  @override
  String toString() =>
      'DeliveryFeeResult('
      'fee: \$$fee, '
      'distance: ${distance.toStringAsFixed(2)} mi, '
      'available: $isAvailable, '
      'tier: ${tier.name})';
}

enum DeliveryTier { base, mid, extended, unavailable }
