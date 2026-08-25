import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class RouteService {
  static const String _baseUrl =
      'https://router.project-osrm.org';

  Future<RouteResult> getDrivingRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final coordinates =
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}';

    final uri = Uri.parse(
      '$_baseUrl/route/v1/driving/$coordinates',
    ).replace(
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
        'alternatives': 'false',
      },
    );

    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'Nizik-App/1.0',
      },
    ).timeout(
      const Duration(seconds: 20),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Route API Error: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception('وەڵامی Route دروست نییە');
    }

    final data =
        Map<String, dynamic>.from(decoded);

    if (data['code'] != 'Ok') {
      if (data['code'] == 'NoRoute') {
        throw Exception(
          'هیچ ڕێگایەک نەدۆزرایەوە',
        );
      }

      throw Exception(
        'نەتوانرا ڕێگاکە بدۆزرێتەوە',
      );
    }

    final routes = data['routes'];

    if (routes is! List || routes.isEmpty) {
      throw Exception(
        'هیچ ڕێگایەک نەدۆزرایەوە',
      );
    }

    if (routes.first is! Map) {
      throw Exception('وەڵامی Route دروست نییە');
    }

    final route =
        Map<String, dynamic>.from(
      routes.first as Map,
    );

    final geometryRaw = route['geometry'];

    if (geometryRaw is! Map) {
      throw Exception(
        'Geometry ـی ڕێگاکە دروست نییە',
      );
    }

    final geometry =
        Map<String, dynamic>.from(
      geometryRaw,
    );

    final coordinatesJson =
        geometry['coordinates'];

    if (coordinatesJson is! List) {
      throw Exception(
        'Geometry ـی ڕێگاکە دروست نییە',
      );
    }

    final points = <LatLng>[];

    for (final coordinate
        in coordinatesJson) {
      if (coordinate is List &&
          coordinate.length >= 2) {
        final lngRaw = coordinate[0];
        final latRaw = coordinate[1];

        if (lngRaw is num &&
            latRaw is num) {
          points.add(
            LatLng(
              latRaw.toDouble(),
              lngRaw.toDouble(),
            ),
          );
        }
      }
    }

    if (points.length < 2) {
      throw Exception(
        'ڕێگاکە خاڵی پێویستی نییە',
      );
    }

    return RouteResult(
      points: points,
      distanceMeters:
          (route['distance'] as num?)
                  ?.toDouble() ??
              0,
      durationSeconds:
          (route['duration'] as num?)
                  ?.toDouble() ??
              0,
    );
  }
}
