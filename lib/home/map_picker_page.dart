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
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission is required.")),
        );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please pick a location.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pick Location")),
      body: _pickedLocation == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
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
                      ),
                    }
                  : {},
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onConfirm,
        icon: const Icon(Icons.check),
        label: const Text("Confirm"),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }
}
