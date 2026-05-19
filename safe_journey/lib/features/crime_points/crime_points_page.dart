import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:safe_journey/core/constants.dart';

const _kPrimary = Color(0xFF6B4FA0);
const _kOrange = Color(0xFFE8761A);
const _kDark = Color(0xFF1A0F33);

enum HeatmapMode {
  actual,
  predicted,
}

class PredictedHeatmapPage extends StatefulWidget {
  const PredictedHeatmapPage({super.key});

  @override
  State<PredictedHeatmapPage> createState() => _PredictedHeatmapPageState();
}

class _PredictedHeatmapPageState extends State<PredictedHeatmapPage> {
  GoogleMapController? _mapController;

  HeatmapMode _mode = HeatmapMode.actual;

  int _selectedDays = 365;
  String _selectedCrimeType = 'All';
  String _selectedWeekStart = '2025-08-04';

  Set<TileOverlay> _tileOverlays = {};

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(41.8781, -87.6298),
    zoom: 11.5,
  );

  final List<int> _dayOptions = [7, 30, 90, 180, 365];

  final List<String> _crimeTypes = [
    'All',
    'Theft',
    'Assault',
    'Battery',
    'Burglary',
    'Robbery',
    'Narcotics',
    'Homicide',
  ];

  final List<String> _predictionWeeks = [
    '2025-08-04',
  ];

  @override
  void initState() {
    super.initState();
    _refreshHeatmap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  String _buildTileUrl(int x, int y, int z) {
    if (_mode == HeatmapMode.predicted) {
      return '${Env.baseUrl}/tiles/predicted-heat/$z/$x/$y.png'
          '?week_start=$_selectedWeekStart';
    }

    final crimeParam = _selectedCrimeType == 'All'
        ? ''
        : '&crime_type=${Uri.encodeComponent(_selectedCrimeType)}';

    return '${Env.baseUrl}/tiles/heat/$z/$x/$y.png'
        '?days=$_selectedDays$crimeParam';
  }

  void _refreshHeatmap() {
    final overlayId = TileOverlayId(
      'heatmap_${_mode.name}_${DateTime.now().millisecondsSinceEpoch}',
    );

    setState(() {
      _tileOverlays = {
        TileOverlay(
          tileOverlayId: overlayId,
          tileProvider: BackendTileProvider(urlBuilder: _buildTileUrl),
          zIndex: 999,
          transparency: 0.0,
        ),
      };
    });
  }

  void _changeMode(HeatmapMode mode) {
    if (_mode == mode) return;

    setState(() {
      _mode = mode;
    });

    _refreshHeatmap();
  }

  void _recenter() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_initialCamera),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            mapType: MapType.normal,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            tileOverlays: _tileOverlays,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeatmapHeader(
                  mode: _mode,
                  onModeChanged: _changeMode,
                ),
                if (_mode == HeatmapMode.actual)
                  _ActualFilterBar(
                    selectedDays: _selectedDays,
                    dayOptions: _dayOptions,
                    selectedCrimeType: _selectedCrimeType,
                    crimeTypes: _crimeTypes,
                    onDaysChanged: (v) {
                      setState(() => _selectedDays = v);
                      _refreshHeatmap();
                    },
                    onCrimeChanged: (v) {
                      setState(() => _selectedCrimeType = v);
                      _refreshHeatmap();
                    },
                  )
                else
                  _PredictionFilterBar(
                    selectedWeekStart: _selectedWeekStart,
                    weeks: _predictionWeeks,
                    onWeekChanged: (v) {
                      setState(() => _selectedWeekStart = v);
                      _refreshHeatmap();
                    },
                  ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 104,
            child: Column(
              children: [
                _MapButton(
                  icon: Icons.add,
                  onTap: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.remove,
                  onTap: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.my_location,
                  onTap: _recenter,
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.refresh_rounded,
                  onTap: _refreshHeatmap,
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _LegendCard(mode: _mode),
          ),
        ],
      ),
    );
  }
}

class BackendTileProvider implements TileProvider {
  BackendTileProvider({
    required this.urlBuilder,
  });

  final String Function(int x, int y, int z) urlBuilder;

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    final z = zoom ?? 0;
    final url = urlBuilder(x, y, z);

    try {
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return Tile(256, 256, res.bodyBytes);
      }
    } catch (_) {}

    return Tile(256, 256, Uint8List(0));
  }
}

class _HeatmapHeader extends StatelessWidget {
  const _HeatmapHeader({
    required this.mode,
    required this.onModeChanged,
  });

  final HeatmapMode mode;
  final ValueChanged<HeatmapMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: top + 8, bottom: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Heatmap',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    mode == HeatmapMode.actual ? 'Actual' : 'Predicted',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _kPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      title: 'Gerçek Yoğunluk',
                      icon: Icons.local_fire_department_rounded,
                      selected: mode == HeatmapMode.actual,
                      onTap: () => onModeChanged(HeatmapMode.actual),
                    ),
                  ),
                  Expanded(
                    child: _ModeButton(
                      title: 'Tahmini Risk',
                      icon: Icons.auto_graph_rounded,
                      selected: mode == HeatmapMode.predicted,
                      onTap: () => onModeChanged(HeatmapMode.predicted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActualFilterBar extends StatelessWidget {
  const _ActualFilterBar({
    required this.selectedDays,
    required this.dayOptions,
    required this.selectedCrimeType,
    required this.crimeTypes,
    required this.onDaysChanged,
    required this.onCrimeChanged,
  });

  final int selectedDays;
  final List<int> dayOptions;
  final String selectedCrimeType;
  final List<String> crimeTypes;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<String> onCrimeChanged;

  String _dayLabel(int d) {
    if (d == 7) return '7 g';
    if (d == 30) return '1 ay';
    if (d == 90) return '3 ay';
    if (d == 180) return '6 ay';
    if (d == 365) return '1 yıl';
    return '$d g';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          _HorizontalSelector<int>(
            items: dayOptions,
            selected: selectedDays,
            labelBuilder: _dayLabel,
            onSelected: onDaysChanged,
            accentColor: _kOrange,
          ),
          const SizedBox(height: 6),
          _HorizontalSelector<String>(
            items: crimeTypes,
            selected: selectedCrimeType,
            labelBuilder: (v) => v,
            onSelected: onCrimeChanged,
            accentColor: _kPrimary,
          ),
        ],
      ),
    );
  }
}

class _PredictionFilterBar extends StatelessWidget {
  const _PredictionFilterBar({
    required this.selectedWeekStart,
    required this.weeks,
    required this.onWeekChanged,
  });

  final String selectedWeekStart;
  final List<String> weeks;
  final ValueChanged<String> onWeekChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 8),
      child: _HorizontalSelector<String>(
        items: weeks,
        selected: selectedWeekStart,
        labelBuilder: (v) => 'Hafta: $v',
        onSelected: onWeekChanged,
        accentColor: _kOrange,
      ),
    );
  }
}

class _HorizontalSelector<T> extends StatelessWidget {
  const _HorizontalSelector({
    required this.items,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    required this.accentColor,
  });

  final List<T> items;
  final T selected;
  final String Function(T item) labelBuilder;
  final ValueChanged<T> onSelected;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final item = items[i];
          final isSelected = item == selected;

          return GestureDetector(
            onTap: () => onSelected(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? accentColor : Colors.grey.shade300,
                ),
              ),
              child: Text(
                labelBuilder(item),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
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
            color: Colors.grey.shade700,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  const _LegendCard({
    required this.mode,
  });

  final HeatmapMode mode;

  @override
  Widget build(BuildContext context) {
    final title = mode == HeatmapMode.actual
        ? 'Gerçek suç yoğunluğu'
        : 'Tahmini suç riski';

    final subtitle = mode == HeatmapMode.actual
        ? 'Geçmiş suç kayıtlarına göre'
        : 'XGBoost tahmin çıktısına göre';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              mode == HeatmapMode.actual
                  ? Icons.local_fire_department_rounded
                  : Icons.auto_graph_rounded,
              color: _kPrimary,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: const [
              _LegendDot(color: Color(0xFF5A8CFF)),
              _LegendDot(color: Color(0xFF00DCAA)),
              _LegendDot(color: Color(0xFFFFDC00)),
              _LegendDot(color: Color(0xFFFF3C00)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
