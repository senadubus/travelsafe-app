import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../core/api_client.dart';
import '../../core/constants.dart';
import 'heatmap_controller.dart';

Future<List<Map<String, dynamic>>> parseMarkersInBackground(String body) {
  return compute(_parseMarkers, body);
}

List<Map<String, dynamic>> _parseMarkers(String body) {
  final data = jsonDecode(body);
  final points = (data['points'] as List?) ?? [];

  return points.map<Map<String, dynamic>>((p) {
    return {
      'id': p['id'].toString(),
      'lat': (p['lat'] as num).toDouble(),
      'lng': (p['lng'] as num).toDouble(),
      'crimeType': p['crime_type']?.toString() ?? 'Crime',
      'description': p['description']?.toString() ?? '',
    };
  }).toList();
}

class HeatmapPage extends StatefulWidget {
  const HeatmapPage({super.key});

  @override
  State<HeatmapPage> createState() => _HeatmapPageState();
}

class _HeatmapPageState extends State<HeatmapPage> {
  late final HeatmapController controller;
  late final TileOverlay _heatOverlay;

  GoogleMapController? _mapController;
  Set<Marker> _crimeMarkers = {};
  final http.Client _client = http.Client();
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    controller = HeatmapController();

    _heatOverlay = TileOverlay(
      tileOverlayId: const TileOverlayId('heat'),
      tileProvider: HeatTileProvider(
        api: ApiClient(),
        controller: controller,
      ),
      zIndex: 10,
      transparency: 0.05,
    );
  }

  @override
  void dispose() {
    _client.close();
    controller.disposeAll();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _handleCameraIdle() async {
    controller.scheduleFetch();

    if (_mapController == null) return;

    final bounds = await _mapController!.getVisibleRegion();
    final zoom = await _mapController!.getZoomLevel();
    print("🔍🔍🔍 MAP ZOOM LEVEL >>> $zoom <<< 🔍🔍🔍");
    await fetchCrimePoints(bounds, zoom);
  }

  Future<void> fetchCrimePoints(LatLngBounds bounds, double zoom) async {
    final int currentRequestId = ++_requestId;

    if (zoom < 13) {
      if (_crimeMarkers.isNotEmpty && mounted) {
        setState(() {
          _crimeMarkers = {};
        });
      }
      return;
    }

    try {
      final limit = zoom >= 15 ? 150 : 80;

      final uri = Uri.parse('${Env.baseUrl}/api/crimes/points').replace(
        queryParameters: {
          'min_lat': bounds.southwest.latitude.toString(),
          'min_lng': bounds.southwest.longitude.toString(),
          'max_lat': bounds.northeast.latitude.toString(),
          'max_lng': bounds.northeast.longitude.toString(),
          'days': '30',
          'limit': limit.toString(),
        },
      );

      final res = await _client.get(uri);

      if (currentRequestId != _requestId) return;

      if (res.statusCode != 200) {
        debugPrint('fetchCrimePoints failed: ${res.statusCode}');
        return;
      }

      final parsed = await parseMarkersInBackground(res.body);

      if (currentRequestId != _requestId || !mounted) return;

      final markers = parsed.map((p) {
        return Marker(
          markerId: MarkerId(p['id'] as String),
          position: LatLng(p['lat'] as double, p['lng'] as double),
          infoWindow: InfoWindow(
            title: p['crimeType'] as String,
            snippet: p['description'] as String,
          ),
        );
      }).toSet();

      setState(() {
        _crimeMarkers = markers;
      });
    } catch (e) {
      debugPrint('fetchCrimePoints error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(41.8781, -87.6298),
              zoom: 11,
            ),
            onMapCreated: (c) async {
              _mapController = c;
              controller.attachMap(c);
              controller.scheduleFetch();

              final bounds = await c.getVisibleRegion();
              final zoom = await c.getZoomLevel();
              await fetchCrimePoints(bounds, zoom);
            },
            onCameraIdle: _handleCameraIdle,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            tiltGesturesEnabled: false,
            mapToolbarEnabled: false,
            tileOverlays: {_heatOverlay},
            markers: _crimeMarkers,
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (_, __) {
              if (!controller.loading) return const SizedBox.shrink();
              return const Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// TileProvider: (z/x/y) tile png’yi backend’den alır.
class HeatTileProvider implements TileProvider {
  final ApiClient api;
  final HeatmapController controller;

  HeatTileProvider({
    required this.api,
    required this.controller,
  });

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    try {
      final days = controller.days;
      final crimeType = controller.crimeType;

      final qp = <String, String>{
        'days': days.toString(),
        if (crimeType != null) 'crime_type': crimeType,
      };

      final uri = Uri.parse('${Env.baseUrl}/tiles/heat/$zoom/$x/$y.png')
          .replace(queryParameters: qp);

      final bytes = await api.getBytes(uri);
      if (bytes.isEmpty) return TileProvider.noTile;

      return Tile(256, 256, bytes);
    } catch (_) {
      return TileProvider.noTile;
    }
  }
}
