import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

        _fromCtrl.text =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
        _toCtrl.clear();
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

        _toCtrl.text =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

        _fitBounds(startPoint!, endPoint!);
      }
    });
  }

  Future<void> _calculateAlternativeRoutes() async {
    if (startPoint == null || endPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce başlangıç ve varış noktası seç.')),
      );
      return;
    }

    setState(() {
      _routeLoading = true;
      _routeResponse = null;
      _polylines.clear();
    });

    try {
      final result = await _routeService.sendUiRoute(
        startLat: startPoint!.latitude,
        startLng: startPoint!.longitude,
        endLat: endPoint!.latitude,
        endLng: endPoint!.longitude,
      );

      setState(() {
        _routeResponse = result;
        _drawRoutes(result);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${result.routes.length} rota backend’den geldi.')),
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

    final routes = response.routes;

    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];

      final points = route.geometry
          .where((p) => p.length >= 2)
          .map((p) => LatLng(p[0], p[1]))
          .toList();

      if (points.isEmpty) continue;

      _polylines.add(
        Polyline(
          polylineId: PolylineId('route_${route.routeId}'),
          points: points,
          width: i == 0 ? 6 : 4,
          color: i == 0 ? _kPrimary : Colors.grey,
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

  String _routeSummaryText() {
    if (_routeResponse == null) {
      return 'Haritadan başlangıç ve varış noktası seç.';
    }

    final routes = _routeResponse!.routes;

    if (routes.isEmpty) {
      return 'Backend cevap verdi ama rota bulunamadı.';
    }

    final best = routes.first;

    return 'Rota ${best.routeId} | '
        'Mesafe: ${(best.totalLengthM / 1000).toStringAsFixed(2)} km | '
        'Segment: ${best.segments.length}';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, top > 0 ? 4 : 12, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Safe Route',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (_markers.isNotEmpty)
                        TextButton(
                          onPressed: _clear,
                          child: const Text('Temizle'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Haritadan önce başlangıç, sonra varış noktası seç.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _InputRow(
                          controller: _fromCtrl,
                          hint: 'Başlangıç koordinatı',
                          icon: Icons.radio_button_checked,
                          iconColor: _kPrimary,
                        ),
                        const SizedBox(height: 10),
                        Divider(color: Colors.grey.shade200, height: 1),
                        const SizedBox(height: 10),
                        _InputRow(
                          controller: _toCtrl,
                          hint: 'Varış koordinatı',
                          icon: Icons.location_on,
                          iconColor: Colors.orange,
                        ),
                        const SizedBox(height: 14),
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _routeSummaryText(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
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
            readOnly: true,
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
