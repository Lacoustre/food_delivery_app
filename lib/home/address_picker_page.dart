import 'dart:async';
import 'package:flutter/material.dart';
import 'package:african_cuisine/services/places_service.dart';

/// What the picker hands back: a delivery address plus its coordinates.
class PickedAddress {
  final String address;
  final double lat;
  final double lng;

  const PickedAddress({
    required this.address,
    required this.lat,
    required this.lng,
  });
}

/// Search-based address picker, replacing the Google Maps pin-drop page.
///
/// Dropping a pin on a map is a poor fit for this anyway: Uber needs a
/// postal address to deliver to, so a pin always had to be reverse-geocoded
/// back into one, and a pin dropped between two houses reverse-geocodes to
/// whichever the geocoder prefers. Searching returns the address directly,
/// with coordinates attached, and costs nothing to run.
class AddressPickerPage extends StatefulWidget {
  const AddressPickerPage({super.key});

  @override
  State<AddressPickerPage> createState() => _AddressPickerPageState();
}

class _AddressPickerPageState extends State<AddressPickerPage> {
  final _controller = TextEditingController();
  final _places = PlacesService();

  Timer? _debounce;
  List<PlacePrediction> _results = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Photon is a free public service — don't fire a request per keystroke.
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    if (value.trim().length < 3) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await _places.autocomplete(value);
      if (!mounted) return;
      setState(() {
        _results = results;
        _error = results.isEmpty ? 'No addresses found. Try adding the town.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not search right now. Please try again.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _choose(PlacePrediction p) async {
    try {
      final loc = await _places.getDetails(p.placeId);
      if (!mounted) return;
      Navigator.pop(
        context,
        PickedAddress(address: p.description, lat: loc.lat, lng: loc.lng),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not use that address. Pick another.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery address')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Street and town, e.g. 35 Talcottville Rd, Vernon',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = _results[i];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(p.description),
                  onTap: () => _choose(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
