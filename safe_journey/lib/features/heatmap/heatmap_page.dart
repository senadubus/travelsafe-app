import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'heatmap_controller.dart';

class HeatmapPage extends StatefulWidget {
  const HeatmapPage({super.key});

  @override
  State<HeatmapPage> createState() => _HeatmapPageState();
}

class _HeatmapPageState extends State<HeatmapPage> {
  late final HeatmapController controller;

  @override
  void initState() {
    super.initState();
    controller = HeatmapController();
  }

  @override
  void dispose() {
    controller.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(41.8781, -87.6298),
                  zoom: 11,
                ),
                onMapCreated: (c) {
                  controller.attachMap(c);
                  controller.fetchHeat();
                },
                onCameraMove: (_) => controller.scheduleFetch(),
                myLocationButtonEnabled: false,
                compassEnabled: false,
                tiltGesturesEnabled: false,
                mapToolbarEnabled: false,
                circles: controller.circles,
              ),
              if (controller.loading)
                const Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}
