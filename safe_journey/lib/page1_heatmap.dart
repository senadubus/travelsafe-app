import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

import '../../core/api.dart';
import '../../data/services/crime_service.dart';

// --------------- ANA SAYFA ---------------
class HeatmapHomePage extends StatefulWidget {
  const HeatmapHomePage({super.key});

  @override
  State<HeatmapHomePage> createState() => _HeatmapHomePageState();
}

class _HeatmapHomePageState extends State<HeatmapHomePage>
    with TickerProviderStateMixin {
  // -- State --
  String _selectedCrimeLabel = 'Tümü';
  int _selectedYear = 2024;
  bool _filterPanelOpen = false;
  bool _isLoading = false;
  late final CrimeService _service = CrimeService(ApiClient());

  Timer? _debounce;
  Set<Circle> _circles = {};

  final List<({String label, String? value})> _crimeTypes = [
    (label: 'Tümü', value: null),
    (label: 'Hırsızlık', value: 'THEFT'),
    (label: 'Saldırı', value: 'ASSAULT'),
    (label: 'Darp', value: 'BATTERY'),
    (label: 'Dolandırıcılık', value: 'DECEPTIVE PRACTICE'),
    (label: 'Vandalizm', value: 'CRIMINAL DAMAGE'),
    (label: 'Uyuşturucu', value: 'NARCOTICS'),
    (label: 'Gasp', value: 'ROBBERY'),
    (label: 'Konut/İşyeri Soygunu', value: 'BURGLARY'),
    (label: 'Araç Hırsızlığı', value: 'MOTOR VEHICLE THEFT'),
    (label: 'Silah İhlali', value: 'WEAPONS VIOLATION'),
  ];

  final List<int> _years = [2019, 2020, 2021, 2022, 2023, 2024, 2025];

  late AnimationController _filterAnim;
  late AnimationController _fabAnim;

  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();

    _filterAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _filterAnim.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadData);
  }

  Future<void> _loadData() async {
    if (_mapController == null) return;

    setState(() => _isLoading = true);

    try {
      final bounds = await _mapController!.getVisibleRegion();
      final zoom = (await _mapController!.getZoomLevel()).round();

      final selectedValue =
          _crimeTypes.firstWhere((e) => e.label == _selectedCrimeLabel).value;

      final points = await _service.fetchHeat(
        sw: bounds.southwest,
        ne: bounds.northeast,
        zoom: zoom,
        maxPoints: 3000,
        crimeType: selectedValue, // null ise service query’ye eklemez
        year: _selectedYear,
      );

      // intensity -> circle (heat hissi)
      final circles = <Circle>{};
      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        final intensity = p.intensity ?? 1;

        final opacity = (0.05 + intensity / 60.0).clamp(0.05, 0.35);
        final radius = (120 + intensity * 6).clamp(120, 650).toDouble();

        circles.add(
          Circle(
            circleId: CircleId('h_$i'),
            center: LatLng(p.lat, p.lng),
            radius: radius,
            fillColor: Colors.red.withOpacity(opacity),
            strokeWidth: 0,
          ),
        );
      }

      setState(() {
        _circles = circles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Heat verisi alınamadı: $e')),
        );
      }
    }
  }

  void _toggleFilterPanel() {
    setState(() => _filterPanelOpen = !_filterPanelOpen);
    if (_filterPanelOpen) {
      _filterAnim.forward();
    } else {
      _filterAnim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── 1. HARİTA ──────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(41.8781, -87.6298), // Chicago
                zoom: 11,
              ),
              mapType: MapType.hybrid,
              onMapCreated: (controller) {
                _mapController = controller;
                _loadData();
              },
              onCameraIdle: _scheduleLoad,
              circles: _circles,
              myLocationEnabled: false,
            ),
          ),

          // ── 2. TOP BAR + FİLTRE ─────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  onFilterTap: _toggleFilterPanel,
                  filterOpen: _filterPanelOpen,
                  selectedCrime: _selectedCrimeLabel,
                  selectedYear: _selectedYear,
                ),
                SizeTransition(
                  sizeFactor: CurvedAnimation(
                    parent: _filterAnim,
                    curve: Curves.easeOutCubic,
                  ),
                  child: _FilterPanel(
                    crimeTypes: _crimeTypes.map((e) => e.label).toList(),
                    years: _years,
                    selectedCrime: _selectedCrimeLabel,
                    selectedYear: _selectedYear,
                    onCrimeChanged: (v) {
                      setState(() => _selectedCrimeLabel = v);
                      _scheduleLoad();
                    },
                    onYearChanged: (v) {
                      setState(() => _selectedYear = v);
                      _scheduleLoad();
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── 4. STATS CHIP ─────────────────────────
          Positioned(
            left: 16,
            bottom: 100,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _fabAnim,
                curve: Curves.elasticOut,
              ),
              child: _StatsChip(
                totalIncidents: 1247,
                riskLevel: 'Orta',
              ),
            ),
          ),

          // ── 5. LOADING ───────────────────────────
          if (_isLoading)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(child: _LoadingPill()),
            ),
        ],
      ),
    );
  }
}

// ── TOP BAR ──────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onFilterTap;
  final bool filterOpen;
  final String selectedCrime;
  final int selectedYear;

  const _TopBar({
    required this.onFilterTap,
    required this.filterOpen,
    required this.selectedCrime,
    required this.selectedYear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.purple.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.purple, AppColors.orange],
              ),
            ),
            child:
                const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SafeJourney',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.3)),
                Text('$selectedCrime • $selectedYear',
                    style: TextStyle(
                        color: AppColors.purple.withOpacity(0.8),
                        fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onFilterTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: filterOpen
                    ? const LinearGradient(
                        colors: [AppColors.purple, AppColors.orange])
                    : null,
                color: filterOpen ? null : AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: filterOpen
                        ? Colors.transparent
                        : AppColors.purple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(filterOpen ? Icons.close_rounded : Icons.tune_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(filterOpen ? 'Kapat' : 'Filtre',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── FİLTRE PANELİ ──────────────────────────────────────────────
class _FilterPanel extends StatelessWidget {
  final List<String> crimeTypes;
  final List<int> years;
  final String selectedCrime;
  final int selectedYear;
  final ValueChanged<String> onCrimeChanged;
  final ValueChanged<int> onYearChanged;

  const _FilterPanel({
    required this.crimeTypes,
    required this.years,
    required this.selectedCrime,
    required this.selectedYear,
    required this.onCrimeChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.purple.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FilterLabel('Suç Tipi'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: crimeTypes.map((type) {
              final sel = type == selectedCrime;
              return GestureDetector(
                onTap: () => onCrimeChanged(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? const LinearGradient(
                            colors: [AppColors.purple, AppColors.orange])
                        : null,
                    color: sel ? null : AppColors.surface2,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: sel ? Colors.transparent : Colors.white12),
                  ),
                  child: Text(type,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.white54,
                          fontSize: 12,
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const _FilterLabel('Yıl'),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: years.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final yr = years[i];
                final sel = yr == selectedYear;
                return GestureDetector(
                  onTap: () => onYearChanged(yr),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: sel
                          ? const LinearGradient(
                              colors: [AppColors.purple, AppColors.orange])
                          : null,
                      color: sel ? null : AppColors.surface2,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: sel ? Colors.transparent : Colors.white12),
                    ),
                    alignment: Alignment.center,
                    child: Text('$yr',
                        style: TextStyle(
                            color: sel ? Colors.white : Colors.white54,
                            fontSize: 13,
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.normal)),
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

// ── STATS CHIP ────────────────────────────────────────────────
class _StatsChip extends StatelessWidget {
  final int totalIncidents;
  final String riskLevel;

  const _StatsChip({required this.totalIncidents, required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.analytics_rounded,
              color: AppColors.orange, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$totalIncidents olay',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              Text('Risk: $riskLevel',
                  style:
                      const TextStyle(color: AppColors.orange, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── LOADING PILL ──────────────────────────────────────────────
class _LoadingPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.purple.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: AppColors.purple.withOpacity(0.2), blurRadius: 20)
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.purple)),
          SizedBox(width: 10),
          Text('Veriler yükleniyor...',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── KÜÇÜK YARDIMCILAR ─────────────────────────────────────────
class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8),
    );
  }
}

// ── RENKLER ───────────────────────────────────────────────────
class AppColors {
  static const bg = Color(0xFF0F0F1E);
  static const surface = Color(0xFF1A1A2E);
  static const surface2 = Color(0xFF252538);
  static const purple = Color(0xFF9C27B0);
  static const orange = Color(0xFFFF7043);
  static const green = Color(0xFF4CAF50);
  static const red = Color(0xFFFF5722);
}
