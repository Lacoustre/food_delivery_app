import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:african_cuisine/payment/payment_page.dart';
import 'package:african_cuisine/delivery/delivery_fee_helper.dart';

class DeliveryFeeProvider extends ChangeNotifier {
  double _deliveryFee = 0.0;
  double _deliveryDistance = 0.0;
  bool _deliveryAvailable = true;
  bool _deliveryWithinRange = true;
  bool _isCalculating = false;
  DeliveryOption _deliveryOption = DeliveryOption.delivery;
  Position? _deliveryLocation;
  String? _deliveryAddress;
  String? _lastError;
  DeliveryTier _deliveryTier = DeliveryTier.base;

  double get deliveryFee => _deliveryFee;
  double get deliveryDistance => _deliveryDistance;
  bool get deliveryAvailable => _deliveryAvailable;
  bool get deliveryWithinRange => _deliveryWithinRange;
  bool get isCalculating => _isCalculating;
  DeliveryOption get deliveryOption => _deliveryOption;
  Position? get deliveryLocation => _deliveryLocation;
  String? get deliveryAddress => _deliveryAddress;
  String? get lastError => _lastError;
  DeliveryTier get deliveryTier => _deliveryTier;

  String get deliveryInfo {
    if (!_deliveryAvailable) {
      return 'Delivery not available';
    }
    if (_deliveryDistance == 0) {
      return 'Enter delivery address';
    }
    return '${_deliveryDistance.toStringAsFixed(1)} mi • \$${_deliveryFee.toStringAsFixed(2)}';
  }

  Future<void> updateDeliveryFee(Position position) async {
    _isCalculating = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await DeliveryCalculator.calculateDeliveryFee(
        position.latitude,
        position.longitude,
      );

      if (result.hasError) {
        throw Exception('Failed to calculate delivery distance');
      }

      _deliveryDistance = result.distance;
      _deliveryWithinRange = result.isAvailable;
      _deliveryTier = result.tier;

      if (!result.isAvailable) {
        _deliveryAvailable = false;
        _deliveryOption = DeliveryOption.pickup;
        _deliveryFee = 0.0;
        _lastError =
            'Location outside delivery area (${result.distance.toStringAsFixed(1)} miles)';
      } else {
        _deliveryAvailable = true;
        _deliveryFee = result.fee;
        _deliveryLocation = position;

        _getAddressFromPosition(position).then((address) {
          if (address != null) {
            _deliveryAddress = address;
            notifyListeners();
          }
        });
      }
    } catch (e) {
      _deliveryAvailable = false;
      _deliveryWithinRange = false;
      _deliveryOption = DeliveryOption.pickup;
      _deliveryFee = 0.0;
      _deliveryDistance = 0.0;
      _lastError = 'Unable to calculate delivery fee. Please try again.';

      debugPrint(' Delivery fee calculation failed: $e');
    } finally {
      _isCalculating = false;
      notifyListeners();
    }
  }

  void setDeliveryOption(DeliveryOption option) {
    if (option == DeliveryOption.delivery) {
      if (!_deliveryAvailable) {
        _lastError = 'Delivery is not available for this location';
        notifyListeners();
        return;
      }
      if (_deliveryLocation == null) {
        _lastError = 'Please select a delivery address first';
        notifyListeners();
        return;
      }
    }

    _deliveryOption = option;
    _lastError = null;
    notifyListeners();
  }

  void clearDeliveryLocation() {
    _deliveryLocation = null;
    _deliveryAddress = null;
    _deliveryFee = 0.0;
    _deliveryDistance = 0.0;
    _deliveryOption = DeliveryOption.pickup;
    _deliveryAvailable = true;
    _deliveryWithinRange = true;
    _lastError = null;
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  Future<String?> _getAddressFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final addressParts = [
        place.street,
        place.locality,
        place.administrativeArea,
        place.postalCode,
      ].where((value) => value != null && value.isNotEmpty);

      return addressParts.join(', ');
    } catch (e) {
      debugPrint(' Error resolving address: $e');
      return null;
    }
  }

  /// Returns formatted debug info
  String get debugInfo =>
      '''
Delivery Fee Provider State:
  - Fee: \$$_deliveryFee
  - Distance: $_deliveryDistance mi
  - Tier: ${_deliveryTier.name}
  - Available: $_deliveryAvailable
  - Within Range: $_deliveryWithinRange
  - Option: ${_deliveryOption.name}
  - Calculating: $_isCalculating
  - Location: ${_deliveryLocation != null ? '(${_deliveryLocation!.latitude.toStringAsFixed(4)}, ${_deliveryLocation!.longitude.toStringAsFixed(4)})' : 'null'}
  - Address: ${_deliveryAddress ?? 'null'}
  - Error: ${_lastError ?? 'none'}
''';

  /// Prints current state to console
  void printDebugInfo() {
    debugPrint(' $debugInfo');
  }
}
