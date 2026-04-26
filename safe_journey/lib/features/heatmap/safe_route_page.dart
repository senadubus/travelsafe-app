import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import 'package:safe_journey/core/api_client.dart';
import 'package:safe_journey/data/models/route_models.dart';
import 'package:safe_journey/data/services/route_service.dart';

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

  int? _selectedRouteIndex;
  String _selectedMode = "car";

  GoogleMapController? _mapController;
  late final RouteService _routeService;

  bool _routeLoading = false;

  LatLng? startPoint;
  LatLng? endPoint;

  UIRouteResponse? _routeResponse;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  static const LatLng _initialCenter = LatLng(41.8781, -87.6298);

  @override
  void initState() {
    super.initState();
    _routeService = RouteService(apiClient: ApiClient());
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
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
          )
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
      _routeResponse = null;
      _polylines.clear();

      if (startPoint == null || endPoint != null) {
        startPoint = point;
        endPoint = null;

        _markers
          ..clear()
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
      } else {
        endPoint = point;

        _markers.add(
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

        _fitBounds(startPoint!, endPoint!);
      }
    });
  }

  Future<void> _calculateAlternativeRoutes() async {
    setState(() {
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

      //koordinatları gözüküyor

      //_fromCtrl.text =
      //    '${resolvedStart.latitude.toStringAsFixed(5)}, ${resolvedStart.longitude.toStringAsFixed(5)}';
      //_toCtrl.text =
      //    '${resolvedEnd.latitude.toStringAsFixed(5)}, ${resolvedEnd.longitude.toStringAsFixed(5)}';

      _markers
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
      _markers.clear();
      _polylines.clear();
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
                      if (_markers.isNotEmpty)
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
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        markers: _markers,
                        polylines: _polylines,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        onTap: _handleMapTap,
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
