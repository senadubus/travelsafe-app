import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants.dart';
import '../../core/api_client.dart';
import '../models/heat_cluster.dart';

class CrimeService {
  final ApiClient _api;
  CrimeService(this._api);

  Future<List<HeatCluster>> fetchHeatClusters({
    required LatLng sw,
    required LatLng ne,
    required int zoom,
    int days = 365,
    int limit = 800,
    String? crimeType,
  }) async {
    final qp = <String, String>{
      'min_lat': sw.latitude.toString(),
      'min_lng': sw.longitude.toString(),
      'max_lat': ne.latitude.toString(),
      'max_lng': ne.longitude.toString(),
      'zoom': zoom.toString(),
      'days': days.toString(),
      'limit': limit.toString(),
    };

    if (crimeType != null) qp['crime_type'] = crimeType;

    final uri = Uri.parse('${Env.baseUrl}/api/crimes/heat')
        .replace(queryParameters: qp);

    final json = await _api.getJson(uri);

    if (json is! List) {
      throw Exception('Unexpected response type: ${json.runtimeType}');
    }

    return json
        .map((e) => HeatCluster.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
