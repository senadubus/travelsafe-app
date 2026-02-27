import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/env.dart';
import '../../core/api.dart';
import '../models/crime_point.dart';

class CrimeService {
  final ApiClient _api;
  CrimeService(this._api);

  // Ham noktalar (eski endpoint)
  Future<List<CrimePoint>> fetchCrimePoints({int limit = 5000}) async {
    final uri = Uri.parse('${Env.baseUrl}/api/crimes?limit=$limit');
    final data = await _api.getJson(uri) as List;
    return data
        .map((e) => CrimePoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CrimePoint>> fetchHeat({
    required LatLng sw,
    required LatLng ne,
    required int zoom,
    int maxPoints = 3000,
    String? crimeType, // THEFT gibi. null ise filtre yok
    int? year,
  }) async {
    final qp = <String, String>{
      'min_lat': sw.latitude.toString(),
      'min_lng': sw.longitude.toString(),
      'max_lat': ne.latitude.toString(),
      'max_lng': ne.longitude.toString(),
      'zoom': zoom.toString(),
      'max_points': maxPoints.toString(),
      if (crimeType != null && crimeType.isNotEmpty && crimeType != 'Tümü')
        'crime_type': crimeType,
      if (year != null) 'year': year.toString(),
    };

    final uri = Uri.parse('${Env.baseUrl}/api/crimes/heat')
        .replace(queryParameters: qp);

    final data = await _api.getJson(uri) as List;

    // heat endpoint crime alanı dönmüyorsa HEAT bas
    return data
        .map((e) => CrimePoint.fromJson({
              'crime': 'HEAT',
              ...(e as Map<String, dynamic>),
            }))
        .toList();
  }
}
