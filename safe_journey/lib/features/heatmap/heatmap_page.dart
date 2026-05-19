import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:safe_journey/core/api_client.dart';
import 'package:safe_journey/data/models/crime_point.dart';
import 'package:safe_journey/data/models/heat_cluster.dart';
import 'package:safe_journey/data/services/crime_service.dart';
import 'package:safe_journey/data/services/tile_overlay.dart';
import 'package:safe_journey/features/heatmap/heatmap_controller.dart';

// ─── constants ────────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF6B4FA0);
const _kOrange = Color(0xFFE8761A);

const _kCrimeTypes = <String>[
  'All',
  'Theft',
  'Assault',
  'Battery',
  'Burglary',
  'Robbery',
  'Narcotics',
  'Homicide',
];

const _kDayOptions = <_DayOption>[
  _DayOption(label: '7 g', days: 7),
  _DayOption(label: '1 ay', days: 30),
  _DayOption(label: '3 ay', days: 90),
  _DayOption(label: '6 ay', days: 180),
  _DayOption(label: '1 yıl', days: 365),
];

String crimeCategory(String crime) {
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

Color crimeCategoryColor(String crime) {
  switch (crimeCategory(crime)) {
    case 'VIOLENCE':
      return const Color(0xFFE8761A);
    case 'SEXUAL':
      return const Color(0xFFD81B60);
    case 'BURGLARY':
      return const Color(0xFF455A64);
    case 'THEFT':
      return const Color(0xFF6B4FA0);
    case 'ROBBERY':
      return const Color(0xFFC62828);
    case 'VEHICLE':
      return const Color(0xFF1976D2);
    case 'DRUG':
      return const Color(0xFF2E7D32);
    case 'FIRE':
      return const Color(0xFFFF6D00);
    case 'WEAPON':
      return const Color(0xFF5D4037);
    case 'TRESPASS':
      return const Color(0xFF616161);
    case 'FRAUD':
      return const Color(0xFF00897B);
    case 'CHILD':
      return const Color(0xFFAD1457);
    case 'KIDNAPPING':
      return const Color(0xFF6A1B9A);
    case 'DOMESTIC':
      return const Color(0xFFEF6C00);
    default:
      return const Color(0xFF6B4FA0);
  }
}

// ─── page ─────────────────────────────────────────────────────────────────────

class HeatmapPage extends StatefulWidget {
  const HeatmapPage({super.key});

  @override
  State<HeatmapPage> createState() => _HeatmapPageState();
}

class _HeatmapPageState extends State<HeatmapPage>
    with TickerProviderStateMixin {
  // ── filter state ─────────────────────────────────────────────────────────
  String _selectedType = 'All';
  int _selectedDays = 365;

  // ── services ─────────────────────────────────────────────────────────────
  final ApiClient _apiClient = ApiClient();
  late final CrimeService _crimeService;
  late final HeatmapController _heatCtrl;

  // ── map state ────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  TileOverlay? _tileOverlay;
  bool _heatmapVisible = true;
  double _currentZoom = 11.0;

  // ── cluster / summary state ──────────────────────────────────────────────
  List<HeatCluster> _clusters = [];
  bool _loadingClusters = false;

  // ── marker state ─────────────────────────────────────────────────────────
  Timer? _markerDebounce;
  int _markerRequestId = 0;
  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _markerIconsReady = false;
  Set<Marker> _markers = {};
  bool _showMarkers = false;
  CrimePoint? _selectedCrime;

  LatLngBounds? _lastMarkerBounds;
  int? _lastMarkerDays;
  String? _lastMarkerType;

  // ── animation ────────────────────────────────────────────────────────────
  late final AnimationController _sheetAnimCtrl;
  late final Animation<double> _sheetAnim;

  static const _initialCamera = CameraPosition(
    target: LatLng(41.87811, -87.6298),
    zoom: 11.0,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _crimeService = CrimeService(_apiClient);
    _heatCtrl = HeatmapController(days: _selectedDays, crimeType: null);
    _tileOverlay = _buildOverlay();

    _sheetAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sheetAnim = CurvedAnimation(
      parent: _sheetAnimCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    // Doğru sıra: önce timer → controller → map
    _markerDebounce?.cancel();
    _sheetAnimCtrl.dispose();
    _heatCtrl.disposeAll();
    _mapController?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sheet helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _showSheet() => _sheetAnimCtrl.forward();

  void _hideSheet() {
    _sheetAnimCtrl.reverse().then((_) {
      if (mounted) setState(() => _selectedCrime = null);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Marker icons — paralel yükleme (FIX #1)
  // ─────────────────────────────────────────────────────────────────────────

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

    // Paralel yükleme — seri await yerine Future.wait
    final icons = await Future.wait(
      keys.map((k) => BitmapDescriptor.asset(config, 'assets/markers/$k.png')),
    );

    for (int i = 0; i < keys.length; i++) {
      _markerIcons[keys[i]] = icons[i];
    }

    _markerIconsReady = true;
  }

  BitmapDescriptor _iconForCrime(String crime) {
    if (!_markerIconsReady) return BitmapDescriptor.defaultMarker;
    return _markerIcons[crimeCategory(crime)] ?? _markerIcons['PUBLIC']!;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tile overlay
  // ─────────────────────────────────────────────────────────────────────────

  TileOverlay _buildOverlay() => TileOverlay(
        tileOverlayId: TileOverlayId('heat_${_selectedType}_$_selectedDays'),
        tileProvider: HeatTileProvider(api: _apiClient, controller: _heatCtrl),
        transparency: 0.0,
        visible: true,
        zIndex: 999,
      );

  Set<TileOverlay> _buildTileOverlays() {
    if (!_heatmapVisible || _tileOverlay == null || _showMarkers) return {};
    return {_tileOverlay!};
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Map created
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onMapCreated(GoogleMapController c) async {
    _mapController = c;
    _heatCtrl.attachMap(c);

    // Icon yüklemesini arka planda başlat, map'i bloklamadan devam et
    _loadMarkerIcons().catchError((e) => debugPrint('Icon load error: $e'));

    setState(() => _tileOverlay = _buildOverlay());

    // Sadece bir kez clearTileCache — _onCameraIdle içinde tekrar çağırma
    await c.clearTileCache(_tileOverlay!.tileOverlayId);
    await _onCameraIdle();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Camera idle (FIX #2 — marker modunda cluster fetch yok)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onCameraIdle() async {
    if (_mapController == null) return;

    final zoom = await _mapController!.getZoomLevel();
    final bounds = await _mapController!.getVisibleRegion();

    if (!mounted) return;

    setState(() => _currentZoom = zoom);

    final showMarkersNow = zoom >= 15;

    // Mod değişimi
    if (showMarkersNow != _showMarkers) {
      setState(() {
        _showMarkers = showMarkersNow;
        if (!_showMarkers) {
          // Heatmap moduna geçiş: marker state temizle
          _markerRequestId++;
          _markerDebounce?.cancel();
          _markers = {};
          _lastMarkerBounds = null;
          _lastMarkerDays = null;
          _lastMarkerType = null;
          // Crime card kapanıyorsa animate et
          if (_selectedCrime != null) {
            _selectedCrime = null;
            _sheetAnimCtrl.reverse();
          }
        }
      });
    }

    // ── Marker modu ───────────────────────────────────────────────────────
    if (_showMarkers) {
      _markerDebounce?.cancel();
      _markerDebounce = Timer(const Duration(milliseconds: 350), () async {
        if (!mounted || _mapController == null) return;
        final latestBounds = await _mapController!.getVisibleRegion();
        await _loadCrimeMarkers(latestBounds);
      });
      return; // Cluster fetch yapma
    }

    // ── Heatmap modu — cluster fetch ──────────────────────────────────────
    if (mounted) setState(() => _loadingClusters = true);

    try {
      final result = await _crimeService.fetchHeatClusters(
        sw: bounds.southwest,
        ne: bounds.northeast,
        zoom: zoom.round(),
        days: _selectedDays,
        crimeType: _selectedType == 'All' ? null : _selectedType.toUpperCase(),
      );
      if (mounted) setState(() => _clusters = result);
    } catch (e) {
      debugPrint('Cluster fetch error: $e');
    } finally {
      if (mounted) setState(() => _loadingClusters = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Crime markers (FIX #3 — requestId önce increment edildi)
  // ─────────────────────────────────────────────────────────────────────────

  bool _boundsAlmostSame(LatLngBounds a, LatLngBounds b) {
    const eps = 0.0015;
    return (a.southwest.latitude - b.southwest.latitude).abs() < eps &&
        (a.southwest.longitude - b.southwest.longitude).abs() < eps &&
        (a.northeast.latitude - b.northeast.latitude).abs() < eps &&
        (a.northeast.longitude - b.northeast.longitude).abs() < eps;
  }

  /// Zoom'a göre temel offset mesafesi.
  /// zoom 15 → ~0.00035°, her zoom artışında yarıya iner.
  double _baseOffset() {
    const base = 0.00035;
    final zoomDiff = (_currentZoom.round() - 15).clamp(0, 8);
    return base / (1 << zoomDiff);
  }

  /// Basit sin/cos
  double _msin(double x) {
    x = x % (2 * 3.14159265);
    if (x > 3.14159265) x -= 2 * 3.14159265;
    final x2 = x * x;
    return x * (1 - x2 / 6 * (1 - x2 / 20 * (1 - x2 / 42)));
  }

  double _mcos(double x) => _msin(x + 3.14159265 / 2);

  /// Yelpaze dağılımı: ikonları eşit açılarla merkez etrafında yayar.
  /// Tek ikon → merkez. İki → karşılıklı. Daha fazla → tam daire.
  List<LatLng> _spreadPositions(int count, double lat, double lng) {
    if (count <= 1) return [LatLng(lat, lng)];

    final positions = <LatLng>[];

    final base = _baseOffset();
    const lngScale = 1.45;

    // Çok fazla marker varsa biri merkezde kalsın
    if (count >= 10) {
      positions.add(LatLng(lat, lng));
    }

    final remaining = count - positions.length;

    final innerCount = remaining <= 8 ? remaining : 8;
    final outerCount = remaining - innerCount;

    void addRing({
      required int ringCount,
      required double radius,
      required double startAngle,
    }) {
      if (ringCount <= 0) return;

      final step = 2 * 3.14159265 / ringCount;

      for (int i = 0; i < ringCount; i++) {
        final angle = startAngle + i * step;

        positions.add(
          LatLng(
            lat + radius * _msin(angle),
            lng + radius * lngScale * _mcos(angle),
          ),
        );
      }
    }

    addRing(
      ringCount: innerCount,
      radius: base * 1.15,
      startAngle: -3.14159265 / 2,
    );

    addRing(
      ringCount: outerCount,
      radius: base * 2.15,
      startAngle: -3.14159265 / 2 + 3.14159265 / outerCount.clamp(1, 999),
    );

    return positions.take(count).toList();
  }

  Future<void> _loadCrimeMarkers(LatLngBounds bounds) async {
    if (!_showMarkers) return;

    // önce requestId'yi artır, sonra cache kontrolü yap
    final requestId = ++_markerRequestId;

    if (!_markerIconsReady) {
      await _loadMarkerIcons();
    }

    final selectedCrimeType =
        _selectedType == 'All' ? null : _selectedType.toUpperCase();

    // Cache hit — hiçbir şey değişmediyse atla
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

      // Stale response kontrolü
      if (!mounted || !_showMarkers || requestId != _markerRequestId) return;

      // Aynı koordinata düşen noktaları grupla (lat+lng string key)
      final Map<String, List<int>> groups = {};
      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        final key = '${p.lat.toStringAsFixed(6)},${p.lng.toStringAsFixed(6)}';
        groups.putIfAbsent(key, () => []).add(i);
      }

      final Set<Marker> markers = {};

      for (final indices in groups.values) {
        final positions = _spreadPositions(
          indices.length,
          points[indices.first].lat,
          points[indices.first].lng,
        );

        for (int j = 0; j < indices.length; j++) {
          final p = points[indices[j]];
          markers.add(Marker(
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
          ));
        }
      }

      setState(() => _markers = markers);
    } catch (e) {
      debugPrint('Marker load error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filters
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _applyFilters() async {
    _heatCtrl.days = _selectedDays;
    _heatCtrl.crimeType =
        _selectedType == 'All' ? null : _selectedType.toUpperCase();

    final oldOverlayId = _tileOverlay?.tileOverlayId;

    setState(() {
      _tileOverlay = _buildOverlay();
      _markers = {};
      _lastMarkerBounds = null;
      _lastMarkerDays = null;
      _lastMarkerType = null;
      // Crime card'ı kapatmak için state sıfırla, animate eder
      if (_selectedCrime != null) {
        _selectedCrime = null;
        _sheetAnimCtrl.reverse();
      }
    });

    if (_mapController != null && oldOverlayId != null) {
      await _mapController!.clearTileCache(oldOverlayId);
    }
    if (_mapController != null && _tileOverlay != null) {
      await _mapController!.clearTileCache(_tileOverlay!.tileOverlayId);
    }

    await _onCameraIdle();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _recenter() => _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(_initialCamera),
      );

  int get _totalIncidents => _clusters.fold(0, (s, c) => s + c.count);

  _RiskLevel get _riskLevel {
    if (_currentZoom < 14) return _RiskLevel.unknown;
    final n = _totalIncidents;
    if (n > 500) return _RiskLevel.high;
    if (n > 150) return _RiskLevel.medium;
    return _RiskLevel.low;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map (tam ekran) ──────────────────────────────────────
          GoogleMap(
            onMapCreated: _onMapCreated,
            onCameraIdle: _onCameraIdle,
            onTap: (_) {
              if (_selectedCrime != null) _hideSheet();
            },
            initialCameraPosition: _initialCamera,
            tileOverlays: _buildTileOverlays(),
            markers: _showMarkers ? _markers : {},
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // ── Filter bar ──────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _FilterBar(
              selectedType: _selectedType,
              selectedDays: _selectedDays,
              onTypeChanged: (v) {
                setState(() => _selectedType = v);
                _applyFilters();
              },
              onDaysChanged: (v) {
                setState(() => _selectedDays = v);
                _applyFilters();
              },
            ),
          ),

          // ── FAB grubu — sağ, sheet'e göre kayar ────────────────────────
          AnimatedBuilder(
            animation: _sheetAnim,
            builder: (context, child) {
              final sheetH = _sheetAnim.value * _kCrimeSheetHeight;
              return Positioned(
                right: 12,
                bottom: sheetH + 12,
                child: child!,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapFab(
                  icon: Icons.my_location,
                  tooltip: 'Merkeze dön',
                  onTap: _recenter,
                ),
                const SizedBox(height: 8),
                _MapFab(
                  icon: _heatmapVisible ? Icons.layers : Icons.layers_clear,
                  tooltip: _heatmapVisible ? 'Heatmap gizle' : 'Heatmap göster',
                  active: _heatmapVisible,
                  onTap: () async {
                    setState(() => _heatmapVisible = !_heatmapVisible);
                    if (_heatmapVisible &&
                        _mapController != null &&
                        _tileOverlay != null) {
                      await _mapController!
                          .clearTileCache(_tileOverlay!.tileOverlayId);
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Crime detail bottom sheet ───────────────────────────────────
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
            child: _selectedCrime != null
                ? _CrimeDetailSheet(
                    crime: _selectedCrime!,
                    onClose: _hideSheet,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── Sabit yükseklikler ───────────────────────────────────────────────────────

const double _kFilterBarHeight = 110.0;
const double _kCrimeSheetHeight = 220.0;

// ─── Filter Bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedType,
    required this.selectedDays,
    required this.onTypeChanged,
    required this.onDaysChanged,
  });

  final String selectedType;
  final int selectedDays;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<int> onDaysChanged;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: top + 4, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.explore, color: _kPrimary, size: 16),
                ),
                const SizedBox(width: 8),
                RichText(
                  text: const TextSpan(children: [
                    TextSpan(
                      text: 'Travel',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: _kPrimary,
                      ),
                    ),
                    TextSpan(
                      text: 'Safe',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: _kOrange,
                      ),
                    ),
                  ]),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 2),
                    Text(
                      'Chicago, IL',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 6),

          // Crime type chips
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kCrimeTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final type = _kCrimeTypes[i];
                return _Chip(
                  label: type,
                  selected: type == selectedType,
                  onTap: () => onTypeChanged(type),
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // Day range chips
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kDayOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final opt = _kDayOptions[i];
                return _Chip(
                  label: opt.label,
                  selected: opt.days == selectedDays,
                  small: true,
                  accentColor: _kOrange,
                  onTap: () => onDaysChanged(opt.days),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.small = false,
    this.accentColor = _kPrimary,
  });

  final String label;
  final bool selected;
  final bool small;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: small ? 10 : 12,
          vertical: small ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accentColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: small ? 11 : 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

// ─── Map FAB ──────────────────────────────────────────────────────────────────

class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
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
              color: active ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Crime Detail Sheet ───────────────────────────────────────────────────────

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

    final description = (crime.description?.trim().isNotEmpty == true)
        ? crime.description!.trim()
        : 'Ek açıklama mevcut değil.';

    return Container(
      height: _kCrimeSheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
          // Handle
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

          // Başlık
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _kOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                      'assets/markers/${crimeCategory(crime.crime)}.png',
                      fit: BoxFit.contain, errorBuilder: (_, __, ___) {
                    return Icon(Icons.report_problem_outlined,
                        color: crimeCategoryColor(crime.crime), size: 22);
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crime.crime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F1F1F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Olay detayı',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
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
                  child:
                      const Icon(Icons.close, size: 16, color: Colors.black54),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Tarih / Saat pills
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

          // Açıklama
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9E9EF)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Pill ────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9E9EF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _kPrimary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

enum _RiskLevel { high, medium, low, unknown }

class _DayOption {
  const _DayOption({required this.label, required this.days});
  final String label;
  final int days;
}
