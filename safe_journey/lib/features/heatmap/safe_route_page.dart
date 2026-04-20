import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/api_client.dart';
import '../../data/models/route_models.dart';
import '../../data/services/route_service.dart';

const _kPrimary = Color(0xFF6B4FA0);
const _kOrange = Color(0xFFE8761A);

class SafeRoutePage extends StatefulWidget {
  const SafeRoutePage({super.key});

  @override
  State<SafeRoutePage> createState() => _SafeRoutePageState();
}

class _SafeRoutePageState extends State<SafeRoutePage> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  late final ApiClient _apiClient;
  late final RouteService _routeService;

  bool _hasResult = false;
  bool _searching = false;

  GoogleMapController? _mapController;
  List<RouteOption> _routes = [];
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _routeService = RouteService(apiClient: _apiClient);

    // test için istersen hazır koordinat bas
    _fromCtrl.text = '41.8781,-87.6298';
    _toCtrl.text = '41.8910,-87.6040';
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _apiClient.dispose();
    super.dispose();
  }

  ({double lat, double lng}) _parseLatLng(String value) {
    final parts = value.split(',');
    if (parts.length != 2) {
      throw Exception('Konumu "lat,lng" formatında gir. Örn: 41.8781,-87.6298');
    }

    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());

    if (lat == null || lng == null) {
      throw Exception('Geçerli koordinat gir. Örn: 41.8781,-87.6298');
    }

    return (lat: lat, lng: lng);
  }

  Future<void> _findRoute() async {
    if (_fromCtrl.text.trim().isEmpty || _toCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter both start and destination')),
      );
      return;
    }

    try {
      final start = _parseLatLng(_fromCtrl.text.trim());
      final end = _parseLatLng(_toCtrl.text.trim());

      FocusScope.of(context).unfocus();

      setState(() {
        _searching = true;
        _hasResult = false;
      });

      final response = await _routeService.getAlternativeRoutes(
        startLat: start.lat,
        startLng: start.lng,
        endLat: end.lat,
        endLng: end.lng,
      );

      debugPrint("ROUTE COUNT: ${response.routes.length}");
      if (response.routes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No route found.')),
        );
        return;
      }

      for (var r in response.routes) {
        debugPrint("points: ${r.geometry.length}");
      }

      final polylines = <Polyline>{};

      for (int i = 0; i < response.routes.length; i++) {
        final route = response.routes[i];

        final points =
            route.geometry.map((point) => LatLng(point[0], point[1])).toList();

        if (points.isEmpty) continue;

        polylines.add(
          Polyline(
            polylineId: PolylineId('route_$i'),
            points: points,
            width: i == 0 ? 6 : 4,
            color: i == 0 ? _kPrimary : (i == 1 ? Colors.green : Colors.orange),
          ),
        );
      }

      final markers = <Marker>{
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(start.lat, start.lng),
          infoWindow: const InfoWindow(title: 'Start'),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: LatLng(end.lat, end.lng),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      };

      setState(() {
        _routes = response.routes;
        _polylines = polylines;
        _markers = markers;
        _hasResult = response.routes.isNotEmpty;
      });

      if (response.routes.isNotEmpty &&
          response.routes.first.geometry.isNotEmpty) {
        final firstPoint = response.routes.first.geometry.first;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(firstPoint[0], firstPoint[1]),
            13,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() {
        _hasResult = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  void _clearRoute() {
    setState(() {
      _hasResult = false;
      _routes = [];
      _polylines = {};
      _markers = {};
    });
    _fromCtrl.clear();
    _toCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final primaryRoute = _routes.isNotEmpty ? _routes.first : null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: top + 12,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Safe Route',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const Spacer(),
                    if (_hasResult)
                      TextButton.icon(
                        onPressed: _clearRoute,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter coordinates as lat,lng',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),
                _RouteInputField(
                  controller: _fromCtrl,
                  hint: 'Start location (lat,lng)',
                  icon: Icons.radio_button_checked,
                  iconColor: _kPrimary,
                  onClear: () => setState(() => _fromCtrl.clear()),
                ),
                const _RouteDivider(),
                _RouteInputField(
                  controller: _toCtrl,
                  hint: 'Destination (lat,lng)',
                  icon: Icons.location_on,
                  iconColor: _kOrange,
                  onClear: () => setState(() => _toCtrl.clear()),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _searching ? null : _findRoute,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.alt_route, size: 18),
                    label: Text(
                      _searching
                          ? 'Finding safest route…'
                          : 'Find Safest Route',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _hasResult && primaryRoute != null
                ? _RouteMapPreview(
                    from: _fromCtrl.text,
                    to: _toCtrl.text,
                    route: primaryRoute,
                    routes: _routes,
                    polylines: _polylines,
                    markers: _markers,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                  )
                : _MapPlaceholder(isSearching: _searching),
          ),
        ],
      ),
    );
  }
}

class _RouteInputField extends StatelessWidget {
  const _RouteInputField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, v, __) => v.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: Icon(Icons.clear,
                            size: 16, color: Colors.grey[400]),
                        onPressed: onClear,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteDivider extends StatelessWidget {
  const _RouteDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Column(
          children: List.generate(
            3,
            (_) => Container(
              width: 2,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      );
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.isSearching});
  final bool isSearching;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFEEE8F4),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSearching ? Icons.alt_route : Icons.map_outlined,
                size: 56,
                color: _kPrimary.withOpacity(0.25),
              ),
              const SizedBox(height: 12),
              Text(
                isSearching
                    ? 'Calculating safest route…'
                    : 'Enter start and destination\na s lat,lng to preview the route',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _kPrimary.withOpacity(0.45),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
}

class _RouteMapPreview extends StatelessWidget {
  const _RouteMapPreview({
    required this.from,
    required this.to,
    required this.route,
    required this.routes,
    required this.polylines,
    required this.markers,
    required this.onMapCreated,
  });

  final String from;
  final String to;
  final RouteOption route;
  final List<RouteOption> routes;
  final Set<Polyline> polylines;
  final Set<Marker> markers;
  final ValueChanged<GoogleMapController> onMapCreated;

  String _formatMinutes(double meters) {
    final minutes = (meters / 80).round();
    return '~$minutes min';
  }

  String _formatRisk(double risk) => risk.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final firstPoint = route.geometry.isNotEmpty
        ? LatLng(route.geometry.first[0], route.geometry.first[1])
        : const LatLng(41.8781, -87.6298);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: firstPoint,
            zoom: 13,
          ),
          onMapCreated: onMapCreated,
          polylines: polylines,
          markers: markers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Material(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black12,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _RouteStat(
                        icon: Icons.shield_outlined,
                        label: 'Risk',
                        value: _formatRisk(route.totalRisk),
                        color: Colors.green[600]!,
                      ),
                      const SizedBox(width: 16),
                      _RouteStat(
                        icon: Icons.timer_outlined,
                        label: 'Est. time',
                        value: _formatMinutes(route.totalLengthM),
                        color: _kPrimary,
                      ),
                      const SizedBox(width: 16),
                      _RouteStat(
                        icon: Icons.straighten_outlined,
                        label: 'Distance',
                        value:
                            '${(route.totalLengthM / 1000).toStringAsFixed(2)} km',
                        color: Colors.grey[600]!,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.radio_button_checked,
                          size: 14, color: _kPrimary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          from,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward,
                            size: 14, color: Colors.grey),
                      ),
                      const Icon(Icons.location_on, size: 14, color: _kOrange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          to,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (routes.length > 1) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: routes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final r = routes[index];
                          return Chip(
                            label: Text(
                              '${r.routeLabel} • ${(r.totalLengthM / 1000).toStringAsFixed(2)} km',
                            ),
                          );
                        },
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteStat extends StatelessWidget {
  const _RouteStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
}
