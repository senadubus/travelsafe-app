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
  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _markerIconsReady = false;

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
  CrimePoint? _selectedCrime;

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

    _markerIcons['VIOLENCE'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/VIOLENCE.png',
    );

    _markerIcons['SEXUAL'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/SEXUAL.png',
    );

    _markerIcons['BURGLARY'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/BURGLARY.png',
    );

    _markerIcons['THEFT'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/THEFT.png',
    );

    _markerIcons['ROBBERY'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/ROBBERY.png',
    );

    _markerIcons['VEHICLE'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/VEHICLE.png',
    );

    _markerIcons['DRUG'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/DRUG.png',
    );

    _markerIcons['FIRE'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/FIRE.png',
    );

    _markerIcons['WEAPON'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/WEAPON.png',
    );

    _markerIcons['TRESPASS'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/TRESPASS.png',
    );

    _markerIcons['FRAUD'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/FRAUD.png',
    );

    _markerIcons['CHILD'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/CHILD.png',
    );

    _markerIcons['KIDNAPPING'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/KIDNAPPING.png',
    );

    _markerIcons['DOMESTIC'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/DOMESTIC.png',
    );

    _markerIcons['PUBLIC'] = await BitmapDescriptor.asset(
      config,
      'assets/markers/PUBLIC.png',
    );

    _markerIconsReady = true;
  }

  BitmapDescriptor _iconForCrime(String crime) {
    if (!_markerIconsReady) {
      return BitmapDescriptor.defaultMarker; // fallback
    }

    final key = getCrimeCategory(crime);
    return _markerIcons[key] ?? _markerIcons['PUBLIC']!;
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

    try {
      await _loadMarkerIcons();
    } catch (e) {
      debugPrint('ICON LOAD ERROR: $e');
    }

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

    // Marker Geçişi !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    final showMarkersNow = zoom >= 15;

    if (showMarkersNow != _showMarkers) {
      setState(() {
        _showMarkers = showMarkersNow;

        if (!_showMarkers) {
          _markers = {};
          _selectedCrime = null;
          _lastMarkerBounds = null;
          _lastMarkerDays = null;
          _lastMarkerType = null;
        }
      });
    }
    // ───────────── MARKER MODE ─────────────
    if (_showMarkers) {
      await _loadCrimeMarkers(bounds);
      return; // heatmap çalışmasın
    }

    // ───────────── HEATMAP MODE ─────────────
    setState(() {
      _selectedCrime = null;
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
      _selectedCrime = null;
      _markers = {};
      _lastMarkerBounds = null;
      _lastMarkerDays = null;
      _lastMarkerType = null;
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
        crimeType: _selectedType == 'All' ? null : _selectedType.toUpperCase(),
        limit: 80,
      );

      final markers = points.map((p) {
        return Marker(
          markerId: MarkerId('crime_${p.lat}_${p.lng}'),
          position: LatLng(p.lat, p.lng),
          icon: _iconForCrime(p.crime),
          onTap: () {
            setState(() {
              _selectedCrime = p;
            });
          },
          infoWindow: InfoWindow.noText,
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
            onTap: (_) {
              if (_selectedCrime != null) {
                setState(() {
                  _selectedCrime = null;
                });
              }
            },
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
          if (_selectedCrime != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 6,
              child: _CrimeDetailCard(
                crime: _selectedCrime!,
                onClose: () {
                  setState(() {
                    _selectedCrime = null;
                  });
                },
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
        (crime.description != null && crime.description!.trim().isNotEmpty)
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
                      color: _kOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: _kOrange,
                      size: 22,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F1F1F),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Incident details",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Description",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ],
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
