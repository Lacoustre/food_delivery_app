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

/// Thin wrapper around the Google Places REST API (Autocomplete + Details).
/// Replaces the abandoned `flutter_google_places`/`google_maps_webservice`
/// packages, which pin `http` to a version incompatible with Supabase.
class PlacesService {
  final String apiKey;

  PlacesService(this.apiKey);

  Future<List<PlacePrediction>> autocomplete(String input) async {
    if (input.trim().isEmpty) return [];

    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': input,
      'key': apiKey,
      'language': 'en',
      'types': 'address',
      'components': 'country:us',
    });

    final response = await http.get(uri);
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final status = body['status'] as String?;
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      throw Exception('Places autocomplete failed: ${body['status']} ${body['error_message'] ?? ''}');
    }

    final predictions = (body['predictions'] as List<dynamic>? ?? []);
    return predictions
        .map((p) => PlacePrediction(
              placeId: p['place_id'] as String,
              description: p['description'] as String,
            ))
        .toList();
  }

  Future<PlaceLocation> getDetails(String placeId) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'key': apiKey,
      'fields': 'geometry',
    });

    final response = await http.get(uri);
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final status = body['status'] as String?;
    if (status != 'OK') {
      throw Exception('Place details failed: ${body['status']} ${body['error_message'] ?? ''}');
    }

    final location = body['result']['geometry']['location'] as Map<String, dynamic>;
    return PlaceLocation(
      lat: (location['lat'] as num).toDouble(),
      lng: (location['lng'] as num).toDouble(),
    );
  }
}
