import 'package:flutter/foundation.dart';
import 'package:safe_journey/core/constants.dart';

import '../../core/api_client.dart';
import '../models/route_models.dart';

class RouteService {
  final ApiClient apiClient;

  RouteService({required this.apiClient});

  static const String _baseUrl = '${Env.baseUrl}/api';
  Future<UIRouteResponse> sendUiRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final uri = Uri.parse('$_baseUrl/uiroute');

    final json = await apiClient.postJson(
      uri,
      body: {
        'start_lat': startLat,
        'start_lng': startLng,
        'end_lat': endLat,
        'end_lng': endLng,
      },
    );

    return UIRouteResponse.fromJson(json as Map<String, dynamic>);
  }

  Future<void> debugHealthCheck() async {
    debugPrint('RouteService hazır');
  }
}
