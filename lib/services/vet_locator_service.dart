import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class VetLocation {
  final String name;
  final double lat;
  final double lon;
  final String? address;

  VetLocation({
    required this.name,
    required this.lat,
    required this.lon,
    this.address,
  });
}

class VetLocatorService {
  Future<List<VetLocation>> findNearbyVets({
    required double lat,
    required double lon,
    int radiusMeters = 5000,
  }) async {
    final query = '[out:json][timeout:15];node["amenity"="veterinary"](around:$radiusMeters,$lat,$lon);out body;';
    final encodedQuery = Uri.encodeComponent(query);

    // Try the primary mirror first, falling back to the secondary mirror
    // on EITHER a bad status code OR a timeout/network error — a timeout
    // throws before a response ever exists, so it must be caught here,
    // not detected via response.statusCode after the fact.
    try {
      final url = Uri.parse('https://overpass.kumi.systems/api/interpreter?data=$encodedQuery');
      final response = await http
          .get(
            url,
            headers: {
              'User-Agent': 'PawPulseApp/1.0',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return _parseOverpassResponse(response.body);
      }
      // Non-200 — fall through to the fallback mirror below.
    } catch (_) {
      // Timeout, socket error, etc. — fall through to the fallback mirror below.
    }

    try {
      final fallbackUrl = Uri.parse('https://overpass-api.de/api/interpreter?data=$encodedQuery');
      final fallbackResponse = await http
          .get(
            fallbackUrl,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (fallbackResponse.statusCode == 200) {
        return _parseOverpassResponse(fallbackResponse.body);
      }
      // Non-200 (e.g. 406, 429) — fall through to the third mirror below.
    } catch (_) {
      // Timeout, socket error, etc. — fall through to the third mirror below.
    }

    try {
      final thirdUrl = Uri.parse('https://overpass.private.coffee/api/interpreter?data=$encodedQuery');
      final thirdResponse = await http
          .get(
            thirdUrl,
            headers: {
              'User-Agent': 'PawPulseApp/1.0',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (thirdResponse.statusCode != 200) {
        throw Exception(
          'Vet search failed (${thirdResponse.statusCode}) — all OpenStreetMap mirrors are busy, try again shortly.',
        );
      }
      return _parseOverpassResponse(thirdResponse.body);
    } on TimeoutException {
      throw Exception(
        'All OpenStreetMap mirrors timed out — this is usually shared public-server load, not the app. Try again in a minute.',
      );
    }
  }

  List<VetLocation> _parseOverpassResponse(String responseBody) {
    final data = jsonDecode(responseBody);
    final elements = data['elements'] as List<dynamic>? ?? [];

    return elements.map((e) {
      final tags = e['tags'] as Map<String, dynamic>? ?? {};
      final addressParts = [tags['addr:housenumber'], tags['addr:street']]
          .where((p) => p != null && p.toString().isNotEmpty)
          .join(' ');
      return VetLocation(
        name: tags['name']?.toString() ?? 'Veterinary Clinic',
        lat: (e['lat'] as num).toDouble(),
        lon: (e['lon'] as num).toDouble(),
        address: addressParts.isEmpty ? null : addressParts,
      );
    }).toList();
  }
}