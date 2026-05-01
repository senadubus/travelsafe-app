import 'dart:async';

import 'package:flutter/material.dart';

import 'package:safe_journey/core/api_client.dart';
import 'package:safe_journey/core/constants.dart';
import 'package:safe_journey/data/models/crime_point.dart';
import 'package:safe_journey/shared/widgets/crime_card.dart';
import 'package:safe_journey/shared/widgets/empty_error_views.dart';
import 'package:safe_journey/shared/widgets/filter_chip.dart';

// ── constants ────────────────────────────────────────────────────────────────

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

// ── page ─────────────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _CrimeHeader(
            searchCtrl: _searchCtrl,
            onSearchChanged: _onSearchChanged,
            selectedType: _selectedType,
            onTypeChanged: _onTypeChanged,
            totalShown: _filtered.length,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? ErrorView(
                        message: _errorMessage!,
                        onRetry: _fetchPoints,
                      )
                    : _filtered.isEmpty
                        ? EmptyView(selectedType: _selectedType)
                        : RefreshIndicator(
                            onRefresh: _fetchPoints,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) =>
                                  CrimeListCard(point: _filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

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
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kAllTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final t = _kAllTypes[i];
                return SmallChip(
                  label: t,
                  selected: t == selectedType,
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
