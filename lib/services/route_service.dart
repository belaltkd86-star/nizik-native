import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum NizikRouteMode { driving, walking }

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

class NizikRouteAlternative extends RouteResult {
  final String id;
  final NizikRouteMode mode;

  const NizikRouteAlternative({
    required this.id,
    required this.mode,
    required super.points,
    required super.distanceMeters,
    required super.durationSeconds,
  });
}

class RouteService {
  static const String _osrm = 'https://router.project-osrm.org';
  static const String _valhalla = 'https://valhalla1.openstreetmap.de';

  Future<RouteResult> getDrivingRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final routes = await getRoutes(
      start: start,
      end: end,
      mode: NizikRouteMode.driving,
    );
    if (routes.isEmpty) throw Exception('هیچ ڕێگایەک نەدۆزرایەوە');
    return routes.first;
  }

  Future<List<NizikRouteAlternative>> getRoutes({
    required LatLng start,
    required LatLng end,
    NizikRouteMode mode = NizikRouteMode.driving,
  }) async {
    _validatePoint(start);
    _validatePoint(end);

    if (mode == NizikRouteMode.walking) {
      return _walkingValhalla(start: start, end: end);
    }
    return _drivingOsrm(start: start, end: end);
  }

  Future<List<NizikRouteAlternative>> _drivingOsrm({
    required LatLng start,
    required LatLng end,
  }) async {
    final coordinates =
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
    final uri = Uri.parse('$_osrm/route/v1/driving/$coordinates').replace(
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
        'alternatives': 'true',
      },
    );

    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'Nizik-App/1.0',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Route API Error: ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['code'] != 'Ok') {
      throw Exception('هیچ ڕێگایەک نەدۆزرایەوە');
    }

    final rawRoutes = decoded['routes'];
    if (rawRoutes is! List || rawRoutes.isEmpty) {
      throw Exception('هیچ ڕێگایەک نەدۆزرایەوە');
    }

    final result = <NizikRouteAlternative>[];
    for (var index = 0; index < rawRoutes.length && index < 3; index++) {
      final raw = rawRoutes[index];
      if (raw is! Map) continue;
      final route = Map<String, dynamic>.from(raw);
      final geometry = route['geometry'];
      if (geometry is! Map) continue;
      final coordinatesJson = geometry['coordinates'];
      if (coordinatesJson is! List) continue;
      final points = <LatLng>[];
      for (final coordinate in coordinatesJson) {
        if (coordinate is List && coordinate.length >= 2) {
          final lng = _toDouble(coordinate[0]);
          final lat = _toDouble(coordinate[1]);
          if (lat != null && lng != null && _validLatLng(lat, lng)) {
            points.add(LatLng(lat, lng));
          }
        }
      }
      if (points.length < 2) continue;
      result.add(
        NizikRouteAlternative(
          id: 'drive_${index + 1}',
          mode: NizikRouteMode.driving,
          points: points,
          distanceMeters: _toDouble(route['distance']) ?? 0,
          durationSeconds: _toDouble(route['duration']) ?? 0,
        ),
      );
    }
    if (result.isEmpty) throw Exception('ڕێگاکە خاڵی پێویستی نییە');
    return result;
  }

  Future<List<NizikRouteAlternative>> _walkingValhalla({
    required LatLng start,
    required LatLng end,
  }) async {
    final request = <String, dynamic>{
      'locations': [
        {'lat': start.latitude, 'lon': start.longitude},
        {'lat': end.latitude, 'lon': end.longitude},
      ],
      'costing': 'pedestrian',
      'directions_options': {'units': 'kilometers'},
    };
    final uri = Uri.parse('$_valhalla/route').replace(
      queryParameters: {'json': jsonEncode(request)},
    );

    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'Nizik-App/1.0',
      },
    ).timeout(const Duration(seconds: 22));

    if (response.statusCode != 200) {
      throw Exception('Walking route unavailable');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['trip'] is! Map) {
      throw Exception('Walking route unavailable');
    }
    final trip = Map<String, dynamic>.from(decoded['trip'] as Map);
    final legs = trip['legs'];
    if (legs is! List || legs.isEmpty) throw Exception('Walking route unavailable');

    final points = <LatLng>[];
    for (final rawLeg in legs) {
      if (rawLeg is! Map) continue;
      final shape = rawLeg['shape']?.toString() ?? '';
      if (shape.isEmpty) continue;
      final decodedPoints = _decodePolyline6(shape);
      if (points.isNotEmpty && decodedPoints.isNotEmpty && points.last == decodedPoints.first) {
        points.addAll(decodedPoints.skip(1));
      } else {
        points.addAll(decodedPoints);
      }
    }
    if (points.length < 2) throw Exception('Walking route unavailable');

    final summary = trip['summary'] is Map
        ? Map<String, dynamic>.from(trip['summary'] as Map)
        : const <String, dynamic>{};
    final lengthKm = _toDouble(summary['length']) ?? 0;
    final seconds = _toDouble(summary['time']) ?? 0;

    return [
      NizikRouteAlternative(
        id: 'walk_1',
        mode: NizikRouteMode.walking,
        points: points,
        distanceMeters: lengthKm * 1000,
        durationSeconds: seconds,
      ),
    ];
  }

  static List<LatLng> _decodePolyline6(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    const factor = 1e6;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      final latitude = lat / factor;
      final longitude = lng / factor;
      if (_validLatLng(latitude, longitude)) {
        points.add(LatLng(latitude, longitude));
      }
    }
    return points;
  }

  static void _validatePoint(LatLng point) {
    if (!_validLatLng(point.latitude, point.longitude)) {
      throw ArgumentError('Invalid coordinates');
    }
  }

  static bool _validLatLng(double lat, double lng) =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
