import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:african_cuisine/payment/payment_page.dart';
import 'package:african_cuisine/delivery/delivery_fee_helper.dart';

class DeliveryFeeProvider extends ChangeNotifier {
  double _deliveryFee = 0.0;
  int? _deliveryEtaMinutes;
  bool _deliveryAvailable = true;
  bool _deliveryWithinRange = true;
  bool _isCalculating = false;
  DeliveryOption _deliveryOption = DeliveryOption.delivery;
  Position? _deliveryLocation;
  String? _deliveryAddress;
  String? _lastError;

  double get deliveryFee => _deliveryFee;
  int? get deliveryEtaMinutes => _deliveryEtaMinutes;
  bool get deliveryAvailable => _deliveryAvailable;
  bool get deliveryWithinRange => _deliveryWithinRange;
  bool get isCalculating => _isCalculating;
  DeliveryOption get deliveryOption => _deliveryOption;
  Position? get deliveryLocation => _deliveryLocation;
  String? get deliveryAddress => _deliveryAddress;
  String? get lastError => _lastError;

  String get deliveryInfo {
    if (!_deliveryAvailable) {
      return 'Delivery not available';
    }
    if (_deliveryAddress == null || _deliveryFee == 0) {
      return 'Enter delivery address';
    }
    final eta = _deliveryEtaMinutes;
    final fee = '\$${_deliveryFee.toStringAsFixed(2)}';
    return eta != null ? '~$eta min • $fee' : fee;
  }

  Future<void> updateDeliveryFee(Position position) async {
    _isCalculating = true;
    _lastError = null;
    notifyListeners();

    try {
      // Uber prices by address, so it has to be resolved before quoting —
      // this used to run fire-and-forget after the fee was computed.
      final address = await _getAddressFromPosition(position);
      if (address == null) {
        throw Exception('Could not resolve delivery address');
      }
      _deliveryAddress = address;
      _deliveryLocation = position;

      final result = await DeliveryCalculator.calculateDeliveryFee(address);

      if (result.hasError) {
        throw Exception(result.reason ?? 'Failed to price delivery');
      }

      _deliveryWithinRange = result.isAvailable;
      _deliveryEtaMinutes = result.etaMinutes;

      if (!result.isAvailable) {
        _deliveryAvailable = false;
        _deliveryOption = DeliveryOption.pickup;
        _deliveryFee = 0.0;
        _lastError = result.reason ?? 'Delivery not available to that address';
      } else {
        _deliveryAvailable = true;
        _deliveryFee = result.fee;
      }
    } catch (e) {
      _deliveryAvailable = false;
      _deliveryWithinRange = false;
      _deliveryOption = DeliveryOption.pickup;
      _deliveryFee = 0.0;
      _deliveryEtaMinutes = null;
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
    _deliveryEtaMinutes = null;
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
  - ETA: ${_deliveryEtaMinutes ?? "-"} min
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
