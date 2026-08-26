import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacePrediction {
  final String placeId;
  final String description;

  PlacePrediction({required this.placeId, required this.description});
}

class PlaceLocation {
  final double lat;
  final double lng;

  PlaceLocation({required this.lat, required this.lng});
}

/// Address autocomplete via Photon, an OpenStreetMap-based geocoder.
///
/// Replaces the Google Places API, which needs billing enabled on a Google
/// Cloud project. Photon needs no key and no account. The webapp already
/// geocodes this way, so both clients now resolve addresses the same way.
///
/// Photon returns coordinates with each suggestion, so unlike Places there is
/// no second "details" round trip — [getDetails] reads what [autocomplete]
/// already fetched.
class PlacesService {
  PlacesService();

  static const _host = 'photon.komoot.io';

  // Bias results towards the restaurant so "main st" offers Vernon before
  // every other Main Street in the country.
  static const _biasLat = 41.82457;
  static const _biasLon = -72.4978;

  final Map<String, PlaceLocation> _coords = {};

  Future<List<PlacePrediction>> autocomplete(String input) async {
    if (input.trim().length < 3) return [];

    final uri = Uri.https(_host, '/api/', {
      'q': input,
      'limit': '6',
      'lang': 'en',
      'lat': '$_biasLat',
      'lon': '$_biasLon',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Address lookup failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (body['features'] as List<dynamic>? ?? []);

    final results = <PlacePrediction>[];
    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      // Uber needs a street address; a bare city or region cannot be
      // delivered to, so drop results that have no road.
      final street = props['street'] ?? props['name'];
      if (street == null) continue;
      if (props['countrycode'] != null && props['countrycode'] != 'US') continue;

      final label = _label(props);
      if (label.isEmpty) continue;

      final geom = f['geometry'] as Map<String, dynamic>?;
      final coords = geom?['coordinates'] as List<dynamic>?;
      if (coords == null || coords.length < 2) continue;

      final id = '${coords[1]},${coords[0]}';
      _coords[id] = PlaceLocation(
        lat: (coords[1] as num).toDouble(),
        lng: (coords[0] as num).toDouble(),
      );
      results.add(PlacePrediction(placeId: id, description: label));
    }
    return results;
  }

  /// "12 Main Street, Vernon, CT 06066"
  String _label(Map<String, dynamic> p) {
    final street = [p['housenumber'], p['street'] ?? p['name']]
        .where((v) => v != null && '$v'.isNotEmpty)
        .join(' ');
    final town = p['city'] ?? p['town'] ?? p['village'] ?? p['county'];
    final tail = [p['state'], p['postcode']]
        .where((v) => v != null && '$v'.isNotEmpty)
        .join(' ');

    return [street, town, tail]
        .where((v) => v != null && '$v'.trim().isNotEmpty)
        .join(', ');
  }

  Future<PlaceLocation> getDetails(String placeId) async {
    final cached = _coords[placeId];
    if (cached != null) return cached;

    // The id is "lat,lng" — recoverable even if the cache was cleared.
    final parts = placeId.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat != null && lng != null) return PlaceLocation(lat: lat, lng: lng);
    }
    throw Exception('Unknown place: $placeId');
  }
}
