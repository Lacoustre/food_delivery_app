import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerPage extends StatefulWidget {
  final LatLng? initialPosition;

  const MapPickerPage({super.key, this.initialPosition});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  GoogleMapController? _mapController;
  LatLng? _pickedLocation;

  @override
  void initState() {
    super.initState();
    _determineInitialPosition();
  }

  Future<void> _determineInitialPosition() async {
    if (widget.initialPosition != null) {
      setState(() {
        _pickedLocation = widget.initialPosition;
      });
      return;
    }

    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // Use default location if permission denied
        setState(() {
          _pickedLocation = const LatLng(41.6032, -73.0877);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Using default location. Tap to select your location.")),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _pickedLocation = latLng;
      });

      // Animate camera if controller is ready
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
    } catch (e) {
      debugPrint("Location error: $e");
      // Use default location on error
      setState(() {
        _pickedLocation = const LatLng(41.6032, -73.0877);
      });
    }
  }

  void _onTap(LatLng position) {
    setState(() => _pickedLocation = position);
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  void _onConfirm() {
    if (_pickedLocation != null) {
      Navigator.pop(context, _pickedLocation);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please pick a location.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Location"),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: _pickedLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pickedLocation!,
                    zoom: 16,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;

                    // Animate to picked location
                    if (_pickedLocation != null) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(_pickedLocation!, 16),
                      );
                    }
                  },
                  onTap: _onTap,
                  markers: _pickedLocation != null
                      ? {
                          Marker(
                            markerId: const MarkerId('picked-location'),
                            position: _pickedLocation!,
                            infoWindow: const InfoWindow(
                              title: 'Selected Location',
                              snippet: 'Tap confirm to use this location',
                            ),
                          ),
                        }
                      : {},
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Tap anywhere on the map to select your delivery location',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onConfirm,
        icon: const Icon(Icons.check),
        label: const Text("Confirm Location"),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }
}
