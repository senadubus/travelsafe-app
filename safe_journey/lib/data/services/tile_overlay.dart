import 'dart:typed_data';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:safe_journey/core/api_client.dart';
import 'package:safe_journey/core/constants.dart';

class HeatTileProvider implements TileProvider {
  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    // backend'den png tile indir
    final url = Uri.parse(
      '${Env.baseUrl}/tiles/heat/$zoom/$x/$y.png?days=365&crime_type=THEFT',
    );

    final bytes = await ApiClient().getBytes(url); // bunu birazdan ekliyorum

    if (bytes.isEmpty) {
      return TileProvider.noTile;
    }
    return Tile(256, 256, bytes);
  }
}
