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

// ─── Tema sabitleri ────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF6B4FA0);
const _kPrimaryLight = Color(0xFFEEEDFE);
const _kBg = Color(0xFFF6F7FB);
const _kCard = Colors.white;
const _kSurface = Color(0xFFF2F0F8);

// ─── Ana sayfa ─────────────────────────────────────────────────────────────────
class SafeRoutePage extends StatefulWidget {
  const SafeRoutePage({super.key});

  @override
  State<SafeRoutePage> createState() => _SafeRoutePageState();
}

class _SafeRoutePageState extends State<SafeRoutePage>
    with TickerProviderStateMixin {
  // Controllers
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();

  // Services
  late final ApiClient _apiClient;
  late final RouteService _routeService;
  late final CrimeService _crimeService;
  late final HeatmapController _heatCtrl;

  // Map
  GoogleMapController? _mapController;
  TileOverlay? _tileOverlay;
  bool _heatmapVisible = true;
  double _currentZoom = 12.0;

  // Markers & polylines
  Timer? _markerDebounce;
  int _markerRequestId = 0;
  final Set<Marker> _routeMarkers = {};
  final Set<Marker> _crimeMarkers = {};
  final Set<Polyline> _polylines = {};

  // Crime marker icons
  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _markerIconsReady = false;
  LatLngBounds? _lastMarkerBounds;
  int? _lastMarkerDays;
  String? _lastMarkerType;

  // Crime state
  bool _showCrimeMarkers = false;
  CrimePoint? _selectedCrime;

  // Route state
  int? _selectedRouteIndex;
  String _selectedMode = 'car';
  bool _routeLoading = false;
  LatLng? startPoint;
  LatLng? endPoint;
  UIRouteResponse? _routeResponse;

  // Filter state
  int _selectedDays = 180;
  String _selectedType = 'All';

  // Animation
  late final AnimationController _sheetAnimCtrl;
  late final Animation<double> _sheetAnim;

  static const LatLng _initialCenter = LatLng(41.8781, -87.6298);

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient();
    _routeService = RouteService(apiClient: _apiClient);
    _crimeService = CrimeService(_apiClient);
    _heatCtrl = HeatmapController(days: _selectedDays, crimeType: null);
    _tileOverlay = _buildOverlay();

    _sheetAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _sheetAnim = CurvedAnimation(
      parent: _sheetAnimCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    _markerDebounce?.cancel();
    _heatCtrl.disposeAll();
    _mapController?.dispose();
    _sheetAnimCtrl.dispose();
    super.dispose();
  }

  void _showSheet() => _sheetAnimCtrl.forward();

  void _hideSheet() => _sheetAnimCtrl.reverse();

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

  TileOverlay _buildOverlay() => TileOverlay(
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

  Set<TileOverlay> _buildTileOverlays() {
    if (!_heatmapVisible || _tileOverlay == null || _showCrimeMarkers) {
      return {};
    }

    return {_tileOverlay!};
  }

  Set<Marker> _buildAllMarkers() => {
        ..._routeMarkers,
        if (_showCrimeMarkers) ..._crimeMarkers,
      };

  bool _boundsAlmostSame(LatLngBounds a, LatLngBounds b) {
    const eps = 0.0015;

    return (a.southwest.latitude - b.southwest.latitude).abs() < eps &&
        (a.southwest.longitude - b.southwest.longitude).abs() < eps &&
        (a.northeast.latitude - b.northeast.latitude).abs() < eps &&
        (a.northeast.longitude - b.northeast.longitude).abs() < eps;
  }

  String _crimeCategory(String crime) {
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

    const config = ImageConfiguration(size: Size(24, 24));

    const keys = [
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
    ];

    final icons = await Future.wait(
      keys.map(
        (key) => BitmapDescriptor.asset(
          config,
          'assets/markers/$key.png',
        ),
      ),
    );

    for (int i = 0; i < keys.length; i++) {
      _markerIcons[keys[i]] = icons[i];
    }

    _markerIconsReady = true;
  }

  BitmapDescriptor _iconForCrime(String crime) {
    if (!_markerIconsReady) return BitmapDescriptor.defaultMarker;
    return _markerIcons[_crimeCategory(crime)] ?? _markerIcons['PUBLIC']!;
  }

  double _baseOffset() {
    const base = 0.00035;
    final zoomDiff = (_currentZoom.round() - 15).clamp(0, 8);
    return base / (1 << zoomDiff);
  }

  double _msin(double x) {
    x = x % (2 * 3.14159265);
    if (x > 3.14159265) x -= 2 * 3.14159265;

    final x2 = x * x;

    return x * (1 - x2 / 6 * (1 - x2 / 20 * (1 - x2 / 42)));
  }

  double _mcos(double x) => _msin(x + 3.14159265 / 2);

  List<LatLng> _spreadPositions(int count, double lat, double lng) {
    if (count == 1) return [LatLng(lat, lng)];

    final r = _baseOffset() * (1 + count * 0.18);
    const lngScale = 1.5;

    final startAngle = count.isEven ? 0.0 : -3.14159265 / 2;
    final step = 2 * 3.14159265 / count;

    return List.generate(count, (i) {
      final angle = startAngle + i * step;

      return LatLng(
        lat + r * _msin(angle),
        lng + r * lngScale * _mcos(angle),
      );
    });
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

      final Map<String, List<int>> groups = {};

      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        final key = '${p.lat.toStringAsFixed(6)},${p.lng.toStringAsFixed(6)}';
        groups.putIfAbsent(key, () => []).add(i);
      }

      final Set<Marker> markers = {};

      for (final indices in groups.values) {
        final basePoint = points[indices.first];

        final positions = _spreadPositions(
          indices.length,
          basePoint.lat,
          basePoint.lng,
        );

        for (int j = 0; j < indices.length; j++) {
          final p = points[indices[j]];

          markers.add(
            Marker(
              markerId: MarkerId(
                'crime_${p.crime}_${p.lat}_${p.lng}_'
                '${p.crimeDate?.millisecondsSinceEpoch ?? 0}',
              ),
              position: positions[j],
              icon: _iconForCrime(p.crime),
              infoWindow: InfoWindow.noText,
              onTap: () {
                setState(() => _selectedCrime = p);
                _showSheet();
              },
            ),
          );
        }
      }

      setState(() {
        _crimeMarkers
          ..clear()
          ..addAll(markers);
      });
    } catch (e) {
      debugPrint('Crime marker error: $e');
    }
  }

  Future<void> _onCameraIdle() async {
    if (_mapController == null) return;

    final zoom = await _mapController!.getZoomLevel();
    final bounds = await _mapController!.getVisibleRegion();

    if (!mounted) return;

    setState(() => _currentZoom = zoom);

    final hasRoutePoints = startPoint != null && endPoint != null;

    final showMarkersNow = zoom >= 15 && hasRoutePoints;

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

  Future<void> _calculateAlternativeRoutes() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedCrime = null;
      _selectedRouteIndex = null;
      _routeLoading = true;
      _routeResponse = null;
      _polylines.clear();
    });

    _hideSheet();

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Başlangıç veya varış adresi bulunamadı.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

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
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet),
          ),
        )
        ..add(
          Marker(
            markerId: const MarkerId('end'),
            position: resolvedEnd,
            infoWindow: const InfoWindow(title: 'Varış'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
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

      if (!mounted) return;

      setState(() {
        _routeResponse = result;
        _drawRoutes(result);
      });

      if (result.routes.isNotEmpty && result.routes.first.geometry.isNotEmpty) {
        final points = result.routes.first.geometry
            .where((p) => p.length >= 2)
            .map((p) => LatLng(p[0], p[1]))
            .toList();

        if (points.isNotEmpty) _fitPolylineBounds(points);
      }

      _showSheet();
    } catch (e) {
      debugPrint('Rota API hata: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rota alınamadı: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _routeLoading = false);
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
          color: _routeColor(i),
          zIndex: isSelected ? 20 : 10 - i,
        ),
      );
    }
  }

  Color _routeColor(int index) {
    if (index == 0) return _kPrimary;
    if (index == 1) return const Color(0xFF22C55E);
    return Colors.orange;
  }

  Color _riskColor(String level) {
    switch (level) {
      case 'Düşük':
        return const Color(0xFF22C55E);
      case 'Orta':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Future<void> _handleMapTap(LatLng point) async {
    if (_selectedCrime != null) {
      setState(() => _selectedCrime = null);
      _hideSheet();
      return;
    }

    setState(() {
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
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet),
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
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
          ),
        );

        _toCtrl.text =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

        _fitBounds(startPoint!, endPoint!);
      }
    });
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

    _hideSheet();
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
    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          _CompactHeader(
            fromCtrl: _fromCtrl,
            toCtrl: _toCtrl,
            fromFocus: _fromFocus,
            toFocus: _toFocus,
            loading: _routeLoading,
            hasPoints: startPoint != null || endPoint != null,
            onCalculate: _calculateAlternativeRoutes,
            onClear: _clear,
          ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _initialCenter,
                    zoom: 12,
                  ),
                  onMapCreated: (ctrl) async {
                    _mapController = ctrl;
                    _heatCtrl.attachMap(ctrl);

                    _loadMarkerIcons().catchError(
                      (e) => debugPrint('Icon load error: $e'),
                    );

                    setState(() => _tileOverlay = _buildOverlay());
                    await _onCameraIdle();
                  },
                  onCameraIdle: _onCameraIdle,
                  onTap: _handleMapTap,
                  tileOverlays: _buildTileOverlays(),
                  markers: _buildAllMarkers(),
                  polylines: _polylines,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _FabColumn(
                    mode: _selectedMode,
                    heatmapVisible: _heatmapVisible,
                    onModeChanged: (m) => setState(() => _selectedMode = m),
                    onHeatmapToggle: () async {
                      setState(() => _heatmapVisible = !_heatmapVisible);

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
                if (_routeLoading)
                  Container(
                    color: Colors.white.withOpacity(0.35),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                AnimatedBuilder(
                  animation: _sheetAnim,
                  builder: (context, child) {
                    if (_sheetAnim.value == 0) return const SizedBox.shrink();

                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: FractionalTranslation(
                        translation: Offset(0, 1.0 - _sheetAnim.value),
                        child: child,
                      ),
                    );
                  },
                  child: _buildBottomSheet(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    if (_selectedCrime != null) {
      return _CrimeDetailSheet(
        crime: _selectedCrime!,
        onClose: () {
          setState(() => _selectedCrime = null);
          _hideSheet();
        },
      );
    }

    if (_routeResponse != null) {
      return _RouteSheet(
        response: _routeResponse!,
        selectedIndex: _selectedRouteIndex,
        onSelectRoute: (index) {
          setState(() {
            _selectedRouteIndex = index;
            _drawRoutes(_routeResponse!);
          });

          final route = _routeResponse!.routes[index];

          final points = route.geometry
              .where((p) => p.length >= 2)
              .map((p) => LatLng(p[0], p[1]))
              .toList();

          if (points.isNotEmpty) _fitPolylineBounds(points);
        },
        routeColor: _routeColor,
        riskColor: _riskColor,
        onClose: () {
          setState(() {
            _routeResponse = null;
            _polylines.clear();
          });

          _hideSheet();
        },
      );
    }

    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KOMPAKT HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.fromCtrl,
    required this.toCtrl,
    required this.fromFocus,
    required this.toFocus,
    required this.loading,
    required this.hasPoints,
    required this.onCalculate,
    required this.onClear,
  });

  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final FocusNode fromFocus;
  final FocusNode toFocus;
  final bool loading;
  final bool hasPoints;
  final VoidCallback onCalculate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      color: _kCard,
      padding: EdgeInsets.fromLTRB(12, top + 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Güvenli Rota',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              if (hasPoints)
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    foregroundColor: _kPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Temizle',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kPrimary,
                      ),
                    ),
                    Container(
                      width: 1.5,
                      height: 14,
                      color: Colors.grey,
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _InlineInput(
                        controller: fromCtrl,
                        focusNode: fromFocus,
                        hint: 'Nereden?',
                      ),
                      Divider(
                        height: 10,
                        thickness: 0.5,
                        color: Colors.grey.shade300,
                      ),
                      _InlineInput(
                        controller: toCtrl,
                        focusNode: toFocus,
                        hint: 'Nereye?',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: loading ? null : onCalculate,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: loading ? _kPrimary.withOpacity(0.6) : _kPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
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

class _InlineInput extends StatelessWidget {
  const _InlineInput({
    required this.controller,
    required this.focusNode,
    required this.hint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF1A1A2E),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade400,
        ),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB COLUMN
// ─────────────────────────────────────────────────────────────────────────────
class _FabColumn extends StatelessWidget {
  const _FabColumn({
    required this.mode,
    required this.heatmapVisible,
    required this.onModeChanged,
    required this.onHeatmapToggle,
  });

  final String mode;
  final bool heatmapVisible;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onHeatmapToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeBtn(
                icon: Icons.directions_car,
                selected: mode == 'car',
                onTap: () => onModeChanged('car'),
              ),
              _ModeBtn(
                icon: Icons.directions_walk,
                selected: mode == 'walk',
                onTap: () => onModeChanged('walk'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _FabIcon(
          icon: heatmapVisible ? Icons.layers : Icons.layers_clear,
          active: heatmapVisible,
          onTap: onHeatmapToggle,
        ),
      ],
    );
  }
}

class _ModeBtn extends StatelessWidget {
  const _ModeBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: selected ? _kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _FabIcon extends StatelessWidget {
  const _FabIcon({
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
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 20,
            color: active ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUTE SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _RouteSheet extends StatelessWidget {
  const _RouteSheet({
    required this.response,
    required this.selectedIndex,
    required this.onSelectRoute,
    required this.routeColor,
    required this.riskColor,
    required this.onClose,
  });

  final UIRouteResponse response;
  final int? selectedIndex;
  final ValueChanged<int> onSelectRoute;
  final Color Function(int) routeColor;
  final Color Function(String) riskColor;
  final VoidCallback onClose;

  static const _labels = ['En Kısa', 'En Güvenli', 'Alternatif'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Rotalar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: Colors.grey,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 140,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              scrollDirection: Axis.horizontal,
              itemCount: response.routes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final route = response.routes[i];
                final isSelected = selectedIndex == i;
                final color = routeColor(i);
                final label = i < _labels.length ? _labels[i] : 'Rota ${i + 1}';

                return GestureDetector(
                  onTap: () => onSelectRoute(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 148,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? color.withOpacity(0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: color,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(route.totalLengthM / 1000).toStringAsFixed(2)} km',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Risk: % ${route.totalRisk.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: riskColor(route.riskLevel).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${route.riskLevel} %${route.totalRisk.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: riskColor(route.riskLevel),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CRIME DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _CrimeDetailSheet extends StatelessWidget {
  const _CrimeDetailSheet({
    required this.crime,
    required this.onClose,
  });

  final CrimePoint crime;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final date = crime.crimeDate != null
        ? '${crime.crimeDate!.day.toString().padLeft(2, '0')}/'
            '${crime.crimeDate!.month.toString().padLeft(2, '0')}/'
            '${crime.crimeDate!.year}'
        : 'Bilinmiyor';

    final time = crime.crimeDate != null
        ? '${crime.crimeDate!.hour.toString().padLeft(2, '0')}:'
            '${crime.crimeDate!.minute.toString().padLeft(2, '0')}'
        : '--:--';

    final description = crime.description?.trim().isNotEmpty == true
        ? crime.description!.trim()
        : 'Ek açıklama mevcut değil.';

    return Container(
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
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
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
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
                child: _InfoPill(
                  icon: Icons.calendar_today_rounded,
                  label: 'Tarih',
                  value: date,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoPill(
                  icon: Icons.access_time_rounded,
                  label: 'Saat',
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
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE9E9EF),
              ),
            ),
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF2D2D2D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE9E9EF),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: _kPrimary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
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
