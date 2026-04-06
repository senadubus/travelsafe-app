import 'dart:async';

import 'package:flutter/material.dart';

import 'package:safe_journey/core/api_client.dart';
import 'package:safe_journey/core/constants.dart';
import 'package:safe_journey/data/models/crime_point.dart';

// ─── constants ────────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF6B4FA0);

const _kAllTypes = <String>[
  'All',
  'Theft',
  'Assault',
  'Battery',
  'Burglary',
  'Robbery',
  'Narcotics',
  'Homicide',
];

// Intensity → color mapping (matches heatmap palette)
Color _intensityColor(int? intensity) {
  if (intensity == null || intensity <= 1) return Colors.green[600]!;
  if (intensity <= 3) return Colors.orange[700]!;
  return Colors.red[600]!;
}

String _intensityLabel(int? intensity) {
  if (intensity == null || intensity <= 1) return 'Low';
  if (intensity <= 3) return 'Medium';
  return 'High';
}

// ─── page ─────────────────────────────────────────────────────────────────────

class CrimePointsPage extends StatefulWidget {
  const CrimePointsPage({super.key});

  @override
  State<CrimePointsPage> createState() => _CrimePointsPageState();
}

class _CrimePointsPageState extends State<CrimePointsPage> {
  final ApiClient _api = ApiClient();

  List<CrimePoint> _allPoints = [];
  List<CrimePoint> _filtered = [];
  bool _loading = false;
  String? _errorMessage;

  String _selectedType = 'All';
  String _searchQuery = '';

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPoints();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── fetch ────────────────────────────────────────────────────────────────
  Future<void> _fetchPoints() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final uri = Uri.parse('${Env.baseUrl}/api/crimes/points');
      final raw = await _api.getJson(uri) as List<dynamic>;
      final points = raw
          .map((e) => CrimePoint.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _allPoints = points;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── filter ───────────────────────────────────────────────────────────────
  void _applyFilter() {
    final q = _searchQuery.toLowerCase();
    setState(() {
      _filtered = _allPoints.where((p) {
        final typeMatch = _selectedType == 'All' ||
            p.crime.toLowerCase().contains(_selectedType.toLowerCase());
        final searchMatch = q.isEmpty ||
            p.crime.toLowerCase().contains(q) ||
            '${p.lat.toStringAsFixed(3)}, ${p.lng.toStringAsFixed(3)}'
                .contains(q);
        return typeMatch && searchMatch;
      }).toList();
    });
  }

  void _onTypeChanged(String type) {
    setState(() => _selectedType = type);
    _applyFilter();
  }

  void _onSearchChanged(String q) {
    _searchQuery = q;
    _applyFilter();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          _CrimeHeader(
            searchCtrl: _searchCtrl,
            onSearchChanged: _onSearchChanged,
            selectedType: _selectedType,
            onTypeChanged: _onTypeChanged,
            totalShown: _filtered.length,
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _ErrorView(
                        message: _errorMessage!,
                        onRetry: _fetchPoints,
                      )
                    : _filtered.isEmpty
                        ? _EmptyView(selectedType: _selectedType)
                        : RefreshIndicator(
                            onRefresh: _fetchPoints,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) =>
                                  _CrimeCard(point: _filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _CrimeHeader extends StatelessWidget {
  const _CrimeHeader({
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.selectedType,
    required this.onTypeChanged,
    required this.totalShown,
  });

  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;
  final int totalShown;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: top + 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Crime Points',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalShown found',
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

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by type or location…',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon:
                    Icon(Icons.search, color: Colors.grey[400], size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            size: 18, color: Colors.grey[400]),
                        onPressed: () {
                          searchCtrl.clear();
                          onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Filter chips
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kAllTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final t = _kAllTypes[i];
                final sel = t == selectedType;
                return _SmallChip(
                  label: t,
                  selected: sel,
                  onTap: () => onTypeChanged(t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Crime Card ───────────────────────────────────────────────────────────────

class _CrimeCard extends StatelessWidget {
  const _CrimeCard({required this.point});
  final CrimePoint point;

  @override
  Widget build(BuildContext context) {
    final color = _intensityColor(point.intensity);
    final level = _intensityLabel(point.intensity);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_crimeIcon(point.crime), color: color, size: 20),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _toTitleCase(point.crime),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${point.lat.toStringAsFixed(4)}, '
                    '${point.lng.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            // Severity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                level,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _crimeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('theft') || t.contains('burglary') || t.contains('robbery'))
      return Icons.money_off_rounded;
    if (t.contains('assault') || t.contains('battery'))
      return Icons.personal_injury_outlined;
    if (t.contains('narcotics')) return Icons.medication_outlined;
    if (t.contains('homicide')) return Icons.gpp_bad_outlined;
    return Icons.report_outlined;
  }

  String _toTitleCase(String s) =>
      s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ─── Small chip ───────────────────────────────────────────────────────────────

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? _kPrimary : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kPrimary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

// ─── Empty / Error states ─────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.selectedType});
  final String selectedType;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No results for "$selectedType"',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'Could not load data',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              ),
            ],
          ),
        ),
      );
}
