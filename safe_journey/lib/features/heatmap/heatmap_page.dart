import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants.dart';
import '../../core/api_client.dart';
import 'heatmap_controller.dart';

class HeatmapPage extends StatefulWidget {
  const HeatmapPage({super.key});

  @override
  State<HeatmapPage> createState() => _HeatmapPageState();
}

class _HeatmapPageState extends State<HeatmapPage> {
  late final HeatmapController controller;

  late final TileOverlay _heatOverlay;

  @override
  void initState() {
    super.initState();
    controller = HeatmapController();

    _heatOverlay = TileOverlay(
      tileOverlayId: const TileOverlayId('heat'),
      tileProvider: HeatTileProvider(
        api: ApiClient(),
        controller: controller,
      ),
      zIndex: 10,
      transparency: 0.15,
    );
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
                  controller.scheduleFetch(); // ilk yükleme
                },
                onCameraIdle: controller.scheduleFetch,

                myLocationButtonEnabled: false,
                compassEnabled: false,
                tiltGesturesEnabled: false,
                mapToolbarEnabled: false,

                // ✅ circles yerine tile overlay
                tileOverlays: {_heatOverlay},
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

/// TileProvider: (z/x/y) tile png’yi backend’den alır.
class HeatTileProvider implements TileProvider {
  final ApiClient api;
  final HeatmapController controller;

  HeatTileProvider({required this.api, required this.controller});

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    try {
      // controller’dan filtreleri çek
      final days = controller.days;
      final crimeType = controller.crimeType;

      final qp = <String, String>{
        'days': days.toString(),
        if (crimeType != null) 'crime_type': crimeType,
      };

      // örnek endpoint: /tiles/heat/{z}/{x}/{y}.png
      final uri = Uri.parse('${Env.baseUrl}/tiles/heat/$zoom/$x/$y.png')
          .replace(queryParameters: qp);

      final bytes = await api.getBytes(uri);
      if (bytes.isEmpty) return TileProvider.noTile;

      return Tile(256, 256, bytes);
    } catch (_) {
      return TileProvider.noTile;
    }
  }
}
