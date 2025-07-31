import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationSelectorBar extends StatefulWidget {
  final String currentLocation;
  final bool isManual;
  final Function(String newLocation, bool isManual, Position? position)
  onLocationUpdated;
  final Function(double lat, double lon)? onCoordinatesUpdated;

  const LocationSelectorBar({
    super.key,
    required this.currentLocation,
    required this.isManual,
    required this.onLocationUpdated,
    this.onCoordinatesUpdated,
  });

  @override
  State<LocationSelectorBar> createState() => _LocationSelectorBarState();
}

class _LocationSelectorBarState extends State<LocationSelectorBar> {
  bool _isRefreshing = false;
  Position? _currentPosition;

  Future<void> _useCurrentLocation() async {
    setState(() => _isRefreshing = true);
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception("Location permission denied");
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final location = placemarks.isNotEmpty
          ? _formatAddressFromPlacemark(placemarks.first)
          : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      setState(() => _currentPosition = position);
      widget.onLocationUpdated(location, false, position);

      // Notify about coordinates update if callback exists
      widget.onCoordinatesUpdated?.call(position.latitude, position.longitude);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  String _formatAddressFromPlacemark(Placemark placemark) {
    final street = placemark.street?.trim() ?? '';
    final city = placemark.locality?.trim() ?? '';
    final parts = [if (street.isNotEmpty) street, if (city.isNotEmpty) city];
    return parts.join(', ');
  }

  void _editLocationManually() async {
    final controller = TextEditingController(text: widget.currentLocation);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '📍 Edit Delivery Address',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'e.g. 123 Main St, City',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use Current'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _useCurrentLocation();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                      ),
                      onPressed: () async {
                        final input = controller.text.trim();
                        if (input.isEmpty) return;

                        try {
                          final locations = await locationFromAddress(input);
                          if (locations.isEmpty) {
                            throw Exception("Address not found");
                          }

                          final placemarks = await placemarkFromCoordinates(
                            locations.first.latitude,
                            locations.first.longitude,
                          );

                          final formatted = _formatAddressFromPlacemark(
                            placemarks.first,
                          );

                          final position = Position(
                            latitude: locations.first.latitude,
                            longitude: locations.first.longitude,
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

                          setState(() => _currentPosition = position);
                          widget.onCoordinatesUpdated?.call(
                            position.latitude,
                            position.longitude,
                          );

                          Navigator.pop(ctx, formatted);
                        } catch (e) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );

    if (result != null && result.isNotEmpty) {
      widget.onLocationUpdated(result, true, _currentPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _editLocationManually,
      child: Container(
        height: 72,
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on,
              color: widget.isManual ? Colors.blue : Colors.deepOrange,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Delivery Address',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.currentLocation,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      height: 1.25,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_isRefreshing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.my_location,
                  color: Colors.deepOrange,
                  size: 24,
                ),
                onPressed: _useCurrentLocation,
                tooltip: 'Use Current Location',
              ),
          ],
        ),
      ),
    );
  }
}
