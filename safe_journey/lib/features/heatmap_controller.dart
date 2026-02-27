import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/models/crime_point.dart';
import '../../data/services/crime_service.dart';

class HeatmapController extends ChangeNotifier {
  HeatmapController(this._service);

  final CrimeService _service;

  GoogleMapController? _map;
  Timer? _debounce;

  bool loading = false;
  Set<Circle> circles = {};

  // filtreler (sayfa set eder)
  String crimeType = 'Tümü';
  int? year;

  // performans
  int maxPoints = 3000;

  void attachMap(GoogleMapController c) {
    _map = c;
  }

  void disposeController() {
    _debounce?.cancel();
  }

  void setFilters({required String crimeType, int? year}) {
    this.crimeType = crimeType;
    this.year = year;
    scheduleFetch();
  }

  void scheduleFetch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), fetchHeat);
  }

  Future<void> fetchHeat() async {
    if (_map == null) return;

    loading = true;
    notifyListeners();

    try {
      final bounds = await _map!.getVisibleRegion();
      final zoom = (await _map!.getZoomLevel()).round();

      final points = await _service.fetchHeat(
        sw: bounds.southwest,
        ne: bounds.northeast,
        zoom: zoom,
        maxPoints: maxPoints,
        crimeType: crimeType,
        year: year,
      );

      circles = HeatmapRenderer.toCircles(points);
      loading = false;
      notifyListeners();
    } catch (_) {
      loading = false;
      notifyListeners();
      rethrow;
    }
  }
}

class HeatmapRenderer {
  static Set<Circle> toCircles(List<CrimePoint> points) {
    final circles = <Circle>{};

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final intensity = (p.intensity ?? 1);

      // intensity arttıkça radius ve opacity artsın
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
    return circles;
  }
}
