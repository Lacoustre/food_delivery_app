import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:african_cuisine/payment/payment_page.dart'; // For DeliveryOption enum
import 'package:african_cuisine/delivery/delivery_fee_helper.dart';
import 'package:geocoding/geocoding.dart';

class DeliveryFeeProvider extends ChangeNotifier {
  double _deliveryFee = 0.0;
  bool _deliveryAvailable = true;
  bool _deliveryWithinRange = true; // Added this property
  DeliveryOption _deliveryOption = DeliveryOption.delivery;
  Position? _deliveryLocation;
  String? _deliveryAddress; // Added this property

  // Getters
  double get deliveryFee => _deliveryFee;
  bool get deliveryAvailable => _deliveryAvailable;
  bool get deliveryWithinRange => _deliveryWithinRange; // Added getter
  DeliveryOption get deliveryOption => _deliveryOption;
  Position? get deliveryLocation => _deliveryLocation;
  String? get deliveryAddress => _deliveryAddress; // Added getter

  Future<void> updateDeliveryFee(Position position) async {
    try {
      final result = DeliveryCalculator.calculateDeliveryFee(
        position.latitude,
        position.longitude,
      );

      _deliveryWithinRange = result.isAvailable;

      if (!result.isAvailable) {
        _deliveryAvailable = false;
        _deliveryOption = DeliveryOption.pickup;
        _deliveryFee = 0.0;
      } else {
        _deliveryAvailable = true;
        _deliveryOption = DeliveryOption.delivery;
        _deliveryFee = result.fee;
        _deliveryLocation = position;
        _deliveryAddress = await _getAddressFromPosition(position);
      }
      notifyListeners();
    } catch (e) {
      _deliveryAvailable = false;
      _deliveryWithinRange = false;
      _deliveryOption = DeliveryOption.pickup;
      _deliveryFee = 0.0;
      notifyListeners();
      rethrow;
    }
  }

  Future<String?> _getAddressFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return [
          place.street,
          place.locality,
          place.administrativeArea,
          place.postalCode,
        ].where((part) => part != null && part.isNotEmpty).join(', ');
      }
      return null;
    } catch (e) {
      debugPrint('Error getting address: $e');
      return null;
    }
  }

  void setDeliveryOption(DeliveryOption option) {
    if (option == DeliveryOption.delivery && !_deliveryAvailable) {
      throw StateError('Delivery is not available for this location');
    }
    _deliveryOption = option;
    notifyListeners();
  }
}
