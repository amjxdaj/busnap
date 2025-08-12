import 'dart:convert';
import 'package:http/http.dart' as http; // http is now a dependency
import 'package:latlong2/latlong.dart';

class DistanceService {
  final String apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjhmNTQ5YmY2ZGNkNDRhMWZiMDkzNGIxNjA0YmRiNDkzIiwiaCI6Im11cm11cjY0In0=';

  Future<Map<String, dynamic>> getRouteData({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey',
    );

    final body = jsonEncode({
      "coordinates": [
        [startLng, startLat],
        [endLng, endLat],
      ],
    });

    final headers = {"Content-Type": "application/json"};

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'] == null || data['routes'].isEmpty) {
        throw Exception('No route found: ${response.body}');
      }
      final summary = data['routes'][0]['summary'];
      final geometry = data['routes'][0]['geometry'];
      // Decode polyline geometry (encoded as polyline5)
      final List<LatLng> routePoints = decodePolyline(geometry);
      return {
        'distance_km': (summary['distance'] / 1000).toStringAsFixed(2),
        'duration_min': (summary['duration'] / 60).toStringAsFixed(2),
        'route_points': routePoints,
      };
    } else {
      throw Exception('Failed to get route data: ${response.body}');
    }
  }

  // Polyline decoding for OpenRouteService polyline5
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
