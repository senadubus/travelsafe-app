import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:safe_journey/core/api_client.dart';
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
  _DayOption(label: '7 d', days: 7),
  _DayOption(label: '1 mo', days: 30),
  _DayOption(label: '3 mo', days: 90),
  _DayOption(label: '6 mo', days: 180),
  _DayOption(label: '1 yr', days: 365),
];

// ─── page ─────────────────────────────────────────────────────────────────────

class HeatmapPage extends StatefulWidget {
  const HeatmapPage({super.key});

  @override
  State<HeatmapPage> createState() => _HeatmapPageState();
}

class _HeatmapPageState extends State<HeatmapPage> {
  // ── filter state ─────────────────────────────────────────────────────────
  String _selectedType = 'All';
  int _selectedDays = 30;
  Timer? _markerDebounce;

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
  Set<Marker> _markers = {};
  bool _showMarkers = false;

  LatLngBounds? _lastMarkerBounds;
  int? _lastMarkerDays;
  String? _lastMarkerType;

  static const _initialCamera = CameraPosition(
    target: LatLng(41.87811, -87.6298),
    zoom: 11.0,
  );

  @override
  void initState() {
    super.initState();
    _crimeService = CrimeService(_apiClient);

    _heatCtrl = HeatmapController(
      days: _selectedDays,
      crimeType: null,
    );
    _tileOverlay = _buildOverlay();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _heatCtrl.disposeAll();
    _markerDebounce?.cancel();
    super.dispose();
  }

  // ── tile overlay ─────────────────────────────────────────────────────────
  bool _boundsAlmostSame(LatLngBounds a, LatLngBounds b) {
    const eps = 0.0015;
    return (a.southwest.latitude - b.southwest.latitude).abs() < eps &&
        (a.southwest.longitude - b.southwest.longitude).abs() < eps &&
        (a.northeast.latitude - b.northeast.latitude).abs() < eps &&
        (a.northeast.longitude - b.northeast.longitude).abs() < eps;
  }

  TileOverlay _buildOverlay() {
    return TileOverlay(
      tileOverlayId: TileOverlayId('heat_${_selectedType}_$_selectedDays'),
      tileProvider: HeatTileProvider(
        api: _apiClient,
        controller: _heatCtrl,
      ),
      transparency: 0.0,
      visible: true,
      zIndex: 999,
    );
  }

  Set<TileOverlay> _buildTileOverlays() {
    if (!_heatmapVisible || _tileOverlay == null || _showMarkers) return {};
    return {_tileOverlay!};
  }

  Future<void> _onMapCreated(GoogleMapController c) async {
    _mapController = c;
    _heatCtrl.attachMap(c);

    final bounds = await c.getVisibleRegion();
    final zoom = await c.getZoomLevel();

    if (!mounted) return;

    setState(() {
      _currentZoom = zoom;
      _tileOverlay = _buildOverlay();
    });

    await _onCameraIdle();
    await c.clearTileCache(_tileOverlay!.tileOverlayId);
    if (_showMarkers) {
      _markerDebounce?.cancel();
      _markerDebounce = Timer(const Duration(milliseconds: 300), () async {
        await _loadCrimeMarkers(bounds);
      });
      return;
    }
  }

  // ── camera idle → refresh clusters ──────────────────────────────────────
  Future<void> _onCameraIdle() async {
    if (_mapController == null) return;

    final bounds = await _mapController!.getVisibleRegion();
    final zoom = await _mapController!.getZoomLevel();

    if (!mounted) return;

    setState(() {
      _currentZoom = zoom;
    });

    // 🔥 MARKER GEÇİŞİ
    final showMarkersNow = zoom >= 16;

    if (showMarkersNow != _showMarkers) {
      setState(() {
        _showMarkers = showMarkersNow;
      });
    }

    // ───────────── MARKER MODE ─────────────
    if (_showMarkers) {
      await _loadCrimeMarkers(bounds);
      return; // heatmap çalışmasın
    }

    // ───────────── HEATMAP MODE ─────────────
    setState(() {
      _loadingClusters = true;
    });

    try {
      final result = await _crimeService.fetchHeatClusters(
        sw: bounds.southwest,
        ne: bounds.northeast,
        zoom: zoom.round(),
        days: _selectedDays,
        crimeType: _selectedType == 'All' ? null : _selectedType.toUpperCase(),
      );

      if (mounted) {
        setState(() => _clusters = result);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loadingClusters = false);
    }
  }

  // ── apply filters ────────────────────────────────────────────────────────
  Future<void> _applyFilters() async {
    _heatCtrl.days = _selectedDays;
    _heatCtrl.crimeType =
        _selectedType == 'All' ? null : _selectedType.toUpperCase();

    final oldOverlayId = _tileOverlay?.tileOverlayId;

    setState(() {
      _tileOverlay = _buildOverlay();
    });

    if (_mapController != null && oldOverlayId != null) {
      await _mapController!.clearTileCache(oldOverlayId);
    }

    if (_mapController != null && _tileOverlay != null) {
      await _mapController!.clearTileCache(_tileOverlay!.tileOverlayId);
    }

    await _onCameraIdle();
  }

  // ── recenter ─────────────────────────────────────────────────────────────
  void _recenter() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_initialCamera),
    );
  }

  // ── derived: area risk ───────────────────────────────────────────────────
  int get _totalIncidents => _clusters.fold(0, (s, c) => s + c.count);

  _RiskLevel get _riskLevel {
    if (_currentZoom >= 14) {
      if (_clusters.isEmpty) return _RiskLevel.unknown;
      final n = _totalIncidents;
      if (n > 500) return _RiskLevel.high;
      if (n > 150) return _RiskLevel.medium;
      return _RiskLevel.low;
    }
    return _RiskLevel.unknown;
  }

  Future<void> _loadCrimeMarkers(LatLngBounds bounds) async {
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
        crimeType: _selectedType == 'All' ? null : _selectedType.toUpperCase(),
        limit: 80,
      );

      final markers = points.map((p) {
        return Marker(
          markerId: MarkerId('crime_${p.lat}_${p.lng}'),
          position: LatLng(p.lat, p.lng),
          infoWindow: InfoWindow(
            title: p.crime,
            snippet: p.description ?? '',
          ),
        );
      }).toSet();

      if (!mounted) return;

      setState(() {
        _markers = markers;
      });
    } catch (e) {
      print("marker error: $e");
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────────
          GoogleMap(
            onMapCreated: _onMapCreated,
            onCameraIdle: _onCameraIdle,
            initialCameraPosition: _initialCamera,
            tileOverlays: _buildTileOverlays(),
            markers: _showMarkers ? _markers : {},
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // ── Filter bar (top) ────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _FilterBar(
              selectedType: _selectedType,
              selectedDays: _selectedDays,
              onTypeChanged: (v) async {
                setState(() => _selectedType = v);
                await _applyFilters();
              },
              onDaysChanged: (v) async {
                setState(() => _selectedDays = v);
                await _applyFilters();
              },
            ),
          ),

          // ── FABs (right side) ──────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 148,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapFab(
                  icon: Icons.my_location,
                  tooltip: 'My location',
                  onTap: _recenter,
                ),
                const SizedBox(height: 8),
                _MapFab(
                  icon: _heatmapVisible ? Icons.layers : Icons.layers_clear,
                  tooltip: _heatmapVisible ? 'Hide heatmap' : 'Show heatmap',
                  active: _heatmapVisible,
                  onTap: () async {
                    setState(() {
                      _heatmapVisible = !_heatmapVisible;
                    });

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

          // ── Bottom summary card ────────────────────────────────────────
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _SummaryCard(
              riskLevel: _riskLevel,
              totalIncidents: _totalIncidents,
              selectedType: _selectedType,
              selectedDays: _selectedDays,
              isLoading: _loadingClusters,
              zoom: _currentZoom,
            ),
          ),
        ],
      ),
    );
  }
}

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
          // ── App bar row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.explore, color: _kPrimary, size: 18),
                ),
                const SizedBox(width: 8),
                RichText(
                  text: const TextSpan(children: [
                    TextSpan(
                      text: 'Travel',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: _kPrimary,
                      ),
                    ),
                    TextSpan(
                      text: 'Safe',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: _kOrange,
                      ),
                    ),
                  ]),
                ),
                const Spacer(),
                Text(
                  'Chicago, IL',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // ── Crime type chips ─────────────────────────────────────────
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kCrimeTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final type = _kCrimeTypes[i];
                final sel = type == selectedType;
                return _FilterChip(
                  label: type,
                  selected: sel,
                  onTap: () => onTypeChanged(type),
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // ── Day range chips ──────────────────────────────────────────
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kDayOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final opt = _kDayOptions[i];
                final sel = opt.days == selectedDays;
                return _FilterChip(
                  label: opt.label,
                  selected: sel,
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

// ─── Small reusable filter chip ───────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
          vertical: small ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accentColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: small ? 11 : 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : Colors.grey[700],
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
              color: active ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.riskLevel,
    required this.totalIncidents,
    required this.selectedType,
    required this.selectedDays,
    required this.isLoading,
    required this.zoom,
  });

  final _RiskLevel riskLevel;
  final int totalIncidents;
  final String selectedType;
  final int selectedDays;
  final bool isLoading;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (riskLevel) {
      _RiskLevel.high => ('High Risk', Colors.red[600]!, Icons.warning_rounded),
      _RiskLevel.medium => (
          'Moderate Risk',
          Colors.orange[700]!,
          Icons.info_outline
        ),
      _RiskLevel.low => (
          'Low Risk',
          Colors.green[600]!,
          Icons.check_circle_outline
        ),
      _RiskLevel.unknown => ('Scanning...', Colors.grey[500]!, Icons.radar),
    };

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: isLoading
            ? const SizedBox(
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalIncidents incidents · $selectedType · ${_daysLabel(selectedDays)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          zoom >= 15
                              ? 'Zoomed in: individual incidents'
                              : 'Zoomed out: heatmap overlay active',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (totalIncidents > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$totalIncidents',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  String _daysLabel(int days) {
    if (days >= 365) return '1 year';
    if (days >= 180) return '6 months';
    if (days >= 90) return '3 months';
    if (days >= 30) return '1 month';
    return '7 days';
  }
}

// ─── helpers ──────────────────────────────────────────────────────────────────

enum _RiskLevel { high, medium, low, unknown }

class _DayOption {
  const _DayOption({
    required this.label,
    required this.days,
  });

  final String label;
  final int days;
}
