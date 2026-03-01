import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/api_client.dart';
import '../../data/models/heat_cluster.dart';
import '../../data/services/crime_service.dart';

class HeatmapController extends ChangeNotifier {
  final CrimeService _service = CrimeService(ApiClient());

  GoogleMapController? _map;
  Timer? _debounce;

  bool loading = false;
  Set<Circle> circles = {};

  String? crimeType; // null = tümü
  int days = 365;

  void attachMap(GoogleMapController c) {
    _map = c;
  }

  void disposeAll() {
    _debounce?.cancel();
    _map?.dispose();
  }

  void setFilters({String? crimeType, int? days}) {
    this.crimeType = crimeType;
    if (days != null) this.days = days;
    scheduleFetch();
  }

  void scheduleFetch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), fetchHeat);
  }

  Future<void> fetchHeat() async {
    if (_map == null) return;

    loading = true;
    notifyListeners();

    try {
      final bounds = await _map!.getVisibleRegion();
      final zoom = (await _map!.getZoomLevel()).round();

      final limit = _limitForZoom(zoom);

      final clusters = await _service.fetchHeatClusters(
        sw: bounds.southwest,
        ne: bounds.northeast,
        zoom: zoom,
        days: days,
        limit: limit,
        crimeType: crimeType,
      );

      circles = _clustersToCircles(clusters, zoom);
    } catch (e) {
      debugPrint('fetchHeat error: $e');
      circles = {};
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  int _limitForZoom(int zoom) {
    if (zoom <= 10) return 80;
    if (zoom <= 12) return 120;
    if (zoom <= 14) return 200;
    return 300;
  }

  Color _heatColor(int c) {
    if (c >= 80) return Colors.red;
    if (c >= 40) return Colors.deepOrange;
    if (c >= 20) return Colors.orange;
    if (c >= 10) return Colors.yellow;
    return Colors.lightGreenAccent;
  }

  Set<Circle> _clustersToCircles(List<HeatCluster> clusters, int zoom) {
    final out = <Circle>{};

    // zoom-out daha büyük radius
    final base = zoom <= 10
        ? 950.0
        : zoom <= 12
            ? 700.0
            : zoom <= 14
                ? 480.0
                : 300.0;

    for (int i = 0; i < clusters.length; i++) {
      final p = clusters[i];
      final c = p.count; // int

      final color = _heatColor(c);

      // yoğunluk arttıkça opaklık artsın ama clamp ile sınırla
      final alpha = (0.06 + c / 220.0).clamp(0.06, 0.45);

      // yoğunluk arttıkça radius artsın (ama aşırı şişmesin)
      final r = (base + c * 12.0).clamp(base, base + 1800.0);

      // 3 katman: dış halo, orta, iç çekirdek
      out.add(Circle(
        circleId: CircleId('cl_${i}_3'),
        center: LatLng(p.lat, p.lng),
        radius: r * 1.35,
        fillColor: color.withOpacity((alpha * 0.35).clamp(0.03, 0.18)),
        strokeWidth: 0,
      ));
      out.add(Circle(
        circleId: CircleId('cl_${i}_2'),
        center: LatLng(p.lat, p.lng),
        radius: r * 0.95,
        fillColor: color.withOpacity((alpha * 0.65).clamp(0.05, 0.32)),
        strokeWidth: 0,
      ));
      out.add(Circle(
        circleId: CircleId('cl_${i}_1'),
        center: LatLng(p.lat, p.lng),
        radius: r * 0.55,
        fillColor: color.withOpacity((alpha * 1.05).clamp(0.08, 0.55)),
        strokeWidth: 0,
      ));
    }

    return out;
  }
}
