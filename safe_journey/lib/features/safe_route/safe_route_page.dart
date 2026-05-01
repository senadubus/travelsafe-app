import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import 'package:safe_journey/core/api_client.dart';
import 'package:safe_journey/data/models/crime_point.dart';
import 'package:safe_journey/data/models/route_models.dart';
import 'package:safe_journey/data/services/crime_service.dart';
import 'package:safe_journey/data/services/route_service.dart';
import 'package:safe_journey/data/services/tile_overlay.dart';
import 'package:safe_journey/features/heatmap/heatmap_controller.dart';

const _kPrimary = Color(0xFF6B4FA0);
const _kBg = Color(0xFFF6F7FB);
const _kCard = Colors.white;

class SafeRoutePage extends StatefulWidget {
  const SafeRoutePage({super.key});

  @override
  State<SafeRoutePage> createState() => _SafeRoutePageState();
}

class _SafeRoutePageState extends State<SafeRoutePage> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  late final ApiClient _apiClient;
  late final RouteService _routeService;
  late final CrimeService _crimeService;
  late final HeatmapController _heatCtrl;

  GoogleMapController? _mapController;

  TileOverlay? _tileOverlay;
  bool _heatmapVisible = true;

  Timer? _markerDebounce;
  int _markerRequestId = 0;

  final Set<Marker> _routeMarkers = {};
  final Set<Marker> _crimeMarkers = {};
  final Set<Polyline> _polylines = {};

  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _markerIconsReady = false;

  LatLngBounds? _lastMarkerBounds;
  int? _lastMarkerDays;
  String? _lastMarkerType;

  bool _showCrimeMarkers = false;
  CrimePoint? _selectedCrime;

  int? _selectedRouteIndex;
  String _selectedMode = "car";

  bool _routeLoading = false;

  LatLng? startPoint;
  LatLng? endPoint;

  UIRouteResponse? _routeResponse;

  int _selectedDays = 365;
  String _selectedType = 'All';

  static const LatLng _initialCenter = LatLng(41.8781, -87.6298);

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient();
    _routeService = RouteService(apiClient: _apiClient);
    _crimeService = CrimeService(_apiClient);

    _heatCtrl = HeatmapController(
      days: _selectedDays,
      crimeType: null,
    );

    _tileOverlay = _buildOverlay();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();

    _markerDebounce?.cancel();
    _heatCtrl.disposeAll();
    _mapController?.dispose();

    super.dispose();
  }

  Future<LatLng?> _geocodeText(String text) async {
    final query = text.trim();
    if (query.isEmpty) return null;

    try {
      final locations = await locationFromAddress('$query, Chicago');
      if (locations.isEmpty) return null;

      final loc = locations.first;
      return LatLng(loc.latitude, loc.longitude);
    } catch (e) {
      debugPrint('Geocoding hata: $e');
      return null;
    }
  }

  TileOverlay _buildOverlay() {
    return TileOverlay(
      tileOverlayId: TileOverlayId(
        'safe_route_heat_${_selectedType}_$_selectedDays',
      ),
      tileProvider: HeatTileProvider(
        api: _apiClient,
        controller: _heatCtrl,
      ),
      transparency: 0.0,
      visible: true,
      zIndex: 1,
    );
  }

  Set<TileOverlay> _buildTileOverlays() {
    if (!_heatmapVisible || _tileOverlay == null || _showCrimeMarkers) {
      return {};
    }

    return {_tileOverlay!};
  }

  Set<Marker> _buildAllMarkers() {
    return {
      ..._routeMarkers,
      if (_showCrimeMarkers) ..._crimeMarkers,
    };
  }

  bool _boundsAlmostSame(LatLngBounds a, LatLngBounds b) {
    const eps = 0.0015;

    return (a.southwest.latitude - b.southwest.latitude).abs() < eps &&
        (a.southwest.longitude - b.southwest.longitude).abs() < eps &&
        (a.northeast.latitude - b.northeast.latitude).abs() < eps &&
        (a.northeast.longitude - b.northeast.longitude).abs() < eps;
  }

  String getCrimeCategory(String crime) {
    final c = crime.toUpperCase();

    if (['BATTERY', 'ASSAULT', 'HOMICIDE'].contains(c)) return 'VIOLENCE';
    if (c.contains('SEX')) return 'SEXUAL';
    if (c == 'BURGLARY') return 'BURGLARY';
    if (c == 'THEFT') return 'THEFT';
    if (c == 'ROBBERY') return 'ROBBERY';
    if (c.contains('VEHICLE')) return 'VEHICLE';
    if (c == 'NARCOTICS') return 'DRUG';
    if (c == 'ARSON') return 'FIRE';
    if (c.contains('WEAPON')) return 'WEAPON';
    if (c.contains('TRESPASS')) return 'TRESPASS';
    if (c.contains('DECEPTIVE')) return 'FRAUD';
    if (c.contains('CHILD')) return 'CHILD';
    if (c == 'KIDNAPPING') return 'KIDNAPPING';
    if (c.contains('DOMESTIC')) return 'DOMESTIC';

    return 'PUBLIC';
  }

  Future<void> _loadMarkerIcons() async {
    if (_markerIconsReady) return;

    const config = ImageConfiguration(size: Size(48, 48));

    for (final key in [
      'VIOLENCE',
      'SEXUAL',
      'BURGLARY',
      'THEFT',
      'ROBBERY',
      'VEHICLE',
      'DRUG',
      'FIRE',
      'WEAPON',
      'TRESPASS',
      'FRAUD',
      'CHILD',
      'KIDNAPPING',
      'DOMESTIC',
      'PUBLIC',
    ]) {
      _markerIcons[key] = await BitmapDescriptor.asset(
        config,
        'assets/markers/$key.png',
      );
    }

    _markerIconsReady = true;
  }

  BitmapDescriptor _iconForCrime(String crime) {
    if (!_markerIconsReady) {
      return BitmapDescriptor.defaultMarker;
    }

    final key = getCrimeCategory(crime);
    return _markerIcons[key] ?? _markerIcons['PUBLIC']!;
  }

  Future<void> _loadCrimeMarkers(LatLngBounds bounds) async {
    if (!_showCrimeMarkers) return;

    final requestId = ++_markerRequestId;

    if (!_markerIconsReady) {
      await _loadMarkerIcons();
    }

    final selectedCrimeType =
        _selectedType == 'All' ? null : _selectedType.toUpperCase();

    if (_lastMarkerBounds != null &&
        _boundsAlmostSame(_lastMarkerBounds!, bounds) &&
        _lastMarkerDays == _selectedDays &&
        _lastMarkerType == selectedCrimeType) {
      return;
    }

    _lastMarkerBounds = bounds;
    _lastMarkerDays = _selectedDays;
    _lastMarkerType = selectedCrimeType;

    try {
      final points = await _crimeService.fetchCrimePoints(
        sw: bounds.southwest,
        ne: bounds.northeast,
        days: _selectedDays,
        crimeType: selectedCrimeType,
        limit: 80,
      );

      if (!mounted || !_showCrimeMarkers || requestId != _markerRequestId) {
        return;
      }

      final markers = points.map((p) {
        return Marker(
          markerId: MarkerId(
            'crime_${p.crime}_${p.lat}_${p.lng}_${p.crimeDate?.millisecondsSinceEpoch ?? 0}',
          ),
          position: LatLng(p.lat, p.lng),
          icon: _iconForCrime(p.crime),
          infoWindow: InfoWindow.noText,
          onTap: () {
            setState(() {
              _selectedCrime = p;
            });
          },
        );
      }).toSet();

      setState(() {
        _crimeMarkers
          ..clear()
          ..addAll(markers);
      });
    } catch (e) {
      debugPrint('SafeRoute crime marker error: $e');
    }
  }

  Future<void> _onCameraIdle() async {
    if (_mapController == null) return;

    final zoom = await _mapController!.getZoomLevel();
    final bounds = await _mapController!.getVisibleRegion();

    if (!mounted) return;

    final showMarkersNow = zoom >= 15;

    if (showMarkersNow != _showCrimeMarkers) {
      setState(() {
        _showCrimeMarkers = showMarkersNow;

        if (!_showCrimeMarkers) {
          _crimeMarkers.clear();
          _selectedCrime = null;
          _lastMarkerBounds = null;
          _lastMarkerDays = null;
          _lastMarkerType = null;
          _markerRequestId++;
          _markerDebounce?.cancel();
        }
      });
    }

    if (_showCrimeMarkers) {
      _markerDebounce?.cancel();

      _markerDebounce = Timer(const Duration(milliseconds: 350), () async {
        if (!mounted || _mapController == null) return;

        final latestBounds = await _mapController!.getVisibleRegion();
        await _loadCrimeMarkers(latestBounds);
      });
    }
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeButton(Icons.directions_car, "car"),
          _modeButton(Icons.directions_walk, "walk"),
        ],
      ),
    );
  }

  Widget _modeButton(IconData icon, String mode) {
    final isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedMode = mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : Colors.black54,
        ),
      ),
    );
  }

  Widget _routeCards() {
    final routes = _routeResponse?.routes ?? [];

    if (routes.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 125,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: routes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final route = routes[index];
          final isSelected = _selectedRouteIndex == index;

          final color = index == 0
              ? Colors.purple
              : index == 1
                  ? Colors.green
                  : Colors.orange;

          final label = index == 0
              ? 'En Kısa'
              : index == 1
                  ? 'En Güvenli'
                  : 'Alternatif';

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedRouteIndex = index;
                _drawRoutes(_routeResponse!);
              });

              final points = route.geometry
                  .where((p) => p.length >= 2)
                  .map((p) => LatLng(p[0], p[1]))
                  .toList();

              if (points.isNotEmpty) {
                _fitPolylineBounds(points);
              }
            },
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(route.totalLengthM / 1000).toStringAsFixed(2)} km',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Risk: ${route.totalRisk.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    route.riskLevel,
                    style: TextStyle(
                      fontSize: 11,
                      color: route.riskLevel == "Düşük"
                          ? Colors.green
                          : route.riskLevel == "Orta"
                              ? Colors.orange
                              : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleMapTap(LatLng point) async {
    setState(() {
      _selectedCrime = null;
      _routeResponse = null;
      _polylines.clear();

      if (startPoint == null || endPoint != null) {
        startPoint = point;
        endPoint = null;

        _routeMarkers
          ..removeWhere((m) => m.markerId.value == 'start')
          ..removeWhere((m) => m.markerId.value == 'end')
          ..add(
            Marker(
              markerId: const MarkerId('start'),
              position: point,
              infoWindow: InfoWindow(
                title: 'Başlangıç',
                snippet:
                    '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
              ),
            ),
          );

        _fromCtrl.text =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
        _toCtrl.clear();
      } else {
        endPoint = point;

        _routeMarkers.removeWhere((m) => m.markerId.value == 'end');
        _routeMarkers.add(
          Marker(
            markerId: const MarkerId('end'),
            position: point,
            infoWindow: InfoWindow(
              title: 'Varış',
              snippet:
                  '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
            ),
          ),
        );

        _toCtrl.text =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

        _fitBounds(startPoint!, endPoint!);
      }
    });
  }

  Future<void> _calculateAlternativeRoutes() async {
    setState(() {
      _selectedCrime = null;
      _selectedRouteIndex = null;
      _routeLoading = true;
      _routeResponse = null;
      _polylines.clear();
    });

    try {
      LatLng? resolvedStart = startPoint;
      LatLng? resolvedEnd = endPoint;

      if (resolvedStart == null && _fromCtrl.text.trim().isNotEmpty) {
        resolvedStart = await _geocodeText(_fromCtrl.text);
      }

      if (resolvedEnd == null && _toCtrl.text.trim().isNotEmpty) {
        resolvedEnd = await _geocodeText(_toCtrl.text);
      }

      if (resolvedStart == null || resolvedEnd == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Başlangıç veya varış adresi bulunamadı.'),
          ),
        );
        return;
      }

      startPoint = resolvedStart;
      endPoint = resolvedEnd;

      _fromCtrl.text =
          '${resolvedStart.latitude.toStringAsFixed(5)}, ${resolvedStart.longitude.toStringAsFixed(5)}';
      _toCtrl.text =
          '${resolvedEnd.latitude.toStringAsFixed(5)}, ${resolvedEnd.longitude.toStringAsFixed(5)}';

      _routeMarkers
        ..clear()
        ..add(
          Marker(
            markerId: const MarkerId('start'),
            position: resolvedStart,
            infoWindow: const InfoWindow(title: 'Başlangıç'),
          ),
        )
        ..add(
          Marker(
            markerId: const MarkerId('end'),
            position: resolvedEnd,
            infoWindow: const InfoWindow(title: 'Varış'),
          ),
        );

      _fitBounds(resolvedStart, resolvedEnd);

      final result = await _routeService.sendUiRoute(
        startLat: resolvedStart.latitude,
        startLng: resolvedStart.longitude,
        endLat: resolvedEnd.latitude,
        endLng: resolvedEnd.longitude,
        mode: _selectedMode,
      );

      setState(() {
        _routeResponse = result;
        _drawRoutes(result);
      });

      if (result.routes.isNotEmpty && result.routes.first.geometry.isNotEmpty) {
        final points = result.routes.first.geometry
            .where((p) => p.length >= 2)
            .map((p) => LatLng(p[0], p[1]))
            .toList();

        if (points.isNotEmpty) {
          _fitPolylineBounds(points);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.routes.length} rota backend’den geldi.'),
        ),
      );
    } catch (e) {
      debugPrint('Rota API hata: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rota alınamadı: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _routeLoading = false);
      }
    }
  }

  void _drawRoutes(UIRouteResponse response) {
    _polylines.clear();

    for (int i = response.routes.length - 1; i >= 0; i--) {
      final route = response.routes[i];

      final points = route.geometry
          .where((p) => p.length >= 2)
          .map((p) => LatLng(p[0], p[1]))
          .toList();

      if (points.isEmpty) continue;

      final isSelected = _selectedRouteIndex == i;
      final showByDefault = _selectedRouteIndex == null && (i == 0 || i == 1);

      if (!isSelected && !showByDefault) continue;

      _polylines.add(
        Polyline(
          polylineId: PolylineId('route_${route.routeId}'),
          points: points,
          width: isSelected || i == 0 ? 5 : 3,
          color: i == 0
              ? Colors.purple
              : i == 1
                  ? Colors.green
                  : Colors.orange,
          zIndex: isSelected ? 20 : 10 - i,
        ),
      );
    }
  }

  void _clear() {
    setState(() {
      startPoint = null;
      endPoint = null;
      _routeResponse = null;

      _routeMarkers.clear();
      _crimeMarkers.clear();
      _polylines.clear();

      _selectedCrime = null;
      _lastMarkerBounds = null;
      _lastMarkerDays = null;
      _lastMarkerType = null;

      _fromCtrl.clear();
      _toCtrl.clear();
    });
  }

  void _fitBounds(LatLng start, LatLng end) {
    final south = start.latitude < end.latitude ? start.latitude : end.latitude;
    final north = start.latitude > end.latitude ? start.latitude : end.latitude;
    final west =
        start.longitude < end.longitude ? start.longitude : end.longitude;
    final east =
        start.longitude > end.longitude ? start.longitude : end.longitude;

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        80,
      ),
    );
  }

  void _fitPolylineBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final hasRoute = _routeResponse != null;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.fromLTRB(
                16,
                hasRoute ? 4 : (top > 0 ? 8 : 14),
                16,
                hasRoute ? 6 : 12,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: hasRoute ? 20 : 24,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E),
                          ),
                          child: const Text('Güvenli Rota'),
                        ),
                      ),
                      if (_routeMarkers.isNotEmpty)
                        TextButton(
                          onPressed: _clear,
                          child: const Text('Temizle'),
                        ),
                    ],
                  ),
                  if (!hasRoute) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bölge/adres yazın veya haritadan başlangıç ve varış seçin.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else
                    const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.all(hasRoute ? 10 : 14),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _InputRow(
                          controller: _fromCtrl,
                          hint: 'Başlangıç adresi / bölgesi',
                          icon: Icons.radio_button_checked,
                          iconColor: _kPrimary,
                        ),
                        SizedBox(height: hasRoute ? 6 : 10),
                        Divider(color: Colors.grey.shade200, height: 1),
                        SizedBox(height: hasRoute ? 6 : 10),
                        _InputRow(
                          controller: _toCtrl,
                          hint: 'Varış adresi / bölgesi',
                          icon: Icons.location_on,
                          iconColor: Colors.orange,
                        ),
                        SizedBox(height: hasRoute ? 10 : 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _routeLoading
                                ? null
                                : _calculateAlternativeRoutes,
                            icon: _routeLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.route, size: 18),
                            label: Text(
                              _routeLoading
                                  ? 'Rota hesaplanıyor...'
                                  : 'Rotayı Hesapla',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _kPrimary,
                              padding: EdgeInsets.symmetric(
                                vertical: hasRoute ? 12 : 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: const CameraPosition(
                          target: _initialCenter,
                          zoom: 12,
                        ),
                        onMapCreated: (controller) async {
                          _mapController = controller;
                          _heatCtrl.attachMap(controller);

                          try {
                            await _loadMarkerIcons();
                          } catch (e) {
                            debugPrint('SafeRoute icon load error: $e');
                          }

                          setState(() {
                            _tileOverlay = _buildOverlay();
                          });

                          await _onCameraIdle();
                        },
                        onCameraIdle: _onCameraIdle,
                        onTap: (point) {
                          if (_selectedCrime != null) {
                            setState(() {
                              _selectedCrime = null;
                            });
                            return;
                          }

                          _handleMapTap(point);
                        },
                        tileOverlays: _buildTileOverlays(),
                        markers: _buildAllMarkers(),
                        polylines: _polylines,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                      ),
                      if (_routeResponse != null)
                        Positioned(
                          left: 0,
                          top: 0,
                          right: 18,
                          child: _routeCards(),
                        ),
                      Positioned(
                        top: _routeResponse != null ? 135 : 50,
                        right: 16,
                        child: _buildModeToggle(),
                      ),
                      Positioned(
                        top: _routeResponse != null ? 190 : 105,
                        right: 16,
                        child: _MapFab(
                          icon: _heatmapVisible
                              ? Icons.layers
                              : Icons.layers_clear,
                          active: _heatmapVisible,
                          onTap: () async {
                            setState(() {
                              _heatmapVisible = !_heatmapVisible;
                            });

                            if (_heatmapVisible &&
                                _mapController != null &&
                                _tileOverlay != null) {
                              await _mapController!.clearTileCache(
                                _tileOverlay!.tileOverlayId,
                              );
                            }
                          },
                        ),
                      ),
                      if (_selectedCrime != null)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: _CrimeDetailCard(
                            crime: _selectedCrime!,
                            onClose: () {
                              setState(() {
                                _selectedCrime = null;
                              });
                            },
                          ),
                        ),
                      if (_routeLoading)
                        Container(
                          color: Colors.white.withOpacity(0.35),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            readOnly: false,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              isDense: true,
              hintStyle: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _kPrimary : Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 20,
            color: active ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class _CrimeDetailCard extends StatelessWidget {
  final CrimePoint crime;
  final VoidCallback onClose;

  const _CrimeDetailCard({
    required this.crime,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final date = crime.crimeDate != null
        ? "${crime.crimeDate!.day.toString().padLeft(2, '0')}/"
            "${crime.crimeDate!.month.toString().padLeft(2, '0')}/"
            "${crime.crimeDate!.year}"
        : "Unknown date";

    final time = crime.crimeDate != null
        ? "${crime.crimeDate!.hour.toString().padLeft(2, '0')}:"
            "${crime.crimeDate!.minute.toString().padLeft(2, '0')}"
        : "--:--";

    final description =
        crime.description != null && crime.description!.trim().isNotEmpty
            ? crime.description!.trim()
            : "No additional description available.";

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      crime.crime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F1F1F),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DetailPill(
                      icon: Icons.calendar_today_rounded,
                      label: "Date",
                      value: date,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DetailPill(
                      icon: Icons.access_time_rounded,
                      label: "Time",
                      value: time,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE9E9EF)),
                ),
                child: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E9EF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _kPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
