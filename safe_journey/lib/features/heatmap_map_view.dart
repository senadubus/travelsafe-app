import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'heatmap_controller.dart';

class HeatmapMapView extends StatefulWidget {
  final HeatmapController controller;
  final CameraPosition initial;

  const HeatmapMapView({
    super.key,
    required this.controller,
    required this.initial,
  });

  @override
  State<HeatmapMapView> createState() => _HeatmapMapViewState();
}

class _HeatmapMapViewState extends State<HeatmapMapView> {
  @override
  void dispose() {
    widget.controller.disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, __) {
        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: widget.initial,
              onMapCreated: (c) {
                widget.controller.attachMap(c);
                widget.controller.fetchHeat(); // ilk yükleme
              },
              onCameraIdle: widget.controller.scheduleFetch,
              circles: widget.controller.circles,
            ),
            if (widget.controller.loading)
              const Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }
}
