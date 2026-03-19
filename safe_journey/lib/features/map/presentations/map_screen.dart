import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import 'package:safe_journey/features/heatmap/heatmap_controller.dart';
import 'package:safe_journey/data/services/tile_overlay.dart';

import 'widgets/bottom_bar.dart';
import 'widgets/filter_panel.dart';
import 'widgets/side_actions.dart';
import 'widgets/threat_badge.dart';
import 'widgets/top_bar.dart';

const _kMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1b1f27"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8f96a3"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1b1f27"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#252b36"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2a3140"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#12161d"}]}
]
''';

Future<List<Map<String, dynamic>>> parseMarkersInBackground(String body) {
  return compute(_parseMarkers, body);
}

List<Map<String, dynamic>> _parseMarkers(String body) {
  final data = jsonDecode(body);
  final points = (data['points'] as List?) ?? [];

  return points.map<Map<String, dynamic>>((p) {
    final lat = (p['lat'] as num).toDouble();
    final lng = (p['lng'] as num).toDouble();

    return {
      'id': p['id']?.toString() ?? '${lat}_$lng',
      'lat': lat,
      'lng': lng,
      'crimeType': p['crime_type']?.toString() ?? 'Crime',
      'description': p['description']?.toString() ?? '',
    };
  }).toList();
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.8781, -87.6298),
    zoom: 11,
  );

  GoogleMapController? _mapController;
  late final HeatmapController _controller;
  late final TileOverlay _heatOverlay;
  final http.Client _client = http.Client();

  Set<Marker> _crimeMarkers = {};
  double _currentZoom = 11.0;
  int _requestId = 0;

  bool _heatmapVisible = true;
  bool _filterOpen = false;
  String _selectedCrimeType = 'ALL';
  int _selectedDays = 30;

  @override
  void initState() {
    super.initState();

    _controller = HeatmapController();
    _controller.days = _selectedDays;
    _controller.crimeType =
        _selectedCrimeType == 'ALL' ? null : _selectedCrimeType;

    _heatOverlay = TileOverlay(
      tileOverlayId: const TileOverlayId('heat'),
      tileProvider: HeatTileProvider(
        api: ApiClient(),
        controller: _controller,
      ),
      zIndex: 10,
      transparency: 0.0,
      visible: _heatmapVisible,
    );
  }

  @override
  void dispose() {
    _client.close();
    _controller.disposeAll();
    _mapController?.dispose();
    super.dispose();
  }

  Set<TileOverlay> _buildTileOverlays() {
    if (!_heatmapVisible) return {};
    if (_currentZoom >= 15) return {};
    return {_heatOverlay};
  }

  Future<void> _handleCameraIdle() async {
    _controller.scheduleFetch();

    if (_mapController == null) return;

    final bounds = await _mapController!.getVisibleRegion();
    final zoom = await _mapController!.getZoomLevel();

    if (!mounted) return;

    setState(() {
      _currentZoom = zoom;
    });

    await _fetchCrimePoints(bounds, zoom);
  }

  Future<void> _fetchCrimePoints(LatLngBounds bounds, double zoom) async {
    final int currentRequestId = ++_requestId;

    if (zoom < 15) {
      if (_crimeMarkers.isNotEmpty && mounted) {
        setState(() => _crimeMarkers = {});
      }
      return;
    }

    try {
      final uri = Uri.parse('${Env.baseUrl}/api/crimes/points').replace(
        queryParameters: {
          'min_lat': bounds.southwest.latitude.toString(),
          'min_lng': bounds.southwest.longitude.toString(),
          'max_lat': bounds.northeast.latitude.toString(),
          'max_lng': bounds.northeast.longitude.toString(),
          'days': _selectedDays.toString(),
          'limit': '150',
          if (_selectedCrimeType != 'ALL') 'crime_type': _selectedCrimeType,
        },
      );

      final res = await _client.get(uri);

      if (currentRequestId != _requestId) return;
      if (res.statusCode != 200) return;

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

      setState(() => _crimeMarkers = markers);
    } catch (e) {
      debugPrint('fetchCrimePoints error: $e');
    }
  }

  void _toggleFilter() {
    setState(() => _filterOpen = !_filterOpen);
  }

  void _closeFilter() {
    setState(() => _filterOpen = false);
  }

  Future<void> _applyFilters() async {
    _controller.setFilters(
      crimeType: _selectedCrimeType == 'ALL' ? null : _selectedCrimeType,
      days: _selectedDays,
    );

    _closeFilter();
    await _handleCameraIdle();
  }

  ThreatLevel get _threatLevel {
    final total = _crimeMarkers.length;
    if (total == 0) return ThreatLevel.unknown;
    if (total > 80) return ThreatLevel.high;
    if (total > 20) return ThreatLevel.medium;
    return ThreatLevel.low;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _controller.loading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _initialPosition,
              onMapCreated: (c) async {
                _mapController = c;
                _controller.attachMap(c);
                await c.setMapStyle(_kMapStyle);

                _controller.scheduleFetch();

                final bounds = await c.getVisibleRegion();
                final zoom = await c.getZoomLevel();

                if (!mounted) return;

                setState(() => _currentZoom = zoom);
                await _fetchCrimePoints(bounds, zoom);
              },
              onCameraIdle: _handleCameraIdle,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              tiltGesturesEnabled: false,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              tileOverlays: _buildTileOverlays(),
              markers: _crimeMarkers,
            ),
            TopBar(
              threatLevel: _threatLevel,
              isLoading: isLoading,
            ),
            Positioned(
              right: 16,
              bottom: 120,
              child: SideActions(
                heatmapOn: _heatmapVisible,
                onRecenter: () {
                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(_initialPosition),
                  );
                },
                onToggleHeatmap: () {
                  setState(() => _heatmapVisible = !_heatmapVisible);
                },
              ),
            ),
            if (_filterOpen)
              GestureDetector(
                onTap: _closeFilter,
                child: Container(
                  color: Colors.black.withOpacity(0.28),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              bottom: _filterOpen ? 0 : -420,
              child: FilterPanel(
                selectedCrimeType: _selectedCrimeType,
                selectedDays: _selectedDays,
                onCrimeTypeChanged: (v) {
                  setState(() => _selectedCrimeType = v);
                },
                onDaysChanged: (v) {
                  setState(() => _selectedDays = v);
                },
                onApply: _applyFilters,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomBar(
                selectedCrimeType: _selectedCrimeType,
                selectedDays: _selectedDays,
                filterOpen: _filterOpen,
                onToggleFilter: _toggleFilter,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
