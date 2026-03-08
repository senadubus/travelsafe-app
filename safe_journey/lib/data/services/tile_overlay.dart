import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:safe_journey/core/api_client.dart';
import 'package:safe_journey/core/constants.dart';
import 'package:safe_journey/features/heatmap/heatmap_controller.dart';

class HeatTileProvider implements TileProvider {
  final ApiClient api;
  final HeatmapController controller;
  HeatTileProvider({required this.api, required this.controller});

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null) return TileProvider.noTile;

    final qp = <String, String>{
      'days': controller.days.toString(),
      if (controller.crimeType != null) 'crime_type': controller.crimeType!,
    };

    final uri = Uri.parse('${Env.baseUrl}/tiles/heat/$zoom/$x/$y.png')
        .replace(queryParameters: qp);

    final bytes = await api.getBytes(uri);
    if (bytes.isEmpty) return TileProvider.noTile;

    return Tile(256, 256, bytes);
  }
}
