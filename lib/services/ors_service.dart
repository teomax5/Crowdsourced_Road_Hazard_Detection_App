import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ORSService {
  ORSService._(); // ✅ Fixed: prevent instantiation — utility class

  static final http.Client _client = http.Client(); // ✅ Fixed: reuse client
  static const Duration _timeout = Duration(seconds: 15); // ✅ Fixed: timeout

  /// Fetches up to 3 alternative driving routes from ORS.
  /// Throws an [Exception] on network or API errors.
  static Future<List<dynamic>> getRoutes(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      ) async {
    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car/geojson',
    );

    late http.Response response;
    try {
      response = await _client
          .post(
        url,
        headers: {
          'Authorization': ApiConfig.orsApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'coordinates': [
            [startLng, startLat],
            [endLng, endLat],
          ],
          'alternative_routes': {
            'target_count': 3,
            'weight_factor': 1.4,
          },
        }),
      )
          .timeout(_timeout); // ✅ Fixed: timeout
    } on TimeoutException {
      throw Exception('ORS request timed out. Check your connection.');
    } catch (e) {
      throw Exception('Network error contacting ORS: $e');
    }

    // ✅ Fixed: check HTTP status before parsing
    if (response.statusCode != 200) {
      debugPrint('ORS error body: ${response.body}');
      throw Exception('ORS API error ${response.statusCode}: ${response.body}');
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['features'] as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to parse ORS response: $e');
    }
  }
}