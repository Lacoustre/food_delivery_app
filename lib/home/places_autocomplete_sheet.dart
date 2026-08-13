import 'dart:async';
import 'package:flutter/material.dart';
import 'package:african_cuisine/services/places_service.dart';

/// Shows a simple search sheet backed by [PlacesService] and returns the
/// selected [PlacePrediction], or null if the user cancelled.
Future<PlacePrediction?> showPlacesAutocompleteSheet({
  required BuildContext context,
  required PlacesService placesService,
}) {
  return showModalBottomSheet<PlacePrediction>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PlacesAutocompleteSheet(placesService: placesService),
  );
}

class _PlacesAutocompleteSheet extends StatefulWidget {
  final PlacesService placesService;

  const _PlacesAutocompleteSheet({required this.placesService});

  @override
  State<_PlacesAutocompleteSheet> createState() => _PlacesAutocompleteSheetState();
}

class _PlacesAutocompleteSheetState extends State<_PlacesAutocompleteSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlacePrediction> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      try {
        final results = await widget.placesService.autocomplete(value);
        if (!mounted) return;
        setState(() {
          _results = results;
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search for an address',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final prediction = _results[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(prediction.description),
                    onTap: () => Navigator.pop(context, prediction),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
